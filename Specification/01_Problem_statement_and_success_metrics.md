# Problem Statement & Success Metrics
## FNOL Claims Processing - AI Agent Solution

---

## 1. Original Statement Received from Business

> A mid-size insurance company's claims team processes 300 first-notice-of-loss (FNOL) reports per day. Each report arrives as unstructured text (email, phone transcript, web form) and must be: triaged by severity, validated against policy coverage, routed to the appropriate adjuster, and acknowledged to the claimant — all within 2 hours of receipt. Currently, a team of 12 specialists handles this manually. Average handling time is 22 minutes per claim. Error rate on routing: 18%. SLA breach rate: 31%.
>
> The client wants to explore whether AI can handle most of this. They are open to full automation where appropriate but insist on human oversight for high-value or ambiguous claims. They have a modern CRM with APIs, a legacy policy administration system with SOAP endpoints, and a document management system. They have no AI infrastructure today.

---

## 2. Problem Statement: Claimant Perspective

### Context
When a claimant files a first-notice-of-loss report, they are typically experiencing a stressful event—an accident, property damage, injury, or loss. At this moment, they face:
- **Immediate uncertainty**: Am I covered? What happens next? Who should I contact?
- **Time-sensitive anxiety**: Claims often involve urgent situations (damaged vehicle needed for work, property requiring immediate repair, medical treatment)
- **Information vacuum**: No visibility into claim status, processing timeline, or next steps

### Current Pain Points

**Delayed acknowledgment:**
- With a **31% SLA breach rate**, approximately **93 claims per day** exceed the 2-hour response window
- Claimants waiting 2+ hours for initial contact experience heightened stress and uncertainty
- No interim communication leaves claimants wondering if their claim was received at all

**Lack of transparency:**
- No self-service visibility into claim status
- Claimants must call in to check status, adding to call center volume
- Unclear timeline expectations: "When will someone contact me? When will my claim be resolved?"

**Routing errors impact claimant experience:**
- **18% routing error rate** means ~54 claims/day are sent to the wrong adjuster
- Claimants receive delayed callbacks when claims must be re-routed
- May need to re-explain their situation to multiple adjusters (poor experience)

**Inconsistent service quality:**
- Different specialists may triage similar claims differently
- Response time varies significantly based on specialist availability and workload
- Claimants filing during peak periods wait longer

### Claimant Needs
1. **Immediate acknowledgment**: Confirmation that claim was received and is being processed
2. **Clear expectations**: What severity is my claim? What's the expected timeline? Who will contact me?
3. **Transparency**: Ability to check status without calling
4. **Correct routing first time**: Assigned to the right specialist who can help
5. **Human contact when needed**: Complex or high-value claims should reach a person who can answer questions

---

## 3. Problem Statement: Business Perspective

### Operational Capacity Crisis

**Current demand exceeds capacity:**
- **Available capacity**: 12 specialists × 8-hour workday × 60 minutes = 5,760 minutes/day (96 person-hours)
- **Required capacity**: 300 claims × 22 minutes/claim = 6,600 minutes/day (110 person-hours)
- **Shortfall**: 840 minutes/day (14 person-hours) - **team is operating at 115% of capacity**

**Consequences of over-capacity:**
- Specialists working overtime to keep up with volume
- **31% SLA breach rate** (93 claims/day) miss the 2-hour acknowledgment window
- Quality degradation: rushed triage leads to errors
- Employee burnout risk: sustained overload is unsustainable
- Cannot absorb volume growth: any increase in claim volume will worsen breaches

### Quality Problems

**High routing error rate:**
- **18% of claims** (~54/day) are routed to the wrong adjuster
- Each routing error creates:
  - Re-work: claim must be reviewed, re-triaged, re-routed
  - Delay: adds 30-60 minutes to processing time
  - Adjuster frustration: incorrect assignments disrupt workflow
  - Claimant dissatisfaction: delayed callbacks, repeated explanations

**Root causes of routing errors:**
- Specialists make judgment calls under time pressure
- Inconsistent interpretation of severity thresholds
- Incomplete policy validation due to time constraints
- Adjuster capacity/specialty not always visible at routing time

**Inconsistent triage quality:**
- No standardized severity scoring across specialists
- Edge cases handled differently by different specialists
- Policy coverage interpretation varies
- Error detection is reactive (discovered by adjusters, not at intake)

### Cost Structure

**Current annual cost of FNOL processing:**
- 12 FTE specialists @ $65K average salary = **$780,000/year**
- Plus benefits, overhead, tools: ~**$1,000,000/year total**

**Hidden costs:**
- Re-work from 18% routing errors: estimated 10% additional specialist time wasted
- SLA breach penalties/reputation damage: unquantified but material
- Missed opportunity cost: specialists doing repetitive triage instead of complex claim resolution
- Call center volume from claimants checking status: adds load to customer service

