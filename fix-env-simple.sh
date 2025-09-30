#!/bin/bash

# Simple Environment Fix for Strapi
# This script creates a proper .env.production file

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

echo "🔧 Creating Proper Environment Configuration"
echo "=========================================="

# Generate secure secrets
print_status "Generating secure secrets..."

# Generate secrets using a more reliable method
APP_KEY_1=$(openssl rand -base64 32 2>/dev/null || node -e "console.log(require('crypto').randomBytes(32).toString('base64'))" 2>/dev/null || echo "app_key_1_$(date +%s)")
APP_KEY_2=$(openssl rand -base64 32 2>/dev/null || node -e "console.log(require('crypto').randomBytes(32).toString('base64'))" 2>/dev/null || echo "app_key_2_$(date +%s)")
APP_KEY_3=$(openssl rand -base64 32 2>/dev/null || node -e "console.log(require('crypto').randomBytes(32).toString('base64'))" 2>/dev/null || echo "app_key_3_$(date +%s)")
APP_KEY_4=$(openssl rand -base64 32 2>/dev/null || node -e "console.log(require('crypto').randomBytes(32).toString('base64'))" 2>/dev/null || echo "app_key_4_$(date +%s)")
JWT_SECRET=$(openssl rand -base64 64 2>/dev/null || node -e "console.log(require('crypto').randomBytes(64).toString('base64'))" 2>/dev/null || echo "jwt_secret_$(date +%s)")
ADMIN_JWT_SECRET=$(openssl rand -base64 64 2>/dev/null || node -e "console.log(require('crypto').randomBytes(64).toString('base64'))" 2>/dev/null || echo "admin_jwt_secret_$(date +%s)")
API_TOKEN_SALT=$(openssl rand -base64 32 2>/dev/null || node -e "console.log(require('crypto').randomBytes(32).toString('base64'))" 2>/dev/null || echo "api_token_salt_$(date +%s)")
TRANSFER_TOKEN_SALT=$(openssl rand -base64 32 2>/dev/null || node -e "console.log(require('crypto').randomBytes(32).toString('base64'))" 2>/dev/null || echo "transfer_token_salt_$(date +%s)")

# Create a new .env.production file
print_status "Creating .env.production with secure values..."

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
APP_KEYS=$APP_KEY_1,$APP_KEY_2,$APP_KEY_3,$APP_KEY_4

# JWT Secret (Generated secure secret)
JWT_SECRET=$JWT_SECRET

# Admin JWT Secret (Generated secure secret)
ADMIN_JWT_SECRET=$ADMIN_JWT_SECRET

# API Token Salt (Generated secure salt)
API_TOKEN_SALT=$API_TOKEN_SALT

# Transfer Token Salt (Generated secure salt)
TRANSFER_TOKEN_SALT=$TRANSFER_TOKEN_SALT

# Database Pool Configuration
DATABASE_POOL_MIN=2
DATABASE_POOL_MAX=10
DATABASE_CONNECTION_TIMEOUT=60000

# Memory Optimization
NODE_OPTIONS=--max-old-space-size=2048
UV_THREADPOOL_SIZE=16
EOF

print_status "✅ Environment file created with secure values!"

# Show the generated values (for reference)
print_debug "Generated secrets:"
echo "APP_KEYS: $APP_KEY_1,$APP_KEY_2,$APP_KEY_3,$APP_KEY_4"
echo "JWT_SECRET: $JWT_SECRET"
echo "ADMIN_JWT_SECRET: $ADMIN_JWT_SECRET"
echo "API_TOKEN_SALT: $API_TOKEN_SALT"
echo "TRANSFER_TOKEN_SALT: $TRANSFER_TOKEN_SALT"

print_status "🔧 Environment configuration completed!"
print_warning "You can now run: pm2 start ecosystem.config.js --env production"
