-- Try to UPDATE audit log (should FAIL)
UPDATE access_logs
SET action_result = 'TAMPERED'
WHERE ROWNUM = 1;