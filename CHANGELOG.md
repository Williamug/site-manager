# Changelog

All notable changes to Site Manager will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [3.0.0] - 2025-09-19

### Added
- **Enhanced Installation Experience**: Professional installation script with comprehensive progress indicators
- **Improved Download Tracking**: Enhanced installer downloads from GitHub Releases for accurate statistics
- **Production-Ready Release**: Complete GitHub repository setup with professional documentation
- **Advanced Error Handling**: Comprehensive error checking and user-friendly error messages
- **Dependency Management**: Automatic dependency detection and installation (curl, wget, jq)
- **File Verification**: Post-download verification to ensure successful installations
- **Professional Branding**: Branded installation experience with color-coded progress indicators

### Enhanced
- **Installation Process**: Beautiful progress indicators with real-time feedback
- **User Experience**: Professional installation output that builds user confidence
- **Documentation**: Comprehensive installation guides with visual examples
- **Error Recovery**: Better error handling and troubleshooting guidance
- **GitHub Integration**: Professional repository setup with issue templates and contribution guidelines

### Improved
- **Download Statistics**: Enhanced tracking through GitHub Releases integration
- **Installation Reliability**: Multiple verification steps to ensure successful deployment
- **User Guidance**: Step-by-step post-installation instructions
- **Repository Structure**: Professional open-source project structure with all necessary documentation

### Technical
- **GitHub Templates**: Bug report, feature request, and pull request templates
- **Security Policy**: Comprehensive security policy and vulnerability reporting guidelines
- **Contributing Guidelines**: Detailed contribution guidelines for developers
- **Professional Documentation**: Complete project documentation following open-source best practices

## [2.1.0] - 2025-09-19

### Added
- **Self-Signed SSL Certificates**: Laravel Valet-style HTTPS for local development
- **Smart Domain Detection**: Automatically detects local (.test, .local, .dev) vs public domains
- **Universal SSL Support**: Works with .test, .local, .dev, and localhost domains
- **Enhanced SSL Management**: Complete SSL certificate lifecycle management
- **Certificate Monitoring**: Comprehensive SSL health diagnostics with `check_all_certificates` function
- **SSL Removal Options**: Complete SSL certificate removal with multiple options
- **Modern Security**: TLS 1.2/1.3 protocols with strong cipher suites
- **Progress Indicators**: Enhanced installation script with real-time progress feedback
- **Better Error Handling**: Improved SSL setup error messages and troubleshooting
- **Certificate Expansion**: Multi-domain certificate support for Let's Encrypt
- **SSL Status Checker**: Detailed analysis of certificate health and configuration

### Enhanced
- **Local Development Experience**: Instant Local HTTPS without mixed content errors
- **Security Headers**: HSTS, CSP, and modern security header configuration
- **Installation Process**: Beautiful progress indicators with color-coded output
- **User Experience**: Professional installation output that builds user confidence
- **Documentation**: Comprehensive SSL setup and troubleshooting guides

### Fixed
- **Certificate Detection**: Improved detection of existing certificates
- **Permission Management**: Better Laravel-specific permission handling
- **Error Reporting**: More informative error messages throughout the system
- **Installation Reliability**: Better error handling and verification in installation

### Security
- **Enhanced SSL/TLS**: Modern cipher suites and security configurations
- **Certificate Validation**: Improved certificate verification and monitoring
- **Secure Defaults**: Better default security configurations for new sites

## [2.0.0] - 2024-12-01

### Added
- **Complete Rewrite**: Comprehensive server and site management solution
- **Server Setup**: Automated installation of Nginx, PHP, MySQL, Node.js, Composer
- **Project Management**: Create, clone, move, backup, and restore web projects
- **SSL Integration**: Let's Encrypt certificate automation
- **Permission Management**: Advanced file permission fixing with Laravel support
- **Firewall Configuration**: Automatic UFW setup with web server rules
- **Memory Optimization**: Smart memory management for low-memory servers
- **Interactive Menu**: User-friendly menu system for all operations

### Enhanced
- **Laravel Support**: Full Laravel project detection and configuration
- **GitHub Integration**: Direct repository cloning with dependency installation
- **Backup System**: Comprehensive backup and restore functionality
- **Multi-PHP Support**: Support for PHP versions 8.1, 8.2, 8.3, and 8.4

## [1.0.0] - 2024-06-01

### Added
- **Initial Release**: Basic site management functionality
- **Nginx Configuration**: Basic virtual host setup
- **PHP Support**: PHP-FPM configuration
- **MySQL Integration**: Database setup and configuration
- **SSL Basics**: Basic Let's Encrypt integration

---

## Release Notes

### v3.0.0 - Production-Ready Professional Release 🚀

This major release marks Site Manager's evolution into a production-ready, professionally documented open-source project with enhanced installation experience and comprehensive GitHub integration.

#### 🎯 Key Features
- **Professional Installation**: Enhanced installer with comprehensive progress indicators
- **Download Tracking**: Accurate GitHub download statistics through Release API integration
- **Production Documentation**: Complete open-source project documentation and templates
- **Enhanced User Experience**: Beautiful, branded installation process with real-time feedback

#### 🔧 Installation Revolution
- **Comprehensive Progress**: Step-by-step installation feedback with color-coded indicators
- **Dependency Management**: Automatic detection and installation of required dependencies
- **File Verification**: Post-download verification ensures successful installations
- **Error Recovery**: Professional error handling with helpful troubleshooting guidance

#### 🛡️ Professional Standards
- **GitHub Templates**: Professional issue and pull request templates
- **Security Policy**: Comprehensive security policy and vulnerability reporting
- **Contributing Guidelines**: Detailed guidelines for community contributions
- **Documentation**: Complete project documentation following open-source best practices

#### 📈 Enhanced Tracking
- **Accurate Statistics**: Enhanced installer integrates with GitHub Releases for precise download tracking
- **User Analytics**: Better understanding of installation patterns and user adoption
- **Community Growth**: Professional project structure to encourage community contributions

### v2.1.0 - Local Development SSL Revolution 🚀

This release brings **Laravel Valet-style HTTPS** to Site Manager, making local development with HTTPS seamless and professional.

#### 🎯 Key Features
- **Instant Local HTTPS**: Set up HTTPS for `.test`, `.local`, `.dev` domains in seconds
- **Smart Detection**: Automatically chooses Let's Encrypt vs self-signed certificates
- **Professional SSL Management**: Complete certificate lifecycle with monitoring
- **Enhanced Installation**: Beautiful progress indicators and better user experience

#### 🔧 Perfect for Developers
- **PWA Development**: Service workers work with local HTTPS
- **OAuth Testing**: Secure callbacks work in local development
- **API Development**: HTTPS APIs work perfectly locally
- **Laravel Projects**: Full HTTPS support for local Laravel development

#### 🛡️ Security & Reliability
- **Modern TLS**: TLS 1.2/1.3 with strong cipher suites
- **Certificate Monitoring**: Track expiration across all domains
- **Better Error Handling**: Clear messages and troubleshooting guides
- **Enhanced Security Headers**: HSTS, CSP, and modern security configurations

### Upgrade Instructions

If you're upgrading from v2.x:
```bash
# Update Site Manager with enhanced installer
curl -fsSL https://raw.githubusercontent.com/williamug/site-manager/main/install.sh | bash

# Verify installation
site-manager check
```

No breaking changes - all existing functionality preserved and enhanced.

---

## Support

- **Issues**: [GitHub Issues](https://github.com/williamug/site-manager/issues)
- **Discussions**: [GitHub Discussions](https://github.com/williamug/site-manager/discussions)
- **Documentation**: [README.md](README.md)
