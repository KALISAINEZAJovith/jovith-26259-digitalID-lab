
SET SERVEROUTPUT ON;

-- =====================================================
-- PROCEDURE 1: ADD_CITIZEN
-- Purpose: Register a new citizen with digital ID
-- Parameters: IN (citizen details), OUT (new IDs)
-- =====================================================
CREATE OR REPLACE PROCEDURE add_citizen(
    p_national_id    IN  VARCHAR2,
    p_first_name     IN  VARCHAR2,
    p_last_name      IN  VARCHAR2,
    p_date_of_birth  IN  DATE,
    p_email          IN  VARCHAR2,
    p_phone_number   IN  VARCHAR2,
    p_address        IN  VARCHAR2,
    p_id_type        IN  VARCHAR2 DEFAULT 'NATIONAL',
    p_citizen_id     OUT NUMBER,
    p_digital_id     OUT NUMBER,
    p_status_message OUT VARCHAR2
)
IS
    v_age NUMBER;
    v_id_number VARCHAR2(20);
    v_biometric_hash VARCHAR2(256);
    v_encryption_key VARCHAR2(128);
    
    -- Custom exceptions
    e_duplicate_national_id EXCEPTION;
    e_duplicate_email       EXCEPTION;
    e_invalid_age           EXCEPTION;
    
    PRAGMA EXCEPTION_INIT(e_duplicate_national_id, -00001); -- Unique constraint violation
BEGIN
    -- Validate age (must be 18+)
    v_age := MONTHS_BETWEEN(SYSDATE, p_date_of_birth) / 12;
    IF v_age < 18 THEN
        RAISE e_invalid_age;
    END IF;
    
    -- Generate new IDs
    p_citizen_id := seq_citizen_id.NEXTVAL;
    p_digital_id := seq_digital_id.NEXTVAL;
    
    -- Generate digital ID number
    v_id_number := 'RWD' || LPAD(p_citizen_id, 12, '0');
    
    -- Generate mock biometric hash (in production, this comes from scanner)
    v_biometric_hash := RAWTOHEX(DBMS_CRYPTO.HASH(
        UTL_RAW.CAST_TO_RAW(p_national_id || TO_CHAR(SYSDATE, 'YYYYMMDDHH24MISS')),
        DBMS_CRYPTO.HASH_SH256
    ));
    
    -- Generate encryption key
    v_encryption_key := RAWTOHEX(DBMS_CRYPTO.RANDOMBYTES(16));
    
    -- Insert citizen record
    INSERT INTO citizens (
        citizen_id, national_id, first_name, last_name, date_of_birth,
        email, phone_number, address, status, created_by
    ) VALUES (
        p_citizen_id, p_national_id, p_first_name, p_last_name, p_date_of_birth,
        p_email, p_phone_number, p_address, 'ACTIVE', USER
    );
    
    -- Insert digital ID record
    INSERT INTO digital_ids (
        digital_id, citizen_id, id_number, biometric_hash,
        issue_date, expiry_date, id_type, security_level,
        is_active, encryption_key
    ) VALUES (
        p_digital_id, p_citizen_id, v_id_number, v_biometric_hash,
        SYSDATE, ADD_MONTHS(SYSDATE, 60), p_id_type, 3,
        'Y', v_encryption_key
    );
    
    COMMIT;
    
    p_status_message := 'SUCCESS: Citizen registered with ID ' || p_citizen_id;
    
EXCEPTION
    WHEN e_invalid_age THEN
        ROLLBACK;
        p_status_message := 'ERROR: Citizen must be 18 years or older. Current age: ' || ROUND(v_age, 1);
    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        p_status_message := 'ERROR: National ID or Email already exists in system';
    WHEN OTHERS THEN
        ROLLBACK;
        p_status_message := 'ERROR: ' || SQLERRM;
END add_citizen;
/

-- =====================================================
-- PROCEDURE 2: UPDATE_CITIZEN_STATUS
-- Purpose: Change citizen account status
-- Parameters: IN (citizen_id, new status, reason)
-- =====================================================
CREATE OR REPLACE PROCEDURE update_citizen_status(
    p_citizen_id  IN NUMBER,
    p_new_status  IN VARCHAR2,
    p_reason      IN VARCHAR2,
    p_updated_by  IN VARCHAR2 DEFAULT USER
)
IS
    v_old_status VARCHAR2(20);
    v_count      NUMBER;
    
    e_invalid_status EXCEPTION;
    e_citizen_not_found EXCEPTION;
