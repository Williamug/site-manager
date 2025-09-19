# Site Manager

![Build Status](https://img.shields.io/badge/build-passing-brightgreen)
![License](https://img.shields.io/badge/license-MIT-blue)
![Version](https://img.shields.io/github/v/release/williamug/site-manager?style=flat-square&logo=github)
![Downloads](https://img.shields.io/github/downloads/williamug/site-manager/total?style=flat-square&logo=github)
![Stars](https://img.shields.io/github/stars/williamug/site-manager?style=flat-square&logo=github)

A comprehensive solution for server administration and web project management with advanced SSL, backup, permission management, and firewall configuration features.

## Features

### Server Management
- **Automated Setup**: Install & configure Nginx, PHP (8.1-8.4), MySQL, Composer, Node.js and NPM
- **Firewall Configuration**: Automatic UFW firewall setup with web server rules (HTTP/HTTPS/SSH)
- **Memory Optimization**: Smart memory management and swap handling for low-memory servers
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
- **Smart SSL Detection**: Automatically detects local vs public domains
- **Let's Encrypt Integration**: Automatic SSL certificate setup for public domains
- **Self-Signed Certificates**: HTTPS for local development (.test, .local, .dev)
- **Certificate Management**: Renew, update, expand, and remove existing certificates
- **Certificate Monitoring**: Check expiration status across all domains
- **Complete SSL Removal**: Clean removal of SSL configurations and certificates
- **Security Headers**: Automatic security header configuration with modern TLS protocols

### Local Development SSL
- **Automatic Detection**: Smart recognition of `.test`, `.local`, `.dev`, and `localhost` domains
- **Full HTTPS Support**: Complete SSL/TLS functionality for local development
- **Long-Term Certificates**: 10-year validity for hassle-free development
- **Modern Security**: TLS 1.2/1.3 protocols with strong cipher suites
- **Browser Trust**: Optional system-wide certificate trust installation

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

### Installation

```bash
# Enhanced installation with comprehensive progress indicators
curl -fsSL https://raw.githubusercontent.com/williamug/site-manager/main/install.sh | bash

# Verify installation
site-manager check
```

**What you'll see during installation:**
```
┌─────────────────────────────────────────┐
│          Site Manager Installer        │
└─────────────────────────────────────────┘

[INFO] Checking internet connectivity...
[✓] Internet connectivity confirmed
[INFO] Checking required dependencies...
[✓] All required dependencies are available
[INFO] Fetching latest release information...
[✓] Latest version: v3.0.0
[INFO] Downloading Site Manager...
Source: https://github.com/williamug/site-manager/releases/latest/download/site-manager.sh
site-manager.sh      100%[===================>]  175K  425 KB/s    in 0.2s
[✓] Download completed successfully
[INFO] Verifying downloaded file...
[✓] File verification passed (179,456 bytes)
[INFO] Installing Site Manager to /usr/local/bin/site-manager...
[✓] Site Manager installed successfully
[✓] Installation verified - site-manager command is available

🎉 Site Manager Installation Complete!

📋 Next Steps:
  1. Check system requirements: site-manager check
  2. Run initial server setup: sudo site-manager setup
  3. Start using Site Manager: sudo site-manager
```

**Features of the enhanced installer:**
- ✅ **Updates GitHub download statistics** (downloads from GitHub Releases)
- ✅ **Comprehensive progress indicators** with color-coded output
- ✅ **Dependency checking** and automatic installation (curl, wget, jq)
- ✅ **Internet connectivity verification** before starting
- ✅ **File verification** to ensure successful download
- ✅ **Error handling** with helpful error messages
- ✅ **Post-installation guidance** with next steps
- ✅ **Professional installation experience**

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
| `ssl <domain>` | Setup SSL (auto-detects local vs public) | `sudo site-manager ssl example.test` |
| `update-ssl [domain]` | Renew/update certificates | `sudo site-manager update-ssl` |
| `remove-ssl <domain>` | Remove/disable SSL certificates | `sudo site-manager remove-ssl example.com` |
| `check-ssl [domain]` | Check SSL status and health | `sudo site-manager check-ssl example.com` |

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
7. **Setup SSL** - Configure SSL certificates (auto-detects local vs public domains)
8. **Configure Existing Project** - Set up domains for existing projects
9. **Fix Project Permissions** - Advanced permission management
10. **Update/Renew SSL Certificate** - Manage existing certificates
11. **Remove SSL Certificate** - Disable or completely remove SSL
12. **Check SSL Status** - Comprehensive SSL health diagnostics (NEW!)
13. **Exit** - Close Site Manager

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

### Local Development with HTTPS (NEW! 🔥)
```bash
# Setup HTTPS for local Laravel development
sudo site-manager ssl myapp.test
# Automatically detects .test domain
# Creates self-signed certificate
# Configures Nginx with HTTPS redirect
# Result: https://myapp.test works perfectly!

# Also works with other local domains
sudo site-manager ssl api.local
sudo site-manager ssl admin.dev
sudo site-manager ssl localhost:8080
```

### SSL Certificate Management
```bash
# Setup SSL for any domain (smart detection)
sudo site-manager ssl myapp.test          # Creates self-signed for local
sudo site-manager ssl myapp.com           # Uses Let's Encrypt for public

# Check all certificate statuses
sudo site-manager update-ssl
# Select: 5) Check all certificates status

# Remove SSL completely
sudo site-manager remove-ssl myapp.test
# Options:
# 1) Disable SSL in Nginx only (keep certificate)
# 2) Remove Let's Encrypt certificate completely
# 3) Complete SSL removal (both Nginx and certificate)
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
- **Smart Domain Detection**: Automatically chooses Let's Encrypt vs self-signed
- **Local Development SSL**: Full HTTPS for .test/.local/.dev domains
- **Public Domain SSL**: Let's Encrypt certificates for production domains
- **Certificate renewal and monitoring**
- **Security header configuration**
- **HTTP to HTTPS redirects**
- **Multi-domain certificate support**
- **Complete SSL removal options**

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

## Local Development Features (NEW! 🚀)

### Self-Signed SSL Certificates
Site Manager now provides **Laravel Valet-style HTTPS** for local development:

#### Automatic Local Domain Detection
- `.test` domains (e.g., `myapp.test`)
- `.local` domains (e.g., `api.local`)
- `.dev` domains (e.g., `admin.dev`)
- `localhost` variations

#### Features
- **Full HTTPS functionality** for local development
- **Automatic HTTP → HTTPS redirects**
- **10-year certificate validity** (no renewal needed)
- **Modern TLS 1.2/1.3 protocols**
- **Strong cipher suites** for security testing
- **Subject Alternative Names** for wildcard support

#### Perfect for Local Development
```bash
# Laravel projects with HTTPS
sudo site-manager ssl mylaravel.test
# Result: https://mylaravel.test with full SSL

# API development requiring HTTPS
sudo site-manager ssl myapi.local
# Result: Perfect for OAuth callbacks, webhooks

# PWA development (requires HTTPS)
sudo site-manager ssl mypwa.test
# Result: Service workers and HTTPS features work locally
```

#### Browser Trust (Optional)
```bash
# Make browsers trust the certificate system-wide
sudo cp /etc/ssl/site-manager/myapp.test.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates

# Or accept the browser warning once (recommended for dev)
# Chrome/Edge: Click "Advanced" → "Proceed to myapp.test (unsafe)"
# Firefox: Click "Advanced" → "Accept the Risk and Continue"
```

## What's New in v2.1.0 🎉

### SSL Enhancements
- **Self-Signed SSL**: Laravel Valet-style HTTPS for local development
- **Smart Detection**: Automatically detects local vs public domains
- **Universal SSL**: Works with .test, .local, .dev, and localhost domains
- **Modern Security**: TLS 1.2/1.3 with strong cipher suites
- **SSL Removal**: Complete SSL certificate removal options
- **Certificate Monitoring**: Enhanced certificate status checking

### Developer Experience
- **Instant Local HTTPS**: No more "mixed content" errors in development
- **Automatic Redirects**: HTTP automatically redirects to HTTPS
- **PWA Development**: Service workers work with local HTTPS
- **OAuth Testing**: Secure callbacks work in local development
- **API Development**: HTTPS APIs work perfectly locally

### Security & Reliability
- **Enhanced Security Headers**: HSTS, CSP, and modern security headers
- **Better Error Handling**: Improved SSL setup error messages
- **Certificate Management**: Full lifecycle SSL certificate management
- **Health Monitoring**: Comprehensive certificate health checks

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

**Local HTTPS Not Working**
```bash
# Create self-signed certificate for local domain
sudo site-manager ssl myapp.test
# Browser will show security warning - this is normal for self-signed certificates
# Click "Advanced" → "Proceed to myapp.test (unsafe)" to continue

# For system-wide trust (optional)
sudo cp /etc/ssl/site-manager/myapp.test.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
```

**SSL Certificate Issues**
```bash
# Check certificate status
sudo site-manager update-ssl
# Select: 5) Check all certificates status

# For public domains - force renewal if needed
# Select: 2) Force certificate renewal

# For local domains - recreate self-signed certificate
sudo site-manager remove-ssl myapp.test
sudo site-manager ssl myapp.test
```

**Mixed Content Warnings with Local HTTPS**
```bash
# Ensure your application uses HTTPS URLs
# For Laravel, check APP_URL in .env:
# APP_URL=https://myapp.test

# For WordPress, update site URL in database or wp-config.php
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

### Certificate Locations
- **Let's Encrypt certificates**: `/etc/letsencrypt/live/{domain}/`
- **Self-signed certificates**: `/etc/ssl/site-manager/{domain}.crt`
- **Private keys**: `/etc/ssl/site-manager/{domain}.key`
- **Certificate configs**: `/etc/ssl/site-manager/{domain}.conf`

## Support

- **Issues**: [GitHub Issues](https://github.com/williamug/site-manager/issues)
- **Discussions**: [GitHub Discussions](https://github.com/williamug/site-manager/discussions)

## Contributing

We welcome contributions! Please:

1. Fork the repository
2. Create a feature branch
3. Test your changes thoroughly
4. Submit a pull request with clear description

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

## License

MIT Licensed. See [LICENSE](LICENSE) for details.
