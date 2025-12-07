-- =====================================================
-- File: analytics_queries.sql
-- Purpose: Analytical queries and KPIs for the Digital ID system.
-- Includes monthly trends, consent metrics, request/approval KPIs,
-- entity rankings, alert & violation summaries suitable for dashboards.
-- Usage: Provide bind variables where shown (e.g. :months_back).
-- Oracle-specific functions (TRUNC, TO_CHAR, NUMTODSINTERVAL) are used.
-- =====================================================

-- 1) Monthly new citizen registrations (last N months)
SELECT TO_CHAR(TRUNC(registration_date,'MM'),'YYYY-MM') AS month,
			 COUNT(*) AS new_citizens
FROM citizens
WHERE registration_date >= ADD_MONTHS(TRUNC(SYSDATE,'MM'), -NVL(:months_back,12))
GROUP BY TRUNC(registration_date,'MM')
ORDER BY TRUNC(registration_date,'MM');

-- 2) Monthly digital ID issuances and active IDs trend
SELECT TO_CHAR(TRUNC(issue_date,'MM'),'YYYY-MM') AS month,
	   SUM(CASE WHEN issue_date IS NOT NULL THEN 1 ELSE 0 END) AS issued_ids,
	   SUM(CASE WHEN is_active='Y' THEN 1 ELSE 0 END) AS active_ids
FROM digital_ids
WHERE issue_date >= ADD_MONTHS(TRUNC(SYSDATE,'MM'), -NVL(:months_back,12))
GROUP BY TRUNC(issue_date,'MM')
ORDER BY TRUNC(issue_date,'MM');

-- 3) Percentage of citizens with at least one active digital ID
SELECT COUNT(DISTINCT d.citizen_id) AS citizens_with_active_id,
			 (COUNT(DISTINCT d.citizen_id) / NULLIF((SELECT COUNT(*) FROM citizens),0)) * 100 AS pct_citizens_with_active_id
FROM digital_ids d
WHERE d.is_active='Y';

-- 4) Consent grant vs revoke trend by category (last N months)
SELECT TO_CHAR(TRUNC(NVL(c.granted_date, c.revoked_date),'MM'),'YYYY-MM') AS month,
			 dc.category_name,
			 SUM(CASE WHEN c.consent_status='GRANTED' THEN 1 ELSE 0 END) AS grants,
			 SUM(CASE WHEN c.consent_status='REVOKED' THEN 1 ELSE 0 END) AS revocations
FROM consent_records c
LEFT JOIN data_categories dc ON c.data_category_id = dc.category_id
WHERE NVL(c.granted_date, c.revoked_date) >= ADD_MONTHS(TRUNC(SYSDATE,'MM'), -NVL(:months_back,6))
GROUP BY TRUNC(NVL(c.granted_date, c.revoked_date),'MM'), dc.category_name
ORDER BY TRUNC(NVL(c.granted_date, c.revoked_date),'MM'), dc.category_name;

-- 5) Request volume and approval rate per month
SELECT TO_CHAR(TRUNC(request_date,'MM'),'YYYY-MM') AS month,
			 COUNT(*) AS total_requests,
			 SUM(CASE WHEN request_status='APPROVED' THEN 1 ELSE 0 END) AS approved_requests,
			 ROUND(100 * SUM(CASE WHEN request_status='APPROVED' THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0),2) AS approval_rate_pct
FROM access_requests
WHERE request_date >= ADD_MONTHS(TRUNC(SYSDATE,'MM'), -NVL(:months_back,12))
GROUP BY TRUNC(request_date,'MM')
ORDER BY TRUNC(request_date,'MM');

-- 6) Average and median approval time (minutes) overall and by entity
-- Average approval minutes
SELECT 'OVERALL' AS scope,
			 AVG((CAST(approval_date AS DATE) - CAST(request_date AS DATE)) * 24 * 60) AS avg_approval_minutes
FROM access_requests
WHERE request_status='APPROVED'
	AND approval_date IS NOT NULL
	AND request_date >= SYSDATE - NVL(:days_back,90);

-- Average approval minutes by entity (top 20 slowest)
SELECT ae.entity_id,
			 ae.entity_name,
			 COUNT(r.request_id) AS approved_count,
			 AVG((CAST(r.approval_date AS DATE) - CAST(r.request_date AS DATE)) * 24 * 60) AS avg_approval_minutes
FROM access_requests r
LEFT JOIN authorized_entities ae ON r.entity_id = ae.entity_id
WHERE r.request_status='APPROVED'
	AND r.approval_date IS NOT NULL
	AND r.request_date >= SYSDATE - NVL(:days_back,90)
GROUP BY ae.entity_id, ae.entity_name
HAVING COUNT(r.request_id) > 5
ORDER BY avg_approval_minutes DESC NULLS LAST
FETCH FIRST 20 ROWS ONLY;

-- 7) Top requested data categories (by requests count)
SELECT data_category,
			 COUNT(*) AS requests_count
FROM access_requests
GROUP BY data_category
ORDER BY requests_count DESC
FETCH FIRST 20 ROWS ONLY;

