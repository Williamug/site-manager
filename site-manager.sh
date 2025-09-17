#!/bin/bash
# Comprehensive Server & Site Management Tool v2.0

set -eo pipefail

# Configuration
WEB_ROOT="/var/www"
NGINX_DIR="/etc/nginx"
CONFIG_DIR="/etc/site-manager"
LOG_DIR="/var/log/site-manager"
BACKUP_DIR="/var/backups/sites"
PHP_SOCKET="/run/php/php@VERSION@-fpm.sock"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to get default PHP version from installed PHP-FPM socket(s)
get_default_php_version() {
    local socket
    socket=$(ls /run/php/php*-fpm.sock 2>/dev/null | head -n 1)
    if [ -n "$socket" ]; then
        echo "$socket" | sed -E 's/.*php([0-9]+\.[0-9]+)-fpm.sock/\1/'
    else
        echo "8.1"
    fi
}

DEFAULT_PHP_VERSION=$(get_default_php_version)

# Helper function to get PHP version
get_php_version() {
    # First check if php_version is already set (from setup_server)
    if [ -n "$php_version" ]; then
        echo "$php_version"
        return
    fi

    # Check config file
    if [ -f "$CONFIG_DIR/config" ] && grep -q "php_version=" "$CONFIG_DIR/config"; then
        grep "php_version=" "$CONFIG_DIR/config" | cut -d'=' -f2
        return
    fi

    # Fallback to auto-detection
    get_default_php_version
}

# ---------- Core Functions ----------
show_header() {
    clear
    echo -e "${BLUE}"
    echo "=============================================="
    echo "        WELCOME TO SITE MANAGER"
    echo "=============================================="
    echo -e "${NC}"
}

get_current_user() {
    if [ -n "$SUDO_USER" ]; then
        echo "$SUDO_USER"
    else
        id -un
    fi
}

# Function to check available memory
check_memory() {
    local available_mb=$(free -m | awk 'NR==2{printf "%.0f", $7}')
    echo "$available_mb"
}

# Function to create swap if needed for low memory systems
ensure_swap() {
    local mem_mb=$(check_memory)
    echo -e "\n${BLUE}Checking system memory: ${mem_mb}MB available${NC}"

    if [ "$mem_mb" -lt 512 ]; then
        echo -e "${YELLOW}⚠️  Low memory detected. Checking swap space...${NC}"

        local swap_mb=$(free -m | awk 'NR==3{printf "%.0f", $2}')
        echo "Current swap: ${swap_mb}MB"

        if [ "$swap_mb" -lt 1024 ]; then
            echo -e "${YELLOW}Creating temporary swap file for installation...${NC}"

            # Check if swap file already exists
            if [ ! -f /swapfile ]; then
                read -p "Create 1GB swap file to help with installation? [Y/n] " create_swap
                if [[ ! "$create_swap" =~ ^[Nn]$ ]]; then
                    if sudo fallocate -l 1G /swapfile 2>/dev/null || sudo dd if=/dev/zero of=/swapfile bs=1024 count=1048576 2>/dev/null; then
                        sudo chmod 600 /swapfile
                        sudo mkswap /swapfile >/dev/null 2>&1
                        sudo swapon /swapfile
                        echo -e "${GREEN}✅ Temporary swap created successfully${NC}"
                        echo -e "${BLUE}💡 Swap will be removed after installation${NC}"
                        return 0
                    else
                        echo -e "${YELLOW}⚠️  Failed to create swap, continuing anyway...${NC}"
                    fi
                fi
            else
                echo -e "${GREEN}✅ Swap file already exists${NC}"
            fi
        else
            echo -e "${GREEN}✅ Sufficient swap space available${NC}"
        fi
    else
        echo -e "${GREEN}✅ Sufficient memory available${NC}"
    fi
}

# Function to cleanup temporary swap
cleanup_temp_swap() {
    if [ -f /swapfile ]; then
        read -p "Remove temporary swap file? [Y/n] " remove_swap
        if [[ ! "$remove_swap" =~ ^[Nn]$ ]]; then
            sudo swapoff /swapfile 2>/dev/null || true
            sudo rm -f /swapfile
            echo -e "${GREEN}✅ Temporary swap removed${NC}"
        fi
    fi
}

# Enhanced MySQL installation with low-memory handling
install_mysql() {
    echo -e "\n${YELLOW}Installing MySQL with memory optimization...${NC}"

    # Check if MySQL is already installed
    if command -v mysqld &>/dev/null; then
        echo -e "${GREEN}✅ MySQL is already installed${NC}"
        return 0
    fi

    # Pre-configure MySQL to reduce memory usage during installation
    echo -e "${BLUE}Configuring MySQL for low-memory installation...${NC}"

    # Create temporary MySQL config for installation
    sudo mkdir -p /etc/mysql/conf.d
    cat << EOF | sudo tee /etc/mysql/conf.d/low-memory.cnf > /dev/null
[mysqld]
innodb_buffer_pool_size = 64M
innodb_log_file_size = 32M
innodb_log_buffer_size = 4M
query_cache_size = 16M
table_open_cache = 64
sort_buffer_size = 512K
net_buffer_length = 16K
read_buffer_size = 256K
read_rnd_buffer_size = 512K
myisam_sort_buffer_size = 8M
thread_stack = 256K
tmp_table_size = 32M
max_heap_table_size = 32M
EOF

    # Set DEBIAN_FRONTEND to avoid interactive prompts
    export DEBIAN_FRONTEND=noninteractive

    # Try installing MySQL with retries
    local mysql_installed=false
    local attempts=0
    local max_attempts=3

    while [ $attempts -lt $max_attempts ] && [ "$mysql_installed" = false ]; do
        attempts=$((attempts + 1))
        echo -e "${YELLOW}MySQL installation attempt $attempts/$max_attempts...${NC}"

        # Clear any previous failed installations
        if [ $attempts -gt 1 ]; then
            echo "Cleaning up previous installation attempt..."
            sudo apt-get purge -y mysql* >/dev/null 2>&1 || true
            sudo apt-get autoremove -y >/dev/null 2>&1 || true
            sudo rm -rf /var/lib/mysql >/dev/null 2>&1 || true
        fi

        # Install with memory-conscious approach
        if sudo apt-get install -y mysql-server 2>/dev/null; then
            mysql_installed=true
            echo -e "${GREEN}✅ MySQL installed successfully${NC}"
        else
            echo -e "${RED}❌ MySQL installation attempt $attempts failed${NC}"

            if [ $attempts -lt $max_attempts ]; then
                echo -e "${YELLOW}Waiting 30 seconds before retry...${NC}"
                sleep 30

                # Try to free up memory
                echo "Clearing system caches..."
                sudo sync
                echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1 || true
            fi
        fi
    done

    if [ "$mysql_installed" = false ]; then
        echo -e "${RED}❌ Failed to install MySQL after $max_attempts attempts${NC}"
        echo -e "${YELLOW}💡 Alternative options:${NC}"
        echo "   • Try installing MariaDB instead: sudo apt install mariadb-server"
        echo "   • Skip MySQL for now and install it later manually"
        echo "   • Increase server memory or add permanent swap"

        read -p "Continue without MySQL? [y/N] " skip_mysql
        if [[ "$skip_mysql" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}⚠️  Skipping MySQL installation${NC}"
            return 0
        else
            return 1
        fi
    fi

    # Start and enable MySQL
    echo "Starting MySQL service..."
    if sudo systemctl enable mysql && sudo systemctl start mysql; then
        echo -e "${GREEN}✅ MySQL service started successfully${NC}"

        # Wait for MySQL to be ready
        echo "Waiting for MySQL to be ready..."
        local wait_count=0
        while ! sudo mysqladmin ping >/dev/null 2>&1 && [ $wait_count -lt 30 ]; do
            sleep 2
            wait_count=$((wait_count + 1))
            echo -n "."
        done
        echo ""

        if sudo mysqladmin ping >/dev/null 2>&1; then
            echo -e "${GREEN}✅ MySQL is ready${NC}"

            # Prompt for MySQL root password
            echo -e "\n${YELLOW}Setting up MySQL security...${NC}"
            read -s -p "Enter a password for MySQL root user: " db_root_pass
            echo ""

            if [ -n "$db_root_pass" ]; then
                # Set MySQL root password
                if sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$db_root_pass'; FLUSH PRIVILEGES;" 2>/dev/null; then
                    echo -e "${GREEN}✅ MySQL root password set successfully${NC}"

                    read -p "Run MySQL secure installation? [Y/n] " run_secure
                    if [[ ! "$run_secure" =~ ^[Nn]$ ]]; then
                        echo -e "${YELLOW}Running MySQL secure installation...${NC}"
                        sudo mysql_secure_installation
                    fi
                else
                    echo -e "${YELLOW}⚠️  Could not set MySQL root password automatically${NC}"
                    echo -e "${BLUE}You can set it manually later with: sudo mysql_secure_installation${NC}"
                fi
            else
                echo -e "${YELLOW}No password set for MySQL root user${NC}"
                echo -e "${BLUE}You can set it later with: sudo mysql_secure_installation${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️  MySQL started but not responding to ping${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  MySQL installed but failed to start automatically${NC}"
        echo -e "${BLUE}You can start it manually later with: sudo systemctl start mysql${NC}"
    fi

    # Clean up temporary config
    sudo rm -f /etc/mysql/conf.d/low-memory.cnf

    return 0
}

# Enhanced Node.js installation with multiple fallback methods
install_nodejs() {
    echo -e "\n${YELLOW}Installing Node.js and npm...${NC}"

    if command -v node &>/dev/null; then
        echo -e "${GREEN}✅ Node.js is already installed${NC}"
        return 0
    fi

    # Method 1: NodeSource repository (preferred)
    echo -e "${BLUE}Trying NodeSource repository installation...${NC}"
    if curl -fsSL https://deb.nodesource.com/setup_20.x 2>/dev/null | sudo -E bash - && sudo apt-get install -y nodejs 2>/dev/null; then
        echo -e "${GREEN}✅ Node.js installed via NodeSource repository${NC}"
        return 0
    fi

    echo -e "${YELLOW}NodeSource installation failed, trying alternative methods...${NC}"

    # Method 2: Ubuntu package manager
    echo -e "${BLUE}Trying Ubuntu package manager...${NC}"
    if sudo apt-get install -y nodejs npm 2>/dev/null; then
        echo -e "${GREEN}✅ Node.js installed via package manager${NC}"

        # Check if we got a reasonable version
        local node_version=$(node -v 2>/dev/null | sed 's/v//')
        local major_version=$(echo "$node_version" | cut -d. -f1)

        if [ -n "$major_version" ] && [ "$major_version" -ge 14 ]; then
            echo -e "${GREEN}✅ Node.js version $node_version is suitable${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠️  Node.js version $node_version might be too old${NC}"
        fi
    fi

    # Method 3: Snap package (if available)
    if command -v snap &>/dev/null; then
        echo -e "${BLUE}Trying Snap package...${NC}"
        if sudo snap install node --classic 2>/dev/null; then
            echo -e "${GREEN}✅ Node.js installed via Snap${NC}"
            return 0
        fi
    fi

    # Method 4: Manual installation
    echo -e "${BLUE}Attempting manual installation...${NC}"
    local node_url="https://nodejs.org/dist/v20.9.0/node-v20.9.0-linux-x64.tar.xz"
    local install_dir="/opt/nodejs"

    if curl -fsSL "$node_url" -o /tmp/nodejs.tar.xz 2>/dev/null; then
        sudo mkdir -p "$install_dir"
        if sudo tar -xf /tmp/nodejs.tar.xz -C "$install_dir" --strip-components=1 2>/dev/null; then
            # Add to PATH
            echo 'export PATH=/opt/nodejs/bin:$PATH' | sudo tee /etc/profile.d/nodejs.sh > /dev/null
            export PATH=/opt/nodejs/bin:$PATH

            # Create symlinks
            sudo ln -sf /opt/nodejs/bin/node /usr/local/bin/node 2>/dev/null || true
            sudo ln -sf /opt/nodejs/bin/npm /usr/local/bin/npm 2>/dev/null || true

            echo -e "${GREEN}✅ Node.js installed manually${NC}"
            rm -f /tmp/nodejs.tar.xz
            return 0
        fi
    fi

    echo -e "${RED}❌ All Node.js installation methods failed${NC}"
    echo -e "${YELLOW}💡 You can install Node.js manually later:${NC}"
    echo "   • Visit: https://nodejs.org/"
    echo "   • Or try: curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash"

    read -p "Continue without Node.js? [y/N] " skip_nodejs
    if [[ "$skip_nodejs" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}⚠️  Skipping Node.js installation${NC}"
        return 0
    else
        return 1
    fi
}

check_tool() {
    local tool=$1
    local user
    user=$(get_current_user)

    if command -v "$tool" &>/dev/null; then
        local version=""
        case $tool in
            nginx)
                version=$(nginx -v 2>&1 | awk -F/ '{print $2}' | cut -d' ' -f1)
                ;;
            php)
                version=$(php -r 'echo PHP_VERSION;' 2>/dev/null)
                ;;
            mysqld)
                version=$(mysqld --version 2>/dev/null | awk '{print $3}' || echo "installed")
                ;;
            node)
                version=$(node -v 2>/dev/null)
                ;;
            npm)
                version=$(npm -v 2>/dev/null)
                ;;
            composer)
                version=$(sudo -u "$user" -i composer --version 2>/dev/null | awk '{print $3}' || echo "installed")
                ;;
        esac

        if [ -n "$version" ]; then
            echo -e "${GREEN}✔️ $tool $version${NC}"
        else
            echo -e "${GREEN}✔️ $tool (version unknown)${NC}"
        fi
        return 0
    else
        echo -e "${RED}❌ $tool${NC}"
        return 1
    fi
}

check_dependencies() {
    echo -e "\n${YELLOW}Checking System Dependencies:${NC}"
    check_tool "nginx"
    check_tool "php"
    check_tool "mysqld"
    check_tool "node"
    check_tool "npm"
    check_tool "composer"
}

