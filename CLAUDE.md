# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Summary

AI-powered FNOL (First Notice of Loss) claims processing agent for insurance. Automates claims intake, triage, validation, routing, and acknowledgment with 70% autonomous processing target and 5-minute SLA compliance.

**Tech Stack**: Python 3.11+, FastAPI, MySQL 8.0+, SQLAlchemy, Alembic, OpenAI/Anthropic for NLP

## Development Commands

### Running the Application

```bash
# Start development server (with auto-reload)
cd src
python main.py
# OR
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Production mode
uvicorn main:app --host 0.0.0.0 --port 8000 --workers 4
```

Access points:
- API: http://localhost:8000
- Swagger docs: http://localhost:8000/docs
- Health check: http://localhost:8000/health

### Testing

```bash
# Run all tests
pytest

# Run with coverage report
pytest --cov=src --cov-report=html

# Run specific test category
pytest tests/unit/
pytest tests/integration/
pytest tests/e2e/

# Run specific test file
pytest tests/unit/test_extraction.py -v

# Run specific test
pytest tests/unit/test_extraction.py::test_extract_from_web_form -v
```

### Database Operations

```bash
# Create database (one-time setup)
mysql -u root -p
# Then: CREATE DATABASE fnol_claims CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

# Apply migrations
cd src
alembic upgrade head

# Create new migration
alembic revision --autogenerate -m "Add new column"

# Rollback migration
alembic downgrade -1

# View migration history
alembic history

# Load schema directly (alternative to migrations)
mysql -u fnol_user -p fnol_claims < database_schema.sql
```

### Code Quality

```bash
# Format code (before committing)
black src/ tests/

# Lint code
flake8 src/ tests/

# Type checking
mypy src/
```

## Architecture Overview

### 5-Stage Processing Pipeline

The agent processes claims through a sequential pipeline:

1. **Extraction** (`services/extraction_service.py`)
   - Input: Unstructured FNOL report (email/phone/web form)
   - Uses NLP (OpenAI GPT-4 or configured provider) to extract structured fields
   - Output: Structured data + confidence scores
   - Escalates to human if confidence < 0.7 (configurable)

2. **Triage** (`services/triage_service.py`)
   - Classifies severity: LOW (<$5K), MEDIUM ($5K-$50K), HIGH ($50K-$100K), CRITICAL (>$100K)
   - Also considers incident type, injuries, fraud flags
   - Sets SLA deadline based on severity

3. **Validation** (`services/validation_service.py`)
   - Queries Policy SOAP API to validate coverage
   - Checks: policy active, incident covered, exclusions, deductibles
   - Flags coverage issues for specialist review

4. **Routing** (`services/routing_service.py`)
   - Matches claim to adjuster based on:
     - Specialty (auto, property, liability, etc.)
     - Seniority level (HIGH/CRITICAL → senior adjusters)
     - Current workload
   - Uses confidence-based routing (escalates if confidence < 0.8)

5. **Acknowledgment** (`services/notification_service.py`)
   - Sends email/SMS to claimant with claim number
   - Target: 95%+ within 5 minutes (tracks SLA compliance)

### Key Integrations

All integrations support **mock mode** via `ENABLE_MOCK_INTEGRATIONS=true` in `.env`:

- **CRM API** (`integrations/crm_client.py`): Claims ingestion from external system
- **Policy SOAP API** (`integrations/policy_soap_client.py`): Legacy system for policy validation
- **Notification Service** (`integrations/notification_client.py`): Email/SMS delivery
- **DMS** (`integrations/dms_client.py`): Document management system

Mock mode is essential for local development as it eliminates external dependencies and provides predictable test data.

### Database Schema

Core entities (see `database_schema.sql` for complete schema):

- **claims**: Main entity tracking claims through pipeline stages
- **claimants**: Person filing the claim (linked to policy holder)
- **policies**: Policy coverage details (cached from SOAP API)
- **adjusters**: Available adjusters with specialties and workload
- **extraction_results**: Detailed NLP extraction output
- **audit_log**: Full audit trail of all claim processing steps
- **severity_overrides**: Manual severity adjustments by specialists

Key design patterns:
- UUID primary keys (CHAR(36))
- Status tracking with timestamp columns (received_at, extracted_at, triaged_at, etc.)
- Computed column for SLA breach detection
- JSON columns for flexible data (coverage_types, extraction_flags, etc.)

### Configuration System

Configuration is managed via Pydantic settings (`src/config.py`):
- Loads from `.env` file (copy from `.env.example`)
- Type-validated settings with defaults
- Grouped by concern (database, integrations, agent behavior, monitoring)

Critical settings for development:
- `ENABLE_MOCK_INTEGRATIONS=true`: Use mocks for all external APIs
- `NLP_PROVIDER=mock`: Use mock NLP (no OpenAI API key needed)
- `DEBUG_MODE=true`: Enable auto-reload and verbose logging
- `APP_ENV=development`: Development mode configuration

## Implementation Guidelines

### When Building New Services

