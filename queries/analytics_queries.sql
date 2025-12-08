-- =====================================================
-- QUERY 1: EXECUTIVE KPI SUMMARY
-- Purpose: Top-level metrics for executive dashboard
-- =====================================================
SELECT 
    (SELECT COUNT(*) FROM citizens WHERE status = 'ACTIVE') AS active_citizens,
    (SELECT COUNT(*) FROM access_requests WHERE TRUNC(request_date) = TRUNC(SYSDATE)) AS requests_today,
    (SELECT COUNT(*) FROM access_requests WHERE request_status = 'PENDING') AS pending_requests,
    (SELECT COUNT(*) FROM violations WHERE status = 'INVESTIGATING') AS active_violations,
    (SELECT ROUND(AVG(risk_score), 3) FROM access_requests WHERE request_date >= SYSDATE - 7) AS avg_risk_7days,
    (SELECT COUNT(*) FROM alerts WHERE status = 'NEW' AND severity IN ('HIGH','CRITICAL')) AS critical_alerts
FROM dual;

-- =====================================================
-- QUERY 2: DAILY REQUEST TRENDS (LAST 30 DAYS)
-- Purpose: Volume analysis for trend charts
-- =====================================================
SELECT 
    TRUNC(request_date) AS request_day,
    COUNT(*) AS total_requests,
    SUM(CASE WHEN request_status = 'APPROVED' THEN 1 ELSE 0 END) AS approved,
    SUM(CASE WHEN request_status = 'DENIED' THEN 1 ELSE 0 END) AS denied,
    SUM(CASE WHEN request_status = 'PENDING' THEN 1 ELSE 0 END) AS pending,
    ROUND(AVG(risk_score), 3) AS avg_risk_score,
    MAX(risk_score) AS max_risk_score
FROM access_requests
WHERE request_date >= SYSDATE - 30
GROUP BY TRUNC(request_date)
ORDER BY request_day DESC;

-- =====================================================
-- QUERY 3: RISK DISTRIBUTION ANALYSIS
-- Purpose: Risk categorization for pie charts
-- =====================================================
SELECT 
    CASE 
        WHEN risk_score >= 0.7 THEN 'HIGH RISK'
        WHEN risk_score >= 0.4 THEN 'MODERATE RISK'
        ELSE 'LOW RISK'
    END AS risk_category,
    COUNT(*) AS request_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage,
    ROUND(AVG(risk_score), 3) AS avg_risk_in_category
FROM access_requests
WHERE request_date >= SYSDATE - 30
GROUP BY 
    CASE 
        WHEN risk_score >= 0.7 THEN 'HIGH RISK'
        WHEN risk_score >= 0.4 THEN 'MODERATE RISK'
        ELSE 'LOW RISK'
    END
ORDER BY 
    CASE 
        WHEN risk_score >= 0.7 THEN 1
        WHEN risk_score >= 0.4 THEN 2
        ELSE 3
    END;

-- =====================================================
-- QUERY 4: TOP 10 ENTITIES BY REQUEST VOLUME
-- Purpose: Entity performance ranking
-- =====================================================
SELECT 
    ae.entity_id,
    ae.entity_name,
    ae.entity_type,
    COUNT(ar.request_id) AS total_requests,
    SUM(CASE WHEN ar.request_status = 'APPROVED' THEN 1 ELSE 0 END) AS approved_count,
    SUM(CASE WHEN ar.request_status = 'DENIED' THEN 1 ELSE 0 END) AS denied_count,
    ROUND(AVG(ar.risk_score), 3) AS avg_risk_score,
    ROUND(SUM(CASE WHEN ar.request_status = 'APPROVED' THEN 1 ELSE 0 END) * 100.0 / 
          COUNT(ar.request_id), 2) AS approval_rate
FROM authorized_entities ae
JOIN access_requests ar ON ae.entity_id = ar.entity_id
WHERE ar.request_date >= SYSDATE - 30
GROUP BY ae.entity_id, ae.entity_name, ae.entity_type
ORDER BY total_requests DESC
FETCH FIRST 10 ROWS ONLY;

-- =====================================================
-- QUERY 5: HIGH-RISK REQUESTS REQUIRING REVIEW
-- Purpose: Security dashboard - immediate action items
-- =====================================================
SELECT 
    ar.request_id,
    ae.entity_name,
    ae.entity_type,
    c.first_name || ' ' || c.last_name AS citizen_name,
    ar.data_category,
    ar.purpose,
    ROUND(ar.risk_score, 3) AS risk_score,
    ar.request_date,
    CASE 
        WHEN ar.risk_score >= 0.9 THEN 'CRITICAL'
        WHEN ar.risk_score >= 0.7 THEN 'HIGH'
        ELSE 'MODERATE'
    END AS risk_level