setup_server() {
    show_header
    echo -e "${YELLOW}This Is The Initial Server Setup${NC}"

    local CURRENT_USER
    CURRENT_USER=$(get_current_user)

    # Check system resources and create swap if needed
    ensure_swap

    # PHP Version Selection using select (enter the option number)
    PS3="Select PHP version (enter the option number): "
    select chosen in 8.4 8.3 8.2 8.1; do
        if [ -n "$chosen" ]; then
            # Make php_version global so it's available to other functions
            export php_version="$chosen"
            break
        else
            echo "Invalid selection! Please enter the number corresponding to the PHP version."
        fi
    done

    echo -e "\n${BLUE}Selected PHP version: $php_version${NC}"

    # Update package list
    echo -e "\n${YELLOW}Updating package list...${NC}"
    sudo apt-get update

    # Nginx
    if ! command -v nginx &>/dev/null; then
        echo -e "\n${YELLOW}Installing Nginx...${NC}"
        if sudo apt-get install -y nginx; then
            sudo systemctl enable nginx
            sudo systemctl start nginx
            echo -e "${GREEN}✅ Nginx installed successfully${NC}"
        else
            echo -e "${RED}❌ Failed to install Nginx${NC}"
            read -p "Continue without Nginx? [y/N] " skip_nginx
            if [[ ! "$skip_nginx" =~ ^[Yy]$ ]]; then
                return 1
            fi
        fi
    else
        echo -e "${GREEN}✅ Nginx is already installed${NC}"
    fi

    # PHP
    echo -e "\n${YELLOW}Installing PHP $php_version and extensions...${NC}"
    if sudo apt-get install -y \
        php$php_version-fpm \
        php$php_version-common \
        php$php_version-mysql \
        php$php_version-xml \
        php$php_version-curl \
        php$php_version-gd \
        php$php_version-imagick \
        php$php_version-cli \
        php$php_version-dev \
        php$php_version-imap \
        php$php_version-mbstring \
        php$php_version-opcache \
        php$php_version-soap \
        php$php_version-zip \
        php$php_version-sqlite3 \
        php$php_version-bcmath \
        php$php_version-intl 2>/dev/null; then

        sudo systemctl enable php$php_version-fpm
        sudo systemctl start php$php_version-fpm
        echo -e "${GREEN}✅ PHP $php_version installed successfully${NC}"
    else
        echo -e "${RED}❌ Failed to install PHP $php_version${NC}"
        read -p "Continue without PHP? [y/N] " skip_php
        if [[ ! "$skip_php" =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi

    # MySQL with enhanced error handling
    install_mysql

    # Node.js with multiple fallback methods
    install_nodejs

    # Composer installation with improved error handling
    if ! command -v composer &>/dev/null; then
        echo -e "\n${YELLOW}Installing Composer...${NC}"

        # Download and install Composer with retries
        local composer_installed=false
        local attempts=0
        local max_attempts=3

        while [ $attempts -lt $max_attempts ] && [ "$composer_installed" = false ]; do
            attempts=$((attempts + 1))
            echo -e "${YELLOW}Composer installation attempt $attempts/$max_attempts...${NC}"

            if curl -sS https://getcomposer.org/installer 2>/dev/null | php -- --install-dir=/tmp --filename=composer 2>/dev/null; then
                if sudo mv /tmp/composer /usr/local/bin/composer && sudo chmod +x /usr/local/bin/composer; then
                    composer_installed=true
                    echo -e "${GREEN}✅ Composer installed successfully${NC}"
                else
                    echo -e "${YELLOW}Failed to move Composer to final location${NC}"
                fi
            else
                echo -e "${YELLOW}Failed to download Composer installer${NC}"
            fi

            if [ "$composer_installed" = false ] && [ $attempts -lt $max_attempts ]; then
                echo "Waiting 10 seconds before retry..."
                sleep 10
            fi
        done

        if [ "$composer_installed" = false ]; then
            echo -e "${RED}❌ Failed to install Composer${NC}"
            echo -e "${YELLOW}💡 You can install Composer manually later:${NC}"
            echo "   • Visit: https://getcomposer.org/download/"

            read -p "Continue without Composer? [y/N] " skip_composer
            if [[ ! "$skip_composer" =~ ^[Yy]$ ]]; then
                return 1
            fi
        else
            # Check if /usr/local/bin is in PATH
            if ! echo "$PATH" | grep -q "/usr/local/bin"; then
                echo -e "\n${YELLOW}⚠️  /usr/local/bin is not in your PATH${NC}"

                # Detect shell configuration file
                detect_shell_config() {
                    local user_home
                    if [ -n "$SUDO_USER" ]; then
                        user_home=$(eval echo "~$SUDO_USER")
                    else
                        user_home="$HOME"
                    fi

                    case $(basename "$SHELL") in
                        bash*)  echo "$user_home/.bashrc" ;;
                        zsh*)   echo "$user_home/.zshrc" ;;
                        fish*)  echo "$user_home/.config/fish/config.fish" ;;
                        *)      echo "$user_home/.profile" ;;
                    esac
                }

                config_file=$(detect_shell_config)
                echo "Detected shell configuration file: $config_file"

                read -p "Add /usr/local/bin to PATH in $config_file? [Y/n] " response
                if [[ ! "$response" =~ ^[Nn] ]]; then
                    # Create backup
                    if [ -f "$config_file" ]; then
                        cp "$config_file" "$config_file.backup.$(date +%Y%m%d_%H%M%S)"
                    fi

                    # Add PATH export
                    echo -e "\n# Added by Site Manager" >> "$config_file"
                    echo 'export PATH="$PATH:/usr/local/bin"' >> "$config_file"

                    if [ -n "$SUDO_USER" ]; then
                        sudo chown "$SUDO_USER:$SUDO_USER" "$config_file"
                    fi

                    echo -e "${GREEN}✅ Added /usr/local/bin to PATH in $config_file${NC}"
                    echo -e "${YELLOW}💡 Please run: source $config_file (or restart your terminal)${NC}"
                else
                    echo -e "${YELLOW}⚠️  You may need to add /usr/local/bin to your PATH manually${NC}"
                fi
            else
                echo -e "${GREEN}✅ /usr/local/bin is already in PATH${NC}"
            fi
        fi
    else
        echo -e "${GREEN}✅ Composer is already installed${NC}"
    fi

    # Configure permissions
    echo -e "\n${YELLOW}Configuring web directory permissions...${NC}"
    sudo mkdir -p "$WEB_ROOT"
    sudo chown -R "$CURRENT_USER":www-data "$WEB_ROOT"
    sudo chmod -R 775 "$WEB_ROOT"

    # Add user to www-data group
    if ! groups "$CURRENT_USER" | grep -q www-data; then
        sudo usermod -aG www-data "$CURRENT_USER"
        echo -e "${GREEN}✅ Added $CURRENT_USER to www-data group${NC}"
        echo -e "${YELLOW}💡 Please log out and back in for group changes to take effect${NC}"
    else
        echo -e "${GREEN}✅ $CURRENT_USER is already in www-data group${NC}"
    fi

    # Create site-manager config directory
    sudo mkdir -p "$CONFIG_DIR"
    echo "php_version=$php_version" | sudo tee "$CONFIG_DIR/config" > /dev/null
    sudo chmod 644 "$CONFIG_DIR/config"

    # Clean up temporary swap if created
    cleanup_temp_swap

    echo -e "\n${GREEN}🎉 Server setup completed!${NC}"
    echo -e "\n${BLUE}📋 Installation Summary:${NC}"

    # Show what was actually installed
    if command -v nginx &>/dev/null; then
        echo -e "  • Nginx: $(nginx -v 2>&1 | awk -F/ '{print $2}' | cut -d' ' -f1)"
    else
        echo -e "  • Nginx: ${RED}Not installed${NC}"
    fi

    if command -v php &>/dev/null; then
        echo -e "  • PHP: $php_version"
    else
        echo -e "  • PHP: ${RED}Not installed${NC}"
    fi

    if command -v mysqld &>/dev/null; then
        echo -e "  • MySQL: $(mysqld --version 2>/dev/null | awk '{print $3}' || echo 'installed')"
    else
        echo -e "  • MySQL: ${RED}Not installed${NC}"
    fi

    if command -v node &>/dev/null; then
        echo -e "  • Node.js: $(node -v 2>/dev/null)"
    else
        echo -e "  • Node.js: ${RED}Not installed${NC}"
    fi

    if command -v npm &>/dev/null; then
        echo -e "  • npm: $(npm -v 2>/dev/null)"
    else
        echo -e "  • npm: ${RED}Not installed${NC}"
    fi

    if command -v composer &>/dev/null; then
        echo -e "  • Composer: $(composer --version 2>/dev/null | awk '{print $3}' || echo 'installed')"
    else
        echo -e "  • Composer: ${RED}Not installed${NC}"
    fi

    echo -e "\n${YELLOW}💡 Next Steps:${NC}"
    echo -e "  1. Run: source ~/.bashrc (or restart your terminal)"
    echo -e "  2. Check installation: site-manager check"
    echo -e "  3. Create your first site: sudo site-manager"
    echo -e "  4. Select option 1 (Create New Project)"

    echo -e "\n${BLUE}💡 If any service failed to install:${NC}"
    echo -e "  • You can retry: sudo site-manager setup"
    echo -e "  • Or install manually later"
    echo -e "  • Check system resources and add more memory if needed"
}

