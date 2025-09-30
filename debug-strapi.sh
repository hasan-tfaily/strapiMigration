#!/bin/bash

# Debug Strapi Issues
# This script will help identify why Strapi is not running

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[DEBUG]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_debug() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

echo "🔍 Debugging Strapi Issues"
echo "=========================="

# 1. Check Current PM2 Status
print_status "1. Current PM2 Status:"
echo "----------------------------------------"
pm2 status
echo ""

# 2. Check PM2 Logs
print_status "2. PM2 Logs (last 50 lines):"
echo "----------------------------------------"
pm2 logs strapi --lines 50 --nostream 2>/dev/null || echo "No PM2 logs available"
echo ""

# 3. Check if Strapi process exists
print_status "3. Strapi Process Check:"
echo "----------------------------------------"
if pgrep -f "strapi" > /dev/null; then
    print_debug "✅ Strapi process found:"
    pgrep -f "strapi"
else
    print_error "❌ No Strapi process found"
fi
echo ""

# 4. Check Port 1337
print_status "4. Port 1337 Check:"
echo "----------------------------------------"
if ss -tlnp | grep 1337 > /dev/null; then
    print_debug "✅ Port 1337 is in use:"
    ss -tlnp | grep 1337
else
    print_error "❌ Port 1337 is not in use"
fi
echo ""

# 5. Check Environment File
print_status "5. Environment File Check:"
echo "----------------------------------------"
if [ -f ".env.production" ]; then
    print_debug "✅ Environment file exists"
    echo "Key variables:"
    grep -E "^(NODE_ENV|DATABASE_CLIENT|HOST|PORT)" .env.production || echo "No key variables found"
    
    # Check for default values
    if grep -q "your_secure_password_here" .env.production; then
        print_error "❌ Default password detected!"
    fi
    if grep -q "your_jwt_secret_here" .env.production; then
        print_error "❌ Default JWT secret detected!"
    fi
else
    print_error "❌ Environment file not found"
fi
echo ""

# 6. Check Database
print_status "6. Database Check:"
echo "----------------------------------------"
if systemctl is-active --quiet postgresql; then
    print_debug "✅ PostgreSQL is running"
    
    # Test database connection
    if sudo -u postgres psql -c "SELECT 1;" > /dev/null 2>&1; then
        print_debug "✅ Database connection successful"
    else
        print_error "❌ Database connection failed"
    fi
else
    print_error "❌ PostgreSQL is not running"
fi
echo ""

# 7. Check Dependencies
print_status "7. Dependencies Check:"
echo "----------------------------------------"
if [ -d "node_modules" ]; then
    print_debug "✅ node_modules exists"
    if [ -f "node_modules/@strapi/strapi/package.json" ]; then
        print_debug "✅ Strapi is installed"
    else
        print_error "❌ Strapi not found in node_modules"
    fi
else
    print_error "❌ node_modules not found"
fi
echo ""

# 8. Check Build
print_status "8. Build Check:"
echo "----------------------------------------"
if [ -d "dist" ]; then
    print_debug "✅ dist directory exists"
    if [ -f "dist/src/index.js" ]; then
        print_debug "✅ Built application found"
    else
        print_error "❌ Built application not found"
    fi
else
    print_error "❌ dist directory not found"
fi
echo ""

# 9. Try to Start Strapi Manually
print_status "9. Manual Start Test:"
echo "----------------------------------------"
print_debug "Trying to start Strapi manually..."
timeout 10 npm start 2>&1 || echo "Manual start failed or timed out"
echo ""

# 10. Check System Resources
print_status "10. System Resources:"
echo "----------------------------------------"
echo "Memory:"
free -h
echo ""
echo "Disk:"
df -h | head -3
echo ""

# 11. Check for Common Issues
print_status "11. Common Issues Check:"
echo "----------------------------------------"

# Check if there are any error files
if [ -f "logs/err.log" ]; then
    print_debug "Error log found:"
    tail -20 logs/err.log
fi

# Check if there are any out files
if [ -f "logs/out.log" ]; then
    print_debug "Output log found:"
    tail -20 logs/out.log
fi

echo ""
print_status "🔍 Debug completed!"
print_warning "Next steps:"
echo "1. If environment has defaults: ./fix-env-simple.sh"
echo "2. If dependencies missing: npm install"
echo "3. If build missing: npm run build"
echo "4. If database issues: sudo systemctl start postgresql"
echo "5. Try manual start: NODE_ENV=production npm start"
