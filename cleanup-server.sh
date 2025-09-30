#!/bin/bash

# Cleanup Server for Fresh Start
# This script will remove the current Strapi setup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[CLEANING]${NC} $1"
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

echo "🧹 Cleaning Up Server for Fresh Start"
echo "====================================="

# 1. Stop and Remove PM2 Processes
print_status "1. Stopping and Removing PM2 Processes..."
echo "----------------------------------------"
pm2 kill
print_debug "✅ PM2 processes stopped and removed"
echo ""

# 2. Remove PM2 Configuration
print_status "2. Removing PM2 Configuration..."
echo "----------------------------------------"
pm2 unstartup 2>/dev/null || true
print_debug "✅ PM2 startup configuration removed"
echo ""

# 3. Stop PostgreSQL (if you want to remove it completely)
print_status "3. Stopping PostgreSQL..."
echo "----------------------------------------"
sudo systemctl stop postgresql 2>/dev/null || true
print_debug "✅ PostgreSQL stopped"
echo ""

# 4. Remove Database (if you want to start fresh)
print_status "4. Removing Database..."
echo "----------------------------------------"
sudo -u postgres psql -c "DROP DATABASE IF EXISTS strapi_production;" 2>/dev/null || true
sudo -u postgres psql -c "DROP USER IF EXISTS strapi_user;" 2>/dev/null || true
print_debug "✅ Database and user removed"
echo ""

# 5. Remove Application Directory
print_status "5. Removing Application Directory..."
echo "----------------------------------------"
if [ -d "/opt/strapi" ]; then
    sudo rm -rf /opt/strapi
    print_debug "✅ Application directory removed"
else
    print_debug "Application directory not found"
fi
echo ""

# 6. Remove Current Project Directory
print_status "6. Removing Current Project Directory..."
echo "----------------------------------------"
cd ..
if [ -d "strapiMigration" ]; then
    rm -rf strapiMigration
    print_debug "✅ Project directory removed"
else
    print_debug "Project directory not found"
fi
echo ""

# 7. Remove Nginx Configuration (if exists)
print_status "7. Removing Nginx Configuration..."
echo "----------------------------------------"
if [ -f "/etc/nginx/nginx.conf" ]; then
    sudo rm -f /etc/nginx/nginx.conf
    print_debug "✅ Nginx configuration removed"
fi
echo ""

# 8. Remove Docker Containers (if using Docker)
print_status "8. Removing Docker Containers..."
echo "----------------------------------------"
docker-compose -f docker-compose.production.yml down 2>/dev/null || true
docker system prune -f 2>/dev/null || true
print_debug "✅ Docker containers removed"
echo ""

# 9. Clean Up Logs
print_status "9. Cleaning Up Logs..."
echo "----------------------------------------"
sudo rm -rf /var/log/pm2* 2>/dev/null || true
sudo rm -rf /home/app/.pm2 2>/dev/null || true
print_debug "✅ Logs cleaned up"
echo ""

# 10. Remove Node.js and Dependencies (if you want to start completely fresh)
print_status "10. Removing Node.js and Dependencies..."
echo "----------------------------------------"
read -p "Do you want to remove Node.js and npm completely? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo apt remove -y nodejs npm 2>/dev/null || true
    print_debug "✅ Node.js and npm removed"
else
    print_debug "Node.js and npm kept"
fi
echo ""

# 11. Remove PostgreSQL (if you want to start completely fresh)
print_status "11. Removing PostgreSQL..."
echo "----------------------------------------"
read -p "Do you want to remove PostgreSQL completely? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo apt remove -y postgresql postgresql-contrib 2>/dev/null || true
    sudo rm -rf /var/lib/postgresql 2>/dev/null || true
    print_debug "✅ PostgreSQL removed"
else
    print_debug "PostgreSQL kept"
fi
echo ""

# 12. Remove Docker (if you want to start completely fresh)
print_status "12. Removing Docker..."
echo "----------------------------------------"
read -p "Do you want to remove Docker completely? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo apt remove -y docker.io docker-compose 2>/dev/null || true
    sudo rm -rf /var/lib/docker 2>/dev/null || true
    print_debug "✅ Docker removed"
else
    print_debug "Docker kept"
fi
echo ""

# 13. Clean Up System
print_status "13. Cleaning Up System..."
echo "----------------------------------------"
sudo apt autoremove -y 2>/dev/null || true
sudo apt autoclean 2>/dev/null || true
print_debug "✅ System cleaned up"
echo ""

# 14. Final Status
print_status "14. Final Status..."
echo "----------------------------------------"
print_debug "PM2 Status:"
pm2 status 2>/dev/null || echo "PM2 not running"
echo ""

print_debug "PostgreSQL Status:"
sudo systemctl status postgresql --no-pager 2>/dev/null || echo "PostgreSQL not running"
echo ""

print_debug "Docker Status:"
docker --version 2>/dev/null || echo "Docker not installed"
echo ""

print_debug "Node.js Status:"
node --version 2>/dev/null || echo "Node.js not installed"
echo ""

print_debug "Current Directory:"
pwd
ls -la
echo ""

print_status "🧹 Server cleanup completed!"
print_warning "You can now start a fresh project!"
print_warning "Next steps:"
echo "1. Create a new project directory"
echo "2. Install fresh dependencies"
echo "3. Set up a new database"
echo "4. Configure your new application"
