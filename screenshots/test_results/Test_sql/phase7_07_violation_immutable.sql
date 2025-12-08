-- Try to delete a violation (should FAIL)
DELETE FROM violations WHERE ROWNUM = 1;