**Growth constraint:**
- Business forecasts 15-20% claim volume growth over next 2 years
- At current trajectory, would require hiring 2-3 additional FTEs (~$200K+/year)
- Hiring lag + training time = sustained SLA breaches during growth

### Regulatory & Compliance Risk

**SLA compliance:**
- 31% breach rate on 2-hour acknowledgment SLA exposes regulatory risk
- State insurance regulations may require timely claim acknowledgment
- Persistent non-compliance could trigger audits or penalties

**Audit trail gaps:**
- Manual processing has inconsistent documentation of triage decisions
- Difficult to demonstrate compliance with fair claims practices
- Limited ability to identify patterns in routing errors or bias

### Strategic Constraint

**Specialist talent misalignment:**
- FNOL triage is largely **cognitive work that is codifiable**: apply rules, check databases, route based on criteria
- Specialists are trained insurance professionals capable of complex claim resolution
- **70% of FNOL volume is routine**: standard coverage, clear severity, straightforward routing
- Current model uses expensive specialist time on low-value repetitive tasks

**Business opportunity:**
- If specialists could focus on the **30% complex/high-value claims**, throughput would improve
- AI handling routine 70% would free ~70 person-hours/day for higher-value work
- Could improve claim resolution times downstream (specialists less overloaded)

---

## 4. Success Metrics: Claimant Perspective

### Primary Metrics (Quantifiable, measurable within 6 months post-deployment)

| Metric | Current State | Target State | Measurement Method |
|--------|---------------|--------------|-------------------|
| **Time to acknowledgment** | 2+ hours (avg) | <5 minutes (95th percentile) | Timestamp: claim received → acknowledgment sent |
| **SLA compliance (claimant view)** | 69% within 2 hours | >95% within 5 minutes | % of claims acknowledged within SLA |
| **Routing accuracy (claimant experience)** | 82% correct first time | >95% correct first time | % of claims not requiring re-route |
| **Status transparency** | 0% self-service visibility | 100% real-time visibility | % of claimants able to check status without calling |
| **Human contact availability** | Variable, depends on specialist queue | 100% for escalated claims within 30 min | % of escalated claims contacted by human within 30 min |

### Secondary Metrics (Qualitative, measured via surveys post-deployment)

| Metric | Current Baseline | Target Improvement | Measurement Method |
|--------|------------------|-------------------|-------------------|
| **Claimant satisfaction (FNOL process)** | Baseline TBD | +15 points (NPS or CSAT) | Post-FNOL survey (7 days after filing) |
| **Perceived transparency** | Baseline TBD | +20 points | Survey: "I always knew the status of my claim" (agree %) |
| **Trust in process** | Baseline TBD | No degradation | Survey: "My claim was handled fairly" (agree %) |
| **Complaint rate** | Baseline TBD | -30% reduction | Complaints specifically about FNOL delays or routing |

### Key Experience Outcomes

**Immediate acknowledgment experience:**
- Claimant receives automated email/SMS within 5 minutes: "We received your claim [ID]. Your claim is categorized as [LOW/MEDIUM/HIGH] severity. Expected timeline: [X]. Your assigned adjuster is [Name], who will contact you by [time]."

**Transparency experience:**
- Claimant can check claim status via web portal or SMS bot: "Your claim was triaged on [date], validated for coverage on [date], assigned to [adjuster] on [date]. Next step: [X]."

**Correct routing experience:**
- Claimant receives callback from **the right specialist** on first attempt
- No need to re-explain situation to multiple adjusters

**Human escalation experience:**
- Complex/high-value claims receive human contact within 30 minutes
- Claimant does not experience "black box" AI for sensitive claims

---

## 5. Success Metrics: Business Perspective

### Primary Operational Metrics (Measured 6 months post-deployment)

| Metric | Current State | Target State | Business Impact |
|--------|---------------|--------------|-----------------|
| **Average handling time (routine claims)** | 22 minutes | <3 minutes (70% of volume) | 86% time reduction on 210 claims/day = ~68 hours/day freed |
| **Team capacity utilization** | 115% (over-capacity) | 85% (sustainable) | Team can handle current volume + 50% growth |
| **Routing error rate** | 18% (~54 claims/day) | <5% (~15 claims/day) | 72% reduction in re-work |
| **SLA compliance (business)** | 69% (31% breach) | >90% (<10% breach) | Regulatory compliance, reputation protection |
| **Claims processed per specialist per day** | 25 claims | 37 claims (with AI) | 48% productivity increase |

### Cost & Efficiency Metrics

