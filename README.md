# FNOL Claims Processing Agent

AI-powered agent for automating first-notice-of-loss (FNOL) claims intake, triage, validation, and routing.

## Project Overview

This system automates FNOL processing for an insurance company handling 300 claims per day:
- **Extracts** structured data from unstructured FNOL reports (emails, phone transcripts, web forms)
- **Triages** claims by severity (LOW, MEDIUM, HIGH, CRITICAL)
- **Validates** policy coverage against legacy policy administration system
- **Routes** claims to appropriate adjusters based on specialty and workload
- **Acknowledges** claimants via email/SMS within 5 minutes

**Key Results:**
- 70% of claims processed autonomously (no human review)
- SLA compliance: 95%+ acknowledged within 5 minutes (current: 69% within 2 hours)
- Routing accuracy: 95%+ (current: 82%)
- Capacity gain: 68 person-hours/day freed for complex claims

## Architecture

```
┌─────────────┐
│   CRM API   │ ──► Claims Ingestion
└─────────────┘
       │
       ▼
┌─────────────────────────────────────────┐
│      FNOL Processing Agent              │
│  ┌─────────────────────────────────┐   │
│  │ 1. Extraction (NLP)             │   │
│  │ 2. Severity Triage              │   │
│  │ 3. Policy Validation (SOAP)     │   │
│  │ 4. Adjuster Routing             │   │
│  │ 5. Claimant Acknowledgment      │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
       │
       ├──► MySQL Database (claims, policies, adjusters)
       ├──► Policy SOAP API (validation)
       ├──► Notification Service (email/SMS)
       └──► Monitoring & Logging
```

## Prerequisites

- **Python 3.11+**
- **MySQL 8.0+**
- **Git**
- **Virtual environment** (venv or conda)

## Quick Start

### 1. Clone and Setup

```bash
# Clone repository
cd /c/Users/Andrzej_Bihun/Projects/FDE_Week1Gateway

# Create virtual environment
python -m venv venv

# Activate virtual environment
# Windows:
venv\Scripts\activate
# macOS/Linux:
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

### 2. Database Setup

```bash
# Start MySQL (if not running)
# Windows: Start MySQL service from Services
# macOS: brew services start mysql
# Linux: sudo systemctl start mysql

# Create database
mysql -u root -p
CREATE DATABASE fnol_claims CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'fnol_user'@'localhost' IDENTIFIED BY 'your_secure_password';
GRANT ALL PRIVILEGES ON fnol_claims.* TO 'fnol_user'@'localhost';
FLUSH PRIVILEGES;
EXIT;

# Run database migrations
cd src
alembic upgrade head
```

### 3. Configuration

```bash
# Copy environment template
cp .env.example .env

# Edit .env with your actual credentials
# At minimum, set:
# - DB_PASSWORD (your MySQL password)
# - OPENAI_API_KEY (for NLP extraction)
# - Set ENABLE_MOCK_INTEGRATIONS=true for development
```

### 4. Run the Agent

```bash
# Development mode (with auto-reload)
cd src
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Production mode
uvicorn main:app --host 0.0.0.0 --port 8000 --workers 4
```

The API will be available at: `http://localhost:8000`

API documentation (Swagger UI): `http://localhost:8000/docs`

### 5. Test the Agent

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=src --cov-report=html

# Run specific test file
pytest tests/test_extraction.py

