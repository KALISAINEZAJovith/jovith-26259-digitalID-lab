-- =====================================================
-- File: audit_queries.sql
-- Purpose: Audit and security-focused queries for monitoring
-- the digital ID system (access logs, denied attempts,
-- suspicious IPs, consent revocations, violations, approval latencies, etc.)
-- Usage: Replace bind variables (e.g. :days_back) with values
-- in your client (SQL*Plus, SQL Developer) or supply them
-- via prepared statements.
-- =====================================================

-- 1) Recent denied access attempts (last N days)
SELECT l.log_id,
			 l.request_id,
			 l.action_timestamp,
			 l.action_by,
			 l.ip_address,
			 l.action_type,
			 l.action_result,
			 l.denial_reason
FROM access_logs l
WHERE l.action_result = 'DENIED'
	AND l.action_timestamp >= SYSTIMESTAMP - NUMTODSINTERVAL(NVL(:days_back,7),'DAY')
ORDER BY l.action_timestamp DESC;

-- 2) Top offending IPs by denied attempts (last N days)
SELECT l.ip_address,
			 COUNT(*) AS denied_count
FROM access_logs l
WHERE l.action_result = 'DENIED'
	AND l.ip_address IS NOT NULL
	AND l.action_timestamp >= SYSTIMESTAMP - NUMTODSINTERVAL(NVL(:days_back,7),'DAY')
GROUP BY l.ip_address
ORDER BY denied_count DESC;

-- 3) Recent access requests denied by entity (with reasons)
SELECT r.request_id,
			 r.entity_id,
			 ae.entity_name,
			 r.digital_id,
			 r.request_date,
			 r.request_status,
			 r.purpose
FROM access_requests r
LEFT JOIN authorized_entities ae ON r.entity_id = ae.entity_id
WHERE r.request_status = 'DENIED'
	AND r.request_date >= SYSTIMESTAMP - NUMTODSINTERVAL(NVL(:days_back,30),'DAY')
ORDER BY r.request_date DESC;

-- 4) Consent revocations in the last N days
SELECT c.consent_id,
			 c.citizen_id,
			 dc.category_name,
			 c.consent_status,
			 c.revoked_date,
			 c.created_date
FROM consent_records c
LEFT JOIN data_categories dc ON c.data_category_id = dc.category_id
WHERE c.consent_status = 'REVOKED'
	AND c.revoked_date >= SYSTIMESTAMP - NUMTODSINTERVAL(NVL(:days_back,30),'DAY')
ORDER BY c.revoked_date DESC;

-- 5) Violations reported recently (last N days)
SELECT v.violation_id,
			 v.violation_type,
			 v.violation_date,
			 v.entity_id,
			 ae.entity_name,
			 v.description,
			 v.status,
			 v.penalty_amount
FROM violations v
LEFT JOIN authorized_entities ae ON v.entity_id = ae.entity_id
WHERE v.violation_date >= SYSTIMESTAMP - NUMTODSINTERVAL(NVL(:days_back,90),'DAY')
ORDER BY v.violation_date DESC;

-- 6) Average approval latency per entity (in minutes)
SELECT ae.entity_id,
			 ae.entity_name,
			 COUNT(r.request_id)                                        AS total_requests,
			 AVG((CAST(r.approval_date AS DATE) - CAST(r.request_date AS DATE))*24*60) AS avg_approval_minutes
FROM access_requests r
LEFT JOIN authorized_entities ae ON r.entity_id = ae.entity_id
WHERE r.request_status = 'APPROVED'
	AND r.approval_date IS NOT NULL
	AND r.request_date >= SYSTIMESTAMP - NUMTODSINTERVAL(NVL(:days_back,90),'DAY')
GROUP BY ae.entity_id, ae.entity_name
ORDER BY avg_approval_minutes DESC NULLS LAST;

