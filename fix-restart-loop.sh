#!/bin/bash

# Fix Strapi Restart Loop and 502 Bad Gateway
# This script addresses the specific restart loop issue

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

echo "🔧 Fixing Strapi Restart Loop and 502 Bad Gateway"
echo "================================================="

# 1. Stop All PM2 Processes
print_status "1. Stopping All PM2 Processes..."
echo "----------------------------------------"

# Force stop all processes
pm2 kill
print_debug "All PM2 processes killed"

# Wait a moment
sleep 3

# 2. Check for Strapi Process Issues
print_status "2. Checking for Process Issues..."
echo "----------------------------------------"

# Check if any Strapi processes are still running
if pgrep -f "strapi" > /dev/null; then
    print_warning "Strapi processes still running, killing them..."
    pkill -f "strapi" || true
    sleep 2
fi

# Check port 1337
if lsof -i :1337 > /dev/null 2>&1; then
    print_warning "Port 1337 is still in use, killing processes..."
    sudo fuser -k 1337/tcp || true
    sleep 2
fi

# 3. Check Environment Configuration
print_status "3. Checking Environment Configuration..."
echo "----------------------------------------"

# Check if .env.production exists and is valid
if [ ! -f ".env.production" ]; then
    print_error "Environment file not found!"
    print_status "Creating .env.production..."
    
    cat > .env.production << 'EOF'
NODE_ENV=production
DATABASE_CLIENT=postgres
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_NAME=strapi_production
DATABASE_USERNAME=strapi_user
DATABASE_PASSWORD=your_secure_password_here
DATABASE_SSL=false
HOST=0.0.0.0
PORT=1337
APP_KEYS=key1,key2,key3,key4
JWT_SECRET=your_jwt_secret_here
ADMIN_JWT_SECRET=your_admin_jwt_secret_here
API_TOKEN_SALT=your_api_token_salt_here
TRANSFER_TOKEN_SALT=your_transfer_token_salt_here
EOF
    
    print_warning "Please update .env.production with your actual values!"
fi

# Check for placeholder values
if grep -q "your_secure_password_here" .env.production; then
    print_error "Default password detected! Please update .env.production"
    print_status "Generating secure secrets..."
    
    # Generate secure secrets
    APP_KEY_1=$(node -e "console.log(require('crypto').randomBytes(32).toString('base64'))" 2>/dev/null || echo "key1")
    APP_KEY_2=$(node -e "console.log(require('crypto').randomBytes(32).toString('base64'))" 2>/dev/null || echo "key2")
    APP_KEY_3=$(node -e "console.log(require('crypto').randomBytes(32).toString('base64'))" 2>/dev/null || echo "key3")
    APP_KEY_4=$(node -e "console.log(require('crypto').randomBytes(32).toString('base64'))" 2>/dev/null || echo "key4")
    JWT_SECRET=$(node -e "console.log(require('crypto').randomBytes(64).toString('base64'))" 2>/dev/null || echo "jwt_secret")
    ADMIN_JWT_SECRET=$(node -e "console.log(require('crypto').randomBytes(64).toString('base64'))" 2>/dev/null || echo "admin_jwt_secret")
    API_TOKEN_SALT=$(node -e "console.log(require('crypto').randomBytes(32).toString('base64'))" 2>/dev/null || echo "api_token_salt")
    TRANSFER_TOKEN_SALT=$(node -e "console.log(require('crypto').randomBytes(32).toString('base64'))" 2>/dev/null || echo "transfer_token_salt")
    
    # Update environment file with proper escaping
    sed -i "s|your_app_key_1|$APP_KEY_1|g" .env.production
    sed -i "s|your_app_key_2|$APP_KEY_2|g" .env.production
    sed -i "s|your_app_key_3|$APP_KEY_3|g" .env.production
    sed -i "s|your_app_key_4|$APP_KEY_4|g" .env.production
    sed -i "s|your_jwt_secret_here|$JWT_SECRET|g" .env.production
    sed -i "s|your_admin_jwt_secret_here|$ADMIN_JWT_SECRET|g" .env.production
    sed -i "s|your_api_token_salt_here|$API_TOKEN_SALT|g" .env.production
    sed -i "s|your_transfer_token_salt_here|$TRANSFER_TOKEN_SALT|g" .env.production
    
    print_status "Secure secrets generated and updated!"
fi

# 4. Check Database Connection
print_status "4. Checking Database Connection..."
echo "----------------------------------------"

# Start PostgreSQL
sudo systemctl start postgresql || sudo service postgresql start || true

# Test database connection
if sudo -u postgres psql -c "SELECT 1;" > /dev/null 2>&1; then
    print_debug "✅ Database connection successful"
else
    print_error "❌ Database connection failed"
    print_status "Setting up database..."
    
    # Create database and user
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
fi

# 5. Fix File Permissions
print_status "5. Fixing File Permissions..."
echo "----------------------------------------"

# Fix ownership
sudo chown -R $USER:$USER . 2>/dev/null || true

# Fix uploads directory
mkdir -p public/uploads
chmod -R 755 public/uploads

# Fix node_modules permissions
if [ -d "node_modules" ]; then
    chmod -R 755 node_modules
fi

# 6. Clean and Reinstall Dependencies
print_status "6. Cleaning and Reinstalling Dependencies..."
echo "----------------------------------------"

# Remove node_modules and package-lock.json
rm -rf node_modules package-lock.json

# Install dependencies
print_status "Installing dependencies..."
npm install

# 7. Build Application
print_status "7. Building Application..."
echo "----------------------------------------"

# Build with memory optimization
print_status "Building application..."
NODE_OPTIONS="--max-old-space-size=2048" npm run build

# 8. Create Simple PM2 Configuration
print_status "8. Creating Simple PM2 Configuration..."
echo "----------------------------------------"

# Create a simple ecosystem config
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

# 9. Start Strapi with PM2
print_status "9. Starting Strapi with PM2..."
echo "----------------------------------------"

# Start with simple configuration
pm2 start ecosystem.config.js --env production

# Save PM2 configuration
pm2 save

# 10. Test Application
print_status "10. Testing Application..."
echo "----------------------------------------"

# Wait for application to start
print_status "Waiting for application to start..."
sleep 15

# Test health endpoint
print_status "Testing health endpoint..."
if curl -s http://localhost:1337/_health > /dev/null 2>&1; then
    print_debug "✅ Health endpoint responding"
    curl -s http://localhost:1337/_health
else
    print_error "❌ Health endpoint not responding"
    print_debug "Checking PM2 logs..."
    pm2 logs strapi --lines 20
fi

# Test main application
print_status "Testing main application..."
if curl -s http://localhost:1337 > /dev/null 2>&1; then
    print_debug "✅ Main application responding"
else
    print_error "❌ Main application not responding"
fi

# 11. Show Final Status
print_status "11. Final Status..."
echo "----------------------------------------"

print_debug "PM2 Status:"
pm2 status

print_debug "Port 1337:"
netstat -tlnp | grep 1337 || echo "Port 1337 not in use"

print_debug "PM2 Logs (last 20 lines):"
pm2 logs strapi --lines 20

echo ""
print_status "🔧 Restart loop fix applied!"
print_warning "If issues persist:"
echo "1. Check logs: pm2 logs strapi"
echo "2. Check database: sudo -u postgres psql -c 'SELECT version();'"
echo "3. Restart services: pm2 restart strapi"
echo "4. Check Nginx: sudo systemctl status nginx"
