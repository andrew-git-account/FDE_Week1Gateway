# Development Roadmap - FNOL Agent Implementation

Step-by-step guide to building the FNOL Claims Processing Agent.

---

## Phase 1: Foundation (Week 1) ✅ DONE

### Completed
- [x] Project structure created
- [x] Configuration management (`.env` + `config.py`)
- [x] FastAPI application skeleton (`main.py`)
- [x] Database schema designed (`database_schema.sql`)
- [x] Development dependencies listed (`requirements.txt`)
- [x] Documentation (README, QUICKSTART)
- [x] Git repository initialized

### Next: Set Up Local Environment

**Your immediate next steps:**

1. **Create virtual environment and install dependencies**
   ```bash
   python -m venv venv
   source venv/Scripts/activate  # or venv\Scripts\activate.bat
   pip install -r requirements.txt
   ```

2. **Setup MySQL database**
   ```bash
   mysql -u root -p < database_schema.sql
   ```

3. **Configure .env file**
   ```bash
   cp .env.example .env
   # Edit .env: Set DB_PASSWORD and OPENAI_API_KEY (or use NLP_PROVIDER=mock)
   ```

4. **Test the setup**
   ```bash
   cd src
   python main.py
   # Visit http://localhost:8000/health
   ```

---

## Phase 2: Core Services (Week 2-3)

### 2.1: Database Models (Day 1-2)

**Goal:** Create SQLAlchemy models matching database schema

**Files to create:**
- `src/models/__init__.py`
- `src/models/base.py` (Base model, session management)
- `src/models/claim.py` (Claim, ExtractionResult, AuditLog)
- `src/models/claimant.py` (Claimant)
- `src/models/policy.py` (Policy)
- `src/models/adjuster.py` (Adjuster, SeverityOverride)

**Prompt for Claude Code:**
```
Read database_schema.sql and create SQLAlchemy ORM models in src/models/.

Create:
1. src/models/base.py with database session management
2. src/models/claim.py with Claim, ExtractionResult, AuditLog models
3. src/models/claimant.py with Claimant model
4. src/models/policy.py with Policy model
5. src/models/adjuster.py with Adjuster, SeverityOverride models

Each model should:
- Match the database schema exactly (column names, types, relationships)
- Include foreign key relationships
- Have __repr__ methods for debugging
- Use UUIDs for primary keys where specified

Use config.py for database connection (settings.database_url).
```

**Test it:**
```python
# Test script: scripts/test_models.py
from src.models.claim import Claim
from src.models.base import SessionLocal

db = SessionLocal()
claims = db.query(Claim).limit(5).all()
print(f"Found {len(claims)} claims")
```

---

### 2.2: Extraction Service (Day 3-5)

**Goal:** NLP-based extraction of structured data from unstructured FNOL reports

**Reference:** Specification/03_Agent_specification.md, Section 4, Decision 1

**File to create:** `src/services/extraction_service.py`

**Core logic:**
1. Input: `raw_content` (string), `source_channel` (WEB_FORM, EMAIL, PHONE)
2. If WEB_FORM: confidence = 1.0 (already structured)
3. If EMAIL/PHONE: Use OpenAI GPT-4 to extract fields
4. Calculate confidence per field
5. Return ExtractionResult

**Prompt for Claude Code:**
```
Read Specification/03_Agent_specification.md, Section 4, Decision 1: Data Extraction.

Implement src/services/extraction_service.py with class ExtractionService:

Methods:
- extract(raw_content: str, source_channel: str) -> ExtractionResult
  - If source_channel == "WEB_FORM": parse structured fields directly
  - If source_channel in ["EMAIL", "PHONE"]: use OpenAI API to extract fields
  - Extract: policy_number, incident_date, incident_type, estimated_value, 
    injury_severity, incident_description
  - Calculate confidence per field (0.0-1.0)
  - Return ExtractionResult with overall_confidence = min(field confidences)

- extract_with_openai(text: str) -> dict
  - Use OpenAI GPT-4 with structured prompt
  - Return JSON with {field_name: {value, confidence}}

Handle:
- config.NLP_PROVIDER == "mock": return mock data with confidence 0.9
- Missing OPENAI_API_KEY: raise configuration error
- API errors: log and return low confidence result

Include logging for each extraction (claim_id, confidence, method).
```

**Test it:**
```python
# tests/unit/test_extraction.py
def test_web_form_extraction():
    service = ExtractionService()
    result = service.extract(
        raw_content='{"policy": "POL-12345678", "description": "Windshield crack", "value": "450"}',
        source_channel="WEB_FORM"
    )
    assert result.policy_number == "POL-12345678"
    assert result.confidence == 1.0

def test_email_extraction_with_mock():
    service = ExtractionService(use_mock=True)
    result = service.extract(
        raw_content="My policy is POL-12345678. I had a windshield crack yesterday. Estimate $450.",
        source_channel="EMAIL"
    )
    assert result.policy_number == "POL-12345678"
    assert result.estimated_value == 450
    assert result.confidence >= 0.7
```

---

### 2.3: Triage Service (Day 6-7)

**Goal:** Classify claims by severity (LOW, MEDIUM, HIGH, CRITICAL)

