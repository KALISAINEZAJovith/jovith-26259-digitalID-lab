-- Try to create request with SUSPENDED entity
INSERT INTO access_requests (
    request_id, 
    entity_id, -- Use suspended entity
    digital_id, 
    purpose, 
    data_category,
    request_status, 
    risk_score
) VALUES (
    seq_request_id.NEXTVAL,
    (SELECT entity_id FROM authorized_entities WHERE status = 'SUSPENDED' AND ROWNUM = 1),
    (SELECT digital_id FROM digital_ids WHERE is_active = 'Y' AND ROWNUM = 1),
    'Test with suspended entity', 
    'PERSONAL_INFO',
    'PENDING', 
    0.3
);