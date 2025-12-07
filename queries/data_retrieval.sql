-- =====================================================
-- File: data_retrieval.sql
-- Purpose: Common SELECT queries to retrieve data from the
-- digital ID schema (citizens, digital_ids, consents, requests,
-- access logs, alerts, violations, etc.).
-- Usage: Replace the bind variables (e.g. :national_id) with
-- actual values or use from your client (SQL*Plus, SQL Developer).
-- =====================================================

-- 1) Retrieve a citizen by national ID
SELECT citizen_id,
			 national_id,
			 first_name || ' ' || last_name AS full_name,
			 date_of_birth,
			 email,
			 phone_number,
			 address,
			 registration_date,
			 status
FROM citizens
WHERE national_id = :national_id;

-- 2) Active digital IDs for a given citizen
SELECT d.digital_id,
			 d.id_number,
			 d.id_type,
			 d.issue_date,
			 d.expiry_date,
			 d.security_level,
			 d.is_active
FROM digital_ids d
WHERE d.citizen_id = :citizen_id
	AND d.is_active = 'Y';

-- 3) Latest consent records for a citizen (by category)
SELECT c.consent_id,
			 c.data_category_id,
			 dc.category_name,
			 c.consent_status,
			 c.consent_level,
			 c.granted_date,
			 c.expiry_date
FROM consent_records c
JOIN data_categories dc ON c.data_category_id = dc.category_id
WHERE c.citizen_id = :citizen_id
ORDER BY c.granted_date DESC;

-- 4) Pending access requests (optionally filter by entity)
SELECT r.request_id,
			 r.entity_id,
			 ae.entity_name,
			 r.digital_id,
			 r.request_date,
			 r.purpose,
			 r.data_category,
			 r.request_status
FROM access_requests r
LEFT JOIN authorized_entities ae ON r.entity_id = ae.entity_id
WHERE r.request_status = 'PENDING'
	/* AND r.entity_id = :entity_id */
ORDER BY r.request_date DESC;

-- 5) Access logs for a specific request (audit trail)
SELECT l.log_id,
			 l.action_type,
			 l.action_timestamp,
			 l.action_by,
			 l.action_result,
			 l.denial_reason,
			 l.ip_address
FROM access_logs l
WHERE l.request_id = :request_id
ORDER BY l.action_timestamp;

-- 6) Entities with highest authorization level
SELECT entity_id,
			 entity_name,
			 entity_type,
			 authorization_level,
			 status
FROM authorized_entities
WHERE authorization_level = 3
	AND status = 'ACTIVE'
ORDER BY entity_name;

-- 7) Recent alerts (last N days)
SELECT alert_id,
			 citizen_id,
			 request_id,
			 alert_type,
			 severity,
			 alert_message,
			 alert_date,
			 status
FROM alerts
WHERE alert_date >= TRUNC(SYSDATE) - NVL(:days_back, 30)
ORDER BY alert_date DESC;

-- 8) Violations summary (counts by type)
SELECT violation_type,
			 COUNT(*) AS violation_count,
			 SUM(NVL(penalty_amount,0)) AS total_penalties
FROM violations
GROUP BY violation_type
ORDER BY violation_count DESC;

-- 9) Top requesting entities (by number of requests)
SELECT ae.entity_id,
			 ae.entity_name,
			 COUNT(r.request_id) AS requests_count
FROM authorized_entities ae
JOIN access_requests r ON ae.entity_id = r.entity_id
GROUP BY ae.entity_id, ae.entity_name
ORDER BY requests_count DESC;

-- 10) System-wide counts and quick stats
SELECT (SELECT COUNT(*) FROM citizens)                AS total_citizens,
			 (SELECT COUNT(*) FROM digital_ids WHERE is_active='Y') AS active_digital_ids,
			 (SELECT COUNT(*) FROM access_requests WHERE request_status='PENDING') AS pending_requests,
			 (SELECT COUNT(*) FROM consent_records WHERE consent_status='GRANTED') AS granted_consents
FROM dual;

-- 11) High-risk recent requests (risk_score > threshold)
SELECT r.request_id,
			 r.entity_id,
			 ae.entity_name,
			 r.digital_id,
			 r.request_date,
			 r.purpose,
			 r.risk_score
FROM access_requests r
LEFT JOIN authorized_entities ae ON r.entity_id = ae.entity_id
WHERE r.risk_score > NVL(:risk_threshold, 0.7)
	AND r.request_date >= SYSDATE - NVL(:days_back, 30)
ORDER BY r.risk_score DESC, r.request_date DESC;

-- 12) Example: join to show which citizen an access log refers to
SELECT l.log_id,
			 l.action_timestamp,
			 l.action_by,
			 l.action_result,
			 r.request_id,
			 r.digital_id,
			 d.citizen_id,
			 c.first_name || ' ' || c.last_name AS citizen_name,
			 r.purpose
FROM access_logs l
LEFT JOIN access_requests r ON l.request_id = r.request_id
LEFT JOIN digital_ids d ON r.digital_id = d.digital_id
LEFT JOIN citizens c ON d.citizen_id = c.citizen_id
WHERE l.action_timestamp >= SYSDATE - NVL(:days_back, 7)
ORDER BY l.action_timestamp DESC;

-- End of file

