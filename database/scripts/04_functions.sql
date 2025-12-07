
SET SERVEROUTPUT ON;

-- =====================================================
-- FUNCTION 1: CHECK_CONSENT
-- Purpose: Verify if citizen has granted consent for data category
-- Returns: VARCHAR2 ('GRANTED', 'REVOKED', 'EXPIRED', 'NOT_FOUND')
-- =====================================================
CREATE OR REPLACE FUNCTION check_consent(
    p_citizen_id    IN NUMBER,
    p_category_name IN VARCHAR2,
    p_entity_type   IN VARCHAR2 DEFAULT NULL
) RETURN VARCHAR2
IS
    v_consent_status VARCHAR2(20);
    v_expiry_date    DATE;
    v_category_id    NUMBER;
BEGIN
    -- Get category ID
    SELECT category_id INTO v_category_id
    FROM data_categories
    WHERE category_name = p_category_name;
    
    -- Check consent status
    SELECT consent_status, expiry_date
    INTO v_consent_status, v_expiry_date
    FROM consent_records
    WHERE citizen_id = p_citizen_id
      AND data_category_id = v_category_id
      AND (entity_type = p_entity_type OR entity_type IS NULL OR p_entity_type IS NULL)
      AND ROWNUM = 1
    ORDER BY granted_date DESC;
    
    -- Check if expired
    IF v_consent_status = 'GRANTED' AND v_expiry_date < SYSDATE THEN
        RETURN 'EXPIRED';
    END IF;
    
    RETURN v_consent_status;
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 'NOT_FOUND';
    WHEN OTHERS THEN
        RETURN 'ERROR: ' || SQLERRM;
END check_consent;
/

-- =====================================================
-- FUNCTION 2: IS_WEEKDAY
-- Purpose: Check if current date is a weekday (Mon-Fri)
-- Returns: BOOLEAN (TRUE if weekday, FALSE if weekend)
-- =====================================================
CREATE OR REPLACE FUNCTION is_weekday(
    p_check_date IN DATE DEFAULT SYSDATE
) RETURN BOOLEAN
IS
    v_day_name VARCHAR2(10);
BEGIN
    v_day_name := TRIM(TO_CHAR(p_check_date, 'DAY'));
    
    IF v_day_name IN ('MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY') THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN TRUE; -- Fail-safe: treat as weekday to prevent operations
END is_weekday;
/

-- =====================================================
-- FUNCTION 3: IS_HOLIDAY
-- Purpose: Check if given date is a public holiday
-- Returns: BOOLEAN (TRUE if holiday, FALSE otherwise)
-- =====================================================
CREATE OR REPLACE FUNCTION is_holiday(
    p_check_date IN DATE DEFAULT SYSDATE
) RETURN BOOLEAN
IS
    v_holiday_count NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO v_holiday_count
    FROM holidays
    WHERE TRUNC(holiday_date) = TRUNC(p_check_date);
    
    IF v_holiday_count > 0 THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN TRUE; -- Fail-safe: treat as holiday to prevent operations
END is_holiday;
/

-- =====================================================
-- FUNCTION 4: CALCULATE_RISK_SCORE
-- Purpose: Calculate risk score for access request based on patterns
-- Returns: NUMBER (0.0 to 1.0, where 1.0 = highest risk)
-- =====================================================
CREATE OR REPLACE FUNCTION calculate_risk_score(
    p_entity_id  IN NUMBER,
    p_digital_id IN NUMBER
) RETURN NUMBER
IS
    v_recent_requests     NUMBER := 0;
    v_denied_requests     NUMBER := 0;
    v_unusual_time        NUMBER := 0;
    v_multiple_entities   NUMBER := 0;
    v_risk_score          NUMBER := 0;
    v_current_hour        NUMBER;
