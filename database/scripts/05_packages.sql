-- =====================================================
-- PHASE VI: PACKAGES SCRIPT
-- Project: Digital ID Data Privacy and Access Monitoring System
-- Student: KALISA INEZA JOVITH (26259)
-- File: database/scripts/05_packages.sql
-- =====================================================

SET SERVEROUTPUT ON;

-- =====================================================
-- PACKAGE 1: PKG_CITIZEN_MGMT
-- Purpose: Citizen management operations
-- =====================================================

-- Package Specification (Public Interface)
CREATE OR REPLACE PACKAGE pkg_citizen_mgmt AS
    -- Public procedures
    PROCEDURE register_citizen(
        p_national_id    IN  VARCHAR2,
        p_first_name     IN  VARCHAR2,
        p_last_name      IN  VARCHAR2,
        p_date_of_birth  IN  DATE,
        p_email          IN  VARCHAR2,
        p_phone_number   IN  VARCHAR2,
        p_address        IN  VARCHAR2,
        p_citizen_id     OUT NUMBER,
        p_status_message OUT VARCHAR2
    );
    
    PROCEDURE update_status(
        p_citizen_id IN NUMBER,
        p_new_status IN VARCHAR2,
        p_reason     IN VARCHAR2
    );
    
    PROCEDURE update_contact_info(
        p_citizen_id   IN NUMBER,
        p_email        IN VARCHAR2 DEFAULT NULL,
        p_phone_number IN VARCHAR2 DEFAULT NULL,
        p_address      IN VARCHAR2 DEFAULT NULL
    );
    
    FUNCTION get_citizen_info(
        p_citizen_id IN NUMBER
    ) RETURN SYS_REFCURSOR;
    
    FUNCTION count_active_citizens RETURN NUMBER;
    
END pkg_citizen_mgmt;
/

-- Package Body (Implementation)
CREATE OR REPLACE PACKAGE BODY pkg_citizen_mgmt AS

    -- Register new citizen
    PROCEDURE register_citizen(
        p_national_id    IN  VARCHAR2,
        p_first_name     IN  VARCHAR2,
        p_last_name      IN  VARCHAR2,
        p_date_of_birth  IN  DATE,
        p_email          IN  VARCHAR2,
        p_phone_number   IN  VARCHAR2,
        p_address        IN  VARCHAR2,
        p_citizen_id     OUT NUMBER,
        p_status_message OUT VARCHAR2
    ) IS
        v_digital_id NUMBER;
    BEGIN
        -- Call the standalone procedure
        add_citizen(
            p_national_id, p_first_name, p_last_name, p_date_of_birth,
            p_email, p_phone_number, p_address, 'NATIONAL',
            p_citizen_id, v_digital_id, p_status_message
        );
    END register_citizen;
    
    -- Update citizen status
    PROCEDURE update_status(
        p_citizen_id IN NUMBER,
        p_new_status IN VARCHAR2,
        p_reason     IN VARCHAR2
    ) IS
    BEGIN
        update_citizen_status(p_citizen_id, p_new_status, p_reason);
    END update_status;
    
    -- Update contact information
    PROCEDURE update_contact_info(
        p_citizen_id   IN NUMBER,
        p_email        IN VARCHAR2 DEFAULT NULL,
        p_phone_number IN VARCHAR2 DEFAULT NULL,
        p_address      IN VARCHAR2 DEFAULT NULL
    ) IS
    BEGIN
        UPDATE citizens
        SET email = NVL(p_email, email),
            phone_number = NVL(p_phone_number, phone_number),
            address = NVL(p_address, address),
            modified_by = USER,
            modified_date = SYSTIMESTAMP
        WHERE citizen_id = p_citizen_id;
        
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20013, 'Citizen not found: ' || p_citizen_id);
        END IF;
        
        COMMIT;
    END update_contact_info;
    
    -- Get citizen information
    FUNCTION get_citizen_info(
        p_citizen_id IN NUMBER
    ) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT c.citizen_id, c.national_id, c.first_name, c.last_name,
                   c.date_of_birth, c.email, c.phone_number, c.address,
                   c.status, d.id_number, d.is_active AS digital_id_active
            FROM citizens c
            LEFT JOIN digital_ids d ON c.citizen_id = d.citizen_id
            WHERE c.citizen_id = p_citizen_id;
        
        RETURN v_cursor;
    END get_citizen_info;
    
    -- Count active citizens
    FUNCTION count_active_citizens RETURN NUMBER IS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*)
        INTO v_count
        FROM citizens
        WHERE status = 'ACTIVE';
        
        RETURN v_count;
    END count_active_citizens;
    
END pkg_citizen_mgmt;
/

-- =====================================================
-- PACKAGE 2: PKG_ACCESS_CONTROL
-- Purpose: Access request and consent management
-- =====================================================

