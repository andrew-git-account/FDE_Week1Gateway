# Assumptions & Unknowns
## FNOL Claims Processing Agent - What We Know, What We Assume, What We Must Validate

---

## Purpose of This Document

This document distinguishes between:
- **Assumptions**: Claims we're taking as given but require client validation before building
- **Unknowns**: Information we genuinely lack and must discover through client engagement

**Critical principle:** Hidden assumptions are the failure mode. Stated assumptions are discovery.

Every non-trivial claim in our specification is either (a) derived from the scenario, (b) assumed — and documented here, or (c) unknown — and flagged for validation.

---

## 1. Assumptions

Assumptions are claims we've made in our specification that need client validation. Each assumption includes:
- **Statement**: What we're assuming
- **Why it matters**: How this assumption shapes the design
- **If wrong**: What breaks or must change
- **Validation method**: How to test this with the client
- **Confidence level**: Low / Medium / High
- **Status**: [Assumed] or [Flagged for Validation]

---

### A1: Claim Volume Distribution by Severity

**Assumption Statement:**
70% of FNOL claims are LOW severity (routine: <$5K value, no injury, standard policy, straightforward incidents like windshield cracks, minor scratches). 25% are MEDIUM severity ($5K-$50K, minor injuries). 5% are HIGH/CRITICAL severity (>$50K, serious injuries, complex cases).

**Why It Matters:**
- Determines automation rate: If 70% are LOW, agent can process 210 claims/day autonomously (zero human review)
- Informs capacity planning: Specialists need to handle 30% oversight/triage (90 claims/day)
- Justifies ROI: $550K annual savings calculation assumes 70% straight-through processing

**If Wrong:**
- If only 50% are LOW: Automation rate drops, capacity gains reduced, ROI decreases to ~$350K/year
- If 80% are LOW: Even better ROI, but may indicate we're being too conservative with escalation thresholds
- Delegation boundaries remain valid but economics change

**Validation Method:**
1. Analyze 3-6 months historical FNOL claims data
2. Classify past claims using our severity rules (value, injury, policy type)
3. Calculate actual distribution: % LOW, % MEDIUM, % HIGH/CRITICAL
4. Interview 3-5 specialists: "What % of your daily claims are routine vs complex?"
5. Review adjuster workload logs: Time spent per claim by complexity

**Confidence Level:** Medium
- Based on: Scenario mentions "most of this is paperwork" and "15% require judgment calls"
- Uncertainty: "Routine" is subjective; our $5K threshold may not match client's mental model

**Status:** [Flagged for Validation] - Critical assumption, must validate before finalizing design

---

### A2: Severity Thresholds Align with Client Risk Appetite

**Assumption Statement:**
Client considers claims valued at <$5K as LOW risk (fully automatable), $5K-$50K as MEDIUM risk (agent-led with oversight acceptable), and >$50K as HIGH risk (requiring human-led triage and senior adjuster assignment).

**Why It Matters:**
- Sets delegation boundaries: These thresholds determine when agent escalates vs decides autonomously
- Defines what "high-value" means (client constraint: "human oversight for high-value or ambiguous claims")
- Impacts escalation rate: If threshold is $25K instead of $50K, escalation rate doubles

**If Wrong:**
- If client's threshold is $25K for HIGH: Agent under-escalates, routes high-value claims to intermediate adjusters (unacceptable risk)
- If client's threshold is $100K for HIGH: Agent over-escalates, wastes specialist time on claims they'd handle autonomously (inefficiency)
- Boundaries shift but delegation model structure remains valid (re-calibrate thresholds in severity logic)

**Validation Method:**
1. Interview claims director: "At what claim value do you require senior adjuster involvement?"
2. Review historical escalation patterns: At what values did specialists manually escalate to senior adjusters?
3. Review risk management policy: Are there documented thresholds for claim authority levels?
4. Survey senior adjusters: "What claim value makes you uncomfortable if handled by intermediate adjuster?"
5. Check regulatory requirements: Do state insurance regulations mandate approval thresholds?

**Confidence Level:** Low
- Based on: Scenario says "high-value or ambiguous" but doesn't define "high-value"
- Uncertainty: Industry standards vary ($25K-$100K range common); need client-specific guidance

**Status:** [Flagged for Validation] - Must confirm before finalizing severity classification rules

---

### A3: Legacy SOAP System Can Handle Peak Concurrent Load

**Assumption Statement:**
The legacy policy administration system (SOAP endpoint) can handle 300+ concurrent requests during business hours (9 AM - 5 PM peak) without significant performance degradation. Response times remain <8 seconds for 95th percentile even under full load.

