
SET SERVEROUTPUT ON SIZE UNLIMITED;
SET LINESIZE 200;

PROMPT
PROMPT =====================================================
PROMPT PHASE VI TESTING - DIGITAL ID PRIVACY SYSTEM
PROMPT Student: KALISA INEZA JOVITH (26259)
PROMPT =====================================================
PROMPT

-- =====================================================
-- TEST 1: ADD_CITIZEN PROCEDURE
-- =====================================================
PROMPT === TEST 1: Adding New Citizen ===
DECLARE
    v_citizen_id NUMBER;
    v_digital_id NUMBER;
    v_status_msg VARCHAR2(500);
BEGIN
    add_citizen(
        p_national_id    => '1199900001234567',
        p_first_name     => 'Jovith',
        p_last_name      => 'Kalisa',
        p_date_of_birth  => DATE '2000-01-15',
        p_email          => 'jovith.kalisa@test.rw',
        p_phone_number   => '+250788999001',
        p_address        => 'KG 100 Ave, Kigali',
        p_id_type        => 'NATIONAL',
        p_citizen_id     => v_citizen_id,
        p_digital_id     => v_digital_id,
        p_status_message => v_status_msg
    );
    
    DBMS_OUTPUT.PUT_LINE('Result: ' || v_status_msg);
    DBMS_OUTPUT.PUT_LINE('Citizen ID: ' || v_citizen_id);
    DBMS_OUTPUT.PUT_LINE('Digital ID: ' || v_digital_id);
    DBMS_OUTPUT.PUT_LINE('');
END;
/

-- Test adding duplicate (should fail)
PROMPT === TEST 1B: Adding Duplicate Citizen (Should Fail) ===
DECLARE
    v_citizen_id NUMBER;
    v_digital_id NUMBER;
    v_status_msg VARCHAR2(500);
BEGIN
    add_citizen(
        p_national_id    => '1199900001234567', -- Duplicate
        p_first_name     => 'Test',
        p_last_name      => 'Duplicate',
        p_date_of_birth  => DATE '2000-01-15',
        p_email          => 'duplicate@test.rw',
        p_phone_number   => '+250788999002',
        p_address        => 'Test Address',
        p_id_type        => 'NATIONAL',
        p_citizen_id     => v_citizen_id,
        p_digital_id     => v_digital_id,
        p_status_message => v_status_msg
    );
    
    DBMS_OUTPUT.PUT_LINE('Result: ' || v_status_msg);
    DBMS_OUTPUT.PUT_LINE('');
END;
/

-- =====================================================
-- TEST 2: GRANT_CONSENT PROCEDURE
-- =====================================================
PROMPT === TEST 2: Granting Consent ===
DECLARE
    v_citizen_id NUMBER;
BEGIN
    -- Get newly created citizen
    SELECT citizen_id INTO v_citizen_id
    FROM citizens
    WHERE national_id = '1199900001234567';
    
    DBMS_OUTPUT.PUT_LINE('Granting consents for citizen: ' || v_citizen_id);
    
    -- Grant multiple consents
    grant_consent(v_citizen_id, 'PERSONAL_INFO', 'FULL', 'GOVERNMENT', 12);
    grant_consent(v_citizen_id, 'CONTACT_DETAILS', 'PARTIAL', 'BANK', 12);
    grant_consent(v_citizen_id, 'FINANCIAL_INFO', 'RESTRICTED', 'BANK', 6);
    
    DBMS_OUTPUT.PUT_LINE('All consents granted successfully');
    DBMS_OUTPUT.PUT_LINE('');
END;
/

-- =====================================================
-- TEST 3: CHECK_CONSENT FUNCTION
-- =====================================================
PROMPT === TEST 3: Checking Consent Status ===
DECLARE
    v_citizen_id NUMBER;
    v_status VARCHAR2(50);
BEGIN
    SELECT citizen_id INTO v_citizen_id
    FROM citizens
    WHERE national_id = '1199900001234567';
    
    v_status := check_consent(v_citizen_id, 'PERSONAL_INFO', 'GOVERNMENT');
    DBMS_OUTPUT.PUT_LINE('PERSONAL_INFO for GOVERNMENT: ' || v_status);
    
    v_status := check_consent(v_citizen_id, 'HEALTH_RECORDS', NULL);
    DBMS_OUTPUT.PUT_LINE('HEALTH_RECORDS (no consent): ' || v_status);
    
    DBMS_OUTPUT.PUT_LINE('');
END;
/

-- =====================================================
-- TEST 4: SUBMIT_ACCESS_REQUEST PROCEDURE
-- =====================================================
PROMPT === TEST 4: Submitting Access Requests ===
DECLARE
    v_entity_id NUMBER;
    v_digital_id NUMBER;
    v_request_id NUMBER;
    v_status_msg VARCHAR2(500);