-- 7) Long access windows (access duration greater than :threshold_minutes)
SELECT r.request_id,
			 r.entity_id,
			 ae.entity_name,
			 r.digital_id,
			 r.access_start_time,
			 r.access_end_time,
			 ((CAST(r.access_end_time AS DATE) - CAST(r.access_start_time AS DATE))*24*60) AS duration_minutes
FROM access_requests r
LEFT JOIN authorized_entities ae ON r.entity_id = ae.entity_id
WHERE r.access_start_time IS NOT NULL
	AND r.access_end_time IS NOT NULL
	AND ((CAST(r.access_end_time AS DATE) - CAST(r.access_start_time AS DATE))*24*60) > NVL(:threshold_minutes,60)
ORDER BY duration_minutes DESC;

-- 8) Audit trail for a specific citizen (logs, requests, consents)
-- Replace :citizen_id as needed
-- a) Access logs related to the citizen via digital_ids
SELECT l.log_id,
			 l.action_timestamp,
			 l.action_by,
			 l.action_type,
			 l.action_result,
			 l.ip_address,
			 r.request_id,
			 r.purpose
FROM access_logs l
LEFT JOIN access_requests r ON l.request_id = r.request_id
LEFT JOIN digital_ids d ON r.digital_id = d.digital_id
WHERE d.citizen_id = :citizen_id
	AND l.action_timestamp >= SYSTIMESTAMP - NUMTODSINTERVAL(NVL(:days_back,30),'DAY')
ORDER BY l.action_timestamp DESC;

-- b) Access requests for citizen's digital IDs
SELECT r.request_id,
			 r.entity_id,
			 ae.entity_name,
			 r.request_date,
			 r.request_status,
			 r.purpose
FROM access_requests r
LEFT JOIN digital_ids d ON r.digital_id = d.digital_id
LEFT JOIN authorized_entities ae ON r.entity_id = ae.entity_id
WHERE d.citizen_id = :citizen_id
ORDER BY r.request_date DESC;

-- c) Consent history for the citizen
SELECT c.consent_id,
			 dc.category_name,
			 c.consent_status,
			 c.consent_level,
			 c.granted_date,
			 c.revoked_date
FROM consent_records c
LEFT JOIN data_categories dc ON c.data_category_id = dc.category_id
WHERE c.citizen_id = :citizen_id
ORDER BY c.granted_date DESC;

-- 9) Suspicious modification attempts: MODIFY/DELETE actions by non-system users
SELECT l.log_id,
			 l.action_timestamp,
			 l.action_by,
			 l.action_type,
			 l.action_result,
			 l.data_accessed,
			 l.ip_address
FROM access_logs l
WHERE l.action_type IN ('MODIFY','DELETE')
	AND l.action_result = 'SUCCESS'
	AND LOWER(l.action_by) NOT LIKE 'sys%'
	AND l.action_timestamp >= SYSTIMESTAMP - NUMTODSINTERVAL(NVL(:days_back,30),'DAY')
ORDER BY l.action_timestamp DESC;

-- 10) System-level audit summary: logs totals and denied rate (last N days)
SELECT COUNT(*)                                                    AS total_logs,
			 SUM(CASE WHEN action_result='DENIED' THEN 1 ELSE 0 END)      AS denied_count,
			 ROUND(100 * SUM(CASE WHEN action_result='DENIED' THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0),2) AS denied_rate_percent
FROM access_logs l
WHERE l.action_timestamp >= SYSTIMESTAMP - NUMTODSINTERVAL(NVL(:days_back,7),'DAY');

-- 11) Recent changes to digital IDs (MODIFY actions referencing digital_id)
SELECT l.log_id,
			 l.action_timestamp,
			 l.action_by,
			 l.action_type,
			 l.action_result,
			 l.data_accessed
FROM access_logs l
WHERE l.action_type = 'MODIFY'
	AND l.data_accessed LIKE '%digital_id%'
	AND l.action_timestamp >= SYSTIMESTAMP - NUMTODSINTERVAL(NVL(:days_back,90),'DAY')
ORDER BY l.action_timestamp DESC;

-- End of file

