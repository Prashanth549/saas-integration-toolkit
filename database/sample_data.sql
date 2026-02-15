-- Sample Data for SaaS Integration Toolkit
-- Realistic customer integration scenarios

-- Insert API Endpoints
INSERT INTO api_endpoints (name, base_url, endpoint_path, http_method, customer_name, environment) VALUES
('Salesforce API', 'https://api.salesforce.com', '/services/data/v52.0/sobjects/Account', 'GET', 'Acme Corp', 'production'),
('HubSpot Contacts', 'https://api.hubapi.com', '/crm/v3/objects/contacts', 'GET', 'TechStart Inc', 'production'),
('Stripe Payments', 'https://api.stripe.com', '/v1/charges', 'GET', 'Acme Corp', 'production'),
('Custom Webhook Endpoint', 'https://webhook.site', '/unique-id-123', 'POST', 'Beta Solutions', 'staging'),
('Zendesk Tickets', 'https://example.zendesk.com', '/api/v2/tickets.json', 'GET', 'Support Plus', 'production'),
('Slack Notifications', 'https://hooks.slack.com', '/services/T00/B00/XXX', 'POST', 'DevOps Team', 'production'),
('Google Analytics', 'https://analyticsreporting.googleapis.com', '/v4/reports:batchGet', 'POST', 'Marketing Co', 'production'),
('Internal API', 'http://localhost:5000', '/api/health', 'GET', 'Internal', 'dev');

-- Insert Health Check Results (Mix of success and failures)
-- Last 24 hours of checks

-- Successful checks
INSERT INTO health_checks (endpoint_id, status_code, response_time_ms, success, checked_at) VALUES
(1, 200, 145.5, TRUE, NOW() - INTERVAL '10 minutes'),
(1, 200, 152.3, TRUE, NOW() - INTERVAL '20 minutes'),
(1, 200, 138.7, TRUE, NOW() - INTERVAL '30 minutes'),
(2, 200, 89.2, TRUE, NOW() - INTERVAL '15 minutes'),
(2, 200, 95.1, TRUE, NOW() - INTERVAL '25 minutes'),
(3, 200, 210.4, TRUE, NOW() - INTERVAL '12 minutes'),
(3, 200, 198.9, TRUE, NOW() - INTERVAL '22 minutes'),
(5, 200, 175.6, TRUE, NOW() - INTERVAL '18 minutes'),
(6, 200, 56.3, TRUE, NOW() - INTERVAL '14 minutes'),
(7, 200, 312.1, TRUE, NOW() - INTERVAL '16 minutes');

-- Failed checks
INSERT INTO health_checks (endpoint_id, status_code, response_time_ms, success, error_type, error_message, checked_at) VALUES
(1, 503, 5000.0, FALSE, 'TIMEOUT', 'Request timeout after 5000ms', NOW() - INTERVAL '2 hours'),
(4, 404, 102.3, FALSE, 'INVALID_RESPONSE', 'Endpoint not found', NOW() - INTERVAL '1 hour'),
(4, 500, 234.5, FALSE, 'SERVER_ERROR', 'Internal server error', NOW() - INTERVAL '45 minutes'),
(8, NULL, NULL, FALSE, 'CONNECTION_ERROR', 'Failed to establish connection', NOW() - INTERVAL '30 minutes'),
(3, 401, 87.6, FALSE, 'AUTH_ERROR', 'Invalid API key', NOW() - INTERVAL '3 hours'),
(5, 429, 45.2, FALSE, 'RATE_LIMIT', 'Rate limit exceeded', NOW() - INTERVAL '90 minutes');

-- More historical data (last 7 days)
INSERT INTO health_checks (endpoint_id, status_code, response_time_ms, success, checked_at)
SELECT 
    (RANDOM() * 7 + 1)::INT as endpoint_id,
    200 as status_code,
    (RANDOM() * 300 + 50)::DECIMAL(10,2) as response_time_ms,
    TRUE as success,
    NOW() - (RANDOM() * INTERVAL '7 days') as checked_at
FROM generate_series(1, 200);

-- Add some failures in historical data
INSERT INTO health_checks (endpoint_id, status_code, response_time_ms, success, error_type, error_message, checked_at)
SELECT 
    (RANDOM() * 7 + 1)::INT as endpoint_id,
    (ARRAY[500, 503, 404, 429])[floor(RANDOM() * 4 + 1)] as status_code,
    (RANDOM() * 1000)::DECIMAL(10,2) as response_time_ms,
    FALSE as success,
    (ARRAY['TIMEOUT', 'SERVER_ERROR', 'CONNECTION_ERROR'])[floor(RANDOM() * 3 + 1)] as error_type,
    'Random test error' as error_message,
    NOW() - (RANDOM() * INTERVAL '7 days') as checked_at
FROM generate_series(1, 30);

-- Insert Webhook Events
INSERT INTO webhook_events (source, event_type, payload, signature_valid, ip_address, processed, received_at) VALUES
('salesforce', 'account.updated', 
 '{"id": "0015000000ABC123", "name": "Acme Corp", "status": "active"}'::jsonb,
 TRUE, '52.89.214.238', TRUE, NOW() - INTERVAL '5 minutes'),
 
('stripe', 'payment.succeeded',
 '{"id": "ch_3KJq8N2eZvKYlo2C0Ox4t5Nn", "amount": 5000, "currency": "usd"}'::jsonb,
 TRUE, '54.187.205.235', TRUE, NOW() - INTERVAL '15 minutes'),
 
