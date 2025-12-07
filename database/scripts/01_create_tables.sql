

-- Drop existing tables (if recreating)
BEGIN
   FOR t IN (SELECT table_name FROM user_tables) LOOP
      EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS';
   END LOOP;
END;
/

-- =====================================================
-- TABLE 1: CITIZENS
-- =====================================================
CREATE TABLE citizens (
    citizen_id          NUMBER(10) PRIMARY KEY,
    national_id         VARCHAR2(16) UNIQUE NOT NULL,
    first_name          VARCHAR2(50) NOT NULL,
    last_name           VARCHAR2(50) NOT NULL,
    date_of_birth       DATE NOT NULL,
    email               VARCHAR2(100) UNIQUE NOT NULL,
    phone_number        VARCHAR2(15) NOT NULL,
    address             VARCHAR2(200),
    registration_date   TIMESTAMP DEFAULT SYSTIMESTAMP,
    status              VARCHAR2(20) DEFAULT 'ACTIVE' 
                        CHECK (status IN ('ACTIVE','SUSPENDED','INACTIVE')),
    created_by          VARCHAR2(50) DEFAULT USER,
    created_date        TIMESTAMP DEFAULT SYSTIMESTAMP,
    modified_by         VARCHAR2(50),
    modified_date       TIMESTAMP,
    CONSTRAINT chk_citizen_age CHECK (MONTHS_BETWEEN(SYSDATE, date_of_birth) / 12 >= 18),
    CONSTRAINT chk_citizen_email CHECK (REGEXP_LIKE(email, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$'))
) TABLESPACE digitalid_data;

-- Create index for performance
CREATE INDEX idx_citizen_national_id ON citizens(national_id) TABLESPACE digitalid_indexes;
CREATE INDEX idx_citizen_email ON citizens(email) TABLESPACE digitalid_indexes;

COMMENT ON TABLE citizens IS 'Stores citizen registration and personal information';
COMMENT ON COLUMN citizens.citizen_id IS 'Unique identifier for each citizen';
COMMENT ON COLUMN citizens.national_id IS 'Government-issued national ID number';
COMMENT ON COLUMN citizens.status IS 'Account status: ACTIVE, SUSPENDED, or INACTIVE';

-- =====================================================
-- TABLE 2: DIGITAL_IDS
-- =====================================================
CREATE TABLE digital_ids (
    digital_id          NUMBER(10) PRIMARY KEY,
    citizen_id          NUMBER(10) NOT NULL,
    id_number           VARCHAR2(20) UNIQUE NOT NULL,
    biometric_hash      VARCHAR2(256) NOT NULL,
    issue_date          DATE NOT NULL,
    expiry_date         DATE NOT NULL,
    id_type             VARCHAR2(30) NOT NULL 
                        CHECK (id_type IN ('NATIONAL','PASSPORT','REFUGEE')),
    security_level      NUMBER(1) DEFAULT 3 
                        CHECK (security_level BETWEEN 1 AND 5),
    is_active           CHAR(1) DEFAULT 'Y' 
                        CHECK (is_active IN ('Y','N')),
    encryption_key      VARCHAR2(128) NOT NULL,
    created_date        TIMESTAMP DEFAULT SYSTIMESTAMP,
    CONSTRAINT fk_digital_citizen FOREIGN KEY (citizen_id) 
        REFERENCES citizens(citizen_id) ON DELETE CASCADE,
    CONSTRAINT chk_digital_expiry CHECK (expiry_date > issue_date)
) TABLESPACE digitalid_data;

CREATE INDEX idx_digital_citizen ON digital_ids(citizen_id) TABLESPACE digitalid_indexes;
CREATE UNIQUE INDEX idx_digital_active ON digital_ids(citizen_id, is_active) 
    WHERE is_active = 'Y' TABLESPACE digitalid_indexes;

COMMENT ON TABLE digital_ids IS 'Stores encrypted digital identity credentials';
COMMENT ON COLUMN digital_ids.biometric_hash IS 'Encrypted biometric data (fingerprint/facial)';
COMMENT ON COLUMN digital_ids.security_level IS 'Clearance level 1-5 (5=highest)';

-- =====================================================
-- TABLE 3: DATA_CATEGORIES
-- =====================================================
CREATE TABLE data_categories (
    category_id         NUMBER(10) PRIMARY KEY,
    category_name       VARCHAR2(50) UNIQUE NOT NULL,
    description         VARCHAR2(200),
    sensitivity_level   NUMBER(1) NOT NULL CHECK (sensitivity_level BETWEEN 1 AND 5),
    requires_consent    CHAR(1) DEFAULT 'Y' CHECK (requires_consent IN ('Y','N')),
    created_date        TIMESTAMP DEFAULT SYSTIMESTAMP
) TABLESPACE digitalid_data;

COMMENT ON TABLE data_categories IS 'Defines types of data with privacy sensitivity levels';
COMMENT ON COLUMN data_categories.sensitivity_level IS '1=Low, 5=Highly Sensitive';

-- =====================================================
-- TABLE 4: AUTHORIZED_ENTITIES
-- =====================================================
CREATE TABLE authorized_entities (
    entity_id           NUMBER(10) PRIMARY KEY,
    entity_name         VARCHAR2(100) NOT NULL,
    entity_type         VARCHAR2(30) NOT NULL 
                        CHECK (entity_type IN ('GOVERNMENT','BANK','HOSPITAL',
                                              'INSURANCE','TELECOM','OTHER')),
    license_number      VARCHAR2(50) UNIQUE NOT NULL,
    contact_person      VARCHAR2(100) NOT NULL,
    contact_email       VARCHAR2(100) NOT NULL,
    contact_phone       VARCHAR2(15) NOT NULL,
    authorization_level NUMBER(1) DEFAULT 1 CHECK (authorization_level BETWEEN 1 AND 3),
    approved_date       DATE,
    expiry_date         DATE,
    status              VARCHAR2(20) DEFAULT 'ACTIVE' 
                        CHECK (status IN ('ACTIVE','SUSPENDED','REVOKED')),
    created_date        TIMESTAMP DEFAULT SYSTIMESTAMP,
    CONSTRAINT chk_entity_auth_expiry CHECK (expiry_date > approved_date)
) TABLESPACE digitalid_data;

CREATE INDEX idx_entity_type ON authorized_entities(entity_type) TABLESPACE digitalid_indexes;
CREATE INDEX idx_entity_status ON authorized_entities(status) TABLESPACE digitalid_indexes;

COMMENT ON TABLE authorized_entities IS 'Organizations authorized to request ID data';
COMMENT ON COLUMN authorized_entities.authorization_level IS '1=Basic, 2=Standard, 3=Full Access';

-- =====================================================
-- TABLE 5: CONSENT_RECORDS
-- =====================================================
CREATE TABLE consent_records (
    consent_id          NUMBER(10) PRIMARY KEY,
    citizen_id          NUMBER(10) NOT NULL,
    data_category_id    NUMBER(10) NOT NULL,
    entity_type         VARCHAR2(30),
    consent_status      VARCHAR2(20) DEFAULT 'GRANTED' 
                        CHECK (consent_status IN ('GRANTED','REVOKED','EXPIRED')),
    granted_date        TIMESTAMP DEFAULT SYSTIMESTAMP,
    expiry_date         DATE,
    revoked_date        TIMESTAMP,
    consent_level       VARCHAR2(20) DEFAULT 'PARTIAL' 
                        CHECK (consent_level IN ('FULL','PARTIAL','RESTRICTED')),
    created_date        TIMESTAMP DEFAULT SYSTIMESTAMP,
    CONSTRAINT fk_consent_citizen FOREIGN KEY (citizen_id) 
        REFERENCES citizens(citizen_id) ON DELETE CASCADE,
    CONSTRAINT fk_consent_category FOREIGN KEY (data_category_id) 
        REFERENCES data_categories(category_id)
) TABLESPACE digitalid_data;

CREATE INDEX idx_consent_citizen ON consent_records(citizen_id) TABLESPACE digitalid_indexes;
CREATE INDEX idx_consent_status ON consent_records(consent_status) TABLESPACE digitalid_indexes;

COMMENT ON TABLE consent_records IS 'Tracks citizen consent for data access by category';
COMMENT ON COLUMN consent_records.consent_level IS 'FULL=all fields, PARTIAL=some, RESTRICTED=minimal';

-- =====================================================
-- TABLE 6: ACCESS_REQUESTS
-- =====================================================
CREATE TABLE access_requests (
    request_id          NUMBER(10) PRIMARY KEY,
    entity_id           NUMBER(10) NOT NULL,
    digital_id          NUMBER(10) NOT NULL,
    request_date        TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    purpose             VARCHAR2(500) NOT NULL,
    data_category       VARCHAR2(50) NOT NULL,
    request_status      VARCHAR2(20) DEFAULT 'PENDING' 
                        CHECK (request_status IN ('PENDING','APPROVED','DENIED','EXPIRED')),
    approved_by         VARCHAR2(50),
    approval_date       TIMESTAMP,
    access_start_time   TIMESTAMP,
    access_end_time     TIMESTAMP,
    ip_address          VARCHAR2(45),
    user_agent          VARCHAR2(200),
    risk_score          NUMBER(3,2) CHECK (risk_score BETWEEN 0 AND 1),
    created_by          VARCHAR2(50) DEFAULT USER,
    CONSTRAINT fk_request_entity FOREIGN KEY (entity_id) 
        REFERENCES authorized_entities(entity_id),
    CONSTRAINT fk_request_digital FOREIGN KEY (digital_id) 
        REFERENCES digital_ids(digital_id),
    CONSTRAINT chk_request_access_time CHECK (access_end_time > access_start_time)
) TABLESPACE digitalid_data;

CREATE INDEX idx_request_entity ON access_requests(entity_id) TABLESPACE digitalid_indexes;
CREATE INDEX idx_request_digital ON access_requests(digital_id) TABLESPACE digitalid_indexes;
CREATE INDEX idx_request_status ON access_requests(request_status) TABLESPACE digitalid_indexes;
CREATE INDEX idx_request_date ON access_requests(request_date) TABLESPACE digitalid_indexes;

COMMENT ON TABLE access_requests IS 'Logs all data access requests from authorized entities';
COMMENT ON COLUMN access_requests.risk_score IS 'AI-calculated risk 0-1 (>0.7 triggers review)';

-- =====================================================
-- TABLE 7: ACCESS_LOGS (IMMUTABLE AUDIT TRAIL)
-- =====================================================
CREATE TABLE access_logs (
    log_id              NUMBER(10) PRIMARY KEY,
    request_id          NUMBER(10),
    action_type         VARCHAR2(20) NOT NULL 
                        CHECK (action_type IN ('VIEW','DOWNLOAD','MODIFY','DELETE','ATTEMPT')),
    action_timestamp    TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    action_by           VARCHAR2(50) NOT NULL,
    action_result       VARCHAR2(20) NOT NULL 
                        CHECK (action_result IN ('SUCCESS','DENIED','ERROR')),
    denial_reason       VARCHAR2(200),
    data_accessed       CLOB,
    session_id          VARCHAR2(50),
    ip_address          VARCHAR2(45),
    created_date        TIMESTAMP DEFAULT SYSTIMESTAMP,
    CONSTRAINT fk_log_request FOREIGN KEY (request_id) 
        REFERENCES access_requests(request_id)
) TABLESPACE digitalid_data;

CREATE INDEX idx_log_request ON access_logs(request_id) TABLESPACE digitalid_indexes;
CREATE INDEX idx_log_timestamp ON access_logs(action_timestamp) TABLESPACE digitalid_indexes;
CREATE INDEX idx_log_result ON access_logs(action_result) TABLESPACE digitalid_indexes;

COMMENT ON TABLE access_logs IS 'Immutable audit trail of all access attempts';
COMMENT ON COLUMN access_logs.action_result IS 'SUCCESS, DENIED (policy), or ERROR (system)';

-- =====================================================
-- TABLE 8: ALERTS
-- =====================================================
CREATE TABLE alerts (
    alert_id            NUMBER(10) PRIMARY KEY,
    citizen_id          NUMBER(10),
    request_id          NUMBER(10),
    alert_type          VARCHAR2(30) NOT NULL 
                        CHECK (alert_type IN ('SUSPICIOUS_ACCESS','UNAUTHORIZED_ATTEMPT',
                                             'CONSENT_VIOLATION','DATA_BREACH','UNUSUAL_PATTERN')),
    severity            VARCHAR2(10) DEFAULT 'MEDIUM' 
                        CHECK (severity IN ('LOW','MEDIUM','HIGH','CRITICAL')),
    alert_message       VARCHAR2(500) NOT NULL,
    alert_date          TIMESTAMP DEFAULT SYSTIMESTAMP,
    status              VARCHAR2(20) DEFAULT 'NEW' 
                        CHECK (status IN ('NEW','REVIEWED','RESOLVED','FALSE_POSITIVE')),
    reviewed_by         VARCHAR2(50),
    reviewed_date       TIMESTAMP,
    resolution_notes    VARCHAR2(500),
    CONSTRAINT fk_alert_citizen FOREIGN KEY (citizen_id) 
        REFERENCES citizens(citizen_id) ON DELETE CASCADE,
    CONSTRAINT fk_alert_request FOREIGN KEY (request_id) 
        REFERENCES access_requests(request_id)
) TABLESPACE digitalid_data;

CREATE INDEX idx_alert_citizen ON alerts(citizen_id) TABLESPACE digitalid_indexes;
CREATE INDEX idx_alert_severity ON alerts(severity) TABLESPACE digitalid_indexes;
CREATE INDEX idx_alert_status ON alerts(status) TABLESPACE digitalid_indexes;

COMMENT ON TABLE alerts IS 'Security alerts for suspicious or unauthorized access';
COMMENT ON COLUMN alerts.severity IS 'CRITICAL alerts notify DPO immediately';

-- =====================================================
-- TABLE 9: HOLIDAYS (For Phase VII Restriction)
-- =====================================================
CREATE TABLE holidays (
    holiday_id          NUMBER(10) PRIMARY KEY,
    holiday_name        VARCHAR2(100) NOT NULL,
    holiday_date        DATE NOT NULL,
    holiday_type        VARCHAR2(20) DEFAULT 'PUBLIC' 
                        CHECK (holiday_type IN ('PUBLIC','RELIGIOUS','NATIONAL')),
    is_recurring        CHAR(1) DEFAULT 'N' CHECK (is_recurring IN ('Y','N')),
    created_date        TIMESTAMP DEFAULT SYSTIMESTAMP
) TABLESPACE digitalid_data;

CREATE UNIQUE INDEX idx_holiday_date ON holidays(holiday_date) TABLESPACE digitalid_indexes;

COMMENT ON TABLE holidays IS 'Public holidays where DML operations are restricted';
COMMENT ON COLUMN holidays.is_recurring IS 'Y=Annual repeat (e.g., Christmas)';

-- =====================================================
-- TABLE 10: VIOLATIONS
-- =====================================================
CREATE TABLE violations (
    violation_id        NUMBER(10) PRIMARY KEY,
    request_id          NUMBER(10),
    entity_id           NUMBER(10),
    violation_type      VARCHAR2(50) NOT NULL 
                        CHECK (violation_type IN ('UNAUTHORIZED_ACCESS','CONSENT_BREACH',
                                                 'TIME_VIOLATION','DATA_MISUSE','EXCESSIVE_ACCESS')),
    violation_date      TIMESTAMP DEFAULT SYSTIMESTAMP,
    description         VARCHAR2(500) NOT NULL,
    penalty_amount      NUMBER(10,2),
    reported_to_authority CHAR(1) DEFAULT 'N' CHECK (reported_to_authority IN ('Y','N')),
    status              VARCHAR2(20) DEFAULT 'INVESTIGATING' 
                        CHECK (status IN ('INVESTIGATING','CONFIRMED','DISMISSED')),
    created_date        TIMESTAMP DEFAULT SYSTIMESTAMP,
    CONSTRAINT fk_violation_request FOREIGN KEY (request_id) 
        REFERENCES access_requests(request_id),
    CONSTRAINT fk_violation_entity FOREIGN KEY (entity_id) 
        REFERENCES authorized_entities(entity_id)
) TABLESPACE digitalid_data;

CREATE INDEX idx_violation_entity ON violations(entity_id) TABLESPACE digitalid_indexes;
CREATE INDEX idx_violation_date ON violations(violation_date) TABLESPACE digitalid_indexes;

COMMENT ON TABLE violations IS 'Records privacy violations and enforcement actions';
COMMENT ON COLUMN violations.penalty_amount IS 'Fine imposed (if applicable)';

-- =====================================================
-- VERIFY TABLE CREATION
-- =====================================================

-- Check all tables created
SELECT table_name, tablespace_name FROM user_tables ORDER BY table_name;

-- Check all indexes
SELECT index_name, table_name FROM user_indexes ORDER BY table_name, index_name;

-- Check all constraints
SELECT constraint_name, constraint_type, table_name 
FROM user_constraints 
WHERE constraint_type IN ('P','R','C','U')
ORDER BY table_name;

-- Check comments
SELECT table_name, comments FROM user_tab_comments WHERE comments IS NOT NULL;

COMMIT;

-- =====================================================
-- COMPLETION MESSAGE
-- =====================================================
BEGIN
    DBMS_OUTPUT.PUT_LINE('=====================================================');
    DBMS_OUTPUT.PUT_LINE('TABLE CREATION COMPLETED SUCCESSFULLY');
    DBMS_OUTPUT.PUT_LINE('Total Tables: 10');
    DBMS_OUTPUT.PUT_LINE('Total Indexes: 20+');
    DBMS_OUTPUT.PUT_LINE('Total Constraints: 50+');
    DBMS_OUTPUT.PUT_LINE('Next Step: Insert realistic data (Phase V continues)');
    DBMS_OUTPUT.PUT_LINE('=====================================================');
END;
/