#!/bin/bash

# Fix PM2 and PostgreSQL Issues
# For your specific server setup

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

echo "🔧 Fixing PM2 and PostgreSQL Issues"
echo "=================================="

# 1. Check PostgreSQL Service Names
print_status "1. Checking PostgreSQL Service Names..."
echo "----------------------------------------"

# Try different PostgreSQL service names
POSTGRES_SERVICES=("postgresql" "postgres" "postgresql@14-main" "postgresql@15-main")

for service in "${POSTGRES_SERVICES[@]}"; do
    if systemctl list-units --full -all | grep -q "$service"; then
        print_debug "Found PostgreSQL service: $service"
        POSTGRES_SERVICE="$service"
        break
    fi
done

if [ -z "$POSTGRES_SERVICE" ]; then
    print_error "PostgreSQL service not found!"
    print_status "Installing PostgreSQL..."
    sudo apt update
    sudo apt install -y postgresql postgresql-contrib
    POSTGRES_SERVICE="postgresql"
fi

print_debug "Using PostgreSQL service: $POSTGRES_SERVICE"

# 2. Start PostgreSQL
print_status "2. Starting PostgreSQL..."
echo "----------------------------------------"

sudo systemctl start $POSTGRES_SERVICE
sudo systemctl enable $POSTGRES_SERVICE

if systemctl is-active --quiet $POSTGRES_SERVICE; then
    print_debug "✅ PostgreSQL is running"
else
    print_error "❌ PostgreSQL failed to start"
    print_debug "Trying alternative startup methods..."
    
    # Try starting with different methods
    sudo service postgresql start || true
    sudo /etc/init.d/postgresql start || true
fi

# 3. Clean up PM2 Processes
print_status "3. Cleaning up PM2 Processes..."
echo "----------------------------------------"

print_debug "Current PM2 processes:"
pm2 status

# Stop all strapi processes
print_status "Stopping all Strapi processes..."
pm2 stop strapi 2>/dev/null || true
pm2 stop strapiMigration 2>/dev/null || true

# Delete old processes
pm2 delete strapi 2>/dev/null || true
pm2 delete strapiMigration 2>/dev/null || true

print_debug "PM2 processes cleaned up"

# 4. Update Environment Variables
print_status "4. Updating Environment Variables..."
echo "----------------------------------------"

# Check if .env.production exists
if [ -f ".env.production" ]; then
    print_debug "Environment file found"
    
    # Update environment variables with --update-env
    print_status "Updating environment variables..."
    
    # Create a new PM2 ecosystem with updated env
    cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'strapi',
    script: 'npm',
    args: 'start',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '2G',
    node_args: '--max-old-space-size=2048',
    env: {
      NODE_ENV: 'production',
      PORT: 1337
    }
  }]
};
EOF

    print_debug "Ecosystem config updated"
else
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

# 5. Setup Database
print_status "5. Setting up Database..."
echo "----------------------------------------"

# Create database and user
print_status "Creating database and user..."
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

# 6. Install Dependencies and Build
print_status "6. Installing Dependencies and Building..."
echo "----------------------------------------"

# Install dependencies
npm install

# Build application
print_status "Building application..."
NODE_OPTIONS="--max-old-space-size=2048" npm run build

# 7. Start Strapi with PM2
print_status "7. Starting Strapi with PM2..."
echo "----------------------------------------"

# Start with updated environment
pm2 start ecosystem.config.js --env production --update-env

# Save PM2 configuration
pm2 save

# 8. Test Application
print_status "8. Testing Application..."
echo "----------------------------------------"

# Wait for application to start
sleep 10

# Test health endpoint
print_status "Testing health endpoint..."
if curl -s http://localhost:1337/_health > /dev/null 2>&1; then
    print_debug "✅ Health endpoint responding"
    curl -s http://localhost:1337/_health
else
    print_error "❌ Health endpoint not responding"
fi

# Test main application
print_status "Testing main application..."
if curl -s http://localhost:1337 > /dev/null 2>&1; then
    print_debug "✅ Main application responding"
else
    print_error "❌ Main application not responding"
fi

# 9. Show Final Status
print_status "9. Final Status..."
echo "----------------------------------------"

print_debug "PM2 Status:"
pm2 status

print_debug "PostgreSQL Status:"
sudo systemctl status $POSTGRES_SERVICE --no-pager -l

print_debug "Port 1337:"
netstat -tlnp | grep 1337 || echo "Port 1337 not in use"

echo ""
print_status "🔧 Fixes applied!"
print_warning "If issues persist:"
echo "1. Check logs: pm2 logs strapi"
echo "2. Check database: sudo -u postgres psql -c 'SELECT version();'"
echo "3. Restart services: pm2 restart strapi"
