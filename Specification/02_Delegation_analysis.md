# Delegation Analysis
## FNOL Claims Processing - Human/Agent Boundary Design

---

## 1. Why Agentic Design is the Right Solution

### The Problem Requires More Than Traditional Automation

The FNOL processing challenge cannot be solved with traditional automation approaches:

**Why NOT traditional software?**
- Traditional software requires fully structured inputs and deterministic business rules
- FNOL reports arrive as **unstructured text** (emails, phone transcripts, web forms) with high variability
- No fixed template: claimants describe incidents in natural language with varying levels of detail
- Traditional rules engines would require hundreds of if-then branches to handle linguistic variations
- Edge cases (ambiguous descriptions, incomplete information) would cause system failures

**Why NOT RPA (Robotic Process Automation)?**
- RPA excels at repetitive click-based tasks (e.g., copying data between fixed-field systems)
- FNOL processing requires **interpretation and reasoning**: "Is this a minor or serious injury based on the description?"
- RPA cannot parse unstructured text or make contextual judgments
- RPA fails when inputs don't match expected patterns (brittleness)
- This problem needs **cognitive work delegation**, not mechanical task automation

**Why NOT pure human process improvement?**
- Current team is already efficient: 22 minutes/claim is reasonable for manual work with 4 complex steps
- The constraint is **volume**, not process inefficiency: 110 person-hours needed vs 96 available
- Hiring more humans doesn't solve quality issues: 18% routing error rate persists regardless of team size
- Growth trajectory (15-20% volume increase) would require continuous hiring
- **The 70% of routine claims are cognitive work that is tedious but codifiable** - perfect candidate for AI delegation

### Why Agentic AI is the Right Answer

**AI agents can handle the cognitive work that is codifiable:**

1. **Natural Language Understanding**
   - Parse unstructured text from emails, transcripts, web forms
   - Extract key facts: incident type, claim amount, injury indicators, policy number
   - Handle linguistic variation: "car accident" = "auto collision" = "vehicle incident"
   - Confidence scoring: flag ambiguous descriptions for human review

2. **Contextual Decision-Making**
   - Apply severity classification rules that combine multiple factors (amount + injury + policy type)
   - Route based on optimization criteria (adjuster specialty + workload + availability)
   - Escalate when decision confidence is below threshold (built-in self-awareness)

3. **System Integration & Orchestration**
   - Query modern CRM (API) and legacy policy system (SOAP) seamlessly
   - Handle integration failures gracefully (timeouts, retries, fallbacks)
   - Maintain state across multiple async operations (validate → route → acknowledge)

4. **Learning & Consistency**
   - Apply triage rules consistently across all 300 claims/day (no fatigue, no bias)
   - Learn from specialist corrections (if routing errors occur, feedback improves model)
   - Audit trail: every decision is logged with reasoning for compliance

5. **Scalability**
   - Handles 300 claims/day or 500 claims/day with same accuracy (linear cost scaling)
   - No hiring lag or training overhead for volume growth
   - Can be deployed to other claim types (property, auto, commercial) after FNOL success

### The Hybrid Model: Agent + Human

**Critical insight:** This is not "replace humans with AI." It is "delegate routine cognitive work to AI, elevate humans to complex work."

- **70% routine claims** (LOW severity, standard coverage): Agent handles end-to-end autonomously
- **25% moderate claims** (MEDIUM severity): Agent triages + routes, specialist oversees
- **5% complex claims** (HIGH severity, ambiguous, exclusions): Agent gathers data, specialist decides

**Result:**
- Specialists freed from 68 hours/day of routine work
- Can focus on high-value claims requiring human judgment, empathy, negotiation
- Team capacity increases from 96 to 140+ effective person-hours/day
- Quality improves (consistent triage rules) while maintaining human accountability for critical decisions

---

## 2. Delegation Framework: Categories Defined

Before analyzing each FNOL step, we define the four delegation categories:

