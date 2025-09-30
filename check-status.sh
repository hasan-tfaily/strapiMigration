#!/bin/bash

# Quick Status Check for Strapi
# This script checks the current status and shows logs

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

echo "🔍 Strapi Status Check"
echo "====================="

# 1. Check PM2 Status
print_status "1. PM2 Status:"
echo "----------------------------------------"
pm2 status
echo ""

# 2. Check PM2 Logs
print_status "2. PM2 Logs (last 50 lines):"
echo "----------------------------------------"
pm2 logs strapi --lines 50 --nostream
echo ""

# 3. Check Port Usage
print_status "3. Port 1337 Status:"
echo "----------------------------------------"
# Try different commands to check port
if command -v netstat &> /dev/null; then
    netstat -tlnp | grep 1337 || echo "Port 1337 not in use"
elif command -v ss &> /dev/null; then
    ss -tlnp | grep 1337 || echo "Port 1337 not in use"
elif command -v lsof &> /dev/null; then
    lsof -i :1337 || echo "Port 1337 not in use"
else
    echo "No port checking tools available"
fi
echo ""

# 4. Check Database
print_status "4. Database Status:"
echo "----------------------------------------"
if systemctl is-active --quiet postgresql; then
    print_debug "✅ PostgreSQL is running"
    sudo -u postgres psql -c "SELECT version();" 2>/dev/null || echo "Database connection failed"
else
    print_error "❌ PostgreSQL is not running"
    echo "Starting PostgreSQL..."
    sudo systemctl start postgresql
fi
echo ""

# 5. Check Environment
print_status "5. Environment Check:"
echo "----------------------------------------"
if [ -f ".env.production" ]; then
    print_debug "✅ Environment file exists"
    echo "Key environment variables:"
    grep -E "^(NODE_ENV|DATABASE_CLIENT|HOST|PORT)" .env.production || echo "No key variables found"
else
    print_error "❌ Environment file not found"
fi
echo ""

# 6. Check Application Health
print_status "6. Application Health:"
echo "----------------------------------------"
if curl -s http://localhost:1337/_health > /dev/null 2>&1; then
    print_debug "✅ Health endpoint responding"
    curl -s http://localhost:1337/_health
else
    print_error "❌ Health endpoint not responding"
fi
echo ""

# 7. Check System Resources
print_status "7. System Resources:"
echo "----------------------------------------"
echo "Memory:"
free -h
echo ""
echo "Disk:"
df -h | head -5
echo ""

# 8. Show Recent Errors
print_status "8. Recent Errors:"
echo "----------------------------------------"
pm2 logs strapi --lines 20 --nostream | grep -i error || echo "No recent errors found"
echo ""

print_status "🔍 Status check completed!"
print_warning "If you see issues:"
echo "1. Run: ./fix-env-simple.sh"
echo "2. Run: pm2 restart strapi"
echo "3. Check logs: pm2 logs strapi --lines 100"
