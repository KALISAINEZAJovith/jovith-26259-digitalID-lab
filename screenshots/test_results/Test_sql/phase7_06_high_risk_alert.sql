-- Check current alerts
SELECT COUNT(*) AS current_alerts FROM alerts;

-- Insert HIGH-RISK request
INSERT INTO access_requests (
    request_id, entity_id, digital_id, purpose, data_category,
    request_status, risk_score
) VALUES (
    seq_request_id.NEXTVAL,
    (SELECT entity_id FROM authorized_entities WHERE status = 'ACTIVE' AND ROWNUM = 1),
    (SELECT digital_id FROM digital_ids WHERE is_active = 'Y' AND ROWNUM = 1),
    'High-risk test request', 'BIOMETRIC_DATA',
    'PENDING', 0.95  -- HIGH RISK!
);

-- Check alerts again
SELECT COUNT(*) AS new_alerts FROM alerts;

-- View the alert
SELECT alert_id, alert_type, severity, alert_message
FROM alerts
WHERE alert_date >= SYSDATE - 1/1440
ORDER BY alert_date DESC;

ROLLBACK;