**Reference:** Specification/03_Agent_specification.md, Section 4, Decision 2

**File to create:** `src/services/triage_service.py`

**Core logic:**
1. Input: ExtractionResult (estimated_value, injury_severity, policy_type, incident_type)
2. Apply severity rules:
   - CRITICAL: value > $100K OR injury = FATAL OR multi-party liability
   - HIGH: value > $50K OR injury = SERIOUS OR exclusions detected
   - MEDIUM: value $5K-$50K OR injury = MINOR
   - LOW: value < $5K AND injury = NONE AND standard policy
3. Calculate confidence
4. Return: severity, confidence, escalation_needed

**Prompt for Claude Code:**
```
Read Specification/03_Agent_specification.md, Section 4, Decision 2: Severity Classification.

Implement src/services/triage_service.py with class TriageService:

Methods:
- classify_severity(
    estimated_value: float,
    injury_severity: str,
    policy_type: str,
    incident_type: str,
    exclusion_flags: bool,
    vip_status: bool
  ) -> TriageResult

  Apply severity rules from spec:
  - CRITICAL: value > 100000 OR injury == FATAL OR vip_status OR multi_party_liability
  - HIGH: value > 50000 OR injury IN [SERIOUS, HOSPITALIZED] OR exclusion_flags
  - MEDIUM: value >= 5000 AND value <= 50000 OR injury == MINOR
  - LOW: value < 5000 AND injury IN [NONE, null] AND policy_type == STANDARD

  Calculate confidence:
  - 1.0 if all inputs present and thresholds clearly met
  - 0.8 if estimated_value is null (use incident_type as proxy)
  - 0.6 if both value and injury are null

  Determine escalation_needed:
  - True if severity IN [HIGH, CRITICAL]
  - True if confidence < 0.7
  - False otherwise

Return TriageResult(severity, confidence, escalation_needed, reasoning).

Use thresholds from config.py (SEVERITY_THRESHOLDS_LOW, HIGH, CRITICAL).
```

**Test it:**
```python
# tests/unit/test_triage.py
@pytest.mark.parametrize("value,injury,expected_severity", [
    (3000, "NONE", "LOW"),
    (4999.99, "NONE", "LOW"),
    (5000.00, "NONE", "MEDIUM"),
    (12000, "MINOR", "MEDIUM"),
    (55000, "NONE", "HIGH"),
    (8000, "SERIOUS", "HIGH"),
    (120000, "NONE", "CRITICAL"),
])
def test_severity_classification(value, injury, expected_severity):
    service = TriageService()
    result = service.classify_severity(
        estimated_value=value,
        injury_severity=injury,
        policy_type="STANDARD",
        incident_type="AUTO_COLLISION_SINGLE",
        exclusion_flags=False,
        vip_status=False
    )
    assert result.severity == expected_severity
```

---

### 2.4: Validation Service (Day 8-10)

**Goal:** Validate policy coverage via SOAP API

**Reference:** Specification/03_Agent_specification.md, Section 3, Integration 2

**Files to create:**
- `src/integrations/policy_soap_client.py` (SOAP client)
- `src/services/validation_service.py` (validation logic)

**Prompt for Claude Code:**
```
Read Specification/03_Agent_specification.md, Section 3, Integration 2: Policy Administration System.

Create two files:

1. src/integrations/policy_soap_client.py with class PolicySOAPClient:
   - Use zeep library for SOAP calls
   - Method: get_policy_coverage(policy_number, incident_date) -> PolicyResponse
   - Handle: timeouts (8s), retries (2 with exponential backoff), SOAP faults
   - Support mock mode (config.MOCK_POLICY_SOAP == True)

2. src/services/validation_service.py with class ValidationService:
   - Method: validate_policy(claim: Claim) -> ValidationResult
   - Steps:
     a. Check policy status (ACTIVE)
     b. Check incident date within coverage period
     c. Check coverage type matches incident type
     d. Check exclusions
   - Return: ValidationResult(status: VALIDATED|REJECTED|ESCALATED, reason)

Use config.py for SOAP endpoint, credentials, timeout.
Include comprehensive error handling and logging.
```

---

### 2.5: Routing Service (Day 11-12)

**Goal:** Assign claims to appropriate adjusters

**Reference:** Specification/03_Agent_specification.md, Section 4, Decision 4

**Files to create:**
- `src/integrations/crm_client.py` (CRM API client)
- `src/services/routing_service.py` (routing logic)

**Logic:**
1. Determine required specialty from incident_type
2. Filter adjusters by: specialty, seniority (HIGH/CRITICAL needs SENIOR+), capacity
3. Select adjuster with lowest workload
4. Assign via CRM API
5. Return routing result with confidence

---

### 2.6: Notification Service (Day 13)

**Goal:** Send acknowledgment emails/SMS to claimants

**Reference:** Specification/03_Agent_specification.md, Section 3, Integration 4

**Files to create:**
- `src/integrations/notification_client.py`
- `src/services/notification_service.py`

**Logic:**
1. Prepare notification (template + variables)
2. Send via notification API
3. Handle retries (3 attempts)
4. Return success/failure

