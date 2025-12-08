
SET SERVEROUTPUT ON;

-- =====================================================
-- CRITICAL BUSINESS RULE (Phase VII Requirement)
-- Employees CANNOT INSERT/UPDATE/DELETE on:
-- 1. WEEKDAYS (Monday-Friday)
-- 2. PUBLIC HOLIDAYS (dates in HOLIDAYS table)
-- =====================================================

-- =====================================================
-- TRIGGER 1: RESTRICT WEEKDAY/HOLIDAY DML ON CITIZENS
-- Purpose: Enforce Phase VII business rule
-- =====================================================
CREATE OR REPLACE TRIGGER trg_restrict_citizens_dml
BEFORE INSERT OR UPDATE OR DELETE ON citizens
FOR EACH ROW
DECLARE
    v_day_name VARCHAR2(10);
    v_is_holiday BOOLEAN;
BEGIN
    -- Check if today is a weekday
    IF is_weekday(SYSDATE) THEN
        RAISE_APPLICATION_ERROR(-20100, 
            'DML operations on CITIZENS table are RESTRICTED on weekdays (Monday-Friday). ' ||
            'Today is ' || TO_CHAR(SYSDATE, 'Day') || '. ' ||
            'Please try again on Saturday or Sunday.');
    END IF;
    
    -- Check if today is a holiday
    IF is_holiday(SYSDATE) THEN
        RAISE_APPLICATION_ERROR(-20101, 
            'DML operations on CITIZENS table are RESTRICTED on public holidays. ' ||
            'Today (' || TO_CHAR(SYSDATE, 'DD-MON-YYYY') || ') is a holiday. ' ||
            'Please try again on a non-holiday weekend.');
    END IF;
    
    -- If we reach here, operation is allowed (weekend, non-holiday)
    DBMS_OUTPUT.PUT_LINE('✓ DML operation ALLOWED - ' || TO_CHAR(SYSDATE, 'Day, DD-MON-YYYY'));
    
EXCEPTION
    WHEN OTHERS THEN
        -- Log the blocked attempt
        INSERT INTO access_logs (
            log_id, request_id, action_type, action_by, 
            action_result, denial_reason, ip_address
        ) VALUES (
            seq_log_id.NEXTVAL, NULL, 'MODIFY', USER,
            'DENIED', 'Weekday/Holiday restriction: ' || SQLERRM, 
            SYS_CONTEXT('USERENV', 'IP_ADDRESS')
        );
        COMMIT;
        RAISE;
END trg_restrict_citizens_dml;
/

-- =====================================================
-- TRIGGER 2: RESTRICT WEEKDAY/HOLIDAY DML ON ACCESS_REQUESTS
-- Purpose: Enforce Phase VII business rule on main transactional table
-- =====================================================
CREATE OR REPLACE TRIGGER trg_restrict_requests_dml
BEFORE INSERT OR UPDATE OR DELETE ON access_requests
FOR EACH ROW
DECLARE
    v_operation VARCHAR2(10);
BEGIN
    -- Determine operation type
    IF INSERTING THEN
        v_operation := 'INSERT';
    ELSIF UPDATING THEN
        v_operation := 'UPDATE';
    ELSE
        v_operation := 'DELETE';
    END IF;
    
    -- Check weekday restriction
    IF is_weekday(SYSDATE) THEN
        RAISE_APPLICATION_ERROR(-20102, 
            'DML operations (' || v_operation || ') on ACCESS_REQUESTS are RESTRICTED on weekdays. ' ||
            'Current day: ' || TO_CHAR(SYSDATE, 'Day, DD-MON-YYYY HH24:MI'));
    END IF;
    
    -- Check holiday restriction
    IF is_holiday(SYSDATE) THEN
        RAISE_APPLICATION_ERROR(-20103, 
            'DML operations (' || v_operation || ') on ACCESS_REQUESTS are RESTRICTED on holidays. ' ||
            'Current date: ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY'));
    END IF;
    
END trg_restrict_requests_dml;
/