BEGIN
    -- Get entity and digital ID
    SELECT entity_id INTO v_entity_id
    FROM authorized_entities
    WHERE entity_type = 'GOVERNMENT'
      AND status = 'ACTIVE'
      AND ROWNUM = 1;
    
    SELECT digital_id INTO v_digital_id
    FROM citizens c
    JOIN digital_ids d ON c.citizen_id = d.citizen_id
    WHERE c.national_id = '1199900001234567';
    
    DBMS_OUTPUT.PUT_LINE('Entity ID: ' || v_entity_id);
    DBMS_OUTPUT.PUT_LINE('Digital ID: ' || v_digital_id);
    
    -- Submit access request
    submit_access_request(
        p_entity_id      => v_entity_id,
        p_digital_id     => v_digital_id,
        p_purpose        => 'Tax verification for fiscal year 2025',
        p_data_category  => 'PERSONAL_INFO',
        p_ip_address     => '192.168.1.100',
        p_request_id     => v_request_id,
        p_status_message => v_status_msg
    );
    
    DBMS_OUTPUT.PUT_LINE('Request ID: ' || v_request_id);
    DBMS_OUTPUT.PUT_LINE('Status: ' || v_status_msg);
    DBMS_OUTPUT.PUT_LINE('');
END;
/

-- =====================================================
-- TEST 5: CALCULATE_RISK_SCORE FUNCTION
-- =====================================================
PROMPT === TEST 5: Risk Score Calculation ===
DECLARE
    v_entity_id NUMBER;
    v_digital_id NUMBER;
    v_risk NUMBER;
BEGIN
    SELECT entity_id INTO v_entity_id
    FROM authorized_entities
    WHERE status = 'ACTIVE'
      AND ROWNUM = 1;
    
    SELECT digital_id INTO v_digital_id
    FROM digital_ids
    WHERE is_active = 'Y'
      AND ROWNUM = 1;
    
    v_risk := calculate_risk_score(v_entity_id, v_digital_id);
    
    DBMS_OUTPUT.PUT_LINE('Entity: ' || v_entity_id || ', Digital ID: ' || v_digital_id);
    DBMS_OUTPUT.PUT_LINE('Risk Score: ' || v_risk);
    DBMS_OUTPUT.PUT_LINE('Risk Level: ' || 
        CASE 
            WHEN v_risk >= 0.7 THEN 'HIGH - Manual Review Required'
            WHEN v_risk >= 0.4 THEN 'MODERATE - Monitor Closely'
            ELSE 'LOW - Auto-Approve'
        END);
    DBMS_OUTPUT.PUT_LINE('');
END;
/

-- =====================================================
-- TEST 6: IS_WEEKDAY and IS_HOLIDAY FUNCTIONS
-- =====================================================
PROMPT === TEST 6: Date Validation Functions ===
BEGIN
    DBMS_OUTPUT.PUT_LINE('Testing Date Functions:');
    DBMS_OUTPUT.PUT_LINE('Today (' || TO_CHAR(SYSDATE, 'Day, DD-MON-YYYY') || '):');
    
    IF is_weekday(SYSDATE) THEN
        DBMS_OUTPUT.PUT_LINE('  - Is a WEEKDAY (Mon-Fri) - DML RESTRICTED');
    ELSE
        DBMS_OUTPUT.PUT_LINE('  - Is a WEEKEND (Sat-Sun) - DML ALLOWED');
    END IF;
    
    IF is_holiday(SYSDATE) THEN
        DBMS_OUTPUT.PUT_LINE('  - Is a HOLIDAY - DML RESTRICTED');
    ELSE
        DBMS_OUTPUT.PUT_LINE('  - Is NOT a holiday');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Test specific dates
    DBMS_OUTPUT.PUT_LINE('Christmas 2025 (25-DEC-2025):');
    IF is_holiday(DATE '2025-12-25') THEN
        DBMS_OUTPUT.PUT_LINE('  - Correctly identified as HOLIDAY');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('');
END;
/

-- =====================================================
-- TEST 7: PACKAGE PKG_CITIZEN_MGMT
-- =====================================================
PROMPT === TEST 7: Citizen Management Package ===
DECLARE
    v_citizen_id NUMBER;
    v_status_msg VARCHAR2(500);
    v_count NUMBER;
