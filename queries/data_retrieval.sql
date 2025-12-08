-- =====================================================
-- DATA RETRIEVAL QUERIES
-- Project: Digital ID Data Privacy and Access Monitoring System
-- Student: KALISA INEZA JOVITH (26259)
-- File: queries/data_retrieval.sql
-- =====================================================

SET LINESIZE 200;
SET PAGESIZE 100;

-- =====================================================
-- QUERY 1: GET ALL ACTIVE CITIZENS
-- Purpose: List all citizens with active status
-- =====================================================
PROMPT === Query 1: All Active Citizens ===

SELECT 
    citizen_id,
    national_id,
    first_name || ' ' || last_name AS full_name,
    email,
    phone_number,
    TO_CHAR(date_of_birth, 'DD-MON-YYYY') AS date_of_birth,
    status,
    TO_CHAR(registration_date, 'DD-MON-YYYY') AS registration_date
FROM citizens
WHERE status = 'ACTIVE'
ORDER BY registration_date DESC;

-- =====================================================
-- QUERY 2: GET RECENT ACCESS REQUESTS (LAST 7 DAYS)
-- Purpose: Monitor recent system activity
-- =====================================================
PROMPT
PROMPT === Query 2: Recent Access Requests (Last 7 Days) ===

SELECT 
    ar.request_id,
    TO_CHAR(ar.request_date, 'DD-MON-YYYY HH24:MI') AS request_time,
    ae.entity_name,
    ae.entity_type,
    c.first_name || ' ' || c.last_name AS citizen_name,
    ar.data_category,
    ar.request_status,
    ROUND(ar.risk_score, 2) AS risk_score,
    CASE 
        WHEN ar.risk_score >= 0.7 THEN 'HIGH'
        WHEN ar.risk_score >= 0.4 THEN 'MODERATE'
        ELSE 'LOW'
    END AS risk_level
FROM access_requests ar
JOIN authorized_entities ae ON ar.entity_id = ae.entity_id
JOIN digital_ids di ON ar.digital_id = di.digital_id
JOIN citizens c ON di.citizen_id = c.citizen_id
WHERE ar.request_date >= SYSDATE - 7
ORDER BY ar.request_date DESC;

-- =====================================================
-- QUERY 3: GET CITIZEN BY NATIONAL ID
-- Purpose: Lookup specific citizen with digital ID info
-- =====================================================
PROMPT
PROMPT === Query 3: Get Citizen by National ID ===
PROMPT Enter National ID when prompted

SELECT 
    c.citizen_id,
    c.national_id,
    c.first_name || ' ' || c.last_name AS full_name,
    c.email,
    c.phone_number,
    c.address,
    TO_CHAR(c.date_of_birth, 'DD-MON-YYYY') AS date_of_birth,
    c.status AS citizen_status,
    d.digital_id,
    d.id_number AS digital_id_number,
    TO_CHAR(d.issue_date, 'DD-MON-YYYY') AS id_issue_date,
    TO_CHAR(d.expiry_date, 'DD-MON-YYYY') AS id_expiry_date,
    d.id_type,
    d.is_active AS digital_id_active
FROM citizens c
LEFT JOIN digital_ids d ON c.citizen_id = d.citizen_id
WHERE c.national_id = '&national_id';

-- =====================================================
-- QUERY 4: GET ACTIVE CONSENTS FOR CITIZEN
-- Purpose: Show all granted consents for a citizen
-- =====================================================
PROMPT
PROMPT === Query 4: Active Consents for Citizen ===
PROMPT Enter Citizen ID when prompted

SELECT 
    cr.consent_id,
    dc.category_name,
    dc.sensitivity_level,
    cr.entity_type,
    cr.consent_level,
    TO_CHAR(cr.granted_date, 'DD-MON-YYYY HH24:MI') AS granted_date,
    TO_CHAR(cr.expiry_date, 'DD-MON-YYYY') AS expiry_date,
    ROUND(cr.expiry_date - SYSDATE) AS days_until_expiry,
    CASE 
        WHEN cr.expiry_date < SYSDATE THEN '🔴 EXPIRED'
        WHEN cr.expiry_date < SYSDATE + 30 THEN '🟡 EXPIRING SOON'
        ELSE '🟢 ACTIVE'
    END AS status_indicator
FROM consent_records cr
JOIN data_categories dc ON cr.data_category_id = dc.category_id
WHERE cr.citizen_id = &citizen_id
  AND cr.consent_status = 'GRANTED'