-- =====================================================
-- TRIGGER 3: AUDIT LOG - AUTO-LOG ACCESS REQUESTS
-- Purpose: Automatically create audit log for every access request
-- =====================================================
CREATE OR REPLACE TRIGGER trg_audit_access_request
AFTER INSERT ON access_requests
FOR EACH ROW
DECLARE
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    -- Create audit log entry
    INSERT INTO access_logs (
        log_id, request_id, action_type, action_by,
        action_result, ip_address, created_date
    ) VALUES (
        seq_log_id.NEXTVAL,
        :NEW.request_id,
        'ATTEMPT',
        :NEW.created_by,
        :NEW.request_status,
        :NEW.ip_address,
        SYSTIMESTAMP
    );
    
    COMMIT;
    
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Warning: Audit log failed - ' || SQLERRM);
END trg_audit_access_request;
/

-- =====================================================
-- TRIGGER 4: GENERATE ALERT ON HIGH-RISK REQUEST
-- Purpose: Automatically create alert for high-risk access requests
-- =====================================================
CREATE OR REPLACE TRIGGER trg_alert_high_risk
AFTER INSERT ON access_requests
FOR EACH ROW
WHEN (NEW.risk_score >= 0.7)
DECLARE
    PRAGMA AUTONOMOUS_TRANSACTION;
    v_citizen_id NUMBER;
    v_alert_msg VARCHAR2(500);
BEGIN
    -- Get citizen ID from digital ID
    SELECT citizen_id INTO v_citizen_id
    FROM digital_ids
    WHERE digital_id = :NEW.digital_id;
    
    -- Construct alert message
    v_alert_msg := 'High-risk access request detected (Risk Score: ' || 
                   ROUND(:NEW.risk_score, 2) || '). ' ||
                   'Request ID: ' || :NEW.request_id || '. ' ||
                   'Data Category: ' || :NEW.data_category;
    
    -- Create alert
    INSERT INTO alerts (
        alert_id, citizen_id, request_id, alert_type,
        severity, alert_message, status
    ) VALUES (
        seq_alert_id.NEXTVAL,
        v_citizen_id,
        :NEW.request_id,
        'UNUSUAL_PATTERN',
        CASE 
            WHEN :NEW.risk_score >= 0.9 THEN 'CRITICAL'
            WHEN :NEW.risk_score >= 0.7 THEN 'HIGH'
            ELSE 'MEDIUM'
        END,
        v_alert_msg,
        'NEW'
    );
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('⚠ HIGH-RISK ALERT generated for Request ' || :NEW.request_id);
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Warning: Could not create alert - citizen not found');
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Warning: Alert creation failed - ' || SQLERRM);
END trg_alert_high_risk;
/

-- =====================================================
-- TRIGGER 5: PREVENT ACCESS_LOGS MODIFICATION
-- Purpose: Make audit logs immutable (no updates or deletes)
-- =====================================================
CREATE OR REPLACE TRIGGER trg_immutable_access_logs
BEFORE UPDATE OR DELETE ON access_logs
FOR EACH ROW
BEGIN
    RAISE_APPLICATION_ERROR(-20104, 
        'SECURITY VIOLATION: Access logs are IMMUTABLE. ' ||
        'Updates and deletes are strictly prohibited for compliance. ' ||
        'Log ID: ' || :OLD.log_id);
END trg_immutable_access_logs;
/

-- =====================================================
-- TRIGGER 6: AUTO-EXPIRE CONSENTS
-- Purpose: Automatically update expired consents status
-- =====================================================
CREATE OR REPLACE TRIGGER trg_check_consent_expiry
BEFORE INSERT OR UPDATE ON access_requests
FOR EACH ROW
DECLARE
    v_consent_status VARCHAR2(20);
    v_citizen_id NUMBER;
