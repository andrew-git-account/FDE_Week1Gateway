# Validation Design
## FNOL Claims Processing Agent - Testing & Quality Assurance

---

## 1. Validation Objectives

### What We Are Validating
1. **Functional Correctness**: Agent makes correct decisions (extraction, triage, routing)
2. **Delegation Boundaries**: Agent escalates when required (HIGH/CRITICAL, low confidence, exclusions)
3. **Integration Reliability**: External API calls handled correctly (retries, fallbacks, errors)
4. **SLA Compliance**: Claims acknowledged within 5 minutes (95th percentile)
5. **Data Quality**: Audit trail complete, PII protected, state transitions valid
6. **Failure Handling**: Agent degrades gracefully when systems fail

### Success Criteria (Quantitative)
- **Extraction accuracy**: >85% of fields extracted with confidence ≥0.7
- **Triage accuracy**: >90% severity classifications match specialist review
- **Routing accuracy**: >95% of claims routed to correct adjuster specialty
- **SLA compliance**: >95% of claims acknowledged within 5 minutes
- **Escalation rate**: 25-35% of claims escalated (aligned with delegation model: 5% HIGH/CRITICAL, 20% flagged issues, 10% low confidence)
- **Integration resilience**: 100% of claims processed or escalated (no lost claims) despite integration failures
- **Audit completeness**: 100% of claims have complete audit trail

---

## 2. Happy Path Scenarios

### Scenario 1: LOW Severity Claim - Fully Agentic Processing

**Input (Web Form - Structured):**
```json
{
  "claimant": {
    "first_name": "John",
    "last_name": "Smith",
    "email": "john.smith@email.com",
    "phone": "555-123-4567",
    "policy_number": "POL-12345678"
  },
  "incident": {
    "date": "2026-04-26",
    "type": "Windshield damage",
    "description": "A rock hit my windshield on Highway 101 and caused a 6-inch crack. No other damage to the vehicle. Car is drivable.",
    "estimated_value": "$450",
    "injury": "No"
  },
  "source_channel": "WEB_FORM",
  "received_at": "2026-04-26T09:03:12Z"
}
```

**Agent Processing Steps:**

**Step 1: Data Extraction**
- Input: Structured web form
- Extraction method: Direct field mapping (no NLP needed)
- Extracted fields:
  - `claimant_name`: "John Smith" (confidence: 1.0)
  - `policy_number`: "POL-12345678" (confidence: 1.0)
  - `incident_date`: 2026-04-26 (confidence: 1.0)
  - `incident_type`: WINDSHIELD_REPLACEMENT (confidence: 1.0)
  - `estimated_value`: 450.00 (confidence: 1.0)
  - `injury_severity`: NONE (confidence: 1.0)
- Overall confidence: 1.0
- Status: RECEIVED → EXTRACTED
- Time: 2 seconds

**Step 2: Severity Triage**
- Input: estimated_value = $450, injury = NONE, policy_type = STANDARD
- Logic applied:
  - estimated_value < $5,000 ✓
  - injury_severity = NONE ✓
  - incident_type = WINDSHIELD_REPLACEMENT (routine) ✓
- Severity assigned: LOW
- Confidence: 1.0
- Escalation needed: NO (fully agentic per delegation model)
- Status: EXTRACTED → TRIAGED
- Time: 1 second

**Step 3: Policy Validation**
- Query: Policy SOAP API with POL-12345678, incident_date 2026-04-26
- Response: 
  - PolicyStatus: ACTIVE
  - CoverageTypes: [AUTO_COMPREHENSIVE, AUTO_LIABILITY]
  - CoverageLimit: $50,000
  - Deductible: $500
  - Exclusions: [] (none)
- Validation checks:
  - Policy active on incident date? YES ✓
  - Coverage includes AUTO_COMPREHENSIVE? YES ✓
  - Estimated value ($450) < coverage limit? YES ✓
  - Exclusions present? NO ✓
- Result: VALIDATED
- Status: TRIAGED → VALIDATED
- Time: 3 seconds (SOAP call)

**Step 4: Adjuster Routing**
- Query: CRM API for available adjusters
  - Specialty: AUTO
  - Seniority: Any (LOW severity)
  - Has capacity: TRUE
- Candidates found: 5 adjusters
- Selected: Adjuster ADJ-0789 (Sarah Johnson)
  - Specialty: AUTO
  - Workload: 8/15 (lowest among candidates)
  - Seniority: INTERMEDIATE
- Assignment API call: Success (200 OK)
- Routing confidence: 1.0
- Status: VALIDATED → ROUTED
- Time: 2 seconds

**Step 5: Claimant Acknowledgment**
- Notification request:
  - Channel: EMAIL
  - Recipient: john.smith@email.com
  - Template: FNOL_ACKNOWLEDGMENT_V2
  - Variables: {claim_number: "CLM-20260426-0123", adjuster_name: "Sarah Johnson", severity: "LOW"}
- Notification service response: SENT (200 OK)
- Email delivered at: 2026-04-26T09:03:32Z
- Status: ROUTED → ACKNOWLEDGED
- Time: 2 seconds

**Total Processing Time:** 10 seconds  
**SLA Performance:** Acknowledged within 20 seconds (target: <5 minutes) ✓

**Expected Final State:**
```json
{
  "claim_id": "uuid-123",
  "claim_number": "CLM-20260426-0123",
  "status": "ACKNOWLEDGED",
  "severity": "LOW",
  "assigned_adjuster_id": "ADJ-0789",
  "sla_deadline": "2026-04-26T11:03:12Z",
  "acknowledged_at": "2026-04-26T09:03:32Z",
  "sla_breach": false,
  "escalation_needed": false,
  "audit_log": [
    {"timestamp": "09:03:12Z", "from": null, "to": "RECEIVED", "by": "AGENT"},
    {"timestamp": "09:03:14Z", "from": "RECEIVED", "to": "EXTRACTED", "by": "AGENT", "confidence": 1.0},
    {"timestamp": "09:03:15Z", "from": "EXTRACTED", "to": "TRIAGED", "by": "AGENT", "severity": "LOW"},
    {"timestamp": "09:03:18Z", "from": "TRIAGED", "to": "VALIDATED", "by": "AGENT"},
    {"timestamp": "09:03:20Z", "from": "VALIDATED", "to": "ROUTED", "by": "AGENT", "adjuster": "ADJ-0789"},
    {"timestamp": "09:03:22Z", "from": "ROUTED", "to": "ACKNOWLEDGED", "by": "AGENT"}
  ]
}
```

**Validation Checks:**
- ✓ All state transitions valid (no skipped states)
- ✓ No escalations (correct for LOW severity)
- ✓ Audit trail complete (6 entries)
- ✓ SLA met (acknowledged in 20 seconds)
- ✓ Correct adjuster specialty (AUTO)
- ✓ Claimant notified (email sent)

---

### Scenario 2: MEDIUM Severity Claim - Agent-Led with Oversight