ORDER BY cr.granted_date DESC;

-- =====================================================
-- QUERY 5: GET ALL AUTHORIZED ENTITIES
-- Purpose: List all active entities that can request data
-- =====================================================
PROMPT
PROMPT === Query 5: All Authorized Entities ===

SELECT 
    entity_id,
    entity_name,
    entity_type,
    license_number,
    contact_person,
    contact_email,
    authorization_level,
    TO_CHAR(approved_date, 'DD-MON-YYYY') AS approved_date,
    TO_CHAR(expiry_date, 'DD-MON-YYYY') AS expiry_date,
    ROUND(expiry_date - SYSDATE) AS days_until_expiry,
    status
FROM authorized_entities
WHERE status = 'ACTIVE'
ORDER BY entity_name;

-- =====================================================
-- QUERY 6: GET PENDING ACCESS REQUESTS
-- Purpose: Show requests waiting for approval
-- =====================================================
PROMPT
PROMPT === Query 6: Pending Access Requests ===

SELECT 
    ar.request_id,
    TO_CHAR(ar.request_date, 'DD-MON-YYYY HH24:MI') AS request_time,
    ae.entity_name,
    c.first_name || ' ' || c.last_name AS citizen_name,
    ar.purpose,
    ar.data_category,
    ROUND(ar.risk_score, 2) AS risk_score,
    ROUND((SYSDATE - ar.request_date) * 24, 1) AS hours_pending
FROM access_requests ar
JOIN authorized_entities ae ON ar.entity_id = ae.entity_id
JOIN digital_ids di ON ar.digital_id = di.digital_id
JOIN citizens c ON di.citizen_id = c.citizen_id
WHERE ar.request_status = 'PENDING'
ORDER BY ar.risk_score DESC, ar.request_date;

-- =====================================================
-- QUERY 7: GET ACCESS LOGS FOR SPECIFIC REQUEST
-- Purpose: View complete audit trail for a request
-- =====================================================
PROMPT
PROMPT === Query 7: Access Logs for Request ===
PROMPT Enter Request ID when prompted

SELECT 
    log_id,
    TO_CHAR(action_timestamp, 'DD-MON-YYYY HH24:MI:SS') AS action_time,
    action_type,
    action_by,
    action_result,
    denial_reason,
    ip_address,
    session_id
FROM access_logs
WHERE request_id = &request_id
ORDER BY action_timestamp;

-- =====================================================
-- QUERY 8: GET ALERTS FOR CITIZEN
-- Purpose: Show all security alerts for a citizen
-- =====================================================
PROMPT
PROMPT === Query 8: Alerts for Citizen ===
PROMPT Enter Citizen ID when prompted

SELECT 
    alert_id,
    TO_CHAR(alert_date, 'DD-MON-YYYY HH24:MI') AS alert_time,
    alert_type,
    severity,
    alert_message,
    status,
    reviewed_by,
    TO_CHAR(reviewed_date, 'DD-MON-YYYY HH24:MI') AS reviewed_time,
    CASE 
        WHEN status = 'NEW' THEN '🔴 NEW'
        WHEN status = 'REVIEWED' THEN '🟡 REVIEWED'
        WHEN status = 'RESOLVED' THEN '🟢 RESOLVED'
        ELSE '⚪ FALSE POSITIVE'
    END AS status_indicator
FROM alerts
WHERE citizen_id = &citizen_id
ORDER BY alert_date DESC;

-- =====================================================
-- QUERY 9: GET OPEN VIOLATIONS
-- Purpose: List all violations under investigation
-- =====================================================
PROMPT
PROMPT === Query 9: Open Violations ===

SELECT 
    v.violation_id,
    TO_CHAR(v.violation_date, 'DD-MON-YYYY') AS violation_date,
    v.violation_type,
    ae.entity_name,
    ae.entity_type,
    v.description,
    v.penalty_amount,
    v.status,
    v.reported_to_authority,
    CASE 
        WHEN v.status = 'INVESTIGATING' THEN '🔍 INVESTIGATING'
        WHEN v.status = 'CONFIRMED' THEN '⚠️ CONFIRMED'
        ELSE '✅ DISMISSED'
    END AS status_indicator
FROM violations v
JOIN authorized_entities ae ON v.entity_id = ae.entity_id
WHERE v.status = 'INVESTIGATING'
ORDER BY v.violation_date DESC;

-- =====================================================
-- QUERY 10: GET UPCOMING HOLIDAYS
-- Purpose: Show holidays for planning purposes
-- =====================================================
PROMPT
PROMPT === Query 10: Upcoming Holidays ===

