-- SaaS Integration Toolkit Database Schema
-- PostgreSQL 14+

-- Table 1: API Endpoints (Services being monitored)
CREATE TABLE api_endpoints (
    endpoint_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    base_url TEXT NOT NULL,
    endpoint_path TEXT NOT NULL,
    http_method VARCHAR(10) DEFAULT 'GET',
    expected_status_code INT DEFAULT 200,
    timeout_seconds INT DEFAULT 30,
    environment VARCHAR(20) DEFAULT 'production', -- production, staging, dev
    customer_name VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table 2: Health Checks (Monitoring results)
CREATE TABLE health_checks (
    check_id SERIAL PRIMARY KEY,
    endpoint_id INT REFERENCES api_endpoints(endpoint_id) ON DELETE CASCADE,
    status_code INT,
    response_time_ms DECIMAL(10, 2),
    success BOOLEAN,
    error_type VARCHAR(50), -- TIMEOUT, CONNECTION_ERROR, INVALID_RESPONSE, etc.
    error_message TEXT,
    response_body TEXT,
    checked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table 3: Webhooks (Incoming webhook events)
CREATE TABLE webhook_events (
    event_id SERIAL PRIMARY KEY,
    source VARCHAR(100) NOT NULL, -- salesforce, stripe, hubspot, etc.
    event_type VARCHAR(100),
    payload JSONB NOT NULL,
    headers JSONB,
    signature VARCHAR(255),
    signature_valid BOOLEAN,
    ip_address INET,
    received_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processed BOOLEAN DEFAULT FALSE,
    processed_at TIMESTAMP
);

-- Table 4: Integration Logs (Application logs)
CREATE TABLE integration_logs (
    log_id SERIAL PRIMARY KEY,
    log_level VARCHAR(20) NOT NULL, -- DEBUG, INFO, WARNING, ERROR, CRITICAL
    source VARCHAR(100), -- Which integration/service
    message TEXT NOT NULL,
    error_code VARCHAR(50),
    stack_trace TEXT,
    metadata JSONB,
    timestamp TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table 5: Customer Integrations (Track customer setup)
CREATE TABLE customer_integrations (
    integration_id SERIAL PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    integration_type VARCHAR(50) NOT NULL, -- salesforce, api, webhook, etc.
    status VARCHAR(20) DEFAULT 'active', -- active, paused, error, setup
    config JSONB, -- Integration configuration
    last_sync_at TIMESTAMP,
    error_count INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table 6: Alerts (Issues detected)
CREATE TABLE alerts (
    alert_id SERIAL PRIMARY KEY,
    endpoint_id INT REFERENCES api_endpoints(endpoint_id),
    integration_id INT REFERENCES customer_integrations(integration_id),
    alert_type VARCHAR(50) NOT NULL, -- API_DOWN, SLOW_RESPONSE, WEBHOOK_FAILURE
    severity VARCHAR(20) NOT NULL, -- LOW, MEDIUM, HIGH, CRITICAL
    title VARCHAR(200) NOT NULL,
    description TEXT,
    resolved BOOLEAN DEFAULT FALSE,
    resolved_at TIMESTAMP,
    resolved_by VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for Performance
CREATE INDEX idx_health_checks_endpoint ON health_checks(endpoint_id);
CREATE INDEX idx_health_checks_time ON health_checks(checked_at DESC);
CREATE INDEX idx_health_checks_success ON health_checks(success);

CREATE INDEX idx_webhook_source ON webhook_events(source);
CREATE INDEX idx_webhook_received ON webhook_events(received_at DESC);
CREATE INDEX idx_webhook_processed ON webhook_events(processed);

CREATE INDEX idx_logs_level ON integration_logs(log_level);
CREATE INDEX idx_logs_timestamp ON integration_logs(timestamp DESC);
CREATE INDEX idx_logs_source ON integration_logs(source);

CREATE INDEX idx_alerts_resolved ON alerts(resolved);
CREATE INDEX idx_alerts_severity ON alerts(severity);
CREATE INDEX idx_alerts_created ON alerts(created_at DESC);

-- JSONB Indexes for faster queries
CREATE INDEX idx_webhook_payload ON webhook_events USING GIN (payload);
CREATE INDEX idx_logs_metadata ON integration_logs USING GIN (metadata);

-- Views for Common Queries

-- View 1: API Health Summary
CREATE OR REPLACE VIEW v_api_health_summary AS
SELECT 
    e.endpoint_id,
    e.name,
    e.customer_name,
    e.environment,
    COUNT(hc.check_id) as total_checks,
    COUNT(CASE WHEN hc.success = TRUE THEN 1 END) as successful_checks,
    COUNT(CASE WHEN hc.success = FALSE THEN 1 END) as failed_checks,
    ROUND(AVG(hc.response_time_ms), 2) as avg_response_time_ms,
    MIN(hc.response_time_ms) as min_response_time_ms,
    MAX(hc.response_time_ms) as max_response_time_ms,
    MAX(hc.checked_at) as last_check_time,
    ROUND(
        100.0 * COUNT(CASE WHEN hc.success = TRUE THEN 1 END) / 
        NULLIF(COUNT(hc.check_id), 0), 
        2
    ) as uptime_percentage
FROM api_endpoints e
LEFT JOIN health_checks hc ON e.endpoint_id = hc.endpoint_id
    AND hc.checked_at >= NOW() - INTERVAL '24 hours'
WHERE e.is_active = TRUE
GROUP BY e.endpoint_id, e.name, e.customer_name, e.environment
ORDER BY uptime_percentage ASC;

-- View 2: Recent Integration Errors
CREATE OR REPLACE VIEW v_recent_errors AS
SELECT 
    e.customer_name,
    e.name as endpoint_name,
    hc.status_code,
    hc.error_type,
    hc.error_message,
    hc.response_time_ms,
    hc.checked_at
FROM health_checks hc
JOIN api_endpoints e ON hc.endpoint_id = e.endpoint_id
WHERE hc.success = FALSE
    AND hc.checked_at >= NOW() - INTERVAL '7 days'
ORDER BY hc.checked_at DESC
LIMIT 100;

-- View 3: Webhook Activity Summary
CREATE OR REPLACE VIEW v_webhook_summary AS
SELECT 
    source,
    COUNT(*) as total_events,
    COUNT(CASE WHEN processed = TRUE THEN 1 END) as processed_events,
    COUNT(CASE WHEN signature_valid = FALSE THEN 1 END) as invalid_signatures,
    MAX(received_at) as last_event_time,
    ROUND(
        100.0 * COUNT(CASE WHEN processed = TRUE THEN 1 END) / 
        NULLIF(COUNT(*), 0), 
        2
    ) as processing_rate
FROM webhook_events
WHERE received_at >= NOW() - INTERVAL '24 hours'
GROUP BY source
ORDER BY total_events DESC;

-- View 4: Customer Integration Health
CREATE OR REPLACE VIEW v_customer_health AS
SELECT 
    ci.customer_name,
    ci.integration_type,
    ci.status,
    ci.error_count,
    ci.last_sync_at,
    COUNT(a.alert_id) as active_alerts,
    COUNT(CASE WHEN a.severity = 'CRITICAL' THEN 1 END) as critical_alerts,
    CASE 
        WHEN ci.status = 'error' OR COUNT(CASE WHEN a.severity = 'CRITICAL' THEN 1 END) > 0 THEN 'red'
        WHEN ci.error_count > 5 OR COUNT(a.alert_id) > 3 THEN 'yellow'
        ELSE 'green'
    END as health_status
FROM customer_integrations ci
LEFT JOIN alerts a ON ci.integration_id = a.integration_id 
    AND a.resolved = FALSE
GROUP BY ci.integration_id, ci.customer_name, ci.integration_type, 
         ci.status, ci.error_count, ci.last_sync_at;

-- View 5: Hourly Performance Trends
CREATE OR REPLACE VIEW v_hourly_trends AS
SELECT 
    e.name as endpoint_name,
    DATE_TRUNC('hour', hc.checked_at) as hour,
    COUNT(*) as checks,
    ROUND(AVG(hc.response_time_ms), 2) as avg_response_time,
    COUNT(CASE WHEN hc.success = TRUE THEN 1 END) as successful,
    COUNT(CASE WHEN hc.success = FALSE THEN 1 END) as failed,
    ROUND(
        100.0 * COUNT(CASE WHEN hc.success = TRUE THEN 1 END) / 
        NULLIF(COUNT(*), 0), 
        2
    ) as success_rate
FROM health_checks hc
JOIN api_endpoints e ON hc.endpoint_id = e.endpoint_id
WHERE hc.checked_at >= NOW() - INTERVAL '48 hours'
GROUP BY e.name, DATE_TRUNC('hour', hc.checked_at)
ORDER BY hour DESC, endpoint_name;

-- Function: Auto-create alert for failed checks
CREATE OR REPLACE FUNCTION create_alert_for_failure()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.success = FALSE AND NEW.error_type IN ('TIMEOUT', 'CONNECTION_ERROR') THEN
        INSERT INTO alerts (
            endpoint_id,
            alert_type,
            severity,
            title,
            description
        ) VALUES (
            NEW.endpoint_id,
            NEW.error_type,
            CASE 
                WHEN NEW.error_type = 'TIMEOUT' THEN 'HIGH'
                WHEN NEW.error_type = 'CONNECTION_ERROR' THEN 'CRITICAL'
                ELSE 'MEDIUM'
            END,
            'API Health Check Failed',
            NEW.error_message
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger: Auto-alert on failures
CREATE TRIGGER trigger_health_check_alert
AFTER INSERT ON health_checks
FOR EACH ROW
EXECUTE FUNCTION create_alert_for_failure();

-- Comments for documentation
COMMENT ON TABLE api_endpoints IS 'Customer API endpoints being monitored';
COMMENT ON TABLE health_checks IS 'Results from API health monitoring checks';
COMMENT ON TABLE webhook_events IS 'Incoming webhook events from integrated services';
COMMENT ON TABLE integration_logs IS 'Application and integration error logs';
COMMENT ON TABLE customer_integrations IS 'Customer integration configurations';
COMMENT ON TABLE alerts IS 'System-generated alerts for integration issues';