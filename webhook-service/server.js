/**
 * Webhook Listener Service
 * Receives and processes incoming webhooks from integrated services
 */

const express = require('express');
const bodyParser = require('body-parser');
const crypto = require('crypto');
const { Pool } = require('pg');
require('dotenv').config({ path: '../backend/.env' });

const app = express();
const PORT = process.env.WEBHOOK_PORT || 3000;

// PostgreSQL connection pool
const pool = new Pool({
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 5432,
    database: process.env.DB_NAME || 'integration_toolkit',
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD
});

// Test database connection
pool.query('SELECT NOW()', (err, res) => {
    if (err) {
        console.error('❌ Database connection failed:', err.message);
    } else {
        console.log('✅ Database connected at:', res.rows[0].now);
    }
});

// Middleware
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// Request logging middleware
app.use((req, res, next) => {
    const timestamp = new Date().toISOString();
    console.log(`[${timestamp}] ${req.method} ${req.path}`);
    next();
});

// ============================================================================
// Webhook Routes
// ============================================================================

/**
 * Health check endpoint
 */
app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        service: 'webhook-listener',
        timestamp: new Date().toISOString(),
        port: PORT
    });
});

/**
 * Generic webhook receiver
 * POST /webhook/:source
 */
app.post('/webhook/:source', async (req, res) => {
    const source = req.params.source;
    const payload = req.body;
    const headers = req.headers;
    const ipAddress = req.ip || req.connection.remoteAddress;
    
    console.log('='.repeat(70));
    console.log(`📥 Webhook received from: ${source}`);
    console.log('='.repeat(70));
    console.log('Headers:', JSON.stringify(headers, null, 2));
    console.log('Payload:', JSON.stringify(payload, null, 2));
    console.log('='.repeat(70));
    
    try {
        // Validate signature if present
        const signature = headers['x-webhook-signature'] || headers['x-hub-signature'];
        let signatureValid = true;
        
        if (signature) {
            signatureValid = validateSignature(signature, payload, source);
            console.log(`🔐 Signature validation: ${signatureValid ? 'VALID ✅' : 'INVALID ❌'}`);
        }
        
        // Determine event type
        const eventType = 
            headers['x-event-type'] || 
            payload.event_type || 
            payload.type || 
            'unknown';
        
        // Store webhook in database
        const query = `
            INSERT INTO webhook_events 
            (source, event_type, payload, headers, signature_valid, ip_address, processed)
            VALUES ($1, $2, $3, $4, $5, $6, $7)
            RETURNING event_id, received_at
        `;
        
        const values = [
            source,
            eventType,
            JSON.stringify(payload),
            JSON.stringify(headers),
            signatureValid,
            ipAddress,
            false
        ];
        
        const result = await pool.query(query, values);
        const eventId = result.rows[0].event_id;
        const receivedAt = result.rows[0].received_at;
        
        console.log(`✅ Webhook stored with ID: ${eventId}`);
        
        // Process webhook asynchronously
        processWebhook(eventId, source, eventType, payload).catch(err => {
            console.error('Error processing webhook:', err);
        });
        
        // Send immediate response
        res.status(200).json({
            success: true,
            message: 'Webhook received',
            event_id: eventId,
            received_at: receivedAt
        });
        
    } catch (error) {
        console.error('❌ Error storing webhook:', error);
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

/**
 * Get webhook events
 */
app.get('/webhooks', async (req, res) => {
    try {
        const limit = req.query.limit || 50;
        const source = req.query.source;
        
        let query = `
            SELECT 
                event_id,
                source,
                event_type,
                signature_valid,
                ip_address,
                received_at,
                processed,
                processed_at
            FROM webhook_events
        `;
        
        const params = [];
        
        if (source) {
            query += ' WHERE source = $1';
            params.push(source);
            query += ` ORDER BY received_at DESC LIMIT $2`;
            params.push(limit);
        } else {
            query += ` ORDER BY received_at DESC LIMIT $1`;
            params.push(limit);
        }
        
        const result = await pool.query(query, params);
        
        res.json({
            success: true,
            count: result.rows.length,
            webhooks: result.rows
        });
        
    } catch (error) {
        console.error('Error fetching webhooks:', error);
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

/**
 * Get webhook event details
 */
app.get('/webhooks/:eventId', async (req, res) => {
    try {
        const eventId = req.params.eventId;
        
        const query = `
            SELECT * FROM webhook_events
            WHERE event_id = $1
        `;
        
        const result = await pool.query(query, [eventId]);
        
        if (result.rows.length === 0) {
            return res.status(404).json({
                success: false,
                error: 'Webhook event not found'
            });
        }
        
        res.json({
            success: true,
            webhook: result.rows[0]
        });
        
    } catch (error) {
        console.error('Error fetching webhook:', error);
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// ============================================================================
// Helper Functions
// ============================================================================

/**
 * Validate webhook signature
 */
function validateSignature(signature, payload, source) {
    // This is a simplified example
    // In production, use the actual signature validation for each service
    
    // Example for GitHub-style signatures:
    // const secret = process.env[`${source.toUpperCase()}_SECRET`];
    // const hash = crypto.createHmac('sha256', secret)
    //     .update(JSON.stringify(payload))
    //     .digest('hex');
    // return signature === `sha256=${hash}`;
    
    // For this demo, we'll just check if signature exists
    return signature && signature.length > 0;
}

/**
 * Process webhook asynchronously
 */
async function processWebhook(eventId, source, eventType, payload) {
    console.log(`🔄 Processing webhook ${eventId} from ${source}...`);
    
    // Simulate processing delay
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    try {
        // Log processing
        await pool.query(`
            INSERT INTO integration_logs 
            (log_level, source, message, metadata, timestamp)
            VALUES ($1, $2, $3, $4, NOW())
        `, [
            'INFO',
            `webhook-${source}`,
            `Processed ${eventType} event`,
            JSON.stringify({ event_id: eventId, payload_size: JSON.stringify(payload).length })
        ]);
        
        // Mark as processed
        await pool.query(`
            UPDATE webhook_events 
            SET processed = TRUE, processed_at = NOW()
            WHERE event_id = $1
        `, [eventId]);
        
        console.log(`✅ Webhook ${eventId} processed successfully`);
        
    } catch (error) {
        console.error(`❌ Error processing webhook ${eventId}:`, error);
        
        // Log error
        await pool.query(`
            INSERT INTO integration_logs 
            (log_level, source, message, error_code, timestamp)
            VALUES ($1, $2, $3, $4, NOW())
        `, [
            'ERROR',
            `webhook-${source}`,
            `Failed to process ${eventType} event: ${error.message}`,
            'WEBHOOK_PROCESSING_ERROR'
        ]);
    }
}

// ============================================================================
// Start Server
// ============================================================================

app.listen(PORT, () => {
    console.log('='.repeat(70));
    console.log('🎯 Webhook Listener Service');
    console.log('='.repeat(70));
    console.log(`✅ Server running on http://localhost:${PORT}`);
    console.log(`📥 Webhook endpoint: http://localhost:${PORT}/webhook/:source`);
    console.log(`🏥 Health check: http://localhost:${PORT}/health`);
    console.log('='.repeat(70));
});

// Graceful shutdown
process.on('SIGINT', async () => {
    console.log('\n📴 Shutting down webhook service...');
    await pool.end();
    console.log('✅ Database pool closed');
    process.exit(0);
});