('hubspot', 'contact.created',
 '{"vid": 12345, "email": "new@customer.com", "firstname": "John"}'::jsonb,
 TRUE, '54.145.63.24', TRUE, NOW() - INTERVAL '30 minutes'),
 
('custom', 'data.sync',
 '{"records": 150, "status": "completed", "timestamp": "2024-02-14T10:30:00Z"}'::jsonb,
 FALSE, '203.0.113.42', FALSE, NOW() - INTERVAL '2 hours'),
 
('slack', 'message.sent',
 '{"channel": "alerts", "text": "Integration health check failed", "user": "system"}'::jsonb,
 TRUE, '54.88.247.93', TRUE, NOW() - INTERVAL '1 hour');

-- Insert Integration Logs
INSERT INTO integration_logs (log_level, source, message, error_code, timestamp) VALUES
('INFO', 'salesforce-sync', 'Successfully synced 150 accounts', NULL, NOW() - INTERVAL '10 minutes'),
('INFO', 'stripe-webhook', 'Payment webhook processed successfully', NULL, NOW() - INTERVAL '15 minutes'),
('WARNING', 'hubspot-api', 'API rate limit approaching (80% used)', 'RATE_LIMIT_WARNING', NOW() - INTERVAL '25 minutes'),
('ERROR', 'custom-integration', 'Failed to process webhook payload', 'PARSE_ERROR', NOW() - INTERVAL '2 hours'),
('CRITICAL', 'api-monitor', 'Endpoint unavailable for 5 consecutive checks', 'ENDPOINT_DOWN', NOW() - INTERVAL '30 minutes'),
('INFO', 'zendesk-sync', 'Fetched 45 new tickets', NULL, NOW() - INTERVAL '20 minutes'),
('ERROR', 'salesforce-api', 'Authentication token expired', 'AUTH_TOKEN_EXPIRED', NOW() - INTERVAL '3 hours'),
('WARNING', 'webhook-receiver', 'Invalid signature detected', 'INVALID_SIGNATURE', NOW() - INTERVAL '2 hours'),
('INFO', 'slack-notify', 'Alert sent to #engineering channel', NULL, NOW() - INTERVAL '1 hour'),
('DEBUG', 'health-checker', 'Starting health check cycle', NULL, NOW() - INTERVAL '5 minutes');

-- Insert Customer Integrations
INSERT INTO customer_integrations (customer_name, integration_type, status, config, last_sync_at, error_count) VALUES
('Acme Corp', 'salesforce', 'active', 
 '{"api_version": "v52.0", "objects": ["Account", "Contact", "Opportunity"]}'::jsonb,
 NOW() - INTERVAL '10 minutes', 0),
 
('TechStart Inc', 'hubspot', 'active',
 '{"sync_frequency": "hourly", "objects": ["contacts", "companies"]}'::jsonb,
 NOW() - INTERVAL '15 minutes', 2),
 
('Beta Solutions', 'webhook', 'error',
 '{"endpoint": "https://webhook.site/unique-id-123", "retry_count": 3}'::jsonb,
 NOW() - INTERVAL '2 hours', 5),
 
('Support Plus', 'zendesk', 'active',
 '{"sync_tickets": true, "sync_users": false}'::jsonb,
 NOW() - INTERVAL '20 minutes', 0),
 
('Marketing Co', 'google_analytics', 'active',
 '{"view_id": "12345678", "metrics": ["sessions", "pageviews"]}'::jsonb,
 NOW() - INTERVAL '30 minutes', 1);

-- Insert Alerts (mix of resolved and unresolved)
INSERT INTO alerts (endpoint_id, integration_id, alert_type, severity, title, description, resolved, resolved_at, created_at) VALUES
(1, 1, 'SLOW_RESPONSE', 'MEDIUM', 'Salesforce API Slow', 
 'Average response time exceeded 1000ms for 3 consecutive checks', 
 TRUE, NOW() - INTERVAL '1 hour', NOW() - INTERVAL '3 hours'),
 
(4, 3, 'WEBHOOK_FAILURE', 'HIGH', 'Webhook Endpoint Unreachable',
 'Failed to deliver webhook to Beta Solutions endpoint',
 FALSE, NULL, NOW() - INTERVAL '2 hours'),
 
(8, NULL, 'API_DOWN', 'CRITICAL', 'Internal API Unavailable',
 'Health check endpoint returning connection errors',
 FALSE, NULL, NOW() - INTERVAL '30 minutes'),
 
(3, 1, 'AUTH_ERROR', 'HIGH', 'Stripe Authentication Failed',
 'API key appears to be invalid or expired',
 TRUE, NOW() - INTERVAL '30 minutes', NOW() - INTERVAL '3 hours'),
 
(5, 4, 'RATE_LIMIT', 'MEDIUM', 'Zendesk Rate Limit Reached',
 'API rate limit exceeded, requests being throttled',
 TRUE, NOW() - INTERVAL '15 minutes', NOW() - INTERVAL '90 minutes');

-- Verify data loaded
SELECT 'API Endpoints:', COUNT(*) FROM api_endpoints
UNION ALL
SELECT 'Health Checks:', COUNT(*) FROM health_checks
UNION ALL
SELECT 'Webhook Events:', COUNT(*) FROM webhook_events
UNION ALL
SELECT 'Integration Logs:', COUNT(*) FROM integration_logs
UNION ALL
SELECT 'Customer Integrations:', COUNT(*) FROM customer_integrations
UNION ALL
SELECT 'Alerts:', COUNT(*) FROM alerts;