**Why It Matters:**
- Agent timeout set to 8 seconds based on assumption system is "slow but reliable"
- No request throttling implemented (agent calls SOAP for every claim validation)
- If system can't handle load, all claims escalate with "policy system unavailable" error

**If Wrong:**
- If system capacity is <100 concurrent requests: Agent must implement request queue/throttling, increases processing time from <60s to 2-3 minutes per claim
- If 95th percentile latency is >8 seconds: Must increase timeout to 15s, accept slower processing
- If system frequently times out: Need caching layer (validate policies once, cache for 1 hour), adds architectural complexity

**Validation Method:**
1. Review SOAP system documentation/SLA (if exists)
2. Interview IT team: "What's the concurrent request limit for policy admin system?"
3. Load test: Send 300 parallel SOAP requests, measure response time distribution and error rate
4. Review historical logs: How often do SOAP timeouts occur during peak hours?
5. Check monitoring dashboards: What's current daily request volume and latency?

**Confidence Level:** Low
- Based on: Scenario mentions "legacy system" but provides no performance data
- Uncertainty: Legacy systems often have undocumented capacity limits; "slow" could mean 3s or 30s

**Status:** [Flagged for Validation] - Must load test before production deployment

---

### A4: CRM Provides Real-Time Adjuster Workload Data

**Assumption Statement:**
CRM API provides adjuster current workload (count of open claims) with <5 minute staleness. When agent queries `GET /adjusters/available`, the `current_workload` field accurately reflects claims assigned in the past 5 minutes.

**Why It Matters:**
- Routing algorithm uses workload for load balancing (assigns to adjuster with lowest `current_workload`)
- If data is stale (30+ minutes), agent may assign multiple claims to same adjuster, creating overload
- Load balancing effectiveness depends on data freshness

**If Wrong:**
- If data staleness is >30 minutes: Routing becomes pseudo-round-robin (not true load balancing), some adjusters overloaded while others idle
- If workload data unavailable: Fallback to round-robin assignment, loses optimization benefit
- If workload calculation is inconsistent: Manual rebalancing required by queue manager

**Validation Method:**
1. Review CRM API documentation: How is `current_workload` calculated? How often updated?
2. Test data freshness: Assign claim via API, immediately re-query adjuster, verify workload incremented
3. Interview CRM admin: "Is adjuster workload updated in real-time or batch-updated?"
4. Review CRM database schema: Is `current_workload` a computed field or cached value?
5. Check for race conditions: Assign 3 claims simultaneously to different adjusters, verify all workloads update correctly

**Confidence Level:** Medium
- Based on: Modern CRM systems typically provide real-time data, but "modern CRM" is vague
- Uncertainty: Workload calculation may include non-FNOL claims (downstream adjusting work), skewing the count

**Status:** [Assumed] - Reasonable assumption for modern CRM, but verify data freshness during integration testing

---

### A5: CRM Supports Webhook/Push Notifications for New Claims

**Assumption Statement:**
CRM API supports webhook subscription for FNOL claim creation events. When a new claim is submitted (email, phone, web form), CRM pushes a notification to agent service immediately (push model), rather than requiring agent to poll for new claims every N seconds (pull model).

**Why It Matters:**
- Push model: <5 second acknowledgment latency (event-driven)
- Pull model: Acknowledgment latency = polling interval (if poll every 30s, avg latency is 15s)
- SLA requirement: 95% acknowledged within 5 minutes — push model comfortable margin, pull model requires careful tuning

**If Wrong:**
- If CRM only supports polling: Implement polling loop (every 15 seconds), acceptable but less efficient
- If polling interval must be >1 minute (CRM rate limits): Risk of SLA breaches during peak load (50 claims/hour)
- Architectural change: Agent becomes polling service instead of event-driven handler

**Validation Method:**
1. Review CRM API documentation: Webhook support? Event subscription endpoints?
2. Interview CRM vendor/admin: "Can we subscribe to claim creation events?"
3. Test: Create webhook endpoint, register with CRM, submit test claim, verify webhook fires
4. Measure latency: Time from claim submission to webhook received (should be <1 second)
5. Fallback plan: If no webhook support, implement polling with 15-second interval

**Confidence Level:** Medium
- Based on: Scenario says "modern CRM with APIs" — webhooks are common in modern systems
- Uncertainty: "Modern" is subjective; some enterprise CRMs lag behind SaaS standards

**Status:** [Assumed] - Likely supported, but have polling fallback ready

---

### A6: Notification Service Can Handle Daily Volume Without Throttling

