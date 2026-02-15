# Detailed Setup Guide

Complete step-by-step installation instructions for the SaaS Integration Toolkit.

## System Requirements

### Minimum Requirements
- **OS:** Windows 10, macOS 10.15+, or Linux (Ubuntu 20.04+)
- **RAM:** 4GB
- **Disk Space:** 500MB
- **Internet:** Required for package downloads

### Software Requirements
- **Python:** 3.8 or higher
- **Node.js:** 14.x or higher
- **PostgreSQL:** 14.x or higher
- **Git:** 2.x or higher

---

## Installation Steps

### 1. Install Prerequisites

#### Python

**Windows:**
1. Download from https://www.python.org/downloads/
2. Run installer
3. ✅ Check "Add Python to PATH"
4. Verify: `python --version`

**Mac:**
```bash
brew install python@3.9
```

**Linux:**
```bash
sudo apt update
sudo apt install python3.9 python3-pip python3-venv
```

#### Node.js

**Windows/Mac:**
1. Download from https://nodejs.org/
2. Run installer
3. Verify: `node --version` and `npm --version`

**Linux:**
```bash
curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
sudo apt-get install -y nodejs
```

#### PostgreSQL

**Windows:**
1. Download from https://www.postgresql.org/download/windows/
2. Run installer
3. Remember your password!
4. Default port: 5432

**Mac:**
```bash
brew install postgresql@14
brew services start postgresql@14
```

**Linux:**
```bash
sudo apt install postgresql postgresql-contrib
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

**Verify PostgreSQL:**
```bash
psql --version
```

---

### 2. Clone Repository
```bash
git clone https://github.com/YOUR-USERNAME/saas-integration-toolkit.git
cd saas-integration-toolkit
```

---

### 3. Database Setup

#### Create Database
```bash
# Connect to PostgreSQL
psql -U postgres

# Create database
CREATE DATABASE integration_toolkit;

# Exit
\q
```

#### Load Schema
```bash
psql -U postgres -d integration_toolkit -f database/schema.sql
```

**Expected output:**
```
CREATE TABLE
CREATE TABLE
CREATE TABLE
...
CREATE VIEW
```

#### Load Sample Data
```bash
psql -U postgres -d integration_toolkit -f database/sample_data.sql
```

**Expected output:**
```
INSERT 0 8
INSERT 0 246
...
```

#### Verify Database
```bash
psql -U postgres -d integration_toolkit -c "\dt"
```

Should show 6 tables.

---

### 4. Backend Setup (Python)

#### Create Virtual Environment
```bash
cd backend

# Windows
python -m venv venv
venv\Scripts\activate

# Mac/Linux
python3 -m venv venv
source venv/bin/activate
```

**You should see `(venv)` in your prompt.**

#### Install Dependencies
```bash
pip install -r requirements.txt
```

**Expected packages:**
- Flask
- psycopg2-binary
- python-dotenv
- requests
- Flask-CORS

#### Configure Environment

Create `backend/.env`:
```env
# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=integration_toolkit
DB_USER=postgres
DB_PASSWORD=YOUR_POSTGRES_PASSWORD

# API
API_HOST=0.0.0.0
API_PORT=5000
DEBUG=True
```

**⚠️ Replace `YOUR_POSTGRES_PASSWORD` with your actual PostgreSQL password!**

#### Test Backend
```bash
python database.py
```

**Expected:**
```
✓ Database connection established
✓ Connection test successful!
✓ Found 8 endpoints
```

---

### 5. Webhook Service Setup (Node.js)

#### Install Dependencies
```bash
cd ../webhook-service
npm install
```

**Expected packages:**
- express
- body-parser
- pg
- dotenv
- crypto

#### Configure Environment

Create `webhook-service/.env`:
```env
WEBHOOK_PORT=3000
DB_HOST=localhost
DB_PORT=5432
DB_NAME=integration_toolkit
DB_USER=postgres
DB_PASSWORD=YOUR_POSTGRES_PASSWORD
```

#### Test Webhook Service
```bash
node server.js
```

**Expected:**
```
✅ Database connected
======================================================================
🎯 Webhook Listener Service
======================================================================
✅ Server running on http://localhost:3000
```

---

### 6. Frontend Setup

No setup required! The frontend is pure HTML/CSS/JavaScript.

---

## Running the Application

### Start All Services

**Terminal 1 - Flask API:**
```bash
cd backend
source venv/bin/activate  # Windows: venv\Scripts\activate
python app.py
```

**Terminal 2 - Webhook Service:**
```bash
cd webhook-service
node server.js
```

**Terminal 3 - Frontend:**
```bash
cd frontend
python -m http.server 8000
```

**Access:**
- Dashboard: http://localhost:8000
- API: http://localhost:5000/api/health
- Webhooks: http://localhost:3000/health

---

## Troubleshooting

### Database Connection Failed

**Error:** `psycopg2.OperationalError: FATAL: password authentication failed`

**Solution:**
1. Check password in `.env` files
2. Verify PostgreSQL is running: `pg_ctl status`
3. Try connecting manually: `psql -U postgres`

### Module Not Found (Python)

**Error:** `ModuleNotFoundError: No module named 'flask'`

**Solution:**
1. Activate virtual environment: `source venv/bin/activate`
2. Install packages: `pip install -r requirements.txt`

### Port Already in Use

**Error:** `Address already in use: 5000`

**Solution:**
1. Find process: `lsof -i :5000` (Mac/Linux) or `netstat -ano | findstr :5000` (Windows)
2. Kill process or change port in `.env`

### Cannot Connect to PostgreSQL

**Error:** `could not connect to server`

**Solution:**
1. Start PostgreSQL:
   - Windows: Start service in Services app
   - Mac: `brew services start postgresql`
   - Linux: `sudo systemctl start postgresql`

---

## Next Steps

1. ✅ Run health monitoring: `python backend/monitor.py`
2. ✅ Send test webhook: See API documentation
3. ✅ Analyze logs: `python scripts/log_analyzer.py logs/sample.log`
4. ✅ Explore database: `psql -U postgres -d integration_toolkit`

---

## Support

**Issues?** Open an issue on GitHub or contact [your-email@example.com]