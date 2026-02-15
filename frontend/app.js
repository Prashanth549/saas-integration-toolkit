/**
 * SaaS Integration Health Dashboard - JavaScript
 * Fetches data from Flask API and updates UI
 */

// Configuration
const CONFIG = {
    API_BASE_URL: 'http://localhost:5000/api',
    REFRESH_INTERVAL: 30000, // 30 seconds
    AUTO_REFRESH: true
};

// State
let refreshInterval = null;

// ============================================================================
// API Functions
// ============================================================================

/**
 * Fetch data from API endpoint
 */
async function fetchAPI(endpoint) {
    try {
        const response = await fetch(`${CONFIG.API_BASE_URL}${endpoint}`);
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        const data = await response.json();
        return data;
    } catch (error) {
        console.error(`API Error (${endpoint}):`, error);
        updateAPIStatus(false, error.message);
        throw error;
    }
}

/**
 * Check API health
 */
async function checkAPIHealth() {
    try {
        const data = await fetchAPI('/health');
        updateAPIStatus(true);
        return data.status === 'healthy';
    } catch (error) {
        updateAPIStatus(false);
        return false;
    }
}

// ============================================================================
// UI Update Functions
// ============================================================================

/**
 * Update API status indicator
 */
function updateAPIStatus(healthy, message = '') {
    const statusDot = document.getElementById('statusDot');
    const statusText = document.getElementById('statusText');
    
    if (healthy) {
        statusDot.classList.remove('error');
        statusText.textContent = 'API Connected';
    } else {
        statusDot.classList.add('error');
        statusText.textContent = message || 'API Disconnected';
    }
}

/**
 * Update last updated timestamp
 */
function updateTimestamp() {
    const now = new Date();
    const timeString = now.toLocaleTimeString();
    document.getElementById('lastUpdated').textContent = `Updated: ${timeString}`;
}

/**
 * Update countdown timer
 */
let countdownSeconds = CONFIG.REFRESH_INTERVAL / 1000;
function updateCountdown() {
    const lastUpdatedElement = document.getElementById('lastUpdated');
    countdownSeconds--;
    
    if (countdownSeconds <= 0) {
        countdownSeconds = CONFIG.REFRESH_INTERVAL / 1000;
    }
    
    const now = new Date();
    const timeString = now.toLocaleTimeString();
    lastUpdatedElement.textContent = `Updated: ${timeString} (Next: ${countdownSeconds}s)`;
}

// Start countdown
setInterval(updateCountdown, 1000);

/**
 * Update summary metrics
 */
async function updateSummary() {
    try {
        const data = await fetchAPI('/summary');
        const endpoints = data.data;
        
        // Calculate metrics
        const total = endpoints.length;
        const healthy = endpoints.filter(e => e.uptime_percentage >= 95).length;
        const warning = endpoints.filter(e => e.uptime_percentage >= 80 && e.uptime_percentage < 95).length;
        const critical = endpoints.filter(e => e.uptime_percentage < 80).length;
        
        // Update UI
        document.getElementById('totalEndpoints').textContent = total;
        document.getElementById('healthyEndpoints').textContent = healthy;
        document.getElementById('warningEndpoints').textContent = warning;
        document.getElementById('criticalEndpoints').textContent = critical;
        
    } catch (error) {
        console.error('Failed to update summary:', error);
    }
}

/**
 * Update API health table
 */
/**
 * Update API health table
 */
