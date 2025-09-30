#!/bin/bash

# Strapi Production Deployment Script - Maximum RAM Configuration
# Server: 165.232.76.106

set -e

echo "🚀 Starting Strapi Production Deployment with Maximum RAM Configuration..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Get system memory info
TOTAL_MEM=$(free -m | awk 'NR==2{printf "%.0f", $2}')
AVAILABLE_MEM=$(free -m | awk 'NR==2{printf "%.0f", $7}')
print_status "Total System Memory: ${TOTAL_MEM}MB"
print_status "Available Memory: ${AVAILABLE_MEM}MB"

# Calculate optimal memory settings
NODE_HEAP_SIZE=$((TOTAL_MEM * 70 / 100))  # Use 70% of total RAM for Node.js
PM2_MEMORY_LIMIT=$((TOTAL_MEM * 80 / 100))  # PM2 restart at 80% of total RAM
DB_POOL_MAX=$((TOTAL_MEM / 100))  # Database pool based on available memory

print_status "Configured Node.js heap size: ${NODE_HEAP_SIZE}MB"
print_status "Configured PM2 memory limit: ${PM2_MEMORY_LIMIT}MB"
print_status "Configured database pool max: ${DB_POOL_MAX}"

# Check if running on the correct server
if [ "$(hostname -I | awk '{print $1}')" != "165.232.76.106" ]; then
    print_warning "This script is designed for server 165.232.76.106"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Update system packages
print_status "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install Docker and Docker Compose
print_status "Installing Docker and Docker Compose..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
fi

if ! command -v docker-compose &> /dev/null; then
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# Install Node.js (for development and debugging)
print_status "Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install PM2 for process management
print_status "Installing PM2..."
sudo npm install -g pm2

# Create application directory
APP_DIR="/opt/strapi"
print_status "Setting up application directory at $APP_DIR..."
sudo mkdir -p $APP_DIR
sudo chown $USER:$USER $APP_DIR

# Copy application files
print_status "Copying application files..."
cp -r . $APP_DIR/
cd $APP_DIR

# Create memory-optimized environment file
print_status "Creating memory-optimized environment configuration..."
cat > .env.production <<EOF
# Production Environment Configuration - Memory Optimized
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

# Database Pool Configuration - Memory Optimized
DATABASE_POOL_MIN=4
DATABASE_POOL_MAX=${DB_POOL_MAX}
DATABASE_CONNECTION_TIMEOUT=60000

# Memory Optimization
NODE_OPTIONS=--max-old-space-size=${NODE_HEAP_SIZE}
UV_THREADPOOL_SIZE=16
NODE_ENV=production
EOF

# Install dependencies
print_status "Installing dependencies..."
npm install

# Build the application with memory optimization
print_status "Building the application with memory optimization..."
NODE_OPTIONS="--max-old-space-size=${NODE_HEAP_SIZE}" npm run build

# Create systemd service for PM2 with memory optimization
print_status "Creating systemd service with memory optimization..."
sudo tee /etc/systemd/system/strapi.service > /dev/null <<EOF
[Unit]
Description=Strapi Application - Memory Optimized
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$APP_DIR
Environment=NODE_ENV=production
Environment=NODE_OPTIONS=--max-old-space-size=${NODE_HEAP_SIZE}
ExecStart=/usr/bin/pm2 start ecosystem.config.js --env production
ExecReload=/usr/bin/pm2 reload ecosystem.config.js --env production
ExecStop=/usr/bin/pm2 stop ecosystem.config.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create PM2 ecosystem file with maximum memory configuration
print_status "Creating PM2 ecosystem configuration with maximum memory..."
cat > ecosystem.config.js <<EOF
module.exports = {
  apps: [{
    name: 'strapi',
    script: 'npm',
    args: 'start',
    cwd: '$APP_DIR',
    instances: 'max', // Use all CPU cores
    autorestart: true,
    watch: false,
    max_memory_restart: '${PM2_MEMORY_LIMIT}M', // Dynamic memory limit
    node_args: '--max-old-space-size=${NODE_HEAP_SIZE}', // Dynamic heap size
    env: {
      NODE_ENV: 'production',
      PORT: 1337,
      NODE_OPTIONS: '--max-old-space-size=${NODE_HEAP_SIZE}',
      UV_THREADPOOL_SIZE: '16'
    },
    // Memory monitoring
    min_uptime: '10s',
    max_restarts: 10,
    // Performance optimization
    exec_mode: 'cluster',
    kill_timeout: 5000,
    wait_ready: true,
    listen_timeout: 10000
  }]
};
EOF