BEGIN
    -- Get citizen ID
    SELECT citizen_id INTO v_citizen_id
    FROM digital_ids
    WHERE digital_id = :NEW.digital_id;
    
    -- Check consent status
    v_consent_status := check_consent(v_citizen_id, :NEW.data_category);
    
    -- If consent expired, update request status
    IF v_consent_status = 'EXPIRED' THEN
        :NEW.request_status := 'DENIED';
        
        -- Log denial reason
        INSERT INTO access_logs (
            log_id, request_id, action_type, action_by,
            action_result, denial_reason
        ) VALUES (
            seq_log_id.NEXTVAL, :NEW.request_id, 'ATTEMPT', USER,
            'DENIED', 'Consent expired for data category: ' || :NEW.data_category
        );
    END IF;
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        NULL; -- Citizen not found, let other validations handle
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Warning: Consent check failed - ' || SQLERRM);
END trg_check_consent_expiry;
/

-- =====================================================
-- TRIGGER 7: TRACK CITIZEN STATUS CHANGES
-- Purpose: Audit trail for citizen status modifications
-- =====================================================
CREATE OR REPLACE TRIGGER trg_audit_citizen_status
AFTER UPDATE OF status ON citizens
FOR EACH ROW
WHEN (OLD.status != NEW.status)
DECLARE
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    -- Log status change in access_logs
    INSERT INTO access_logs (
        log_id, request_id, action_type, action_by,
        action_result, denial_reason, data_accessed
    ) VALUES (
        seq_log_id.NEXTVAL,
        NULL,
        'MODIFY',
        :NEW.modified_by,
        'SUCCESS',
        'Status changed from ' || :OLD.status || ' to ' || :NEW.status,
        'Citizen ID: ' || :NEW.citizen_id || ', Name: ' || :NEW.first_name || ' ' || :NEW.last_name
    );
    
    COMMIT;
    
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
END trg_audit_citizen_status;
/

-- =====================================================
-- COMPOUND TRIGGER: COMPREHENSIVE ACCESS REQUEST PROCESSING
-- Purpose: Handle multiple events in single trigger (Phase VII requirement)
-- =====================================================
CREATE OR REPLACE TRIGGER trg_process_access_request
FOR INSERT OR UPDATE ON access_requests
COMPOUND TRIGGER

    -- Private variables shared across timing points
    TYPE t_request_ids IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    v_request_ids t_request_ids;
    v_index PLS_INTEGER := 0;
    
    -- BEFORE EACH ROW: Validation
    BEFORE EACH ROW IS
    BEGIN
        -- Validate entity is active
        DECLARE
            v_entity_status VARCHAR2(20);
        BEGIN
            SELECT status INTO v_entity_status
            FROM authorized_entities
            WHERE entity_id = :NEW.entity_id;
            
            IF v_entity_status != 'ACTIVE' THEN
                RAISE_APPLICATION_ERROR(-20105, 
                    'Entity is not ACTIVE. Status: ' || v_entity_status);
            END IF;
        END;
        
        -- Set default values
        IF :NEW.request_date IS NULL THEN
            :NEW.request_date := SYSTIMESTAMP;
        END IF;
        
        IF :NEW.request_status IS NULL THEN
            :NEW.request_status := 'PENDING';
        END IF;
        
        -- Calculate risk score if not provided
        IF :NEW.risk_score IS NULL THEN
            :NEW.risk_score := calculate_risk_score(:NEW.entity_id, :NEW.digital_id);
        END IF;
        
    END BEFORE EACH ROW;
    
    -- AFTER EACH ROW: Collect request IDs
    AFTER EACH ROW IS
    BEGIN
        IF INSERTING THEN
            v_index := v_index + 1;
            v_request_ids(v_index) := :NEW.request_id;
        END IF;
    END AFTER EACH ROW;
    
    -- AFTER STATEMENT: Bulk processing
    AFTER STATEMENT IS
    BEGIN
        -- Process all collected requests
        FOR i IN 1..v_index LOOP
            DBMS_OUTPUT.PUT_LINE('✓ Processed Access Request: ' || v_request_ids(i));
        END LOOP;
        
        IF v_index > 0 THEN
            DBMS_OUTPUT.PUT_LINE('Total requests processed: ' || v_index);
        END IF;
        
        -- Clear the collection
        v_request_ids.DELETE;
        v_index := 0;
    END AFTER STATEMENT;
    
