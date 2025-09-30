# Deployment Checklist

## Pre-Deployment

- [ ] **Server Access**: Confirm SSH access to 165.232.76.106
- [ ] **Domain/DNS**: Point domain to server IP (if using custom domain)
- [ ] **SSL Certificate**: Obtain SSL certificate for HTTPS (optional but recommended)
- [ ] **Backup Strategy**: Plan for database and file backups

## Environment Setup

- [ ] **Generate Secrets**: Create secure random strings for:
  - [ ] APP_KEYS (4 keys)
  - [ ] JWT_SECRET
  - [ ] ADMIN_JWT_SECRET
  - [ ] API_TOKEN_SALT
  - [ ] TRANSFER_TOKEN_SALT
- [ ] **Database Credentials**: Set strong PostgreSQL password
- [ ] **Environment File**: Update `.env.production` with actual values

## Server Preparation

- [ ] **Update System**: `sudo apt update && sudo apt upgrade -y`
- [ ] **Install Dependencies**: Node.js, PostgreSQL, PM2, Nginx
- [ ] **Configure Firewall**: Allow ports 22, 80, 443, 1337
- [ ] **Create Application Directory**: `/opt/strapi`

## Database Setup

- [ ] **Install PostgreSQL**: `sudo apt install postgresql postgresql-contrib`
- [ ] **Start PostgreSQL**: `sudo systemctl start postgresql`
- [ ] **Create Database**: `strapi_production`
- [ ] **Create User**: `strapi_user` with secure password
- [ ] **Grant Privileges**: Full access to database and schema
- [ ] **Test Connection**: Verify database connectivity

## Application Deployment

- [ ] **Upload Code**: Transfer project files to server
- [ ] **Install Dependencies**: `npm install`
- [ ] **Build Application**: `npm run build`
- [ ] **Configure PM2**: Create ecosystem.config.js
- [ ] **Start Application**: `pm2 start strapi`
- [ ] **Save PM2 Config**: `pm2 save`
- [ ] **Enable Auto-start**: `pm2 startup`

## Reverse Proxy Setup

- [ ] **Install Nginx**: `sudo apt install nginx`
- [ ] **Configure Nginx**: Copy nginx.conf to /etc/nginx/
- [ ] **Test Configuration**: `sudo nginx -t`
- [ ] **Start Nginx**: `sudo systemctl start nginx`
- [ ] **Enable Nginx**: `sudo systemctl enable nginx`

## Security Configuration

- [ ] **Change Default Passwords**: All default credentials
- [ ] **Configure SSL**: HTTPS setup (if using domain)
- [ ] **Security Headers**: Verify Nginx security headers
- [ ] **Rate Limiting**: Confirm API rate limits
- [ ] **File Permissions**: Secure file and directory permissions

## Testing

- [ ] **Health Check**: Visit `http://165.232.76.106/_health`
- [ ] **Application**: Visit `http://165.232.76.106:1337`
- [ ] **Admin Panel**: Visit `http://165.232.76.106:1337/admin`
- [ ] **API Endpoints**: Test API functionality
- [ ] **Database Connection**: Verify data persistence
- [ ] **File Uploads**: Test file upload functionality

## Monitoring Setup

- [ ] **PM2 Monitoring**: `pm2 monit`
- [ ] **Log Rotation**: Configure log rotation
- [ ] **Database Backups**: Set up automated backups
- [ ] **System Monitoring**: CPU, memory, disk usage
- [ ] **Error Tracking**: Monitor application errors

## Post-Deployment

- [ ] **Create Admin User**: Set up first admin account
- [ ] **Configure Content Types**: Set up your content structure
- [ ] **API Permissions**: Configure public/private API access
- [ ] **File Storage**: Configure upload directories
- [ ] **Email Configuration**: Set up email notifications (if needed)

## Maintenance Tasks

- [ ] **Regular Backups**: Database and file backups
- [ ] **Security Updates**: Keep system and dependencies updated
- [ ] **Log Monitoring**: Regular log review
- [ ] **Performance Monitoring**: Track application performance
- [ ] **SSL Certificate Renewal**: If using SSL certificates

## Troubleshooting Commands

```bash
# Check application status
pm2 status
pm2 logs strapi

# Check database
sudo systemctl status postgresql
sudo -u postgres psql -c "SELECT version();"

# Check Nginx
sudo systemctl status nginx
sudo nginx -t

# Check system resources
htop
df -h
free -h

# Check network
netstat -tlnp | grep 1337
```

## Rollback Plan

- [ ] **Backup Current State**: Before any changes
- [ ] **Database Backup**: Full database dump
- [ ] **File Backup**: Application files backup
- [ ] **Rollback Procedure**: Document rollback steps
- [ ] **Testing Rollback**: Verify rollback works

## Success Criteria

- [ ] Application accessible at server IP
- [ ] Admin panel functional
- [ ] API endpoints responding
- [ ] Database connectivity confirmed
- [ ] File uploads working
- [ ] Health check endpoint responding
- [ ] No critical errors in logs
- [ ] Performance within acceptable limits