FROM access_requests ar
JOIN authorized_entities ae ON ar.entity_id = ae.entity_id
JOIN digital_ids di ON ar.digital_id = di.digital_id
JOIN citizens c ON di.citizen_id = c.citizen_id
WHERE ar.request_status = 'PENDING'
  AND ar.risk_score >= 0.7
ORDER BY ar.risk_score DESC, ar.request_date;

-- =====================================================
-- QUERY 6: CONSENT COVERAGE ANALYSIS
-- Purpose: Compliance monitoring - consent status
-- =====================================================
WITH citizen_consent_summary AS (
    SELECT 
        c.citizen_id,
        COUNT(DISTINCT cr.consent_id) AS total_consents,
        SUM(CASE WHEN cr.consent_status = 'GRANTED' THEN 1 ELSE 0 END) AS granted_consents,
        SUM(CASE WHEN cr.consent_status = 'REVOKED' THEN 1 ELSE 0 END) AS revoked_consents,
        SUM(CASE WHEN cr.consent_status = 'EXPIRED' THEN 1 ELSE 0 END) AS expired_consents
    FROM citizens c
    LEFT JOIN consent_records cr ON c.citizen_id = cr.citizen_id
    WHERE c.status = 'ACTIVE'
    GROUP BY c.citizen_id
)
SELECT 
    COUNT(*) AS total_active_citizens,
    SUM(CASE WHEN total_consents > 0 THEN 1 ELSE 0 END) AS citizens_with_consents,
    ROUND(SUM(CASE WHEN total_consents > 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS consent_coverage_pct,
    ROUND(AVG(granted_consents), 2) AS avg_granted_per_citizen,
    SUM(granted_consents) AS total_granted_consents,
    SUM(revoked_consents) AS total_revoked_consents,
    SUM(expired_consents) AS total_expired_consents
FROM citizen_consent_summary;

-- =====================================================
-- QUERY 7: VIOLATION TRENDS BY TYPE
-- Purpose: Compliance dashboard - violation analysis
-- =====================================================
SELECT 
    TRUNC(violation_date, 'MM') AS violation_month,
    violation_type,
    COUNT(*) AS violation_count,
    SUM(penalty_amount) AS total_penalties,
    ROUND(AVG(penalty_amount), 2) AS avg_penalty,
    COUNT(DISTINCT entity_id) AS unique_violators
FROM violations
WHERE violation_date >= ADD_MONTHS(SYSDATE, -12)
GROUP BY TRUNC(violation_date, 'MM'), violation_type
ORDER BY violation_month DESC, violation_count DESC;

-- =====================================================
-- QUERY 8: ENTITY AUTHORIZATION EXPIRY TRACKING
-- Purpose: Compliance dashboard - proactive monitoring
-- =====================================================
SELECT 
    entity_id,
    entity_name,
    entity_type,
    authorization_level,
    expiry_date,
    expiry_date - SYSDATE AS days_until_expiry,
    CASE 
        WHEN expiry_date - SYSDATE < 0 THEN 'EXPIRED'
        WHEN expiry_date - SYSDATE <= 7 THEN 'URGENT'
        WHEN expiry_date - SYSDATE <= 30 THEN 'WARNING'
        ELSE 'OK'
    END AS expiry_status,
    contact_person,
    contact_email
FROM authorized_entities
WHERE status = 'ACTIVE'
  AND expiry_date IS NOT NULL
ORDER BY days_until_expiry;

-- =====================================================
-- QUERY 9: DATA CATEGORY ACCESS FREQUENCY HEATMAP
-- Purpose: Identify over-accessed data categories
-- =====================================================
SELECT 
    ae.entity_type,
    ar.data_category,
    COUNT(*) AS access_count,
    ROUND(AVG(ar.risk_score), 3) AS avg_risk,
    SUM(CASE WHEN ar.request_status = 'DENIED' THEN 1 ELSE 0 END) AS denied_count
FROM access_requests ar
JOIN authorized_entities ae ON ar.entity_id = ae.entity_id
WHERE ar.request_date >= SYSDATE - 30
GROUP BY ae.entity_type, ar.data_category
ORDER BY ae.entity_type, access_count DESC;

-- =====================================================
-- QUERY 10: HOURLY ACCESS PATTERN ANALYSIS
-- Purpose: Capacity planning - identify peak hours
-- =====================================================
SELECT 
    EXTRACT(HOUR FROM request_date) AS hour_of_day,
    COUNT(*) AS total_requests,
    ROUND(AVG(risk_score), 3) AS avg_risk_score,
    SUM(CASE WHEN request_status = 'DENIED' THEN 1 ELSE 0 END) AS denied_requests,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_total
FROM access_requests
WHERE request_date >= SYSDATE - 7
GROUP BY EXTRACT(HOUR FROM request_date)
ORDER BY hour_of_day;

-- =====================================================
-- QUERY 11: CITIZEN ACCESS HISTORY DETAILED VIEW
-- Purpose: Transparency report for individual citizen
-- =====================================================
CREATE OR REPLACE VIEW v_citizen_access_history AS
SELECT 
    c.citizen_id,
    c.first_name || ' ' || c.last_name AS citizen_name,
    c.national_id,
    ae.entity_name,
    ae.entity_type,
    ar.data_category,
    ar.purpose,
    ar.request_status,
    ar.risk_score,
    ar.request_date,
    ar.approval_date,
    ar.approved_by,
    al.action_result,
    al.denial_reason,
    CASE 
        WHEN ar.request_status = 'DENIED' THEN 'ACCESS DENIED'
        WHEN ar.request_status = 'APPROVED' THEN 'ACCESS GRANTED'
        ELSE 'PENDING REVIEW'
    END AS access_outcome
FROM citizens c
JOIN digital_ids di ON c.citizen_id = di.citizen_id
JOIN access_requests ar ON di.digital_id = ar.digital_id
JOIN authorized_entities ae ON ar.entity_id = ae.entity_id
LEFT JOIN access_logs al ON ar.request_id = al.request_id
ORDER BY ar.request_date DESC;

-- =====================================================
-- QUERY 12: MONTHLY COMPLIANCE SCORECARD
-- Purpose: Executive report - overall health metrics
-- =====================================================
WITH monthly_metrics AS (
    SELECT 
        TO_CHAR(SYSDATE, 'YYYY-MM') AS report_month,
        (SELECT COUNT(*) FROM citizens WHERE status = 'ACTIVE') AS active_citizens,
        (SELECT COUNT(*) FROM access_requests 
         WHERE TRUNC(request_date, 'MM') = TRUNC(SYSDATE, 'MM')) AS total_requests,
        (SELECT COUNT(*) FROM access_requests 
         WHERE TRUNC(request_date, 'MM') = TRUNC(SYSDATE, 'MM') 
         AND request_status = 'APPROVED') AS approved_requests,
        (SELECT COUNT(*) FROM violations 
         WHERE TRUNC(violation_date, 'MM') = TRUNC(SYSDATE, 'MM')) AS total_violations,
        (SELECT COUNT(*) FROM consent_records 
         WHERE consent_status = 'GRANTED') AS active_consents,
        (SELECT COUNT(*) FROM alerts 
         WHERE TRUNC(alert_date, 'MM') = TRUNC(SYSDATE, 'MM') 
         AND severity IN ('HIGH','CRITICAL')) AS critical_alerts
    FROM dual
)
SELECT 
    report_month,
    active_citizens,
    total_requests,
    approved_requests,
    ROUND(approved_requests * 100.0 / NULLIF(total_requests, 0), 2) AS approval_rate,
    total_violations,
    active_consents,
    ROUND(active_consents * 100.0 / NULLIF(active_citizens, 0), 2) AS consent_coverage,
    critical_alerts,
    CASE 
        WHEN total_violations = 0 AND approval_rate > 70 AND consent_coverage > 80 THEN 'EXCELLENT'
        WHEN total_violations <= 2 AND approval_rate > 60 AND consent_coverage > 70 THEN 'GOOD'
        WHEN total_violations <= 5 THEN 'NEEDS IMPROVEMENT'
        ELSE 'CRITICAL'
    END AS overall_health_status
FROM monthly_metrics;

-- =====================================================
-- QUERY 13: ENTITY RISK MATRIX (SCATTER PLOT DATA)
-- Purpose: Identify problematic entities
-- =====================================================
SELECT 
    ae.entity_id,
    ae.entity_name,
    ae.entity_type,
    COUNT(ar.request_id) AS total_requests,
    ROUND(AVG(ar.risk_score), 3) AS avg_risk_score,
    COUNT(v.violation_id) AS violation_count,
    SUM(CASE WHEN ar.request_status = 'DENIED' THEN 1 ELSE 0 END) AS denied_count,
    CASE 
        WHEN COUNT(ar.request_id) > 100 AND AVG(ar.risk_score) > 0.5 THEN 'HIGH RISK - HIGH VOLUME'
        WHEN COUNT(ar.request_id) > 100 THEN 'HIGH VOLUME - LOW RISK'
        WHEN AVG(ar.risk_score) > 0.5 THEN 'LOW VOLUME - HIGH RISK'
        ELSE 'LOW RISK - LOW VOLUME'
    END AS risk_category
FROM authorized_entities ae
JOIN access_requests ar ON ae.entity_id = ar.entity_id
LEFT JOIN violations v ON ae.entity_id = v.entity_id
WHERE ar.request_date >= SYSDATE - 90
GROUP BY ae.entity_id, ae.entity_name, ae.entity_type
HAVING COUNT(ar.request_id) > 10
ORDER BY avg_risk_score DESC, total_requests DESC;

-- =====================================================
-- QUERY 14: ALERT RESPONSE TIME ANALYSIS
-- Purpose: Measure DPO efficiency
-- =====================================================
SELECT 
    alert_type,
    severity,
    COUNT(*) AS total_alerts,
    SUM(CASE WHEN status IN ('RESOLVED','FALSE_POSITIVE') THEN 1 ELSE 0 END) AS resolved_alerts,
    ROUND(AVG(CASE 
        WHEN reviewed_date IS NOT NULL 
        THEN (reviewed_date - alert_date) * 24 
        ELSE NULL 
    END), 2) AS avg_response_hours,
    MIN(CASE 
        WHEN reviewed_date IS NOT NULL 
        THEN (reviewed_date - alert_date) * 24 
        ELSE NULL 
    END) AS min_response_hours,
    MAX(CASE 
        WHEN reviewed_date IS NOT NULL 
        THEN (reviewed_date - alert_date) * 24 
        ELSE NULL 
    END) AS max_response_hours
FROM alerts
WHERE alert_date >= SYSDATE - 30
GROUP BY alert_type, severity
ORDER BY severity DESC, avg_response_hours DESC;

-- =====================================================
-- QUERY 15: PREDICTIVE - CONSENT EXPIRY FORECAST
-- Purpose: Proactive consent renewal notifications
-- =====================================================
SELECT 
    TRUNC(expiry_date, 'MM') AS expiry_month,
    COUNT(*) AS consents_expiring,
    COUNT(DISTINCT citizen_id) AS affected_citizens,
    LISTAGG(DISTINCT data_category_id, ', ') WITHIN GROUP (ORDER BY data_category_id) AS categories
FROM consent_records
WHERE consent_status = 'GRANTED'
  AND expiry_date BETWEEN SYSDATE AND SYSDATE + 90
GROUP BY TRUNC(expiry_date, 'MM')
ORDER BY expiry_month;

-- =====================================================
-- MATERIALIZED VIEW: DAILY AGGREGATES FOR PERFORMANCE
-- Purpose: Pre-calculated metrics for dashboard speed
-- =====================================================
CREATE MATERIALIZED VIEW mv_daily_access_metrics
BUILD IMMEDIATE
REFRESH COMPLETE ON DEMAND
AS
SELECT 
    TRUNC(request_date) AS request_day,
    entity_id,
    COUNT(*) AS total_requests,
    SUM(CASE WHEN request_status = 'APPROVED' THEN 1 ELSE 0 END) AS approved,
    SUM(CASE WHEN request_status = 'DENIED' THEN 1 ELSE 0 END) AS denied,
    SUM(CASE WHEN request_status = 'PENDING' THEN 1 ELSE 0 END) AS pending,
    ROUND(AVG(risk_score), 3) AS avg_risk_score,
    MAX(risk_score) AS max_risk_score,
    MIN(risk_score) AS min_risk_score
FROM access_requests
GROUP BY TRUNC(request_date), entity_id;

-- Create index for fast queries
CREATE INDEX idx_mv_daily_access ON mv_daily_access_metrics(request_day, entity_id);

-- Refresh the materialized view (run daily via scheduler)
-- EXEC DBMS_MVIEW.REFRESH('MV_DAILY_ACCESS_METRICS', 'C');

PROMPT
PROMPT ===== ANALYTICS QUERIES COMPLETED =====
PROMPT Total Queries: 15 analytical queries + 1 materialized view
PROMPT Purpose: Executive dashboards, security monitoring, compliance reporting
PROMPT