#!/bin/bash

# Strapi Production Deployment Script
# Server: 165.232.76.106

set -e

echo "🚀 Starting Strapi Production Deployment..."

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

# Install PM2 for process management (alternative to Docker)
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

# Create environment file from template
if [ ! -f .env.production ]; then
    print_warning "Creating .env.production from template..."
    cp .env.production .env.production.template
    print_warning "Please edit .env.production with your actual values!"
fi

# Install dependencies
print_status "Installing dependencies..."
npm install

# Build the application
print_status "Building the application..."
npm run build

# Create systemd service for PM2
print_status "Creating systemd service..."
sudo tee /etc/systemd/system/strapi.service > /dev/null <<EOF
[Unit]
Description=Strapi Application
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$APP_DIR
Environment=NODE_ENV=production
ExecStart=/usr/bin/pm2 start ecosystem.config.js --env production
ExecReload=/usr/bin/pm2 reload ecosystem.config.js --env production
ExecStop=/usr/bin/pm2 stop ecosystem.config.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create PM2 ecosystem file
print_status "Creating PM2 ecosystem configuration..."
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
    max_memory_restart: '4G', // Increased memory limit
    node_args: '--max-old-space-size=4096', // Increase Node.js heap size
    env: {
      NODE_ENV: 'production',
      PORT: 1337,
      NODE_OPTIONS: '--max-old-space-size=4096'
    }
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

# Create database setup script
print_status "Creating database setup script..."
cat > setup-database.sh <<'EOF'
#!/bin/bash

# Database setup script
echo "Setting up PostgreSQL database..."

# Install PostgreSQL
sudo apt update
sudo apt install -y postgresql postgresql-contrib

# Start PostgreSQL service
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create database and user
sudo -u postgres psql <<EOSQL
CREATE DATABASE strapi_production;
CREATE USER strapi_user WITH ENCRYPTED PASSWORD 'your_secure_password_here';
GRANT ALL PRIVILEGES ON DATABASE strapi_production TO strapi_user;
ALTER USER strapi_user CREATEDB;
EOSQL

# Configure PostgreSQL
sudo -u postgres psql -c "ALTER USER strapi_user CREATEDB;"

echo "Database setup completed!"
echo "Please update your .env.production file with the correct database credentials."
EOF

chmod +x setup-database.sh

print_status "Deployment script completed!"
print_warning "Next steps:"
echo "1. Edit .env.production with your actual values"
echo "2. Run ./setup-database.sh to set up PostgreSQL"
echo "3. Start the application with: sudo systemctl start strapi"
echo "4. Check status with: sudo systemctl status strapi"
echo "5. View logs with: pm2 logs strapi"

print_status "🎉 Deployment setup completed!"
