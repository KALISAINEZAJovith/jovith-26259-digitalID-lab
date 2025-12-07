
SET SERVEROUTPUT ON;

-- =====================================================
-- EXAMPLE 1: EXPLICIT CURSOR - Process Expired Consents
-- Purpose: Find and update all expired consents
-- =====================================================
DECLARE
    CURSOR c_expired_consents IS
        SELECT consent_id, citizen_id, data_category_id, expiry_date
        FROM consent_records
        WHERE consent_status = 'GRANTED'
          AND expiry_date < SYSDATE
        FOR UPDATE; -- Lock rows for update
    
    v_updated_count NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== Processing Expired Consents ===');
    
    FOR rec IN c_expired_consents LOOP
        UPDATE consent_records
        SET consent_status = 'EXPIRED'
        WHERE CURRENT OF c_expired_consents;
        
        v_updated_count := v_updated_count + 1;
        
        DBMS_OUTPUT.PUT_LINE('Expired consent ID: ' || rec.consent_id || 
                           ' for citizen: ' || rec.citizen_id);
    END LOOP;
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('Total consents expired: ' || v_updated_count);
    DBMS_OUTPUT.PUT_LINE('');
END;
/

-- =====================================================
-- EXAMPLE 2: EXPLICIT CURSOR WITH PARAMETERS
-- Purpose: Get access requests for specific entity
-- =====================================================
DECLARE
    CURSOR c_entity_requests(p_entity_id NUMBER, p_status VARCHAR2) IS
        SELECT request_id, digital_id, purpose, request_date, risk_score
        FROM access_requests
        WHERE entity_id = p_entity_id
          AND request_status = p_status
        ORDER BY request_date DESC;
    
    v_entity_id NUMBER;
    v_rec c_entity_requests%ROWTYPE;
BEGIN
    -- Get first entity
    SELECT entity_id INTO v_entity_id
    FROM authorized_entities
    WHERE status = 'ACTIVE'
      AND ROWNUM = 1;
    
    DBMS_OUTPUT.PUT_LINE('=== Pending Requests for Entity ' || v_entity_id || ' ===');
    
    OPEN c_entity_requests(v_entity_id, 'PENDING');
    
    LOOP
        FETCH c_entity_requests INTO v_rec;
        EXIT WHEN c_entity_requests%NOTFOUND;
        
        DBMS_OUTPUT.PUT_LINE('Request: ' || v_rec.request_id || 
                           ', Risk: ' || v_rec.risk_score ||
                           ', Date: ' || TO_CHAR(v_rec.request_date, 'YYYY-MM-DD'));
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('Total rows fetched: ' || c_entity_requests%ROWCOUNT);
    
    CLOSE c_entity_requests;
    DBMS_OUTPUT.PUT_LINE('');
END;
/

-- =====================================================
-- EXAMPLE 3: BULK COLLECT - High-Performance Cursor
-- Purpose: Process large result sets efficiently
-- =====================================================
DECLARE
    TYPE t_request_id IS TABLE OF access_requests.request_id%TYPE;
    TYPE t_entity_id IS TABLE OF access_requests.entity_id%TYPE;
    TYPE t_risk_score IS TABLE OF access_requests.risk_score%TYPE;
    
    v_request_ids t_request_id;
    v_entity_ids  t_entity_id;
    v_risk_scores t_risk_score;
    
    CURSOR c_high_risk IS
        SELECT request_id, entity_id, risk_score
        FROM access_requests
        WHERE risk_score >= 0.7
          AND request_status = 'PENDING';
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== Processing High-Risk Requests (Bulk) ===');
    
    OPEN c_high_risk;
    
    FETCH c_high_risk BULK COLLECT INTO 
        v_request_ids, v_entity_ids, v_risk_scores
    LIMIT 100; -- Process in batches of 100
    
    CLOSE c_high_risk;
    
    FOR i IN 1..v_request_ids.COUNT LOOP
        DBMS_OUTPUT.PUT_LINE('Request: ' || v_request_ids(i) || 
                           ', Entity: ' || v_entity_ids(i) ||
                           ', Risk: ' || v_risk_scores(i));
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('Total high-risk requests: ' || v_request_ids.COUNT);
    DBMS_OUTPUT.PUT_LINE('');
END;
/