**Assumption Statement:**
Email/SMS notification service can deliver 300 notifications per day (one per FNOL claim) without hitting rate limits or throttling. Service supports 500 requests/minute burst capacity for peak hours (50 claims/hour = <1 req/min sustained, comfortably under limit).

**Why It Matters:**
- If service throttles at lower rate (e.g., 100 messages/day), acknowledgments delayed, SLA breaches increase
- If delivery SLA is >5 minutes, claimant acknowledgment target missed
- If service cost scales with volume, impacts ROI calculation

**If Wrong:**
- If rate limit is 100/day: Need to batch acknowledgments or queue during peak, increases complexity
- If delivery is slow (>1 minute per email): Acknowledgment step takes longer, risk of timeout
- If service is unreliable (>5% delivery failure rate): Many claims escalate with "unable to notify claimant"

**Validation Method:**
1. Review notification service documentation: Rate limits? Delivery SLA? Success rate?
2. Interview notification service admin: "Can we send 300 emails/day? What's the burst limit?"
3. Load test: Send 100 emails in 1 minute, measure delivery time and success rate
4. Check service health history: What's typical uptime? Average delivery time?
5. Review pricing: Does cost increase linearly with volume or is there a tier threshold?

**Confidence Level:** High
- Based on: 300 messages/day is very low volume for modern services (typically support 10K+/day)
- Uncertainty: Minimal; this is unlikely to be a bottleneck

**Status:** [Assumed] - 300/day is well within typical service capacity, low risk

---

### A7: Claimants Will Trust Automated Acknowledgment

**Assumption Statement:**
Claimants will perceive automated email/SMS acknowledgment (sent within 5 minutes) as sufficient initial contact, without requiring immediate human voice conversation. Trust in the process is not degraded by automation, provided message is clear and includes adjuster contact info.

**Why It Matters:**
- If claimants distrust automation: Satisfaction scores may not improve despite faster response
- If claimants expect human call: Incoming call volume to claims department increases (defeats capacity benefit)
- Affects success metrics: "Claimant satisfaction +15 points" assumes automation is acceptable

**If Wrong:**
- If claimants demand human contact: Specialists must call all claimants after acknowledgment, negates time savings
- If certain demographics distrust automation: May need human acknowledgment for senior claimants, complex claims
- If message tone is wrong: Automated message feels impersonal, satisfaction decreases

**Validation Method:**
1. A/B test during pilot: 50% receive automated acknowledgment, 50% receive specialist call, measure satisfaction
2. Survey claimants: "Did you feel your claim was handled appropriately with automated acknowledgment?"
3. Analyze callback rate: Do claimants call in after automated acknowledgment (indicates confusion/distrust)?
4. Review complaint data: Are complaints about "talking to a robot" or "lack of personal touch"?
5. Interview claimant services team: "What do claimants typically ask when they call after filing FNOL?"

**Confidence Level:** Medium
- Based on: Industry trend toward automated acknowledgments is common (banking, healthcare)
- Uncertainty: Insurance claims are stressful; claimants may want human reassurance even if logically unnecessary

**Status:** [Flagged for Validation] - Test during pilot, adjust messaging based on feedback

---

### A8: Specialists Will Trust Agent Decisions for LOW/MEDIUM Claims

**Assumption Statement:**
Claims specialists will trust agent triage/routing decisions for LOW and MEDIUM severity claims without excessive second-guessing or over-monitoring. Specialists will only review flagged claims (MEDIUM oversight) and escalations, not every claim.

**Why It Matters:**
- If specialists don't trust agent: They review every claim anyway, negates capacity gains
- If specialists constantly override: Indicates agent is not accurate enough, needs retraining
- Affects change management: Adoption requires trust-building phase

**If Wrong:**
- If specialists over-monitor: 68 hours/day freed becomes 20 hours/day (still positive but lower ROI)
- If override rate >20%: Agent accuracy insufficient, back to training/tuning phase
- If trust varies by specialist: Some adopt, some resist; inconsistent outcomes

**Validation Method:**
1. Phased rollout: Start with 10% of claims processed by agent, specialists review all, measure override rate
2. Target: If override rate <10% for LOW and <15% for MEDIUM after 2 weeks, proceed to full rollout
3. Weekly feedback sessions: "What agent decisions surprised you? Where did you disagree?"
4. Measure: Time spent by specialists reviewing agent decisions (should decrease over weeks as trust builds)
5. Incentive alignment: Ensure specialist performance metrics don't penalize them for trusting agent

**Confidence Level:** Medium
- Based on: Specialists are already handling routine claims; agent should match their judgment for 80%+
- Uncertainty: Human resistance to automation is common; trust must be earned through demonstrated accuracy