configure_existing_project() {
    local CURRENT_USER
    CURRENT_USER=$(get_current_user)

    echo -e "${YELLOW}Configure Existing Project in /var/www${NC}"

    # List existing projects in /var/www
    echo -e "\n${BLUE}Available projects in $WEB_ROOT:${NC}"
    if [ -d "$WEB_ROOT" ] && [ "$(ls -A "$WEB_ROOT" 2>/dev/null)" ]; then
        local count=1
        local projects=()

        # Store projects in array and display them
        for dir in "$WEB_ROOT"/*; do
            if [ -d "$dir" ]; then
                local project_name=$(basename "$dir")
                projects[count]="$project_name"
                echo "  $count) $project_name"
                ((count++))
            fi
        done

        if [ ${#projects[@]} -eq 0 ]; then
            echo -e "${RED}❌ No projects found in $WEB_ROOT${NC}"
            return 1
        fi

        echo -e "\n${YELLOW}Select a project or enter a custom path:${NC}"
        read -p "Enter project number (1-$((count-1))) or full path: " selection

        local project_path=""
        local project_name=""

        # Check if selection is a number
        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -lt "$count" ]; then
            project_name="${projects[$selection]}"
            project_path="$WEB_ROOT/$project_name"
        else
            # Treat as custom path
            project_path=$(realpath "$selection" 2>/dev/null)
            if [ -z "$project_path" ] || [ ! -d "$project_path" ]; then
                echo -e "${RED}❌ Invalid selection or path does not exist: $selection${NC}"
                return 1
            fi
            project_name=$(basename "$project_path")
        fi

        echo "Selected project: $project_name"
        echo "Project path: $project_path"

    else
        echo -e "${RED}❌ $WEB_ROOT directory is empty or does not exist${NC}"
        echo -e "${YELLOW}💡 Use 'Create New Project' or 'Move Project' first${NC}"
        return 1
    fi

    # Get domain name with validation
    while true; do
        read -p "Enter domain name for this project: " domain
        if [ -z "$domain" ] || [ "$domain" = "exit" ]; then
            echo -e "${RED}Error: Please enter a valid domain name${NC}"
            continue
        fi

        # Check if domain already has configuration
        if [ -f "${NGINX_DIR}/sites-available/${domain}" ]; then
            echo -e "${YELLOW}Warning: Nginx configuration already exists for domain: $domain${NC}"
            read -p "Overwrite existing configuration? [y/N] " overwrite
            if [[ "$overwrite" =~ ^[Yy]$ ]]; then
                break
            else
                continue
            fi
        fi

        # Basic domain validation
        if [[ "$domain" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]] || [[ "$domain" =~ \.test$ ]] || [[ "$domain" =~ \.local$ ]]; then
            break
        else
            echo -e "${YELLOW}Warning: '$domain' doesn't look like a valid domain. Continue anyway? [y/N]${NC}"
            read -p "" confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                break
            fi
        fi
    done

    # Detect project type and set document root
    local is_laravel=false
    local document_root="$project_path"

    if [ -f "$project_path/artisan" ] && [ -d "$project_path/app" ] && [ -f "$project_path/composer.json" ]; then
        is_laravel=true
        document_root="$project_path/public"
        echo -e "${GREEN}Laravel project detected!${NC}"
        echo "Document root will be set to: $document_root"

        # Offer to fix Laravel permissions
        read -p "Fix Laravel permissions? [Y/n] " fix_perms
        if [[ ! "$fix_perms" =~ ^[Nn]$ ]]; then
            echo "Setting Laravel permissions..."
            for dir in storage bootstrap/cache; do
                if [ -d "$project_path/$dir" ]; then
                    sudo chown -R "$CURRENT_USER":www-data "$project_path/$dir"
                    sudo find "$project_path/$dir" -type d -exec chmod 775 {} \;
                    sudo find "$project_path/$dir" -type f -exec chmod 664 {} \;
                    sudo chmod -R g+s "$project_path/$dir"
                fi
            done

            # Handle database directory if exists
            if [ -d "$project_path/database" ]; then
                sudo chown -R "$CURRENT_USER":www-data "$project_path/database"
                sudo find "$project_path/database" -type d -exec chmod 775 {} \;
                sudo find "$project_path/database" -type f -exec chmod 664 {} \;
                sudo chmod -R g+s "$project_path/database"
            fi

            # Set execute permissions for artisan
            if [ -f "$project_path/artisan" ]; then
                sudo chmod +x "$project_path/artisan"
            fi

            echo -e "${GREEN}✅ Laravel permissions set${NC}"
        fi

        # Check for missing files
        if [ ! -f "$project_path/.env" ] && [ -f "$project_path/.env.example" ]; then
            read -p "Create .env file from .env.example? [Y/n] " create_env
            if [[ ! "$create_env" =~ ^[Nn]$ ]]; then
                sudo -u "$CURRENT_USER" cp "$project_path/.env.example" "$project_path/.env"
                echo -e "${GREEN}✅ .env file created${NC}"

                # Generate app key if needed
                if grep -q "APP_KEY=$" "$project_path/.env" 2>/dev/null; then
                    read -p "Generate Laravel application key? [Y/n] " gen_key
                    if [[ ! "$gen_key" =~ ^[Nn]$ ]]; then
                        sudo -u "$CURRENT_USER" bash -c "cd '$project_path' && php artisan key:generate --ansi"
                        echo -e "${GREEN}✅ Application key generated${NC}"
                    fi
                fi
            fi
        fi

        # Check for vendor directory
        if [ ! -d "$project_path/vendor" ] && [ -f "$project_path/composer.json" ]; then
            read -p "Install Composer dependencies? [Y/n] " install_deps
            if [[ ! "$install_deps" =~ ^[Nn]$ ]]; then
                echo "Installing Composer dependencies..."
                if sudo -u "$CURRENT_USER" bash -c "cd '$project_path' && composer install --no-dev --optimize-autoloader"; then
                    echo -e "${GREEN}✅ Composer dependencies installed${NC}"
                else
                    echo -e "${YELLOW}⚠️  Failed to install Composer dependencies${NC}"
                fi
            fi
        fi

    else
        echo "Standard PHP project detected."
        echo "Document root will be set to: $document_root"

        # Check for index file
        if [ ! -f "$project_path/index.php" ] && [ ! -f "$project_path/index.html" ] && [ ! -f "$project_path/index.htm" ]; then
            read -p "No index file found. Create index.php? [Y/n] " create_index
            if [[ ! "$create_index" =~ ^[Nn]$ ]]; then
                echo "Creating welcome index.php..."
                sudo bash -c "cat > '$project_path/index.php'" <<EOL
<?php
echo "<html><head><title>Welcome to $domain</title><style>body { font-family: Arial, sans-serif; text-align: center; margin-top: 50px; background: #f5f5f5; }</style></head><body><h1>Project Configured Successfully!</h1><p>Your existing project is now accessible via <strong>http://$domain</strong></p><p>Project location: <code>$project_path</code></p><p>For more information, visit <a href=\"https://github.com/williamug/site-manager\">Site Manager</a>.</p></body></html>";
?>
EOL
                sudo chown "$CURRENT_USER":www-data "$project_path/index.php"
                sudo chmod 644 "$project_path/index.php"
                echo -e "${GREEN}✅ Welcome index.php created${NC}"
            fi
        fi
    fi

    # Ensure proper basic permissions
    sudo chown -R "$CURRENT_USER":www-data "$project_path"
    sudo find "$project_path" -type d -exec chmod 755 {} \;
    sudo find "$project_path" -type f -exec chmod 644 {} \;

    # Setup Nginx configuration
    echo -e "\n${YELLOW}Creating Nginx configuration...${NC}"
    setup_nginx "$domain" "$document_root"

    echo -e "${GREEN}✅ Project successfully configured!${NC}"
    echo -e "${GREEN}📁 Project: ${project_name}${NC}"
    echo -e "${GREEN}📂 Location: ${project_path}${NC}"
    echo -e "${GREEN}🌐 URL: http://${domain}${NC}"

    if [ "$is_laravel" = true ]; then
        echo -e "${YELLOW}💡 Laravel Tips:${NC}"
        echo "   • Configure your .env file: $project_path/.env"
        echo "   • Run migrations: php artisan migrate"
        echo "   • Install npm dependencies: npm install && npm run build"
        echo "   • Check storage and cache permissions"
    fi
}

create_site() {
    local CURRENT_USER
    CURRENT_USER=$(get_current_user)
    read -p "Enter domain name (e.g., example.test): " domain
    read -p "Project path relative to ${WEB_ROOT}: " path
    read -p "Is this a Laravel project? [y/N]: " laravel

    full_path="${WEB_ROOT}/${path}"

    sudo mkdir -p "$full_path"
    sudo chown -R "$CURRENT_USER":www-data "$full_path"
    sudo chmod -R 775 "$full_path"

    if [[ "$laravel" =~ ^[Yy]$ ]]; then
        if [ -z "$(ls -A "$full_path")" ]; then
            echo "Installing Laravel project..."
            sudo -u "$CURRENT_USER" -i bash -c "cd '$full_path' && composer create-project --prefer-dist laravel/laravel ."
            if [ $? -ne 0 ]; then
                echo "Laravel installation failed!"
                exit 1
            fi
            echo -e "\n${YELLOW}Setting Laravel directory permissions...${NC}"
            sudo -u "$CURRENT_USER" mkdir -p "$full_path/database"
            for dir in storage bootstrap/cache database; do
                sudo chown -R "$CURRENT_USER":www-data "$full_path/$dir"
                sudo find "$full_path/$dir" -type d -exec chmod 775 {} \;
                sudo find "$full_path/$dir" -type f -exec chmod 664 {} \;
                sudo chmod -R g+s "$full_path/$dir"
            done
            if [ -f "$full_path/.env" ] && grep -E "^[[:space:]]*#?[[:space:]]*DB_CONNECTION=sqlite" "$full_path/.env" > /dev/null; then
                echo "Configuring SQLite database..."
                sudo -u "$CURRENT_USER" touch "$full_path/database/database.sqlite"
                sudo chown "$CURRENT_USER":www-data "$full_path/database/database.sqlite"
                sudo chmod 664 "$full_path/database/database.sqlite"
            fi
        fi
        document_root="${full_path}/public"
    else
        index_file="${full_path}/index.php"
        echo "Creating index.php with welcome message..."
        sudo bash -c "cat > '$index_file'" <<EOL
<?php
    echo "<html><head><title>Welcome</title><style>body { font-family: Arial, sans-serif; text-align: center; margin-top: 50px; }</style></head><body><h1>Welcome to Site Manager</h1><p>If you see this page, Site Manager has successfully installed your project.</p><p>For more information, visit <a href="https://github.com/Williamug/site-manager">GitHub</a>.</p><p>Happy coding!</p></body></html>";
?>
EOL
        sudo chown "$CURRENT_USER":www-data "$index_file"
        sudo chmod 664 "$index_file"
        document_root="$full_path"
    fi

    # Debug: Print document_root to verify it's set correctly
    echo -e "\n${YELLOW}Debug: document_root = ${document_root}${NC}"

    if [ -z "$document_root" ]; then
        echo -e "${RED}Error: document_root is empty!${NC}"
        exit 1
    fi

    setup_nginx "$domain" "$document_root"
    echo -e "${GREEN}Project created: http://${domain}${NC}"
}

delete_site() {
    local domain delete_files project_root document_root
    read -p "Enter domain to delete: " domain
    local config_file="${NGINX_DIR}/sites-available/${domain}"
    if [ ! -f "$config_file" ]; then
        echo -e "${RED}Error: No configuration found for ${domain}${NC}"
        return 1
    fi
    document_root=$(grep -m1 "root " "$config_file" | awk '{print $2}' | tr -d ';')
    if [[ "$document_root" == *"/public" ]]; then
        project_root=$(dirname "$document_root")
    else
        project_root="$document_root"
    fi
    echo -e "\n${RED}WARNING: This will permanently delete:${NC}"
    echo "• Domain configuration: $config_file"
    echo "• Hosts entry: $domain"
    echo "• Project files: $project_root"
    read -p "Are you sure you want to do this? [y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy] ]]; then
        echo "Deletion cancelled"
        return
    fi
    sudo rm -f "$config_file"
    sudo rm -f "${NGINX_DIR}/sites-enabled/${domain}"
    sudo sed -i "/${domain}/d" /etc/hosts
    if [ -d "$project_root" ]; then
        read -p "Delete project files? [y/N] " delete_files
        if [[ "$delete_files" =~ ^[Yy] ]]; then
            sudo rm -rfv "$project_root"
        fi
    fi
    sudo systemctl reload nginx
    echo -e "${GREEN}Project ${domain} removed!${NC}"
}

move_project() {
    local CURRENT_USER
    CURRENT_USER=$(get_current_user)

    echo -e "${YELLOW}Moving Project to /var/www/${NC}"

    # Get source path
    read -p "Enter full path to project: " source_path
    source_path=$(realpath "$source_path" 2>/dev/null)

    if [ -z "$source_path" ] || [ ! -d "$source_path" ]; then
        echo -e "${RED}Error: Source directory '$source_path' does not exist.${NC}"
        return 1
    fi

    echo "Source path resolved to '$source_path'"

    # Get domain name with validation
    while true; do
        read -p "Enter domain name: " domain
        if [ -z "$domain" ] || [ "$domain" = "exit" ]; then
            echo -e "${RED}Error: Please enter a valid domain name (not empty or 'exit')${NC}"
            continue
        fi
        # Basic domain validation
        if [[ "$domain" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]] || [[ "$domain" =~ \.test$ ]] || [[ "$domain" =~ \.local$ ]]; then
            break
        else
            echo -e "${YELLOW}Warning: '$domain' doesn't look like a valid domain. Continue anyway? [y/N]${NC}"
            read -p "" confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                break
            fi
        fi
    done

    project_name=$(basename "$source_path")
    target_path="${WEB_ROOT}/${project_name}"

    echo "Target path will be '$target_path'"

    # Check if target already exists
    if [ -d "$target_path" ]; then
        echo -e "${YELLOW}Warning: Target directory '$target_path' already exists.${NC}"
        read -p "Overwrite? [y/N] " overwrite
        if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
            echo "Operation cancelled."
            return 1
        fi
    fi

    # Create target directory if it doesn't exist
    if ! sudo mkdir -p "$target_path"; then
        echo -e "${RED}Error: Failed to create target directory '$target_path'${NC}"
        return 1
    fi

    # Copy files using rsync
    echo "Copying files from '$source_path' to '$target_path'..."
    if ! sudo rsync -av --exclude='.git' --exclude='node_modules' --exclude='vendor' "$source_path/" "$target_path/"; then
        echo -e "${RED}Error: Failed to copy files to '$target_path'${NC}"
        return 1
    fi

    # Set ownership and basic permissions
    sudo chown -R "$CURRENT_USER":www-data "$target_path"
    sudo find "$target_path" -type d -exec chmod 755 {} \;
    sudo find "$target_path" -type f -exec chmod 644 {} \;

    # Detect if it's a Laravel project
    local is_laravel=false
    local document_root="$target_path"

    if [ -f "$target_path/artisan" ] && [ -d "$target_path/app" ] && [ -f "$target_path/composer.json" ]; then
        is_laravel=true
        document_root="$target_path/public"
        echo -e "${GREEN}Laravel project detected!${NC}"

        # Set Laravel-specific permissions
        echo "Setting Laravel permissions..."
        for dir in storage bootstrap/cache; do
            if [ -d "$target_path/$dir" ]; then
                sudo chown -R "$CURRENT_USER":www-data "$target_path/$dir"
                sudo find "$target_path/$dir" -type d -exec chmod 775 {} \;
                sudo find "$target_path/$dir" -type f -exec chmod 664 {} \;
                sudo chmod -R g+s "$target_path/$dir"
            fi
        done

        # Handle database directory if exists
        if [ -d "$target_path/database" ]; then
            sudo chown -R "$CURRENT_USER":www-data "$target_path/database"
            sudo find "$target_path/database" -type d -exec chmod 775 {} \;
            sudo find "$target_path/database" -type f -exec chmod 664 {} \;
            sudo chmod -R g+s "$target_path/database"
        fi

        # Set execute permissions for artisan
        if [ -f "$target_path/artisan" ]; then
            sudo chmod +x "$target_path/artisan"
        fi

        # Install dependencies if composer.json exists but no vendor directory
        if [ -f "$target_path/composer.json" ] && [ ! -d "$target_path/vendor" ]; then
            echo "Installing Composer dependencies..."
            sudo -u "$CURRENT_USER" bash -c "cd '$target_path' && composer install --no-dev --optimize-autoloader"
        fi

        # Create .env if .env.example exists but no .env
        if [ -f "$target_path/.env.example" ] && [ ! -f "$target_path/.env" ]; then
            echo "Creating .env file from .env.example..."
            sudo -u "$CURRENT_USER" cp "$target_path/.env.example" "$target_path/.env"
            sudo -u "$CURRENT_USER" bash -c "cd '$target_path' && php artisan key:generate --ansi"
        fi
    else
        echo "Standard PHP project detected."
        # Create index.php if no index file exists
        if [ ! -f "$target_path/index.php" ] && [ ! -f "$target_path/index.html" ]; then
            echo "Creating welcome index.php..."
            sudo bash -c "cat > '$target_path/index.php'" <<EOL
<?php
echo "<html><head><title>Welcome to $domain</title><style>body { font-family: Arial, sans-serif; text-align: center; margin-top: 50px; background: #f5f5f5; }</style></head><body><h1>Project Moved Successfully!</h1><p>Your project has been moved to <code>/var/www/</code> and is accessible via <strong>http://$domain</strong></p><p>For more information, visit <a href=\"https://github.com/williamug/site-manager\">Site Manager</a>.</p></body></html>";
?>
EOL
            sudo chown "$CURRENT_USER":www-data "$target_path/index.php"
            sudo chmod 644 "$target_path/index.php"
        fi
    fi

    # Setup Nginx configuration
    setup_nginx "$domain" "$document_root"

    echo -e "${GREEN}✅ Project successfully moved!${NC}"
    echo -e "${GREEN}📁 Location: ${target_path}${NC}"
    echo -e "${GREEN}🌐 URL: http://${domain}${NC}"

    if [ "$is_laravel" = true ]; then
        echo -e "${YELLOW}💡 Laravel Tips:${NC}"
        echo "   • Configure your .env file in $target_path"
        echo "   • Run migrations: php artisan migrate"
        echo "   • Install npm dependencies: npm install && npm run build"
    fi
}


clone_project() {
    local CURRENT_USER
    CURRENT_USER=$(get_current_user)

    echo -e "${YELLOW}Cloning Project from GitHub${NC}"

    # Get and validate repository URL
    while true; do
        read -p "Git repository URL: " repo_url
        if [ -z "$repo_url" ]; then
            echo -e "${RED}Error: Repository URL cannot be empty${NC}"
            continue
        fi

        # Basic URL validation
        if [[ "$repo_url" =~ ^(https?://|git@) ]]; then
            break
        else
            echo -e "${YELLOW}Warning: '$repo_url' doesn't look like a valid Git URL. Continue anyway? [y/N]${NC}"
            read -p "" confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                break
            fi
        fi
    done

    # Get and validate domain name
    while true; do
        read -p "Enter domain name: " domain
        if [ -z "$domain" ] || [ "$domain" = "exit" ]; then
            echo -e "${RED}Error: Please enter a valid domain name${NC}"
            continue
        fi
        # Basic domain validation
        if [[ "$domain" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]] || [[ "$domain" =~ \.test$ ]] || [[ "$domain" =~ \.local$ ]]; then
            break
        else
            echo -e "${YELLOW}Warning: '$domain' doesn't look like a valid domain. Continue anyway? [y/N]${NC}"
            read -p "" confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                break
            fi
        fi
    done

    # Extract project name from repository URL
    if [[ "$repo_url" =~ git@github\.com:(.+)\.git$ ]]; then
        # SSH URL: git@github.com:user/repo.git
        project_name=$(echo "${BASH_REMATCH[1]}" | cut -d'/' -f2)
    elif [[ "$repo_url" =~ https?://[^/]+/(.+)\.git$ ]]; then
        # HTTPS URL: https://github.com/user/repo.git
        project_name=$(echo "${BASH_REMATCH[1]}" | cut -d'/' -f2)
    else
        # Fallback: use basename
        project_name=$(basename "$repo_url" .git)
    fi

    target_path="${WEB_ROOT}/${project_name}"

    echo "Project name: $project_name"
    echo "Target path: $target_path"

    # Check if target directory already exists
    if [ -d "$target_path" ]; then
        echo -e "${YELLOW}Warning: Target directory '$target_path' already exists.${NC}"
        read -p "Remove existing directory and continue? [y/N] " overwrite
        if [[ "$overwrite" =~ ^[Yy]$ ]]; then
            sudo rm -rf "$target_path"
        else
            echo "Operation cancelled."
            return 1
        fi
    fi

    # Create parent directory
    sudo mkdir -p "$(dirname "$target_path")"

    # Clone the repository
    echo -e "\n${YELLOW}Cloning repository...${NC}"
    if sudo -u "$CURRENT_USER" git clone "$repo_url" "$target_path"; then
        echo -e "${GREEN}✅ Repository cloned successfully${NC}"
    else
        echo -e "${RED}❌ Failed to clone repository${NC}"
        return 1
    fi

    # Set basic ownership and permissions
    sudo chown -R "$CURRENT_USER":www-data "$target_path"
    sudo find "$target_path" -type d -exec chmod 755 {} \;
    sudo find "$target_path" -type f -exec chmod 644 {} \;

    # Detect if it's a Laravel project
    local is_laravel=false
    local document_root="$target_path"

    if [ -f "$target_path/artisan" ] && [ -d "$target_path/app" ] && [ -f "$target_path/composer.json" ]; then
        is_laravel=true
        document_root="$target_path/public"
        echo -e "${GREEN}Laravel project detected!${NC}"

        # Set Laravel-specific permissions
        echo "Setting Laravel permissions..."
        for dir in storage bootstrap/cache; do
            if [ -d "$target_path/$dir" ]; then
                sudo chown -R "$CURRENT_USER":www-data "$target_path/$dir"
                sudo find "$target_path/$dir" -type d -exec chmod 775 {} \;
                sudo find "$target_path/$dir" -type f -exec chmod 664 {} \;
                sudo chmod -R g+s "$target_path/$dir"
            fi
        done

        # Handle database directory if exists
        if [ -d "$target_path/database" ]; then
            sudo chown -R "$CURRENT_USER":www-data "$target_path/database"
            sudo find "$target_path/database" -type d -exec chmod 775 {} \;
            sudo find "$target_path/database" -type f -exec chmod 664 {} \;
            sudo chmod -R g+s "$target_path/database"
        fi

        # Set execute permissions for artisan
        if [ -f "$target_path/artisan" ]; then
            sudo chmod +x "$target_path/artisan"
        fi

        # Install Composer dependencies
        if [ -f "$target_path/composer.json" ]; then
            echo "Installing Composer dependencies..."
            if sudo -u "$CURRENT_USER" bash -c "cd '$target_path' && composer install --no-dev --optimize-autoloader"; then
                echo -e "${GREEN}✅ Composer dependencies installed${NC}"
            else
                echo -e "${YELLOW}⚠️  Failed to install Composer dependencies${NC}"
            fi
        fi

        # Create .env if .env.example exists
        if [ -f "$target_path/.env.example" ] && [ ! -f "$target_path/.env" ]; then
            echo "Creating .env file from .env.example..."
            sudo -u "$CURRENT_USER" cp "$target_path/.env.example" "$target_path/.env"
            sudo -u "$CURRENT_USER" bash -c "cd '$target_path' && php artisan key:generate --ansi"
        fi

        # Install NPM dependencies if package.json exists
        if [ -f "$target_path/package.json" ]; then
            echo "Installing NPM dependencies..."
            if sudo -u "$CURRENT_USER" bash -c "cd '$target_path' && npm install"; then
                echo -e "${GREEN}✅ NPM dependencies installed${NC}"
            else
                echo -e "${YELLOW}⚠️  Failed to install NPM dependencies${NC}"
            fi
        fi
    else
        echo "Standard project detected."
        # Create index.php if no index file exists
        if [ ! -f "$target_path/index.php" ] && [ ! -f "$target_path/index.html" ]; then
            echo "Creating welcome index.php..."
            sudo bash -c "cat > '$target_path/index.php'" <<EOL
<?php
echo "<html><head><title>Welcome to $domain</title><style>body { font-family: Arial, sans-serif; text-align: center; margin-top: 50px; background: #f5f5f5; }</style></head><body><h1>Project Cloned Successfully!</h1><p>Your project has been cloned from GitHub and is accessible via <strong>http://$domain</strong></p><p>For more information, visit <a href=\"https://github.com/williamug/site-manager\">Site Manager</a>.</p></body></html>";
?>
EOL
            sudo chown "$CURRENT_USER":www-data "$target_path/index.php"
            sudo chmod 644 "$target_path/index.php"
        fi
    fi

    # Setup Nginx configuration
    setup_nginx "$domain" "$document_root"

    echo -e "${GREEN}✅ Project successfully cloned!${NC}"
    echo -e "${GREEN}📁 Location: ${target_path}${NC}"
    echo -e "${GREEN}🌐 URL: http://${domain}${NC}"

    if [ "$is_laravel" = true ]; then
        echo -e "${YELLOW}💡 Laravel Tips:${NC}"
        echo "   • Configure your .env file in $target_path"
        echo "   • Run migrations: php artisan migrate"
        echo "   • Build assets: npm run build"
    fi
}

setup_nginx() {
    local domain=$1
    local root_path=$2

    # Validate root_path
    if [ -z "$root_path" ]; then
        echo -e "${RED}Error: root_path is empty!${NC}"
        return 1
    fi

    # Validate that the root path exists
    if [ ! -d "$root_path" ]; then
        echo -e "${RED}Error: root_path '$root_path' does not exist!${NC}"
        return 1
    fi

    echo -e "\n${YELLOW}Setting up Nginx configuration for ${domain}${NC}"
    echo "Document root: ${root_path}"

    cat << EOF | sudo tee "${NGINX_DIR}/sites-available/${domain}" > /dev/null
server {
    listen 80;
    server_name ${domain};
    root ${root_path};

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Content-Type-Options "nosniff";

    index index.html index.htm index.php;

    charset utf-8;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    error_page 404 /index.php;

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php$(get_php_version)-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }

    access_log /var/log/nginx/${domain}-access.log;
    error_log /var/log/nginx/${domain}-error.log;
}
EOF

    echo "✅ Nginx config created at ${NGINX_DIR}/sites-available/${domain}"

    # Enable the site
    if sudo ln -sf "${NGINX_DIR}/sites-available/${domain}" "${NGINX_DIR}/sites-enabled/${domain}"; then
        echo "✅ Site enabled: ${NGINX_DIR}/sites-enabled/${domain}"
    else
        echo -e "${RED}❌ Failed to enable site${NC}"
        return 1
    fi

    # Add domain to /etc/hosts
    echo "Adding domain to /etc/hosts..."
    if ! grep -q "127.0.0.1.*${domain}" /etc/hosts; then
        echo "127.0.0.1 ${domain}" | sudo tee -a /etc/hosts > /dev/null
        echo "✅ Added ${domain} to /etc/hosts"
    else
        echo "✅ ${domain} already exists in /etc/hosts"
    fi

    # Test and reload Nginx
    echo "Testing Nginx configuration..."
    if sudo nginx -t; then
        echo "✅ Nginx configuration is valid"
        if sudo systemctl reload nginx; then
            echo "✅ Nginx reloaded successfully"
        else
            echo -e "${RED}❌ Failed to reload Nginx${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ Nginx configuration test failed${NC}"
        return 1
    fi
}

backup_site() {
    local domain=$1
    local CURRENT_USER
    CURRENT_USER=$(get_current_user)

    echo -e "${YELLOW}Creating Project Backup${NC}"

    # Get backup destination
    read -p "Enter custom backup destination (or press Enter to use default [$BACKUP_DIR]): " custom_dest
    if [ -n "$custom_dest" ]; then
        custom_dir="$custom_dest"
    else
        custom_dir="$BACKUP_DIR"
    fi

    # Create backup directory if it doesn't exist
    if ! sudo mkdir -p "$custom_dir"; then
        echo -e "${RED}❌ Failed to create backup directory: $custom_dir${NC}"
        return 1
    fi

    local default_backup_name="${domain}_$(date +%Y%m%d_%H%M%S)"
    echo -e "${YELLOW}Backup destination: ${custom_dir}/${default_backup_name}.tar.gz${NC}"
    echo -e "Default backup name: ${default_backup_name} (press Enter to keep)\n"

    read -p "Enter custom backup name [${default_backup_name}]: " backup_name
    backup_name=${backup_name:-$default_backup_name}

    local backup_dir="${custom_dir}/${backup_name}"
    local backup_file="${backup_dir}.tar.gz"

    # Check if backup file already exists
    if [ -f "$backup_file" ]; then
        echo -e "${YELLOW}Warning: Backup file '$backup_file' already exists.${NC}"
        read -p "Overwrite existing backup? [y/N] " overwrite
        if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
            echo "Backup cancelled."
            return 1
        fi
    fi

    echo -e "\n${YELLOW}Select backup type (default: 1):${NC}"
    PS3="Enter your choice (1-3): "
    local backup_code=false
    local backup_db=false
    select type in "Both project code and database" "Project code only" "Database only"; do
        case $REPLY in
            1) backup_code=true; backup_db=true; break;;
            2) backup_code=true; break;;
            3) backup_db=true; break;;
            *) echo "Using default (Both)"; backup_code=true; backup_db=true; break;;
        esac
    done

    # Get project directory
    read -p "Enter full path of the project directory to backup: " project_dir
    if [ ! -d "$project_dir" ]; then
        echo -e "${RED}❌ Project directory does not exist: $project_dir${NC}"
        return 1
    fi

    # Create temporary backup directory
    local temp_backup_dir="${backup_dir}_temp"
    if ! mkdir -p "$temp_backup_dir"; then
        echo -e "${RED}❌ Failed to create temporary backup directory${NC}"
        return 1
    fi

    # Backup project code
    if $backup_code; then
        echo -e "\n${YELLOW}Backing up project files...${NC}"
        # Use rsync to exclude common large directories
        if rsync -av --exclude='.git' --exclude='node_modules' --exclude='vendor' --exclude='storage/logs/*' --exclude='storage/framework/cache/*' --exclude='storage/framework/sessions/*' --exclude='storage/framework/views/*' "$project_dir/" "$temp_backup_dir/$(basename "$project_dir")/"; then
            echo -e "${GREEN}✅ Project files backed up successfully${NC}"
        else
            echo -e "${RED}❌ Failed to backup project files${NC}"
            rm -rf "$temp_backup_dir"
            return 1
        fi
    fi

    # Backup database
    if $backup_db; then
        echo -e "\n${YELLOW}Backing up database...${NC}"
        read -p "Enter database name: " db_name
        if [ -z "$db_name" ]; then
            echo -e "${YELLOW}⚠️  No database name provided, skipping database backup${NC}"
        else
            read -p "Enter database user: " db_user
            read -s -p "Enter database password: " db_pass
            echo ""

            if [ -n "$db_user" ] && [ -n "$db_pass" ]; then
                echo "Creating database dump..."
                if mysqldump -u "$db_user" -p"$db_pass" "$db_name" > "$temp_backup_dir/db_dump.sql" 2>/dev/null; then
                    echo -e "${GREEN}✅ Database backed up successfully${NC}"
                else
                    echo -e "${RED}❌ Failed to backup database${NC}"
                    echo -e "${YELLOW}⚠️  Continuing with project files backup only...${NC}"
                fi
            else
                echo -e "${YELLOW}⚠️  Database credentials not provided, skipping database backup${NC}"
            fi
        fi
    fi

    # Create final backup archive
    echo -e "\n${YELLOW}Creating backup archive...${NC}"
    if tar -czf "$backup_file" -C "$(dirname "$temp_backup_dir")" "$(basename "$temp_backup_dir")" 2>/dev/null; then
        # Clean up temporary directory
        rm -rf "$temp_backup_dir"

        # Get backup file size
        local backup_size=$(du -h "$backup_file" | cut -f1)

        echo -e "${GREEN}✅ Backup created successfully!${NC}"
        echo -e "${GREEN}📁 Location: $backup_file${NC}"
        echo -e "${GREEN}📦 Size: $backup_size${NC}"
        echo -e "\n${BLUE}💡 To restore this backup, run:${NC}"
        echo -e "   sudo site-manager restore $backup_file"
    else
        echo -e "${RED}❌ Failed to create backup archive${NC}"
        rm -rf "$temp_backup_dir"
        return 1
    fi
}

restore_site() {
    local backup_file=$1
    local CURRENT_USER
    CURRENT_USER=$(get_current_user)

    echo -e "${YELLOW}Restoring Project from Backup${NC}"

    # Validate backup file
    if [ ! -f "$backup_file" ]; then
        echo -e "${RED}❌ Backup file does not exist: $backup_file${NC}"
        return 1
    fi

    # Get domain for restored site
    read -p "Enter domain name for restored site: " restore_domain
    if [ -z "$restore_domain" ]; then
        echo -e "${RED}❌ Domain name is required for restoration${NC}"
        return 1
    fi

    echo -e "\n${YELLOW}Restoring from: ${backup_file}${NC}"

    # Create temporary extraction directory
    local temp_extract_dir="/tmp/site_manager_restore_$$"
    mkdir -p "$temp_extract_dir"

    # Extract backup
    echo "Extracting backup archive..."
    if [[ "$backup_file" == *.tar.gz ]]; then
        if tar -xzf "$backup_file" -C "$temp_extract_dir" 2>/dev/null; then
            echo -e "${GREEN}✅ Backup extracted successfully${NC}"
        else
            echo -e "${RED}❌ Failed to extract backup archive${NC}"
            rm -rf "$temp_extract_dir"
            return 1
        fi
    elif [[ "$backup_file" == *.zip ]]; then
        if unzip -q "$backup_file" -d "$temp_extract_dir" 2>/dev/null; then
            echo -e "${GREEN}✅ Backup extracted successfully${NC}"
        else
            echo -e "${RED}❌ Failed to extract backup archive${NC}"
            rm -rf "$temp_extract_dir"
            return 1
        fi
    else
        echo -e "${RED}❌ Unsupported backup format - use .tar.gz or .zip${NC}"
        rm -rf "$temp_extract_dir"
        return 1
    fi

    # Find the project directory in extraction
    local extracted_project=$(find "$temp_extract_dir" -mindepth 2 -maxdepth 2 -type d | head -1)
    if [ -z "$extracted_project" ] || [ ! -d "$extracted_project" ]; then
        echo -e "${RED}❌ Could not find project directory in backup${NC}"
        rm -rf "$temp_extract_dir"
        return 1
    fi

    local project_name=$(basename "$extracted_project")
    local target_path="${WEB_ROOT}/${project_name}"

    echo "Project name: $project_name"
    echo "Target path: $target_path"

    # Check if target already exists
    if [ -d "$target_path" ]; then
        echo -e "${YELLOW}Warning: Target directory '$target_path' already exists.${NC}"
        read -p "Overwrite existing project? [y/N] " overwrite
        if [[ "$overwrite" =~ ^[Yy]$ ]]; then
            sudo rm -rf "$target_path"
        else
            echo "Restoration cancelled."
            rm -rf "$temp_extract_dir"
            return 1
        fi
    fi

    # Move project to target location
    echo "Moving project to target location..."
    if sudo mv "$extracted_project" "$target_path"; then
        echo -e "${GREEN}✅ Project files restored${NC}"
    else
        echo -e "${RED}❌ Failed to move project files${NC}"
        rm -rf "$temp_extract_dir"
        return 1
    fi

    # Set proper ownership and permissions
    sudo chown -R "$CURRENT_USER":www-data "$target_path"
    sudo find "$target_path" -type d -exec chmod 755 {} \;
    sudo find "$target_path" -type f -exec chmod 644 {} \;

    # Detect if it's a Laravel project and set appropriate document root
    local is_laravel=false
    local document_root="$target_path"

    if [ -f "$target_path/artisan" ] && [ -d "$target_path/app" ] && [ -f "$target_path/composer.json" ]; then
        is_laravel=true
        document_root="$target_path/public"
        echo -e "${GREEN}Laravel project detected!${NC}"

        # Set Laravel-specific permissions
        for dir in storage bootstrap/cache; do
            if [ -d "$target_path/$dir" ]; then
                sudo chown -R "$CURRENT_USER":www-data "$target_path/$dir"
                sudo find "$target_path/$dir" -type d -exec chmod 775 {} \;
                sudo find "$target_path/$dir" -type f -exec chmod 664 {} \;
                sudo chmod -R g+s "$project_path/$dir"
            fi
        done

        # Set execute permissions for artisan
        if [ -f "$target_path/artisan" ]; then
            sudo chmod +x "$target_path/artisan"
        fi
    fi

    # Restore database if dump exists
    local db_dump_file="$temp_extract_dir/$(basename "$temp_extract_dir")/db_dump.sql"
    if [ -f "$db_dump_file" ]; then
        echo -e "\n${YELLOW}Database dump found. Restore database? [y/N]${NC}"
        read -p "" restore_db
        if [[ "$restore_db" =~ ^[Yy]$ ]]; then
            read -p "Enter database name: " db_name
            read -p "Enter database user: " db_user
            read -s -p "Enter database password: " db_pass
            echo ""

            if [ -n "$db_name" ] && [ -n "$db_user" ] && [ -n "$db_pass" ]; then
                echo "Restoring database..."
                if mysql -u "$db_user" -p"$db_pass" "$db_name" < "$db_dump_file" 2>/dev/null; then
                    echo -e "${GREEN}✅ Database restored successfully${NC}"
                else
                    echo -e "${RED}❌ Failed to restore database${NC}"
                fi
            else
                echo -e "${YELLOW}⚠️  Database credentials not provided, skipping database restore${NC}"
            fi
        fi
    fi

    # Clean up extraction directory
    rm -rf "$temp_extract_dir"

    # Setup Nginx configuration
    setup_nginx "$restore_domain" "$document_root"

    echo -e "${GREEN}✅ Project successfully restored!${NC}"
    echo -e "${GREEN}📁 Location: ${target_path}${NC}"
    echo -e "${GREEN}🌐 URL: http://${restore_domain}${NC}"

    if [ "$is_laravel" = true ]; then
        echo -e "${YELLOW}💡 Laravel Tips:${NC}"
        echo "   • Check your .env file configuration"
        echo "   • Run composer install if needed"
        echo "   • Run migrations: php artisan migrate"
    fi
}

setup_ssl() {
    local domain=$1

    echo -e "${YELLOW}Setting up SSL Certificate${NC}"

    # Validate domain parameter
    if [ -z "$domain" ]; then
        echo -e "${RED}❌ Domain name is required${NC}"
        return 1
    fi

    # Check if nginx config exists for this domain
    local nginx_config="/etc/nginx/sites-available/$domain"
    if [ ! -f "$nginx_config" ]; then
        echo -e "${RED}❌ Nginx configuration not found for domain: $domain${NC}"
        echo -e "${YELLOW}💡 Please create the site first using site-manager${NC}"
        return 1
    fi

    # Check if nginx config is enabled
    if [ ! -L "/etc/nginx/sites-enabled/$domain" ]; then
        echo -e "${YELLOW}⚠️  Nginx site is not enabled. Enabling now...${NC}"
        sudo ln -sf "$nginx_config" "/etc/nginx/sites-enabled/$domain"
        sudo nginx -t && sudo systemctl reload nginx
    fi

    # Detect if this is a local development domain
    local is_local_domain=false
    if [[ "$domain" =~ \.(test|local|dev)$ ]] || [[ "$domain" =~ ^localhost ]]; then
        is_local_domain=true
    fi

    if [ "$is_local_domain" = true ]; then
        echo -e "\n${BLUE}🔍 Local development domain detected: $domain${NC}"
        echo -e "${YELLOW}Since this is a local domain (.test/.local/.dev), Let's Encrypt cannot issue certificates.${NC}"
        echo -e "${GREEN}I'll create a self-signed certificate for local HTTPS development.${NC}"
        echo ""
        echo -e "${BLUE}Self-signed certificates provide:${NC}"
        echo "  ✅ Full HTTPS functionality for local development"
        echo "  ✅ Same behavior as Laravel Valet"
        echo "  ✅ Testing SSL/TLS features locally"
        echo "  ⚠️  Browser security warning (can be ignored for local dev)"
        echo ""

        read -p "Create self-signed SSL certificate for $domain? [Y/n] " create_selfsigned
        if [[ "$create_selfsigned" =~ ^[Nn]$ ]]; then
            echo "SSL setup cancelled."
            return 0
        fi

        setup_selfsigned_ssl "$domain"
        return $?
    fi

    # For public domains, continue with Let's Encrypt...
    echo -e "\n${BLUE}🌐 Public domain detected: $domain${NC}"
    echo -e "${YELLOW}Setting up Let's Encrypt SSL certificate...${NC}"

    # Check if certbot is installed
    if ! command -v certbot &>/dev/null; then
        echo -e "${YELLOW}Installing Certbot and Nginx plugin...${NC}"
        if sudo apt update && sudo apt install -y certbot python3-certbot-nginx; then
            echo -e "${GREEN}✅ Certbot installed successfully${NC}"
        else
            echo -e "${RED}❌ Failed to install Certbot${NC}"
            return 1
        fi
    else
        echo -e "${GREEN}✅ Certbot is already installed${NC}"
    fi

    # Prompt for email (required for Let's Encrypt)
    echo -e "\n${YELLOW}Let's Encrypt requires an email address for certificate registration${NC}"
    echo -e "${BLUE}This email will be used for:${NC}"
    echo "• Certificate expiry notifications"
    echo "• Important security updates"
    echo "• Account recovery"

    while true; do
        read -p "Enter your email address: " email
        if [ -z "$email" ]; then
            read -p "Skip email registration? [y/N] " skip_email
            if [[ "$skip_email" =~ ^[Yy]$ ]]; then
                email_flag="--register-unsafely-without-email"
                break
            else
                echo -e "${RED}Email address is required${NC}"
                continue
            fi
        elif [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            email_flag="--email $email"
            break
        else
            echo -e "${RED}Please enter a valid email address${NC}"
        fi
    done

    # Test nginx configuration before proceeding
    echo -e "\n${YELLOW}Testing Nginx configuration...${NC}"
    if ! sudo nginx -t; then
        echo -e "${RED}❌ Nginx configuration test failed${NC}"
        echo -e "${YELLOW}Please fix nginx configuration before setting up SSL${NC}"
        return 1
    fi

    # Check if domain is accessible (optional but recommended)
    echo -e "${YELLOW}Checking domain accessibility...${NC}"
    if curl -s --connect-timeout 5 "http://$domain" > /dev/null; then
        echo -e "${GREEN}✅ Domain is accessible${NC}"
    else
        echo -e "${YELLOW}⚠️  Warning: Domain might not be accessible from the internet${NC}"
        echo -e "${BLUE}For Let's Encrypt to work, your domain must be:${NC}"
        echo "• Pointing to this server's public IP"
        echo "• Accessible from the internet on port 80"

        read -p "Continue anyway? [y/N] " continue_ssl
        if [[ ! "$continue_ssl" =~ ^[Yy]$ ]]; then
            echo "SSL setup cancelled."
            return 1
        fi
    fi

    # Request SSL certificate
    echo -e "\n${YELLOW}Requesting SSL certificate for $domain...${NC}"
    local certbot_cmd="sudo certbot --nginx -d $domain $email_flag --agree-tos --non-interactive"

    # Add staging flag for testing (uncomment for testing)
    # certbot_cmd="$certbot_cmd --staging"

    echo "Running: $certbot_cmd"
    if $certbot_cmd; then
        echo -e "${GREEN}✅ SSL certificate installed successfully!${NC}"

        # Reload nginx to ensure new config is active
        if sudo systemctl reload nginx; then
            echo -e "${GREEN}✅ Nginx reloaded with SSL configuration${NC}"
        else
            echo -e "${YELLOW}⚠️  Warning: Failed to reload Nginx${NC}"
        fi

        # Test HTTPS
        echo -e "\n${YELLOW}Testing HTTPS connection...${NC}"
        if curl -s --connect-timeout 5 "https://$domain" > /dev/null; then
            echo -e "${GREEN}✅ HTTPS is working correctly${NC}"
        else
            echo -e "${YELLOW}⚠️  HTTPS test failed - certificate might still be propagating${NC}"
        fi

        echo -e "\n${GREEN}🎉 SSL setup completed successfully!${NC}"
        echo -e "${BLUE}💡 Important Information:${NC}"
        echo -e "• Your site is now available at: https://$domain"
        echo -e "• HTTP traffic will be automatically redirected to HTTPS"
        echo -e "• Certificate will auto-renew (Let's Encrypt handles this)"
        echo -e "• You can test renewal with: sudo certbot renew --dry-run"

    else
        echo -e "${RED}❌ Failed to obtain SSL certificate${NC}"
        echo -e "${BLUE}💡 Common issues:${NC}"
        echo "• Domain not pointing to this server"
        echo "• Firewall blocking port 80/443"
        echo "• Domain not accessible from internet"
        echo "• Rate limiting (try again later)"

        # Check certbot logs for more details
        echo -e "\n${YELLOW}Check certbot logs for details:${NC}"
        echo "  sudo tail -f /var/log/letsencrypt/letsencrypt.log"

        return 1
    fi
}

setup_selfsigned_ssl() {
    local domain=$1
    local cert_dir="/etc/ssl/site-manager"
    local nginx_config="/etc/nginx/sites-available/$domain"

    echo -e "${YELLOW}Creating self-signed SSL certificate for $domain...${NC}"

    # Create certificate directory
    sudo mkdir -p "$cert_dir"

    # Generate private key
    echo "Generating private key..."
    if sudo openssl genrsa -out "$cert_dir/$domain.key" 2048 2>/dev/null; then
        echo -e "${GREEN}✅ Private key generated${NC}"
    else
        echo -e "${RED}❌ Failed to generate private key${NC}"
        return 1
    fi

    # Create certificate configuration
    echo "Creating certificate configuration..."
    cat << EOF | sudo tee "$cert_dir/$domain.conf" > /dev/null
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[dn]
C=US
ST=Local
L=Local
O=Site Manager
OU=Development
CN=$domain

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = $domain
DNS.2 = *.$domain
EOF

    # Generate certificate
    echo "Generating self-signed certificate..."
    if sudo openssl req -new -x509 -key "$cert_dir/$domain.key" -out "$cert_dir/$domain.crt" -days 3650 -config "$cert_dir/$domain.conf" -extensions v3_req 2>/dev/null; then
        echo -e "${GREEN}✅ Self-signed certificate generated (valid for 10 years)${NC}"
    else
        echo -e "${RED}❌ Failed to generate certificate${NC}"
        return 1
    fi

    # Set proper permissions
    sudo chmod 600 "$cert_dir/$domain.key"
    sudo chmod 644 "$cert_dir/$domain.crt"

    # Backup existing nginx config
    echo "Backing up Nginx configuration..."
    sudo cp "$nginx_config" "$nginx_config.backup.$(date +%Y%m%d_%H%M%S)"

    # Get document root from existing config
    local document_root=$(grep -m1 "root " "$nginx_config" | awk '{print $2}' | tr -d ';')

    if [ -z "$document_root" ]; then
        echo -e "${RED}❌ Could not determine document root from existing config${NC}"
        return 1
    fi

    # Create SSL-enabled Nginx configuration
    echo "Creating SSL-enabled Nginx configuration..."
    cat << EOF | sudo tee "$nginx_config" > /dev/null
server {
    listen 80;
    server_name $domain;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $domain;
    root $document_root;

    # SSL Configuration
    ssl_certificate $cert_dir/$domain.crt;
    ssl_certificate_key $cert_dir/$domain.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    index index.html index.htm index.php;
    charset utf-8;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    error_page 404 /index.php;

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php$(get_php_version)-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_param HTTPS on;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }

    access_log /var/log/nginx/$domain-access.log;
    error_log /var/log/nginx/$domain-error.log;
}
EOF

    # Test nginx configuration
    echo "Testing Nginx configuration..."
    if sudo nginx -t; then
        echo -e "${GREEN}✅ Nginx configuration is valid${NC}"

        # Reload nginx
        if sudo systemctl reload nginx; then
            echo -e "${GREEN}✅ Nginx reloaded successfully${NC}"
        else
            echo -e "${RED}❌ Failed to reload Nginx${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ Nginx configuration test failed${NC}"
        echo "Restoring backup configuration..."
        sudo cp "$nginx_config.backup.$(date +%Y%m%d_%H%M%S)" "$nginx_config"
        return 1
    fi

    # Test HTTPS
    echo -e "\n${YELLOW}Testing HTTPS connection...${NC}"
    if curl -k -s --connect-timeout 5 "https://$domain" > /dev/null; then
        echo -e "${GREEN}✅ HTTPS is working correctly${NC}"
    else
        echo -e "${YELLOW}⚠️  HTTPS test failed${NC}"
    fi

    echo -e "\n${GREEN}🎉 Self-signed SSL setup completed successfully!${NC}"
    echo -e "${BLUE}💡 Important Information:${NC}"
    echo -e "• Your site is now available at: https://$domain"
    echo -e "• HTTP traffic is automatically redirected to HTTPS"
    echo -e "• Certificate is valid for 10 years"
    echo -e "• ${YELLOW}Browser will show 'Not Secure' warning (this is normal for self-signed certificates)${NC}"

    echo -e "\n${YELLOW}💡 How to trust the certificate (optional):${NC}"
    echo -e "${BLUE}Chrome/Edge:${NC}"
    echo "  1. Visit https://$domain"
    echo "  2. Click 'Advanced' → 'Proceed to $domain (unsafe)'"
    echo "  3. Or add certificate to system trust store"

    echo -e "\n${BLUE}Firefox:${NC}"
    echo "  1. Visit https://$domain"
    echo "  2. Click 'Advanced' → 'Accept the Risk and Continue'"

    echo -e "\n${BLUE}System-wide trust (Ubuntu/Debian):${NC}"
    echo "  sudo cp $cert_dir/$domain.crt /usr/local/share/ca-certificates/"
    echo "  sudo update-ca-certificates"

    echo -e "\n${GREEN}🔧 Certificate Details:${NC}"
    echo "  • Certificate: $cert_dir/$domain.crt"
    echo "  • Private Key: $cert_dir/$domain.key"
    echo "  • Configuration: $cert_dir/$domain.conf"

    echo -e "\n${YELLOW}💡 Perfect for:${NC}"
    echo "  • Laravel development with HTTPS"
    echo "  • Testing SSL/TLS features locally"
    echo "  • API development requiring HTTPS"
    echo "  • PWA development (requires HTTPS)"
}

update_ssl() {
    local domain=$1
    local CURRENT_USER
    CURRENT_USER=$(get_current_user)

    echo -e "${YELLOW}Update/Renew SSL Certificate${NC}"

    # Get domain if not provided
    if [ -z "$domain" ]; then
        echo -e "\n${BLUE}Available domains with SSL certificates:${NC}"
        if [ -d "/etc/letsencrypt/live" ]; then
            local count=1
            local domains=()

            for cert_dir in /etc/letsencrypt/live/*; do
                if [ -d "$cert_dir" ] && [ "$(basename "$cert_dir")" != "README" ]; then
                    local domain_name=$(basename "$cert_dir")
                    domains[count]="$domain_name"

                    # Check certificate expiry
                    local cert_file="$cert_dir/cert.pem"
                    if [ -f "$cert_file" ]; then
                        local expiry_date=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
                        local days_left=$(( ($(date -d "$expiry_date" +%s) - $(date +%s)) / 86400 ))

                        if [ $days_left -lt 30 ]; then
                            echo "  $count) $domain_name ${RED}(expires in $days_left days)${NC}"
                        elif [ $days_left -lt 60 ]; then
                            echo "  $count) $domain_name ${YELLOW}(expires in $days_left days)${NC}"
                        else
                            echo "  $count) $domain_name ${GREEN}(expires in $days_left days)${NC}"
                        fi
                    else
                        echo "  $count) $domain_name (unable to check expiry)"
                    fi
                    ((count++))
                fi
            done

            if [ ${#domains[@]} -eq 0 ]; then
                echo -e "${RED}❌ No SSL certificates found${NC}"
                return 1
            fi

            echo -e "\n${YELLOW}Select a domain or enter domain name:${NC}"
            read -p "Enter domain number (1-$((count-1))) or domain name: " selection

            # Check if selection is a number
            if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -lt "$count" ]; then
                domain="${domains[$selection]}"
            else
                domain="$selection"
            fi
        else
            read -p "Enter domain name: " domain
        fi
    fi

    # Validate domain
    if [ -z "$domain" ]; then
        echo -e "${RED}❌ Domain name is required${NC}"
        return 1
    fi

    # Check if certificate exists
    if [ ! -d "/etc/letsencrypt/live/$domain" ]; then
        echo -e "${RED}❌ No SSL certificate found for domain: $domain${NC}"
        echo -e "${YELLOW}💡 Use 'Setup SSL' to create a new certificate${NC}"
        return 1
    fi

    local cert_file="/etc/letsencrypt/live/$domain/cert.pem"

    # Display current certificate information
    echo -e "\n${BLUE}Current certificate information for $domain:${NC}"
    if [ -f "$cert_file" ]; then
        local issuer=$(openssl x509 -in "$cert_file" -noout -issuer | sed 's/.*CN=\([^,]*\).*/\1/')
        local subject=$(openssl x509 -in "$cert_file" -noout -subject | sed 's/.*CN=\([^,]*\).*/\1/')
        local not_before=$(openssl x509 -in "$cert_file" -noout -startdate | cut -d= -f2)
        local not_after=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
        local days_left=$(( ($(date -d "$not_after" +%s) - $(date +%s)) / 86400 ))

        echo "  Subject: $subject"
        echo "  Issuer: $issuer"
        echo "  Valid from: $not_before"
        echo "  Valid until: $not_after"

        if [ $days_left -lt 0 ]; then
            echo -e "  Status: ${RED}❌ EXPIRED ($((0 - days_left)) days ago)${NC}"
        elif [ $days_left -lt 7 ]; then
            echo -e "  Status: ${RED}⚠️  CRITICAL - Expires in $days_left days${NC}"
        elif [ $days_left -lt 30 ]; then
            echo -e "  Status: ${YELLOW}⚠️  WARNING - Expires in $days_left days${NC}"
        else
            echo -e "  Status: ${GREEN}✅ Valid for $days_left more days${NC}"
        fi
    fi

    echo -e "\n${YELLOW}What would you like to do?${NC}"
    echo "1) Renew certificate (recommended for expiring certs)"
    echo "2) Force certificate renewal (recreate certificate)"
    echo "3) Test certificate renewal (dry run)"
    echo "4) Expand certificate (add more domains)"
    echo "5) Check all certificates status"
    echo "6) Cancel"

    read -p "Select option [1-6]: " ssl_choice

    case $ssl_choice in
        1)
            echo -e "\n${YELLOW}Renewing SSL certificate for $domain...${NC}"
            renew_certificate "$domain"
            ;;
        2)
            echo -e "\n${YELLOW}Force renewing SSL certificate for $domain...${NC}"
            force_renew_certificate "$domain"
            ;;
        3)
            echo -e "\n${YELLOW}Testing certificate renewal (dry run)...${NC}"
            test_certificate_renewal "$domain"
            ;;
        4)
            echo -e "\n${YELLOW}Expanding certificate to include more domains...${NC}"
            expand_certificate "$domain"
            ;;
        5)
            echo -e "\n${YELLOW}Checking all certificates status...${NC}"
            check_all_certificates
            ;;
        6)
            echo "Operation cancelled."
            return 0
            ;;
        *)
            echo -e "${RED}❌ Invalid option${NC}"
            return 1
            ;;
    esac
}

