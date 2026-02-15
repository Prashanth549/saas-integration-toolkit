"""
API Health Monitoring Script
Continuously monitors API endpoints and records results
"""
import requests
import time
import logging
from datetime import datetime
from database import Database
from config import Config

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class APIMonitor:
    """Monitors API endpoint health"""
    
    def __init__(self):
        self.db = Database()
        self.timeout = Config.REQUEST_TIMEOUT
    
    def check_endpoint(self, endpoint):
        """
        Check a single API endpoint
        
        Args:
            endpoint: Dictionary with endpoint details
        
        Returns:
            Dictionary with check results
        """
        endpoint_id = endpoint['endpoint_id']
        name = endpoint['name']
        url = endpoint['base_url'] + endpoint['endpoint_path']
        method = endpoint['http_method']
        expected_status = endpoint['expected_status_code']
        
        logger.info(f"Checking {name}...")
        
        try:
            start_time = time.time()
            
            # Make HTTP request
            if method == 'GET':
                response = requests.get(url, timeout=self.timeout)
            elif method == 'POST':
                response = requests.post(url, timeout=self.timeout)
            else:
                response = requests.request(method, url, timeout=self.timeout)
            
            end_time = time.time()
            response_time_ms = (end_time - start_time) * 1000
            
            # Determine success
            success = response.status_code == expected_status
            error_type = None
            error_message = None
            
            if not success:
                if response.status_code >= 500:
                    error_type = 'SERVER_ERROR'
                elif response.status_code == 404:
                    error_type = 'NOT_FOUND'
                elif response.status_code == 401 or response.status_code == 403:
                    error_type = 'AUTH_ERROR'
                elif response.status_code == 429:
                    error_type = 'RATE_LIMIT'
                else:
                    error_type = 'INVALID_RESPONSE'
                
                error_message = f"Expected {expected_status}, got {response.status_code}"
            
            # Log result
            self.db.insert_health_check(
                endpoint_id=endpoint_id,
                status_code=response.status_code,
                response_time_ms=round(response_time_ms, 2),
                success=success,
                error_type=error_type,
                error_message=error_message
            )
            
            status_icon = "✓" if success else "✗"
            logger.info(
                f"{status_icon} {name}: {response.status_code} "
                f"({response_time_ms:.2f}ms)"
            )
            
            return {
                'endpoint_id': endpoint_id,
                'name': name,
                'success': success,
                'status_code': response.status_code,
                'response_time_ms': response_time_ms
            }
        
        except requests.exceptions.Timeout:
            logger.error(f"✗ {name}: TIMEOUT")
            self.db.insert_health_check(
                endpoint_id=endpoint_id,
                status_code=None,
                response_time_ms=self.timeout * 1000,
                success=False,
                error_type='TIMEOUT',
                error_message=f'Request timeout after {self.timeout}s'
            )
            return {
                'endpoint_id': endpoint_id,
                'name': name,
                'success': False,
                'error': 'TIMEOUT'
            }
        
        except requests.exceptions.ConnectionError as e:
            logger.error(f"✗ {name}: CONNECTION_ERROR")
            self.db.insert_health_check(
                endpoint_id=endpoint_id,
                status_code=None,
                response_time_ms=None,
                success=False,
                error_type='CONNECTION_ERROR',
                error_message=str(e)
            )
            return {
                'endpoint_id': endpoint_id,
                'name': name,
                'success': False,
                'error': 'CONNECTION_ERROR'
            }
        
        except Exception as e:
            logger.error(f"✗ {name}: ERROR - {e}")
            self.db.insert_health_check(
                endpoint_id=endpoint_id,
                status_code=None,
                response_time_ms=None,
                success=False,
                error_type='UNKNOWN_ERROR',
                error_message=str(e)
            )
            return {
                'endpoint_id': endpoint_id,
                'name': name,
                'success': False,
                'error': str(e)
            }
    
    def run_check_cycle(self):
        """Run one complete check cycle for all endpoints"""
        logger.info("=" * 70)
        logger.info(f"Starting health check cycle at {datetime.now()}")
        logger.info("=" * 70)
        
        endpoints = self.db.get_active_endpoints()
        logger.info(f"Found {len(endpoints)} active endpoints to monitor")
        
        results = []
        for endpoint in endpoints:
            result = self.check_endpoint(endpoint)
            results.append(result)
            time.sleep(1)  # Small delay between checks
        
        # Summary
        successful = sum(1 for r in results if r.get('success', False))
        failed = len(results) - successful
        
        logger.info("=" * 70)
        logger.info(f"Check cycle complete: {successful} successful, {failed} failed")
        logger.info("=" * 70)
        
        return results
    
    def run_continuous(self, interval_seconds=None):
        """
        Run continuous monitoring
        
        Args:
            interval_seconds: Seconds between checks (default from config)
        """
        if interval_seconds is None:
            interval_seconds = Config.CHECK_INTERVAL_SECONDS
        
        logger.info("Starting continuous monitoring...")
        logger.info(f"Check interval: {interval_seconds} seconds")
        logger.info("Press Ctrl+C to stop")
        logger.info("")
        
        try:
            while True:
                self.run_check_cycle()
                logger.info(f"Sleeping for {interval_seconds} seconds...")
                logger.info("")
                time.sleep(interval_seconds)
        
        except KeyboardInterrupt:
            logger.info("\nMonitoring stopped by user")

def main():
    """Main execution"""
    monitor = APIMonitor()
    
    # Run a single check cycle
    # To run continuously, use: monitor.run_continuous()
    monitor.run_check_cycle()

if __name__ == "__main__":
    main()