BEGIN
    -- Validate new status
    IF p_new_status NOT IN ('ACTIVE', 'SUSPENDED', 'INACTIVE') THEN
        RAISE e_invalid_status;
    END IF;
    
    -- Check if citizen exists
    SELECT COUNT(*) INTO v_count
    FROM citizens
    WHERE citizen_id = p_citizen_id;
    
    IF v_count = 0 THEN
        RAISE e_citizen_not_found;
    END IF;
    
    -- Get old status
    SELECT status INTO v_old_status
    FROM citizens
    WHERE citizen_id = p_citizen_id;
    
    -- Update status
    UPDATE citizens
    SET status = p_new_status,
        modified_by = p_updated_by,
        modified_date = SYSTIMESTAMP
    WHERE citizen_id = p_citizen_id;
    
    -- If suspending or deactivating, also deactivate digital ID
    IF p_new_status IN ('SUSPENDED', 'INACTIVE') THEN
        UPDATE digital_ids
        SET is_active = 'N'
        WHERE citizen_id = p_citizen_id;
    END IF;
    
    -- Create alert if status changed to SUSPENDED
    IF p_new_status = 'SUSPENDED' THEN
        INSERT INTO alerts (
            alert_id, citizen_id, alert_type, severity,
            alert_message, status
        ) VALUES (
            seq_alert_id.NEXTVAL, p_citizen_id, 'SUSPICIOUS_ACCESS', 'HIGH',
            'Account suspended: ' || p_reason, 'NEW'
        );
    END IF;
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('Citizen ' || p_citizen_id || ' status changed from ' || 
                         v_old_status || ' to ' || p_new_status);
    
EXCEPTION
    WHEN e_invalid_status THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20001, 'Invalid status. Must be ACTIVE, SUSPENDED, or INACTIVE');
    WHEN e_citizen_not_found THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20002, 'Citizen ID ' || p_citizen_id || ' not found');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20003, 'Error updating citizen status: ' || SQLERRM);
END update_citizen_status;
/

-- =====================================================
-- PROCEDURE 3: GRANT_CONSENT
-- Purpose: Citizen grants data access consent
-- Parameters: IN (citizen_id, category_name, consent_level, entity_type)
-- =====================================================
CREATE OR REPLACE PROCEDURE grant_consent(
    p_citizen_id     IN NUMBER,
    p_category_name  IN VARCHAR2,
    p_consent_level  IN VARCHAR2 DEFAULT 'PARTIAL',
    p_entity_type    IN VARCHAR2 DEFAULT NULL,
    p_expiry_months  IN NUMBER DEFAULT 12
)
IS
    v_category_id NUMBER;
    v_consent_id  NUMBER;
    
    e_invalid_level EXCEPTION;
    e_category_not_found EXCEPTION;
BEGIN
    -- Validate consent level
    IF p_consent_level NOT IN ('FULL', 'PARTIAL', 'RESTRICTED') THEN
        RAISE e_invalid_level;
    END IF;
    
    -- Get category ID
    BEGIN
        SELECT category_id INTO v_category_id
        FROM data_categories
        WHERE category_name = p_category_name;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE e_category_not_found;
    END;
    
    -- Check if consent already exists
    BEGIN
        SELECT consent_id INTO v_consent_id
        FROM consent_records
        WHERE citizen_id = p_citizen_id
          AND data_category_id = v_category_id
          AND (entity_type = p_entity_type OR (entity_type IS NULL AND p_entity_type IS NULL))
          AND consent_status = 'GRANTED'
          AND ROWNUM = 1;
        
        -- Update existing consent
        UPDATE consent_records
        SET consent_level = p_consent_level,
            expiry_date = ADD_MONTHS(SYSDATE, p_expiry_months),
            granted_date = SYSTIMESTAMP
        WHERE consent_id = v_consent_id;
        
        DBMS_OUTPUT.PUT_LINE('Consent updated: ID ' || v_consent_id);
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            -- Insert new consent
            v_consent_id := seq_consent_id.NEXTVAL;
            
            INSERT INTO consent_records (
                consent_id, citizen_id, data_category_id, entity_type,
                consent_status, granted_date, expiry_date, consent_level
            ) VALUES (
                v_consent_id, p_citizen_id, v_category_id, p_entity_type,
                'GRANTED', SYSTIMESTAMP, ADD_MONTHS(SYSDATE, p_expiry_months), p_consent_level
            );
            
            DBMS_OUTPUT.PUT_LINE('New consent granted: ID ' || v_consent_id);
    END;
    
    COMMIT;
    
EXCEPTION
    WHEN e_invalid_level THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20004, 'Invalid consent level. Must be FULL, PARTIAL, or RESTRICTED');
    WHEN e_category_not_found THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20005, 'Data category not found: ' || p_category_name);
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20006, 'Error granting consent: ' || SQLERRM);
END grant_consent;
/