# Run with verbose output
pytest -v
```

## Project Structure

```
FDE_Week1Gateway/
├── Specification/              # Design documents (from Gate 1)
│   ├── 01_Problem_statement_and_success_metrics.md
│   ├── 02_Delegation_analysis.md
│   ├── 03_Agent_specification.md
│   ├── 04_Validation_design.md
│   └── 05_Assumptions_and_unknowns.md
├── src/                        # Source code
│   ├── main.py                 # FastAPI application entry point
│   ├── config.py               # Configuration management (.env loader)
│   ├── models/                 # Database models (SQLAlchemy)
│   │   ├── claim.py
│   │   ├── claimant.py
│   │   ├── policy.py
│   │   └── adjuster.py
│   ├── services/               # Business logic
│   │   ├── extraction_service.py
│   │   ├── triage_service.py
│   │   ├── validation_service.py
│   │   ├── routing_service.py
│   │   └── notification_service.py
│   ├── integrations/           # External API clients
│   │   ├── crm_client.py
│   │   ├── policy_soap_client.py
│   │   ├── notification_client.py
│   │   └── dms_client.py
│   ├── api/                    # FastAPI routes
│   │   ├── claims.py
│   │   ├── health.py
│   │   └── admin.py
│   ├── schemas/                # Pydantic schemas (API contracts)
│   │   ├── claim_schemas.py
│   │   └── response_schemas.py
│   └── utils/                  # Utilities
│       ├── logging.py
│       └── metrics.py
├── tests/                      # Test suite
│   ├── unit/
│   │   ├── test_extraction.py
│   │   ├── test_triage.py
│   │   └── test_routing.py
│   ├── integration/
│   │   ├── test_crm_api.py
│   │   └── test_policy_soap.py
│   └── e2e/
│       └── test_claim_processing.py
├── scripts/                    # Utility scripts
│   ├── seed_test_data.py
│   └── load_test.py
├── alembic/                    # Database migrations
│   ├── versions/
│   └── env.py
├── docs/                       # Additional documentation
├── .env.example                # Environment configuration template
├── .gitignore
├── requirements.txt            # Python dependencies
└── README.md                   # This file
```

## Development Workflow

### 1. Feature Development

```bash
# Create feature branch
git checkout -b feature/extraction-service

# Make changes, commit frequently
git add .
git commit -m "Implement NLP extraction service"

# Push to remote
git push origin feature/extraction-service

# Create pull request (review + merge)
```

### 2. Database Changes

```bash
# Create new migration
cd src
alembic revision --autogenerate -m "Add extraction_result table"

# Review generated migration in alembic/versions/
# Edit if needed

# Apply migration
alembic upgrade head

# Rollback if needed
alembic downgrade -1
```

### 3. Testing

```bash
# Run tests before committing
pytest

# Test specific service
pytest tests/unit/test_triage.py -v

# Run with coverage
pytest --cov=src --cov-report=html
# View coverage: open htmlcov/index.html
```

### 4. Code Quality

```bash
# Format code
black src/ tests/

# Lint code
flake8 src/ tests/

# Type checking
mypy src/
```

## Configuration Guide

### Environment Variables

Key configuration in `.env`:

**Database:**
- `DB_HOST`: MySQL host (default: localhost)
- `DB_PORT`: MySQL port (default: 3306)
- `DB_NAME`: Database name (fnol_claims)
- `DB_USER`: Database user
- `DB_PASSWORD`: Database password

**NLP Provider:**
- `NLP_PROVIDER`: openai | azure_openai | claude | local
- `OPENAI_API_KEY`: OpenAI API key
- `OPENAI_MODEL`: Model to use (gpt-4-turbo-preview)

**Agent Behavior:**
- `EXTRACTION_CONFIDENCE_THRESHOLD`: 0.7 (escalate if below)
- `SEVERITY_THRESHOLDS_LOW`: 5000 (< $5K = LOW)
- `SEVERITY_THRESHOLDS_HIGH`: 50000 (> $50K = HIGH)

**Mock Integrations:**
- `ENABLE_MOCK_INTEGRATIONS`: true (use mocks for testing)
- `MOCK_CRM_API`: true
- `MOCK_POLICY_SOAP`: true

### Mock vs Real Integrations

**Development (local):** Set `ENABLE_MOCK_INTEGRATIONS=true`
- All external APIs mocked with predictable responses
- No actual API calls to CRM, SOAP, Notification services
- Fast testing, no external dependencies

**Staging:** Set `ENABLE_MOCK_INTEGRATIONS=false`
- Connect to real test environments
- Requires valid credentials in `.env`
- Tests actual integration behavior

**Production:** All real integrations, no mocks

## API Endpoints

### Health Check
```bash
GET /health
# Returns: {"status": "healthy", "database": "connected"}
```

### Process FNOL Claim
```bash
POST /api/v1/claims/fnol
Content-Type: application/json

