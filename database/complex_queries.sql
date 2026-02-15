-- Complex SQL Queries for Reporting
-- Demonstrates PostgreSQL proficiency

-- Query 1: Customer Health Dashboard
-- Shows customer integration status with multiple metrics
SELECT 
    ci.customer_name,
    ci.integration_type,
    ci.status as integration_status,
    COUNT(DISTINCT hc.check_id) as total_health_checks,
    ROUND(AVG(hc.response_time_ms), 2) as avg_response_time,
    COUNT(CASE WHEN hc.success = FALSE THEN 1 END) as failed_checks,
    COUNT(DISTINCT a.alert_id) FILTER (WHERE a.resolved = FALSE) as active_alerts,
    ci.last_sync_at,
    CASE 
        WHEN ci.status = 'error' THEN 'red'
        WHEN ci.error_count > 3 THEN 'yellow'
        WHEN COUNT(CASE WHEN hc.success = FALSE THEN 1 END) > 5 THEN 'yellow'
        ELSE 'green'
    END as health_color
FROM customer_integrations ci
LEFT JOIN api_endpoints e ON e.customer_name = ci.customer_name
LEFT JOIN health_checks hc ON e.endpoint_id = hc.endpoint_id 
    AND hc.checked_at >= NOW() - INTERVAL '24 hours'
LEFT JOIN alerts a ON ci.integration_id = a.integration_id
GROUP BY ci.integration_id, ci.customer_name, ci.integration_type, 
         ci.status, ci.error_count, ci.last_sync_at
ORDER BY health_color DESC, ci.customer_name;

-- Query 2: API Performance Comparison (Window Functions)
-- Ranks endpoints by performance with percentile calculations
WITH endpoint_stats AS (
    SELECT 
        e.name,
        e.customer_name,
        hc.response_time_ms,
        hc.success,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY hc.response_time_ms) 
            OVER (PARTITION BY e.endpoint_id) as median_response_time,
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY hc.response_time_ms) 
            OVER (PARTITION BY e.endpoint_id) as p95_response_time,
        ROW_NUMBER() OVER (PARTITION BY e.endpoint_id ORDER BY hc.checked_at DESC) as recency_rank
    FROM api_endpoints e
    JOIN health_checks hc ON e.endpoint_id = hc.endpoint_id
    WHERE hc.checked_at >= NOW() - INTERVAL '7 days'
)
SELECT DISTINCT
    name,
    customer_name,
    ROUND(median_response_time, 2) as median_ms,
    ROUND(p95_response_time, 2) as p95_ms,
    RANK() OVER (ORDER BY median_response_time ASC) as performance_rank
FROM endpoint_stats
WHERE recency_rank <= 100
ORDER BY performance_rank;

-- Query 3: Error Pattern Analysis (CTEs and Aggregations)
-- Identifies common error patterns and affected customers
WITH error_patterns AS (
    SELECT 
        e.customer_name,
        hc.error_type,
        hc.status_code,
        COUNT(*) as occurrence_count,
        MIN(hc.checked_at) as first_occurrence,
        MAX(hc.checked_at) as last_occurrence,
        ARRAY_AGG(DISTINCT e.name) as affected_endpoints
    FROM health_checks hc
    JOIN api_endpoints e ON hc.endpoint_id = e.endpoint_id
    WHERE hc.success = FALSE
        AND hc.checked_at >= NOW() - INTERVAL '7 days'
    GROUP BY e.customer_name, hc.error_type, hc.status_code
),
customer_impact AS (
    SELECT 
        customer_name,
        COUNT(DISTINCT error_type) as unique_error_types,
        SUM(occurrence_count) as total_errors
    FROM error_patterns
    GROUP BY customer_name
)
SELECT 
    ep.customer_name,
    ep.error_type,
    ep.status_code,
    ep.occurrence_count,
    ep.first_occurrence,
    ep.last_occurrence,
    ep.affected_endpoints,
    ci.unique_error_types,
    ci.total_errors,
    ROUND(100.0 * ep.occurrence_count / ci.total_errors, 2) as pct_of_customer_errors
FROM error_patterns ep
JOIN customer_impact ci ON ep.customer_name = ci.customer_name
ORDER BY ci.total_errors DESC, ep.occurrence_count DESC;

-- Query 4: Webhook Processing Metrics (JSONB Queries)
-- Analyzes webhook data using JSON operators
SELECT 
    source,
    event_type,
    COUNT(*) as total_events,
    COUNT(CASE WHEN processed = TRUE THEN 1 END) as processed_count,
    COUNT(CASE WHEN signature_valid = FALSE THEN 1 END) as signature_failures,
    ROUND(AVG(EXTRACT(EPOCH FROM (processed_at - received_at))), 2) as avg_processing_seconds,
    -- Extract common JSON fields
    COUNT(DISTINCT payload->>'id') as unique_entities,
    MODE() WITHIN GROUP (ORDER BY payload->>'status') as most_common_status
FROM webhook_events
WHERE received_at >= NOW() - INTERVAL '7 days'
GROUP BY source, event_type
ORDER BY total_events DESC;

-- Query 5: Time-Series Analysis with LAG
-- Compares current performance vs previous period
WITH hourly_metrics AS (
    SELECT 
        e.name,
        DATE_TRUNC('hour', hc.checked_at) as hour,
        AVG(hc.response_time_ms) as avg_response_time,
        COUNT(CASE WHEN hc.success = FALSE THEN 1 END) as error_count
    FROM health_checks hc
    JOIN api_endpoints e ON hc.endpoint_id = e.endpoint_id
    WHERE hc.checked_at >= NOW() - INTERVAL '48 hours'
    GROUP BY e.name, DATE_TRUNC('hour', hc.checked_at)
)
SELECT 
    name,
    hour,
    ROUND(avg_response_time, 2) as current_avg_ms,
    ROUND(LAG(avg_response_time, 1) OVER (PARTITION BY name ORDER BY hour), 2) as previous_hour_ms,
    ROUND(avg_response_time - LAG(avg_response_time, 1) OVER (PARTITION BY name ORDER BY hour), 2) as change_ms,
    error_count,
    LAG(error_count, 1) OVER (PARTITION BY name ORDER BY hour) as previous_hour_errors
FROM hourly_metrics
ORDER BY name, hour DESC;

-- Query 6: Alert Effectiveness Report
-- Analyzes how quickly alerts are resolved
SELECT 
    alert_type,
    severity,
    COUNT(*) as total_alerts,
    COUNT(CASE WHEN resolved = TRUE THEN 1 END) as resolved_count,
    ROUND(
        AVG(EXTRACT(EPOCH FROM (resolved_at - created_at)) / 60) 
        FILTER (WHERE resolved = TRUE),
        2
    ) as avg_resolution_minutes,
    MIN(created_at) as first_alert,
    MAX(created_at) as most_recent_alert
FROM alerts
WHERE created_at >= NOW() - INTERVAL '30 days'
GROUP BY alert_type, severity
ORDER BY severity, total_alerts DESC;