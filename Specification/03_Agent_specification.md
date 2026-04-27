# Agent Specification
## FNOL Claims Processing Agent - Technical Implementation Specification

---

## 1. Purpose & Scope

### Agent Purpose
The FNOL Claims Processing Agent automates the intake, triage, validation, routing, and acknowledgment of first-notice-of-loss (FNOL) reports for an insurance company processing 300 claims per day.

### What the Agent Does
- Ingests FNOL reports from multiple channels (email, phone transcript, web form)
- Extracts structured data from unstructured text using NLP
- Classifies claims by severity (CRITICAL, HIGH, MEDIUM, LOW)
- Validates policy coverage against legacy policy administration system
- Routes claims to appropriate adjusters based on specialty, workload, and seniority
- Sends acknowledgment notifications to claimants via email/SMS
- Escalates complex, ambiguous, or high-value claims to human specialists
- Maintains complete audit trail of all decisions

### What the Agent Does NOT Do
- Make final decisions on HIGH/CRITICAL severity claims (human-led)
- Interpret policy exclusion clauses (requires specialist judgment)
- Negotiate claim settlements (human only)
- Override policy validation failures without human approval
- Process claims for inactive or expired policies (automatic rejection)
- Send claimant communications beyond initial acknowledgment (adjuster handles follow-up)

### Deployment Context
- Runs as a service integrated with company CRM (modern REST API)
- Connects to legacy policy administration system (SOAP)
- Processes claims 24/7 with 2-hour SLA for acknowledgment
- Operates with human oversight: specialists monitor dashboard and can override agent decisions
- Logging to centralized audit system for compliance

---

## 2. Core Entities

### Entity: Claim

**Purpose:** Represents a single FNOL report from receipt through routing to adjuster.

**Attributes:**
- `id`: UUID, primary key, immutable, generated on creation
- `claim_number`: string, format "CLM-YYYYMMDD-NNNN", generated on creation, immutable, unique
- `claimant_id`: UUID, foreign key to Claimant, required, immutable
- `policy_id`: UUID, foreign key to Policy, required, immutable
- `status`: enum [RECEIVED, EXTRACTED, TRIAGED, VALIDATED, ROUTED, ACKNOWLEDGED, ESCALATED, REJECTED], required, default RECEIVED
- `severity`: enum [LOW, MEDIUM, HIGH, CRITICAL], nullable until triaged
- `estimated_value`: decimal(10,2), range 0-10000000, nullable, currency USD
- `incident_type`: enum [AUTO_COLLISION_SINGLE, AUTO_COLLISION_MULTI, AUTO_COLLISION_HIT_RUN, PROPERTY_DAMAGE_MINOR, PROPERTY_DAMAGE_STRUCTURAL, PROPERTY_DAMAGE_TOTAL_LOSS, INJURY_MINOR, INJURY_SERIOUS, INJURY_FATAL, THEFT, VANDALISM, WEATHER_DAMAGE, FIRE, FLOOD, OTHER], nullable until extracted
- `incident_description`: text, max 5000 characters, required
- `incident_date`: ISO 8601 date, required, must be <= today, must be >= today - 365 days
- `incident_location`: string, max 500 characters, nullable
- `extraction_confidence`: float 0.0-1.0, set by extraction process, required after extraction
- `extraction_flags`: JSON object, stores low-confidence field names and reasons
- `assigned_adjuster_id`: UUID, foreign key to Adjuster, nullable
- `escalation_reason`: text, max 1000 characters, nullable, required if status = ESCALATED
- `rejection_reason`: text, max 1000 characters, nullable, required if status = REJECTED
- `policy_validation_result`: JSON object, stores policy system response
- `exclusion_flags`: boolean, default FALSE, set TRUE if policy exclusions detected
- `routing_confidence`: float 0.0-1.0, set during routing process
- `received_at`: ISO 8601 timestamp UTC, immutable, set on creation
- `extracted_at`: ISO 8601 timestamp UTC, nullable, set when extraction completes
- `triaged_at`: ISO 8601 timestamp UTC, nullable, set when severity assigned
- `validated_at`: ISO 8601 timestamp UTC, nullable, set when policy validation completes
- `routed_at`: ISO 8601 timestamp UTC, nullable, set when assigned to adjuster
- `acknowledged_at`: ISO 8601 timestamp UTC, nullable, set when claimant notification sent
- `sla_deadline`: ISO 8601 timestamp UTC, computed as received_at + 2 hours, immutable
- `sla_breach`: boolean, computed as (acknowledged_at > sla_deadline OR (acknowledged_at IS NULL AND now() > sla_deadline))
- `created_by`: string, "AGENT" or user identifier if manual entry
- `updated_at`: ISO 8601 timestamp UTC, updated on any modification
- `audit_log`: JSON array, append-only log of all state transitions with timestamps and reasons

**State Machine:**

```
RECEIVED → EXTRACTED
  Trigger: NLP extraction completes
  Preconditions: incident_description is non-null, extraction_confidence calculated
  Actions: Set extracted_at timestamp

EXTRACTED → TRIAGED
  Trigger: Severity classification completes
  Preconditions: severity is non-null, extraction_confidence >= 0.7
  Actions: Set triaged_at timestamp
  
EXTRACTED → ESCALATED
  Trigger: Extraction confidence < 0.7
  Preconditions: extraction_confidence < 0.7
  Actions: Set status = ESCALATED, escalation_reason = "Low extraction confidence: [field names]"

TRIAGED → VALIDATED
  Trigger: Policy validation succeeds
  Preconditions: policy_validation_result.status = ACTIVE, coverage confirmed
  Actions: Set validated_at timestamp

TRIAGED → REJECTED
  Trigger: Policy validation fails
  Preconditions: policy_validation_result.status IN [EXPIRED, CANCELLED, SUSPENDED] OR coverage not found
  Actions: Set status = REJECTED, rejection_reason = [specific reason from policy system]

TRIAGED → ESCALATED
  Trigger: HIGH or CRITICAL severity, or exclusion_flags = TRUE
  Preconditions: severity IN [HIGH, CRITICAL] OR exclusion_flags = TRUE
  Actions: Set status = ESCALATED, escalation_reason = [severity level or exclusion details]

VALIDATED → ROUTED
  Trigger: Adjuster assignment succeeds
  Preconditions: assigned_adjuster_id is non-null, routing_confidence >= 0.8
  Actions: Set routed_at timestamp, notify adjuster

VALIDATED → ESCALATED
  Trigger: No available adjuster matching criteria
  Preconditions: routing algorithm returns no candidates OR routing_confidence < 0.8
  Actions: Set status = ESCALATED, escalation_reason = "No available adjuster with required specialty"

ROUTED → ACKNOWLEDGED
  Trigger: Claimant notification sent successfully
  Preconditions: notification service returns success
  Actions: Set acknowledged_at timestamp

ROUTED → ESCALATED
  Trigger: Notification fails after retries
  Preconditions: notification service fails after 3 retry attempts
  Actions: Set status = ESCALATED, escalation_reason = "Unable to notify claimant"

ESCALATED → ROUTED
  Trigger: Specialist resolves escalation and assigns adjuster
  Preconditions: assigned_adjuster_id is non-null, escalation resolved by human
  Actions: Set routed_at timestamp, clear escalation_reason

REJECTED is terminal (no further transitions)
ACKNOWLEDGED is terminal (claim handed to adjuster for resolution)
```