async function updateHealthTable() {
    try {
        const data = await fetchAPI('/summary');
        const endpoints = data.data;
        const tbody = document.getElementById('healthTableBody');
        
        if (endpoints.length === 0) {
            tbody.innerHTML = `
                <tr>
                    <td colspan="6" class="empty-state">
                        <div class="empty-state-icon">📭</div>
                        <p>No endpoints found</p>
                    </td>
                </tr>
            `;
            return;
        }
        
        tbody.innerHTML = endpoints.map(endpoint => {
            // Fix: Convert to number and handle null/undefined
            const uptime = parseFloat(endpoint.uptime_percentage) || 0;
            const statusClass = uptime >= 95 ? 'healthy' : uptime >= 80 ? 'warning' : 'critical';
            const statusIcon = uptime >= 95 ? '✅' : uptime >= 80 ? '⚠️' : '❌';
            
            const lastCheck = endpoint.last_check_time 
                ? new Date(endpoint.last_check_time).toLocaleString()
                : 'Never';
            
            // Fix: Handle null response time
            const avgResponse = endpoint.avg_response_time_ms 
                ? `${Math.round(parseFloat(endpoint.avg_response_time_ms))}ms`
                : 'N/A';
            
            return `
                <tr>
                    <td>
                        <span class="status-badge ${statusClass}">
                            ${statusIcon} ${statusClass.charAt(0).toUpperCase() + statusClass.slice(1)}
                        </span>
                    </td>
                    <td><strong>${endpoint.name}</strong></td>
                    <td>${endpoint.customer_name || 'Internal'}</td>
                    <td>
                        <div class="uptime-bar">
                            <div class="uptime-progress">
                                <div class="uptime-fill ${statusClass}" style="width: ${uptime}%"></div>
                            </div>
                            <span class="uptime-text">${uptime.toFixed(1)}%</span>
                        </div>
                    </td>
                    <td>${avgResponse}</td>
                    <td>${lastCheck}</td>
                </tr>
            `;
        }).join('');
        
    } catch (error) {
        console.error('Failed to update health table:', error);
        document.getElementById('healthTableBody').innerHTML = `
            <tr>
                <td colspan="6" class="empty-state">
                    <p>❌ Failed to load data</p>
                </td>
            </tr>
        `;
    }
}

/**
 * Update customer health cards
 */
async function updateCustomerHealth() {
    try {
        const data = await fetchAPI('/customers');
        const customers = data.data;
        const grid = document.getElementById('customerGrid');
        
        if (customers.length === 0) {
            grid.innerHTML = `
                <div class="customer-card">
                    <div class="empty-state">
                        <div class="empty-state-icon">👥</div>
                        <p>No customer integrations found</p>
                    </div>
                </div>
            `;
            return;
        }
        
      grid.innerHTML = customers.map(customer => {
    const healthColor = customer.health_status || 'green';
    const statusIcon = healthColor === 'green' ? '✅' : healthColor === 'yellow' ? '⚠️' : '❌';
    
    const lastSync = customer.last_sync_at 
        ? new Date(customer.last_sync_at).toLocaleString()
        : 'Never';
    
    // Fix: Use correct field name from database
    const integrationStatus = customer.status || 'unknown';
    const errorCount = customer.error_count || 0;
    const activeAlerts = customer.active_alerts || 0;
    
    return `
        <div class="customer-card ${healthColor}">
            <div class="customer-name">${statusIcon} ${customer.customer_name}</div>
            <div class="customer-info">
                <div><strong>Type:</strong> ${customer.integration_type}</div>
                <div><strong>Status:</strong> ${integrationStatus}</div>
                <div><strong>Errors:</strong> ${errorCount}</div>
                <div><strong>Active Alerts:</strong> ${activeAlerts}</div>
                <div><strong>Last Sync:</strong> ${lastSync}</div>
            </div>
        </div>
    `;
}).join('');


        
    } catch (error) {
        console.error('Failed to update customer health:', error);
    }
}

/**
 * Update recent errors list
 */
async function updateRecentErrors() {
    try {
        const data = await fetchAPI('/errors?limit=10');
        const errors = data.data;
        const list = document.getElementById('errorList');
        
        if (errors.length === 0) {
            list.innerHTML = `
                <div class="empty-state">
                    <div class="empty-state-icon">✨</div>
                    <p>No recent errors - all integrations running smoothly!</p>
                </div>
            `;
            return;
        }
        
        list.innerHTML = errors.map(error => {
            const timestamp = new Date(error.checked_at).toLocaleString();
            
            return `
                <div class="error-item">
                    <div class="error-header">
                        <div>
                            <span class="error-code">${error.status_code || 'N/A'}</span>
                            <span class="error-endpoint">${error.endpoint_name}</span>
                        </div>
                        <span class="error-time">${timestamp}</span>
                    </div>
                    <div class="error-message">
                        <strong>${error.customer_name}:</strong> ${error.error_message || 'Unknown error'}
                    </div>
                </div>
            `;
        }).join('');
        
    } catch (error) {
        console.error('Failed to update errors:', error);
    }
}

