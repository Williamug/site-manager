# Security Policy

## Supported Versions

We actively support the following versions of Site Manager:

| Version | Supported          |
| ------- | ------------------ |
| 3.0.x   | :white_check_mark: |
| 2.1.x   | :white_check_mark: |
| 2.0.x   | :x:                |
| < 2.0   | :x:                |

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability, please follow these steps:

### 1. Do NOT open a public issue
Security vulnerabilities should not be reported publicly to avoid potential exploitation.

### 2. Report privately
- **Email**: Send details to the repository owner via GitHub
- **GitHub Security**: Use GitHub's private vulnerability reporting feature
- **Include**: Detailed description, steps to reproduce, potential impact

### 3. What to include in your report
- Description of the vulnerability
- Steps to reproduce the issue
- Potential impact and exploitation scenarios
- Suggested fix (if you have one)
- Your contact information

### 4. Response timeline
- **Acknowledgment**: Within 48 hours
- **Initial assessment**: Within 1 week
- **Fix timeline**: Varies based on severity and complexity
- **Disclosure**: After fix is released (coordinated disclosure)

## Security Best Practices

When using Site Manager:

### Server Security
- Keep your system updated: `sudo apt update && sudo apt upgrade`
- Use strong passwords for database users
- Configure UFW firewall properly
- Regular security audits of your server

### SSL/TLS Security
- Use Let's Encrypt for production domains
- Keep certificates updated
- Monitor certificate expiration
- Use strong cipher suites (Site Manager configures these automatically)

### File Permissions
- Follow Site Manager's permission recommendations
- Avoid running with unnecessary root privileges
- Regular permission audits for web directories

### Database Security
- Use strong database passwords
- Limit database user privileges
- Regular database backups
- Consider encryption for sensitive data

## Known Security Considerations

### Root Privileges
Site Manager requires sudo/root privileges for:
- Installing system packages
- Configuring web server
- Managing SSL certificates
- Setting file permissions

**Mitigation**: Only run Site Manager on systems you control and trust.

### File System Access
Site Manager creates and modifies files in:
- `/etc/nginx/` - Web server configuration
- `/var/www/` - Web content
- `/etc/ssl/` - SSL certificates
- `/etc/hosts` - Domain resolution

**Mitigation**: Review generated configurations before deployment.

### Network Access
Site Manager makes network requests to:
- GitHub API (for updates)
- Let's Encrypt servers (for SSL certificates)
- Package repositories (for software installation)

**Mitigation**: Use on trusted networks and verify SSL certificates.

### Enhanced Installer Security (v3.0.0)
The new enhanced installer includes additional security measures:
- **File verification**: Post-download integrity checks
- **Dependency validation**: Secure installation of required packages
- **Error handling**: Prevents incomplete installations that could compromise security
- **Source verification**: Downloads only from official GitHub Releases

**Security Note**: The installer downloads from both raw.githubusercontent.com (installer script) and GitHub Releases (main application), both secured with HTTPS and GitHub's security infrastructure.

## Security Updates

Security updates will be released as:
1. **Critical**: Immediate patch release
2. **High**: Within 1 week
3. **Medium**: Next minor version
4. **Low**: Next major version

Subscribe to releases on GitHub to stay informed about security updates.

## Acknowledgments

We appreciate security researchers who help improve Site Manager's security. Contributors will be acknowledged in release notes (with permission).

## Questions?

For security-related questions that are not vulnerabilities:
- Open a GitHub Discussion
- Tag with "security" label
- Check existing security documentation

Thank you for helping keep Site Manager secure! 🔒