**Constraints:**
- Cannot transition to TRIAGED if extraction_confidence < 0.7 (must escalate)
- Cannot transition to VALIDATED if policy_id references non-existent policy
- Cannot transition to ROUTED if assigned_adjuster_id is null
- Cannot transition to ACKNOWLEDGED if acknowledged_at is null
- severity must be non-null before transitioning to VALIDATED
- If status = ESCALATED, escalation_reason must be non-null (minimum 10 characters)
- If status = REJECTED, rejection_reason must be non-null (minimum 10 characters)
- incident_date must be within past 365 days (stale claims rejected)
- estimated_value cannot be negative
- All timestamps immutable once set (except updated_at)

---

### Entity: Claimant

**Purpose:** Represents the person filing the FNOL claim.

**Attributes:**
- `id`: UUID, primary key, immutable
- `policy_holder_id`: UUID, foreign key to PolicyHolder (may differ from claimant if third-party claim)
- `first_name`: string, max 100 characters, required
- `last_name`: string, max 100 characters, required
- `email`: string, max 255 characters, required, format validated via RFC 5322
- `phone`: string, max 20 characters, required, format E.164 or US domestic (XXX-XXX-XXXX)
- `alternate_phone`: string, max 20 characters, nullable
- `preferred_contact_method`: enum [EMAIL, PHONE, SMS], default EMAIL
- `vip_status`: boolean, default FALSE (set TRUE for board members, executives, high-net-worth policyholders)
- `language_preference`: enum [EN, ES, FR], default EN
- `created_at`: ISO 8601 timestamp UTC, immutable
- `updated_at`: ISO 8601 timestamp UTC

**Validation Rules:**
- email must match regex: `^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`
- phone must match E.164 format `+1XXXXXXXXXX` or US format `XXX-XXX-XXXX`
- At least one contact method (email or phone) must be valid
- If preferred_contact_method = SMS, phone must be non-null

---

### Entity: Policy

**Purpose:** Represents insurance policy coverage details (cached from policy admin system).

**Attributes:**
- `id`: UUID, primary key, immutable
- `policy_number`: string, format "POL-NNNNNNNN", required, unique, immutable
- `policy_holder_id`: UUID, foreign key to PolicyHolder, required
- `status`: enum [ACTIVE, EXPIRED, CANCELLED, SUSPENDED], required
- `policy_type`: enum [STANDARD, COMMERCIAL, HIGH_VALUE, UMBRELLA], required
- `effective_date`: ISO 8601 date, required
- `expiration_date`: ISO 8601 date, required
- `coverage_types`: JSON array of enum [AUTO_LIABILITY, AUTO_COLLISION, AUTO_COMPREHENSIVE, PROPERTY, INJURY, THEFT, WEATHER], required, minimum 1 element
- `coverage_limit`: decimal(12,2), required, minimum 0
- `deductible`: decimal(10,2), required, minimum 0
- `exclusions`: JSON array of strings (free text exclusion clauses), nullable, default []
- `last_validated_at`: ISO 8601 timestamp UTC, updated when policy validation API called
- `cached_at`: ISO 8601 timestamp UTC, time when this record was cached from policy system
- `cache_ttl`: integer seconds, default 3600 (1 hour cache lifetime)

**Computed Fields:**
- `is_cache_valid`: boolean, computed as (now() - cached_at) < cache_ttl
- `is_active_for_date(date)`: boolean, computed as status = ACTIVE AND effective_date <= date <= expiration_date

**Validation Rules:**
- expiration_date must be > effective_date
- If status = ACTIVE, expiration_date must be >= today
- coverage_limit must be >= deductible
- exclusions array can be empty but not null

---

### Entity: Adjuster

**Purpose:** Represents claims adjusters who handle assigned claims.

**Attributes:**
- `id`: UUID, primary key, immutable
- `employee_id`: string, format "EMP-NNNN", required, unique
- `first_name`: string, max 100 characters, required
- `last_name`: string, max 100 characters, required
- `email`: string, max 255 characters, required
- `phone`: string, max 20 characters, required
- `specialties`: JSON array of enum [AUTO, PROPERTY, INJURY, COMMERCIAL, WEATHER, THEFT], required, minimum 1 element
- `seniority_level`: enum [JUNIOR, INTERMEDIATE, SENIOR, PRINCIPAL], required
- `status`: enum [AVAILABLE, BUSY, ON_LEAVE, IN_TRAINING, INACTIVE], required, default AVAILABLE
- `current_workload`: integer, count of currently assigned claims with status IN [ROUTED, IN_PROGRESS], computed field, read-only
- `max_workload`: integer, maximum concurrent claims, default 15, range 1-25
- `is_available_for_high_value`: boolean, computed as seniority_level IN [SENIOR, PRINCIPAL]
- `updated_at`: ISO 8601 timestamp UTC

**Computed Fields:**
- `has_capacity`: boolean, computed as current_workload < max_workload AND status = AVAILABLE
- `workload_percentage`: float, computed as (current_workload / max_workload) * 100

**Validation Rules:**
- current_workload cannot exceed max_workload (enforced by routing algorithm)
- If status != AVAILABLE, cannot be assigned new claims
- specialties array must contain at least one value
- Only SENIOR or PRINCIPAL adjusters can be assigned HIGH or CRITICAL claims

---

### Entity: ExtractionResult

**Purpose:** Stores raw extraction output from NLP processing for audit and confidence tracking.

**Attributes:**
- `id`: UUID, primary key, immutable
- `claim_id`: UUID, foreign key to Claim, required, immutable
- `raw_input_text`: text, max 10000 characters, the original unstructured input
- `extraction_method`: enum [NLP_LLM, REGEX_PATTERN, WEB_FORM_STRUCTURED], required
- `extracted_fields`: JSON object with keys:
  - `claimant_name`: {value: string, confidence: float}
  - `policy_number`: {value: string, confidence: float}
  - `incident_date`: {value: ISO 8601 date, confidence: float}
  - `incident_type`: {value: enum, confidence: float}
  - `estimated_value`: {value: decimal, confidence: float}
  - `injury_indicator`: {value: boolean, confidence: float}
  - `injury_severity`: {value: enum, confidence: float}
  - `incident_description_clean`: {value: text, confidence: float}
- `overall_confidence`: float 0.0-1.0, minimum of all field confidence scores
- `low_confidence_fields`: JSON array of field names where confidence < 0.7
- `extraction_warnings`: JSON array of strings, human-readable warnings (e.g., "Policy number format invalid", "Incident date is in future")
- `extracted_at`: ISO 8601 timestamp UTC, immutable
- `processing_time_ms`: integer, time taken for extraction in milliseconds

**Validation Rules:**
- overall_confidence must be <= minimum(all field confidence scores)
- If extraction_method = WEB_FORM_STRUCTURED, all confidence scores should be 1.0
- If low_confidence_fields array is non-empty, overall_confidence must be < 0.7
- extracted_fields must contain all required keys (claimant_name through injury_severity)

---

## 3. Integration Contracts