renew_certificate() {
    local domain=$1

    echo "Attempting to renew certificate for $domain..."

    if sudo certbot renew --cert-name "$domain"; then
        echo -e "${GREEN}✅ Certificate renewed successfully!${NC}"

        # Reload nginx
        if sudo systemctl reload nginx; then
            echo -e "${GREEN}✅ Nginx reloaded${NC}"
        else
            echo -e "${YELLOW}⚠️  Warning: Failed to reload Nginx${NC}"
        fi

        # Test the renewed certificate
        echo -e "\n${YELLOW}Testing renewed certificate...${NC}"
        if curl -s --connect-timeout 5 "https://$domain" > /dev/null; then
            echo -e "${GREEN}✅ HTTPS is working correctly${NC}"
        else
            echo -e "${YELLOW}⚠️  HTTPS test failed${NC}"
        fi

    else
        echo -e "${RED}❌ Certificate renewal failed${NC}"
        echo -e "${YELLOW}💡 Certificate might not be due for renewal yet${NC}"
        echo -e "${BLUE}Certificates are automatically renewed when they have 30 days or less remaining${NC}"
        return 1
    fi
}

force_renew_certificate() {
    local domain=$1

    echo -e "${RED}⚠️  WARNING: This will force renewal even if not needed${NC}"
    read -p "Are you sure you want to force renew? [y/N] " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Operation cancelled."
        return 0
    fi

    echo "Force renewing certificate for $domain..."

    if sudo certbot renew --cert-name "$domain" --force-renewal; then
        echo -e "${GREEN}✅ Certificate force renewed successfully!${NC}"

        # Reload nginx
        if sudo systemctl reload nginx; then
            echo -e "${GREEN}✅ Nginx reloaded${NC}"
        else
            echo -e "${YELLOW}⚠️  Warning: Failed to reload Nginx${NC}"
        fi

    else
        echo -e "${RED}❌ Certificate force renewal failed${NC}"
        return 1
    fi
}