| Category | Definition | When to Use | Example |
|----------|------------|-------------|---------|
| **Category 1: Fully Agentic** | Agent decides and acts autonomously, no human review before execution | Decision logic fully codifiable, low error risk, high volume, reversible | Email validation, database lookups, status updates |
| **Category 2: Agent-Led + Human Oversight** | Agent decides and acts, human can review and correct after | Mostly codifiable, moderate risk, detectable/correctable errors | Medium-severity triage, routing to adjuster |
| **Category 3: Human-Led + Agent Support** | Agent gathers data, human makes final decision | Partially codifiable, high risk, low volume, human accountability required | High-value claims, policy exclusions, complex routing |
| **Category 4: Human Only** | No agent involvement | Not codifiable, requires empathy/negotiation, one-off strategic | Settlement negotiation, executive escalations |

---

## 3. FNOL Processing Steps: Delegation Analysis

### Overview of FNOL Workflow

The FNOL process consists of five core steps:

1. **Data Extraction & Normalization** - Parse unstructured report into structured fields
2. **Severity Triage** - Classify claim by severity (CRITICAL / HIGH / MEDIUM / LOW)
3. **Policy Validation** - Verify active coverage and check for exclusions
4. **Adjuster Routing** - Assign claim to appropriate specialist
5. **Claimant Acknowledgment** - Confirm receipt and communicate next steps

Each step is analyzed below with delegation classification and justification.

---

### Step 1: Data Extraction & Normalization

**Task:** Parse unstructured FNOL report (email, phone transcript, web form) and extract structured fields.

**Required extractions:**
- Claimant identification (name, policy number, contact info)
- Incident details (date, time, location, type)
- Estimated claim amount
- Injury indicator (yes/no/severity description)
- Policy number
- Description of incident (free text)

**Delegation Classification:** **Category 2 - Agent-Led + Human Oversight**

**Agent Role:**
- Use NLP to extract key facts from unstructured text
- Normalize incident types (e.g., "car crash" → INCIDENT_TYPE: AUTO_COLLISION)
- Parse claim amounts from text (e.g., "$5,000 in damage" → ESTIMATED_VALUE: 5000)
- Flag missing or ambiguous fields (confidence scoring)

