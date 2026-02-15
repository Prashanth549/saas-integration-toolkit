# API Documentation

Complete reference for the SaaS Integration Toolkit REST API.

## Base URL
```
http://localhost:5000/api
```

## Authentication

Currently, no authentication is required (demo project).

In production, implement:
- API key authentication
- JWT tokens
- OAuth 2.0

---

## Endpoints

### Health Check

Check API service health and database connectivity.

**Endpoint:** `GET /api/health`

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2024-02-14T12:00:00",
  "database": "connected"
}
```

**Status Codes:**
- `200` - Service healthy
- `503` - Service unavailable

---

### API Summary

Get health summary for all monitored endpoints.

**Endpoint:** `GET /api/summary`

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "endpoint_id": 1,
      "name": "Salesforce API",
      "customer_name": "Acme Corp",
      "environment": "production",
      "total_checks": 48,
      "successful_checks": 46,
      "failed_checks": 2,
      "avg_response_time_ms": 145.32,
      "min_response_time_ms": 89.12,
      "max_response_time_ms": 312.45,
      "last_check_time": "2024-02-14T11:45:00",
      "uptime_percentage": 95.83
    }
  ],
  "count": 8,
  "timestamp": "2024-02-14T12:00:00"
}
```

**Status Codes:**
- `200` - Success
- `500` - Server error

---

### Get Endpoints

List all active API endpoints being monitored.

**Endpoint:** `GET /api/endpoints`

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "endpoint_id": 1,
      "name": "Salesforce API",
      "base_url": "https://api.salesforce.com",
      "endpoint_path": "/services/data/v52.0/sobjects/Account",
      "http_method": "GET",
      "expected_status_code": 200,
      "timeout_seconds": 30
    }
  ],
  "count": 8
}
```

---

### Get Endpoint Details

Get detailed information for a specific endpoint.

**Endpoint:** `GET /api/endpoints/:id`

**Parameters:**
- `id` (path) - Endpoint ID

**Example:** `GET /api/endpoints/1`

**Response:**
```json
{
  "success": true,
  "data": {
    "endpoint_id": 1,
    "name": "Salesforce API",
    "base_url": "https://api.salesforce.com",
    "endpoint_path": "/services/data/v52.0/sobjects/Account",
    "total_checks": 48,
    "avg_response_time": 145.32,
    "failed_checks": 2
  }
}
```

**Status Codes:**
- `200` - Success
- `404` - Endpoint not found
- `500` - Server error

---

### Get Recent Errors

Retrieve recent integration errors.

**Endpoint:** `GET /api/errors`

**Query Parameters:**
- `limit` (optional) - Number of errors to return (default: 50)

**Example:** `GET /api/errors?limit=10`

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "customer_name": "Acme Corp",
      "endpoint_name": "Salesforce API",
      "status_code": 503,
      "error_message": "Request timeout after 5000ms",
      "response_time_ms": 5000.00,
      "checked_at": "2024-02-14T10:30:00"
    }
  ],
  "count": 10
}
```

---

### Get Customer Health

Get integration health status for all customers.

**Endpoint:** `GET /api/customers`

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "customer_name": "Acme Corp",
      "integration_type": "salesforce",
      "status": "active",
      "error_count": 0,
      "last_sync_at": "2024-02-14T11:45:00",
      "active_alerts": 0,
      "critical_alerts": 0,
      "health_status": "green"
    }
  ],
  "count": 5
}
```

---

### Get Webhook Summary

Get webhook processing statistics.

**Endpoint:** `GET /api/webhooks`

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "source": "salesforce",
      "total_events": 25,
      "processed_events": 24,
      "invalid_signatures": 1,
      "last_event_time": "2024-02-14T11:30:00",
      "processing_rate": 96.00
    }
  ],
  "count": 3
}
```

---

### Get Alerts

Get system alerts (optionally filtered).

**Endpoint:** `GET /api/alerts`

**Query Parameters:**
- `resolved` (optional) - Filter by resolved status (`true` or `false`)

**Examples:**
- `GET /api/alerts` - All alerts
- `GET /api/alerts?resolved=false` - Only unresolved alerts
- `GET /api/alerts?resolved=true` - Only resolved alerts

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "alert_id": 1,
      "alert_type": "API_DOWN",
      "severity": "CRITICAL",
      "title": "Internal API Unavailable",
      "description": "Health check endpoint returning connection errors",
      "resolved": false,
      "created_at": "2024-02-14T10:00:00"
    }
  ],
  "count": 5
}
```

---

### Get Performance Trends

Get hourly performance metrics.

**Endpoint:** `GET /api/trends`

**Query Parameters:**
- `hours` (optional) - Number of hours to retrieve (default: 24)

**Example:** `GET /api/trends?hours=48`

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "endpoint_name": "Salesforce API",
      "hour": "2024-02-14T11:00:00",
      "checks": 12,
      "avg_response_time": 145.32,
      "successful": 11,
      "failed": 1,
      "success_rate": 91.67
    }
  ],
  "count": 192,
  "hours": 48
}
```

---

## Error Responses

All endpoints may return error responses:

**Format:**
```json
{
  "success": false,
  "error": "Error message description"
}
```

**Common Status Codes:**
- `400` - Bad Request
- `404` - Not Found
- `500` - Internal Server Error
- `503` - Service Unavailable

---

## Webhook Service API

### Receive Webhook

**Endpoint:** `POST http://localhost:3000/webhook/:source`

**Parameters:**
- `source` (path) - Integration source name (e.g., `salesforce`, `stripe`)

**Headers:**
- `Content-Type: application/json`
- `X-Webhook-Signature` (optional) - Webhook signature for validation

**Example:**
```bash
curl -X POST http://localhost:3000/webhook/salesforce \
  -H "Content-Type: application/json" \
  -H "X-Event-Type: contact.created" \
  -d '{"id": "12345", "name": "John Doe", "email": "john@example.com"}'
```

**Response:**
```json
{
  "success": true,
  "message": "Webhook received",
  "event_id": 6,
  "received_at": "2024-02-14T12:00:00"
}
```

---

### List Webhook Events

**Endpoint:** `GET http://localhost:3000/webhooks`

**Query Parameters:**
- `limit` (optional) - Number of events (default: 50)
- `source` (optional) - Filter by source

**Example:** `GET http://localhost:3000/webhooks?source=salesforce&limit=10`

**Response:**
```json
{
  "success": true,
  "count": 10,
  "webhooks": [
    {
      "event_id": 6,
      "source": "salesforce",
      "event_type": "contact.created",
      "signature_valid": true,
      "ip_address": "52.89.214.238",
      "received_at": "2024-02-14T12:00:00",
      "processed": true,
      "processed_at": "2024-02-14T12:00:01"
    }
  ]
}
```

---

## Rate Limiting

Currently no rate limiting (demo project).

**Recommended for production:**
- 100 requests per minute per IP
- 1000 requests per hour per API key
- Webhook burst limit: 10 per second

---

## Versioning

Current version: `v1`

Future versions will be prefixed: `/api/v2/...`

---

## Support

For questions or issues, contact: [your-email@example.com]