test_certificate_renewal() {
    local domain=$1

    echo "Testing certificate renewal for $domain (dry run)..."

    if sudo certbot renew --cert-name "$domain" --dry-run; then
        echo -e "${GREEN}✅ Certificate renewal test passed!${NC}"
        echo -e "${BLUE}Your certificate can be renewed successfully when needed${NC}"
    else
        echo -e "${RED}❌ Certificate renewal test failed${NC}"
        echo -e "${YELLOW}There might be issues with your domain configuration${NC}"
        return 1
    fi
}

expand_certificate() {
    local domain=$1

    echo "Current certificate covers: $domain"
    echo -e "\n${YELLOW}Enter additional domains to add to this certificate:${NC}"
    echo -e "${BLUE}Examples: www.$domain, api.$domain, admin.$domain${NC}"
    echo -e "${YELLOW}Enter domains separated by spaces:${NC}"

    read -p "Additional domains: " additional_domains

    if [ -z "$additional_domains" ]; then
        echo "No additional domains specified."
        return 0
    fi

    # Build the certbot command with all domains
    local all_domains="$domain $additional_domains"
    local domain_flags=""

    for d in $all_domains; do
        domain_flags="$domain_flags -d $d"
    done

    echo -e "\n${YELLOW}Expanding certificate to cover: $all_domains${NC}"
    read -p "Continue? [y/N] " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Operation cancelled."
        return 0
    fi

    # Use --expand flag to add domains to existing certificate
    if sudo certbot --nginx $domain_flags --expand --non-interactive; then
        echo -e "${GREEN}✅ Certificate expanded successfully!${NC}"
        echo -e "${GREEN}Certificate now covers: $all_domains${NC}"

        # Reload nginx
        if sudo systemctl reload nginx; then
            echo -e "${GREEN}✅ Nginx reloaded${NC}"
        else
            echo -e "${YELLOW}⚠️  Warning: Failed to reload Nginx${NC}"
        fi

    else
        echo -e "${RED}❌ Certificate expansion failed${NC}"
        echo -e "${YELLOW}💡 Make sure all domains point to this server and are accessible${NC}"
        return 1
    fi
}

