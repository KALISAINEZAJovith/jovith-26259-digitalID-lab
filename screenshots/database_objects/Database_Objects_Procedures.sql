SELECT object_name, status, created
FROM user_objects
WHERE object_type = 'PROCEDURE'
ORDER BY object_name;