BEGIN
    v_current_hour := TO_NUMBER(TO_CHAR(SYSDATE, 'HH24'));
    
    -- Factor 1: Recent request count from same entity (last 24 hours)
    SELECT COUNT(*)
    INTO v_recent_requests
    FROM access_requests
    WHERE entity_id = p_entity_id
      AND request_date >= SYSDATE - 1;
    
    -- Factor 2: Denied requests from entity (last 30 days)
    SELECT COUNT(*)
    INTO v_denied_requests
    FROM access_requests
    WHERE entity_id = p_entity_id
      AND request_status = 'DENIED'
      AND request_date >= SYSDATE - 30;
    
    -- Factor 3: Unusual access time (midnight to 6am)
    IF v_current_hour >= 0 AND v_current_hour < 6 THEN
        v_unusual_time := 1;
    END IF;
    
    -- Factor 4: Multiple entities accessing same ID (last 7 days)
    SELECT COUNT(DISTINCT entity_id)
    INTO v_multiple_entities
    FROM access_requests
    WHERE digital_id = p_digital_id
      AND request_date >= SYSDATE - 7;
    
    -- Calculate risk score (weighted average)
    v_risk_score := (
        (LEAST(v_recent_requests, 10) / 10 * 0.3) +      -- 30% weight
        (LEAST(v_denied_requests, 5) / 5 * 0.3) +        -- 30% weight
        (v_unusual_time * 0.2) +                         -- 20% weight
        (LEAST(v_multiple_entities, 10) / 10 * 0.2)      -- 20% weight
    );
    
    RETURN ROUND(v_risk_score, 2);
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN 0.5; -- Default moderate risk if calculation fails
END calculate_risk_score;
/

-- =====================================================
-- FUNCTION 5: GET_ACCESS_COUNT
-- Purpose: Get total access count for an entity
-- Returns: NUMBER (count of all access requests)
-- =====================================================
CREATE OR REPLACE FUNCTION get_access_count(
    p_entity_id   IN NUMBER,
    p_days_back   IN NUMBER DEFAULT 30,
    p_status_filter IN VARCHAR2 DEFAULT NULL
) RETURN NUMBER
IS
    v_count NUMBER := 0;
BEGIN
    IF p_status_filter IS NULL THEN
        SELECT COUNT(*)
        INTO v_count
        FROM access_requests
        WHERE entity_id = p_entity_id
          AND request_date >= SYSDATE - p_days_back;
    ELSE
        SELECT COUNT(*)
        INTO v_count
        FROM access_requests
        WHERE entity_id = p_entity_id
          AND request_date >= SYSDATE - p_days_back
          AND request_status = p_status_filter;
    END IF;
    
    RETURN v_count;
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN 0;
END get_access_count;
/

-- =====================================================
-- FUNCTION 6: VALIDATE_ENTITY_AUTHORIZATION
-- Purpose: Check if entity is authorized and active
-- Returns: VARCHAR2 ('VALID', 'SUSPENDED', 'REVOKED', 'EXPIRED', 'NOT_FOUND')
-- =====================================================
CREATE OR REPLACE FUNCTION validate_entity_authorization(
    p_entity_id IN NUMBER
) RETURN VARCHAR2
IS
    v_status       VARCHAR2(20);
    v_expiry_date  DATE;
BEGIN
    SELECT status, expiry_date
    INTO v_status, v_expiry_date
    FROM authorized_entities
    WHERE entity_id = p_entity_id;
    
    -- Check status
    IF v_status != 'ACTIVE' THEN
        RETURN v_status;
    END IF;
    
    -- Check expiry
    IF v_expiry_date < SYSDATE THEN
        RETURN 'EXPIRED';
    END IF;
    
    RETURN 'VALID';
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 'NOT_FOUND';
    WHEN OTHERS THEN
        RETURN 'ERROR';
END validate_entity_authorization;
/