**Input (Email - Unstructured):**
```
From: michael.jones@email.com
Subject: Car Accident Claim

Hi, I need to file a claim. I was in a car accident yesterday (April 25th) 
on Main Street. Another driver rear-ended me at a stoplight. My car has 
significant damage to the rear bumper, trunk, and taillights. I got an 
estimate from a body shop for about $12,000. I have a sore neck but didn't 
go to the hospital. My policy number is POL-87654321.

Thanks,
Michael Jones
Phone: 555-987-6543
```

**Agent Processing Steps:**

**Step 1: Data Extraction (NLP)**
- Input: Unstructured email text
- NLP extraction results:
  - `claimant_name`: "Michael Jones" (confidence: 0.95)
  - `policy_number`: "POL-87654321" (confidence: 1.0, exact match)
  - `incident_date`: 2026-04-25 (confidence: 0.9, inferred from "yesterday")
  - `incident_type`: AUTO_COLLISION_MULTI (confidence: 0.85, "rear-ended" implies multi-vehicle)
  - `estimated_value`: 12000.00 (confidence: 0.9, "$12,000" extracted)
  - `injury_severity`: MINOR (confidence: 0.7, "sore neck but didn't go to hospital")
- Overall confidence: 0.7 (minimum of all fields)
- Low confidence fields: ["injury_severity"] (0.7 is at threshold)
- Status: RECEIVED → EXTRACTED
- Time: 15 seconds (NLP processing)

**Step 2: Severity Triage**
- Input: estimated_value = $12,000, injury = MINOR, policy_type = STANDARD
- Logic applied:
  - estimated_value ($12,000) is between $5K-$50K ✓
  - injury_severity = MINOR ✓
  - incident_type = AUTO_COLLISION_MULTI ✓
- Severity assigned: MEDIUM
- Confidence: 0.85 (injury extraction at threshold reduces confidence)
- Escalation needed: NO (but specialist oversight per delegation model)
- Oversight flag: TRUE (specialist reviews within 30 minutes)
- Status: EXTRACTED → TRIAGED
- Time: 2 seconds

**Step 3: Policy Validation**
- (Same process as Scenario 1, assume ACTIVE policy with coverage)
- Result: VALIDATED
- Status: TRIAGED → VALIDATED
- Time: 3 seconds

**Step 4: Adjuster Routing**
- Required specialty: AUTO
- Seniority: Any (MEDIUM allows intermediate)
- Selected: Adjuster ADJ-0456 (Tom Wilson, workload: 10/15)
- Routing confidence: 0.95
- Status: VALIDATED → ROUTED
- Time: 2 seconds

**Step 5: Claimant Acknowledgment**
- Email sent successfully
- Status: ROUTED → ACKNOWLEDGED
- Time: 2 seconds

**Step 6: Specialist Oversight (Asynchronous)**
- Specialist Lisa Chen reviews triage within 30 minutes
- Reviews: extraction (sore neck = MINOR?), severity (MEDIUM correct?)
- Decision: APPROVED (severity MEDIUM is appropriate, injury is minor, value fits)
- No adjustment needed
- Oversight_reviewed_at: 2026-04-26T09:28:00Z

**Total Processing Time:** 24 seconds (agent), +25 minutes (specialist review)  
**SLA Performance:** Acknowledged within 24 seconds ✓

**Validation Checks:**
- ✓ Extraction confidence at threshold (0.7) but not escalated (acceptable)
- ✓ MEDIUM severity triggers oversight (per delegation model)
- ✓ Specialist reviews within 30 minutes
- ✓ Severity classification correct (specialist confirms)
- ✓ SLA met

---

### Scenario 3: HIGH Severity Claim - Human-Led with Agent Support

**Input (Phone Transcript):**
```
Transcript from call received 2026-04-26 08:45:00

Operator: "Claims department, how can I help you?"

Caller: "Hi, I need to report a serious accident. My name is Emily Rodriguez. 
Yesterday my husband was driving our car and was hit by a truck that ran a 
red light. He was taken to the hospital by ambulance with a head injury. 
He's still in the ICU. The car is completely totaled. The police said the 
other driver was at fault."

Operator: "I'm very sorry to hear that. Can you provide your policy number?"

Caller: "Yes, it's POL-11223344. We have the premium coverage."

Operator: "Thank you. Do you have an estimate for the vehicle damage?"

Caller: "The car is totaled. It was a 2024 SUV worth about $55,000. But I'm 
more worried about my husband right now."

Operator: "Of course. I'll submit this claim immediately and a senior adjuster 
will contact you within an hour. Is your callback number 555-234-5678?"

Caller: "Yes, that's correct."
```

**Agent Processing Steps:**

**Step 1: Data Extraction (NLP from Transcript)**
- NLP extraction results:
  - `claimant_name`: "Emily Rodriguez" (confidence: 1.0)
  - `policy_number`: "POL-11223344" (confidence: 1.0)
  - `incident_date`: 2026-04-25 (confidence: 0.9, "yesterday")
  - `incident_type`: AUTO_COLLISION_MULTI (confidence: 1.0, "hit by a truck")
  - `estimated_value`: 55000.00 (confidence: 0.95, "totaled SUV worth $55,000")
  - `injury_severity`: SERIOUS (confidence: 0.95, "head injury", "ICU", "ambulance")
- Overall confidence: 0.9
- Status: RECEIVED → EXTRACTED
- Time: 20 seconds

**Step 2: Severity Triage (Agent Detects HIGH)**
- Input: estimated_value = $55,000, injury = SERIOUS, incident complexity = multi-party with injury
- Logic applied:
  - estimated_value > $50,000 ✓ (triggers HIGH)
  - injury_severity = SERIOUS ✓ (triggers HIGH)
- Severity detected: HIGH
- **Agent does NOT assign severity** (human-led per delegation model)
- Escalation needed: YES (mandatory for HIGH)
- Status: EXTRACTED → ESCALATED (NOT TRIAGED autonomously)
- Escalation reason: "High-value claim with serious injury. Estimated value: $55,000, Injury: SERIOUS (ICU admission). Requires specialist triage and senior adjuster assignment."
- Time: 2 seconds

**Step 3: Agent Gathers Supporting Data (Agent Support Role)**
- Query policy system: POL-11223344
  - PolicyStatus: ACTIVE
  - PolicyType: HIGH_VALUE (premium coverage)
  - CoverageLimit: $100,000
  - Exclusions: [] (none)
- Query available senior adjusters:
  - Specialty: AUTO + INJURY (multi-specialty needed)
  - Seniority: SENIOR or PRINCIPAL
  - Available: 2 candidates (ADJ-0234 Sarah Lee - SENIOR, ADJ-0567 James Park - PRINCIPAL)
- Agent prepares data package for specialist:
  - Extracted incident details
  - Policy summary
  - Recommended adjuster: ADJ-0567 (PRINCIPAL, specialty: AUTO+INJURY, workload: 5/12)
- Time: 5 seconds

