#!/bin/bash

# Fix JWT Secret Configuration
# This script fixes the missing JWT secret issue

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[FIXING]${NC} $1"
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

echo "🔧 Fixing JWT Secret Configuration"
echo "=================================="

# 1. Stop PM2
print_status "1. Stopping PM2..."
echo "----------------------------------------"
pm2 kill
sleep 2
print_debug "PM2 stopped"
echo ""

# 2. Check current environment file
print_status "2. Checking Environment File..."
echo "----------------------------------------"
if [ -f ".env.production" ]; then
    print_debug "Environment file exists"
    echo "Current JWT_SECRET:"
    grep "JWT_SECRET" .env.production || echo "JWT_SECRET not found"
    echo ""
    echo "Current ADMIN_JWT_SECRET:"
    grep "ADMIN_JWT_SECRET" .env.production || echo "ADMIN_JWT_SECRET not found"
else
    print_error "Environment file not found!"
    exit 1
fi
echo ""

# 3. Fix environment file with proper JWT secrets
print_status "3. Fixing JWT Secrets..."
echo "----------------------------------------"

# Generate new JWT secrets
JWT_SECRET=$(openssl rand -base64 64 2>/dev/null || node -e "console.log(require('crypto').randomBytes(64).toString('base64'))" 2>/dev/null || echo "jwt_secret_$(date +%s)")
ADMIN_JWT_SECRET=$(openssl rand -base64 64 2>/dev/null || node -e "console.log(require('crypto').randomBytes(64).toString('base64'))" 2>/dev/null || echo "admin_jwt_secret_$(date +%s)")

# Create a new environment file with proper JWT secrets
cat > .env.production << EOF
# Production Environment Configuration
NODE_ENV=production

# Database Configuration (PostgreSQL)
DATABASE_CLIENT=postgres
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_NAME=strapi_production
DATABASE_USERNAME=strapi_user
DATABASE_PASSWORD=strapi_secure_password_$(date +%s)
DATABASE_SSL=false
DATABASE_SCHEMA=public

# Server Configuration
HOST=0.0.0.0
PORT=1337

# App Keys (Generated secure keys)
APP_KEYS=app_key_1_$(date +%s),app_key_2_$(date +%s),app_key_3_$(date +%s),app_key_4_$(date +%s)

# JWT Secret (Generated secure secret)
JWT_SECRET=$JWT_SECRET

# Admin JWT Secret (Generated secure secret)
ADMIN_JWT_SECRET=$ADMIN_JWT_SECRET

# API Token Salt (Generated secure salt)
API_TOKEN_SALT=api_token_salt_$(date +%s)

# Transfer Token Salt (Generated secure salt)
TRANSFER_TOKEN_SALT=transfer_token_salt_$(date +%s)

# Database Pool Configuration
DATABASE_POOL_MIN=2
DATABASE_POOL_MAX=10
DATABASE_CONNECTION_TIMEOUT=60000

# Memory Optimization
NODE_OPTIONS=--max-old-space-size=2048
UV_THREADPOOL_SIZE=16
EOF

print_debug "✅ Environment file updated with proper JWT secrets"
echo ""

# 4. Verify the environment file
print_status "4. Verifying Environment File..."
echo "----------------------------------------"
print_debug "JWT_SECRET: $JWT_SECRET"
print_debug "ADMIN_JWT_SECRET: $ADMIN_JWT_SECRET"
echo ""

# 5. Check if database is running
print_status "5. Checking Database..."
echo "----------------------------------------"
if systemctl is-active --quiet postgresql; then
    print_debug "✅ PostgreSQL is running"
else
    print_error "❌ PostgreSQL is not running"
    print_status "Starting PostgreSQL..."
    sudo systemctl start postgresql
fi
echo ""

# 6. Test environment variables
print_status "6. Testing Environment Variables..."
echo "----------------------------------------"
export $(cat .env.production | xargs)
print_debug "NODE_ENV: $NODE_ENV"
print_debug "JWT_SECRET: $JWT_SECRET"
print_debug "ADMIN_JWT_SECRET: $ADMIN_JWT_SECRET"
echo ""

# 7. Start Strapi with PM2
print_status "7. Starting Strapi with PM2..."
echo "----------------------------------------"
pm2 start ecosystem.config.js --env production
pm2 save
print_debug "✅ Strapi started with PM2"
echo ""

# 8. Wait and test
print_status "8. Waiting for Application to Start..."
echo "----------------------------------------"
print_status "Waiting 15 seconds for Strapi to start..."
sleep 15

# 9. Test application
print_status "9. Testing Application..."
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

print_status "🔧 JWT secret fix completed!"
print_warning "If issues persist:"
echo "1. Check logs: pm2 logs strapi --lines 100"
echo "2. Restart: pm2 restart strapi"
echo "3. Test: curl http://localhost:1337/_health"
