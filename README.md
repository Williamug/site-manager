# Site Manager 

![Build Status](https://img.shields.io/badge/build-passing-brightgreen)
![License](https://img.shields.io/badge/license-MIT-blue)

A complete solution for server administration and web project management with advanced features.

## Features 

- **Server Setup**: Install & configure Nginx, PHP, MySQL, Node.js and NPM
- **Site Management**: Create/delete/move/clone projects
- **Security**: SSL certificate management, permission hardening
- **Backup System**: Full site backups and restores
- **Dependency Checks**: Verify installed components
- **Interactive Menu**: User-friendly CLI interface

## Installation 

```bash
sudo curl -L https://raw.githubusercontent.com/williamug/site-manager/main/site-manager.sh -o /usr/local/bin/site-manager
sudo chmod +x /usr/local/bin/site-manager
```

## Uninstallation
```bash
sudo rm /usr/local/bin/site-manager
```

## Usage 

### Basic Commands
```bash
# Check system requirements
site-manager check

# Server setup wizard
sudo site-manager setup

# Start interactive menu
sudo site-manager
```

### Advanced Usage
```bash
# Create backup
site-manager backup example.com

# Restore backup
site-manager restore /backups/example.tar.gz

# Setup SSL
site-manager ssl example.com
```

## Command Reference 

| Command           | Description                |
| ----------------- | -------------------------- |
| `check`           | Verify system dependencies |
| `setup`           | Install server components  |
| `backup <domain>` | Create project backup         |
| `restore <path>`  | Restore from backup        |
| `ssl <domain>`    | Setup Let's Encrypt SSL    |

## Workflow Examples 

**Create Laravel Project**
```bash
1) Create New Site
Domain: mysite.test
Path: mysite
Laravel: Y
```

**Backup and Restore**
```bash
site-manager backup mysite.test
```

**Backup Commands**
```bash
  backup <domain> [destination]   // Create backup with optional custom path
  restore <path/to/backup>       // Restore from specific backup file
```
**Backup Example**
```bash
  site-manager backup example.com
  site-manager backup example.com ~/my-backups
  site-manager restore /custom/path/example_backup.tar.gz
```

```bash
# Later...
site-manager restore /backups/mysite.test_20231201.tar.gz
```

**SSL Setup**
```bash
site-manager ssl mysite.test
# Automatically configures HTTPS
```

## Support 

For support, please [open an issue](https://github.com/williamug/site-manager/issues).

## Contributing 

Contributions welcome! Please read our [contribution guidelines](CONTRIBUTING.md).

## License 

MIT Licensed. See [LICENSE](LICENSE) for details.