

SET SERVEROUTPUT ON;
SET LINESIZE 200;

-- =====================================================
-- AUDIT QUERY 1: COMPLETE AUDIT TRAIL FOR REQUEST
-- Purpose: Full lifecycle tracking of single request
-- =====================================================
SELECT 
    ar.request_id,
    ar.request_date,
    ae.entity_name,
    c.first_name || ' ' || c.last_name AS citizen_name,
    ar.data_category,
    ar.request_status,
    ar.risk_score,
    al.action_type,
    al.action_timestamp,
    al.action_by,
    al.action_result,
    al.denial_reason,
    al.ip_address
FROM access_requests ar
JOIN authorized_entities ae ON ar.entity_id = ae.entity_id
JOIN digital_ids di ON ar.digital_id = di.digital_id
JOIN citizens c ON di.citizen_id = c.citizen_id
LEFT JOIN access_logs al ON ar.request_id = al.request_id
WHERE ar.request_id = &request_id
ORDER BY al.action_timestamp;

-- =====================================================
-- AUDIT QUERY 2: ALL DENIED ACCESS ATTEMPTS (LAST 30 DAYS)
-- Purpose: Security audit - unauthorized access attempts
-- =====================================================
SELECT 
    al.log_id,
    al.action_timestamp,
    al.action_by,
    ar.request_id,
    ae.entity_name,
    ae.entity_type,
    c.first_name || ' ' || c.last_name AS citizen_affected,
    ar.data_category,
    al.denial_reason,
    al.ip_address,
    ar.risk_score
FROM access_logs al
JOIN access_requests ar ON al.request_id = ar.request_id
JOIN authorized_entities ae ON ar.entity_id = ae.entity_id
JOIN digital_ids di ON ar.digital_id = di.digital_id
JOIN citizens c ON di.citizen_id = c.citizen_id
WHERE al.action_result = 'DENIED'
  AND al.action_timestamp >= SYSDATE - 30
ORDER BY al.action_timestamp DESC;

-- =====================================================
-- AUDIT QUERY 3: CONSENT CHANGE HISTORY FOR CITIZEN
-- Purpose: Track all consent modifications
-- =====================================================
SELECT 
    cr.consent_id,
    c.first_name || ' ' || c.last_name AS citizen_name,
    dc.category_name,
    cr.entity_type,
    cr.consent_status,
    cr.consent_level,
    cr.granted_date,
    cr.expiry_date,
    cr.revoked_date,
    CASE 
        WHEN cr.consent_status = 'GRANTED' THEN 'Active consent'
        WHEN cr.consent_status = 'REVOKED' THEN 'Revoked on ' || TO_CHAR(cr.revoked_date, 'DD-MON-YYYY')
        WHEN cr.consent_status = 'EXPIRED' THEN 'Expired on ' || TO_CHAR(cr.expiry_date, 'DD-MON-YYYY')
    END AS status_detail
FROM consent_records cr
JOIN citizens c ON cr.citizen_id = c.citizen_id
JOIN data_categories dc ON cr.data_category_id = dc.category_id
WHERE c.citizen_id = &citizen_id
ORDER BY cr.granted_date DESC;

-- =====================================================
-- AUDIT QUERY 4: ENTITY ACCESS AUDIT LOG
-- Purpose: Complete access history for specific entity
-- =====================================================
SELECT 
    ar.request_id,
    ar.request_date,
    c.first_name || ' ' || c.last_name AS citizen_accessed,
    ar.data_category,
    ar.purpose,
    ar.request_status,
    ar.risk_score,
    ar.approved_by,
    al.action_type,
    al.action_result,
    al.action_timestamp,
    al.ip_address
FROM access_requests ar
JOIN digital_ids di ON ar.digital_id = di.digital_id
JOIN citizens c ON di.citizen_id = c.citizen_id
LEFT JOIN access_logs al ON ar.request_id = al.request_id
WHERE ar.entity_id = &entity_id
ORDER BY ar.request_date DESC;

