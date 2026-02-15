"""
Database connection and query utilities
"""
import psycopg2
from psycopg2.extras import RealDictCursor
from config import Config
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class Database:
    """PostgreSQL database connection manager"""
    
    def __init__(self):
        self.connection_string = Config.get_db_connection_string()
        self.conn = None
    
    def connect(self):
        """Establish database connection"""
        try:
            self.conn = psycopg2.connect(self.connection_string)
            logger.info("✓ Database connection established")
            return self.conn
        except Exception as e:
            logger.error(f"✗ Database connection failed: {e}")
            raise
    
    def disconnect(self):
        """Close database connection"""
        if self.conn:
            self.conn.close()
            logger.info("Database connection closed")
    
    def execute_query(self, query, params=None, fetch=True):
        """
        Execute a SQL query and return results
        
        Args:
            query: SQL query string
            params: Query parameters (optional)
            fetch: Whether to fetch results (default True)
        
        Returns:
            Query results as list of dictionaries
        """
        try:
            with psycopg2.connect(self.connection_string) as conn:
                with conn.cursor(cursor_factory=RealDictCursor) as cursor:
                    cursor.execute(query, params)
                    
                    if fetch:
                        results = cursor.fetchall()
                        # Convert to list of dicts
                        return [dict(row) for row in results]
                    else:
                        conn.commit()
                        return {"success": True, "rowcount": cursor.rowcount}
        
        except Exception as e:
            logger.error(f"Query execution error: {e}")
            raise
    
    def get_api_health_summary(self):
        """Get API health summary from view"""
        query = "SELECT * FROM v_api_health_summary ORDER BY uptime_percentage ASC"
        return self.execute_query(query)
    
    def get_recent_errors(self, limit=50):
        """Get recent integration errors"""
        query = "SELECT * FROM v_recent_errors LIMIT %s"
        return self.execute_query(query, (limit,))
    
    def get_customer_health(self):
        """Get customer integration health status"""
        query = "SELECT * FROM v_customer_health ORDER BY health_status DESC"
        return self.execute_query(query)
    
    def get_webhook_summary(self):
        """Get webhook processing summary"""
        query = "SELECT * FROM v_webhook_summary"
        return self.execute_query(query)
    
    def get_endpoint_details(self, endpoint_id):
        """Get details for a specific endpoint"""
        query = """
            SELECT 
                e.*,
                COUNT(hc.check_id) as total_checks,
                AVG(hc.response_time_ms) as avg_response_time,
                COUNT(CASE WHEN hc.success = FALSE THEN 1 END) as failed_checks
            FROM api_endpoints e
            LEFT JOIN health_checks hc ON e.endpoint_id = hc.endpoint_id
                AND hc.checked_at >= NOW() - INTERVAL '24 hours'
            WHERE e.endpoint_id = %s
            GROUP BY e.endpoint_id
        """
        result = self.execute_query(query, (endpoint_id,))
        return result[0] if result else None
    
    def insert_health_check(self, endpoint_id, status_code, response_time_ms, 
                           success, error_type=None, error_message=None):
        """Insert a new health check record"""
        query = """
            INSERT INTO health_checks 
            (endpoint_id, status_code, response_time_ms, success, error_type, error_message)
            VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING check_id
        """
        params = (endpoint_id, status_code, response_time_ms, success, error_type, error_message)
        result = self.execute_query(query, params)
        return result[0] if result else None
    
    def get_active_endpoints(self):
        """Get all active API endpoints for monitoring"""
        query = """
            SELECT endpoint_id, name, base_url, endpoint_path, 
                   http_method, expected_status_code, timeout_seconds
            FROM api_endpoints
            WHERE is_active = TRUE
            ORDER BY name
        """
        return self.execute_query(query)
    
    def get_hourly_trends(self, hours=24):
        """Get hourly performance trends"""
        query = """
            SELECT * FROM v_hourly_trends
            WHERE hour >= NOW() - INTERVAL '%s hours'
            ORDER BY hour DESC, endpoint_name
        """
        return self.execute_query(query, (hours,))
    
    def get_alerts(self, resolved=None):
        """
        Get alerts, optionally filtered by resolved status
        
        Args:
            resolved: None (all), True (resolved only), False (unresolved only)
        """
        if resolved is None:
            query = "SELECT * FROM alerts ORDER BY created_at DESC LIMIT 100"
            params = None
        else:
            query = "SELECT * FROM alerts WHERE resolved = %s ORDER BY created_at DESC LIMIT 100"
            params = (resolved,)
        
        return self.execute_query(query, params)

# Test connection
if __name__ == "__main__":
    db = Database()
    try:
        db.connect()
        print("\n✓ Connection test successful!")
        
        # Test a simple query
        summary = db.get_api_health_summary()
        print(f"\n✓ Found {len(summary)} endpoints")
        
        for endpoint in summary[:3]:
            print(f"  - {endpoint['name']}: {endpoint['uptime_percentage']}% uptime")
        
        db.disconnect()
    except Exception as e:
        print(f"\n✗ Connection test failed: {e}")