#!/bin/bash

# Site Manager Installation Script with Progress Indicators
# Usage: curl -fsSL https://raw.githubusercontent.com/williamug/site-manager/main/install.sh | bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Progress indicator function
show_progress() {
    local message="$1"
    echo -e "${BLUE}[INFO]${NC} $message"
}

show_success() {
    local message="$1"
    echo -e "${GREEN}[✓]${NC} $message"
}

show_error() {
    local message="$1"
    echo -e "${RED}[✗]${NC} $message"
}

show_warning() {
    local message="$1"
    echo -e "${YELLOW}[!]${NC} $message"
}

# Spinner function for long operations
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        show_error "This script should not be run as root"
        show_warning "Please run as a regular user with sudo privileges"
        exit 1
    fi
}

# Function to check internet connectivity
check_internet() {
    show_progress "Checking internet connectivity..."
    if ! curl -s --connect-timeout 5 https://api.github.com > /dev/null; then
        show_error "No internet connection available"
        echo "Please check your internet connection and try again."
        exit 1
    fi
    show_success "Internet connectivity confirmed"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install dependencies
install_dependencies() {
    local missing_deps=()

    show_progress "Checking required dependencies..."

    # Check for required commands
    if ! command_exists curl; then
        missing_deps+=("curl")
    fi

    if ! command_exists wget; then
        missing_deps+=("wget")
    fi

    if ! command_exists jq; then
        missing_deps+=("jq")
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        show_warning "Missing dependencies: ${missing_deps[*]}"
        show_progress "Installing missing dependencies..."

        # Update package list
        sudo apt update -qq &
        spinner $!

        # Install missing dependencies
        sudo apt install -y "${missing_deps[@]}" &
        spinner $!

        show_success "Dependencies installed successfully"
    else
        show_success "All required dependencies are available"
    fi
}

# Function to get latest release info
get_latest_release() {
    show_progress "Fetching latest release information..."

    local api_response
    api_response=$(curl -s https://api.github.com/repos/williamug/site-manager/releases/latest)

    if [ -z "$api_response" ]; then
        show_error "Failed to fetch release information"
        exit 1
    fi

    # Extract version and download URL
    LATEST_VERSION=$(echo "$api_response" | jq -r '.tag_name // "unknown"')
    DOWNLOAD_URL=$(echo "$api_response" | jq -r '.assets[0].browser_download_url // empty')

    if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" = "null" ]; then
        # Fallback to direct GitHub download
        DOWNLOAD_URL="https://github.com/williamug/site-manager/releases/latest/download/site-manager.sh"
    fi

    show_success "Latest version: $LATEST_VERSION"
}

# Function to download with progress
download_with_progress() {
    local url="$1"
    local output="$2"

    show_progress "Downloading Site Manager..."
    echo "Source: $url"

    # Download with progress bar
    if wget --progress=bar:force -O "$output" "$url" 2>&1 | \
       sed -u 's/.* \([0-9]\+%\).*\([0-9.]\+.\).*/\1\n# Downloading... \1 at \2\/s/'; then
        show_success "Download completed successfully"
    else
        show_error "Download failed"
        rm -f "$output"
        exit 1
    fi
}

# Function to verify download
verify_download() {
    local file="$1"

    show_progress "Verifying downloaded file..."

    if [ ! -f "$file" ]; then
        show_error "Downloaded file not found"
        exit 1
    fi

    if [ ! -s "$file" ]; then
        show_error "Downloaded file is empty"
        exit 1
    fi

    # Check if it's a valid bash script
    if ! head -1 "$file" | grep -q "^#!/bin/bash"; then
        show_error "Downloaded file is not a valid bash script"
        exit 1
    fi

    local file_size=$(stat -c%s "$file")
    if [ "$file_size" -lt 1000 ]; then
        show_error "Downloaded file seems too small (${file_size} bytes)"
        exit 1
    fi

    show_success "File verification passed (${file_size} bytes)"
}

# Function to install site-manager
install_site_manager() {
    local temp_file="$1"

    show_progress "Installing Site Manager to /usr/local/bin/site-manager..."

    # Make executable
    chmod +x "$temp_file"

    # Move to system location
    if sudo mv "$temp_file" /usr/local/bin/site-manager; then
        show_success "Site Manager installed successfully"
    else
        show_error "Failed to install Site Manager"
        exit 1
    fi

    # Verify installation
    if command_exists site-manager; then
        show_success "Installation verified - site-manager command is available"
    else
        show_warning "site-manager command not found in PATH"
        echo "You may need to restart your terminal or run: source ~/.bashrc"
    fi
}

# Function to show post-installation info
show_post_install_info() {
    echo ""
    echo -e "${GREEN}🎉 Site Manager Installation Complete!${NC}"
    echo ""
    echo -e "${BLUE}📋 Next Steps:${NC}"
    echo "  1. Check system requirements:"
    echo -e "     ${YELLOW}site-manager check${NC}"
    echo ""
    echo "  2. Run initial server setup:"
    echo -e "     ${YELLOW}sudo site-manager setup${NC}"
    echo ""
    echo "  3. Start using Site Manager:"
    echo -e "     ${YELLOW}sudo site-manager${NC}"
    echo ""
    echo -e "${BLUE}📖 Documentation:${NC}"
    echo "  • GitHub: https://github.com/williamug/site-manager"
    echo "  • README: Full feature documentation and examples"
    echo ""
    echo -e "${BLUE}🆘 Support:${NC}"
    echo "  • Issues: https://github.com/williamug/site-manager/issues"
    echo "  • Discussions: https://github.com/williamug/site-manager/discussions"
    echo ""
}

# Main installation function
main() {
    echo -e "${BLUE}┌─────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│          Site Manager Installer        │${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────┘${NC}"
    echo ""

    # Pre-installation checks
    check_root
    check_internet
    install_dependencies

    # Get release information
    get_latest_release

    # Create temporary file
    local temp_file
    temp_file=$(mktemp)

    # Cleanup function
    cleanup() {
        rm -f "$temp_file"
    }
    trap cleanup EXIT

    # Download and install
    download_with_progress "$DOWNLOAD_URL" "$temp_file"
    verify_download "$temp_file"
    install_site_manager "$temp_file"

    # Show completion message
    show_post_install_info
}

# Run main function
main "$@"