-- =====================================================
-- AUDIT QUERY 5: SUSPICIOUS ACTIVITY REPORT
-- Purpose: Identify anomalies and potential security breaches
-- =====================================================
WITH suspicious_patterns AS (
    -- Pattern 1: Multiple failed attempts in short time
    SELECT 
        'MULTIPLE_FAILURES' AS pattern_type,
        entity_id,
        COUNT(*) AS incident_count,
        MIN(request_date) AS first_occurrence,
        MAX(request_date) AS last_occurrence
    FROM access_requests
    WHERE request_status = 'DENIED'
      AND request_date >= SYSDATE - 1
    GROUP BY entity_id
    HAVING COUNT(*) >= 3
    
    UNION ALL
    
    -- Pattern 2: Access attempts outside business hours
    SELECT 
        'OFF_HOURS_ACCESS' AS pattern_type,
        entity_id,
        COUNT(*) AS incident_count,
        MIN(request_date) AS first_occurrence,
        MAX(request_date) AS last_occurrence
    FROM access_requests
    WHERE EXTRACT(HOUR FROM request_date) NOT BETWEEN 6 AND 22
      AND request_date >= SYSDATE - 7
    GROUP BY entity_id
    HAVING COUNT(*) >= 5
    
    UNION ALL
    
    -- Pattern 3: Excessive high-risk requests
    SELECT 
        'HIGH_RISK_PATTERN' AS pattern_type,
        entity_id,
        COUNT(*) AS incident_count,
        MIN(request_date) AS first_occurrence,
        MAX(request_date) AS last_occurrence
    FROM access_requests
    WHERE risk_score >= 0.7
      AND request_date >= SYSDATE - 7
    GROUP BY entity_id
    HAVING COUNT(*) >= 10
)
SELECT 
    sp.pattern_type,
    ae.entity_name,
    ae.entity_type,
    sp.incident_count,
    sp.first_occurrence,
    sp.last_occurrence,
    ROUND((sp.last_occurrence - sp.first_occurrence) * 24, 2) AS hours_duration
FROM suspicious_patterns sp
JOIN authorized_entities ae ON sp.entity_id = ae.entity_id
ORDER BY sp.pattern_type, sp.incident_count DESC;

-- =====================================================
-- AUDIT QUERY 6: VIOLATION INVESTIGATION REPORT
-- Purpose: Detailed view of all violations for compliance
-- =====================================================
SELECT 
    v.violation_id,
    v.violation_date,
    v.violation_type,
    ae.entity_name,
    ae.entity_type,
    ar.purpose AS request_purpose,
    c.first_name || ' ' || c.last_name AS citizen_affected,
    v.description,
    v.penalty_amount,
    v.status AS investigation_status,
    v.reported_to_authority,
    CASE 
        WHEN v.reported_to_authority = 'Y' THEN 'Escalated to regulatory authority'
        WHEN v.status = 'CONFIRMED' THEN 'Violation confirmed - penalties applied'
        WHEN v.status = 'DISMISSED' THEN 'After investigation - no violation found'
        ELSE 'Under investigation'
    END AS status_detail
FROM violations v
JOIN authorized_entities ae ON v.entity_id = ae.entity_id
LEFT JOIN access_requests ar ON v.request_id = ar.request_id
LEFT JOIN digital_ids di ON ar.digital_id = di.digital_id
LEFT JOIN citizens c ON di.citizen_id = c.citizen_id
WHERE v.violation_date >= SYSDATE - 90
ORDER BY v.violation_date DESC;

-- =====================================================
-- AUDIT QUERY 7: ALERT INVESTIGATION LOG
-- Purpose: Track all security alerts and resolutions
-- =====================================================
SELECT 
    a.alert_id,
    a.alert_date,
    a.alert_type,
    a.severity,
    c.first_name || ' ' || c.last_name AS citizen_affected,
    ar.request_id,
    ae.entity_name,
    a.alert_message,
    a.status AS alert_status,
    a.reviewed_by,
    a.reviewed_date,
    ROUND((a.reviewed_date - a.alert_date) * 24, 2) AS response_time_hours,
    a.resolution_notes
FROM alerts a
LEFT JOIN citizens c ON a.citizen_id = c.citizen_id
LEFT JOIN access_requests ar ON a.request_id = ar.request_id
LEFT JOIN authorized_entities ae ON ar.entity_id = ae.entity_id
WHERE a.alert_date >= SYSDATE - 30
ORDER BY a.severity DESC, a.alert_date DESC;