-- 8) Entity ranking by request volume and approval rate
SELECT ae.entity_id,
			 ae.entity_name,
			 COUNT(r.request_id) AS total_requests,
			 SUM(CASE WHEN r.request_status='APPROVED' THEN 1 ELSE 0 END) AS approved_requests,
			 ROUND(100 * SUM(CASE WHEN r.request_status='APPROVED' THEN 1 ELSE 0 END) / NULLIF(COUNT(r.request_id),0),2) AS approval_rate_pct
FROM authorized_entities ae
LEFT JOIN access_requests r ON ae.entity_id = r.entity_id
GROUP BY ae.entity_id, ae.entity_name
ORDER BY total_requests DESC
FETCH FIRST 50 ROWS ONLY;

-- 9) Alerts by severity over time (last N months)
SELECT TO_CHAR(TRUNC(alert_date,'MM'),'YYYY-MM') AS month,
			 severity,
			 COUNT(*) AS alerts_count
FROM alerts
WHERE alert_date >= ADD_MONTHS(TRUNC(SYSDATE,'MM'), -NVL(:months_back,12))
GROUP BY TRUNC(alert_date,'MM'), severity
ORDER BY TRUNC(alert_date,'MM') DESC, severity;

-- 10) Violations by type and monthly penalties (last N months)
SELECT TO_CHAR(TRUNC(violation_date,'MM'),'YYYY-MM') AS month,
			 violation_type,
			 COUNT(*) AS violations_count,
			 SUM(NVL(penalty_amount,0)) AS total_penalties
FROM violations
WHERE violation_date >= ADD_MONTHS(TRUNC(SYSDATE,'MM'), -NVL(:months_back,12))
GROUP BY TRUNC(violation_date,'MM'), violation_type
ORDER BY TRUNC(violation_date,'MM') DESC, violations_count DESC;

-- 11) Daily request volume and 7-day moving average (last N days)
WITH daily AS (
	SELECT TRUNC(request_date) AS day,
				 COUNT(*) AS requests
	FROM access_requests
	WHERE request_date >= TRUNC(SYSDATE) - NVL(:days_back,30)
	GROUP BY TRUNC(request_date)
)
SELECT d.day,
			 d.requests,
			 ROUND(AVG(d.requests) OVER (ORDER BY d.day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW),2) AS ma_7
FROM daily d
ORDER BY d.day;

-- 12) Percentage of requests that are high-risk by entity
SELECT ae.entity_id,
			 ae.entity_name,
			 COUNT(r.request_id) AS total_requests,
			 SUM(CASE WHEN NVL(r.risk_score,0) > NVL(:risk_threshold,0.7) THEN 1 ELSE 0 END) AS high_risk_count,
			 ROUND(100 * SUM(CASE WHEN NVL(r.risk_score,0) > NVL(:risk_threshold,0.7) THEN 1 ELSE 0 END) / NULLIF(COUNT(r.request_id),0),2) AS high_risk_pct
FROM access_requests r
LEFT JOIN authorized_entities ae ON r.entity_id = ae.entity_id
WHERE r.request_date >= SYSDATE - NVL(:days_back,90)
GROUP BY ae.entity_id, ae.entity_name
ORDER BY high_risk_pct DESC NULLS LAST
FETCH FIRST 50 ROWS ONLY;

-- 13) Cohort-like measure: how many citizens receive a digital ID within X months of registration
SELECT cohort_month,
			 COUNT(*) AS total_registered,
			 SUM(CASE WHEN months_to_first_id <= NVL(:months_threshold,3) THEN 1 ELSE 0 END) AS got_id_within_threshold,
			 ROUND(100 * SUM(CASE WHEN months_to_first_id <= NVL(:months_threshold,3) THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0),2) AS pct_got_id
FROM (
	SELECT c.citizen_id,
				 TO_CHAR(TRUNC(c.registration_date,'MM'),'YYYY-MM') AS cohort_month,
				 MIN(MONTHS_BETWEEN(d.issue_date, c.registration_date)) AS months_to_first_id
	FROM citizens c
	LEFT JOIN digital_ids d ON c.citizen_id = d.citizen_id
	GROUP BY c.citizen_id, TRUNC(c.registration_date,'MM')
) t
GROUP BY cohort_month
ORDER BY cohort_month DESC;

-- 14) Quick KPI single-row snapshot
SELECT (SELECT COUNT(*) FROM citizens)                                         AS total_citizens,
			 (SELECT COUNT(*) FROM digital_ids WHERE is_active='Y')                  AS active_digital_ids,
			 (SELECT COUNT(*) FROM access_requests WHERE request_status='PENDING')    AS pending_requests,
			 (SELECT ROUND(100 * SUM(CASE WHEN request_status='APPROVED' THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0),2)
					 FROM access_requests
					 WHERE request_date >= TRUNC(SYSDATE) - 30)                           AS approval_rate_last_30d,
			 (SELECT COUNT(*) FROM alerts WHERE alert_date >= TRUNC(SYSDATE) - 30)   AS alerts_last_30d;

-- End of file

