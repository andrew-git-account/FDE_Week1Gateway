-- FNOL Claims Processing Agent - Database Schema
-- MySQL 8.0+

-- Drop tables if they exist (for clean setup)
DROP TABLE IF EXISTS audit_log;
DROP TABLE IF EXISTS severity_overrides;
DROP TABLE IF EXISTS extraction_results;
DROP TABLE IF EXISTS claims;
DROP TABLE IF EXISTS adjusters;
DROP TABLE IF EXISTS policies;
DROP TABLE IF EXISTS claimants;

-- Claimants table
CREATE TABLE claimants (
    id CHAR(36) PRIMARY KEY,
    policy_holder_id CHAR(36),
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    alternate_phone VARCHAR(20),
    preferred_contact_method ENUM('EMAIL', 'PHONE', 'SMS') DEFAULT 'EMAIL',
    vip_status BOOLEAN DEFAULT FALSE,
    language_preference ENUM('EN', 'ES', 'FR') DEFAULT 'EN',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_email (email),
    INDEX idx_phone (phone)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Policies table
CREATE TABLE policies (
    id CHAR(36) PRIMARY KEY,
    policy_number VARCHAR(20) UNIQUE NOT NULL,
    policy_holder_id CHAR(36),
    status ENUM('ACTIVE', 'EXPIRED', 'CANCELLED', 'SUSPENDED') NOT NULL,
    policy_type ENUM('STANDARD', 'COMMERCIAL', 'HIGH_VALUE', 'UMBRELLA') NOT NULL,
    effective_date DATE NOT NULL,
    expiration_date DATE NOT NULL,
    coverage_types JSON NOT NULL COMMENT 'Array of coverage types',
    coverage_limit DECIMAL(12,2) NOT NULL,
    deductible DECIMAL(10,2) NOT NULL,
    exclusions JSON COMMENT 'Array of exclusion clauses',
    last_validated_at TIMESTAMP,
    cached_at TIMESTAMP,
    cache_ttl INT DEFAULT 3600,
    INDEX idx_policy_number (policy_number),
    INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Adjusters table
CREATE TABLE adjusters (
    id CHAR(36) PRIMARY KEY,
    employee_id VARCHAR(20) UNIQUE NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    specialties JSON NOT NULL COMMENT 'Array of specialties',
    seniority_level ENUM('JUNIOR', 'INTERMEDIATE', 'SENIOR', 'PRINCIPAL') NOT NULL,
    status ENUM('AVAILABLE', 'BUSY', 'ON_LEAVE', 'IN_TRAINING', 'INACTIVE') DEFAULT 'AVAILABLE',
    current_workload INT DEFAULT 0,
    max_workload INT DEFAULT 15,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_status (status),
    INDEX idx_seniority (seniority_level)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Claims table (main entity)
CREATE TABLE claims (
    id CHAR(36) PRIMARY KEY,
    claim_number VARCHAR(30) UNIQUE NOT NULL,
    claimant_id CHAR(36) NOT NULL,
    policy_id CHAR(36) NOT NULL,
    status ENUM('RECEIVED', 'EXTRACTED', 'TRIAGED', 'VALIDATED', 'ROUTED', 'ACKNOWLEDGED', 'ESCALATED', 'REJECTED') DEFAULT 'RECEIVED',
    severity ENUM('LOW', 'MEDIUM', 'HIGH', 'CRITICAL'),
    estimated_value DECIMAL(10,2),
    incident_type VARCHAR(50),
    incident_description TEXT NOT NULL,
    incident_date DATE NOT NULL,
    incident_location VARCHAR(500),
    extraction_confidence FLOAT,
    extraction_flags JSON,
    assigned_adjuster_id CHAR(36),
    escalation_reason TEXT,
    rejection_reason TEXT,
    policy_validation_result JSON,
    exclusion_flags BOOLEAN DEFAULT FALSE,
    routing_confidence FLOAT,
    received_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    extracted_at TIMESTAMP NULL,
    triaged_at TIMESTAMP NULL,
    validated_at TIMESTAMP NULL,
    routed_at TIMESTAMP NULL,
    acknowledged_at TIMESTAMP NULL,
    sla_deadline TIMESTAMP NOT NULL,
    sla_breach BOOLEAN AS (acknowledged_at > sla_deadline OR (acknowledged_at IS NULL AND NOW() > sla_deadline)) STORED,
    created_by VARCHAR(50) DEFAULT 'AGENT',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (claimant_id) REFERENCES claimants(id),
    FOREIGN KEY (policy_id) REFERENCES policies(id),
    FOREIGN KEY (assigned_adjuster_id) REFERENCES adjusters(id),
    INDEX idx_claim_number (claim_number),
    INDEX idx_status (status),
    INDEX idx_severity (severity),
    INDEX idx_received_at (received_at),
    INDEX idx_sla_deadline (sla_deadline),
    INDEX idx_sla_breach (sla_breach)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Extraction Results table (detailed NLP extraction data)
CREATE TABLE extraction_results (
    id CHAR(36) PRIMARY KEY,
    claim_id CHAR(36) NOT NULL,
    raw_input_text TEXT NOT NULL,
    extraction_method ENUM('NLP_LLM', 'REGEX_PATTERN', 'WEB_FORM_STRUCTURED') NOT NULL,
    extracted_fields JSON NOT NULL COMMENT 'Object with field name -> {value, confidence}',
    overall_confidence FLOAT NOT NULL,
    low_confidence_fields JSON COMMENT 'Array of field names with confidence < 0.7',
    extraction_warnings JSON COMMENT 'Array of warning messages',
    extracted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processing_time_ms INT,
    FOREIGN KEY (claim_id) REFERENCES claims(id) ON DELETE CASCADE,
    INDEX idx_claim_id (claim_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Audit Log table (all state transitions)
CREATE TABLE audit_log (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    claim_id CHAR(36) NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    from_status VARCHAR(50),
    to_status VARCHAR(50) NOT NULL,
    triggered_by VARCHAR(100) DEFAULT 'AGENT',
    reason TEXT,
    decision_data JSON COMMENT 'Inputs used for decision',
    FOREIGN KEY (claim_id) REFERENCES claims(id) ON DELETE CASCADE,
    INDEX idx_claim_id (claim_id),
    INDEX idx_timestamp (timestamp)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Severity Overrides table (track when adjusters change agent's severity)
CREATE TABLE severity_overrides (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    claim_id CHAR(36) NOT NULL,
    original_severity ENUM('LOW', 'MEDIUM', 'HIGH', 'CRITICAL') NOT NULL,
    overridden_severity ENUM('LOW', 'MEDIUM', 'HIGH', 'CRITICAL') NOT NULL,
    overridden_by VARCHAR(100) NOT NULL,
    overridden_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    reason TEXT,
    FOREIGN KEY (claim_id) REFERENCES claims(id) ON DELETE CASCADE,
    INDEX idx_claim_id (claim_id),
    INDEX idx_overridden_at (overridden_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Sample test data (for development)
-- Claimant
INSERT INTO claimants (id, first_name, last_name, email, phone, vip_status) VALUES
('550e8400-e29b-41d4-a716-446655440001', 'John', 'Smith', 'john.smith@example.com', '555-123-4567', FALSE),
('550e8400-e29b-41d4-a716-446655440002', 'Emily', 'Rodriguez', 'emily.rodriguez@example.com', '555-234-5678', TRUE);

-- Policy
INSERT INTO policies (id, policy_number, policy_holder_id, status, policy_type, effective_date, expiration_date, coverage_types, coverage_limit, deductible) VALUES
('650e8400-e29b-41d4-a716-446655440001', 'POL-12345678', '550e8400-e29b-41d4-a716-446655440001', 'ACTIVE', 'STANDARD', '2025-04-01', '2027-04-01', '["AUTO_COMPREHENSIVE", "AUTO_LIABILITY"]', 50000.00, 500.00),
('650e8400-e29b-41d4-a716-446655440002', 'POL-11223344', '550e8400-e29b-41d4-a716-446655440002', 'ACTIVE', 'HIGH_VALUE', '2024-01-01', '2027-01-01', '["AUTO_COMPREHENSIVE", "AUTO_LIABILITY", "INJURY"]', 100000.00, 1000.00);

-- Adjusters
INSERT INTO adjusters (id, employee_id, first_name, last_name, email, phone, specialties, seniority_level, status, current_workload, max_workload) VALUES
('750e8400-e29b-41d4-a716-446655440001', 'EMP-0789', 'Sarah', 'Johnson', 'sarah.johnson@company.com', '555-111-2222', '["AUTO"]', 'INTERMEDIATE', 'AVAILABLE', 8, 15),
('750e8400-e29b-41d4-a716-446655440002', 'EMP-0567', 'James', 'Park', 'james.park@company.com', '555-333-4444', '["AUTO", "INJURY"]', 'PRINCIPAL', 'AVAILABLE', 5, 12),
('750e8400-e29b-41d4-a716-446655440003', 'EMP-0456', 'Tom', 'Wilson', 'tom.wilson@company.com', '555-555-6666', '["PROPERTY"]', 'INTERMEDIATE', 'AVAILABLE', 10, 15);
