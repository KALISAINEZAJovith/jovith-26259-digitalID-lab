-- Count current logs
SELECT COUNT(*) AS current_logs FROM access_logs;

-- Insert access request
INSERT INTO access_requests (
    request_id, entity_id, digital_id, purpose, data_category,
    request_status, risk_score
) VALUES (
    seq_request_id.NEXTVAL,
    (SELECT entity_id FROM authorized_entities WHERE status = 'ACTIVE' AND ROWNUM = 1),
    (SELECT digital_id FROM digital_ids WHERE is_active = 'Y' AND ROWNUM = 1),
    'Test automatic audit logging', 'PERSONAL_INFO',
    'PENDING', 0.3
);

-- Count logs again
SELECT COUNT(*) AS new_logs FROM access_logs;

-- Should have increased by 1
ROLLBACK;