**Status:** [Flagged for Validation] - Pilot with feedback loop, iterate until override rate acceptable

---

### A9: FNOL Reports Contain Sufficient Detail for NLP Extraction

**Assumption Statement:**
80% of FNOL reports (emails, phone transcripts, web forms) contain enough structured or extractable information for NLP to extract key fields (policy number, incident date, incident type, estimated value, injury indicator) with ≥0.7 confidence.

**Why It Matters:**
- If extraction confidence consistently <0.7: Most claims escalate at extraction phase, capacity gains eliminated
- If reports are highly unstructured (free-form rambling with no facts): NLP cannot reliably extract, need structured intake forms
- Determines whether NLP-based extraction is viable or if we need data enrichment step (agent prompts claimant for missing info)

**If Wrong:**
- If only 50% of reports have sufficient detail: Escalation rate 50%, not 30% (overwhelms specialists)
- If email/phone transcripts lack critical fields: Need to redesign intake process (add structured intake form step before FNOL submission)
- If extraction accuracy varies by channel (web form 95%, phone transcript 40%): Need channel-specific handling

**Validation Method:**
1. Sample 100 historical FNOL reports: 30 emails, 30 phone transcripts, 40 web forms
2. Test NLP extraction: Process with current NLP model, measure per-field confidence scores
3. Calculate: What % of reports achieve overall_confidence ≥0.7?
4. Identify patterns: Which channels/formats have low confidence? Which fields are most often missing?
5. Review with claims team: "Are there fields you often have to call claimants back to get?"

**Confidence Level:** Low
- Based on: Scenario says "unstructured text" but doesn't provide samples
- Uncertainty: High variability in claimant communication styles; some provide every detail, some provide minimal info

**Status:** [Flagged for Validation] - Test NLP on sample historical reports before committing to design

---

### A10: Policy Admin System Response Time Averages 3-5 Seconds

**Assumption Statement:**
Legacy SOAP policy administration system responds to `GetPolicyCoverage` requests in 3-5 seconds on average (95th percentile <8 seconds). This informed our 8-second timeout value with 2-retry strategy (total max time: 24 seconds per policy validation).

**Why It Matters:**
- If actual response time is 10-15 seconds: 8-second timeout causes false failures, all claims escalate
- If response time is <1 second: 8-second timeout is overly conservative, could reduce to 3 seconds for faster processing
- Sets expectations for end-to-end processing time (validation is 25% of total processing time)

**If Wrong:**
- If average is 10s: Increase timeout to 15s, accept slower processing (60s → 90s per claim)
- If average is 15s+ or highly variable: Need caching layer (validate once per policy, cache for 1 hour), architectural change
- If timeouts occur >10% of time: Policy validation becomes bottleneck, most claims escalate

**Validation Method:**
1. Review SOAP system monitoring dashboards: What's actual p50, p95, p99 latency?
2. Measure: Send 100 test SOAP requests, record response times, calculate distribution
3. Interview IT team: "What's typical response time for policy lookups?"
4. Check for time-of-day variation: Does latency spike during business hours? (9 AM - 5 PM peak)
5. Review historical timeout logs: How often do policy lookups time out currently?

**Confidence Level:** Low
- Based on: Scenario says "legacy system with SOAP endpoints" — legacy often means slow, but how slow?
- Uncertainty: No performance data provided; "slow" is subjective

**Status:** [Flagged for Validation] - Measure actual latency during integration phase, adjust timeout if needed

---

## 2. Unknowns

Unknowns are information gaps we must fill through client discovery. These are **genuine "I don't know"** statements, not platitudes. Each unknown includes:
- **Question**: What specifically do we need to learn?
- **Why it matters**: How this affects the design
- **Discovery method**: How to find out (interview, data analysis, observation)
- **Urgency**: High / Medium / Low (when must we know this?)

---

### U1: Actual Format and Structure of FNOL Reports by Channel

**Question:**
What is the actual format of FNOL reports for each channel?
- **Email**: Do claimants use a structured template? Free-form text? Are there common subject line patterns?
- **Phone transcript**: How are transcripts generated? Speech-to-text automated or human transcribed? What's the typical Q&A structure?
- **Web form**: What fields are required vs optional? Is there free-text description field?

**Why It Matters:**
- NLP extraction accuracy depends entirely on input format consistency
- If emails are free-form with no structure: Extraction confidence may be <0.5, making automation infeasible
- If web forms are fully structured: No NLP needed, 100% extraction confidence (just field mapping)
- Determines whether we need channel-specific extraction logic or one unified approach