SELECT 
    holiday_id,
    holiday_name,
    TO_CHAR(holiday_date, 'Day, DD-MON-YYYY') AS holiday_date,
    holiday_type,
    CASE 
        WHEN is_recurring = 'Y' THEN 'Annual'
        ELSE 'One-time'
    END AS recurrence,
    ROUND(holiday_date - SYSDATE) AS days_away
FROM holidays
WHERE holiday_date >= SYSDATE
ORDER BY holiday_date;

-- =====================================================
-- QUERY 11: GET DATA CATEGORIES
-- Purpose: List all data categories with sensitivity levels
-- =====================================================
PROMPT
PROMPT === Query 11: All Data Categories ===

SELECT 
    category_id,
    category_name,
    description,
    sensitivity_level,
    CASE 
        WHEN sensitivity_level = 5 THEN '🔴 HIGHLY SENSITIVE'
        WHEN sensitivity_level = 4 THEN '🟠 SENSITIVE'
        WHEN sensitivity_level = 3 THEN '🟡 MODERATE'
        WHEN sensitivity_level = 2 THEN '🟢 LOW'
        ELSE '⚪ MINIMAL'
    END AS sensitivity_indicator,
    requires_consent
FROM data_categories
ORDER BY sensitivity_level DESC, category_name;

-- =====================================================
-- QUERY 12: GET ENTITY ACCESS HISTORY (LAST 30 DAYS)
-- Purpose: View all access requests by specific entity
-- =====================================================
PROMPT
PROMPT === Query 12: Entity Access History ===
PROMPT Enter Entity ID when prompted

SELECT 
    ar.request_id,
    TO_CHAR(ar.request_date, 'DD-MON-YYYY HH24:MI') AS request_time,
    c.first_name || ' ' || c.last_name AS citizen_accessed,
    ar.data_category,
    ar.purpose,
    ar.request_status,
    ROUND(ar.risk_score, 2) AS risk_score,
    ar.approved_by,
    TO_CHAR(ar.approval_date, 'DD-MON-YYYY HH24:MI') AS approval_time
FROM access_requests ar
JOIN digital_ids di ON ar.digital_id = di.digital_id
JOIN citizens c ON di.citizen_id = c.citizen_id
WHERE ar.entity_id = &entity_id
  AND ar.request_date >= SYSDATE - 30
ORDER BY ar.request_date DESC;

-- =====================================================
-- QUERY 13: GET CONSENT SUMMARY BY CATEGORY
-- Purpose: Overview of consents grouped by data category
-- =====================================================
PROMPT
PROMPT === Query 13: Consent Summary by Category ===

