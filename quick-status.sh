#!/bin/bash

# Quick Status Check - Compatible with your system
# This script checks the current status without complex commands

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

echo "🔍 Quick Strapi Status Check"
echo "============================"

# 1. Check PM2 Status
print_status "1. PM2 Status:"
echo "----------------------------------------"
pm2 status
echo ""

# 2. Check PM2 Logs (without tailing)
print_status "2. PM2 Logs (last 20 lines):"
echo "----------------------------------------"
timeout 5 pm2 logs strapi --lines 20 --nostream 2>/dev/null || echo "No logs available or PM2 not running"
echo ""

# 3. Check if Strapi process is running
print_status "3. Strapi Process Check:"
echo "----------------------------------------"
if pgrep -f "strapi" > /dev/null; then
    print_debug "✅ Strapi process is running"
    pgrep -f "strapi"
else
    print_error "❌ No Strapi process found"
fi
echo ""

# 4. Check Port 1337 (alternative methods)
print_status "4. Port 1337 Check:"
echo "----------------------------------------"
if command -v ss &> /dev/null; then
    ss -tlnp | grep 1337 || echo "Port 1337 not in use"
elif command -v lsof &> /dev/null; then
    lsof -i :1337 || echo "Port 1337 not in use"
else
    # Try to connect to the port
    if timeout 2 bash -c "</dev/tcp/localhost/1337" 2>/dev/null; then
        print_debug "✅ Port 1337 is responding"
    else
        print_error "❌ Port 1337 is not responding"
    fi
fi
echo ""

# 5. Check Database
print_status "5. Database Status:"
echo "----------------------------------------"
if systemctl is-active --quiet postgresql; then
    print_debug "✅ PostgreSQL is running"
else
    print_error "❌ PostgreSQL is not running"
    echo "Starting PostgreSQL..."
    sudo systemctl start postgresql
fi
echo ""

# 6. Test Application
print_status "6. Application Test:"
echo "----------------------------------------"
if curl -s http://localhost:1337/_health > /dev/null 2>&1; then
    print_debug "✅ Health endpoint responding"
    curl -s http://localhost:1337/_health
else
    print_error "❌ Health endpoint not responding"
fi
echo ""

# 7. Check Environment
print_status "7. Environment Check:"
echo "----------------------------------------"
if [ -f ".env.production" ]; then
    print_debug "✅ Environment file exists"
    if grep -q "your_secure_password_here" .env.production; then
        print_error "❌ Default password detected in .env.production"
    else
        print_debug "✅ Environment file looks configured"
    fi
else
    print_error "❌ Environment file not found"
fi
echo ""

# 8. Show PM2 Process Details
print_status "8. PM2 Process Details:"
echo "----------------------------------------"
pm2 show strapi 2>/dev/null || echo "Strapi process not found in PM2"
echo ""

print_status "🔍 Quick status check completed!"
print_warning "If you see issues:"
echo "1. Fix environment: ./fix-env-simple.sh"
echo "2. Restart Strapi: pm2 restart strapi"
echo "3. Check logs: pm2 logs strapi --lines 50"