1. **Follow the pipeline pattern**: Each service takes input from previous stage, performs logic, updates database, returns structured output
2. **Use structured logging**: `logger.info("event_name", claim_id=..., field=value)` for JSON logs
3. **Check confidence thresholds**: Escalate to human review when confidence is low
4. **Update audit_log**: Every decision should be logged for traceability
5. **Handle mock mode**: Check `settings.enable_mock_integrations` to toggle behavior
6. **Use database transactions**: Wrap multi-step operations in SQLAlchemy transactions

### When Adding API Endpoints

- Place routes in `src/api/` (e.g., `claims.py`, `admin.py`)
- Use Pydantic schemas from `src/schemas/` for request/response validation
- Include operation_id and tags for OpenAPI docs
- Add corresponding tests in `tests/integration/`

### Testing Strategy

- **Unit tests** (`tests/unit/`): Test individual services in isolation with mocked dependencies
- **Integration tests** (`tests/integration/`): Test API endpoints and external integrations
- **E2E tests** (`tests/e2e/`): Test complete claim flow from ingestion to acknowledgment

Use pytest fixtures for database setup, mock data, and test clients.

### Database Migrations

Use Alembic for schema changes:
1. Modify SQLAlchemy models in `src/models/`
2. Generate migration: `alembic revision --autogenerate -m "description"`
3. Review generated migration in `alembic/versions/` (always review - autogenerate is not perfect)
4. Apply: `alembic upgrade head`
5. Commit both model changes and migration file

## Project Structure Context

```
src/
├── main.py                 # FastAPI app entry point, CORS, health check
├── config.py              # Pydantic settings, loads .env
├── models/                # SQLAlchemy ORM models
├── services/              # Business logic (5-stage pipeline)
├── integrations/          # External API clients (CRM, SOAP, notifications)
├── api/                   # FastAPI route handlers
├── schemas/               # Pydantic request/response models
└── utils/                 # Shared utilities (logging, metrics)

Specification/             # Gate 1 deliverables (requirements, design)
tests/                     # unit/ integration/ e2e/
alembic/                   # Database migration files
scripts/                   # Utility scripts (seed_test_data.py, etc.)
```

## Important Constraints & Design Decisions

### Autonomy vs Escalation

Target: 70% autonomous processing (30% escalated to humans)

Escalate to human review when:
- Extraction confidence < 0.7
- Policy validation fails (coverage issue, exclusion triggered)
- Routing confidence < 0.8 (no clear adjuster match)
- Fraud flags detected
- High-value claim (>$100K) with complexity flags

### SLA Tracking

- Primary SLA: 95%+ of claims acknowledged within 5 minutes
- Database has computed column `sla_breach` that checks `acknowledged_at > sla_deadline`
- Current baseline: 69% within 2 hours (significant improvement opportunity)
- Monitor via `/metrics` endpoint

### Performance Requirements

- 300 claims/day (12.5/hour average, peak ~50/hour)
- Each stage should complete in <10 seconds
- Policy API cached (1 hour TTL) to reduce SOAP call latency
- Async processing preferred for I/O-bound operations

### Mock vs Real Integrations

**Always use mock mode locally** unless specifically testing real integrations:
- Mock mode provides predictable test data
- No external dependencies (no API keys, no network calls)
- Faster test execution
- Controlled error scenarios for testing edge cases

Real integrations only needed for staging/production and integration testing.

## Relevant Documentation

- **Specification/** directory contains complete Gate 1 requirements and design
  - `01_Problem_statement_and_success_metrics.md`: Business goals and KPIs
  - `03_Agent_specification.md`: Detailed logic for each pipeline stage
  - `04_Validation_design.md`: Test strategy and success criteria
- **README.md**: Setup guide, API documentation, troubleshooting
- **QUICKSTART.md**: 15-minute getting started guide
- **database_schema.sql**: Complete schema with comments

## Common Patterns in This Codebase

### Service Pattern

```python
class ExtractionService:
    def __init__(self, db_session, nlp_client):
        self.db = db_session
        self.nlp = nlp_client
    
    async def extract(self, raw_text: str, source_channel: str) -> ExtractionResult:
        # 1. Call NLP API (or mock)
        # 2. Parse structured output
        # 3. Calculate confidence scores
        # 4. Save to extraction_results table
        # 5. Update claim status to 'EXTRACTED'
        # 6. Log to audit_log
        # 7. Return result
```

### Mock Mode Pattern

```python
if settings.enable_mock_integrations or settings.mock_policy_soap:
    return MockPolicySoapClient()
else:
    return RealPolicySoapClient(
        url=settings.policy_soap_url,
        username=settings.policy_soap_username,
        password=settings.policy_soap_password
    )
```

### Structured Logging Pattern

```python
logger.info(
    "claim_triaged",
    claim_id=claim.id,
    claim_number=claim.claim_number,
    severity=claim.severity,
    estimated_value=claim.estimated_value,
    processing_time_ms=elapsed_ms
)
```