/**
 * Update alerts list
 */
async function updateAlerts() {
    try {
        const data = await fetchAPI('/alerts?resolved=false');
        const alerts = data.data;
        const list = document.getElementById('alertList');
        
        if (alerts.length === 0) {
            list.innerHTML = `
                <div class="empty-state">
                    <div class="empty-state-icon">🎉</div>
                    <p>No active alerts!</p>
                </div>
            `;
            return;
        }
        
        list.innerHTML = alerts.map(alert => {
            const timestamp = new Date(alert.created_at).toLocaleString();
            const severity = alert.severity.toLowerCase();
            
            return `
                <div class="alert-item ${severity}">
                    <div class="alert-header">
                        <div class="alert-title">${alert.title}</div>
                        <span class="alert-severity ${severity}">${alert.severity}</span>
                    </div>
                    <div class="alert-description">${alert.description || 'No description'}</div>
                    <div class="alert-time">Created: ${timestamp}</div>
                </div>
            `;
        }).join('');
        
    } catch (error) {
        console.error('Failed to update alerts:', error);
    }
}

// ============================================================================
// Main Functions
// ============================================================================

/**
 * Refresh all dashboard data
 */
async function refreshDashboard() {
    console.log('Refreshing dashboard...');
    
    // Check API health first
    const isHealthy = await checkAPIHealth();
    
    if (isHealthy) {
        // Update all sections
        await Promise.all([
            updateSummary(),
            updateHealthTable(),
            updateCustomerHealth(),
            updateRecentErrors(),
            updateAlerts()
        ]);
        
        updateTimestamp();
        console.log('Dashboard refreshed successfully');
    } else {
        console.error('API is not healthy, skipping data refresh');
    }
}

/**
 * Start auto-refresh
 */
/**
 * Start auto-refresh
 */
function startAutoRefresh() {
    // Clear any existing interval first
    if (refreshInterval) {
        clearInterval(refreshInterval);
        refreshInterval = null;
    }
    
    if (CONFIG.AUTO_REFRESH) {
        refreshInterval = setInterval(() => {
            console.log(`Auto-refresh triggered at ${new Date().toLocaleTimeString()}`);
            refreshDashboard();
        }, CONFIG.REFRESH_INTERVAL);
        
        console.log(`✓ Auto-refresh enabled (every ${CONFIG.REFRESH_INTERVAL / 1000}s)`);
        console.log(`Next refresh at: ${new Date(Date.now() + CONFIG.REFRESH_INTERVAL).toLocaleTimeString()}`);
    } else {
        console.log('Auto-refresh is disabled in config');
    }
}




/**
 * Initialize dashboard
 */
/**
 * Initialize dashboard
 */
async function initDashboard() {
    console.log('='.repeat(70));
    console.log('Initializing dashboard...');
    console.log('='.repeat(70));
    
    // Initial data load
    await refreshDashboard();
    
    // Setup event listeners
    document.getElementById('btnRefresh').addEventListener('click', () => {
        console.log('Manual refresh triggered');
        refreshDashboard();
    });
    
    // Start auto-refresh
    console.log(`Starting auto-refresh (interval: ${CONFIG.REFRESH_INTERVAL / 1000}s)...`);
    startAutoRefresh();
    
    console.log('Dashboard initialized successfully');
    console.log('='.repeat(70));
}

// ============================================================================
// Run on page load
// ============================================================================

// Wait for DOM to be ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initDashboard);
} else {
    initDashboard();
}