SET SERVEROUTPUT ON;

BEGIN
    DBMS_OUTPUT.PUT_LINE('=== DATE VALIDATION TESTS ===');
    DBMS_OUTPUT.PUT_LINE('Today: ' || TO_CHAR(SYSDATE, 'Day, DD-MON-YYYY'));
    
    IF is_weekday(SYSDATE) THEN
        DBMS_OUTPUT.PUT_LINE('Result: WEEKDAY (Mon-Fri) - DML RESTRICTED');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Result: WEEKEND (Sat-Sun) - DML ALLOWED');
    END IF;
    
    IF is_holiday(SYSDATE) THEN
        DBMS_OUTPUT.PUT_LINE('Result: PUBLIC HOLIDAY - DML RESTRICTED');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Result: Not a holiday');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Test Christmas 2025:');
    IF is_holiday(DATE '2025-12-25') THEN
        DBMS_OUTPUT.PUT_LINE('Result: Christmas correctly identified as HOLIDAY');
    END IF;
END;
/