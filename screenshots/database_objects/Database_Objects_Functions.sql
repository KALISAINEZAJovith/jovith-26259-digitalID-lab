SELECT object_name, status, created
FROM user_objects
WHERE object_type = 'FUNCTION'
ORDER BY object_name;