**Step 4: Specialist Review (Human-Led)**
- Specialist: David Kim (senior claims specialist)
- Receives escalation at: 2026-04-26T08:45:30Z
- Reviews agent's data package
- Confirms severity: HIGH (concurs with agent's detection)
- Confirms policy coverage: ACTIVE, sufficient limits
- Decision: Assign to PRINCIPAL adjuster (James Park) given ICU admission
- Manually sets:
  - Claim.severity = HIGH
  - Claim.assigned_adjuster_id = ADJ-0567
  - Claim.priority = URGENT
- Status: ESCALATED → TRIAGED (by specialist) → VALIDATED (policy checked) → ROUTED (specialist assigns)
- Time: 8 minutes (specialist review + decision)

**Step 5: Claimant Acknowledgment (Agent Resumes)**
- Agent sends acknowledgment:
  - Channel: EMAIL + SMS (HIGH priority, both channels)
  - Template: FNOL_ACKNOWLEDGMENT_HIGH_PRIORITY
  - Variables: {severity: "HIGH", adjuster_name: "James Park - Principal Adjuster", callback_within: "1 hour"}
- Status: ROUTED → ACKNOWLEDGED
- Time: 3 seconds

**Step 6: Adjuster Follow-Up (Manual)**
- Principal adjuster James Park contacts Emily Rodriguez at 09:15:00Z (30 minutes after filing)
- Provides direct support, discusses medical care coordination, rental vehicle, claim process

**Total Processing Time:** 30 seconds (agent detection + data gathering), +8 minutes (specialist triage), +30 minutes (adjuster callback)  
**SLA Performance:** Acknowledged within 8 minutes 33 seconds ✓

**Validation Checks:**
- ✓ Agent correctly detected HIGH severity triggers ($55K value, SERIOUS injury)
- ✓ Agent did NOT autonomously triage (escalated instead, per delegation model)
- ✓ Agent provided supporting data to specialist (policy, adjuster options)
- ✓ Specialist made final triage decision (human-led)
- ✓ PRINCIPAL adjuster assigned (appropriate for serious injury)
- ✓ Urgent priority set
- ✓ SLA met with high-touch service

---

## 3. Edge Cases

### Edge Case 1: Missing Estimated Value

**Scenario:**
Claimant reports incident but doesn't provide damage estimate.

**Input:**
```
"My car was broken into last night. They stole my laptop from the back seat 
and broke the driver's window. Policy: POL-99887766."
```

**NLP Extraction:**
- `incident_type`: THEFT (confidence: 1.0)
- `estimated_value`: NULL (confidence: 0.0, not mentioned)
- `injury_severity`: NONE (confidence: 1.0)

**Agent Behavior:**
- Overall confidence: 0.0 (missing critical field)
- Cannot classify severity without value (is it $200 laptop or $2000 laptop?)
- Status: EXTRACTED → ESCALATED
- Escalation reason: "Unable to determine claim value. Estimated value not provided in report. Specialist must contact claimant for damage assessment."

**Expected Outcome:**
- Specialist contacts claimant: "Can you provide an estimate for the stolen laptop and window repair?"
- Claimant responds: "Laptop was $1,200, window repair quoted at $350, so about $1,550 total"
- Specialist updates claim.estimated_value = 1550.00
- Agent resumes processing: Severity = LOW ($1,550 < $5K)

**Validation Test:**
- Verify agent does NOT guess estimated_value
- Verify status = ESCALATED (not TRIAGED)
- Verify escalation_reason contains "claim value" or "estimated value"
- Verify claim does not proceed to routing without value

---

### Edge Case 2: Claim Value Exactly at Threshold

**Scenario:**
Claim amount is exactly $5,000.00 (boundary between LOW and MEDIUM).

**Input:**
- `estimated_value`: 5000.00
- `injury_severity`: NONE
- `policy_type`: STANDARD
- `incident_type`: AUTO_COLLISION_SINGLE

**Severity Logic (from spec):**
```
MEDIUM if: estimated_value >= 5000 AND estimated_value <= 50000
LOW if: estimated_value < 5000
```

**Agent Behavior:**
- $5,000.00 >= $5,000 → MEDIUM threshold met
- Severity = MEDIUM
- Agent-led with oversight (specialist can review)

**Boundary Test Matrix:**
| Estimated Value | Expected Severity | Reasoning |
|-----------------|-------------------|-----------|
| $4,999.99 | LOW | < $5,000 |
| $5,000.00 | MEDIUM | >= $5,000 |
| $5,000.01 | MEDIUM | >= $5,000 |
| $49,999.99 | MEDIUM | >= $5K and <= $50K |
| $50,000.00 | HIGH | >= $50K |
| $50,000.01 | HIGH | > $50K |

**Validation Test:**
- Test all boundary values in matrix
- Verify consistent classification
- Verify no off-by-one errors
- Verify floating-point precision doesn't cause issues ($5000.00 vs 5000.0000001)

---

### Edge Case 3: Adjuster Goes On Leave During Routing

**Scenario:**
Agent selects adjuster, but adjuster's status changes to ON_LEAVE between selection and assignment API call.

**Agent Processing:**
1. Query available adjusters: Returns ADJ-0123 (status: AVAILABLE, workload: 7/15)
2. Agent selects ADJ-0123
3. **During 500ms between query and assignment**, adjuster's manager marks them ON_LEAVE (emergency)
4. Agent calls CRM API: POST /claims/{id}/assign with adjuster_id = ADJ-0123

**CRM API Response:**
```json
HTTP 422 Unprocessable Entity
{
  "error_code": "ADJUSTER_UNAVAILABLE",
  "message": "Adjuster ADJ-0123 is not available (status: ON_LEAVE)",
  "adjuster_status": "ON_LEAVE"
}
```

**Agent Behavior:**
- Detects 422 error (adjuster unavailable)
- Does NOT fail hard or escalate immediately
- Retry routing logic:
  1. Re-query available adjusters (exclude ADJ-0123)
  2. Select next candidate
  3. Retry assignment
- If retry succeeds: Continue to acknowledgment
- If no other adjusters available: Escalate with reason "All {specialty} adjusters unavailable or at capacity"

**Validation Test:**
- Mock CRM API: First assignment call returns 422, second call returns 200
- Verify agent retries routing (audit log shows 2 routing attempts)
- Verify no escalation if retry succeeds
- Verify claim eventually reaches ROUTED status
- Verify audit trail shows: "Routing attempt 1 failed (adjuster unavailable), retry initiated"

---

### Edge Case 4: Policy Expired After Incident But Before Claim Filing

**Scenario:**
Incident occurred while policy was active, but policy expired before claimant filed claim.

**Input:**
- `incident_date`: 2026-03-15
- `claim_filed_date`: 2026-04-26
- Policy details:
  - `effective_date`: 2025-04-01
  - `expiration_date`: 2026-04-01 (policy expired 25 days before claim filed)
  - `policy_status` (current): EXPIRED

**Policy Validation Logic:**
```
Question: Is this claim covered?

Key check: Was policy ACTIVE on incident_date?
- incident_date (2026-03-15) is between effective_date (2025-04-01) and expiration_date (2026-04-01)? 
  - YES, incident occurred during coverage period

Decision: Claim is COVERED (policy was active when incident occurred)
```

**Agent Behavior:**
- Query policy system with incident_date = 2026-03-15
- Policy system returns: PolicyStatus = ACTIVE (for incident date), but ExpirationDate = 2026-04-01
- Agent detects: Policy expired after incident but coverage applies for incident date
- Validation result: VALIDATED
- Sets validation note: "Policy expired 2026-04-01 (after incident date 2026-03-15). Coverage confirmed for incident."
- Proceeds to routing

**Wrong Behavior (What Agent Must NOT Do):**
- Do NOT reject claim because current policy_status = EXPIRED
- Do NOT use current date for coverage check (must use incident_date)

**Validation Test:**
- Create test claim with incident during coverage, filing after expiration
- Verify status = VALIDATED (not REJECTED)
- Verify policy_validation_result contains note about expiration
- Verify audit log shows correct reasoning

---

### Edge Case 5: Incident Description Conflicts with Extracted Value

**Scenario:**
Claimant describes incident as "minor" but extracted estimated value is very high (potential NLP misread).

**Input:**
```
"Minor fender bender in parking lot. Just a small scratch on my bumper, 
barely noticeable. I got an estimate and it said $15,000 but that seems 
way too high. Car is totally drivable."
```

**NLP Extraction:**
- `incident_description`: "Minor fender bender...small scratch...barely noticable..."
- `estimated_value`: 15000.00 (confidence: 0.6, NLP extracted "$15,000" but context suggests error)
- `incident_type`: AUTO_COLLISION_SINGLE (confidence: 0.9)
- Extraction flags: ["VALUE_CONFLICT: Description says 'minor' and 'small scratch' but extracted value $15,000 is HIGH. Possible OCR/transcription error or claimant uncertainty."]

**Agent Behavior:**
- Overall confidence: 0.6 (below 0.7 threshold)
- Detects conflict between qualitative description (minor, small) and quantitative value ($15K)
- Status: RECEIVED → EXTRACTED → ESCALATED
- Escalation reason: "Conflicting incident details. Description indicates minor damage ('small scratch') but extracted estimate is $15,000. Confidence: 0.6. Specialist review required to confirm actual damage value."

**Specialist Review:**
- Specialist reads full description
- Recognizes likely transcription error: "$15,000" vs "$1,500" (common speech recognition error)
- Contacts claimant: "Did you say $15,000 or $1,500?"
- Claimant: "Oh no, it was $1,500. Fifteen hundred dollars."
- Specialist corrects: estimated_value = 1500.00
- Agent resumes: Severity = LOW

**Validation Test:**
- Prepare 10 test cases with description/value mismatches
- Verify agent flags conflicts (confidence < 0.7)
- Verify escalation triggered
- Verify extraction_flags contains "CONFLICT" or "INCONSISTENT"
- Verify agent doesn't blindly use high value

---

## 4. Failure Modes

### Failure Mode 1: Policy SOAP API Timeout (Obvious Failure)

**Scenario:**
Legacy policy administration system experiences outage during validation.

**Trigger:**
- Agent calls policy SOAP API: `GetPolicyCoverage(POL-12345678, 2026-04-26)`
- SOAP endpoint times out after 8 seconds
- Retry 1 (after 2s delay): timeout again
- Retry 2 (after 4s delay): timeout again
- All retries exhausted

**Agent Behavior:**
1. Detects timeout after 8 seconds
2. Waits 2 seconds, retry attempt 1
3. Timeout again after 8 seconds
4. Waits 4 seconds, retry attempt 2
5. Timeout again after 8 seconds
6. Retry limit exhausted
7. **Agent does NOT fail hard**:
   - Sets Claim.status = ESCALATED
   - Sets escalation_reason = "Policy validation system unavailable. SOAP endpoint timed out after 3 attempts (8s timeout each). Unable to verify coverage. Manual validation required. Error: Connection timeout to policy-admin.company.internal:443"
   - Does NOT send acknowledgment to claimant (cannot confirm coverage)
   - Logs ERROR level: "Integration failure: Policy SOAP API unreachable"
   - Sends alert to operations team (system health monitoring)

**Detection Method:**
- **Immediate**: Operations team receives alert (system integration failure)
- **Dashboard**: Claims stuck in ESCALATED with reason "Policy validation system unavailable"
- **Monitoring**: Integration health check shows SOAP endpoint down

**Recovery:**
1. Operations team investigates SOAP endpoint (database issue, network failure, etc.)
2. Once system recovers, specialist manually validates policy via internal tool
3. Specialist updates claim: status → VALIDATED
4. Agent resumes processing (routing + acknowledgment)

**Validation Test:**
- Mock SOAP endpoint with 10-second delay (exceeds 8s timeout)
- Verify agent attempts exactly 3 calls (initial + 2 retries)
- Verify exponential backoff (2s, 4s delays observed in logs)
- Verify status = ESCALATED after exhaustion
- Verify no acknowledgment sent to claimant
- Verify operations alert triggered
- Verify error log contains timeout details

**Acceptance Criteria:**
- 100% of claims with policy validation failures are escalated (not lost)
- 0% of claims acknowledged without policy validation
- Operations team alerted within 1 minute of failure

---

### Failure Mode 2: Agent Routes to Wrong Adjuster Specialty (Silent Failure)

**Scenario:**
Agent's incident-to-specialty mapping logic has a bug, causing property damage claims to route to auto adjusters.

**Trigger:**
- Incident type: PROPERTY_DAMAGE_STRUCTURAL (requires PROPERTY specialist)
- Agent's specialty mapping (buggy):
  ```python
  # BUG: Missing PROPERTY_* mapping, defaults to AUTO
  if incident_type.startswith("AUTO_"):
      return "AUTO"
  else:
      return "AUTO"  # Wrong default!
  ```
- Agent queries: `GET /adjusters?specialty=AUTO` (should be PROPERTY)
- Finds available AUTO adjuster: ADJ-0123
- Assignment succeeds: `POST /claims/{id}/assign` returns 200 OK
- Adjuster accepts assignment
- Claimant acknowledged
- **Status = ACKNOWLEDGED (looks successful, no error thrown)**

**Actual Problem:**
- AUTO adjuster (Tom Wilson) opens claim at 10:00 AM
- Realizes: "This is structural property damage (roof collapse), not auto collision"
- Manually re-routes to PROPERTY adjuster (Sarah Chen) at 10:30 AM
- Claimant receives callback 30 minutes later than expected
- **Agent is unaware anything went wrong** (no error in its logs)

**Why This Is Silent:**
- No HTTP error (200 OK from all APIs)
- No exception thrown in agent code
- Status progression looks normal (RECEIVED → ... → ACKNOWLEDGED)
- Only human review (adjuster) detects the error

**Detection Method:**

**Method 1: Daily Routing Audit (Batch)**
```sql
-- Run daily at 2 AM
SELECT 
    claim_id,
    claim.incident_type,
    adjuster.specialty AS assigned_specialty,
    CASE 
        WHEN claim.incident_type LIKE 'AUTO_%' AND adjuster.specialty != 'AUTO' THEN 'MISMATCH'
        WHEN claim.incident_type LIKE 'PROPERTY_%' AND adjuster.specialty != 'PROPERTY' THEN 'MISMATCH'
        WHEN claim.incident_type LIKE 'INJURY_%' AND adjuster.specialty != 'INJURY' THEN 'MISMATCH'
        ELSE 'CORRECT'
    END AS routing_accuracy
FROM claims
JOIN adjusters ON claims.assigned_adjuster_id = adjusters.id
WHERE claims.routed_at >= CURRENT_DATE - INTERVAL '1 day'
  AND routing_accuracy = 'MISMATCH'
```

**Alert triggered if:**
- Mismatch rate > 5% in past 24 hours
- Alert sent to: Engineering team + Queue manager
- Alert contains: List of misrouted claims, incident type distribution

**Method 2: Adjuster Feedback (Real-time)**
- CRM provides "Report Routing Error" button on claim view
- Adjuster clicks: "Wrong specialty assigned"
- System logs: `routing_error_feedback` table
- If >10 reports in 1 hour → alert engineering team

**Method 3: Post-Assignment Review (Sample-based)**
- Queue manager reviews 5% random sample of routed claims daily
- Checks: Does adjuster specialty match incident type?
- Tracks accuracy over time (target: >95%)

**Prevention:**
- **Unit tests** for specialty mapping logic:
  ```python
  def test_specialty_mapping():
      assert map_incident_to_specialty("AUTO_COLLISION_SINGLE") == "AUTO"
      assert map_incident_to_specialty("PROPERTY_DAMAGE_STRUCTURAL") == "PROPERTY"
      assert map_incident_to_specialty("INJURY_SERIOUS") == "INJURY"
      # Test all enum values
  ```
- **Integration tests** with mock adjuster API:
  ```python
  def test_property_claim_routes_to_property_adjuster():
      claim = create_test_claim(incident_type="PROPERTY_DAMAGE_STRUCTURAL")
      agent.process(claim)
      assert claim.assigned_adjuster.specialty == "PROPERTY"
  ```
- **Daily automated audit** (as described above)
- **Weekly review of adjuster overrides** to identify patterns

**Validation Test:**
- Inject incorrect specialty mapping (e.g., PROPERTY → AUTO)
- Process 100 test claims with PROPERTY_* incident types
- Run daily audit query
- Verify audit detects >95 misroutes
- Verify alert triggered
- Verify detection within 24 hours

**Acceptance Criteria:**
- Routing accuracy >95% (measured by daily audit)
- Silent failures detected within 24 hours (batch audit)
- Adjuster feedback mechanism available in CRM UI

---

### Failure Mode 3: Agent Under-Triages HIGH Severity Claim as MEDIUM (Silent Failure)

**Scenario:**
NLP extraction misclassifies serious injury as minor, causing agent to assign incorrect severity.

**Trigger:**
- Incident description: "Rear-ended at high speed. I went to the emergency room with severe neck pain and headaches. Doctor said possible whiplash. Car is badly damaged, estimate around $8,000."
- NLP extraction:
  - `injury_severity`: MINOR (confidence: 0.75)
  - Reasoning: NLP saw "neck pain" but didn't weight "severe", "emergency room", "whiplash" heavily enough
  - `estimated_value`: 8000.00 (confidence: 0.9)
- Agent severity logic:
  - estimated_value ($8K) → MEDIUM range ($5K-$50K)
  - injury_severity = MINOR → does not trigger HIGH
  - **Severity assigned: MEDIUM**
- Agent routes to intermediate adjuster (not senior)
- Status: ACKNOWLEDGED (looks successful)

**Actual Problem:**
- ER visit + whiplash diagnosis = SERIOUS injury (not MINOR)
- Should have been HIGH severity → human-led triage → senior adjuster
- Intermediate adjuster (Tom Wilson) is less experienced with injury claims
- Adjuster recognizes severity during review: "This needs a senior adjuster"
- Manually escalates to senior adjuster at 11:00 AM (1 hour after filing)
- Claimant experience: delay, handoff to second adjuster

**Why This Is Silent:**
- Agent completed all steps (no error)
- All integrations succeeded (200 OK responses)
- Claimant was acknowledged within SLA
- Only specialist review catches under-triage

**Detection Method:**

**Method 1: Adjuster Override Tracking**
```sql
-- Track when adjusters manually change severity
CREATE TABLE severity_overrides (
    claim_id UUID,
    original_severity VARCHAR,
    overridden_severity VARCHAR,
    overridden_by VARCHAR,
    overridden_at TIMESTAMP,
    reason TEXT
);

-- Daily query: What's the override rate?
SELECT 
    original_severity,
    overridden_severity,
    COUNT(*) as override_count,
    (COUNT(*) * 100.0 / total_triaged.count) as override_rate
FROM severity_overrides
JOIN (
    SELECT COUNT(*) as count 
    FROM claims 
    WHERE triaged_at >= CURRENT_DATE - INTERVAL '1 day'
) total_triaged
WHERE overridden_at >= CURRENT_DATE - INTERVAL '1 day'
GROUP BY original_severity, overridden_severity, total_triaged.count
```

**Alert triggered if:**
- MEDIUM → HIGH override rate >10% in past 7 days
- Alert: "Agent may be under-triaging injury claims. Review NLP injury classification."

**Method 2: Keyword Re-Analysis (Batch)**
- Weekly job: Re-process incident descriptions with updated NLP model
- Compare: Original extraction vs new extraction
- Flag discrepancies: "Original: MINOR, New: SERIOUS"
- Review flagged claims for patterns (which keywords were missed?)

**Method 3: Claimant Satisfaction Survey**
- 7 days after claim filed: Email survey
- Question: "Were you assigned to the right specialist for your claim?"
- If satisfaction score <3/5 and claim had injury: Flag for review
- Correlate low scores with severity classification accuracy

**Prevention:**
- **Improve NLP training** on injury keywords:
  - "emergency room", "ER", "hospital", "ambulance" → SERIOUS
  - "severe", "excruciating", "unbearable" → SERIOUS
  - "whiplash", "concussion", "fracture" → SERIOUS
- **Add confidence threshold for injury extraction**:
  ```python
  if "emergency room" in description or "ER" in description:
      if injury_severity == "MINOR":
          # Flag conflict: ER visit but minor injury?
          confidence = 0.6  # Force escalation
  ```
- **Weekly review of adjuster overrides**:
  - Engineering team reviews severity_overrides table
  - Identifies patterns: "10 claims with 'ER' were triaged MEDIUM but overridden to HIGH"
  - Updates NLP model or severity rules

**Validation Test:**
- Prepare 20 test descriptions with serious injury language:
  - "went to emergency room"
  - "ambulance took me to hospital"
  - "doctor diagnosed whiplash"
  - "severe head injury"
- Process through agent
- Compare agent severity to human specialist triage
- Measure accuracy:
  - Target: >90% match on HIGH severity claims
  - Failure: Agent triages HIGH as MEDIUM >10% of time
- Identify false negatives (missed HIGH claims)

**Acceptance Criteria:**
- Severity classification accuracy >90% (measured by adjuster override rate)
- MEDIUM → HIGH override rate <10%
- Weekly NLP model updates based on override patterns
- Adjuster override mechanism available in CRM UI

---

## 5. Automated Validation Framework

### 5.1 Testing Pyramid

Our validation strategy follows the testing pyramid: many fast unit tests, fewer integration tests, and critical end-to-end tests.

```
                  /\
                 /  \
                / E2E \          10 scenarios (critical paths)
               /--------\
              /          \
             / Integration \     50 scenarios (API contracts)
            /--------------\
           /                \
          /   Unit Tests     \   200+ tests (decision logic)
         /____________________\
```

**Level 1: Unit Tests (Fast, Isolated)**
- **Quantity:** 200+ tests
- **Scope:** Individual functions, decision logic, data transformations
- **Execution:** <5 seconds total, run on every commit
- **Examples:**
  - Severity classification logic: Test all combinations of (value, injury, policy_type)
  - Data extraction confidence scoring: Test edge cases (missing fields, null values)
  - Policy validation rules: Test active/expired, coverage matching, exclusions
  - Adjuster routing algorithm: Test filtering, load balancing, specialty matching

**Level 2: Integration Tests (Mock External Systems)**
- **Quantity:** 50 scenarios
- **Scope:** Agent interactions with external APIs (CRM, SOAP, Notification), state transitions
- **Execution:** ~2 minutes total, run on every pull request
- **Examples:**
  - CRM API: Mock responses (200, 400, 500, timeout), verify retry logic
  - Policy SOAP: Mock SOAP envelopes, verify request format, test fault handling
  - Notification service: Mock delivery success/failure, verify acknowledgment logic
  - State machine: Test all valid transitions, verify invalid transitions are blocked

**Level 3: End-to-End Tests (Real or Staging Systems)**
- **Quantity:** 10 critical scenarios
- **Scope:** Full claim processing from ingestion to acknowledgment
- **Execution:** ~5 minutes total, run before deployment
- **Examples:**
  - Happy path: LOW, MEDIUM, HIGH severity claims
  - Edge cases: Missing data, boundary values, policy expired
  - Failure modes: Integration timeout, routing failure, notification failure

---

### 5.2 Test Data Strategy

#### Golden Dataset (Regression Test Suite)
Curated set of test claims with known-good outcomes.

**Structure:**
```
/test_data/
  /golden_claims/
    low_severity_001.json       # Windshield crack, $450
    low_severity_002.json       # Minor scratch, $1,200
    medium_severity_001.json    # Rear-end collision, $12,000
    medium_severity_002.json    # Property damage, $8,500
    high_severity_001.json      # Serious injury + totaled car, $55,000
    high_severity_002.json      # Multi-party liability, $85,000
    edge_case_missing_value.json
    edge_case_policy_expired.json
    failure_mode_soap_timeout.json
```

**Each test file contains:**
```json
{
  "test_id": "low_severity_001",
  "test_name": "Windshield crack - fully agentic",
  "input": {
    "raw_content": "...",
    "source_channel": "WEB_FORM",
    "claimant_email": "test@example.com",
    ...
  },
  "expected_output": {
    "status": "ACKNOWLEDGED",
    "severity": "LOW",
    "escalation_needed": false,
    "assigned_adjuster_specialty": "AUTO",
    "acknowledged_within_seconds": 60,
    "audit_log_entry_count": 6
  },
  "assertions": [
    {"field": "status", "operator": "equals", "value": "ACKNOWLEDGED"},
    {"field": "severity", "operator": "equals", "value": "LOW"},
    {"field": "sla_breach", "operator": "equals", "value": false},
    {"field": "audit_log", "operator": "length_gte", "value": 6}
  ]
}
```

**Golden Dataset Maintenance:**
- Updated when: Agent logic changes, new edge cases discovered, production issues found
- Version controlled: Git repository, tagged with agent version
- Review cadence: Monthly review by engineering + claims team

#### Synthetic Data Generation
For volume testing and coverage of long-tail scenarios.

**Generator Script:**
```python
# /tests/synthetic_claim_generator.py

def generate_claim(severity="LOW", with_injury=False, policy_expired=False):
    """
    Generate synthetic FNOL claim for testing.
    
    Args:
        severity: Target severity (LOW, MEDIUM, HIGH, CRITICAL)
        with_injury: Include injury details
        policy_expired: Set policy expiration before incident
    
    Returns:
        dict: Synthetic claim JSON
    """
    claim = {
        "claimant": fake_claimant(),
        "policy_number": fake_policy_number(),
        "incident": fake_incident(
            severity=severity,
            include_injury=with_injury
        ),
        "incident_date": fake_recent_date()
    }
    
    if policy_expired:
        claim["policy_expiration"] = claim["incident_date"] - timedelta(days=30)
    
    return claim

# Generate 1000 claims for load testing
load_test_claims = [generate_claim(severity=random.choice(["LOW", "MEDIUM", "HIGH"])) 
                     for _ in range(1000)]
```

**Use cases:**
- Load testing: 1000 claims to test 300/day throughput
- Fuzzing: Random variations to find edge cases
- Boundary testing: Generate claims at exact thresholds ($4999.99, $5000.00, $5000.01)

---

### 5.3 Regression Test Suite

#### Test Categories

**Category A: Core Decision Logic (Unit Level)**
```python
# tests/unit/test_severity_classification.py

class TestSeverityClassification:
    def test_low_severity_no_injury_low_value(self):
        result = classify_severity(
            estimated_value=3000,
            injury_severity="NONE",
            policy_type="STANDARD"
        )
        assert result.severity == "LOW"
        assert result.confidence == 1.0
        assert result.escalation_needed == False
    
    def test_boundary_5000_exact(self):
        # $5,000 exactly should be MEDIUM
        result = classify_severity(
            estimated_value=5000.00,
            injury_severity="NONE",
            policy_type="STANDARD"
        )
        assert result.severity == "MEDIUM"
    
    def test_high_severity_serious_injury(self):
        result = classify_severity(
            estimated_value=15000,
            injury_severity="SERIOUS",
            policy_type="STANDARD"
        )
        assert result.severity == "HIGH"
        assert result.escalation_needed == True  # Must escalate
    
    def test_missing_value_escalates(self):
        result = classify_severity(
            estimated_value=None,
            injury_severity=None,
            policy_type="STANDARD"
        )
        assert result.severity == "MEDIUM"  # Default
        assert result.confidence < 0.7
        assert result.escalation_needed == True
```

**Category B: Integration Contracts (Integration Level)**
```python
# tests/integration/test_policy_soap_api.py

@pytest.fixture
def mock_soap_server():
    """Mock SOAP endpoint with controllable responses."""
    with responses.RequestsMock() as rsps:
        yield rsps

class TestPolicySoapIntegration:
    def test_active_policy_returns_coverage(self, mock_soap_server):
        # Mock SOAP response
        mock_soap_server.add(
            responses.POST,
            "https://policy-admin.company.internal/soap/PolicyService",
            body=SOAP_RESPONSE_ACTIVE_POLICY,
            status=200,
            content_type="text/xml"
        )
        
        result = validate_policy("POL-12345678", date(2026, 4, 26))
        
        assert result.status == "VALIDATED"
        assert result.policy_status == "ACTIVE"
        assert "AUTO_COMPREHENSIVE" in result.coverage_types
    
    def test_soap_timeout_escalates_after_retries(self, mock_soap_server):
        # Mock timeout (no response)
        mock_soap_server.add(
            responses.POST,
            "https://policy-admin.company.internal/soap/PolicyService",
            body=responses.ConnectionError("Connection timeout")
        )
        
        result = validate_policy("POL-12345678", date(2026, 4, 26))
        
        # Verify 3 attempts (initial + 2 retries)
        assert len(mock_soap_server.calls) == 3
        assert result.status == "ESCALATED"
        assert "policy system unavailable" in result.escalation_reason.lower()
    
    def test_policy_not_found_does_not_retry(self, mock_soap_server):
        # Mock SOAP Fault: PolicyNotFound
        mock_soap_server.add(
            responses.POST,
            "https://policy-admin.company.internal/soap/PolicyService",
            body=SOAP_FAULT_POLICY_NOT_FOUND,
            status=500,
            content_type="text/xml"
        )
        
        result = validate_policy("POL-99999999", date(2026, 4, 26))
        
        # Verify NO retries (policy doesn't exist)
        assert len(mock_soap_server.calls) == 1
        assert result.status == "ESCALATED"
        assert "policy not found" in result.escalation_reason.lower()
```

**Category C: End-to-End Scenarios (E2E Level)**
```python
# tests/e2e/test_claim_processing.py

class TestClaimProcessingE2E:
    @pytest.fixture(autouse=True)
    def setup_test_environment(self):
        """Set up test database, mock external services."""
        self.db = TestDatabase()
        self.mock_crm = MockCRMService()
        self.mock_policy_system = MockPolicySOAPService()
        self.mock_notifications = MockNotificationService()
        
        yield
        
        self.db.cleanup()
    
    def test_low_severity_claim_fully_agentic(self):
        # Given: Web form claim with windshield damage
        claim_input = load_golden_test("low_severity_001.json")
        
        # When: Agent processes claim
        result = agent.process_claim(claim_input)
        
        # Then: Claim acknowledged without escalation
        assert result.status == "ACKNOWLEDGED"
        assert result.severity == "LOW"
        assert result.escalation_needed == False
        assert result.assigned_adjuster.specialty == "AUTO"
        assert result.sla_breach == False
        
        # Verify audit trail
        audit_log = self.db.get_audit_log(result.claim_id)
        assert len(audit_log) == 6  # All 6 state transitions
        assert audit_log[-1].to_status == "ACKNOWLEDGED"
        
        # Verify claimant notified
        notifications = self.mock_notifications.get_sent()
        assert len(notifications) == 1
        assert notifications[0].recipient == claim_input["claimant_email"]
    
    def test_high_severity_claim_requires_specialist(self):
        # Given: Phone transcript with serious injury
        claim_input = load_golden_test("high_severity_001.json")
        
        # When: Agent processes claim
        result = agent.process_claim(claim_input)
        
        # Then: Claim escalated, NOT autonomously triaged
        assert result.status == "ESCALATED"
        assert result.escalation_needed == True
        assert "serious injury" in result.escalation_reason.lower()
        assert result.assigned_adjuster_id is None  # Not routed yet
        
        # Verify NO acknowledgment sent (cannot confirm coverage without specialist review)
        notifications = self.mock_notifications.get_sent()
        assert len(notifications) == 0
```

**Run Schedule:**
```bash
# On every commit (CI pipeline)
pytest tests/unit/                     # ~5 seconds, 200+ tests

# On every pull request
pytest tests/unit/ tests/integration/  # ~2 minutes, 250+ tests

# Before deployment (staging environment)
pytest tests/                           # ~5 minutes, all tests including E2E

# Daily (production validation - against test environment)
pytest tests/regression/                # ~10 minutes, golden dataset + synthetic
```

---

### 5.4 CI/CD Integration

#### Pre-Commit Hooks
```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: unit-tests
        name: Run unit tests
        entry: pytest tests/unit/ --maxfail=1
        language: system
        pass_filenames: false
        always_run: true
```

#### GitHub Actions Workflow
```yaml
# .github/workflows/test.yml
name: Test Agent

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      
      - name: Install dependencies
        run: |
          pip install -r requirements.txt
          pip install -r requirements-test.txt
      
      - name: Run unit tests
        run: pytest tests/unit/ -v --cov=agent --cov-report=xml
      
      - name: Run integration tests
        run: pytest tests/integration/ -v
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          file: ./coverage.xml
      
      - name: Check coverage threshold
        run: |
          coverage report --fail-under=85
  
  e2e:
    runs-on: ubuntu-latest
    needs: test
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v3
      
      - name: Deploy to staging
        run: ./deploy_staging.sh
      
      - name: Run E2E tests (staging)
        run: pytest tests/e2e/ -v --env=staging
      
      - name: Rollback if tests fail
        if: failure()
        run: ./rollback_staging.sh
```

---

### 5.5 Production Monitoring & Continuous Validation

#### Real-Time Metrics (Dashboard)
```
FNOL Agent Health Dashboard
----------------------------
Last 24 hours:

Claims Processed:        287 / 300 target
SLA Compliance:          96.2% (target: >95%) ✓
Avg Processing Time:     18 seconds (target: <60s) ✓

Triage Accuracy:         92.1% (target: >90%) ✓
Routing Accuracy:        96.5% (target: >95%) ✓
Extraction Confidence:   87.3% avg (target: >85%) ✓

Escalation Rate:         28.9% (expected: 25-35%) ✓
  - LOW confidence:      12.1%
  - HIGH/CRITICAL:       4.5%
  - Exclusions:          7.2%
  - System failures:     5.1%

Integration Health:
  - CRM API:             99.8% success ✓
  - Policy SOAP:         97.2% success ⚠️ (3 timeouts in past hour)
  - Notification:        99.9% success ✓

Active Alerts:
  ⚠️  Policy SOAP latency increased to 6.5s (normal: 3s) - investigating
```

#### Automated Audits (Batch Jobs)
```python
# jobs/daily_audit.py

def daily_routing_accuracy_audit():
    """
    Check routing accuracy: does adjuster specialty match incident type?
    Runs daily at 2 AM.
    """
    misroutes = db.query("""
        SELECT claim_id, incident_type, adjuster.specialty
        FROM claims
        JOIN adjusters ON claims.assigned_adjuster_id = adjusters.id
        WHERE routed_at >= CURRENT_DATE - INTERVAL '1 day'
          AND (
              (incident_type LIKE 'AUTO_%' AND adjuster.specialty != 'AUTO')
              OR (incident_type LIKE 'PROPERTY_%' AND adjuster.specialty != 'PROPERTY')
              OR (incident_type LIKE 'INJURY_%' AND adjuster.specialty != 'INJURY')
          )
    """)
    
    mismatch_rate = len(misroutes) / total_claims_routed * 100
    
    if mismatch_rate > 5.0:
        send_alert(
            to="engineering-team@company.com",
            subject=f"⚠️ High routing error rate: {mismatch_rate:.1f}%",
            body=f"Detected {len(misroutes)} routing mismatches in past 24 hours. See attached list.",
            attachment=misroutes.to_csv()
        )
    
    log_metric("routing_accuracy", 100 - mismatch_rate)

def weekly_severity_override_analysis():
    """
    Analyze when adjusters override agent severity classifications.
    Runs weekly on Monday.
    """
    overrides = db.query("""
        SELECT 
            original_severity,
            overridden_severity,
            COUNT(*) as count,
            ARRAY_AGG(claim_id) as claim_ids
        FROM severity_overrides
        WHERE overridden_at >= CURRENT_DATE - INTERVAL '7 days'
        GROUP BY original_severity, overridden_severity
    """)
    
    # Flag high override rates
    for override in overrides:
        if override.original_severity == "MEDIUM" and override.overridden_severity == "HIGH":
            override_rate = override.count / total_medium_claims * 100
            if override_rate > 10.0:
                send_alert(
                    to="ml-team@company.com",
                    subject=f"⚠️ Agent under-triaging: {override_rate:.1f}% MEDIUM→HIGH overrides",
                    body=f"Agent is under-triaging {override.count} claims as MEDIUM when they should be HIGH. Review NLP injury classification model. Claim IDs: {override.claim_ids}"
                )
```

#### Synthetic Production Tests (Canary Claims)
```python
# jobs/hourly_canary_test.py

def submit_canary_claim():
    """
    Submit a synthetic test claim every hour to verify agent is functioning.
    Runs hourly.
    """
    canary_claim = {
        "claimant_email": "test+canary@company.internal",  # Special test email
        "policy_number": "POL-00000001",  # Test policy
        "incident_description": "CANARY TEST: Windshield crack",
        "estimated_value": "$300",
        "source_channel": "WEB_FORM"
    }
    
    start_time = time.time()
    result = agent.process_claim(canary_claim)
    processing_time = time.time() - start_time
    
    # Assertions
    assert result.status == "ACKNOWLEDGED", f"Canary claim failed: {result.status}"
    assert result.severity == "LOW", f"Canary severity wrong: {result.severity}"
    assert processing_time < 60, f"Canary too slow: {processing_time}s"
    
    log_metric("canary_test_passed", 1)
    log_metric("canary_processing_time", processing_time)
    
    # Clean up: delete canary claim
    db.delete(result.claim_id)
```

---

### 5.6 Testing Tools & Infrastructure

#### Recommended Testing Stack

**Unit Testing:**
- **pytest** (Python) or **Jest** (Node.js): Test runner
- **pytest-mock**: Mocking framework
- **pytest-cov**: Code coverage

**Integration Testing:**
- **responses** (Python) or **nock** (Node.js): HTTP mocking
- **testcontainers**: Spin up PostgreSQL, Redis for integration tests
- **VCR.py**: Record/replay HTTP interactions

**E2E Testing:**
- **pytest** with real staging environment
- **Docker Compose**: Orchestrate multi-service test environment

**Load Testing:**
- **Locust** (Python) or **k6** (Go): Generate 300 claims/day load
- **Grafana + Prometheus**: Monitor performance under load

**Monitoring:**
- **Datadog** or **New Relic**: Real-time metrics, alerting
- **Sentry**: Error tracking, exception monitoring
- **CloudWatch** (AWS): Logs aggregation

#### Test Environment Architecture
```
Development:
  - Local PostgreSQL (Docker)
  - Mock external APIs (in-memory)
  - Fast feedback (<5s test runs)

Staging:
  - Dedicated database (staging-db.company.internal)
  - Mock external APIs (controlled responses)
  - E2E tests run here before production deploy

Production:
  - Real database, real integrations
  - Canary tests (synthetic claims)
  - Continuous monitoring (dashboards, alerts)
```

---

## 6. Testing Strategy Summary

### Test Execution Schedule

| Test Type | Frequency | Duration | Trigger | Pass Threshold |
|-----------|-----------|----------|---------|----------------|
| Unit tests | Every commit | 5 seconds | Git push | 100% pass |
| Integration tests | Every PR | 2 minutes | Pull request | 100% pass |
| E2E tests | Pre-deployment | 5 minutes | Merge to main | 100% pass |
| Regression suite (golden) | Daily | 10 minutes | Cron (2 AM) | >95% pass |
| Load test (300 claims/day) | Weekly | 30 minutes | Manual trigger | Avg <60s, SLA >95% |
| Canary tests (production) | Hourly | 1 minute | Cron | 100% pass |
| Routing accuracy audit | Daily | 2 minutes | Cron (2 AM) | >95% accuracy |
| Severity override analysis | Weekly | 5 minutes | Cron (Monday 8 AM) | <10% override rate |

### Acceptance Criteria for Deployment

Agent cannot be deployed to production unless:
- ✓ All unit tests pass (200+ tests)
- ✓ All integration tests pass (50 scenarios)
- ✓ All E2E tests pass (10 critical paths)
- ✓ Code coverage >85%
- ✓ Golden dataset tests >95% pass rate
- ✓ Load test: 300 claims/day processed with <5% SLA breaches
- ✓ No critical or high-severity bugs open
- ✓ Manual QA sign-off from claims team (5 test claims reviewed)

---

## 7. Continuous Improvement Loop

### Feedback Mechanisms

**Source 1: Adjuster Overrides**
- Track when adjusters manually change agent decisions (severity, routing)
- Weekly review: Identify patterns, update agent logic or NLP model
- Example: "10 claims with 'ER visit' triaged as MEDIUM, should be HIGH" → Update injury keyword weights

**Source 2: Escalation Analysis**
- Monitor escalation rate: Target 25-35% (5% HIGH/CRITICAL + 20% flagged issues + 10% low confidence)
- If escalation rate >40%: Agent is too conservative, adjust confidence thresholds
- If escalation rate <20%: Agent may be under-escalating, review HIGH claim detection

**Source 3: Production Incidents**
- Any agent-related production issue (lost claim, wrong routing, SLA breach) becomes a test case
- Root cause analysis → New test added to regression suite
- Example: "Claim stuck in EXTRACTED for 2 hours due to SOAP timeout" → Add test for timeout handling

**Source 4: Claimant Satisfaction Surveys**
- Post-FNOL survey (7 days after filing): Rate experience 1-5
- Correlate low scores (<3) with agent decisions
- Example: Low scores correlate with MEDIUM severity claims → Review if agent is triaging correctly

### Model Retraining Cadence

**NLP Extraction Model:**
- **Frequency:** Monthly
- **Training data:** New FNOL reports from past month (anonymized)
- **Validation:** Compare extraction accuracy on golden dataset before/after retraining
- **Deployment:** If accuracy improves >2%, deploy new model

**Severity Classification Rules:**
- **Frequency:** Quarterly
- **Review:** Analyze adjuster override patterns, claimant satisfaction, claim resolution times
- **Adjustment:** Update thresholds ($5K, $50K) or add new rules based on business feedback

**Routing Algorithm:**
- **Frequency:** As needed (when adjuster team composition changes)
- **Trigger:** New adjuster hired, specialty reassignment, workload capacity changes
- **Update:** Adjust specialty mapping, capacity limits, seniority requirements

---