-- =====================================================
-- WINDOW FUNCTION 1: ROW_NUMBER()
-- Purpose: Rank access requests by risk score per entity
-- =====================================================
SELECT 
    entity_id,
    request_id,
    risk_score,
    request_date,
    ROW_NUMBER() OVER (
        PARTITION BY entity_id 
        ORDER BY risk_score DESC, request_date DESC
    ) AS risk_rank_within_entity
FROM access_requests
WHERE request_status = 'PENDING'
ORDER BY entity_id, risk_rank_within_entity
FETCH FIRST 20 ROWS ONLY;

-- =====================================================
-- WINDOW FUNCTION 2: RANK() and DENSE_RANK()
-- Purpose: Find top risky entities with tied rankings
-- =====================================================
WITH entity_risk_summary AS (
    SELECT 
        entity_id,
        COUNT(*) AS total_requests,
        AVG(risk_score) AS avg_risk_score,
        MAX(risk_score) AS max_risk_score
    FROM access_requests
    WHERE request_date >= SYSDATE - 30
    GROUP BY entity_id
)
SELECT 
    entity_id,
    total_requests,
    ROUND(avg_risk_score, 3) AS avg_risk,
    ROUND(max_risk_score, 3) AS max_risk,
    RANK() OVER (ORDER BY avg_risk_score DESC) AS risk_rank,
    DENSE_RANK() OVER (ORDER BY avg_risk_score DESC) AS dense_risk_rank
FROM entity_risk_summary
ORDER BY risk_rank
FETCH FIRST 10 ROWS ONLY;

-- =====================================================
-- WINDOW FUNCTION 3: LAG() and LEAD()
-- Purpose: Compare consecutive access requests for pattern detection
-- =====================================================
SELECT 
    request_id,
    entity_id,
    request_date,
    risk_score,
    LAG(risk_score, 1) OVER (
        PARTITION BY entity_id 
        ORDER BY request_date
    ) AS previous_risk_score,
    LEAD(risk_score, 1) OVER (
        PARTITION BY entity_id 
        ORDER BY request_date
    ) AS next_risk_score,
    risk_score - LAG(risk_score, 1, 0) OVER (
        PARTITION BY entity_id 
        ORDER BY request_date
    ) AS risk_increase
FROM access_requests
WHERE request_date >= SYSDATE - 7
ORDER BY entity_id, request_date
FETCH FIRST 20 ROWS ONLY;

