# Strapi Production Setup Guide

## Server Information
- **Server IP**: 165.232.76.106
- **Database**: PostgreSQL
- **Environment**: Production

## Prerequisites

### 1. Server Access
Make sure you have SSH access to the server:
```bash
ssh root@165.232.76.106
# or
ssh your_username@165.232.76.106
```

### 2. Required Software
- Node.js 18.x
- PostgreSQL 15+
- Docker & Docker Compose (optional)
- PM2 (for process management)
- Nginx (for reverse proxy)

## Quick Deployment

### Option 1: Automated Deployment (Recommended)
```bash
# Upload your project to the server
scp -r /path/to/your/project root@165.232.76.106:/opt/strapi

# SSH into the server
ssh root@165.232.76.106

# Navigate to project directory
cd /opt/strapi

# Run the deployment script
./deploy.sh
```

### Option 2: Manual Setup

#### Step 1: Install Dependencies
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Node.js 18
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install PostgreSQL
sudo apt install -y postgresql postgresql-contrib

# Install PM2
sudo npm install -g pm2

# Install Docker (optional)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

#### Step 2: Database Setup
```bash
# Start PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create database and user
sudo -u postgres psql
```

In PostgreSQL console:
```sql
CREATE DATABASE strapi_production;
CREATE USER strapi_user WITH ENCRYPTED PASSWORD 'your_secure_password';
GRANT ALL PRIVILEGES ON DATABASE strapi_production TO strapi_user;
ALTER USER strapi_user CREATEDB;
\q
```

#### Step 3: Configure Environment
```bash
# Copy and edit environment file
cp .env.production .env.production.local
nano .env.production.local
```

Update the following values in `.env.production.local`:
```env
# Database Configuration
DATABASE_CLIENT=postgres
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_NAME=strapi_production
DATABASE_USERNAME=strapi_user
DATABASE_PASSWORD=your_actual_secure_password

# Generate secure secrets
APP_KEYS=key1,key2,key3,key4
JWT_SECRET=your_jwt_secret_here
ADMIN_JWT_SECRET=your_admin_jwt_secret_here
API_TOKEN_SALT=your_api_token_salt_here
TRANSFER_TOKEN_SALT=your_transfer_token_salt_here
```

#### Step 4: Install Dependencies and Build
```bash
# Install dependencies
npm install

# Build the application
npm run build
```

#### Step 5: Start the Application

**Option A: Using PM2 (Recommended)**
```bash
# Create PM2 ecosystem file
cat > ecosystem.config.js <<EOF
module.exports = {
  apps: [{
    name: 'strapi',
    script: 'npm',
    args: 'start',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: 1337
    }
  }]
};
EOF

# Start with PM2
pm2 start ecosystem.config.js --env production
pm2 save
pm2 startup
```

**Option B: Using Docker Compose**
```bash
# Start with Docker Compose
docker-compose -f docker-compose.production.yml up -d
```

#### Step 6: Setup Nginx Reverse Proxy
```bash
# Install Nginx
sudo apt install -y nginx

# Copy nginx configuration
sudo cp nginx.conf /etc/nginx/nginx.conf

# Test and restart Nginx
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl enable nginx
```

#### Step 7: Configure Firewall
```bash
# Allow necessary ports
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 1337/tcp
sudo ufw --force enable
```

## Environment Configuration

### Generate Secure Secrets
```bash
# Generate APP_KEYS (4 random strings)
node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"

# Generate JWT_SECRET
node -e "console.log(require('crypto').randomBytes(64).toString('base64'))"

# Generate ADMIN_JWT_SECRET
node -e "console.log(require('crypto').randomBytes(64).toString('base64'))"

# Generate API_TOKEN_SALT
node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"

# Generate TRANSFER_TOKEN_SALT
node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"
```

## Monitoring and Maintenance

### Check Application Status
```bash
# PM2 status
pm2 status
pm2 logs strapi

# Docker status (if using Docker)
docker-compose -f docker-compose.production.yml ps
docker-compose -f docker-compose.production.yml logs
```

### Database Backup
```bash
# Create backup
pg_dump -h localhost -U strapi_user -d strapi_production > backup_$(date +%Y%m%d_%H%M%S).sql

# Restore backup
psql -h localhost -U strapi_user -d strapi_production < backup_file.sql
```

### Application Updates
```bash
# Stop application
pm2 stop strapi

# Pull latest changes
git pull origin main

# Install new dependencies
npm install

# Build application
npm run build

# Start application
pm2 start strapi
```

## Security Considerations

1. **Change default passwords** in `.env.production`
2. **Use SSL certificates** for HTTPS
3. **Regular security updates** for the server
4. **Database backups** on a regular schedule
5. **Monitor logs** for suspicious activity
6. **Use strong secrets** for all JWT and API tokens

## Troubleshooting

### Common Issues

1. **Database Connection Issues**
   - Check PostgreSQL is running: `sudo systemctl status postgresql`
   - Verify database credentials in `.env.production`
   - Check firewall settings

2. **Application Won't Start**
   - Check logs: `pm2 logs strapi`
   - Verify environment variables
   - Check port availability: `netstat -tlnp | grep 1337`

3. **Nginx Issues**
   - Test configuration: `sudo nginx -t`
   - Check logs: `sudo tail -f /var/log/nginx/error.log`

### Useful Commands
```bash
# Check application status
pm2 status
pm2 logs strapi --lines 100

# Restart application
pm2 restart strapi

# Check database connection
sudo -u postgres psql -c "SELECT version();"

# Check disk space
df -h

# Check memory usage
free -h

# Check running processes
ps aux | grep strapi
```

## Access URLs

- **Application**: http://165.232.76.106:1337
- **Admin Panel**: http://165.232.76.106:1337/admin
- **API**: http://165.232.76.106:1337/api

## Support

For issues or questions:
1. Check the logs first
2. Verify all environment variables
3. Ensure all services are running
4. Check firewall and network settings