---

## Phase 3: End-to-End Integration (Week 4)

### 3.1: Claims API Endpoint (Day 1-2)

**File to create:** `src/api/claims.py`

**Endpoints:**
- `POST /api/v1/claims/fnol` - Submit new FNOL claim
- `GET /api/v1/claims/{claim_id}` - Get claim status
- `GET /api/v1/claims` - List claims (with filters)

**Workflow in POST /fnol:**
```python
1. Receive raw FNOL data
2. Create Claim record (status=RECEIVED)
3. extraction_service.extract()
4. If confidence < 0.7: escalate, return
5. triage_service.classify_severity()
6. If severity HIGH/CRITICAL: escalate, return
7. validation_service.validate_policy()
8. If validation fails: reject or escalate, return
9. routing_service.route_to_adjuster()
10. notification_service.send_acknowledgment()
11. Update claim status to ACKNOWLEDGED
12. Return claim details
```

---

### 3.2: Integration Tests (Day 3-4)

**Files to create:**
- `tests/integration/test_claim_flow.py`
- `tests/integration/test_crm_api.py`
- `tests/integration/test_policy_soap.py`

**Test scenarios:**
- LOW severity claim (end-to-end, no escalation)
- MEDIUM severity claim (with oversight flag)
- HIGH severity claim (escalated, no routing)
- Policy validation failure
- SOAP timeout and retry

---

### 3.3: Monitoring & Metrics (Day 5)

**File to create:** `src/utils/metrics.py`

**Metrics to track:**
- Claims processed (counter)
- Claims by severity (gauge)
- SLA compliance rate (gauge)
- Extraction confidence average (gauge)
- Routing accuracy rate (gauge)
- API response times (histogram)

Expose at `/metrics` endpoint (Prometheus format).

---

## Phase 4: Testing & Documentation (Week 5)

### 4.1: Comprehensive Test Suite

**Coverage targets:**
- Unit tests: >85% coverage
- Integration tests: All external APIs mocked
- E2E tests: 10 critical scenarios from Validation Design

**Run:**
```bash
pytest --cov=src --cov-report=html
# View: htmlcov/index.html
```

---

### 4.2: Load Testing

**Tool:** Locust or k6

**Scenario:** Simulate 300 claims/day (burst of 50 claims/hour during peak)

**Measure:**
- Average processing time (target: <60s)
- SLA compliance (target: >95%)
- Error rate (target: <1%)

---

### 4.3: Documentation

**Create:**
- `docs/api_guide.md` - API usage examples
- `docs/architecture.md` - System architecture diagrams
- `docs/deployment.md` - Deployment instructions
- `docs/monitoring.md` - Monitoring and alerting setup

---

## Phase 5: Pilot & Production (Week 6+)

### 5.1: Deploy to Staging

1. Setup staging MySQL database
2. Configure .env with staging credentials
3. Deploy application
4. Run E2E tests against staging
5. Smoke test with 10 test claims

---

### 5.2: Pilot (10% Traffic)

**Duration:** 2 weeks

**Metrics to track:**
- SLA compliance: target >90%
- Routing accuracy: target >90%
- Specialist override rate: target <15%
- Claimant satisfaction: no degradation

**Go/No-Go Criteria:**
- If all metrics met: proceed to full rollout
- If any metric fails: iterate, fix, re-pilot

---

### 5.3: Production Rollout

**Phased approach:**
- Week 1: 10% traffic
- Week 2: 25% traffic
- Week 3: 50% traffic
- Week 4: 75% traffic
- Week 5: 100% traffic

Monitor at each phase. Rollback if issues detected.

---

## Current Status

**You are here:** ✅ Phase 1 Complete

**Next immediate steps:**
1. Set up local environment (QUICKSTART.md)
2. Start Phase 2: Build database models
3. Then build extraction service

**Estimated timeline:**
- Phase 2 (Core Services): 2-3 weeks
- Phase 3 (Integration): 1 week
- Phase 4 (Testing): 1 week
- **Total to pilot-ready: 4-5 weeks**

---

## Decision Points

**Before Phase 2.2 (Extraction Service):**
- [ ] Decide: Use real OpenAI API or mock NLP for development?
- [ ] If real API: Obtain OpenAI API key, test API access
- [ ] If mock: Ensure mock provides realistic extraction results

**Before Phase 3 (Integration):**
- [ ] Decide: Build with all mocks first, or integrate with real systems incrementally?
- [ ] If real systems: Obtain test environment credentials for CRM, SOAP, Notification
- [ ] If mocks: Plan when to swap mocks for real integrations (staging? production?)

**Before Phase 5 (Pilot):**
- [ ] Get stakeholder approval for pilot (claims director, ops manager)
- [ ] Define success criteria with client
- [ ] Establish feedback loop with specialists

---

## Resources

- **Specifications:** `Specification/` directory (your design docs)
- **Quick Start:** `QUICKSTART.md` (get running in 15 min)
- **This Roadmap:** `DEVELOPMENT_ROADMAP.md` (where you are now)
- **README:** `README.md` (full project overview)

---

**Ready to build?** Start with QUICKSTART.md to set up your environment!
