#!/bin/bash

# Strapi Production Troubleshooting Script
# For Internal Server Error and other production issues

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
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

echo "🔍 Strapi Production Troubleshooting Script"
echo "=========================================="

# Check if running as root or with sudo
if [ "$EUID" -eq 0 ]; then
    print_warning "Running as root. Some commands may need adjustment."
fi

# 1. Check System Resources
print_status "1. Checking System Resources..."
echo "----------------------------------------"
echo "Memory Usage:"
free -h
echo ""
echo "Disk Usage:"
df -h
echo ""
echo "CPU Load:"
uptime
echo ""

# 2. Check if Strapi is running
print_status "2. Checking Strapi Application Status..."
echo "----------------------------------------"

# Check PM2 processes
if command -v pm2 &> /dev/null; then
    print_debug "PM2 Status:"
    pm2 status
    echo ""
    
    print_debug "PM2 Logs (last 50 lines):"
    pm2 logs strapi --lines 50
    echo ""
else
    print_warning "PM2 not found. Checking for other process managers..."
fi

# Check for Node.js processes
print_debug "Node.js Processes:"
ps aux | grep node | grep -v grep || echo "No Node.js processes found"
echo ""

# Check port 1337
print_debug "Port 1337 Status:"
netstat -tlnp | grep 1337 || echo "Port 1337 not in use"
echo ""

# 3. Check Database Connection
print_status "3. Checking Database Connection..."
echo "----------------------------------------"

# Check PostgreSQL status
if systemctl is-active --quiet postgresql; then
    print_debug "PostgreSQL is running"
else
    print_error "PostgreSQL is not running!"
    echo "Starting PostgreSQL..."
    sudo systemctl start postgresql
fi

# Test database connection
print_debug "Testing database connection..."
if sudo -u postgres psql -c "SELECT version();" &> /dev/null; then
    print_debug "Database connection successful"
else
    print_error "Database connection failed!"
fi

# Check database exists
print_debug "Checking if strapi_production database exists..."
if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw strapi_production; then
    print_debug "Database strapi_production exists"
else
    print_error "Database strapi_production does not exist!"
    echo "Creating database..."
    sudo -u postgres createdb strapi_production
fi

echo ""

# 4. Check Environment Variables
print_status "4. Checking Environment Configuration..."
echo "----------------------------------------"

if [ -f ".env.production" ]; then
    print_debug "Environment file found"
    
    # Check critical environment variables
    if grep -q "DATABASE_CLIENT=postgres" .env.production; then
        print_debug "Database client configured for PostgreSQL"
    else
        print_error "Database client not configured for PostgreSQL!"
    fi
    
    if grep -q "NODE_ENV=production" .env.production; then
        print_debug "Node environment set to production"
    else
        print_error "Node environment not set to production!"
    fi
    
    # Check if secrets are set (not placeholder values)
    if grep -q "your_secure_password_here" .env.production; then
        print_error "Default password detected! Please update .env.production"
    fi
    
    if grep -q "your_jwt_secret_here" .env.production; then
        print_error "Default JWT secret detected! Please update .env.production"
    fi
    
else
    print_error "Environment file .env.production not found!"
fi

echo ""

# 5. Check Application Logs
print_status "5. Checking Application Logs..."
echo "----------------------------------------"

# Check system logs
print_debug "Recent system logs:"
journalctl -u strapi --lines 20 --no-pager || echo "No systemd service logs found"
echo ""

# Check Nginx logs if running
if systemctl is-active --quiet nginx; then
    print_debug "Nginx is running"
    print_debug "Nginx error logs:"
    sudo tail -20 /var/log/nginx/error.log 2>/dev/null || echo "No Nginx error logs"
    echo ""
else
    print_warning "Nginx not running"
fi

# 6. Check File Permissions
print_status "6. Checking File Permissions..."
echo "----------------------------------------"