-- =====================================================
-- PROCEDURE 4: REVOKE_CONSENT
-- Purpose: Citizen revokes data access consent
-- Parameters: IN (citizen_id, category_name, entity_type)
-- =====================================================
CREATE OR REPLACE PROCEDURE revoke_consent(
    p_citizen_id    IN NUMBER,
    p_category_name IN VARCHAR2,
    p_entity_type   IN VARCHAR2 DEFAULT NULL
)
IS
    v_category_id NUMBER;
    v_rows_updated NUMBER := 0;
BEGIN
    -- Get category ID
    SELECT category_id INTO v_category_id
    FROM data_categories
    WHERE category_name = p_category_name;
    
    -- Revoke consent
    UPDATE consent_records
    SET consent_status = 'REVOKED',
        revoked_date = SYSTIMESTAMP
    WHERE citizen_id = p_citizen_id
      AND data_category_id = v_category_id
      AND (entity_type = p_entity_type OR (entity_type IS NULL AND p_entity_type IS NULL))
      AND consent_status = 'GRANTED';
    
    v_rows_updated := SQL%ROWCOUNT;
    
    IF v_rows_updated = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No active consent found to revoke');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Consent revoked: ' || v_rows_updated || ' record(s) updated');
    END IF;
    
    COMMIT;
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20007, 'Data category not found: ' || p_category_name);
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20008, 'Error revoking consent: ' || SQLERRM);
END revoke_consent;
/

-- =====================================================
-- PROCEDURE 5: SUBMIT_ACCESS_REQUEST
-- Purpose: Entity submits request to access citizen data
-- Parameters: IN (entity_id, digital_id, purpose, data_category), OUT (request_id, status)
-- =====================================================
CREATE OR REPLACE PROCEDURE submit_access_request(
    p_entity_id      IN  NUMBER,
    p_digital_id     IN  NUMBER,
    p_purpose        IN  VARCHAR2,
    p_data_category  IN  VARCHAR2,
    p_ip_address     IN  VARCHAR2 DEFAULT NULL,
    p_request_id     OUT NUMBER,
    p_status_message OUT VARCHAR2
)
IS
    v_entity_status    VARCHAR2(20);
    v_citizen_id       NUMBER;
    v_consent_status   VARCHAR2(20);
    v_risk_score       NUMBER;
    v_request_status   VARCHAR2(20);
    
    e_entity_not_authorized EXCEPTION;
    e_no_consent EXCEPTION;
BEGIN
    -- Validate entity authorization
    v_entity_status := validate_entity_authorization(p_entity_id);
    
    IF v_entity_status != 'VALID' THEN
        RAISE e_entity_not_authorized;
    END IF;
    
    -- Get citizen ID from digital ID
    SELECT citizen_id INTO v_citizen_id
    FROM digital_ids
    WHERE digital_id = p_digital_id
      AND is_active = 'Y';
    
    -- Check consent
    v_consent_status := check_consent(v_citizen_id, p_data_category);
    
    IF v_consent_status NOT IN ('GRANTED') THEN
        RAISE e_no_consent;
    END IF;
    
    -- Calculate risk score
    v_risk_score := calculate_risk_score(p_entity_id, p_digital_id);
    
    -- Determine initial status
    IF v_risk_score >= 0.7 THEN
        v_request_status := 'PENDING'; -- High risk requires manual review
    ELSE
        v_request_status := 'APPROVED'; -- Auto-approve low risk
    END IF;
    
    -- Generate request ID
    p_request_id := seq_request_id.NEXTVAL;
    
    -- Insert access request
    INSERT INTO access_requests (
        request_id, entity_id, digital_id, purpose, data_category,
        request_status, risk_score, ip_address, created_by
    ) VALUES (
        p_request_id, p_entity_id, p_digital_id, p_purpose, p_data_category,
        v_request_status, v_risk_score, p_ip_address, USER
    );
    
    -- Log the request attempt
    INSERT INTO access_logs (
        log_id, request_id, action_type, action_by,
        action_result, ip_address
    ) VALUES (
        seq_log_id.NEXTVAL, p_request_id, 'ATTEMPT', USER,
        v_request_status, p_ip_address
    );
    
    -- Create alert if high risk
    IF v_risk_score >= 0.7 THEN
        INSERT INTO alerts (
            alert_id, citizen_id, request_id, alert_type,
            severity, alert_message
        ) VALUES (
            seq_alert_id.NEXTVAL, v_citizen_id, p_request_id, 'UNUSUAL_PATTERN',
            'HIGH', 'High-risk access request (score: ' || v_risk_score || ')'
        );
    END IF;
    
    COMMIT;
    
    p_status_message := 'SUCCESS: Request ' || v_request_status || ' (Risk: ' || v_risk_score || ')';
    