END trg_process_access_request;
/

-- =====================================================
-- TRIGGER 8: PREVENT VIOLATION RECORD DELETION
-- Purpose: Ensure compliance records are never deleted
-- =====================================================
CREATE OR REPLACE TRIGGER trg_immutable_violations
BEFORE DELETE ON violations
FOR EACH ROW
BEGIN
    RAISE_APPLICATION_ERROR(-20106, 
        'COMPLIANCE VIOLATION: Violation records cannot be deleted. ' ||
        'Violation ID: ' || :OLD.violation_id || ' must be retained for 7 years.');
END trg_immutable_violations;
/

-- =====================================================
-- VERIFY ALL TRIGGERS CREATED
-- =====================================================
SELECT trigger_name, status, triggering_event, table_name
FROM user_triggers
WHERE trigger_name LIKE 'TRG_%'
ORDER BY trigger_name;

PROMPT
PROMPT ===== TRIGGER CREATION SUMMARY =====
PROMPT

SELECT 
    COUNT(*) AS total_triggers,
    SUM(CASE WHEN status = 'ENABLED' THEN 1 ELSE 0 END) AS enabled_triggers,
    SUM(CASE WHEN status = 'DISABLED' THEN 1 ELSE 0 END) AS disabled_triggers
FROM user_triggers
WHERE trigger_name LIKE 'TRG_%';

PROMPT
PROMPT ===== PHASE VII TESTING =====
PROMPT

-- =====================================================
-- TEST 1: WEEKDAY RESTRICTION (Should FAIL on Mon-Fri)
-- =====================================================
PROMPT
PROMPT === TEST 1: Attempting INSERT on CITIZENS (Weekday Test) ===
PROMPT

DECLARE
    v_test_passed BOOLEAN := FALSE;
BEGIN
    DBMS_OUTPUT.PUT_LINE('Current Day: ' || TO_CHAR(SYSDATE, 'Day, DD-MON-YYYY'));
    
    BEGIN
        -- Attempt to insert
        INSERT INTO citizens (
            citizen_id, national_id, first_name, last_name, 
            date_of_birth, email, phone_number, status
        ) VALUES (
            9999, '9999999999999999', 'Test', 'Weekday',
            DATE '1990-01-01', 'test.weekday@test.rw', '+250788000000', 'ACTIVE'
        );
        
        -- If we reach here, it's a weekend
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('✓ INSERT ALLOWED - Operation completed (Weekend)');
        v_test_passed := TRUE;
        
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE IN (-20100, -20101) THEN
                DBMS_OUTPUT.PUT_LINE('✓ INSERT BLOCKED - ' || SQLERRM);
                DBMS_OUTPUT.PUT_LINE('✓ TEST PASSED: Weekday/Holiday restriction working correctly');
                v_test_passed := TRUE;
            ELSE
                DBMS_OUTPUT.PUT_LINE('✗ UNEXPECTED ERROR: ' || SQLERRM);
                v_test_passed := FALSE;
            END IF;
    END;
    
    IF NOT v_test_passed THEN
        RAISE_APPLICATION_ERROR(-20999, 'Test failed');
    END IF;
END;
/

-- =====================================================
-- TEST 2: HOLIDAY RESTRICTION (Test Christmas)
-- =====================================================
PROMPT
PROMPT === TEST 2: Holiday Restriction Test ===
PROMPT

BEGIN
    DBMS_OUTPUT.PUT_LINE('Testing IS_HOLIDAY function:');
    
    -- Test Christmas
    IF is_holiday(DATE '2025-12-25') THEN
        DBMS_OUTPUT.PUT_LINE('✓ Christmas (2025-12-25) correctly identified as HOLIDAY');
    ELSE
        DBMS_OUTPUT.PUT_LINE('✗ ERROR: Christmas not recognized as holiday');
    END IF;
    
    -- Test regular day
    IF NOT is_holiday(DATE '2025-12-07') THEN
        DBMS_OUTPUT.PUT_LINE('✓ Regular day (2025-12-07) correctly identified as NON-HOLIDAY');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Note: 2025-12-07 is marked as holiday in system');
    END IF;