check_all_certificates() {
    echo -e "${BLUE}Checking all SSL certificates...${NC}\n"

    if [ ! -d "/etc/letsencrypt/live" ]; then
        echo -e "${RED}❌ No certificates directory found${NC}"
        return 1
    fi

    local cert_count=0
    local expiring_soon=0
    local expired=0

    for cert_dir in /etc/letsencrypt/live/*; do
        if [ -d "$cert_dir" ] && [ "$(basename "$cert_dir")" != "README" ]; then
            local domain_name=$(basename "$cert_dir")
            local cert_file="$cert_dir/cert.pem"

            if [ -f "$cert_file" ]; then
                cert_count=$((cert_count + 1))

                local not_after=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
                local days_left=$(( ($(date -d "$not_after" +%s) - $(date +%s)) / 86400 ))

                printf "%-30s " "$domain_name"

                if [ $days_left -lt 0 ]; then
                    echo -e "${RED}❌ EXPIRED ($((0 - days_left)) days ago)${NC}"
                    expired=$((expired + 1))
                elif [ $days_left -lt 7 ]; then
                    echo -e "${RED}⚠️  CRITICAL - $days_left days left${NC}"
                    expiring_soon=$((expiring_soon + 1))
                elif [ $days_left -lt 30 ]; then
                    echo -e "${YELLOW}⚠️  WARNING - $days_left days left${NC}"
                    expiring_soon=$((expiring_soon + 1))
                else
                    echo -e "${GREEN}✅ Valid for $days_left days${NC}"
                fi
            fi
        fi
    done

    echo -e "\n${BLUE}Summary:${NC}"
    echo "  Total certificates: $cert_count"
    echo "  Expiring soon (< 30 days): $expiring_soon"
    echo "  Expired: $expired"

    if [ $expired -gt 0 ] || [ $expiring_soon -gt 0 ]; then
        echo -e "\n${YELLOW}💡 Recommended actions:${NC}"
        if [ $expired -gt 0 ]; then
            echo "  • Renew expired certificates immediately"
        fi
        if [ $expiring_soon -gt 0 ]; then
            echo "  • Schedule renewal for expiring certificates"
        fi
        echo "  • Set up automatic renewal: sudo crontab -e"
        echo "    Add: 0 12 * * * /usr/bin/certbot renew --quiet"
    else
        echo -e "\n${GREEN}✅ All certificates are healthy!${NC}"
    fi
}

remove_ssl() {
    local domain=$1
    local CURRENT_USER
    CURRENT_USER=$(get_current_user)

    echo -e "${YELLOW}Remove/Disable SSL Certificate${NC}"

    # Get domain if not provided
    if [ -z "$domain" ]; then
        echo -e "\n${BLUE}Available domains with SSL certificates:${NC}"
        if [ -d "/etc/letsencrypt/live" ]; then
            local count=1
            local domains=()

            for cert_dir in /etc/letsencrypt/live/*; do
                if [ -d "$cert_dir" ] && [ "$(basename "$cert_dir")" != "README" ]; then
                    local domain_name=$(basename "$cert_dir")
                    domains[count]="$domain_name"

                    # Check if nginx config has SSL enabled
                    local nginx_config="/etc/nginx/sites-available/$domain_name"
                    if [ -f "$nginx_config" ] && grep -q "listen 443" "$nginx_config"; then
                        echo "  $count) $domain_name ${GREEN}(SSL enabled in Nginx)${NC}"
                    else
                        echo "  $count) $domain_name ${YELLOW}(SSL certificate exists but not in Nginx)${NC}"
                    fi
                    ((count++))
                fi
            done

            if [ ${#domains[@]} -eq 0 ]; then
                echo -e "${RED}❌ No SSL certificates found${NC}"
                return 1
            fi

            echo -e "\n${YELLOW}Select a domain or enter domain name:${NC}"
            read -p "Enter domain number (1-$((count-1))) or domain name: " selection

            # Check if selection is a number
            if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -lt "$count" ]; then
                domain="${domains[$selection]}"
            else
                domain="$selection"
            fi
        else
            read -p "Enter domain name: " domain
        fi
    fi

    # Validate domain
    if [ -z "$domain" ]; then
        echo -e "${RED}❌ Domain name is required${NC}"
        return 1
    fi

    # Check if nginx config exists
    local nginx_config="/etc/nginx/sites-available/$domain"
    if [ ! -f "$nginx_config" ]; then
        echo -e "${RED}❌ Nginx configuration not found for domain: $domain${NC}"
        echo -e "${YELLOW}💡 The domain might not be managed by site-manager${NC}"
        return 1
    fi

    # Check if SSL is actually configured in nginx
    local has_ssl_nginx=false
    if grep -q "listen 443" "$nginx_config" || grep -q "ssl_certificate" "$nginx_config"; then
        has_ssl_nginx=true
    fi

    # Check if Let's Encrypt certificate exists
    local has_letsencrypt=false
    if [ -d "/etc/letsencrypt/live/$domain" ]; then
        has_letsencrypt=true
    fi

    # Display current SSL status
    echo -e "\n${BLUE}Current SSL status for $domain:${NC}"
    if [ "$has_ssl_nginx" = true ]; then
        echo -e "  • Nginx SSL configuration: ${GREEN}✅ Enabled${NC}"
    else
        echo -e "  • Nginx SSL configuration: ${RED}❌ Not configured${NC}"
    fi

    if [ "$has_letsencrypt" = true ]; then
        local cert_file="/etc/letsencrypt/live/$domain/cert.pem"
        if [ -f "$cert_file" ]; then
            local not_after=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
            local days_left=$(( ($(date -d "$not_after" +%s) - $(date +%s)) / 86400 ))
            echo -e "  • Let's Encrypt certificate: ${GREEN}✅ Valid for $days_left days${NC}"
        else
            echo -e "  • Let's Encrypt certificate: ${YELLOW}⚠️  Directory exists but certificate missing${NC}"
        fi
    else
        echo -e "  • Let's Encrypt certificate: ${RED}❌ Not found${NC}"
    fi

    # If no SSL is configured, inform user
    if [ "$has_ssl_nginx" = false ] && [ "$has_letsencrypt" = false ]; then
        echo -e "\n${YELLOW}ℹ️  No SSL configuration found for $domain${NC}"
        echo -e "${BLUE}The domain appears to be already using HTTP only${NC}"
        return 0
    fi

    # Offer removal options
    echo -e "\n${YELLOW}What would you like to do?${NC}"
    echo -e "${BLUE}Choose the SSL removal option:${NC}"
    echo ""

    if [ "$has_ssl_nginx" = true ]; then
        echo -e "${GREEN}1) Disable SSL in Nginx only${NC} (keep certificate for future use)"
        echo -e "   ${BLUE}What it does:${NC}"
        echo -e "   • Removes HTTPS (port 443) from Nginx configuration"
        echo -e "   • Keeps HTTP (port 80) working"
        echo -e "   • Preserves Let's Encrypt certificate files"
        echo -e "   • Site becomes accessible via HTTP only"
        echo -e "   ${YELLOW}Use when:${NC} Temporary SSL disable, testing, development"
        echo ""
    fi

    if [ "$has_letsencrypt" = true ]; then
        echo -e "${GREEN}2) Remove Let's Encrypt certificate completely${NC} (permanent removal)"
        echo -e "   ${BLUE}What it does:${NC}"
        echo -e "   • Removes SSL from Nginx configuration"
        echo -e "   • Deletes Let's Encrypt certificate files permanently"
        echo -e "   • Removes certificate from auto-renewal"
        echo -e "   • Cannot be undone (you'll need to recreate certificate)"
        echo -e "   ${YELLOW}Use when:${NC} Permanently switching to HTTP, domain change, cleanup"
        echo ""
    fi

    if [ "$has_ssl_nginx" = true ] && [ "$has_letsencrypt" = true ]; then
        echo -e "${GREEN}3) Complete SSL removal${NC} (both Nginx and certificate)"
        echo -e "   ${BLUE}What it does:${NC}"
        echo -e "   • Everything from options 1 and 2 combined"
        echo -e "   • Complete clean removal of all SSL components"
        echo -e "   • Site reverts to HTTP-only permanently"
        echo -e "   ${YELLOW}Use when:${NC} Complete SSL cleanup, permanent HTTP switch"
        echo ""
    fi

    echo -e "${GREEN}4) Cancel${NC} (no changes)"

    read -p "Select option [1-4]: " removal_choice

    case $removal_choice in
        1)
            if [ "$has_ssl_nginx" = false ]; then
                echo -e "${RED}❌ No SSL configuration found in Nginx${NC}"
                return 1
            fi
            echo -e "\n${YELLOW}Disabling SSL in Nginx configuration...${NC}"
            disable_ssl_nginx "$domain"
            ;;
        2)
            if [ "$has_letsencrypt" = false ]; then
                echo -e "${RED}❌ No Let's Encrypt certificate found${NC}"
                return 1
            fi
            echo -e "\n${YELLOW}Removing Let's Encrypt certificate...${NC}"
            remove_letsencrypt_certificate "$domain"
            ;;
        3)
            if [ "$has_ssl_nginx" = false ] && [ "$has_letsencrypt" = false ]; then
                echo -e "${RED}❌ No SSL configuration found${NC}"
                return 1
            fi
            echo -e "\n${YELLOW}Performing complete SSL removal...${NC}"

            # Remove SSL from nginx first
            if [ "$has_ssl_nginx" = true ]; then
                disable_ssl_nginx "$domain"
            fi

            # Then remove Let's Encrypt certificate
            if [ "$has_letsencrypt" = true ]; then
                remove_letsencrypt_certificate "$domain"
            fi
            ;;
        4)
            echo "Operation cancelled."
            return 0
            ;;
        *)
            echo -e "${RED}❌ Invalid option${NC}"
            return 1
            ;;
    esac

    echo -e "\n${GREEN}✅ SSL removal completed!${NC}"
    echo -e "${GREEN}🌐 Domain: $domain${NC}"
    echo -e "${GREEN}📄 Site is now accessible via: http://$domain${NC}"

    echo -e "\n${BLUE}💡 What's changed:${NC}"
    echo -e "  • HTTPS redirects have been removed"
    echo -e "  • Site now serves traffic over HTTP (port 80)"
    echo -e "  • Browsers will no longer see SSL certificate"

    echo -e "\n${YELLOW}💡 To re-enable SSL later:${NC}"
    echo -e "  • Run: sudo site-manager ssl $domain"
    echo -e "  • Or use the SSL setup option in main menu"
}

disable_ssl_nginx() {
    local domain=$1
    local nginx_config="/etc/nginx/sites-available/$domain"

    echo "Backing up current Nginx configuration..."
    if ! sudo cp "$nginx_config" "$nginx_config.ssl-backup.$(date +%Y%m%d_%H%M%S)"; then
        echo -e "${RED}❌ Failed to create backup${NC}"
        return 1
    fi
    echo -e "${GREEN}✅ Backup created${NC}"

    # Get document root from existing config
    local document_root=$(grep -m1 "root " "$nginx_config" | awk '{print $2}' | tr -d ';')

    if [ -z "$document_root" ]; then
        echo -e "${RED}❌ Could not determine document root from existing config${NC}"
        return 1
    fi

    echo "Creating HTTP-only Nginx configuration..."

    # Create new HTTP-only configuration
    cat << EOF | sudo tee "$nginx_config" > /dev/null
server {
    listen 80;
    server_name ${domain};
    root ${document_root};

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Content-Type-Options "nosniff";

    index index.html index.htm index.php;

    charset utf-8;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    error_page 404 /index.php;

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php$(get_php_version)-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }

    access_log /var/log/nginx/${domain}-access.log;
    error_log /var/log/nginx/${domain}-error.log;
}
EOF

    # Test nginx configuration
    echo "Testing Nginx configuration..."
    if sudo nginx -t; then
        echo -e "${GREEN}✅ Nginx configuration is valid${NC}"

        # Reload nginx
        if sudo systemctl reload nginx; then
            echo -e "${GREEN}✅ Nginx reloaded successfully${NC}"
            echo -e "${GREEN}✅ SSL disabled in Nginx - site now serves HTTP only${NC}"
        else
            echo -e "${RED}❌ Failed to reload Nginx${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ Nginx configuration test failed${NC}"
        echo "Restoring backup configuration..."
        sudo cp "$nginx_config.ssl-backup.$(date +%Y%m%d_%H%M%S)" "$nginx_config"
        return 1
    fi
}

remove_letsencrypt_certificate() {
    local domain=$1

    echo -e "${RED}⚠️  WARNING: This will permanently delete the SSL certificate!${NC}"
    echo -e "${YELLOW}The following will be removed:${NC}"
    echo "  • Certificate files in /etc/letsencrypt/live/$domain/"
    echo "  • Certificate from auto-renewal system"
    echo "  • All certificate history and backups"
    echo ""
    echo -e "${RED}This action cannot be undone!${NC}"
    echo -e "${BLUE}You will need to recreate the certificate if you want SSL again.${NC}"

    read -p "Are you absolutely sure you want to delete the certificate? [y/N] " confirm_delete

    if [[ ! "$confirm_delete" =~ ^[Yy]$ ]]; then
        echo "Certificate deletion cancelled."
        return 0
    fi

    # Also disable SSL in nginx if still enabled
    local nginx_config="/etc/nginx/sites-available/$domain"
    if [ -f "$nginx_config" ] && grep -q "listen 443" "$nginx_config"; then
        echo "Removing SSL from Nginx configuration first..."
        disable_ssl_nginx "$domain"
    fi

    echo "Deleting Let's Encrypt certificate..."

    # Use certbot to delete the certificate properly
    if sudo certbot delete --cert-name "$domain" --non-interactive 2>/dev/null; then
        echo -e "${GREEN}✅ Certificate deleted via certbot${NC}"
    else
        echo -e "${YELLOW}⚠️  Certbot deletion failed, trying manual removal...${NC}"

        # Manual removal as fallback
        local letsencrypt_dirs=(
            "/etc/letsencrypt/live/$domain"
            "/etc/letsencrypt/archive/$domain"
            "/etc/letsencrypt/renewal/$domain.conf"
        )

        for dir in "${letsencrypt_dirs[@]}"; do
            if [ -e "$dir" ]; then
                echo "Removing: $dir"
                sudo rm -rf "$dir"
            fi
        done

        echo -e "${GREEN}✅ Certificate files removed manually${NC}"
    fi

    # Remove from crontab if present (though usually not needed for user installations)
    if crontab -l 2>/dev/null | grep -q "certbot.*$domain"; then
        echo "Removing certificate from cron jobs..."
        (crontab -l 2>/dev/null | grep -v "certbot.*$domain") | crontab -
        echo -e "${GREEN}✅ Removed from scheduled renewals${NC}"
    fi

    echo -e "${GREEN}✅ Let's Encrypt certificate completely removed${NC}"
}

fix_permissions() {
    local CURRENT_USER
    CURRENT_USER=$(get_current_user)

    echo -e "${YELLOW}Fix Project Permissions${NC}"

    # List existing projects in /var/www
    echo -e "\n${BLUE}Available projects in $WEB_ROOT:${NC}"
    if [ -d "$WEB_ROOT" ] && [ "$(ls -A "$WEB_ROOT" 2>/dev/null)" ]; then
        local count=1
        local projects=()

        # Store projects in array and display them
        for dir in "$WEB_ROOT"/*; do
            if [ -d "$dir" ]; then
                local project_name=$(basename "$dir")
                projects[count]="$project_name"
                echo "  $count) $project_name"
                ((count++))
            fi
        done

        if [ ${#projects[@]} -eq 0 ]; then
            echo -e "${RED}❌ No projects found in $WEB_ROOT${NC}"
            return 1
        fi

        echo -e "\n${YELLOW}Select a project or enter a custom path:${NC}"
        read -p "Enter project number (1-$((count-1))) or full path: " selection

        local project_path=""
        local project_name=""

        # Check if selection is a number
        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -lt "$count" ]; then
            project_name="${projects[$selection]}"
            project_path="$WEB_ROOT/$project_name"
        else
            # Treat as custom path
            project_path=$(realpath "$selection" 2>/dev/null)
            if [ -z "$project_path" ] || [ ! -d "$project_path" ]; then
                echo -e "${RED}❌ Invalid selection or path does not exist: $selection${NC}"
                return 1
            fi
            project_name=$(basename "$project_path")
        fi

        echo "Selected project: $project_name"
        echo "Project path: $project_path"

    else
        echo -e "${RED}❌ $WEB_ROOT directory is empty or does not exist${NC}"
        echo -e "${YELLOW}💡 Use 'Create New Project' or 'Move Project' first${NC}"
        return 1
    fi

    # Detect project type
    local is_laravel=false

    if [ -f "$project_path/artisan" ] && [ -d "$project_path/app" ] && [ -f "$project_path/composer.json" ]; then
        is_laravel=true
        echo -e "${GREEN}Laravel project detected!${NC}"
    else
        echo "Standard PHP project detected."
    fi

    echo -e "\n${YELLOW}What type of permission fix do you need?${NC}"
    echo -e "${BLUE}🔧 Permission Fix Options:${NC}"
    echo ""
    echo -e "${GREEN}1) Quick Fix (recommended)${NC} - Fix common permission issues"
    echo -e "   ${BLUE}What it does:${NC}"
    echo -e "   • Sets owner to your user (${USER}) and group to www-data"
    echo -e "   • Directories: 755 (you: read/write/execute, others: read/execute)"
    echo -e "   • Files: 644 (you: read/write, others: read only)"
    echo -e "   • Laravel storage/cache: 775 (group writable for web server)"
    echo -e "   ${YELLOW}Use when:${NC} File uploads fail, cache errors, general permission issues"
    echo ""
    echo -e "${GREEN}2) Full Reset${NC} - Complete permission reset (more thorough)"
    echo -e "   ${BLUE}What it does:${NC}"
    echo -e "   • Everything from Quick Fix PLUS:"
    echo -e "   • Advanced ACL permissions (setfacl) for better web server access"
    echo -e "   • Clears all Laravel caches (application, config, views)"
    echo -e "   • Sets sticky bit (g+s) so new files inherit group ownership"
    echo -e "   ${YELLOW}Use when:${NC} Quick fix didn't work, after major updates, deployment issues"
    echo ""
    echo -e "${GREEN}3) Laravel Specific${NC} - Fix Laravel storage/cache/database issues only"
    echo -e "   ${BLUE}What it does:${NC}"
    echo -e "   • Focuses ONLY on Laravel critical directories:"
    echo -e "     - storage/framework/views (where your error occurred)"
    echo -e "     - storage/framework/cache, storage/framework/sessions"
    echo -e "     - storage/logs, bootstrap/cache"
    echo -e "   • Fixes SQLite database permissions (your specific issue!)"
    echo -e "   • Creates missing Laravel directories if needed"
    echo -e "   • Runs database migrations"
    echo -e "   ${YELLOW}Use when:${NC} Laravel errors like 'readonly database', view compilation fails"
    echo ""
    echo -e "${GREEN}4) Web Server Only${NC} - Basic web permissions"
    echo -e "   ${BLUE}What it does:${NC}"
    echo -e "   • Just basic web server permissions:"
    echo -e "   • Owner: your user, Group: www-data"
    echo -e "   • Directories: 755, Files: 644"
    echo -e "   • Makes sure www-data group can read everything"
    echo -e "   • NO special Laravel handling"
    echo -e "   ${YELLOW}Use when:${NC} Non-Laravel projects, simple PHP sites, static websites"
    echo ""

    read -p "Select option [1-4]: " fix_type

    case $fix_type in
        1|"")
            echo -e "\n${YELLOW}Applying quick permission fix...${NC}"
            # Basic ownership
            sudo chown -R "$CURRENT_USER":www-data "$project_path"

            # Basic permissions
            sudo find "$project_path" -type d -exec chmod 755 {} \;
            sudo find "$project_path" -type f -exec chmod 644 {} \;

            if [ "$is_laravel" = true ]; then
                # Laravel specific directories
                for dir in storage bootstrap/cache; do
                    if [ -d "$project_path/$dir" ]; then
                        echo "Fixing permissions for $dir..."
                        sudo chown -R "$CURRENT_USER":www-data "$project_path/$dir"
                        sudo find "$project_path/$dir" -type d -exec chmod 775 {} \;
                        sudo find "$project_path/$dir" -type f -exec chmod 664 {} \;
                        sudo chmod -R g+s "$project_path/$dir"
                    fi
                done

                # Handle database directory if exists
                if [ -d "$project_path/database" ]; then
                    sudo chown -R "$CURRENT_USER":www-data "$project_path/database"
                    sudo find "$project_path/database" -type d -exec chmod 775 {} \;
                    sudo find "$project_path/database" -type f -exec chmod 664 {} \;
                    sudo chmod -R g+s "$project_path/database"
                fi

                # Make artisan executable
                if [ -f "$project_path/artisan" ]; then
                    sudo chmod +x "$project_path/artisan"
                fi
            fi
            ;;

        2)
            echo -e "\n${YELLOW}Applying full permission reset...${NC}"

            # Reset ownership completely
            sudo chown -R "$CURRENT_USER":www-data "$project_path"

            # Remove all permissions and set fresh ones
            sudo find "$project_path" -type d -exec chmod 755 {} \;
            sudo find "$project_path" -type f -exec chmod 644 {} \;

            if [ "$is_laravel" = true ]; then
                # Laravel writable directories with more aggressive settings
                for dir in storage bootstrap/cache; do
                    if [ -d "$project_path/$dir" ]; then
                        echo "Full reset for $dir..."
                        sudo chown -R "$CURRENT_USER":www-data "$project_path/$dir"
                        sudo find "$project_path/$dir" -type d -exec chmod 775 {} \;
                        sudo find "$project_path/$dir" -type f -exec chmod 664 {} \;
                        sudo chmod -R g+s "$project_path/$dir"

                        # Ensure www-data can write
                        sudo setfacl -R -m u:www-data:rwx "$project_path/$dir" 2>/dev/null || true
                        sudo setfacl -R -d -m u:www-data:rwx "$project_path/$dir" 2>/dev/null || true
                    fi
                done

                # Database permissions
                if [ -d "$project_path/database" ]; then
                    sudo chown -R "$CURRENT_USER":www-data "$project_path/database"
                    sudo find "$project_path/database" -type d -exec chmod 775 {} \;
                    sudo find "$project_path/database" -type f -exec chmod 664 {} \;
                    sudo chmod -R g+s "$project_path/database"
                fi

                # Make artisan executable
                if [ -f "$project_path/artisan" ]; then
                    sudo chmod +x "$project_path/artisan"
                fi

                # Clear Laravel caches
                echo "Clearing Laravel caches..."
                sudo -u "$CURRENT_USER" bash -c "cd '$project_path' && php artisan cache:clear" 2>/dev/null || true
                sudo -u "$CURRENT_USER" bash -c "cd '$project_path' && php artisan config:clear" 2>/dev/null || true
                sudo -u "$CURRENT_USER" bash -c "cd '$project_path' && php artisan view:clear" 2>/dev/null || true
            fi
            ;;

        3)
            if [ "$is_laravel" != true ]; then
                echo -e "${RED}❌ This is not a Laravel project!${NC}"
                return 1
            fi

            echo -e "\n${YELLOW}Applying Laravel-specific permission fix...${NC}"

            # Focus only on Laravel critical directories
            for dir in storage bootstrap/cache; do
                if [ -d "$project_path/$dir" ]; then
                    echo "Fixing Laravel permissions for $dir..."
                    sudo chown -R "$CURRENT_USER":www-data "$project_path/$dir"

                    # Remove and recreate with proper permissions
                    sudo find "$project_path/$dir" -type d -exec chmod 775 {} \;
                    sudo find "$project_path/$dir" -type f -exec chmod 664 {} \;

                    # Set group sticky bit
                    sudo chmod -R g+s "$project_path/$dir"

                    # Advanced ACL if available
                    if command -v setfacl &>/dev/null; then
                        echo "Setting advanced ACL permissions..."
                        sudo setfacl -R -m u:www-data:rwx "$project_path/$dir"
                        sudo setfacl -R -d -m u:www-data:rwx "$project_path/$dir"
                        sudo setfacl -R -m g:www-data:rwx "$project_path/$dir"
                        sudo setfacl -R -d -m g:www-data:rwx "$project_path/$dir"
                    fi
                fi
            done

            # Ensure specific Laravel subdirectories exist with correct permissions
            local laravel_dirs=(
                "storage/app"
                "storage/framework/cache"
                "storage/framework/sessions"
                "storage/framework/views"
                "storage/logs"
                "bootstrap/cache"
            )

            for dir in "${laravel_dirs[@]}"; do
                if [ ! -d "$project_path/$dir" ]; then
                    echo "Creating missing directory: $dir"
                    sudo -u "$CURRENT_USER" mkdir -p "$project_path/$dir"
                fi
                sudo chown -R "$CURRENT_USER":www-data "$project_path/$dir"
                sudo chmod -R 775 "$project_path/$dir"
                sudo chmod -R g+s "$project_path/$dir"
            done

            # Fix SQLite database permissions (common issue)
            echo "Checking for SQLite database files..."

            # Check database directory
            if [ -d "$project_path/database" ]; then
                # Find .sqlite files
                local sqlite_files=($(find "$project_path/database" -name "*.sqlite" 2>/dev/null))

                if [ ${#sqlite_files[@]} -gt 0 ]; then
                    echo "Found SQLite database files, fixing permissions..."
                    for sqlite_file in "${sqlite_files[@]}"; do
                        echo "Fixing permissions for: $(basename "$sqlite_file")"
                        sudo chown "$CURRENT_USER":www-data "$sqlite_file"
                        sudo chmod 664 "$sqlite_file"

                        # Ensure the directory is writable too
                        sudo chmod 775 "$(dirname "$sqlite_file")"
                    done
                fi

                # Also check for common Laravel database file names
                local common_db_files=(
                    "$project_path/database/database.sqlite"
                    "$project_path/storage/database.sqlite"
                    "$project_path/database.sqlite"
                )

                for db_file in "${common_db_files[@]}"; do
                    if [ -f "$db_file" ]; then
                        echo "Fixing permissions for: $(basename "$db_file")"
                        sudo chown "$CURRENT_USER":www-data "$db_file"
                        sudo chmod 664 "$db_file"
                        sudo chmod 775 "$(dirname "$db_file")"
                    fi
                done
            fi

            # Check .env file for SQLite configuration and create database if needed
            if [ -f "$project_path/.env" ]; then
                local db_connection=$(grep "^DB_CONNECTION=" "$project_path/.env" | cut -d'=' -f2)
                local db_database=$(grep "^DB_DATABASE=" "$project_path/.env" | cut -d'=' -f2)

                if [[ "$db_connection" == "sqlite" ]]; then
                    echo "SQLite configuration detected in .env file"

                    if [ -n "$db_database" ] && [ ! -f "$project_path/$db_database" ]; then
                        echo "Creating missing SQLite database: $db_database"
                        sudo -u "$CURRENT_USER" touch "$project_path/$db_database"
                        sudo chown "$CURRENT_USER":www-data "$project_path/$db_database"
                        sudo chmod 664 "$project_path/$db_database"
                        sudo chmod 775 "$(dirname "$project_path/$db_database")"
                    elif [ -n "$db_database" ] && [ -f "$project_path/$db_database" ]; then
                        echo "Fixing permissions for .env database: $db_database"
                        sudo chown "$CURRENT_USER":www-data "$project_path/$db_database"
                        sudo chmod 664 "$project_path/$db_database"
                        sudo chmod 775 "$(dirname "$project_path/$db_database")"
                    fi
                fi
            fi

            # Clear caches
            echo "Clearing Laravel caches..."
            sudo -u "$CURRENT_USER" bash -c "cd '$project_path' && php artisan cache:clear" 2>/dev/null || echo "Cache clear skipped (not available)"
            sudo -u "$CURRENT_USER" bash -c "cd '$project_path' && php artisan config:clear" 2>/dev/null || echo "Config clear skipped (not available)"
            sudo -u "$CURRENT_USER" bash -c "cd '$project_path' && php artisan view:clear" 2>/dev/null || echo "View clear skipped (not available)"

            # Try to run migrations if SQLite database exists
            if [ -f "$project_path/.env" ]; then
                local db_connection=$(grep "^DB_CONNECTION=" "$project_path/.env" | cut -d'=' -f2)
                if [[ "$db_connection" == "sqlite" ]]; then
                    read -p "Run database migrations to ensure tables exist? [Y/n] " run_migrations
                    if [[ ! "$run_migrations" =~ ^[Nn]$ ]]; then
                        echo "Running Laravel migrations..."
                        sudo -u "$CURRENT_USER" bash -c "cd '$project_path' && php artisan migrate --force" 2>/dev/null || echo "Migration skipped (not available or failed)"
                    fi
                fi
            fi
            ;;

        4)
            echo -e "\n${YELLOW}Applying basic web server permissions...${NC}"

            # Basic web permissions
            sudo chown -R "$CURRENT_USER":www-data "$project_path"
            sudo find "$project_path" -type d -exec chmod 755 {} \;
            sudo find "$project_path" -type f -exec chmod 644 {} \;

            # Make sure www-data can read everything
            sudo chmod -R g+r "$project_path"
            ;;

        *)
            echo -e "${RED}❌ Invalid option selected${NC}"
            return 1
            ;;
    esac

    echo -e "\n${GREEN}✅ Permissions fixed successfully!${NC}"
    echo -e "${GREEN}📁 Project: ${project_name}${NC}"
    echo -e "${GREEN}📂 Location: ${project_path}${NC}"

    if [ "$is_laravel" = true ]; then
        echo -e "\n${BLUE}💡 Laravel Permission Tips:${NC}"
        echo "   • If you still have issues, try: sudo chmod -R 777 storage (temporary)"
        echo "   • For production, consider: sudo chown -R www-data:www-data storage"
        echo "   • Check SELinux if enabled: sudo setsebool -P httpd_unified 1"
        echo "   • Verify .env file permissions: chmod 644 .env"
    fi

    echo -e "\n${YELLOW}💡 General Tips:${NC}"
    echo "   • If problems persist, check file ownership with: ls -la"
    echo "   • Verify nginx/apache user matches www-data group"
    echo "   • For development, you might need: sudo usermod -aG www-data \$USER"
}

# ---------- Main Program ----------
case "$1" in
    check)
        check_dependencies
        ;;
    setup)
        setup_server
        ;;
    backup)
        backup_site "$2"
        ;;
    restore)
        restore_site "$2"
        ;;
    ssl)
        setup_ssl "$2"
        ;;
    update-ssl)
        update_ssl "$2"
        ;;
    configure)
        configure_existing_project
        ;;
    fix-permissions)
        fix_permissions
        ;;
    remove-ssl)
        remove_ssl "$2"
        ;;
    *)
        while true; do
            show_header
            echo "Main Operations:"
            echo "1) Create New Project"
            echo "2) Delete Existing Project"
            echo "3) Move Project"
            echo "4) Clone from GitHub"
            echo "5) Backup Project"
            echo "6) Restore Project"
            echo "7) Setup SSL"
            echo "8) Configure Existing Project"
            echo "9) Fix Project Permissions"
            echo "10) Update/Renew SSL Certificate"
            echo "11) Remove SSL Certificate"
            echo "12) Exit"
            read -p "Select operation [1-12]: " choice
            case $choice in
                1) create_site ;;
                2) delete_site ;;
                3) move_project ;;
                4) clone_project ;;
                5) read -p "Enter domain to backup: " d; backup_site "$d" ;;
                6) read -p "Enter backup path: " p; restore_site "$p" ;;
                7) read -p "Enter domain for SSL: " d; setup_ssl "$d" ;;
                8) configure_existing_project ;;
                9) fix_permissions ;;
                10) update_ssl ;;
                11) read -p "Enter domain to remove SSL: " d; remove_ssl "$d" ;;
                12) exit 0 ;;
                *) echo "Invalid option!" ;;
            esac
            read -p "Press Enter to continue..."
        done
        ;;
esac