SELECT 
    dc.category_name,
    COUNT(*) AS total_consents,
    SUM(CASE WHEN cr.consent_status = 'GRANTED' THEN 1 ELSE 0 END) AS granted,
    SUM(CASE WHEN cr.consent_status = 'REVOKED' THEN 1 ELSE 0 END) AS revoked,
    SUM(CASE WHEN cr.consent_status = 'EXPIRED' THEN 1 ELSE 0 END) AS expired,
    ROUND(SUM(CASE WHEN cr.consent_status = 'GRANTED' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS grant_rate
FROM consent_records cr
JOIN data_categories dc ON cr.data_category_id = dc.category_id
GROUP BY dc.category_name
ORDER BY total_consents DESC;

-- =====================================================
-- QUERY 14: GET ACCESS REQUEST STATISTICS BY STATUS
-- Purpose: Count of requests by status
-- =====================================================
PROMPT
PROMPT === Query 14: Access Request Statistics ===

SELECT 
    request_status,
    COUNT(*) AS request_count,
    ROUND(AVG(risk_score), 3) AS avg_risk_score,
    MIN(request_date) AS earliest_request,
    MAX(request_date) AS latest_request
FROM access_requests
GROUP BY request_status
ORDER BY request_count DESC;

-- =====================================================
-- QUERY 15: GET TOP 10 MOST ACCESSED CITIZENS
-- Purpose: Identify citizens with highest access frequency
-- =====================================================
PROMPT
PROMPT === Query 15: Top 10 Most Accessed Citizens ===

SELECT 
    c.citizen_id,
    c.first_name || ' ' || c.last_name AS citizen_name,
    c.national_id,
    COUNT(ar.request_id) AS total_access_requests,
    SUM(CASE WHEN ar.request_status = 'APPROVED' THEN 1 ELSE 0 END) AS approved_requests,
    SUM(CASE WHEN ar.request_status = 'DENIED' THEN 1 ELSE 0 END) AS denied_requests,
    ROUND(AVG(ar.risk_score), 3) AS avg_risk_score
FROM citizens c
JOIN digital_ids di ON c.citizen_id = di.citizen_id
JOIN access_requests ar ON di.digital_id = ar.digital_id
WHERE ar.request_date >= SYSDATE - 90
GROUP BY c.citizen_id, c.first_name, c.last_name, c.national_id
ORDER BY total_access_requests DESC
FETCH FIRST 10 ROWS ONLY;

-- =====================================================
-- QUERY 16: GET ENTITY COMPLIANCE SCORE
-- Purpose: Calculate compliance metrics for entities
-- =====================================================
PROMPT
PROMPT === Query 16: Entity Compliance Scores ===

SELECT 
    ae.entity_name,
    ae.entity_type,
    COUNT(ar.request_id) AS total_requests,
    ROUND(AVG(ar.risk_score), 3) AS avg_risk_score,
    COUNT(v.violation_id) AS violation_count,
    CASE 
        WHEN COUNT(v.violation_id) = 0 AND AVG(ar.risk_score) < 0.4 THEN '🟢 EXCELLENT'
        WHEN COUNT(v.violation_id) <= 1 AND AVG(ar.risk_score) < 0.5 THEN '🟡 GOOD'
        WHEN COUNT(v.violation_id) <= 3 THEN '🟠 NEEDS IMPROVEMENT'
        ELSE '🔴 CRITICAL'
    END AS compliance_score
FROM authorized_entities ae
LEFT JOIN access_requests ar ON ae.entity_id = ar.entity_id AND ar.request_date >= SYSDATE - 90
LEFT JOIN violations v ON ae.entity_id = v.entity_id AND v.violation_date >= SYSDATE - 90
WHERE ae.status = 'ACTIVE'
GROUP BY ae.entity_name, ae.entity_type
ORDER BY violation_count, avg_risk_score;

-- =====================================================
-- QUERY 17: GET CITIZEN DIGITAL ID STATUS
-- Purpose: Check digital ID validity and expiry
-- =====================================================
PROMPT
PROMPT === Query 17: Citizen Digital ID Status ===

SELECT 
    c.citizen_id,
    c.first_name || ' ' || c.last_name AS citizen_name,
    d.id_number,
    d.id_type,
    TO_CHAR(d.issue_date, 'DD-MON-YYYY') AS issue_date,
    TO_CHAR(d.expiry_date, 'DD-MON-YYYY') AS expiry_date,
    ROUND(d.expiry_date - SYSDATE) AS days_until_expiry,
    d.is_active,
    CASE 
        WHEN d.expiry_date < SYSDATE THEN '🔴 EXPIRED'
        WHEN d.expiry_date < SYSDATE + 30 THEN '🟡 EXPIRING SOON'
        WHEN d.is_active = 'N' THEN '⚪ INACTIVE'
        ELSE '🟢 ACTIVE'
    END AS status_indicator
FROM citizens c
JOIN digital_ids d ON c.citizen_id = d.citizen_id
WHERE c.status = 'ACTIVE'
ORDER BY days_until_expiry;

-- =====================================================
-- QUERY 18: GET SYSTEM ACTIVITY SUMMARY (TODAY)
-- Purpose: Daily dashboard summary
-- =====================================================
PROMPT
PROMPT === Query 18: Today's System Activity ===

SELECT 
    'Access Requests' AS metric,
    COUNT(*) AS count
FROM access_requests
WHERE TRUNC(request_date) = TRUNC(SYSDATE)

UNION ALL

SELECT 
    'New Citizens',
    COUNT(*)
FROM citizens
WHERE TRUNC(registration_date) = TRUNC(SYSDATE)

UNION ALL

SELECT 
    'Alerts Generated',
    COUNT(*)
FROM alerts
WHERE TRUNC(alert_date) = TRUNC(SYSDATE)

UNION ALL

SELECT 
    'Violations Reported',
    COUNT(*)
FROM violations
WHERE TRUNC(violation_date) = TRUNC(SYSDATE);

PROMPT
PROMPT ===== ALL DATA RETRIEVAL QUERIES COMPLETED =====
PROMPT Total Queries: 18 comprehensive retrieval queries
PROMPT Purpose: Basic data access, reporting, monitoring
PROMPT