BEGIN
    -- Register new citizen using package
    pkg_citizen_mgmt.register_citizen(
        p_national_id    => '1198800005555555',
        p_first_name     => 'Marie',
        p_last_name      => 'Uwase',
        p_date_of_birth  => DATE '1988-05-20',
        p_email          => 'marie.uwase@test.rw',
        p_phone_number   => '+250788888001',
        p_address        => 'KG 200 Ave, Kigali',
        p_citizen_id     => v_citizen_id,
        p_status_message => v_status_msg
    );
    
    DBMS_OUTPUT.PUT_LINE('Package Registration: ' || v_status_msg);
    
    -- Count active citizens
    v_count := pkg_citizen_mgmt.count_active_citizens;
    DBMS_OUTPUT.PUT_LINE('Total Active Citizens: ' || v_count);
    
    -- Update contact info
    pkg_citizen_mgmt.update_contact_info(
        p_citizen_id   => v_citizen_id,
        p_email        => 'marie.uwase.new@test.rw',
        p_phone_number => '+250788888002'
    );
    DBMS_OUTPUT.PUT_LINE('Contact info updated for citizen: ' || v_citizen_id);
    
    DBMS_OUTPUT.PUT_LINE('');
END;
/

-- =====================================================
-- TEST 8: PACKAGE PKG_ACCESS_CONTROL
-- =====================================================
PROMPT === TEST 8: Access Control Package ===
DECLARE
    v_request_id NUMBER;
    v_status_msg VARCHAR2(500);
    v_entity_id NUMBER;
    v_digital_id NUMBER;
    v_cursor SYS_REFCURSOR;
    v_count NUMBER := 0;
BEGIN
    -- Get IDs for testing
    SELECT entity_id INTO v_entity_id
    FROM authorized_entities
    WHERE status = 'ACTIVE' AND ROWNUM = 1;
    
    SELECT digital_id INTO v_digital_id
    FROM digital_ids
    WHERE is_active = 'Y' AND ROWNUM = 1;
    
    -- Request access using package
    pkg_access_control.request_access(
        p_entity_id      => v_entity_id,
        p_digital_id     => v_digital_id,
        p_purpose        => 'Package test - Account verification',
        p_data_category  => 'CONTACT_DETAILS',
        p_request_id     => v_request_id,
        p_status_message => v_status_msg
    );
    
    DBMS_OUTPUT.PUT_LINE('Access Request: ' || v_status_msg);
    DBMS_OUTPUT.PUT_LINE('Request ID: ' || v_request_id);
    
    -- Get pending requests count
    v_cursor := pkg_access_control.get_pending_requests(10);
    CLOSE v_cursor;
    
    DBMS_OUTPUT.PUT_LINE('Pending requests cursor opened successfully');
    DBMS_OUTPUT.PUT_LINE('');
END;
/

-- =====================================================
-- TEST 9: PACKAGE PKG_AUDIT - Access Report
-- =====================================================
PROMPT === TEST 9: Audit Package - Access Report ===
BEGIN
    pkg_audit.generate_access_report(
        p_start_date => SYSDATE - 30,
        p_end_date   => SYSDATE
    );
    DBMS_OUTPUT.PUT_LINE('');
END;
/

-- =====================================================
-- TEST 10: WINDOW FUNCTIONS - Top Risky Requests
-- =====================================================
PROMPT === TEST 10: Window Functions - Top Risky Requests ===
SELECT 
    request_id,
    entity_id,
    risk_score,
    request_date,
    ROW_NUMBER() OVER (ORDER BY risk_score DESC) AS risk_rank,
    CASE 
        WHEN risk_score >= 0.7 THEN 'HIGH'
        WHEN risk_score >= 0.4 THEN 'MODERATE'
        ELSE 'LOW'
    END AS risk_category
FROM access_requests
WHERE request_date >= SYSDATE - 7
ORDER BY risk_score DESC
FETCH FIRST 10 ROWS ONLY;

PROMPT
-- =====================================================
-- TEST 11: GET_ACCESS_COUNT FUNCTION
-- =====================================================
PROMPT === TEST 11: Entity Access Count ===
DECLARE
    v_entity_id NUMBER;
    v_count_30d NUMBER;
    v_count_7d  NUMBER;
    v_denied    NUMBER;
BEGIN
    SELECT entity_id INTO v_entity_id
    FROM authorized_entities
    WHERE status = 'ACTIVE' AND ROWNUM = 1;
    
    v_count_30d := get_access_count(v_entity_id, 30);
    v_count_7d  := get_access_count(v_entity_id, 7);
    v_denied    := get_access_count(v_entity_id, 30, 'DENIED');
    
    DBMS_OUTPUT.PUT_LINE('Entity ID: ' || v_entity_id);
    DBMS_OUTPUT.PUT_LINE('Requests (last 30 days): ' || v_count_30d);
    DBMS_OUTPUT.PUT_LINE('Requests (last 7 days): ' || v_count_7d);
    DBMS_OUTPUT.PUT_LINE('Denied requests: ' || v_denied);
    DBMS_OUTPUT.PUT_LINE('');