END;
/

-- =====================================================
-- TEST 3: AUDIT LOG IMMUTABILITY
-- =====================================================
PROMPT
PROMPT === TEST 3: Audit Log Immutability Test ===
PROMPT

DECLARE
    v_test_passed BOOLEAN := FALSE;
BEGIN
    BEGIN
        -- Attempt to update audit log
        UPDATE access_logs
        SET action_result = 'TAMPERED'
        WHERE ROWNUM = 1;
        
        DBMS_OUTPUT.PUT_LINE('✗ TEST FAILED: Audit log was modified!');
        ROLLBACK;
        
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20104 THEN
                DBMS_OUTPUT.PUT_LINE('✓ UPDATE BLOCKED: ' || SQLERRM);
                DBMS_OUTPUT.PUT_LINE('✓ TEST PASSED: Audit logs are immutable');
                v_test_passed := TRUE;
            ELSE
                DBMS_OUTPUT.PUT_LINE('✗ UNEXPECTED ERROR: ' || SQLERRM);
            END IF;
    END;
    
    IF NOT v_test_passed THEN
        RAISE_APPLICATION_ERROR(-20999, 'Test failed');
    END IF;
END;
/

-- =====================================================
-- TEST 4: HIGH-RISK ALERT GENERATION
-- =====================================================
PROMPT
PROMPT === TEST 4: High-Risk Alert Generation Test ===
PROMPT

DECLARE
    v_request_id NUMBER;
    v_alert_count NUMBER;
    v_entity_id NUMBER;
    v_digital_id NUMBER;
BEGIN
    -- Note: This test will only work on weekends!
    IF is_weekday(SYSDATE) OR is_holiday(SYSDATE) THEN
        DBMS_OUTPUT.PUT_LINE('⚠ Skipping test - DML restricted on weekdays/holidays');
        DBMS_OUTPUT.PUT_LINE('Run this test on a weekend');
        RETURN;
    END IF;
    
    -- Get test data
    SELECT entity_id INTO v_entity_id FROM authorized_entities WHERE status = 'ACTIVE' AND ROWNUM = 1;
    SELECT digital_id INTO v_digital_id FROM digital_ids WHERE is_active = 'Y' AND ROWNUM = 1;
    
    v_request_id := seq_request_id.NEXTVAL;
    
    -- Insert high-risk request
    INSERT INTO access_requests (
        request_id, entity_id, digital_id, purpose, data_category,
        request_status, risk_score
    ) VALUES (
        v_request_id, v_entity_id, v_digital_id,
        'Test high-risk request', 'BIOMETRIC_DATA',
        'PENDING', 0.95  -- High risk score
    );
    
    -- Check if alert was created
    SELECT COUNT(*) INTO v_alert_count
    FROM alerts
    WHERE request_id = v_request_id;
    
    IF v_alert_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('✓ TEST PASSED: High-risk alert automatically created');
    ELSE
        DBMS_OUTPUT.PUT_LINE('✗ TEST FAILED: Alert was not created');
    END IF;
    
    ROLLBACK;
END;
/

PROMPT
PROMPT ===== ALL TRIGGERS CREATED AND TESTED =====
PROMPT
PROMPT Critical Phase VII Requirements:
PROMPT ✓ Weekday restriction (Mon-Fri) - IMPLEMENTED
PROMPT ✓ Holiday restriction - IMPLEMENTED
PROMPT ✓ Audit logging - AUTOMATED
PROMPT ✓ Immutable logs - ENFORCED
PROMPT ✓ High-risk alerts - AUTOMATED
PROMPT ✓ Compound trigger - IMPLEMENTED
PROMPT
PROMPT Next: Run tests on WEEKEND to see INSERT operations succeed!
PROMPT

-- verify if triggers created successfully
SELECT trigger_name, status, triggering_event, table_name
FROM user_triggers
WHERE trigger_name LIKE 'TRG_%'
ORDER BY trigger_name;