#!/bin/bash

# Start Strapi Application
# This script will start Strapi properly

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[STARTING]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

echo "🚀 Starting Strapi Application"
echo "============================="

# 1. Check if PM2 is running
print_status "1. Checking PM2 Status..."
echo "----------------------------------------"
pm2 status
echo ""

# 2. Kill any existing processes
print_status "2. Cleaning up existing processes..."
echo "----------------------------------------"
pm2 kill 2>/dev/null || true
pkill -f "strapi" 2>/dev/null || true
sleep 2
print_debug "Existing processes cleaned up"
echo ""

# 3. Check Environment File
print_status "3. Checking Environment Configuration..."
echo "----------------------------------------"
if [ -f ".env.production" ]; then
    print_debug "✅ Environment file exists"
    if grep -q "your_secure_password_here" .env.production; then
        print_error "❌ Default password detected!"
        print_status "Fixing environment file..."
        ./fix-env-simple.sh
    else
        print_debug "✅ Environment file looks good"
    fi
else
    print_error "❌ Environment file not found!"
    print_status "Creating environment file..."
    ./fix-env-simple.sh
fi
echo ""

# 4. Check Database
print_status "4. Checking Database..."
echo "----------------------------------------"
if systemctl is-active --quiet postgresql; then
    print_debug "✅ PostgreSQL is running"
else
    print_error "❌ PostgreSQL is not running"
    print_status "Starting PostgreSQL..."
    sudo systemctl start postgresql
fi

# Test database connection
if sudo -u postgres psql -c "SELECT 1;" > /dev/null 2>&1; then
    print_debug "✅ Database connection successful"
else
    print_error "❌ Database connection failed"
    print_status "Setting up database..."
    sudo -u postgres psql << 'EOSQL'
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'strapi_production') THEN
        CREATE DATABASE strapi_production;
    END IF;
END
$$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'strapi_user') THEN
        CREATE ROLE strapi_user WITH LOGIN PASSWORD 'strapi_secure_password_123';
    END IF;
END
$$;

GRANT ALL PRIVILEGES ON DATABASE strapi_production TO strapi_user;
ALTER USER strapi_user CREATEDB;
EOSQL
fi
echo ""

# 5. Install Dependencies
print_status "5. Installing Dependencies..."
echo "----------------------------------------"
if [ ! -d "node_modules" ]; then
    print_status "Installing dependencies..."
    npm install
else
    print_debug "✅ Dependencies already installed"
fi
echo ""

# 6. Build Application
print_status "6. Building Application..."
echo "----------------------------------------"
print_status "Building Strapi application..."
NODE_OPTIONS="--max-old-space-size=2048" npm run build
print_debug "✅ Application built successfully"
echo ""

# 7. Create PM2 Ecosystem
print_status "7. Creating PM2 Configuration..."
echo "----------------------------------------"
cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'strapi',
    script: 'npm',
    args: 'start',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    node_args: '--max-old-space-size=1024',
    env: {
      NODE_ENV: 'production',
      PORT: 1337
    },
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log',
    time: true
  }]
};
EOF

# Create logs directory
mkdir -p logs
print_debug "✅ PM2 configuration created"
echo ""

# 8. Start Strapi
print_status "8. Starting Strapi with PM2..."
echo "----------------------------------------"
pm2 start ecosystem.config.js --env production
pm2 save
print_debug "✅ Strapi started with PM2"
echo ""

# 9. Wait and Test
print_status "9. Waiting for Application to Start..."
echo "----------------------------------------"
print_status "Waiting 15 seconds for Strapi to start..."
sleep 15

# 10. Test Application
print_status "10. Testing Application..."
echo "----------------------------------------"

# Check PM2 status
print_debug "PM2 Status:"
pm2 status
echo ""

# Test health endpoint
print_status "Testing health endpoint..."
if curl -s http://localhost:1337/_health > /dev/null 2>&1; then
    print_debug "✅ Health endpoint responding"
    curl -s http://localhost:1337/_health
else
    print_error "❌ Health endpoint not responding"
    print_debug "Checking PM2 logs..."
    pm2 logs strapi --lines 20 --nostream
fi
echo ""

# Test main application
print_status "Testing main application..."
if curl -s http://localhost:1337 > /dev/null 2>&1; then
    print_debug "✅ Main application responding"
else
    print_error "❌ Main application not responding"
fi
echo ""

# 11. Final Status
print_status "11. Final Status..."
echo "----------------------------------------"
print_debug "PM2 Status:"
pm2 status
echo ""

print_debug "Port 1337:"
ss -tlnp | grep 1337 || echo "Port 1337 not in use"

echo ""
print_status "🚀 Strapi startup completed!"
print_warning "If issues persist:"
echo "1. Check logs: pm2 logs strapi --lines 100"
echo "2. Restart: pm2 restart strapi"
echo "3. Test: curl http://localhost:1337/_health"