{
  "source_channel": "WEB_FORM",
  "raw_content": "My windshield cracked...",
  "claimant_email": "john@example.com",
  "claimant_phone": "555-123-4567",
  "received_timestamp": "2026-04-27T10:00:00Z"
}

# Returns:
{
  "claim_id": "uuid",
  "claim_number": "CLM-20260427-0001",
  "status": "ACKNOWLEDGED",
  "severity": "LOW",
  "sla_deadline": "2026-04-27T12:00:00Z",
  "acknowledged_at": "2026-04-27T10:00:15Z"
}
```

### Get Claim Status
```bash
GET /api/v1/claims/{claim_id}

# Returns full claim details including audit log
```

## Monitoring

### Metrics Endpoint
```bash
GET /metrics
# Prometheus-format metrics
```

**Key metrics:**
- `fnol_claims_processed_total`: Counter of claims processed
- `fnol_claims_by_severity`: Gauge of claims by severity
- `fnol_sla_compliance_rate`: Gauge (0.0-1.0)
- `fnol_extraction_confidence_avg`: Gauge (0.0-1.0)
- `fnol_routing_accuracy_rate`: Gauge (0.0-1.0)

### Logs

Structured JSON logs:
```json
{
  "timestamp": "2026-04-27T10:00:00Z",
  "level": "INFO",
  "event": "claim_processed",
  "claim_id": "uuid",
  "severity": "LOW",
  "processing_time_ms": 1234
}
```

View logs:
```bash
# Development (console)
tail -f logs/fnol-agent.log

# Production (structured logs to file)
cat logs/fnol-agent.json | jq
```

## Troubleshooting

### Database Connection Issues
```bash
# Test MySQL connection
mysql -h localhost -u fnol_user -p fnol_claims

# Check if database exists
SHOW DATABASES;

# Check user permissions
SHOW GRANTS FOR 'fnol_user'@'localhost';
```

### API Not Starting
```bash
# Check if port 8000 is already in use
# Windows:
netstat -ano | findstr :8000
# macOS/Linux:
lsof -i :8000

# Use different port
uvicorn main:app --port 8001
```

### NLP Extraction Failing
```bash
# Check OpenAI API key
echo $OPENAI_API_KEY

# Test API key manually
curl https://api.openai.com/v1/models \
  -H "Authorization: Bearer $OPENAI_API_KEY"

# Enable mock NLP for testing
# In .env: NLP_PROVIDER=mock
```

### Tests Failing
```bash
# Ensure test database exists
mysql -u root -p
CREATE DATABASE fnol_claims_test;

# Set test environment
export APP_ENV=test

# Run tests with verbose output
pytest -v --tb=short
```

## Next Steps

### Phase 1: Core Agent (Weeks 1-2)
- [x] Project setup
- [ ] Extraction service (NLP)
- [ ] Triage service (severity classification)
- [ ] Database models and migrations
- [ ] Unit tests

### Phase 2: Integrations (Weeks 3-4)
- [ ] CRM API client
- [ ] Policy SOAP client
- [ ] Notification service client
- [ ] Integration tests

### Phase 3: Validation & Monitoring (Week 5)
- [ ] E2E tests
- [ ] Monitoring dashboard
- [ ] Load testing (300 claims/day)
- [ ] Production deployment prep

### Phase 4: Pilot (Weeks 6-8)
- [ ] Deploy to staging
- [ ] Process 10% of claims
- [ ] Measure: SLA, accuracy, specialist override rate
- [ ] Iterate based on feedback

## Support

**For issues:**
1. Check [Troubleshooting](#troubleshooting) section
2. Review specification documents in `Specification/`
3. Check logs: `logs/fnol-agent.log`
4. Contact: [Your contact info]

**Documentation:**
- Gate 1 Specification: `Specification/`
- API docs: `http://localhost:8000/docs`
- Architecture diagrams: `docs/architecture.md`

## License

[Your license here]
