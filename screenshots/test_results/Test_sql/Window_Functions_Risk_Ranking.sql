-- Top 10 risky requests with ranking
SELECT 
    request_id,
    entity_id,
    ROUND(risk_score, 3) AS risk_score,
    TO_CHAR(request_date, 'DD-MON-YY HH24:MI') AS request_time,
    ROW_NUMBER() OVER (ORDER BY risk_score DESC) AS risk_rank,
    RANK() OVER (ORDER BY risk_score DESC) AS rank_with_ties,
    CASE 
        WHEN risk_score >= 0.7 THEN 'HIGH'
        WHEN risk_score >= 0.4 THEN 'MODERATE'
        ELSE 'LOW'
    END AS risk_category
FROM access_requests
WHERE request_date >= SYSDATE - 7
ORDER BY risk_score DESC
FETCH FIRST 10 ROWS ONLY;