**Human Role:**
- Review agent extractions where confidence < 0.7
- Correct misinterpretations (e.g., agent parsed "$5K deductible" as claim amount)
- Complete missing fields if agent cannot extract (claimant didn't provide)

**Escalation Triggers:**
- Confidence score < 0.7 on any critical field (policy number, incident type, claim amount)
- Policy number not found in database (potential typo)
- Claimant contact information missing or malformed
- Free-text description is <20 words (insufficient detail for triage)

**Why This Boundary:**
1. **Codifiability:** NLP extraction is 80-90% accurate for structured extraction tasks (modern LLMs excel at this)
2. **Error detectability:** Specialist reviewing the structured output can immediately spot extraction errors
3. **Volume:** All 300 claims/day need extraction; full human review would take 10-15 minutes/claim (50+ hours/day) - not feasible
4. **Correction window:** Errors caught during specialist review (next 30 minutes) before triage decisions propagate
5. **Risk:** Extraction errors are correctable without downstream harm (just re-triage with corrected data)

**Expected Performance:**
- Agent autonomously processes: ~240 claims/day (80% straight-through)
- Human review required: ~60 claims/day (20% flagged for low confidence)
- Average time per claim: Agent 30 seconds, human review (when needed) 2 minutes

---

### Step 2: Severity Triage

**Task:** Classify claim into severity categories: CRITICAL / HIGH / MEDIUM / LOW

**Severity Classification Rules** (agent-defined):

```
CRITICAL Severity:
- estimated_value > $100,000 OR
- injury_severity = FATAL OR
- incident_type = MULTI_PARTY_LIABILITY OR
- incident_type = PRODUCT_LIABILITY OR
- claimant_is_VIP = TRUE (board member, executive, high-profile)

HIGH Severity:
- estimated_value > $50,000 OR
- injury_severity IN [SERIOUS, HOSPITALIZED] OR
- policy_type = COMMERCIAL OR
- exclusion_clauses_detected = TRUE (from policy validation) OR
- fraud_indicators_present = TRUE

MEDIUM Severity:
- estimated_value $5,000 - $50,000 OR
- injury_severity = MINOR OR
- incident_type IN [AUTO_COLLISION_MULTI_VEHICLE, PROPERTY_DAMAGE_STRUCTURAL] OR
- claimant_explicitly_requested_callback = TRUE

LOW Severity:
- estimated_value < $5,000 AND
- injury_severity = NONE AND
- policy_type = STANDARD AND
- incident_type IN [AUTO_COLLISION_SINGLE_VEHICLE, MINOR_PROPERTY_DAMAGE, WINDSHIELD_REPLACEMENT]
```

**Delegation Classification: Varies by Severity Outcome**

#### For LOW Severity Claims (Estimated 210/day, 70% of volume):
**Category 1 - Fully Agentic**

**Agent Role:**
- Apply severity rules above
- Assign severity = LOW
- Log decision with reasoning (which rules triggered)
- Proceed to policy validation automatically

**Human Role:**
- None (no review before proceeding)
- Specialist sees severity when reviewing assigned claim
- Can re-triage if agent made an error (detected during adjuster review)

**Why This Boundary:**
1. **Fully codifiable:** LOW severity is defined by clear thresholds (amount < $5K, no injury, standard policy)
2. **Low error risk:** If agent mis-classifies a LOW claim, worst case is slight delay (specialist catches it within 1 hour)
3. **High volume:** 210 claims/day - human review would consume 7+ hours/day
4. **Client alignment:** LOW claims are not "high-value or ambiguous" (client's constraint doesn't apply)

---

#### For MEDIUM Severity Claims (Estimated 75/day, 25% of volume):
**Category 2 - Agent-Led + Human Oversight**

**Agent Role:**
- Apply severity rules
- Assign severity = MEDIUM
- Proceed to policy validation and routing
- Flag for specialist review (notification in queue)

**Human Role:**
- Specialist reviews severity assignment within 30 minutes of routing
- Can re-triage to LOW (if agent over-classified) or escalate to HIGH (if under-classified)
- Override requires justification note (logged for audit)

**Escalation Triggers:**
- Agent confidence score < 0.75 on severity classification
- Borderline values (e.g., claim amount = $4,900 - close to $5K threshold)
- Conflicting indicators (e.g., LOW amount but injury description uses word "serious")

**Why This Boundary:**
1. **Mostly codifiable:** MEDIUM severity has clear rules, but edge cases exist (e.g., "minor injury" is somewhat subjective)
2. **Moderate error risk:** Mis-triage could assign to wrong adjuster tier, but correctable within 30 min
3. **Volume:** 75 claims/day - specialist oversight takes ~2 min/claim = 2.5 hours/day (feasible)
4. **Client alignment:** MEDIUM claims can have agent-led processing with oversight (not purely "high-value")

---

#### For HIGH & CRITICAL Severity Claims (Estimated 15/day, 5% of volume):
**Category 3 - Human-Led + Agent Support**

**Agent Role:**
- Apply severity rules
- Detect HIGH or CRITICAL triggers (amount > $50K, serious injury, exclusions, fraud)
- **Do NOT assign final severity** - flag for specialist review
- Present pre-gathered data to specialist:
  - Extracted incident details
  - Policy coverage summary
  - Reason for HIGH/CRITICAL flag (which rule triggered)
  - Recommended adjuster specialty

**Human Role:**
- Specialist reviews agent's assessment
- Makes final severity determination (HIGH, CRITICAL, or downgrade to MEDIUM if agent over-flagged)
- Decides routing (can override agent's recommendation)
- Specialist's name attached to triage decision (accountability)

**Escalation Triggers:**
- Any claim meeting HIGH/CRITICAL criteria is automatically escalated
- No agent autonomy at this tier

**Why This Boundary:**
1. **Client constraint:** Client explicitly requires "human oversight for high-value or ambiguous claims"
2. **High error risk:** Mis-triaging a $60K claim could lead to inadequate specialist assignment, litigation exposure
3. **Partially codifiable:** While $ thresholds are clear, "serious injury" and exclusion clause interpretation require judgment
4. **Low volume:** 15 claims/day = 75 min/day specialist time (highly feasible)
5. **Accountability requirement:** High-value decisions must have a named human on record

**Expected Performance:**
- LOW (Category 1): 210 claims/day, 0 human review, agent autonomy
- MEDIUM (Category 2): 75 claims/day, specialist oversight, ~2.5 hours/day
- HIGH/CRITICAL (Category 3): 15 claims/day, specialist decides, ~1.25 hours/day

---

### Step 3: Policy Validation

**Task:** Verify that the claim is covered under the claimant's policy.

**Sub-tasks:**
a. Check policy status (active vs expired)
b. Verify coverage type matches incident type
c. Check coverage limits vs estimated claim amount
d. Identify exclusion clauses that may apply

**Delegation Classification: Varies by Sub-Task**

#### Sub-task 3a: Policy Status Check
**Category 1 - Fully Agentic**

**Agent Role:**
- Query policy admin system: GET /policy/{policy_number}/status
- Check: policy.status = ACTIVE AND policy.effective_date <= incident_date <= policy.expiration_date
- If not active: flag claim as REJECTED_INACTIVE_POLICY

**Human Role:** None

**Why This Boundary:**
- Fully codifiable (database lookup + date comparison)
- Zero ambiguity: policy is either active or not
- High volume (all 300 claims/day)

---

#### Sub-task 3b: Coverage Type Verification
**Category 1 - Fully Agentic**

**Agent Role:**
- Query policy admin system: GET /policy/{policy_number}/coverage_details
- Check: policy.coverage_types INCLUDES incident_type
  - Example: AUTO_COLLISION requires policy.auto_liability = TRUE
- If not covered: flag claim as REJECTED_NOT_COVERED

**Human Role:** None

**Why This Boundary:**
- Fully codifiable (set membership check)
- Policy coverage types are structured data fields (enum values)
- Clear yes/no outcome

---

#### Sub-task 3c: Coverage Limit Check
**Category 1 - Fully Agentic**

**Agent Role:**
- Check: estimated_claim_value <= policy.coverage_limit
- If exceeds: flag as EXCEEDS_COVERAGE_LIMIT (specialist review required)
- Log comparison for audit trail

**Human Role:**
- Specialist reviews claims that exceed limits
- Decides: partial coverage, claimant pays overage, or escalate to senior adjuster

**Escalation Trigger:**
- estimated_claim_value > policy.coverage_limit

**Why This Boundary:**
- Limit check is fully codifiable (numeric comparison)
- But when exceeded, requires human judgment on how to proceed (cannot auto-reject)

---

#### Sub-task 3d: Exclusion Clause Detection
**Category 3 - Human-Led + Agent Support**

**Agent Role:**
- Query policy admin system for exclusion clauses attached to policy
- Use NLP to scan incident description for exclusion keywords:
  - "intentional damage" → EXCLUSION: intentional_acts
  - "driving under influence" → EXCLUSION: DUI
  - "act of God" → EXCLUSION: force_majeure
  - "earthquake" + policy.earthquake_coverage = FALSE → EXCLUSION: earthquake
- Flag potential exclusions with confidence scores
- Present to specialist with:
  - Exclusion clause text (from policy)
  - Portion of incident description that triggered flag
  - Confidence score

**Human Role:**
- Specialist reads exclusion clause
- Specialist reads claimant's incident description
- Makes judgment call: does exclusion apply?
- If exclusion applies: REJECT claim or REQUEST_MORE_INFO from claimant
- Specialist's interpretation is final and logged

**Escalation Triggers:**
- Any exclusion clause keyword detected (confidence > 0.6)
- Policy has >0 exclusions on record (proactive check)

**Why This Boundary:**
1. **Not fully codifiable:** Exclusion clauses use legal language requiring interpretation
   - Example: "Loss caused by act of God" - is a hurricane an act of God? Depends on policy definition and jurisdiction
2. **High risk:** Incorrectly denying a valid claim = reputation damage + potential lawsuit
3. **Low volume:** Estimated <10% of claims have exclusion considerations (~30 claims/day)
4. **Client requirement:** Ambiguous claims require human judgment

**Expected Performance:**
- Policy status, coverage type, limits: Fully automated (300 claims/day, <10 seconds each)
- Exclusion clause interpretation: 30 claims/day require specialist review (~30 min/day)

---

### Step 4: Adjuster Routing

**Task:** Assign claim to appropriate adjuster based on specialty, workload, and availability.

**Routing Criteria:**
- Adjuster specialty must match incident type (e.g., auto collision → auto claims adjuster)
- Adjuster workload: current_open_cases < max_capacity (e.g., <15 active claims)
- Adjuster availability: status = AVAILABLE (not on PTO, not in training)
- Severity match: HIGH/CRITICAL claims → senior adjusters only

**Delegation Classification:** **Category 2 - Agent-Led + Human Oversight**

**Agent Role:**
- Query CRM: GET /adjusters?specialty={incident_type}&status=AVAILABLE
- Filter: current_open_cases < 15
- For HIGH/CRITICAL claims: filter by seniority_level >= SENIOR
- Select adjuster with lowest current_open_cases (load balancing)
- Assign claim: POST /claims/{claim_id}/assign with adjuster_id
- Send notification to adjuster (email/dashboard alert)

**Human Role:**
- Queue manager (operations lead) can view all routing decisions in dashboard
- Can manually re-assign if:
  - Agent selected wrong specialty (e.g., assigned property claim to auto adjuster)
  - Adjuster workload is actually higher than system shows (CRM data lag)
  - Specific adjuster has subject matter expertise for unusual claim
- Override requires justification note

**Escalation Triggers:**
- No available adjusters found matching criteria (capacity exhausted)
- Multiple adjusters tied with same workload (agent requests tiebreaker preference)
- Claim marked as HIGH but no senior adjusters available

**Why This Boundary:**
1. **Mostly codifiable:** Specialty matching, workload balancing, availability checks are all database queries + rules
2. **Moderate error risk:** Routing error wastes adjuster time but is correctable within 30 min (adjuster can reject assignment)
3. **High volume:** All 300 claims/day need routing; manual routing takes 5 min/claim (25 hours/day) - not feasible
4. **Quality improvement:** Current 18% routing error rate suggests humans make mistakes under time pressure; consistent agent rules should reduce to <5%
5. **Human oversight preserves judgment:** Queue manager can override for edge cases agent doesn't know (e.g., "this adjuster is best with difficult customers")

**Expected Performance:**
- Agent routes: 290 claims/day autonomously (>95%)
- Manual override: <10 claims/day (~30 min/day)
- Routing error rate: <5% (down from 18% current)

---

### Step 5: Claimant Acknowledgment

**Task:** Send confirmation to claimant that claim was received and is being processed.

**Acknowledgment Content:**
- Claim ID (reference number)
- Confirmation of receipt timestamp
- Assigned severity
- Expected timeline for adjuster contact
- Assigned adjuster name and contact info
- Next steps for claimant

**Delegation Classification:** **Category 1 - Fully Agentic**

**Agent Role:**
- Compose acknowledgment message using template with dynamic fields:
  - "Your claim (ID: {claim_id}) was received on {timestamp}."
  - "Severity: {severity}. Expected adjuster contact: {timeline}."
  - "Your assigned adjuster is {adjuster_name} ({adjuster_email})."
  - "Next steps: {next_steps_based_on_severity}."
- Send via claimant's preferred channel (email, SMS)
- Log acknowledgment sent with timestamp

**Human Role:** None

**Why This Boundary:**
1. **Fully codifiable:** Template-based message generation with field substitution
2. **Zero error risk:** Sending acknowledgment is informational; if content is wrong, it's correctable in adjuster's follow-up
3. **High volume:** All 300 claims/day
4. **SLA-critical:** Must send within 5 minutes to meet target - no time for human review

**Expected Performance:**
- 100% automated
- <2 minutes from claim receipt to acknowledgment sent
- 95th percentile: <5 minutes (meets target SLA)

---

## 4. Summary: Delegation Boundaries

| FNOL Step | Delegation Category | Agent Autonomy | Human Role | Volume/Day | Est. Specialist Time |
|-----------|---------------------|----------------|------------|------------|----------------------|
| **Data Extraction** | Category 2: Agent-Led + Oversight | Extracts 80%, flags low-confidence 20% | Reviews flagged extractions | 300 (60 flagged) | 2 hours |
| **Severity Triage - LOW** | Category 1: Fully Agentic | 100% autonomous | None (monitors only) | 210 | 0 hours |
| **Severity Triage - MEDIUM** | Category 2: Agent-Led + Oversight | Assigns, specialist oversees | Reviews within 30 min, can override | 75 | 2.5 hours |
| **Severity Triage - HIGH/CRITICAL** | Category 3: Human-Led + Support | Gathers data, flags | Specialist decides final severity + routing | 15 | 1.25 hours |
| **Policy Validation - Status/Type/Limits** | Category 1: Fully Agentic | 100% autonomous | None | 300 | 0 hours |
| **Policy Validation - Exclusions** | Category 3: Human-Led + Support | Flags potential exclusions | Specialist interprets clauses | 30 | 0.5 hours |
| **Adjuster Routing** | Category 2: Agent-Led + Oversight | Routes based on rules | Queue manager can override | 300 (10 overrides) | 0.5 hours |
| **Claimant Acknowledgment** | Category 1: Fully Agentic | 100% autonomous | None | 300 | 0 hours |

**Total Specialist Time Required:** ~6.75 hours/day (vs current 110 hours/day)

**Capacity Impact:**
- Current: 110 person-hours/day required, 96 available → 115% over-capacity
- With agent: 6.75 person-hours/day for oversight + 30 hours/day for downstream claim resolution = ~37 hours/day
- **Net capacity gain: 73 person-hours/day freed for complex claims work**

---

## 5. Justification of Boundary Decisions

### Why These Boundaries are Defensible

**Client Constraint Honored:**
- HIGH/CRITICAL claims (high-value) → Human-led (Category 3)
- Exclusion clause interpretation (ambiguous) → Human-led (Category 3)
- All other decisions have human oversight or monitoring capability

**Risk-Proportionate:**
- LOW-risk, high-volume tasks → Fully agentic (Category 1)
- MODERATE-risk, moderate-volume → Agent-led with oversight (Category 2)
- HIGH-risk, low-volume → Human-led with agent support (Category 3)

**Codifiability-Driven:**
- Database lookups, numeric thresholds, template generation → Agent decides
- NLP extraction, specialty matching, load balancing → Agent decides with oversight
- Legal interpretation, high-value judgment calls → Human decides

**Volume-Feasible:**
- Human oversight required for only ~150 claims/day (6.75 hours/day)
- Specialists can sustainably handle this workload
- Agent autonomously processes 210 LOW claims/day (zero specialist time)

**Error-Correctable:**
- All agent decisions have detection windows (specialist reviews within 30-60 min)
- Routing errors correctable before adjuster begins work
- Extraction errors caught during specialist review

---

## 6. Expected Outcomes from This Delegation Model

**Operational Metrics:**
- Average handling time: 22 min → 3 min for LOW claims (86% reduction)
- Specialist capacity utilization: 115% → 85% (sustainable)
- Claims processed per specialist: 25/day → 37/day (48% increase)

**Quality Metrics:**
- Routing error rate: 18% → <5% (consistent agent rules)
- SLA compliance: 69% → >95% (automated acknowledgment <5 min)
- Triage consistency: Variable → 100% (same rules applied to all claims)

**Specialist Experience:**
- Time on routine work: 70% → 20%
- Time on complex work: 30% → 80%
- Job satisfaction: Higher (more meaningful work, less repetitive tasks)

**Claimant Experience:**
- Time to acknowledgment: 2+ hours → <5 minutes
- Status transparency: 0% → 100% (self-service visibility)
- Routing accuracy: 82% → >95% (fewer callbacks, correct specialist first time)

---

## 7. Assumptions That Underpin This Delegation Model

**Assumption D1:** 70% of claims are routine (LOW severity) and algorithmically triageable
- **If wrong:** Automation rate drops; more specialist oversight needed; ROI decreases
- **Validation:** Analyze 3 months historical claims by severity distribution

**Assumption D2:** Severity thresholds ($5K, $50K, $100K) align with client's risk appetite
- **If wrong:** Boundaries shift but delegation structure remains valid (re-calibrate thresholds)
- **Validation:** Confirm with claims leadership and review historical high-value claim outcomes

**Assumption D3:** CRM provides real-time adjuster workload and availability data
- **If wrong:** Routing becomes round-robin instead of load-balanced (less optimal but functional)
- **Validation:** Review CRM API documentation and test data freshness

**Assumption D4:** Policy admin SOAP system can handle 300+ concurrent requests
- **If wrong:** Need request throttling or caching layer (adds latency but maintains functionality)
- **Validation:** Load testing on legacy system

**Assumption D5:** Specialists will trust agent decisions for LOW/MEDIUM claims
- **If wrong:** Over-monitoring wastes time, negates capacity gains
- **Validation:** Phased rollout with specialist feedback loop; demonstrate <5% error rate in pilot

---


