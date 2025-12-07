SET SERVEROUTPUT ON;

DECLARE
    v_citizen_id NUMBER;
    v_digital_id NUMBER;
    v_status_msg VARCHAR2(500);
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== TESTING ADD_CITIZEN PROCEDURE ===');
    
    add_citizen(
        p_national_id    => '1199900099999999',
        p_first_name     => 'Test',
        p_last_name      => 'Student',
        p_date_of_birth  => DATE '2000-06-15',
        p_email          => 'test.student@screenshot.rw',
        p_phone_number   => '+250788999999',
        p_address        => 'KG 500 Ave, Kigali',
        p_id_type        => 'NATIONAL',
        p_citizen_id     => v_citizen_id,
        p_digital_id     => v_digital_id,
        p_status_message => v_status_msg
    );
    
    DBMS_OUTPUT.PUT_LINE('Status: ' || v_status_msg);
    DBMS_OUTPUT.PUT_LINE('New Citizen ID: ' || v_citizen_id);
    DBMS_OUTPUT.PUT_LINE('New Digital ID: ' || v_digital_id);
    
    -- Verify in database
    DECLARE
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_count
        FROM citizens
        WHERE citizen_id = v_citizen_id;
        
        DBMS_OUTPUT.PUT_LINE('Verification: Citizen record exists = ' || 
            CASE WHEN v_count = 1 THEN 'YES' ELSE 'NO' END);
    END;
END;
/