EXCEPTION
    WHEN e_entity_not_authorized THEN
        ROLLBACK;
        p_status_message := 'ERROR: Entity not authorized - Status: ' || v_entity_status;
    WHEN e_no_consent THEN
        ROLLBACK;
        p_status_message := 'ERROR: No valid consent found - Status: ' || v_consent_status;
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        p_status_message := 'ERROR: Digital ID not found or inactive';
    WHEN OTHERS THEN
        ROLLBACK;
        p_status_message := 'ERROR: ' || SQLERRM;
END submit_access_request;
/

-- =====================================================
-- PROCEDURE 6: APPROVE_ACCESS_REQUEST
-- Purpose: DPO approves or denies access request
-- Parameters: IN (request_id, decision, approved_by, notes)
-- =====================================================
CREATE OR REPLACE PROCEDURE approve_access_request(
    p_request_id  IN NUMBER,
    p_decision    IN VARCHAR2, -- 'APPROVED' or 'DENIED'
    p_approved_by IN VARCHAR2,
    p_notes       IN VARCHAR2 DEFAULT NULL
)
IS
    v_old_status VARCHAR2(20);
    v_entity_id  NUMBER;
    v_digital_id NUMBER;
    
    e_invalid_decision EXCEPTION;
    e_request_not_found EXCEPTION;
BEGIN
    -- Validate decision
    IF p_decision NOT IN ('APPROVED', 'DENIED') THEN
        RAISE e_invalid_decision;
    END IF;
    
    -- Get current request details
    BEGIN
        SELECT request_status, entity_id, digital_id
        INTO v_old_status, v_entity_id, v_digital_id
        FROM access_requests
        WHERE request_id = p_request_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE e_request_not_found;
    END;
    
    -- Update request
    UPDATE access_requests
    SET request_status = p_decision,
        approved_by = p_approved_by,
        approval_date = SYSTIMESTAMP,
        access_start_time = CASE WHEN p_decision = 'APPROVED' THEN SYSTIMESTAMP ELSE NULL END,
        access_end_time = CASE WHEN p_decision = 'APPROVED' THEN SYSTIMESTAMP + 1 ELSE NULL END
    WHERE request_id = p_request_id;
    
    -- Log the decision
    INSERT INTO access_logs (
        log_id, request_id, action_type, action_by,
        action_result, denial_reason
    ) VALUES (
        seq_log_id.NEXTVAL, p_request_id, 'VIEW', p_approved_by,
        p_decision, p_notes
    );
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('Request ' || p_request_id || ' ' || p_decision || ' by ' || p_approved_by);
    
EXCEPTION
    WHEN e_invalid_decision THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20009, 'Invalid decision. Must be APPROVED or DENIED');
    WHEN e_request_not_found THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20010, 'Access request not found: ' || p_request_id);
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20011, 'Error approving request: ' || SQLERRM);
END approve_access_request;
/

-- =====================================================
-- PROCEDURE 7: LOG_VIOLATION
-- Purpose: Record a privacy violation
-- Parameters: IN (request_id, entity_id, violation_type, description)
-- =====================================================
CREATE OR REPLACE PROCEDURE log_violation(
    p_request_id      IN NUMBER,
    p_entity_id       IN NUMBER,
    p_violation_type  IN VARCHAR2,
    p_description     IN VARCHAR2,
    p_penalty_amount  IN NUMBER DEFAULT NULL
)
IS
    v_violation_id NUMBER;
BEGIN
    v_violation_id := seq_violation_id.NEXTVAL;
    
    INSERT INTO violations (
        violation_id, request_id, entity_id, violation_type,
        description, penalty_amount, status
    ) VALUES (
        v_violation_id, p_request_id, p_entity_id, p_violation_type,
        p_description, p_penalty_amount, 'INVESTIGATING'
    );
    
    -- Update entity status to SUSPENDED if serious violation
    IF p_violation_type IN ('UNAUTHORIZED_ACCESS', 'DATA_MISUSE') THEN
        UPDATE authorized_entities
        SET status = 'SUSPENDED'
        WHERE entity_id = p_entity_id;
        
        DBMS_OUTPUT.PUT_LINE('Entity ' || p_entity_id || ' suspended due to serious violation');
    END IF;
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('Violation logged: ID ' || v_violation_id);
    
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20012, 'Error logging violation: ' || SQLERRM);
END log_violation;
/

-- =====================================================
-- VERIFY PROCEDURES CREATED
-- =====================================================
SELECT object_name, status, object_type
FROM user_objects
WHERE object_type = 'PROCEDURE'
ORDER BY object_name;

PROMPT
PROMPT ===== ALL PROCEDURES CREATED SUCCESSFULLY =====
PROMPT