-- Package Specification
CREATE OR REPLACE PACKAGE pkg_access_control AS
    -- Public procedures
    PROCEDURE request_access(
        p_entity_id      IN  NUMBER,
        p_digital_id     IN  NUMBER,
        p_purpose        IN  VARCHAR2,
        p_data_category  IN  VARCHAR2,
        p_request_id     OUT NUMBER,
        p_status_message OUT VARCHAR2
    );
    
    PROCEDURE manage_consent(
        p_citizen_id    IN NUMBER,
        p_category_name IN VARCHAR2,
        p_action        IN VARCHAR2, -- 'GRANT' or 'REVOKE'
        p_consent_level IN VARCHAR2 DEFAULT 'PARTIAL'
    );
    
    PROCEDURE review_request(
        p_request_id IN NUMBER,
        p_decision   IN VARCHAR2,
        p_reviewer   IN VARCHAR2
    );
    
    FUNCTION get_pending_requests(
        p_limit IN NUMBER DEFAULT 100
    ) RETURN SYS_REFCURSOR;
    
    FUNCTION get_high_risk_requests RETURN SYS_REFCURSOR;
    
END pkg_access_control;
/

-- Package Body
CREATE OR REPLACE PACKAGE BODY pkg_access_control AS

    -- Submit access request
    PROCEDURE request_access(
        p_entity_id      IN  NUMBER,
        p_digital_id     IN  NUMBER,
        p_purpose        IN  VARCHAR2,
        p_data_category  IN  VARCHAR2,
        p_request_id     OUT NUMBER,
        p_status_message OUT VARCHAR2
    ) IS
    BEGIN
        submit_access_request(
            p_entity_id, p_digital_id, p_purpose, p_data_category,
            NULL, p_request_id, p_status_message
        );
    END request_access;
    
    -- Manage consent (grant or revoke)
    PROCEDURE manage_consent(
        p_citizen_id    IN NUMBER,
        p_category_name IN VARCHAR2,
        p_action        IN VARCHAR2,
        p_consent_level IN VARCHAR2 DEFAULT 'PARTIAL'
    ) IS
    BEGIN
        IF p_action = 'GRANT' THEN
            grant_consent(p_citizen_id, p_category_name, p_consent_level);
        ELSIF p_action = 'REVOKE' THEN
            revoke_consent(p_citizen_id, p_category_name);
        ELSE
            RAISE_APPLICATION_ERROR(-20014, 'Invalid action. Must be GRANT or REVOKE');
        END IF;
    END manage_consent;
    
    -- Review access request
    PROCEDURE review_request(
        p_request_id IN NUMBER,
        p_decision   IN VARCHAR2,
        p_reviewer   IN VARCHAR2
    ) IS
    BEGIN
        approve_access_request(p_request_id, p_decision, p_reviewer);
    END review_request;
    
    -- Get pending requests
    FUNCTION get_pending_requests(
        p_limit IN NUMBER DEFAULT 100
    ) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT ar.request_id, ar.entity_id, ae.entity_name,
                   ar.digital_id, ar.purpose, ar.data_category,
                   ar.risk_score, ar.request_date
            FROM access_requests ar
            JOIN authorized_entities ae ON ar.entity_id = ae.entity_id
            WHERE ar.request_status = 'PENDING'
            ORDER BY ar.risk_score DESC, ar.request_date
            FETCH FIRST p_limit ROWS ONLY;
        
        RETURN v_cursor;
    END get_pending_requests;
    
    -- Get high-risk requests
    FUNCTION get_high_risk_requests RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT ar.request_id, ar.entity_id, ae.entity_name,
                   ar.digital_id, ar.purpose, ar.risk_score,
                   ar.request_status, ar.request_date
            FROM access_requests ar
            JOIN authorized_entities ae ON ar.entity_id = ae.entity_id
            WHERE ar.risk_score >= 0.7
            ORDER BY ar.risk_score DESC, ar.request_date DESC;
        
        RETURN v_cursor;
    END get_high_risk_requests;
    
END pkg_access_control;
/

-- =====================================================
-- PACKAGE 3: PKG_AUDIT
-- Purpose: Auditing and reporting utilities
-- =====================================================

-- Package Specification
CREATE OR REPLACE PACKAGE pkg_audit AS
    -- Public procedures
    PROCEDURE generate_access_report(
        p_start_date IN DATE,
        p_end_date   IN DATE,
        p_entity_id  IN NUMBER DEFAULT NULL
    );
    
    PROCEDURE generate_violation_report(
        p_start_date IN DATE,
        p_end_date   IN DATE
    );
    
    FUNCTION get_access_history(
        p_citizen_id IN NUMBER,
        p_days_back  IN NUMBER DEFAULT 30
    ) RETURN SYS_REFCURSOR;
    
    FUNCTION get_entity_activity(
        p_entity_id IN NUMBER,
        p_days_back IN NUMBER DEFAULT 30
    ) RETURN SYS_REFCURSOR;
    
    PROCEDURE cleanup_old_logs(
        p_retention_days IN NUMBER DEFAULT 2555 -- ~7 years
    );
    
END pkg_audit;
/