**Discovery Method:**
1. Request 30 sample FNOL reports per channel (anonymized) from past 3 months
2. Analyze: What fields are consistently present? What's the linguistic style? Any common patterns?
3. Interview claims intake team: "What's the biggest challenge when processing email claims vs phone vs web?"
4. Shadow specialist: Observe them processing 10 claims, note what info is missing and how they fill gaps
5. Test NLP extraction on samples: Measure actual accuracy by channel

**Urgency:** High
- **Must know before**: Committing to NLP-based extraction design
- **Blocks**: Agent specification finalization (extraction logic depends on input format)

---

### U2: Client's Existing Severity Classification Criteria

**Question:**
How do specialists currently classify claims by severity? Is there a documented rulebook, or is it based on tacit knowledge/experience? What makes a claim "routine" vs "complex" in their current mental model?

**Why It Matters:**
- Our severity rules (LOW < $5K, MEDIUM $5K-$50K, HIGH >$50K) are our design, not client's
- If client has existing criteria that conflict: Agent classifications won't match specialist expectations, high override rate
- If no documented criteria exist: Our rules become the standard, but need buy-in
- Affects specialist trust: If agent matches their mental model, trust builds faster

**Discovery Method:**
1. Interview 5 specialists: "Walk me through how you decide if a claim is routine vs needs senior adjuster"
2. Card sorting exercise: Give specialists 20 anonymized claim descriptions, ask them to sort into LOW/MEDIUM/HIGH
3. Analyze sorting: What factors drove their decisions? Value? Injury? Policy type? Something else?
4. Review: Are there documented triage guidelines in training materials or procedure manuals?
5. Compare: Our rules vs their criteria, identify mismatches