# Setup firewall
print_status "Configuring firewall..."
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 1337/tcp
sudo ufw --force enable

# Create memory-optimized database setup script
print_status "Creating memory-optimized database setup script..."
cat > setup-database.sh <<EOF
#!/bin/bash

# Memory-optimized database setup script
echo "Setting up PostgreSQL database with memory optimization..."

# Install PostgreSQL
sudo apt update
sudo apt install -y postgresql postgresql-contrib

# Start PostgreSQL service
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Optimize PostgreSQL for memory usage
TOTAL_MEM=\$(free -m | awk 'NR==2{printf "%.0f", \$2}')
SHARED_BUFFERS=\$((TOTAL_MEM / 4))
EFFECTIVE_CACHE_SIZE=\$((TOTAL_MEM * 3 / 4))
WORK_MEM=\$((TOTAL_MEM / 8))

echo "Optimizing PostgreSQL for ${TOTAL_MEM}MB RAM..."
echo "Shared buffers: ${SHARED_BUFFERS}MB"
echo "Effective cache size: ${EFFECTIVE_CACHE_SIZE}MB"
echo "Work memory: ${WORK_MEM}MB"

# Create optimized PostgreSQL configuration
sudo tee -a /etc/postgresql/*/main/postgresql.conf > /dev/null <<EOCONF

# Memory optimization settings
shared_buffers = ${SHARED_BUFFERS}MB
effective_cache_size = ${EFFECTIVE_CACHE_SIZE}MB
work_mem = ${WORK_MEM}MB
maintenance_work_mem = ${SHARED_BUFFERS}MB
max_connections = 100
shared_preload_libraries = 'pg_stat_statements'
EOCONF

# Restart PostgreSQL with new settings
sudo systemctl restart postgresql

# Create database and user
sudo -u postgres psql <<EOSQL
CREATE DATABASE strapi_production;
CREATE USER strapi_user WITH ENCRYPTED PASSWORD 'your_secure_password_here';
GRANT ALL PRIVILEGES ON DATABASE strapi_production TO strapi_user;
ALTER USER strapi_user CREATEDB;
EOSQL

echo "Memory-optimized database setup completed!"
echo "PostgreSQL configured for ${TOTAL_MEM}MB system memory"
EOF

chmod +x setup-database.sh

# Create memory monitoring script
print_status "Creating memory monitoring script..."
cat > monitor-memory.sh <<EOF
#!/bin/bash

echo "=== Memory Usage Report ==="
echo "Date: \$(date)"
echo ""

echo "=== System Memory ==="
free -h
echo ""

echo "=== Node.js Processes ==="
ps aux | grep node | grep -v grep
echo ""

echo "=== PM2 Status ==="
pm2 status
echo ""

echo "=== Database Connections ==="
sudo -u postgres psql -c "SELECT count(*) as active_connections FROM pg_stat_activity WHERE state = 'active';"
echo ""

echo "=== Top Memory Consumers ==="
ps aux --sort=-%mem | head -10
EOF

chmod +x monitor-memory.sh

print_status "Memory-optimized deployment script completed!"
print_warning "Next steps:"
echo "1. Edit .env.production with your actual values"
echo "2. Run ./setup-database.sh to set up optimized PostgreSQL"
echo "3. Start the application with: sudo systemctl start strapi"
echo "4. Monitor memory usage with: ./monitor-memory.sh"
echo "5. Check status with: sudo systemctl status strapi"
echo "6. View logs with: pm2 logs strapi"

print_status "🎉 Memory-optimized deployment setup completed!"
print_status "Configured for ${TOTAL_MEM}MB total system memory"
print_status "Node.js heap size: ${NODE_HEAP_SIZE}MB"
print_status "PM2 memory limit: ${PM2_MEMORY_LIMIT}MB"