END;
/

-- =====================================================
-- TEST 12: UPDATE_CITIZEN_STATUS PROCEDURE
-- =====================================================
PROMPT === TEST 12: Update Citizen Status ===
DECLARE
    v_citizen_id NUMBER;
BEGIN
    SELECT citizen_id INTO v_citizen_id
    FROM citizens
    WHERE national_id = '1199900001234567';
    
    DBMS_OUTPUT.PUT_LINE('Suspending citizen: ' || v_citizen_id);
    
    update_citizen_status(
        p_citizen_id => v_citizen_id,
        p_new_status => 'SUSPENDED',
        p_reason     => 'Testing suspension functionality'
    );
    
    -- Check alert was created
    DECLARE
        v_alert_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_alert_count
        FROM alerts
        WHERE citizen_id = v_citizen_id
          AND alert_date >= SYSDATE - 1/1440; -- Last minute
        
        DBMS_OUTPUT.PUT_LINE('Alerts created: ' || v_alert_count);
    END;
    
    -- Reactivate
    DBMS_OUTPUT.PUT_LINE('Reactivating citizen...');
    update_citizen_status(
        p_citizen_id => v_citizen_id,
        p_new_status => 'ACTIVE',
        p_reason     => 'Test completed - reactivating'
    );
    
    DBMS_OUTPUT.PUT_LINE('');
END;
/

-- =====================================================
-- TEST 13: REVOKE_CONSENT PROCEDURE
-- =====================================================
PROMPT === TEST 13: Revoke Consent ===
DECLARE
    v_citizen_id NUMBER;
BEGIN
    SELECT citizen_id INTO v_citizen_id
    FROM citizens
    WHERE national_id = '1199900001234567';
    
    DBMS_OUTPUT.PUT_LINE('Revoking FINANCIAL_INFO consent for citizen: ' || v_citizen_id);
    
    revoke_consent(v_citizen_id, 'FINANCIAL_INFO', 'BANK');
    
    -- Verify revocation
    DECLARE
        v_status VARCHAR2(50);
    BEGIN
        v_status := check_consent(v_citizen_id, 'FINANCIAL_INFO', 'BANK');
        DBMS_OUTPUT.PUT_LINE('Current consent status: ' || v_status);
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
END;
/

-- =====================================================
-- TEST 14: VALIDATE_ENTITY_AUTHORIZATION FUNCTION
-- =====================================================
PROMPT === TEST 14: Entity Authorization Validation ===
DECLARE
    v_entity_id NUMBER;
    v_status VARCHAR2(50);
BEGIN
    -- Test valid entity
    SELECT entity_id INTO v_entity_id
    FROM authorized_entities
    WHERE status = 'ACTIVE' AND ROWNUM = 1;
    
    v_status := validate_entity_authorization(v_entity_id);
    DBMS_OUTPUT.PUT_LINE('Active Entity ' || v_entity_id || ': ' || v_status);
    
    -- Test suspended entity
    BEGIN
        SELECT entity_id INTO v_entity_id
        FROM authorized_entities
        WHERE status = 'SUSPENDED' AND ROWNUM = 1;
        
        v_status := validate_entity_authorization(v_entity_id);
        DBMS_OUTPUT.PUT_LINE('Suspended Entity ' || v_entity_id || ': ' || v_status);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('No suspended entities found for testing');
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
END;
/

-- =====================================================
-- SUMMARY: Verify All Objects Created
-- =====================================================
PROMPT
PROMPT =====================================================
PROMPT PHASE VI COMPLETION SUMMARY
PROMPT =====================================================
PROMPT

PROMPT === Functions Created ===
SELECT object_name, status
FROM user_objects
WHERE object_type = 'FUNCTION'
ORDER BY object_name;

PROMPT
PROMPT === Procedures Created ===
SELECT object_name, status
FROM user_objects
WHERE object_type = 'PROCEDURE'
ORDER BY object_name;

PROMPT
PROMPT === Packages Created ===
SELECT object_name, object_type, status
FROM user_objects
WHERE object_type IN ('PACKAGE', 'PACKAGE BODY')
ORDER BY object_name, object_type;

PROMPT
PROMPT =====================================================
PROMPT ALL PHASE VI TESTS COMPLETED SUCCESSFULLY!
PROMPT =====================================================
PROMPT
PROMPT Next Step: Continue to Phase VII (Triggers & Auditing)
PROMPT