APP_DIR="/opt/strapi"
if [ -d "$APP_DIR" ]; then
    print_debug "Application directory permissions:"
    ls -la $APP_DIR | head -10
    echo ""
    
    # Check if uploads directory exists and is writable
    if [ -d "$APP_DIR/public/uploads" ]; then
        print_debug "Uploads directory exists"
        if [ -w "$APP_DIR/public/uploads" ]; then
            print_debug "Uploads directory is writable"
        else
            print_error "Uploads directory is not writable!"
            echo "Fixing permissions..."
            sudo chown -R $USER:$USER $APP_DIR/public/uploads
            sudo chmod -R 755 $APP_DIR/public/uploads
        fi
    else
        print_warning "Uploads directory not found"
        echo "Creating uploads directory..."
        mkdir -p $APP_DIR/public/uploads
        chmod 755 $APP_DIR/public/uploads
    fi
else
    print_error "Application directory not found at $APP_DIR"
fi

echo ""

# 7. Test Application Endpoints
print_status "7. Testing Application Endpoints..."
echo "----------------------------------------"

# Test health endpoint
print_debug "Testing health endpoint..."
if curl -s http://localhost:1337/_health > /dev/null 2>&1; then
    print_debug "Health endpoint responding"
    curl -s http://localhost:1337/_health | jq . 2>/dev/null || curl -s http://localhost:1337/_health
else
    print_error "Health endpoint not responding"
fi

echo ""

# Test main application
print_debug "Testing main application..."
if curl -s http://localhost:1337 > /dev/null 2>&1; then
    print_debug "Main application responding"
else
    print_error "Main application not responding"
fi

echo ""

# 8. Common Fixes
print_status "8. Applying Common Fixes..."
echo "----------------------------------------"

# Restart services
print_debug "Restarting services..."

# Restart PostgreSQL
sudo systemctl restart postgresql
print_debug "PostgreSQL restarted"

# Restart Strapi if using PM2
if command -v pm2 &> /dev/null; then
    pm2 restart strapi
    print_debug "Strapi restarted via PM2"
fi

# Restart Nginx if running
if systemctl is-active --quiet nginx; then
    sudo systemctl restart nginx
    print_debug "Nginx restarted"
fi

echo ""

# 9. Generate Diagnostic Report
print_status "9. Generating Diagnostic Report..."
echo "----------------------------------------"

REPORT_FILE="strapi-diagnostic-$(date +%Y%m%d_%H%M%S).txt"

cat > $REPORT_FILE << EOF
Strapi Production Diagnostic Report
Generated: $(date)
Server: $(hostname)
IP: $(hostname -I | awk '{print $1}')

=== SYSTEM INFO ===
OS: $(uname -a)
Memory: $(free -h | grep Mem)
Disk: $(df -h | grep -E '^/dev/')
CPU: $(nproc) cores

=== STRAPI STATUS ===
PM2 Status:
$(pm2 status 2>/dev/null || echo "PM2 not available")

Port 1337:
$(netstat -tlnp | grep 1337 || echo "Port 1337 not in use")

=== DATABASE STATUS ===
PostgreSQL Status:
$(systemctl status postgresql --no-pager -l || echo "PostgreSQL not available")

Database List:
$(sudo -u postgres psql -l 2>/dev/null || echo "Cannot access PostgreSQL")

=== ENVIRONMENT ===
Node Version: $(node --version 2>/dev/null || echo "Node not found")
NPM Version: $(npm --version 2>/dev/null || echo "NPM not found")

Environment Variables:
$(cat .env.production 2>/dev/null || echo "Environment file not found")

=== LOGS ===
PM2 Logs (last 100 lines):
$(pm2 logs strapi --lines 100 2>/dev/null || echo "No PM2 logs available")

System Logs:
$(journalctl -u strapi --lines 50 --no-pager 2>/dev/null || echo "No system logs available")
EOF

print_debug "Diagnostic report saved to: $REPORT_FILE"

echo ""
print_status "Troubleshooting completed!"
print_warning "If issues persist, check the diagnostic report: $REPORT_FILE"
print_warning "Common solutions:"
echo "1. Update .env.production with correct values"
echo "2. Restart all services: sudo systemctl restart postgresql && pm2 restart strapi"
echo "3. Check file permissions: sudo chown -R \$USER:\$USER /opt/strapi"
echo "4. Verify database connection and credentials"
echo "5. Check firewall settings: sudo ufw status"