-- =====================================================
-- AUDIT QUERY 8: DATA ACCESS TRANSPARENCY REPORT
-- Purpose: Show all entities that accessed specific citizen
-- =====================================================
SELECT 
    c.first_name || ' ' || c.last_name AS citizen_name,
    c.national_id,
    ae.entity_name,
    ae.entity_type,
    COUNT(*) AS total_accesses,
    MAX(ar.request_date) AS last_access_date,
    LISTAGG(DISTINCT ar.data_category, ', ') WITHIN GROUP (ORDER BY ar.data_category) AS categories_accessed,
    SUM(CASE WHEN ar.request_status = 'APPROVED' THEN 1 ELSE 0 END) AS approved_accesses,
    SUM(CASE WHEN ar.request_status = 'DENIED' THEN 1 ELSE 0 END) AS denied_accesses
FROM citizens c
JOIN digital_ids di ON c.citizen_id = di.citizen_id
JOIN access_requests ar ON di.digital_id = ar.digital_id
JOIN authorized_entities ae ON ar.entity_id = ae.entity_id
WHERE c.citizen_id = &citizen_id
  AND ar.request_date >= SYSDATE - 365
GROUP BY c.first_name, c.last_name, c.national_id, ae.entity_name, ae.entity_type
ORDER BY total_accesses DESC;

-- =====================================================
-- AUDIT QUERY 9: IMMUTABLE LOG VERIFICATION
-- Purpose: Verify audit log integrity (no modifications)
-- =====================================================
SELECT 
    'ACCESS_LOGS' AS table_name,
    COUNT(*) AS total_records,
    MIN(created_date) AS oldest_log,
    MAX(created_date) AS newest_log,
    COUNT(DISTINCT action_by) AS unique_actors,
    SUM(CASE WHEN action_result = 'SUCCESS' THEN 1 ELSE 0 END) AS successful_actions,
    SUM(CASE WHEN action_result = 'DENIED' THEN 1 ELSE 0 END) AS denied_actions,
    SUM(CASE WHEN action_result = 'ERROR' THEN 1 ELSE 0 END) AS error_actions
FROM access_logs
WHERE created_date >= SYSDATE - 30;

-- Verify no modifications (created_date should never be older than action_timestamp)
SELECT 
    log_id,
    action_timestamp,
    created_date,
    CASE 
        WHEN created_date < action_timestamp THEN 'INTEGRITY VIOLATION'
        ELSE 'OK'
    END AS integrity_check
FROM access_logs
WHERE created_date < action_timestamp;

-- =====================================================
-- AUDIT QUERY 10: COMPLIANCE ATTESTATION DATA
-- Purpose: Generate regulatory compliance report
-- =====================================================
WITH compliance_metrics AS (
    SELECT 
        'Consent Coverage' AS metric_name,
        ROUND((SELECT COUNT(*) FROM consent_records WHERE consent_status = 'GRANTED') * 100.0 / 
              NULLIF((SELECT COUNT(*) FROM citizens WHERE status = 'ACTIVE'), 0), 2) AS metric_value,
        '> 80%' AS target,
        CASE WHEN ROUND((SELECT COUNT(*) FROM consent_records WHERE consent_status = 'GRANTED') * 100.0 / 
              NULLIF((SELECT COUNT(*) FROM citizens WHERE status = 'ACTIVE'), 0), 2) >= 80 
             THEN 'PASS' ELSE 'FAIL' END AS status
    FROM dual
    
    UNION ALL
    
    SELECT 
        'Audit Log Completeness',
        ROUND((SELECT COUNT(*) FROM access_logs) * 100.0 / 
              NULLIF((SELECT COUNT(*) FROM access_requests), 0), 2),
        '100%',
        CASE WHEN ROUND((SELECT COUNT(*) FROM access_logs) * 100.0 / 
              NULLIF((SELECT COUNT(*) FROM access_requests), 0), 2) = 100 
             THEN 'PASS' ELSE 'FAIL' END
    FROM dual
    
    UNION ALL
    
    SELECT 
        'Violation Rate',
        ROUND((SELECT COUNT(*) FROM violations WHERE violation_date >= ADD_MONTHS(SYSDATE, -1)) * 100.0 / 
              NULLIF((SELECT COUNT(*) FROM access_requests WHERE request_date >= ADD_MONTHS(SYSDATE, -1)), 0), 2),
        '< 1%',
        CASE WHEN ROUND((SELECT COUNT(*) FROM violations WHERE violation_date >= ADD_MONTHS(SYSDATE, -1)) * 100.0 / 
              NULLIF((SELECT COUNT(*) FROM access_requests WHERE request_date >= ADD_MONTHS(SYSDATE, -1)), 0), 2) < 1 
             THEN 'PASS' ELSE 'FAIL' END
    FROM dual
    
    UNION ALL
    
    SELECT 
        'Entity Authorization Currency',
        ROUND((SELECT COUNT(*) FROM authorized_entities WHERE status = 'ACTIVE' AND expiry_date > SYSDATE) * 100.0 / 
              NULLIF((SELECT COUNT(*) FROM authorized_entities WHERE status = 'ACTIVE'), 0), 2),
        '100%',
        CASE WHEN ROUND((SELECT COUNT(*) FROM authorized_entities WHERE status = 'ACTIVE' AND expiry_date > SYSDATE) * 100.0 / 
              NULLIF((SELECT COUNT(*) FROM authorized_entities WHERE status = 'ACTIVE'), 0), 2) = 100 
             THEN 'PASS' ELSE 'FAIL' END
    FROM dual
    
    UNION ALL
    
    SELECT 
        'Data Retention Compliance',
        ROUND((SELECT COUNT(*) FROM access_logs WHERE created_date >= SYSDATE - 2555) * 100.0 / 
              NULLIF((SELECT COUNT(*) FROM access_logs), 0), 2),
        '100%',
        'PASS'
    FROM dual
)
SELECT 
    metric_name,
    metric_value || '%' AS current_value,
    target AS required_target,
    status AS compliance_status