### Integration 1: CRM API (Modern REST)

**Purpose:** Ingest FNOL reports and manage adjuster assignments.

#### Endpoint 1a: Ingest New FNOL Report

**Endpoint:** `POST /api/v2/claims/fnol`  
**Base URL:** `https://crm.company.internal`  
**Authentication:** Bearer token in Authorization header
- Token stored in secrets manager (key: `CRM_API_TOKEN`)
- Token refreshed every 24 hours via OAuth 2.0 client credentials flow
- Never log token

**Request Headers:**
```
Authorization: Bearer {token}
Content-Type: application/json
X-Request-ID: {UUID} (generated per request for tracing)
```

**Request Body (JSON):**
```json
{
  "source_channel": "enum [EMAIL, PHONE, WEB_FORM]",
  "raw_content": "string, max 10000 chars, the unstructured report text",
  "claimant_email": "string, optional if phone provided",
  "claimant_phone": "string, optional if email provided",
  "received_timestamp": "ISO 8601 timestamp UTC",
  "policy_number": "string, optional if not extracted yet",
  "attachments": [
    {
      "filename": "string",
      "url": "string, URL to document in DMS",
      "file_type": "enum [PDF, JPG, PNG, DOC]"
    }
  ]
}
```

**Success Response (HTTP 201):**
```json
{
  "claim_id": "UUID",
  "claim_number": "string, format CLM-YYYYMMDD-NNNN",
  "status": "RECEIVED",
  "received_at": "ISO 8601 timestamp UTC",
  "sla_deadline": "ISO 8601 timestamp UTC"
}
```

**Error Responses:**
```
HTTP 400 Bad Request:
{
  "error_code": "INVALID_REQUEST",
  "message": "Missing required field: raw_content",
  "field": "raw_content"
}

HTTP 401 Unauthorized:
{
  "error_code": "INVALID_TOKEN",
  "message": "Bearer token expired or invalid"
}

HTTP 429 Too Many Requests:
{
  "error_code": "RATE_LIMIT_EXCEEDED",
  "message": "Rate limit of 100 requests/minute exceeded",
  "retry_after_seconds": 30
}

HTTP 500 Internal Server Error:
{
  "error_code": "INTERNAL_ERROR",
  "message": "CRM service temporarily unavailable"
}
```

**Timeout:** 5 seconds  
**Retry Logic:**
- HTTP 5xx or timeout: retry up to 3 times with exponential backoff (1s, 2s, 4s)
- HTTP 429: wait retry_after_seconds, then retry once
- HTTP 4xx (except 429): do NOT retry, return error to caller
- After exhausting retries: log error, queue claim for manual intake, alert operations

**Rate Limits:** 100 requests per minute per API token  
**Idempotency:** Use X-Request-ID header; duplicate IDs within 5 minutes return cached response

---

#### Endpoint 1b: Assign Claim to Adjuster

**Endpoint:** `POST /api/v2/claims/{claim_id}/assign`  
**Base URL:** `https://crm.company.internal`  
**Authentication:** Bearer token (same as 1a)

**Request Body (JSON):**
```json
{
  "adjuster_id": "UUID, required",
  "assigned_by": "string, 'AGENT' or user identifier",
  "assignment_reason": "string, optional, human-readable explanation",
  "priority": "enum [ROUTINE, URGENT, CRITICAL], default ROUTINE"
}
```

**Success Response (HTTP 200):**
```json
{
  "claim_id": "UUID",
  "adjuster_id": "UUID",
  "assigned_at": "ISO 8601 timestamp UTC",
  "notification_sent": "boolean, true if adjuster was notified"
}
```

**Error Responses:**
```
HTTP 404 Not Found:
{
  "error_code": "CLAIM_NOT_FOUND",
  "message": "Claim with ID {claim_id} does not exist"
}

HTTP 409 Conflict:
{
  "error_code": "ALREADY_ASSIGNED",
  "message": "Claim is already assigned to adjuster {adjuster_id}",
  "current_adjuster_id": "UUID"
}

HTTP 422 Unprocessable Entity:
{
  "error_code": "ADJUSTER_UNAVAILABLE",
  "message": "Adjuster is not available (status: ON_LEAVE)",
  "adjuster_status": "ON_LEAVE"
}
```

**Timeout:** 3 seconds  
**Retry Logic:** Same as 1a  
**Idempotency:** Assigning same adjuster_id to same claim_id is idempotent (returns 200)

---

#### Endpoint 1c: Get Available Adjusters

**Endpoint:** `GET /api/v2/adjusters/available`  
**Base URL:** `https://crm.company.internal`  
**Authentication:** Bearer token (same as 1a)

**Query Parameters:**
```
specialty: enum [AUTO, PROPERTY, INJURY, COMMERCIAL, WEATHER, THEFT], optional
seniority: enum [JUNIOR, INTERMEDIATE, SENIOR, PRINCIPAL], optional
max_workload: integer, optional, return only adjusters with current_workload < this value
```

**Success Response (HTTP 200):**
```json
{
  "adjusters": [
    {
      "adjuster_id": "UUID",
      "name": "string, full name",
      "specialties": ["AUTO", "INJURY"],
      "seniority_level": "SENIOR",
      "current_workload": 8,
      "max_workload": 15,
      "has_capacity": true
    }
  ],
  "total_count": 12
}
```

**Timeout:** 2 seconds  
**Retry Logic:** Same as 1a  
**Caching:** Cache results for 30 seconds (workload changes frequently)

---

### Integration 2: Policy Administration System (Legacy SOAP)

**Purpose:** Validate policy status and coverage for incoming claims.

**Endpoint:** `https://policy-admin.company.internal/soap/PolicyService`  
**Protocol:** SOAP 1.2  
**Authentication:** WS-Security UsernameToken
- Username stored in secrets manager (key: `POLICY_SYSTEM_USERNAME`)
- Password stored in secrets manager (key: `POLICY_SYSTEM_PASSWORD`)
- Never log credentials

**SOAP Action:** `http://company.internal/policy/v2/GetPolicyCoverage`

**Request Envelope (XML):**
```xml
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" 
                   xmlns:pol="http://company.internal/policy/v2"
                   xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
   <soapenv:Header>
      <wsse:Security>
         <wsse:UsernameToken>
            <wsse:Username>{username}</wsse:Username>
            <wsse:Password Type="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordText">{password}</wsse:Password>
         </wsse:UsernameToken>
      </wsse:Security>
   </soapenv:Header>
   <soapenv:Body>
      <pol:GetPolicyCoverage>
         <pol:PolicyNumber>string, required, format POL-NNNNNNNN</pol:PolicyNumber>
         <pol:EffectiveDate>ISO 8601 date, required, the incident date</pol:EffectiveDate>
      </pol:GetPolicyCoverage>
   </soapenv:Body>
</soapenv:Envelope>
```