-- =====================================================
-- WINDOW FUNCTION 4: Running Totals and Moving Averages
-- Purpose: Calculate cumulative access counts and trends
-- =====================================================
SELECT 
    TRUNC(request_date) AS request_day,
    COUNT(*) AS daily_requests,
    SUM(COUNT(*)) OVER (
        ORDER BY TRUNC(request_date)
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_requests,
    AVG(COUNT(*)) OVER (
        ORDER BY TRUNC(request_date)
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS moving_avg_7days
FROM access_requests
WHERE request_date >= SYSDATE - 30
GROUP BY TRUNC(request_date)
ORDER BY request_day DESC;

-- =====================================================
-- WINDOW FUNCTION 5: NTILE() - Quartile Analysis
-- Purpose: Divide citizens into risk quartiles
-- =====================================================
WITH citizen_access_stats AS (
    SELECT 
        c.citizen_id,
        c.first_name || ' ' || c.last_name AS citizen_name,
        COUNT(ar.request_id) AS total_access_requests,
        AVG(ar.risk_score) AS avg_risk_score
    FROM citizens c
    LEFT JOIN digital_ids di ON c.citizen_id = di.citizen_id
    LEFT JOIN access_requests ar ON di.digital_id = ar.digital_id
    WHERE ar.request_date >= SYSDATE - 90
    GROUP BY c.citizen_id, c.first_name, c.last_name
    HAVING COUNT(ar.request_id) > 0
)
SELECT 
    citizen_id,
    citizen_name,
    total_access_requests,
    ROUND(avg_risk_score, 3) AS avg_risk,
    NTILE(4) OVER (ORDER BY avg_risk_score) AS risk_quartile,
    CASE 
        WHEN NTILE(4) OVER (ORDER BY avg_risk_score) = 4 THEN 'HIGH RISK'
        WHEN NTILE(4) OVER (ORDER BY avg_risk_score) = 3 THEN 'MODERATE RISK'
        WHEN NTILE(4) OVER (ORDER BY avg_risk_score) = 2 THEN 'LOW RISK'
        ELSE 'MINIMAL RISK'
    END AS risk_category
FROM citizen_access_stats
ORDER BY risk_quartile DESC, avg_risk_score DESC
FETCH FIRST 30 ROWS ONLY;

-- =====================================================
-- COMPLEX EXAMPLE: Comprehensive Access Pattern Analysis
-- Purpose: Combine multiple window functions for insights
-- =====================================================
WITH daily_entity_activity AS (
    SELECT 
        TRUNC(request_date) AS activity_date,
        entity_id,
        COUNT(*) AS daily_requests,
        AVG(risk_score) AS daily_avg_risk,
        MAX(risk_score) AS daily_max_risk,
        COUNT(CASE WHEN request_status = 'DENIED' THEN 1 END) AS denied_count
    FROM access_requests
    WHERE request_date >= SYSDATE - 30
    GROUP BY TRUNC(request_date), entity_id
)
SELECT 
    activity_date,
    entity_id,
    daily_requests,
    ROUND(daily_avg_risk, 3) AS avg_risk,
    ROUND(daily_max_risk, 3) AS max_risk,
    denied_count,
    -- Running statistics
    SUM(daily_requests) OVER (
        PARTITION BY entity_id 
        ORDER BY activity_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_requests,
    -- Moving average (7-day)
    ROUND(AVG(daily_avg_risk) OVER (
        PARTITION BY entity_id 
        ORDER BY activity_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 3) AS moving_avg_risk_7d,
    -- Comparison with previous day
    daily_avg_risk - LAG(daily_avg_risk, 1) OVER (
        PARTITION BY entity_id 
        ORDER BY activity_date
    ) AS risk_change_from_prev_day,
    -- Rank within entity's history
    RANK() OVER (
        PARTITION BY entity_id 
        ORDER BY daily_avg_risk DESC
    ) AS risk_rank_in_history
FROM daily_entity_activity
ORDER BY activity_date DESC, entity_id
FETCH FIRST 50 ROWS ONLY;

-- =====================================================
-- PROCEDURE USING CURSOR: Monthly Compliance Report
-- Purpose: Generate compliance report using explicit cursor
-- =====================================================
CREATE OR REPLACE PROCEDURE generate_monthly_compliance_report(
    p_month IN NUMBER DEFAULT EXTRACT(MONTH FROM SYSDATE),
    p_year  IN NUMBER DEFAULT EXTRACT(YEAR FROM SYSDATE)
)
IS
    CURSOR c_monthly_stats IS
        SELECT 
            ae.entity_name,
            ae.entity_type,
            COUNT(*) AS total_requests,
            SUM(CASE WHEN ar.request_status = 'APPROVED' THEN 1 ELSE 0 END) AS approved,
            SUM(CASE WHEN ar.request_status = 'DENIED' THEN 1 ELSE 0 END) AS denied,
            AVG(ar.risk_score) AS avg_risk
        FROM access_requests ar
        JOIN authorized_entities ae ON ar.entity_id = ae.entity_id
        WHERE EXTRACT(MONTH FROM ar.request_date) = p_month
          AND EXTRACT(YEAR FROM ar.request_date) = p_year
        GROUP BY ae.entity_name, ae.entity_type
        ORDER BY total_requests DESC;
    
    v_total_requests NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== MONTHLY COMPLIANCE REPORT ===');
    DBMS_OUTPUT.PUT_LINE('Month: ' || p_month || '/' || p_year);
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE(RPAD('Entity', 35) || RPAD('Type', 15) || 
                       RPAD('Total', 8) || RPAD('Approved', 10) || 
                       RPAD('Denied', 8) || 'Avg Risk');
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 90, '-'));
    
    FOR rec IN c_monthly_stats LOOP
        DBMS_OUTPUT.PUT_LINE(
            RPAD(rec.entity_name, 35) ||
            RPAD(rec.entity_type, 15) ||
            RPAD(rec.total_requests, 8) ||
            RPAD(rec.approved, 10) ||
            RPAD(rec.denied, 8) ||
            ROUND(rec.avg_risk, 2)
        );
        
        v_total_requests := v_total_requests + rec.total_requests;
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 90, '-'));
    DBMS_OUTPUT.PUT_LINE('Total Requests Processed: ' || v_total_requests);
END generate_monthly_compliance_report;
/

-- =====================================================
-- TEST THE PROCEDURE
-- =====================================================
BEGIN
    generate_monthly_compliance_report(12, 2025);
END;
/

PROMPT
PROMPT ===== CURSORS AND WINDOW FUNCTIONS COMPLETED =====
PROMPT