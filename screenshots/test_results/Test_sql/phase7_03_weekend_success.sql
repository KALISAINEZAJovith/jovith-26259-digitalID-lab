-- Check it's a weekend
SELECT TO_CHAR(SYSDATE, 'Day, DD-MON-YYYY') AS today FROM dual;

-- This should SUCCEED
INSERT INTO citizens (
    citizen_id, national_id, first_name, last_name, 
    date_of_birth, email, phone_number, status
) VALUES (
    9998, '9998999999999998', 'Weekend', 'Test',
    DATE '1992-06-15', 'weekend.test@test.rw', '+250788999999', 'ACTIVE'
);

-- Verify insertion
SELECT * FROM citizens WHERE citizen_id = 9998;

-- Clean up
DELETE FROM citizens WHERE citizen_id = 9998;
COMMIT;