-- Package Body
CREATE OR REPLACE PACKAGE BODY pkg_audit AS

    -- Generate access report
    PROCEDURE generate_access_report(
        p_start_date IN DATE,
        p_end_date   IN DATE,
        p_entity_id  IN NUMBER DEFAULT NULL
    ) IS
        CURSOR c_access IS
            SELECT ae.entity_name,
                   ar.request_status,
                   COUNT(*) AS request_count,
                   AVG(ar.risk_score) AS avg_risk_score
            FROM access_requests ar
            JOIN authorized_entities ae ON ar.entity_id = ae.entity_id
            WHERE ar.request_date BETWEEN p_start_date AND p_end_date
              AND (p_entity_id IS NULL OR ar.entity_id = p_entity_id)
            GROUP BY ae.entity_name, ar.request_status
            ORDER BY ae.entity_name, ar.request_status;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('=== ACCESS REPORT ===');
        DBMS_OUTPUT.PUT_LINE('Period: ' || TO_CHAR(p_start_date, 'YYYY-MM-DD') || 
                           ' to ' || TO_CHAR(p_end_date, 'YYYY-MM-DD'));
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE(RPAD('Entity', 40) || RPAD('Status', 15) || 
                           RPAD('Count', 10) || 'Avg Risk');
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 80, '-'));
        
        FOR rec IN c_access LOOP
            DBMS_OUTPUT.PUT_LINE(
                RPAD(rec.entity_name, 40) ||
                RPAD(rec.request_status, 15) ||
                RPAD(rec.request_count, 10) ||
                ROUND(rec.avg_risk_score, 2)
            );
        END LOOP;
    END generate_access_report;
    
    -- Generate violation report
    PROCEDURE generate_violation_report(
        p_start_date IN DATE,
        p_end_date   IN DATE
    ) IS
        CURSOR c_violations IS
            SELECT v.violation_type,
                   COUNT(*) AS violation_count,
                   SUM(v.penalty_amount) AS total_penalties
            FROM violations v
            WHERE v.violation_date BETWEEN p_start_date AND p_end_date
            GROUP BY v.violation_type
            ORDER BY violation_count DESC;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('=== VIOLATION REPORT ===');
        DBMS_OUTPUT.PUT_LINE('Period: ' || TO_CHAR(p_start_date, 'YYYY-MM-DD') || 
                           ' to ' || TO_CHAR(p_end_date, 'YYYY-MM-DD'));
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE(RPAD('Violation Type', 40) || 
                           RPAD('Count', 10) || 'Total Penalties');
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 70, '-'));
        
        FOR rec IN c_violations LOOP
            DBMS_OUTPUT.PUT_LINE(
                RPAD(rec.violation_type, 40) ||
                RPAD(rec.violation_count, 10) ||
                NVL(TO_CHAR(rec.total_penalties, '$999,999.99'), 'N/A')
            );
        END LOOP;
    END generate_violation_report;
    
    -- Get citizen access history
    FUNCTION get_access_history(
        p_citizen_id IN NUMBER,
        p_days_back  IN NUMBER DEFAULT 30
    ) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT ar.request_id, ae.entity_name, ae.entity_type,
                   ar.data_category, ar.request_status, ar.risk_score,
                   ar.request_date, al.action_result
            FROM digital_ids di
            JOIN access_requests ar ON di.digital_id = ar.digital_id
            JOIN authorized_entities ae ON ar.entity_id = ae.entity_id
            LEFT JOIN access_logs al ON ar.request_id = al.request_id
            WHERE di.citizen_id = p_citizen_id
              AND ar.request_date >= SYSDATE - p_days_back
            ORDER BY ar.request_date DESC;
        
        RETURN v_cursor;
    END get_access_history;
    
    -- Get entity activity
    FUNCTION get_entity_activity(
        p_entity_id IN NUMBER,
        p_days_back IN NUMBER DEFAULT 30
    ) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT ar.request_id, ar.digital_id, ar.purpose,
                   ar.data_category, ar.request_status, ar.risk_score,
                   ar.request_date, al.action_result
            FROM access_requests ar
            LEFT JOIN access_logs al ON ar.request_id = al.request_id
            WHERE ar.entity_id = p_entity_id
              AND ar.request_date >= SYSDATE - p_days_back
            ORDER BY ar.request_date DESC;
        
        RETURN v_cursor;
    END get_entity_activity;
    
    -- Cleanup old logs (for maintenance)
    PROCEDURE cleanup_old_logs(
        p_retention_days IN NUMBER DEFAULT 2555
    ) IS
        v_deleted_count NUMBER;
    BEGIN
        -- Note: In production, ACCESS_LOGS should be immutable
        -- This is for demonstration purposes only
        DELETE FROM access_logs
        WHERE action_timestamp < SYSDATE - p_retention_days;
        
        v_deleted_count := SQL%ROWCOUNT;
        
        COMMIT;
        
        DBMS_OUTPUT.PUT_LINE('Cleaned up ' || v_deleted_count || ' old log records');
    END cleanup_old_logs;
    
END pkg_audit;
/

-- =====================================================
-- VERIFY PACKAGES CREATED
-- =====================================================
SELECT object_name, object_type, status
FROM user_objects
WHERE object_type IN ('PACKAGE', 'PACKAGE BODY')
ORDER BY object_name, object_type;

PROMPT
PROMPT ===== ALL PACKAGES CREATED SUCCESSFULLY =====
PROMPT