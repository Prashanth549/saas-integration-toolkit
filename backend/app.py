"""
Flask REST API for SaaS Integration Toolkit
Provides endpoints for integration health monitoring and reporting
"""
from flask import Flask, jsonify, request
from flask_cors import CORS
from database import Database
from config import Config
import logging
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize Flask app
app = Flask(__name__)
CORS(app, resources={r"/api/*": {"origins": "*"}})
  # Enable CORS for frontend access

# Initialize database
db = Database()

# ============================================================================
# API Routes
# ============================================================================

@app.route('/')
def home():
    """API home page"""
    return jsonify({
        'name': 'SaaS Integration Health API',
        'version': '1.0.0',
        'status': 'running',
        'endpoints': {
            'health': '/api/health',
            'summary': '/api/summary',
            'endpoints': '/api/endpoints',
            'errors': '/api/errors',
            'customers': '/api/customers',
            'webhooks': '/api/webhooks',
            'alerts': '/api/alerts',
            'trends': '/api/trends'
        }
    })

@app.route('/api/health')
def api_health():
    """API health check endpoint"""
    try:
        # Test database connection
        db.connect()
        db.disconnect()
        
        return jsonify({
            'status': 'healthy',
            'timestamp': datetime.now().isoformat(),
            'database': 'connected'
        })
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return jsonify({
            'status': 'unhealthy',
            'timestamp': datetime.now().isoformat(),
            'database': 'disconnected',
            'error': str(e)
        }), 503

@app.route('/api/summary')
def get_summary():
    """Get API health summary"""
    try:
        summary = db.get_api_health_summary()
        return jsonify({
            'success': True,
            'data': summary,
            'count': len(summary),
            'timestamp': datetime.now().isoformat()
        })
    except Exception as e:
        logger.error(f"Error fetching summary: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/endpoints')
def get_endpoints():
    """Get all active endpoints"""
    try:
        endpoints = db.get_active_endpoints()
        return jsonify({
            'success': True,
            'data': endpoints,
            'count': len(endpoints)
        })
    except Exception as e:
        logger.error(f"Error fetching endpoints: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/endpoints/<int:endpoint_id>')
def get_endpoint_details(endpoint_id):
    """Get details for a specific endpoint"""
    try:
        endpoint = db.get_endpoint_details(endpoint_id)
        
        if endpoint:
            return jsonify({
                'success': True,
                'data': endpoint
            })
        else:
            return jsonify({
                'success': False,
                'error': 'Endpoint not found'
            }), 404
    
    except Exception as e:
        logger.error(f"Error fetching endpoint {endpoint_id}: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/errors')
def get_errors():
    """Get recent integration errors"""
    try:
        limit = request.args.get('limit', 50, type=int)
        errors = db.get_recent_errors(limit)
        
        return jsonify({
            'success': True,
            'data': errors,
            'count': len(errors)
        })
    except Exception as e:
        logger.error(f"Error fetching errors: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/customers')
def get_customers():
    """Get customer integration health"""
    try:
        customers = db.get_customer_health()
        return jsonify({
            'success': True,
            'data': customers,
            'count': len(customers)
        })
    except Exception as e:
        logger.error(f"Error fetching customers: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/webhooks')
def get_webhooks():
    """Get webhook processing summary"""
    try:
        webhooks = db.get_webhook_summary()
        return jsonify({
            'success': True,
            'data': webhooks,
            'count': len(webhooks)
        })
    except Exception as e:
        logger.error(f"Error fetching webhooks: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/alerts')
def get_alerts():
    """Get alerts (optionally filtered)"""
    try:
        resolved_param = request.args.get('resolved')
        
        if resolved_param is not None:
            resolved = resolved_param.lower() == 'true'
            alerts = db.get_alerts(resolved=resolved)
        else:
            alerts = db.get_alerts()
        
        return jsonify({
            'success': True,
            'data': alerts,
            'count': len(alerts)
        })
    except Exception as e:
        logger.error(f"Error fetching alerts: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/trends')
def get_trends():
    """Get hourly performance trends"""
    try:
        hours = request.args.get('hours', 24, type=int)
        trends = db.get_hourly_trends(hours)
        
        return jsonify({
            'success': True,
            'data': trends,
            'count': len(trends),
            'hours': hours
        })
    except Exception as e:
        logger.error(f"Error fetching trends: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

# ============================================================================
# Error Handlers
# ============================================================================

@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors"""
    return jsonify({
        'success': False,
        'error': 'Endpoint not found'
    }), 404

@app.errorhandler(500)
def internal_error(error):
    """Handle 500 errors"""
    logger.error(f"Internal server error: {error}")
    return jsonify({
        'success': False,
        'error': 'Internal server error'
    }), 500

# ============================================================================
# Run Application
# ============================================================================

if __name__ == '__main__':
    logger.info("=" * 70)
    logger.info("SaaS Integration Health API")
    logger.info("=" * 70)
    logger.info(f"Starting server on {Config.API_HOST}:{Config.API_PORT}")
    logger.info(f"Debug mode: {Config.DEBUG}")
    logger.info("=" * 70)
    
    app.run(
        host=Config.API_HOST,
        port=Config.API_PORT,
        debug=Config.DEBUG
    )