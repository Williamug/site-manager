# Contributing to Site Manager

Thank you for considering contributing to Site Manager! We welcome contributions from the community.

## How to Contribute

### Reporting Issues
- Check existing issues before creating a new one
- Use the issue templates when available
- Provide clear reproduction steps
- Include system information (OS, PHP version, etc.)

### Feature Requests
- Describe the feature and its benefits
- Explain the use case
- Consider backward compatibility

### Code Contributions

#### Prerequisites
- Basic knowledge of Bash scripting
- Understanding of web server configuration (Nginx, PHP, SSL)
- Familiarity with Linux system administration

#### Development Setup
1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/site-manager.git
   cd site-manager
   ```
3. Test the script:
   ```bash
   chmod +x site-manager.sh
   sudo ./site-manager.sh check
   ```

#### Making Changes
1. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```
2. Make your changes
3. Test thoroughly on a clean system if possible
4. Follow the coding standards below

#### Testing
- Test all modified functionality
- Verify the script works on Ubuntu/Debian systems
- Test both successful and error scenarios
- Ensure no existing functionality is broken
- Test the enhanced installer if making installation changes

#### Coding Standards
- Use 4 spaces for indentation
- Include comments for complex logic
- Use meaningful variable names
- Follow existing code style and patterns
- Add error handling for new features
- Maintain the professional output formatting introduced in v3.0.0

#### Submitting Changes
1. Commit your changes:
   ```bash
   git add .
   git commit -m "Add: description of your changes"
   ```
2. Push to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```
3. Create a Pull Request with:
   - Clear description of changes
   - Reference to any related issues
   - Screenshots if UI changes are involved

## Development Guidelines

### Code Structure
- Keep functions focused and single-purpose
- Use consistent error handling patterns
- Maintain backward compatibility when possible
- Document any breaking changes
- Follow the enhanced user experience patterns from v3.0.0

### Testing Areas
- SSL certificate management
- Project creation and configuration
- Permission management
- Backup and restore functionality
- Error handling and edge cases
- Enhanced installer functionality (v3.0.0+)

### Security Considerations
- Validate all user inputs
- Use proper file permissions
- Avoid hardcoded credentials
- Follow security best practices for SSL/TLS
- Review the Security Policy for v3.0.0 requirements

### Documentation Standards (v3.0.0+)
- Update relevant documentation files
- Maintain consistency with professional formatting
- Include examples and use cases
- Update CHANGELOG.md for all changes
- Follow the established documentation patterns

## Release Process
1. Update version numbers across all files
2. Update CHANGELOG.md with detailed release notes
3. Test on multiple systems
4. Create GitHub release with proper versioning
5. Update installation documentation
6. Verify enhanced installer compatibility

## v3.0.0 Contribution Guidelines

### Enhanced Installer
When contributing to the enhanced installer:
- Maintain the professional progress indicators
- Ensure download tracking compatibility
- Test dependency management
- Verify file verification processes

### Documentation Updates
- Follow the professional documentation standards
- Maintain consistency across all markdown files
- Update version references appropriately
- Include comprehensive examples

### GitHub Integration
- Use proper issue and PR templates
- Follow the established labeling system
- Maintain professional commit message standards

## Questions?
- Open a discussion on GitHub
- Check existing documentation
- Review similar issues or PRs
- Reference the v3.0.0 documentation standards

Thank you for contributing to Site Manager! 🚀