-- =====================================================
-- FUNCTION 7: GET_CITIZEN_ID_BY_NATIONAL_ID
-- Purpose: Lookup citizen ID by national ID number
-- Returns: NUMBER (citizen_id)
-- =====================================================
CREATE OR REPLACE FUNCTION get_citizen_id_by_national_id(
    p_national_id IN VARCHAR2
) RETURN NUMBER
IS
    v_citizen_id NUMBER;
BEGIN
    SELECT citizen_id
    INTO v_citizen_id
    FROM citizens
    WHERE national_id = p_national_id
      AND status = 'ACTIVE';
    
    RETURN v_citizen_id;
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;
    WHEN TOO_MANY_ROWS THEN
        RETURN -1; -- Error: duplicate national IDs found
    WHEN OTHERS THEN
        RETURN -2; -- Error: other exception
END get_citizen_id_by_national_id;
/

-- =====================================================
-- VERIFY FUNCTIONS CREATED
-- =====================================================
SELECT object_name, status, object_type
FROM user_objects
WHERE object_type = 'FUNCTION'
  AND object_name IN (
    'CHECK_CONSENT',
    'IS_WEEKDAY',
    'IS_HOLIDAY',
    'CALCULATE_RISK_SCORE',
    'GET_ACCESS_COUNT',
    'VALIDATE_ENTITY_AUTHORIZATION',
    'GET_CITIZEN_ID_BY_NATIONAL_ID'
)
ORDER BY object_name;

-- =====================================================
-- TEST FUNCTIONS
-- =====================================================
SET SERVEROUTPUT ON;

BEGIN
    DBMS_OUTPUT.PUT_LINE('=== TESTING FUNCTIONS ===');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Test 1: Check if today is weekday
    DBMS_OUTPUT.PUT_LINE('Test 1: Is today a weekday?');
    IF is_weekday(SYSDATE) THEN
        DBMS_OUTPUT.PUT_LINE('Result: YES (Monday-Friday)');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Result: NO (Weekend)');
    END IF;
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Test 2: Check if today is holiday
    DBMS_OUTPUT.PUT_LINE('Test 2: Is today a holiday?');
    IF is_holiday(SYSDATE) THEN
        DBMS_OUTPUT.PUT_LINE('Result: YES');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Result: NO');
    END IF;
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Test 3: Check specific date (Christmas)
    DBMS_OUTPUT.PUT_LINE('Test 3: Is December 25, 2025 a holiday?');
    IF is_holiday(DATE '2025-12-25') THEN
        DBMS_OUTPUT.PUT_LINE('Result: YES (Christmas)');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Result: NO');
    END IF;
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Test 4: Calculate risk score for first entity and digital ID
    DECLARE
        v_risk NUMBER;
    BEGIN
        SELECT calculate_risk_score(
            (SELECT entity_id FROM authorized_entities WHERE ROWNUM = 1),
            (SELECT digital_id FROM digital_ids WHERE ROWNUM = 1)
        ) INTO v_risk FROM dual;
        
        DBMS_OUTPUT.PUT_LINE('Test 4: Risk Score Calculation');
        DBMS_OUTPUT.PUT_LINE('Result: ' || v_risk || ' (0.0 = low risk, 1.0 = high risk)');
        DBMS_OUTPUT.PUT_LINE('');
    END;
    
    -- Test 5: Validate entity authorization
    DECLARE
        v_status VARCHAR2(50);
    BEGIN
        SELECT validate_entity_authorization(
            (SELECT entity_id FROM authorized_entities WHERE status = 'ACTIVE' AND ROWNUM = 1)
        ) INTO v_status FROM dual;
        
        DBMS_OUTPUT.PUT_LINE('Test 5: Entity Authorization Check');
        DBMS_OUTPUT.PUT_LINE('Result: ' || v_status);
        DBMS_OUTPUT.PUT_LINE('');
    END;
    
    DBMS_OUTPUT.PUT_LINE('=== ALL FUNCTION TESTS COMPLETED ===');
END;
/