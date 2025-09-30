#!/bin/bash

# Quick Fix for Strapi Internal Server Error
# Common fixes for production issues

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

echo "🔧 Strapi Internal Server Error - Quick Fix"
echo "==========================================="

# 1. Fix Environment Variables
print_status "1. Fixing Environment Variables..."

# Create proper .env.production if it doesn't exist
if [ ! -f ".env.production" ]; then
    print_status "Creating .env.production file..."
    cat > .env.production << 'EOF'
# Production Environment Configuration
NODE_ENV=production

# Database Configuration (PostgreSQL)
DATABASE_CLIENT=postgres
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_NAME=strapi_production
DATABASE_USERNAME=strapi_user
DATABASE_PASSWORD=your_secure_password_here
DATABASE_SSL=false
DATABASE_SCHEMA=public

# Server Configuration
HOST=0.0.0.0
PORT=1337

# App Keys (Generate new ones for production)
APP_KEYS=your_app_key_1,your_app_key_2,your_app_key_3,your_app_key_4

# JWT Secret (Generate a secure secret)
JWT_SECRET=your_jwt_secret_here

# Admin JWT Secret (Generate a secure secret)
ADMIN_JWT_SECRET=your_admin_jwt_secret_here

# API Token Salt (Generate a secure salt)
API_TOKEN_SALT=your_api_token_salt_here

# Transfer Token Salt (Generate a secure salt)
TRANSFER_TOKEN_SALT=your_transfer_token_salt_here

# Database Pool Configuration
DATABASE_POOL_MIN=2
DATABASE_POOL_MAX=10
DATABASE_CONNECTION_TIMEOUT=60000

# Memory Optimization
NODE_OPTIONS=--max-old-space-size=4096
UV_THREADPOOL_SIZE=16
EOF
fi

# Generate secure secrets if using defaults
if grep -q "your_secure_password_here" .env.production; then
    print_warning "Please update .env.production with your actual values!"
    print_status "Generating secure secrets..."
    
    # Generate secure secrets
    APP_KEY_1=$(node -e "console.log(require('crypto').randomBytes(32).toString('base64'))")
    APP_KEY_2=$(node -e "console.log(require('crypto').randomBytes(32).toString('base64'))")
    APP_KEY_3=$(node -e "console.log(require('crypto').randomBytes(32).toString('base64'))")
    APP_KEY_4=$(node -e "console.log(require('crypto').randomBytes(32).toString('base64'))")
    JWT_SECRET=$(node -e "console.log(require('crypto').randomBytes(64).toString('base64'))")
    ADMIN_JWT_SECRET=$(node -e "console.log(require('crypto').randomBytes(64).toString('base64'))")
    API_TOKEN_SALT=$(node -e "console.log(require('crypto').randomBytes(32).toString('base64'))")
    TRANSFER_TOKEN_SALT=$(node -e "console.log(require('crypto').randomBytes(32).toString('base64'))")
    
    # Update environment file with generated secrets
    sed -i "s/your_app_key_1/$APP_KEY_1/g" .env.production
    sed -i "s/your_app_key_2/$APP_KEY_2/g" .env.production
    sed -i "s/your_app_key_3/$APP_KEY_3/g" .env.production
    sed -i "s/your_app_key_4/$APP_KEY_4/g" .env.production
    sed -i "s/your_jwt_secret_here/$JWT_SECRET/g" .env.production
    sed -i "s/your_admin_jwt_secret_here/$ADMIN_JWT_SECRET/g" .env.production
    sed -i "s/your_api_token_salt_here/$API_TOKEN_SALT/g" .env.production
    sed -i "s/your_transfer_token_salt_here/$TRANSFER_TOKEN_SALT/g" .env.production
    
    print_status "Secure secrets generated and updated!"
fi

# 2. Fix Database Connection
print_status "2. Fixing Database Connection..."

# Ensure PostgreSQL is running
if ! systemctl is-active --quiet postgresql; then
    print_status "Starting PostgreSQL..."
    sudo systemctl start postgresql
    sudo systemctl enable postgresql
fi

# Create database and user if they don't exist
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
        CREATE ROLE strapi_user WITH LOGIN PASSWORD 'your_secure_password_here';
    END IF;
END
$$;

GRANT ALL PRIVILEGES ON DATABASE strapi_production TO strapi_user;
ALTER USER strapi_user CREATEDB;
EOSQL

# 3. Fix File Permissions
print_status "3. Fixing File Permissions..."

# Fix ownership
sudo chown -R $USER:$USER /opt/strapi 2>/dev/null || true
sudo chown -R $USER:$USER . 2>/dev/null || true

# Fix uploads directory
mkdir -p public/uploads
chmod -R 755 public/uploads

# Fix node_modules permissions
if [ -d "node_modules" ]; then
    chmod -R 755 node_modules
fi

# 4. Fix Middleware Configuration
print_status "4. Fixing Middleware Configuration..."

# Ensure health middleware is properly configured
if [ ! -d "src/middlewares" ]; then
    mkdir -p src/middlewares
fi

# Create health middleware if it doesn't exist
if [ ! -f "src/middlewares/health.js" ]; then
    cat > src/middlewares/health.js << 'EOF'
module.exports = (config, { strapi }) => {
  return async (ctx, next) => {
    if (ctx.path === '/_health') {
      try {
        // Check database connection
        await strapi.db.connection.raw('SELECT 1');
        
        ctx.status = 200;
        ctx.body = {
          status: 'ok',
          timestamp: new Date().toISOString(),
          uptime: process.uptime(),
          memory: process.memoryUsage(),
          version: process.version
        };
      } catch (error) {
        ctx.status = 503;
        ctx.body = {
          status: 'error',
          error: error.message,
          timestamp: new Date().toISOString()
        };
      }
      return;
    }
    
    await next();
  };
};
EOF
fi

# 5. Rebuild Application
print_status "5. Rebuilding Application..."

# Install dependencies
print_status "Installing dependencies..."
npm install

# Build application
print_status "Building application..."
NODE_OPTIONS="--max-old-space-size=4096" npm run build

# 6. Restart Services
print_status "6. Restarting Services..."

# Restart PostgreSQL
sudo systemctl restart postgresql

# Restart Strapi
if command -v pm2 &> /dev/null; then
    print_status "Restarting Strapi via PM2..."
    pm2 restart strapi || pm2 start ecosystem.config.js --env production
else
    print_status "PM2 not found. Please start Strapi manually."
fi

# 7. Test Application
print_status "7. Testing Application..."

# Wait a moment for services to start
sleep 5

# Test health endpoint
print_status "Testing health endpoint..."
if curl -s http://localhost:1337/_health > /dev/null 2>&1; then
    print_status "✅ Health endpoint is working!"
    curl -s http://localhost:1337/_health | jq . 2>/dev/null || curl -s http://localhost:1337/_health
else
    print_error "❌ Health endpoint not responding"
fi

# Test main application
print_status "Testing main application..."
if curl -s http://localhost:1337 > /dev/null 2>&1; then
    print_status "✅ Main application is working!"
else
    print_error "❌ Main application not responding"
fi

echo ""
print_status "🔧 Quick fixes applied!"
print_warning "If issues persist, run: ./troubleshoot-production.sh"
print_warning "Check logs with: pm2 logs strapi"