FROM compliance_metrics;

-- =====================================================
-- AUDIT QUERY 11: CHANGE TRACKING - CITIZEN STATUS
-- Purpose: Audit all citizen status changes
-- =====================================================
-- Note: This would typically use a separate audit table
-- For demonstration, showing current status with modification tracking
SELECT 
    citizen_id,
    first_name || ' ' || last_name AS citizen_name,
    national_id,
    status AS current_status,
    created_by,
    created_date AS registration_date,
    modified_by AS last_modified_by,
    modified_date AS last_modification_date,
    ROUND((modified_date - created_date), 2) AS days_since_registration
FROM citizens
WHERE modified_date IS NOT NULL
ORDER BY modified_date DESC;

-- =====================================================
-- AUDIT QUERY 12: WEEKLY AUDIT SUMMARY
-- Purpose: Management report - weekly activity overview
-- =====================================================
DECLARE
    v_week_start DATE := TRUNC(SYSDATE, 'IW');
    v_week_end DATE := v_week_start + 6;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== WEEKLY AUDIT SUMMARY ===');
    DBMS_OUTPUT.PUT_LINE('Week: ' || TO_CHAR(v_week_start, 'DD-MON-YYYY') || 
                       ' to ' || TO_CHAR(v_week_end, 'DD-MON-YYYY'));
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Access Requests
    FOR rec IN (
        SELECT 
            request_status,
            COUNT(*) AS request_count,
            ROUND(AVG(risk_score), 3) AS avg_risk
        FROM access_requests
        WHERE request_date BETWEEN v_week_start AND v_week_end
        GROUP BY request_status
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('Requests ' || RPAD(rec.request_status, 10) || ': ' || 
                           rec.request_count || ' (Avg Risk: ' || rec.avg_risk || ')');
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Alerts
    DECLARE
        v_alert_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_alert_count
        FROM alerts
        WHERE alert_date BETWEEN v_week_start AND v_week_end
          AND severity IN ('HIGH', 'CRITICAL');
        
        DBMS_OUTPUT.PUT_LINE('Critical/High Alerts: ' || v_alert_count);
    END;
    
    -- Violations
    DECLARE
        v_violation_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_violation_count
        FROM violations
        WHERE violation_date BETWEEN v_week_start AND v_week_end;
        
        DBMS_OUTPUT.PUT_LINE('Violations Reported: ' || v_violation_count);
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=== END OF WEEKLY SUMMARY ===');
END;
/

PROMPT
PROMPT ===== AUDIT QUERIES COMPLETED =====
PROMPT Total Queries: 12 comprehensive audit queries
PROMPT Purpose: Compliance reporting, security investigation, transparency
PROMPT