| Metric | Current State | Target State | Annual Value |
|--------|---------------|--------------|--------------|
| **Cost per FNOL processed** | $1M ÷ 300/day ÷ 250 days = **~$13.33/claim** | **~$6/claim** (with AI automation) | $550K/year savings |
| **Specialist time on routine triage** | ~70 hours/day | ~20 hours/day | 50 hours/day freed for complex claims |
| **Avoidable headcount growth** | +2-3 FTEs needed for growth | 0 FTEs needed (AI scales) | $200K/year cost avoidance |
| **Re-work cost (routing errors)** | ~5.4 hours/day wasted | ~1.5 hours/day | ~4 hours/day recovered |

### Quality Metrics

| Metric | Current State | Target State | Measurement Method |
|--------|---------------|--------------|-------------------|
| **Triage consistency** | Variable by specialist | 100% consistent (AI applies same rules) | Audit of severity scoring across identical claim types |
| **Policy validation accuracy** | Assumed ~95% (untracked) | >98% (AI queries authoritative system) | Post-adjudication audit: was coverage determination correct? |
| **Escalation precision** | Unknown | >90% of escalated claims warrant human review | Adjuster feedback: was this escalation appropriate? |
| **Audit trail completeness** | ~60% (inconsistent documentation) | 100% (every decision logged) | % of claims with complete decision trail |

### Strategic Outcomes (12 months post-deployment)

**Capacity for growth:**
- Handle 450+ claims/day with same 12-person team (50% volume increase without headcount growth)
- Absorb forecasted 15-20% annual claim volume growth without additional hiring

**Specialist redeployment:**
- Specialists spend 70% of time on complex claims requiring human judgment
- Reduction in overtime and burnout
- Improved employee satisfaction (more meaningful work)

**Scalability:**
- AI agent scales linearly with volume (minimal marginal cost per additional claim)
- Can deploy to other lines of business (property, auto, commercial) after FNOL success

**Risk reduction:**
- Consistent application of triage rules reduces compliance risk
- Complete audit trail for regulatory review
- Early detection of fraud patterns (AI can flag anomalies)

### ROI Calculation (12-month view)

**Investment** (estimated):
- AI agent development & integration: $150K
- System integration (CRM, SOAP, DMS): $50K
- Training & change management: $30K
- Ongoing AI platform costs: $40K/year
- **Total Year 1 investment: ~$270K**

**Return** (annual):
- Cost reduction: $550K (efficiency gains)
- Cost avoidance: $200K (no additional hires for growth)
- Re-work reduction: ~$50K (routing error elimination)
- **Total annual benefit: ~$800K**

**Net ROI: ~$530K/year, payback period: 4-5 months**

---

## Assumptions Used to Create Success Metrics

**Assumption A1:** Routine claims (70% of volume) are algorithmically triageable
- **If wrong:** Success metrics for automation rate must be revised downward; ROI decreases
- **Validation needed:** Analyze 3 months of historical claims to confirm % distribution by complexity

**Assumption A2:** CRM API supports webhook subscription for real-time FNOL notification
- **If wrong:** Agent must poll; <5 min acknowledgment target may need adjustment
- **Validation needed:** Review CRM API documentation with IT team

**Assumption A3:** Legacy SOAP system can handle 300+ concurrent requests without degradation
- **If wrong:** Agent needs request throttling; processing time increases
- **Validation needed:** Load testing on policy admin system

**Assumption A4:** Claimants will trust automated acknowledgment vs human contact
- **If wrong:** Satisfaction scores may not improve despite faster response
- **Validation needed:** A/B test messaging: automated vs "your case is being reviewed by our team"

**Assumption A5:** $50K is appropriate threshold for "high-value" human oversight
- **If wrong:** Over-escalation (inefficiency) or under-escalation (risk)
- **Validation needed:** Historical analysis: at what claim value do routing errors or mis-triages become material risk?

---

## Success Definition Summary

**This AI agent solution succeeds if, within 6 months of deployment:**

- **Claimants** receive acknowledgment in <5 minutes (95th percentile) with clear next steps
- **95% of claimants** do not experience re-routing (correct assignment first time)
- **Agent autonomously processes** ≥200 routine claims/day with <5% error rate
- **12 specialists** sustainably handle 300+ claims/day (vs current 115% over-capacity)
- **SLA compliance** improves from 69% to >90%
- **Cost per claim** drops from $13/claim to ~$6/claim
- **ROI** achieved within 12 months (payback <5 months)

**This solution fails if:**
- Claimant satisfaction scores degrade (trust lost in automated process)
- Routing errors increase (AI performs worse than humans)
- High-value claims are auto-processed without human review (unacceptable risk)
- Agent requires >20% manual intervention rate (does not reduce specialist workload)

---