**Success Response (HTTP 200, XML):**
```xml
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
   <soapenv:Body>
      <pol:CoverageResponse xmlns:pol="http://company.internal/policy/v2">
         <pol:PolicyNumber>string</pol:PolicyNumber>
         <pol:PolicyStatus>enum [ACTIVE, EXPIRED, CANCELLED, SUSPENDED]</pol:PolicyStatus>
         <pol:PolicyType>enum [STANDARD, COMMERCIAL, HIGH_VALUE, UMBRELLA]</pol:PolicyType>
         <pol:EffectiveDate>ISO 8601 date</pol:EffectiveDate>
         <pol:ExpirationDate>ISO 8601 date</pol:ExpirationDate>
         <pol:CoverageTypes>
            <pol:Coverage>AUTO_LIABILITY</pol:Coverage>
            <pol:Coverage>AUTO_COLLISION</pol:Coverage>
            <!-- array, 1 or more Coverage elements -->
         </pol:CoverageTypes>
         <pol:CoverageLimit>decimal, max coverage amount</pol:CoverageLimit>
         <pol:Deductible>decimal</pol:Deductible>
         <pol:Exclusions>
            <pol:Exclusion>
               <pol:Code>string, e.g. "EXCLUSION_DUI"</pol:Code>
               <pol:Description>string, human-readable clause text</pol:Description>
            </pol:Exclusion>
            <!-- array, 0 or more Exclusion elements -->
         </pol:Exclusions>
      </pol:CoverageResponse>
   </soapenv:Body>
</soapenv:Envelope>
```

**SOAP Fault Responses:**
```xml
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
   <soapenv:Body>
      <soapenv:Fault>
         <faultcode>pol:PolicyNotFound</faultcode>
         <faultstring>Policy number POL-12345678 not found in system</faultstring>
      </soapenv:Fault>
   </soapenv:Body>
</soapenv:Envelope>

Other fault codes:
- pol:InvalidDate (incident date format invalid or in future)
- pol:SystemError (database unavailable, internal error)
- pol:AuthenticationFailed (invalid credentials)
```

**HTTP Error Responses:**
```
HTTP 500 Internal Server Error:
<soapenv:Fault>
   <faultcode>pol:SystemError</faultcode>
   <faultstring>Policy database temporarily unavailable</faultstring>
</soapenv:Fault>

HTTP 401 Unauthorized:
Authentication failure (invalid WS-Security token)
```

