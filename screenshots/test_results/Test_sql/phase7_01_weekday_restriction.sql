-- Check today's day
SELECT TO_CHAR(SYSDATE, 'Day, DD-MON-YYYY') AS today FROM dual;

-- Attempt INSERT (should FAIL on Monday-Friday)
INSERT INTO citizens (
    citizen_id, national_id, first_name, last_name, 
    date_of_birth, email, phone_number, status
) VALUES (
    9999, '9999999999999999', 'Test', 'Weekday',
    DATE '1990-01-01', 'test.weekday@test.rw', '+250788000000', 'ACTIVE'
);