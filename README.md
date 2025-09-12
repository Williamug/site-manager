# Site Manager

![Build Status](https://img.shields.io/badge/build-passing-brightgreen)
![License](https://img.shields.io/badge/license-MIT-blue)
![Version](https://img.shields.io/badge/version-2.0-blue)
![Downloads](https://img.shields.io/github/downloads/williamug/site-manager/total?style=flat-square&logo=github)
![Stars](https://img.shields.io/github/stars/williamug/site-manager?style=flat-square&logo=github)

A comprehensive solution for server administration and web project management with advanced SSL, backup, and permission management features.

## Features

### Server Management
- **Automated Setup**: Install & configure Nginx, PHP (8.1-8.4), MySQL, Composer, Node.js and NPM
- **Dependency Verification**: Check system requirements and component versions
- **Permission Management**: Advanced file permission fixing with Laravel-specific support
- **User Management**: Automatic www-data group configuration

### Project Management
- **Site Creation**: Create new PHP/Laravel projects with automatic configuration
- **Project Migration**: Move existing projects to /var/www with proper setup
- **GitHub Integration**: Clone repositories directly with dependency installation
- **Project Configuration**: Configure existing projects in /var/www with domain setup
- **Site Deletion**: Clean removal of projects, configurations, and files

### SSL & Security
- **Let's Encrypt Integration**: Automatic SSL certificate setup and configuration
- **Certificate Management**: Renew, update, and expand existing certificates
- **Certificate Monitoring**: Check expiration status across all domains
- **Security Headers**: Automatic security header configuration

### Backup & Restore
- **Comprehensive Backups**: Full project code and database backups
- **Flexible Destinations**: Custom backup locations and naming
- **Multiple Formats**: Support for .tar.gz and .zip archives
- **Database Support**: MySQL/SQLite database backup and restore
- **Selective Backup**: Choose code-only, database-only, or combined backups

### Advanced Permission Management
- **Quick Fix**: Standard permission repairs for common issues
- **Full Reset**: Complete permission reset with ACL support
- **Laravel Specific**: Targeted fixes for Laravel storage/cache/database issues
- **Web Server Only**: Basic web server permissions for simple projects
- **SQLite Support**: Automatic SQLite database permission handling

## Installation

```bash
# Install Site Manager
sudo curl -L https://raw.githubusercontent.com/williamug/site-manager/main/site-manager.sh -o /usr/local/bin/site-manager

sudo chmod +x /usr/local/bin/site-manager

# Verify installation
site-manager check
```

### Alternative Installation with Analytics
```bash
# One-liner installation with install tracking
curl -s https://api.github.com/repos/williamug/site-manager/releases/latest | grep browser_download_url | cut -d '"' -f 4 | wget -qi - && sudo chmod +x site-manager.sh && sudo mv site-manager.sh /usr/local/bin/site-manager
```

## Uninstallation
```bash
sudo rm /usr/local/bin/site-manager
```

## Usage

### Initial Setup
```bash
# Check system requirements
site-manager check

# Complete server setup wizard
sudo site-manager setup

# Start interactive menu
sudo site-manager
```

### Command Line Interface
```bash
# Direct commands
sudo site-manager <command> [options]

# Interactive menu (recommended)
sudo site-manager
```

## Command Reference

### Basic Commands
| Command | Description | Example |
|---------|-------------|---------|
| `check` | Verify system dependencies | `site-manager check` |
| `setup` | Install server components | `sudo site-manager setup` |
| `configure` | Configure existing project | `sudo site-manager configure` |
| `fix-permissions` | Fix project permissions | `sudo site-manager fix-permissions` |

### SSL Management
| Command | Description | Example |
|---------|-------------|---------|
| `ssl <domain>` | Setup Let's Encrypt SSL | `sudo site-manager ssl example.com` |
| `update-ssl [domain]` | Renew/update certificates | `sudo site-manager update-ssl` |

### Backup & Restore
| Command | Description | Example |
|---------|-------------|---------|
| `backup <domain>` | Create project backup | `sudo site-manager backup example.com` |
| `restore <path>` | Restore from backup | `sudo site-manager restore /path/backup.tar.gz` |

## Interactive Menu Options

When you run `sudo site-manager`, you'll see these options:

1. **Create New Project** - Set up new PHP/Laravel projects
2. **Delete Existing Project** - Remove projects and configurations
3. **Move Project** - Migrate existing projects to /var/www
4. **Clone from GitHub** - Clone and configure Git repositories
5. **Backup Project** - Create comprehensive project backups
6. **Restore Project** - Restore from backup archives
7. **Setup SSL** - Configure Let's Encrypt certificates
8. **Configure Existing Project** - Set up domains for existing projects
9. **Fix Project Permissions** - Advanced permission management
10. **Update/Renew SSL Certificate** - Manage existing certificates
11. **Exit** - Close Site Manager

## Workflow Examples

### Creating a New Laravel Project
```bash
sudo site-manager
# Select: 1) Create New Project
# Domain: myapp.test
# Path: myapp
# Laravel: Y
# Result: Full Laravel installation with proper permissions
```

### Moving an Existing Project
```bash
sudo site-manager
# Select: 3) Move Project
# Source: /home/user/my-project
# Domain: myproject.test
# Result: Project moved to /var/www with Nginx configuration
```

### Cloning from GitHub
```bash
sudo site-manager
# Select: 4) Clone from GitHub
# Repository: https://github.com/user/laravel-app.git
# Domain: myapp.test
# Result: Cloned, configured, and dependencies installed
```

### SSL Certificate Management
```bash
# Setup SSL for a domain
sudo site-manager ssl myapp.test

# Check all certificate statuses
sudo site-manager update-ssl
# Select: 5) Check all certificates status
```

### Advanced Permission Fixes
```bash
sudo site-manager fix-permissions
# Options:
# 1) Quick Fix - Standard permission repair
# 2) Full Reset - Complete reset with ACL
# 3) Laravel Specific - Storage/cache/database focus
# 4) Web Server Only - Basic web permissions
```

### Comprehensive Backup Strategy
```bash
# Create full backup (code + database)
sudo site-manager backup myapp.test

# Custom backup location
sudo site-manager
# Select: 5) Backup Project
# Enter custom destination: /home/user/backups
# Choose: 1) Both project code and database

# Restore from backup
sudo site-manager restore /backups/myapp_20241212_143022.tar.gz
```

## Project Type Support

### Laravel Projects
- Automatic detection via `artisan` and `composer.json`
- Proper `storage/` and `bootstrap/cache/` permissions
- `.env` file creation from `.env.example`
- Composer dependency installation
- Application key generation
- Database migration support
- NPM dependency handling

### Standard PHP Projects
- Basic Nginx configuration
- Standard file permissions
- Welcome page creation
- Custom document root support

### Static Sites
- Basic web server permissions
- Simple Nginx configuration
- No special handling required

## Security Features

### SSL/TLS
- Automatic Let's Encrypt certificate generation
- Certificate renewal and monitoring
- Security header configuration
- HTTP to HTTPS redirects
- Multi-domain certificate support

### File Permissions
- User/group ownership management
- ACL (Access Control List) support
- Laravel-specific permission handling
- SQLite database permission fixes
- Secure file permission defaults

### Server Hardening
- Nginx security headers
- PHP security configuration
- MySQL secure installation
- Proper file ownership chains

## Troubleshooting

### Common Issues

**Permission Errors**
```bash
# Try Laravel-specific fix first
sudo site-manager fix-permissions
# Select: 3) Laravel Specific

# If that doesn't work, use Full Reset
# Select: 2) Full Reset
```

**SSL Certificate Issues**
```bash
# Check certificate status
sudo site-manager update-ssl
# Select: 5) Check all certificates status

# Force renewal if needed
# Select: 2) Force certificate renewal
```

**Database Connection Issues**
```bash
# For Laravel projects with SQLite
sudo site-manager fix-permissions
# Select: 3) Laravel Specific
# This will fix SQLite database permissions
```

**Nginx Configuration Errors**
```bash
# Test configuration
sudo nginx -t

# Reload if valid
sudo systemctl reload nginx
```

### Log Locations
- Nginx logs: `/var/log/nginx/`
- Site-specific logs: `/var/log/nginx/{domain}-access.log`
- Let's Encrypt logs: `/var/log/letsencrypt/`
- Site Manager config: `/etc/site-manager/`

## Support

- **Issues**: [GitHub Issues](https://github.com/williamug/site-manager/issues)
- **Discussions**: [GitHub Discussions](https://github.com/williamug/site-manager/discussions)
- **Documentation**: This README and inline help

## Contributing

We welcome contributions! Please:

1. Fork the repository
2. Create a feature branch
3. Test your changes thoroughly
4. Submit a pull request with clear description

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

## 📄 License

MIT Licensed. See [LICENSE](LICENSE) for details.

---

**Site Manager v2.0** - Making web development server management simple and powerful!
