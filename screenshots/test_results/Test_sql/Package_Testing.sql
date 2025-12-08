SET SERVEROUTPUT ON;

DECLARE
    v_count NUMBER;
    v_cursor SYS_REFCURSOR;
    v_request_id NUMBER;
    v_entity_name VARCHAR2(100);
    v_risk NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== TESTING PACKAGES ===');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Test pkg_citizen_mgmt
    DBMS_OUTPUT.PUT_LINE('1. PKG_CITIZEN_MGMT:');
    v_count := pkg_citizen_mgmt.count_active_citizens;
    DBMS_OUTPUT.PUT_LINE('   Active Citizens: ' || v_count);
    
    -- Test pkg_access_control
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('2. PKG_ACCESS_CONTROL:');
    v_cursor := pkg_access_control.get_pending_requests(5);
    DBMS_OUTPUT.PUT_LINE('   Pending requests cursor opened successfully');
    
    -- Fetch one row as example
    FETCH v_cursor INTO v_request_id, v_entity_name, v_risk;
    IF v_cursor%FOUND THEN
        DBMS_OUTPUT.PUT_LINE('   Sample: Request ' || v_request_id || 
                           ', Entity: ' || v_entity_name);
    END IF;
    CLOSE v_cursor;
    
    -- Test pkg_audit
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('3. PKG_AUDIT:');
    pkg_audit.generate_access_report(SYSDATE - 7, SYSDATE);
END;
/