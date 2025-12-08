-- Check if today is a holiday
BEGIN
    IF is_holiday(SYSDATE) THEN
        DBMS_OUTPUT.PUT_LINE('Today IS a holiday');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Today is NOT a holiday');
    END IF;
END;
/

-- If today is NOT a holiday, you can't test this live
-- But you can verify the function works:
BEGIN
    IF is_holiday(DATE '2025-12-25') THEN
        DBMS_OUTPUT.PUT_LINE('Christmas correctly identified as holiday');
    END IF;
END;
/