**Urgency:** High
- **Must know before**: Finalizing severity classification logic
- **Blocks**: Delegation boundary definition (what's "routine" is subjective without client input)

---

### U3: Client's Risk Appetite for Automation Errors

**Question:**
What error rate is acceptable for automated triage/routing?
- Is 5% routing error rate acceptable (current is 18%, agent targets <5%)?
- Is 10% false negative rate on HIGH severity claims acceptable (agent misses 10% of high-value claims)?
- What's the cost/impact of a mis-triaged HIGH claim routed to junior adjuster?

**Why It Matters:**
- Determines escalation thresholds: If client is risk-averse, set confidence threshold at 0.8 (more escalations, safer)
- If client prioritizes efficiency over perfection: Set threshold at 0.6 (fewer escalations, higher throughput)
- Informs success metrics: "Routing accuracy >95%" assumes 5% error is acceptable

**Discovery Method:**
1. Interview claims director: "Would you rather have 5% wrong routing with 95% automation, or 2% wrong with 70% automation?"
2. Present trade-off scenarios: "Agent can process 70% autonomously with 5% error, or 50% autonomously with 2% error. Which do you prefer?"
3. Analyze: What's the cost of a mis-routed claim? (adjuster time wasted, claimant delay, reputation risk)
4. Review historical errors: What happened when specialists made routing errors? How severe were consequences?
5. Discuss: Regulatory/compliance tolerance for automation errors

**Urgency:** High
- **Must know before**: Setting confidence thresholds in decision logic
- **Blocks**: Escalation strategy (threshold determines escalation rate, which determines specialist workload)

---

### U4: Most Common Policy Exclusion Clauses

**Question:**
What exclusion clauses appear most frequently in the client's policies? What's the typical language used? Are there standard exclusions (e.g., DUI, intentional damage, acts of God) or highly customized clauses?

**Why It Matters:**
- Agent flags exclusions for specialist review but doesn't interpret them (human-led per delegation)
- NLP training: Need sample exclusion language to train keyword detection ("intentional", "DUI", "pre-existing condition")
- If exclusions are rare (<5% of claims): Simple keyword matching sufficient
- If exclusions are common (>20% of claims) and complex: May need more sophisticated NLP or always-escalate-if-exclusions policy

**Discovery Method:**
1. Request sample policies: 10-20 anonymized policies across STANDARD, COMMERCIAL, HIGH_VALUE types
2. Extract exclusion clauses: What language is used? How many exclusions per policy (0, 5, 20)?
3. Interview specialists: "What exclusions do you see most often? Which are hardest to interpret?"
4. Analyze past claims: How many claims were affected by exclusions? Which exclusions triggered most disputes?
5. Consult legal team: Are there exclusions that frequently lead to litigation?

**Urgency:** Medium
- **Must know before**: Finalizing NLP extraction logic for exclusion detection
- **Blocks**: Agent specification detail (exclusion handling strategy depends on frequency/complexity)

---

### U5: Current Specialist Workload Distribution

**Question:**
How do specialists currently spend their time? What % of their day is FNOL intake (triage + routing) vs downstream adjusting (claim investigation, negotiation, settlement)? Of FNOL intake, what % is truly routine (LOW) vs requires judgment (MEDIUM/HIGH)?

**Why It Matters:**
- ROI calculation assumes 68 hours/day freed (out of 96 total) for specialists to focus on downstream work
- If specialists currently spend 50% on FNOL, 50% on adjusting: Freeing FNOL time doubles adjusting capacity
- If specialists spend 20% on FNOL, 80% on adjusting: Freeing FNOL time has smaller impact
- Validates our 70% LOW / 25% MEDIUM / 5% HIGH assumption

**Discovery Method:**
1. Time study: Ask 3 specialists to log activities for 1 week (FNOL triage, policy lookup, routing, claimant calls, adjusting work)
2. Analyze: What % of time is FNOL vs adjusting? Within FNOL, what % is routine vs judgment calls?
3. Interview: "If you didn't have to do FNOL intake, what would you spend that time on?"
4. Review workload data: How many claims per specialist per day? How much time per claim?
5. Calculate: If FNOL is removed, can specialists handle more downstream claims? By how much?

**Urgency:** Medium
- **Must know before**: Finalizing ROI calculation and capacity planning
- **Blocks**: Success metrics (capacity impact depends on current workload distribution)

---

### U6: Adjuster Specialty Definitions and Overlap

**Question:**
How are adjuster specialties defined? Is there clear separation (AUTO adjusters only handle auto, PROPERTY only property), or is there overlap (AUTO adjusters can handle minor property claims)? Can adjusters have multiple specialties?

**Why It Matters:**
- Routing algorithm assumes strict specialty matching: AUTO claim → AUTO adjuster
- If there's flexibility: Can route to adjacent specialty when primary specialty at capacity (better load balancing)
- If multi-specialty common: Agent can optimize by selecting adjuster with lowest workload among all qualified
- Affects escalation rate: If no strict boundaries, fewer "no available adjuster" escalations

**Discovery Method:**
1. Interview HR/claims manager: "How do you assign specialties to adjusters? Can they have multiple?"
2. Review adjuster profiles in CRM: Do adjusters have one specialty or multiple listed?
3. Observe: Are there cases where AUTO adjuster handles PROPERTY claim? When and why?
4. Survey adjusters: "Would you be comfortable handling claims outside your primary specialty? Which types?"
5. Analyze historical routing: Do specialists ever manually re-assign between specialties? Why?

**Urgency:** Low
- **Must know before**: Finalizing routing algorithm (optimization opportunity if flexibility exists)
- **Blocks**: None (design works with strict matching; flexibility is enhancement)

---

### U7: Policy Admin System Actual Capacity and SLA

**Question:**
What is the policy administration system's documented capacity, uptime SLA, and support contact? Is there a service level agreement (SLA) for response time? What's the escalation path if the system is down?

**Why It Matters:**
- Agent assumes system can handle 300+ concurrent requests, but this is unvalidated
- If system has undocumented capacity limit (e.g., 50 concurrent): Need request throttling queue
- If uptime SLA is <99%: Expect frequent "policy system unavailable" escalations, need caching strategy
- If no support contact: When system is down, who do we call?

**Discovery Method:**
1. Request system documentation from IT team: Capacity specs, SLA, API rate limits
2. Interview system administrator: "What's the max concurrent requests you've seen? Any throttling?"
3. Review incident history: How often is system unavailable? Typical outage duration?
4. Load test (with IT approval): Gradually increase concurrent requests until response degrades
5. Establish: Escalation contact for production issues (24/7 support? Business hours only?)

**Urgency:** High
- **Must know before**: Production deployment (system outage plan requires support contact)
- **Blocks**: Integration testing (need to know safe load test limits)

---

### U8: Actual Cost Per FNOL Processed Today

**Question:**
What is the current fully-loaded cost per FNOL claim processed? We estimated $13/claim ($780K salary ÷ 300 claims/day ÷ 250 days), but actual cost includes benefits, overhead, tools, facilities.

**Why It Matters:**
- ROI calculation ($550K savings) depends on accurate baseline cost
- If actual cost is $20/claim: Savings are $1M+/year (even better ROI)
- If actual cost is $8/claim: Savings are $300K/year (lower but still positive)
- Informs business case: How much can client invest in agent development?

**Discovery Method:**
1. Request financial data from finance team: Total FNOL department budget (salaries, benefits, tools, overhead)
2. Calculate: Total annual cost ÷ annual claims volume = cost per claim
3. Interview operations manager: "Are there hidden costs we're missing?" (training, turnover, overtime)
4. Benchmark: Industry averages for FNOL processing cost (insurance industry reports)
5. Sensitivity analysis: At what cost does ROI become unattractive?

**Urgency:** Low
- **Must know before**: Presenting business case to leadership
- **Blocks**: None (design is independent of cost; this affects buy-in, not buildability)

---

### U9: Applicable Compliance and Regulatory Requirements

**Question:**
What compliance requirements apply to automated claim processing? Are there state insurance regulations that mandate human review for certain claim types/values? Are there audit/documentation requirements? Any prohibitions on AI decision-making?

**Why It Matters:**
- Some states require human adjuster sign-off on all claim decisions (cannot be fully agentic)
- If documentation standards require human signature: Agent can triage but specialist must approve
- If AI use must be disclosed to claimants: Need to add disclosure to acknowledgment message
- Regulatory non-compliance is unacceptable risk (fines, loss of license)

**Discovery Method:**
1. Interview legal/compliance team: "What regulations apply to FNOL automation?"
2. Review state insurance department requirements (varies by state if multi-state operation)
3. Consult: Industry associations (NAIC model regulations on AI in insurance)
4. Check: Are there internal compliance policies beyond legal requirements?
5. Document: What audit trail/documentation is required for regulatory inspection?

**Urgency:** High
- **Must know before**: Finalizing delegation boundaries (regulatory requirements override design preferences)
- **Blocks**: Cannot deploy agent in violation of regulations

---

### U10: Acceptable False Negative Rate for HIGH Severity Claims

**Question:**
What is the acceptable rate of HIGH severity claims being mis-triaged as MEDIUM (false negatives)? If agent classifies a $60K serious injury claim as MEDIUM (routes to intermediate adjuster instead of senior), how often can this happen before it's unacceptable?

**Why It Matters:**
- Trade-off: Lower confidence threshold (0.6) = more automation but higher false negative rate
- Higher confidence threshold (0.9) = fewer false negatives but more escalations (lower throughput)
- Determines: Should we be conservative (escalate on any doubt) or aggressive (trust NLP extraction)?
- Affects: Validation design (how do we detect false negatives that slip through?)

**Discovery Method:**
1. Interview claims director: "If agent routes 100 HIGH claims and 5 go to wrong adjuster, is that acceptable?"
2. Present scenarios: "Serious injury claim routed to intermediate adjuster. Adjuster catches it within 30 min. Acceptable?"
3. Analyze cost: What's the business impact of a false negative? (delayed service, potential litigation, reputation)
4. Compare to current: What's the current rate of specialists mis-triaging HIGH claims?
5. Set threshold: If current specialist error rate is 10%, agent matching that is acceptable; beating it is excellent

**Urgency:** Medium
- **Must know before**: Setting escalation confidence thresholds
- **Blocks**: Decision logic confidence scoring (threshold determines when to escalate vs proceed)

---

## 3. Assumptions vs Unknowns Summary

### Quick Reference Table

| ID | Type | Topic | Urgency | Status |
|----|------|-------|---------|--------|
| A1 | Assumption | 70% of claims are LOW severity | Medium | [Flagged] |
| A2 | Assumption | Severity thresholds ($5K, $50K, $100K) | Low | [Flagged] |
| A3 | Assumption | SOAP system can handle 300+ concurrent requests | Low | [Flagged] |
| A4 | Assumption | CRM provides real-time adjuster workload | Medium | [Assumed] |
| A5 | Assumption | CRM supports webhooks for new claims | Medium | [Assumed] |
| A6 | Assumption | Notification service handles 300/day | High | [Assumed] |
| A7 | Assumption | Claimants trust automated acknowledgment | Medium | [Flagged] |
| A8 | Assumption | Specialists trust agent decisions | Medium | [Flagged] |
| A9 | Assumption | FNOL reports have sufficient detail for NLP | Low | [Flagged] |
| A10 | Assumption | SOAP response time averages 3-5 seconds | Low | [Flagged] |
| U1 | Unknown | Actual format of FNOL reports by channel | High | Must discover |
| U2 | Unknown | Client's existing severity classification criteria | High | Must discover |
| U3 | Unknown | Client's risk appetite for automation errors | High | Must discover |
| U4 | Unknown | Most common policy exclusion clauses | Medium | Must discover |
| U5 | Unknown | Current specialist workload distribution | Medium | Must discover |
| U6 | Unknown | Adjuster specialty definitions and overlap | Low | Must discover |
| U7 | Unknown | Policy system capacity and SLA | High | Must discover |
| U8 | Unknown | Actual cost per FNOL processed today | Low | Must discover |
| U9 | Unknown | Compliance and regulatory requirements | High | Must discover |
| U10 | Unknown | Acceptable false negative rate for HIGH claims | Medium | Must discover |

### Validation Priority

**Must validate before design finalization:**
- U1: FNOL report formats (blocks NLP design)
- U2: Existing severity criteria (blocks delegation boundaries)
- U3: Risk appetite (blocks confidence thresholds)
- U7: SOAP system capacity (blocks integration design)
- U9: Regulatory requirements (blocks deployment)

**Must validate before pilot:**
- A1: 70% LOW severity distribution (validates ROI)
- A3: SOAP concurrency (validates architecture)
- A9: NLP extraction accuracy (validates automation rate)
- A10: SOAP response time (validates timeout settings)

**Can validate during pilot:**
- A7: Claimant trust (measure satisfaction)
- A8: Specialist trust (measure override rate)
- U5: Workload distribution (observe actual time savings)
- U10: Acceptable false negative rate (measure and adjust)

---

## 4. Discovery Plan

### Phase 1: Pre-Design Discovery (Week 1-2)
**Goal:** Gather information needed to finalize specification

**Activities:**
1. Request sample FNOL reports (U1) - 30 per channel
2. Interview claims director (U2, U3) - severity criteria, risk appetite
3. Interview IT team (U7) - SOAP system capacity, SLA
4. Review regulatory requirements (U9) - compliance constraints
5. Request policy samples (U4) - exclusion clause analysis

**Deliverables:**
- Updated severity classification rules based on client criteria
- Validated NLP extraction feasibility with actual report samples
- Documented SOAP system capacity limits
- Compliance requirements integrated into design

### Phase 2: Design Validation (Week 3-4)
**Goal:** Validate assumptions before building

**Activities:**
1. Test NLP extraction on sample reports (A9) - measure confidence
2. Load test SOAP system (A3) - measure concurrent request capacity
3. Time study with specialists (U5) - measure current workload distribution
4. Interview adjusters (U6) - specialty definitions and flexibility
5. Financial analysis (U8) - actual cost per FNOL

**Deliverables:**
- Validated NLP extraction accuracy (>80% target)
- Confirmed SOAP system can handle load (or documented throttling need)
- Updated ROI calculation with actual costs
- Finalized routing algorithm with specialty flexibility

### Phase 3: Pilot Validation (Week 5-8)
**Goal:** Test assumptions in production with real users

**Activities:**
1. Process 10% of claims through agent (A1, A7, A8)
2. Measure: Severity distribution, claimant satisfaction, specialist override rate
3. A/B test: Automated acknowledgment vs human call (A7)
4. Monitor: SOAP latency, CRM data freshness, notification delivery (A4, A5, A6, A10)
5. Adjust: Confidence thresholds based on false negative rate (U10)

**Deliverables:**
- Validated severity distribution (actual % LOW/MEDIUM/HIGH)
- Measured specialist trust (override rate <10% target)
- Measured claimant satisfaction (no degradation target)
- Tuned confidence thresholds for production rollout

---

## 5. Risk Mitigation

### High-Risk Assumptions

**A1 (70% LOW severity):**
- **Risk:** If only 50% are LOW, ROI drops significantly
- **Mitigation:** Pilot with small sample first, measure actual distribution, adjust economics
- **Fallback:** Even 50% automation is valuable; adjust expectations

**A9 (NLP extraction accuracy):**
- **Risk:** If extraction consistently fails, automation infeasible
- **Mitigation:** Test on 100 sample reports before committing to design
- **Fallback:** If NLP fails, use structured intake form (add form-filling step before agent processes)

**U3 (Risk appetite):**
- **Risk:** If client is highly risk-averse, may demand 99% accuracy (unachievable)
- **Mitigation:** Set expectations early: "5% error is industry standard for automation"
- **Fallback:** Increase oversight (all claims reviewed by specialist), reduces throughput benefit

**U9 (Regulatory requirements):**
- **Risk:** Regulation may prohibit AI decision-making entirely
- **Mitigation:** Consult legal/compliance before design commitment
- **Fallback:** Agent becomes recommendation engine, not decision engine (all decisions human-approved)

### Unknown Discovery Failure

**If client cannot provide information (U1, U2, U5):**
- **Plan A:** Work with what's available, document gaps as ongoing discovery
- **Plan B:** Start with most conservative design (high escalation thresholds), adjust as we learn
- **Plan C:** Phased rollout: Start with web form claims only (most structured), expand to email/phone later

---