**Timeout:** 8 seconds (legacy system is slow)  
**Retry Logic:**
- HTTP 5xx or timeout: retry up to 2 times with exponential backoff (2s, 4s)
- SOAP Fault with faultcode = SystemError: retry up to 2 times
- SOAP Fault with faultcode = PolicyNotFound: do NOT retry (policy doesn't exist)
- SOAP Fault with faultcode = InvalidDate: do NOT retry (client error)
- SOAP Fault with faultcode = AuthenticationFailed: do NOT retry, alert operations (credentials expired)
- After exhausting retries: escalate claim with reason "Policy validation system unavailable"

**Rate Limits:** Unknown - assumed legacy system can handle 300+ concurrent requests during business hours. Monitor for degradation. Flag as assumption A4 in spec.

**Data Mapping:**
```
Internal → SOAP Request:
- Claim.policy_id → lookup Policy.policy_number → format as POL-{8 digits}
- Claim.incident_date → pol:EffectiveDate

SOAP Response → Internal:
- pol:PolicyStatus → Policy.status (direct enum mapping)
- pol:PolicyType → Policy.policy_type
- pol:CoverageTypes array → Policy.coverage_types (array of enums)
- pol:CoverageLimit → Policy.coverage_limit
- pol:Exclusions → Policy.exclusions (array of objects)
- If Exclusions array length > 0: set Claim.exclusion_flags = TRUE
```

**Fallback Behavior:**
If policy validation fails after all retries:
1. Set Claim.status = ESCALATED
2. Set Claim.escalation_reason = "Policy validation system unavailable - unable to verify coverage. System error: {error details}. Manual validation required."
3. Assign to specialist queue (highest priority)
4. Do NOT acknowledge to claimant until validation completes
5. Alert operations team via monitoring system
6. Log incident for SLA tracking (system downtime, not agent failure)

---

### Integration 3: Document Management System (DMS)

**Purpose:** Retrieve attachments (photos, documents) associated with FNOL reports.

**Endpoint:** `GET /api/documents/{document_id}`  
**Base URL:** `https://dms.company.internal`  
**Authentication:** API Key in X-API-Key header
- Key stored in secrets manager (key: `DMS_API_KEY`)

**Request Headers:**
```
X-API-Key: {api_key}
Accept: application/octet-stream
```

**Success Response (HTTP 200):**
- Body: Binary file content
- Headers:
  - `Content-Type: image/jpeg` (or appropriate MIME type)
  - `Content-Disposition: attachment; filename="photo.jpg"`
  - `Content-Length: {bytes}`

**Error Responses:**
```
HTTP 404 Not Found:
{
  "error_code": "DOCUMENT_NOT_FOUND",
  "message": "Document {document_id} does not exist or has been deleted"
}

HTTP 403 Forbidden:
{
  "error_code": "ACCESS_DENIED",
  "message": "API key does not have permission to access this document"
}
```

**Timeout:** 10 seconds (documents can be large)  
**Retry Logic:**
- HTTP 5xx or timeout: retry up to 2 times
- HTTP 404 or 403: do NOT retry
- If retrieval fails: log error, proceed with claim processing without attachment (attachment not blocking)

**Rate Limits:** 200 requests per minute  
**Usage Note:** Document retrieval is optional for agent processing. Agent does not analyze image content (no CV/OCR in scope). Documents are passed through to adjuster for review.

---

### Integration 4: Notification Service (Email/SMS)

**Purpose:** Send acknowledgment notifications to claimants.

**Endpoint:** `POST /api/v1/notifications/send`  
**Base URL:** `https://notifications.company.internal`  
**Authentication:** Bearer token (separate from CRM)
- Token stored in secrets manager (key: `NOTIFICATION_SERVICE_TOKEN`)

**Request Body (JSON):**
```json
{
  "recipient": {
    "email": "string, optional if phone provided",
    "phone": "string, E.164 format, optional if email provided"
  },
  "channel": "enum [EMAIL, SMS, BOTH], required",
  "template_id": "string, template identifier, e.g. 'FNOL_ACKNOWLEDGMENT_V2'",
  "variables": {
    "claimant_name": "string",
    "claim_number": "string",
    "claim_id": "UUID",
    "severity": "string",
    "adjuster_name": "string",
    "adjuster_phone": "string",
    "expected_contact_time": "string, human-readable, e.g. 'within 24 hours'"
  },
  "priority": "enum [NORMAL, HIGH], default NORMAL",
  "idempotency_key": "UUID, prevents duplicate sends"
}
```

**Success Response (HTTP 200):**
```json
{
  "notification_id": "UUID",
  "status": "SENT",
  "sent_at": "ISO 8601 timestamp UTC",
  "channels_used": ["EMAIL"],
  "delivery_status": {
    "email": {
      "delivered": true,
      "delivered_at": "ISO 8601 timestamp UTC"
    }
  }
}
```

**Error Responses:**
```
HTTP 400 Bad Request:
{
  "error_code": "INVALID_RECIPIENT",
  "message": "Email format invalid: {email}"
}

HTTP 404 Not Found:
{
  "error_code": "TEMPLATE_NOT_FOUND",
  "message": "Template ID 'FNOL_ACKNOWLEDGMENT_V2' does not exist"
}

HTTP 429 Too Many Requests:
{
  "error_code": "RATE_LIMIT_EXCEEDED",
  "retry_after_seconds": 10
}

HTTP 500 Internal Server Error:
{
  "error_code": "DELIVERY_FAILED",
  "message": "Email service temporarily unavailable"
}
```

**Timeout:** 5 seconds  
**Retry Logic:**
- HTTP 5xx or timeout: retry up to 3 times with exponential backoff (1s, 2s, 4s)
- HTTP 429: wait retry_after_seconds, then retry once
- HTTP 4xx (except 429): do NOT retry (client error - bad email/phone format)
- After exhausting retries: escalate claim with reason "Unable to notify claimant - notification service unavailable"

**Rate Limits:** 500 notifications per minute  
**Idempotency:** Use idempotency_key (claim_id as key) to prevent duplicate notifications if retry occurs

**Template Variables (FNOL_ACKNOWLEDGMENT_V2):**
Email template example:
```
Subject: Your Claim {claim_number} Has Been Received

Dear {claimant_name},

We have received your claim (ID: {claim_number}) and it is being processed.

Claim Details:
- Severity: {severity}
- Assigned Adjuster: {adjuster_name}
- Adjuster Contact: {adjuster_phone}
- Expected Contact: {expected_contact_time}

You can track your claim status online at: https://claims.company.com/track/{claim_id}

If you have urgent questions, please contact your adjuster directly.

Thank you,
Claims Team
```

---

## 4. Decision Logic

### Decision 1: Data Extraction from Unstructured Text

**Purpose:** Parse unstructured FNOL report text and extract structured fields.

**Input:** 
- `raw_content`: string, the unstructured report (email body, phone transcript, web form text)
- `source_channel`: enum [EMAIL, PHONE, WEB_FORM]

**Process:**
1. Use NLP (LLM-based extraction) to identify and extract:
   - Claimant name (first + last)
   - Policy number (pattern: POL-NNNNNNNN or similar)
   - Incident date (parse date from text)
   - Incident type (classify into predefined enum based on keywords)
   - Estimated claim value (extract monetary amounts, e.g., "$5,000 damage")
   - Injury indicator (boolean: does text mention injury, hurt, hospital, etc.?)
   - Injury severity (if injury present, classify as MINOR, SERIOUS, FATAL)
   - Incident description (cleaned, summarized version)

2. For each extracted field, calculate confidence score (0.0-1.0):
   - 1.0: Exact match with clear context (e.g., "Policy Number: POL-12345678")
   - 0.9: High confidence match with minor ambiguity (e.g., "policy POL-12345678")
   - 0.7: Moderate confidence, inferred from context (e.g., "I have policy 12345678" → add POL- prefix)
   - 0.5: Low confidence, multiple possible interpretations
   - 0.0: Field not found in text

3. Calculate overall_confidence = MIN(all field confidence scores)

4. Identify low_confidence_fields where confidence < 0.7

**Output:**
- `ExtractionResult` entity populated with all fields
- `overall_confidence` score
- If overall_confidence < 0.7: flag for human review

**Logic:**
```
IF source_channel = WEB_FORM AND all fields present in structured form
THEN
  confidence = 1.0 for all fields (no NLP needed, direct field mapping)
  
ELSE IF source_channel IN [EMAIL, PHONE]
THEN
  Apply NLP extraction:
  
  FOR EACH required_field IN [claimant_name, policy_number, incident_date, incident_type, estimated_value]
    extracted_value, confidence = NLP_extract(raw_content, field_type=required_field)
    
    IF confidence < 0.7
      add to low_confidence_fields
      add warning: "{field} could not be reliably extracted - confidence {confidence}"
    END IF
  END FOR
  
  overall_confidence = MIN(all field confidence scores)
  
  IF overall_confidence < 0.7
    escalation_needed = TRUE
    escalation_reason = "Low extraction confidence on fields: {low_confidence_fields}"
  END IF
END IF

RETURN ExtractionResult
```

**Escalation Trigger:**
- overall_confidence < 0.7 → Set Claim.status = ESCALATED, specialist reviews and corrects extraction

**Edge Cases:**
- Multiple policy numbers in text → extract first, flag ambiguity
- Multiple dates → select date closest to present (assume incident is recent)
- No monetary amount found → set estimated_value = NULL, confidence = 0.0
- Ambiguous injury language ("hurt my back a little") → classify as MINOR, confidence = 0.6

---

### Decision 2: Severity Classification

**Purpose:** Assign severity level (CRITICAL, HIGH, MEDIUM, LOW) based on claim characteristics.

**Input:**
- `estimated_value`: decimal, nullable
- `injury_severity`: enum [NONE, MINOR, SERIOUS, FATAL], nullable
- `policy_type`: enum [STANDARD, COMMERCIAL, HIGH_VALUE, UMBRELLA]
- `incident_type`: enum
- `exclusion_flags`: boolean
- `claimant_vip_status`: boolean

**Logic:**
```
severity = NULL
confidence = 1.0

# CRITICAL Severity
IF estimated_value > 100000
   OR injury_severity = FATAL
   OR incident_type IN [MULTI_PARTY_LIABILITY, PRODUCT_LIABILITY]
   OR claimant_vip_status = TRUE
THEN
  severity = CRITICAL
  confidence = 1.0
  escalation_needed = TRUE (human-led per delegation analysis)
  RETURN severity, confidence, escalation_needed
END IF

# HIGH Severity
IF estimated_value > 50000
   OR injury_severity IN [SERIOUS, HOSPITALIZED]
   OR policy_type IN [COMMERCIAL, HIGH_VALUE]
   OR exclusion_flags = TRUE
THEN
  severity = HIGH
  confidence = 1.0
  escalation_needed = TRUE (human-led per delegation analysis)
  RETURN severity, confidence, escalation_needed
END IF

# MEDIUM Severity
IF (estimated_value >= 5000 AND estimated_value <= 50000)
   OR injury_severity = MINOR
   OR incident_type IN [AUTO_COLLISION_MULTI, PROPERTY_DAMAGE_STRUCTURAL, FIRE]
THEN
  severity = MEDIUM
  confidence = 1.0
  escalation_needed = FALSE (agent-led with oversight)
  RETURN severity, confidence, escalation_needed
END IF

# LOW Severity
IF estimated_value < 5000
   AND injury_severity IN [NONE, NULL]
   AND policy_type = STANDARD
   AND incident_type IN [AUTO_COLLISION_SINGLE, PROPERTY_DAMAGE_MINOR, WINDSHIELD_REPLACEMENT, MINOR_THEFT]
THEN
  severity = LOW
  confidence = 1.0
  escalation_needed = FALSE (fully agentic)
  RETURN severity, confidence, escalation_needed
END IF

# Ambiguous case (insufficient data or borderline values)
IF estimated_value IS NULL AND injury_severity IS NULL
THEN
  severity = MEDIUM (default safe classification)
  confidence = 0.5 (low confidence due to missing data)
  escalation_needed = TRUE (escalate due to low confidence)
  RETURN severity, confidence, escalation_needed
END IF

# If none of the above match (edge case)
severity = MEDIUM (default)
confidence = 0.6
escalation_needed = TRUE
RETURN severity, confidence, escalation_needed
```

**Output:**
- `Claim.severity`: enum value
- `confidence`: float 0.0-1.0
- `escalation_needed`: boolean

**Escalation Triggers:**
- severity IN [HIGH, CRITICAL] → always escalate (human-led)
- confidence < 0.7 → escalate regardless of severity
- exclusion_flags = TRUE → escalate (requires human interpretation)

---

### Decision 3: Policy Coverage Validation

**Purpose:** Verify claim is covered under policy and check for exclusions.

**Input:**
- `policy_id`: UUID
- `incident_date`: date
- `incident_type`: enum
- `estimated_value`: decimal

**Process:**
1. Query Policy entity (cached) or call Policy Admin SOAP API
2. Check policy active for incident date
3. Verify coverage type matches incident type
4. Check coverage limit vs estimated value
5. Check for exclusion clauses

**Logic:**
```
# Step 1: Retrieve policy
policy = Policy.get(policy_id)

IF policy IS NULL
  RETURN validation_result = {status: REJECTED, reason: "Policy not found"}
END IF

IF NOT policy.is_cache_valid
  # Cache expired, refresh from policy admin system
  policy = call_policy_admin_soap_api(policy.policy_number, incident_date)
  IF policy_api_call fails
    RETURN validation_result = {status: ESCALATED, reason: "Policy system unavailable"}
  END IF
END IF

# Step 2: Check policy active
IF policy.status != ACTIVE
  RETURN validation_result = {status: REJECTED, reason: "Policy status is {policy.status}"}
END IF

IF incident_date < policy.effective_date OR incident_date > policy.expiration_date
  RETURN validation_result = {status: REJECTED, reason: "Incident date {incident_date} outside policy coverage period {policy.effective_date} to {policy.expiration_date}"}
END IF

# Step 3: Check coverage type
required_coverage = map_incident_to_coverage_type(incident_type)
# Example mapping:
#   AUTO_COLLISION_SINGLE → AUTO_COLLISION
#   AUTO_COLLISION_MULTI → AUTO_LIABILITY
#   INJURY_MINOR → INJURY
#   PROPERTY_DAMAGE_MINOR → PROPERTY

IF required_coverage NOT IN policy.coverage_types
  RETURN validation_result = {status: REJECTED, reason: "Policy does not cover {required_coverage} for incident type {incident_type}"}
END IF

# Step 4: Check coverage limit
IF estimated_value IS NOT NULL AND estimated_value > policy.coverage_limit
  RETURN validation_result = {status: ESCALATED, reason: "Estimated value ${estimated_value} exceeds policy coverage limit ${policy.coverage_limit}. Specialist review required for partial coverage determination."}
END IF

# Step 5: Check exclusions
IF policy.exclusions IS NOT NULL AND LENGTH(policy.exclusions) > 0
  # Set flag for specialist to review exclusion clauses
  RETURN validation_result = {status: ESCALATED, reason: "Policy has {LENGTH(policy.exclusions)} exclusion clauses. Specialist must review to determine if any apply to this claim.", exclusion_flags: TRUE}
END IF

# All validations passed
RETURN validation_result = {status: VALIDATED, reason: "Policy active and covers incident type"}
```

**Output:**
- `validation_result`: object with status [VALIDATED, REJECTED, ESCALATED] and reason
- `Claim.policy_validation_result`: JSON object storing full result
- `Claim.exclusion_flags`: boolean

**State Transitions:**
- status = VALIDATED → proceed to routing
- status = REJECTED → set Claim.status = REJECTED, do not route
- status = ESCALATED → set Claim.status = ESCALATED for specialist review

---

### Decision 4: Adjuster Routing

**Purpose:** Assign claim to appropriate adjuster based on specialty, workload, seniority.

**Input:**
- `incident_type`: enum
- `severity`: enum [LOW, MEDIUM, HIGH, CRITICAL]
- `available_adjusters`: array from CRM API

**Process:**
1. Filter adjusters by specialty match
2. Filter by seniority requirement (HIGH/CRITICAL needs SENIOR+)
3. Filter by availability and capacity
4. Select adjuster with lowest workload (load balancing)

**Logic:**
```
# Step 1: Determine required specialty
required_specialty = map_incident_to_specialty(incident_type)
# Example mapping:
#   AUTO_COLLISION_* → AUTO
#   PROPERTY_DAMAGE_* → PROPERTY
#   INJURY_* → INJURY
#   incident_type = THEFT → THEFT
#   incident_type IN [FIRE, FLOOD, WEATHER_DAMAGE] → WEATHER

# Step 2: Determine seniority requirement
IF severity IN [HIGH, CRITICAL]
  required_seniority = [SENIOR, PRINCIPAL]
ELSE
  required_seniority = [JUNIOR, INTERMEDIATE, SENIOR, PRINCIPAL]
END IF

# Step 3: Query available adjusters
available_adjusters = CRM_API.get_available_adjusters(
  specialty = required_specialty,
  seniority = required_seniority
)

IF available_adjusters.count = 0
  RETURN routing_result = {status: ESCALATED, reason: "No available adjusters with specialty {required_specialty} and seniority {required_seniority}"}
END IF

# Step 4: Filter by capacity
candidates = []
FOR EACH adjuster IN available_adjusters
  IF adjuster.has_capacity = TRUE AND adjuster.status = AVAILABLE
    candidates.append(adjuster)
  END IF
END FOR

IF candidates.count = 0
  RETURN routing_result = {status: ESCALATED, reason: "All {required_specialty} adjusters at capacity. Queue for next available."}
END IF

# Step 5: Select adjuster with lowest workload (load balancing)
selected_adjuster = candidates.sort_by(current_workload).first()

# Step 6: Calculate routing confidence
IF candidates.count >= 3
  routing_confidence = 1.0 (multiple good options)
ELSE IF candidates.count = 2
  routing_confidence = 0.9
ELSE IF candidates.count = 1
  routing_confidence = 0.8 (only one option, acceptable)
END IF

RETURN routing_result = {
  status: ROUTED,
  adjuster_id: selected_adjuster.id,
  adjuster_name: selected_adjuster.name,
  confidence: routing_confidence
}
```

**Output:**
- `routing_result`: object with status [ROUTED, ESCALATED], adjuster_id, confidence
- `Claim.assigned_adjuster_id`: UUID
- `Claim.routing_confidence`: float

**Escalation Triggers:**
- No available adjusters matching criteria → escalate to queue manager
- routing_confidence < 0.8 → flag for queue manager review (but still route)
- Adjuster assignment API call fails → escalate

---

## 5. Escalation Triggers

Agent automatically escalates claim (sets status = ESCALATED) under these conditions:

### Extraction Phase Escalations
1. **Low overall extraction confidence**
   - Condition: `extraction_confidence < 0.7`
   - Reason: "Low extraction confidence on fields: {field_names}. Specialist review required."
   - Action: Specialist reviews raw text and corrects extracted fields

2. **Policy number not found**
   - Condition: `policy_number extraction confidence = 0.0 OR policy_number format invalid`
   - Reason: "Unable to extract valid policy number from report. Manual lookup required."
   - Action: Specialist searches by claimant name or contacts claimant

### Triage Phase Escalations
3. **HIGH or CRITICAL severity**
   - Condition: `severity IN [HIGH, CRITICAL]`
   - Reason: "High-value claim requires specialist triage. Estimated value: ${estimated_value}, Injury: {injury_severity}."
   - Action: Specialist reviews severity assessment and confirms routing (human-led per delegation analysis)

4. **Insufficient data for severity classification**
   - Condition: `estimated_value IS NULL AND injury_severity IS NULL`
   - Reason: "Insufficient incident details to classify severity. Specialist triage required."
   - Action: Specialist contacts claimant for additional details

### Validation Phase Escalations
5. **Policy exclusion clauses detected**
   - Condition: `policy.exclusions.length > 0`
   - Reason: "Policy has {count} exclusion clauses: {clause_codes}. Specialist must review applicability."
   - Action: Specialist reads clauses, interprets whether they apply, decides coverage

6. **Claim value exceeds coverage limit**
   - Condition: `estimated_value > policy.coverage_limit`
   - Reason: "Claim value ${estimated_value} exceeds policy limit ${policy.coverage_limit}. Specialist review for partial coverage."
   - Action: Specialist determines partial coverage terms, contacts claimant

7. **Policy validation system unavailable**
   - Condition: `Policy SOAP API fails after retries`
   - Reason: "Policy validation system unavailable. Unable to verify coverage. Error: {error_details}."
   - Action: Specialist validates policy manually or waits for system recovery

### Routing Phase Escalations
8. **No available adjuster matching criteria**
   - Condition: `available_adjusters.count = 0 OR all adjusters at capacity`
   - Reason: "No available {specialty} adjusters with required seniority. Claim queued for next available."
   - Action: Queue manager reviews queue, may reassign from other specialties or escalate to senior leadership

9. **Routing confidence below threshold**
   - Condition: `routing_confidence < 0.8`
   - Reason: "Low routing confidence ({confidence}). Only one adjuster available with high workload ({workload}/{max_workload})."
   - Action: Queue manager reviews, may manually reassign

### Acknowledgment Phase Escalations
10. **Claimant notification fails**
    - Condition: `Notification service fails after retries`
    - Reason: "Unable to notify claimant via email or SMS. All delivery attempts failed. Error: {error_details}."
    - Action: Specialist attempts manual contact via phone

### Special Case Escalations
11. **VIP claimant**
    - Condition: `claimant.vip_status = TRUE`
    - Reason: "VIP claimant requires priority handling. Escalated to senior adjuster."
    - Action: Senior adjuster or account manager handles personally

12. **Fraud indicators detected**
    - Condition: `fraud_indicators_present = TRUE` (future enhancement, not implemented in v1)
    - Reason: "Fraud indicators detected: {indicator_details}. Investigation required."
    - Action: Fraud investigation team reviews

---

## 6. Error Handling & Fallback Behavior

### Integration Failure Scenarios

#### CRM API Failures
**Scenario 1:** CRM unavailable at claim ingestion (POST /api/v2/claims/fnol fails)
- **Action:** Queue claim in local persistent storage (Redis or database)
- **Retry:** Attempt ingestion every 60 seconds for up to 30 minutes
- **Fallback:** After 30 minutes, alert operations team, send email to claims inbox for manual intake
- **Impact:** Claim processing delayed but not lost

**Scenario 2:** CRM unavailable at adjuster assignment (POST /api/v2/claims/{id}/assign fails)
- **Action:** Set claim status = ESCALATED with reason "Unable to assign adjuster - CRM unavailable"
- **Retry:** Retry assignment every 5 minutes for up to 1 hour
- **Fallback:** After 1 hour, alert queue manager manually assign via CRM UI
- **Impact:** Claim triaged and validated but not routed

#### Policy SOAP API Failures
**Scenario 3:** Policy system timeout or 500 error
- **Action:** Retry up to 2 times with exponential backoff (2s, 4s)
- **Fallback:** After retries exhausted:
  - Set claim status = ESCALATED
  - escalation_reason = "Policy validation system unavailable - manual validation required"
  - Do NOT acknowledge to claimant (cannot confirm coverage)
  - Alert operations team (system health issue)
- **Impact:** Processing halted at validation step, requires manual policy check

**Scenario 4:** Policy not found (SOAP Fault: PolicyNotFound)
- **Action:** Do NOT retry (policy genuinely doesn't exist)
- **Check:** Query internal Policy cache - was policy recently cancelled?
- **Fallback:**
  - Set claim status = ESCALATED
  - escalation_reason = "Policy number {policy_number} not found in policy system. Verify with claimant."
  - Specialist contacts claimant to confirm policy number
- **Impact:** Possible data entry error or invalid policy

#### Notification Service Failures
**Scenario 5:** Email delivery fails (all retries exhausted)
- **Action:** 
  - Set claim status = ESCALATED
  - escalation_reason = "Unable to send acknowledgment email to {claimant_email}. Email may be invalid."
  - Claim still proceeds to adjuster (acknowledgment failure is not blocking)
- **Fallback:** Specialist attempts phone contact with claimant
- **Impact:** SLA breach (acknowledgment not received within 2 hours)

#### DMS Failures
**Scenario 6:** Document retrieval fails
- **Action:** Log warning, proceed without attachment
- **Fallback:** Adjuster can retrieve documents directly from DMS when reviewing claim
- **Impact:** None (documents not required for triage/routing)

---

### Data Quality Failures

#### Invalid or Missing Data
**Scenario 7:** Claimant email and phone both invalid
- **Action:** 
  - Set claim status = ESCALATED
  - escalation_reason = "No valid contact information for claimant. Email: {email} invalid, Phone: {phone} invalid."
- **Fallback:** Specialist looks up claimant in policyholder database, corrects contact info
- **Impact:** Cannot send acknowledgment until contact info corrected

**Scenario 8:** Incident date in future
- **Action:**
  - Set claim status = ESCALATED
  - escalation_reason = "Incident date {incident_date} is in the future. Possible data entry error."
- **Fallback:** Specialist reviews, corrects date or contacts claimant
- **Impact:** Triage cannot proceed until date corrected

**Scenario 9:** Estimated value negative or absurdly high (>$10M)
- **Action:**
  - Flag as data quality issue
  - If estimated_value < 0: set to NULL, escalate with reason "Negative claim value detected"
  - If estimated_value > 10000000: escalate with reason "Claim value exceeds $10M threshold. Requires executive review."
- **Fallback:** Specialist verifies value with claimant
- **Impact:** Severity classification may be incorrect until corrected

---

### Agent Logic Failures

#### Confidence Threshold Breaches
**Scenario 10:** Low extraction confidence across multiple fields
- **Action:** Escalate to specialist (already covered in escalation triggers)
- **Impact:** Processing pauses at extraction phase

**Scenario 11:** Ambiguous severity classification
- **Action:** Default to MEDIUM severity (safe fallback), but escalate for review
- **Impact:** May over-escalate some LOW claims, but prevents under-triaging HIGH claims

#### Deadlock Scenarios
**Scenario 12:** Claim stuck in ROUTED status (adjuster never acknowledges)
- **Detection:** Monitoring job runs hourly, identifies claims with routed_at > 24 hours ago and no adjuster activity
- **Action:** Alert queue manager, re-assign to different adjuster
- **Impact:** Claim delayed but not lost

**Scenario 13:** Claim stuck in ESCALATED status (specialist never reviews)
- **Detection:** Monitoring job identifies ESCALATED claims > 4 hours old
- **Action:** Send escalation alert to queue manager and claims director
- **Impact:** SLA breach likely

---

### System-Wide Failures

#### Agent Service Outage
**Scenario 14:** Agent service crashes or is unreachable
- **Detection:** Health check endpoint fails
- **Action:** Orchestrator (Kubernetes, container platform) restarts service automatically
- **Fallback:** Claims queued in CRM during outage, processed when agent recovers (queue-based architecture)
- **Impact:** Processing delayed during outage (minutes), no data loss

#### Database Unavailable
**Scenario 15:** Claim database unreachable
- **Action:** 
  - Return 503 Service Unavailable to CRM API calls
  - Queue incoming claims in Redis (in-memory queue, 1-hour retention)
  - Retry database connection every 30 seconds
- **Fallback:** After 1 hour, persist queue to disk, alert operations team
- **Impact:** Processing halted, manual intervention required

---

## 7. Validation Rules

### Claim Entity Validation
- `claim_number` must be unique across all claims
- `incident_date` must be <= today and >= today - 365 days
- `estimated_value` must be >= 0 and <= 10000000
- `status` transitions must follow state machine (cannot skip states)
- `severity` must be non-null before status = VALIDATED
- `assigned_adjuster_id` must be non-null before status = ROUTED
- `escalation_reason` must be non-null and length >= 10 if status = ESCALATED
- `rejection_reason` must be non-null and length >= 10 if status = REJECTED

### Claimant Entity Validation
- `email` must match RFC 5322 format regex
- `phone` must match E.164 or US domestic format
- At least one of {email, phone} must be valid (non-null and format-valid)
- `first_name` and `last_name` required, minimum 2 characters each

### Policy Entity Validation
- `expiration_date` must be > `effective_date`
- `coverage_limit` must be >= `deductible`
- `coverage_types` array must have at least 1 element
- `policy_number` must match format "POL-NNNNNNNN" (POL- prefix, 8 digits)

### Adjuster Entity Validation
- `specialties` array must have at least 1 element
- `current_workload` cannot exceed `max_workload`
- `max_workload` must be in range 1-25
- If `status` != AVAILABLE, adjuster cannot be assigned new claims (enforced by routing logic)

---

## 8. Audit & Compliance Requirements

### Audit Trail
Every claim state transition must be logged with:
- `timestamp`: ISO 8601 UTC
- `from_status`: previous status
- `to_status`: new status
- `triggered_by`: "AGENT" or user identifier
- `reason`: human-readable explanation (e.g., "Severity classified as HIGH based on estimated value $75,000")
- `decision_data`: JSON object with inputs used (e.g., {estimated_value: 75000, injury_severity: "NONE", policy_type: "STANDARD"})

Stored in `Claim.audit_log` JSON array, append-only, immutable.

### Logging Requirements
Log to centralized logging system (e.g., Splunk, ELK) at these levels:

**INFO level:**
- Claim received
- Extraction completed
- Severity assigned
- Policy validated
- Adjuster assigned
- Claimant acknowledged

**WARN level:**
- Low extraction confidence (< 0.7)
- Policy exclusions detected
- Routing confidence low (< 0.8)
- Integration retry attempts

**ERROR level:**
- Integration failures after retries exhausted
- Data validation failures
- System errors (database unavailable, service crash)

**CRITICAL level:**
- Agent service outage
- Multiple claims stuck in ESCALATED (> 10 claims)
- SLA breach rate > 20% in past hour

### Personally Identifiable Information (PII) Handling
**Never log in plaintext:**
- Full claimant name (log as "Claimant {claimant_id}")
- Email addresses (log as "email ending in @{domain}")
- Phone numbers (log as "phone ending in {last 4 digits}")
- Policy numbers (log as "policy {first 4 chars}****")
- Incident descriptions (may contain sensitive details)

**Encryption requirements:**
- All PII encrypted at rest in database (AES-256)
- All API calls over TLS 1.3
- Secrets (API keys, passwords) stored in secrets manager, never in code or config files

### Data Retention
- Claims data: retain 7 years (regulatory requirement for insurance)
- Audit logs: retain 7 years (immutable, compliance)
- Extracted unstructured text (`raw_input_text`): retain 90 days, then purge (storage optimization, PII minimization)
- Attachments in DMS: retain per DMS policy (outside agent scope)

---

## 9. Performance & Scalability Requirements

### Throughput Targets
- Process 300 claims per day (average)
- Peak load: 50 claims per hour (during business hours 9am-5pm)
- Target processing time per claim:
  - Extraction: < 30 seconds
  - Triage: < 10 seconds
  - Validation: < 8 seconds (limited by SOAP API)
  - Routing: < 5 seconds
  - Acknowledgment: < 5 seconds
- **Total end-to-end: < 60 seconds for 95th percentile of LOW/MEDIUM claims**

### SLA Requirements
- **Acknowledgment SLA:** 95% of claims acknowledged within 5 minutes of receipt (current: 69% within 2 hours)
- **Extraction SLA:** 90% of claims extracted within 1 minute
- **Routing SLA:** 95% of claims routed to adjuster within 30 minutes

### Concurrency
- Support up to 20 concurrent claims in processing
- Each claim processed independently (stateless agent design, state in database)
- Integration rate limits respected (CRM: 100 req/min, Policy SOAP: unknown, Notification: 500/min)

### Scalability Plan
- Horizontal scaling: deploy multiple agent service instances behind load balancer
- Queue-based architecture: claims queued in CRM, agent pulls from queue (decoupled, backpressure-resistant)
- Database connection pooling: max 50 connections per agent instance
- Caching: Policy data cached 1 hour (reduces SOAP calls by ~90%)

---

## 10. Assumptions Flagged for Validation

**Assumption S1:** Legacy SOAP policy system can handle 300+ concurrent requests without degradation
- **If wrong:** Need request throttling or longer timeouts, increases processing time
- **Validation:** Load test SOAP endpoint with 300 parallel requests, measure latency and error rate

**Assumption S2:** Incident descriptions in FNOL reports contain sufficient detail for NLP extraction (80% achievable accuracy)
- **If wrong:** Extraction confidence will be low, most claims escalated, negates capacity gains
- **Validation:** Test NLP extraction on 100 sample historical FNOL reports, measure per-field confidence

**Assumption S3:** CRM API provides real-time adjuster workload data with < 5 minute staleness
- **If wrong:** Routing may assign to overloaded adjusters, requires manual rebalancing
- **Validation:** Review CRM API documentation, test data freshness (query workload, assign claim, re-query)

**Assumption S4:** Notification service can deliver 300 emails/SMS per day without throttling
- **If wrong:** Acknowledgments delayed, SLA breaches
- **Validation:** Confirm rate limits with notification service team (500/min should be sufficient)

**Assumption S5:** 70% of claims are LOW severity (routine, fully agentic processing)
- **If wrong:** More escalations than planned, reduces capacity gains
- **Validation:** Analyze 3-6 months historical claims data, calculate actual severity distribution

---


