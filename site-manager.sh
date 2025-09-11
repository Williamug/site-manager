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
                version=$(mysqld --version | awk '{print $3}')
                ;;
            node)
                version=$(node -v 2>/dev/null)
                ;;
            npm)
                version=$(npm -v 2>/dev/null)
                ;;
            composer)
                version=$(sudo -u "$user" -i composer --version 2>/dev/null | awk '{print $3}')
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
    sudo apt update

    # Nginx
    if ! command -v nginx &>/dev/null; then
        echo -e "\n${YELLOW}Installing Nginx...${NC}"
        if sudo apt install -y nginx; then
            sudo systemctl enable nginx
            sudo systemctl start nginx
            echo -e "${GREEN}✅ Nginx installed successfully${NC}"
        else
            echo -e "${RED}❌ Failed to install Nginx${NC}"
            return 1
        fi
    else
        echo -e "${GREEN}✅ Nginx is already installed${NC}"
    fi

    # PHP
    echo -e "\n${YELLOW}Installing PHP $php_version and extensions...${NC}"
    if sudo apt install -y \
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
        php$php_version-intl; then
        
        sudo systemctl enable php$php_version-fpm
        sudo systemctl start php$php_version-fpm
        echo -e "${GREEN}✅ PHP $php_version installed successfully${NC}"
    else
        echo -e "${RED}❌ Failed to install PHP $php_version${NC}"
        return 1
    fi

    # MySQL
    if ! command -v mysqld &>/dev/null; then
        echo -e "\n${YELLOW}Installing MySQL...${NC}"
        if sudo apt install -y mysql-server; then
            sudo systemctl enable mysql
            sudo systemctl start mysql
            echo -e "${GREEN}✅ MySQL installed successfully${NC}"
            
            # Prompt for MySQL root password
            echo -e "\n${YELLOW}Setting up MySQL security...${NC}"
            read -s -p "Enter a password for MySQL root user: " db_root_pass
            echo ""
            
            if [ -n "$db_root_pass" ]; then
                # Set MySQL root password
                if sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$db_root_pass'; FLUSH PRIVILEGES;"; then
                    echo -e "${GREEN}✅ MySQL root password set successfully${NC}"
                    echo -e "${YELLOW}Running MySQL secure installation...${NC}"
                    sudo mysql_secure_installation
                else
                    echo -e "${RED}❌ Failed to set MySQL root password${NC}"
                fi
            else
                echo -e "${YELLOW}No password set for MySQL root user${NC}"
            fi
        else
            echo -e "${RED}❌ Failed to install MySQL${NC}"
            return 1
        fi
    else
        echo -e "${GREEN}✅ MySQL is already installed${NC}"
    fi

    # Node.js and npm
    if ! command -v node &>/dev/null; then
        echo -e "\n${YELLOW}Installing Node.js and npm...${NC}"
        # Install Node.js 20 LTS
        if curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - && sudo apt install -y nodejs; then
            echo -e "${GREEN}✅ Node.js and npm installed successfully${NC}"
        else
            echo -e "${RED}❌ Failed to install Node.js${NC}"
            # Try alternative method
            echo -e "${YELLOW}Trying alternative installation method...${NC}"
            if sudo apt install -y nodejs npm; then
                echo -e "${GREEN}✅ Node.js and npm installed via package manager${NC}"
            else
                echo -e "${RED}❌ Failed to install Node.js and npm${NC}"
                return 1
            fi
        fi
    else
        echo -e "${GREEN}✅ Node.js is already installed${NC}"
    fi

    # Composer installation with improved PATH handling
    if ! command -v composer &>/dev/null; then
        echo -e "\n${YELLOW}Installing Composer...${NC}"
        
        # Download and install Composer
        if php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
           sudo php composer-setup.php --install-dir=/usr/local/bin --filename=composer; then
            rm -f composer-setup.php
            echo -e "${GREEN}✅ Composer installed to /usr/local/bin/composer${NC}"
            
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
        else
            echo -e "${RED}❌ Failed to install Composer${NC}"
            rm -f composer-setup.php
            return 1
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

    echo -e "\n${GREEN}🎉 Server setup completed successfully!${NC}"
    echo -e "\n${BLUE}📋 Installation Summary:${NC}"
    echo -e "  • Nginx: $(nginx -v 2>&1 | awk -F/ '{print $2}' | cut -d' ' -f1)"
    echo -e "  • PHP: $php_version"
    echo -e "  • MySQL: $(mysqld --version | awk '{print $3}')"
    echo -e "  • Node.js: $(node -v 2>/dev/null)"
    echo -e "  • npm: $(npm -v 2>/dev/null)"
    echo -e "  • Composer: $(composer --version 2>/dev/null | awk '{print $3}')"
    echo -e "\n${YELLOW}💡 Next Steps:${NC}"
    echo -e "  1. Restart your terminal or run: source ~/.zshrc"
    echo -e "  2. Create your first site: sudo site-manager"
    echo -e "  3. Select option 1 (Create New Project)"
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
    read -p "Enter custom backup destination (or press Enter to use default [$BACKUP_DIR]): " custom_dest
    if [ -n "$custom_dest" ]; then
        custom_dir="$custom_dest"
    else
        custom_dir="$BACKUP_DIR"
    fi
    local default_backup_name="${domain}_$(date +%Y%m%d%H%M)"
    local backup_dir="${custom_dir}/${default_backup_name}"
    mkdir -p "$custom_dir" || { echo "Failed to create backup directory: $custom_dir"; return 1; }
    echo -e "${YELLOW}Backup destination: ${custom_dir}/${default_backup_name}{format}${NC}"
    echo -e "Default backup name: ${default_backup_name} (press Enter to keep)\n"
    read -p "Enter custom backup name [${default_backup_name}]: " backup_name
    backup_name=${backup_name:-$default_backup_name}
    backup_dir="${custom_dir}/${backup_name}"
    mkdir -p "$backup_dir"
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
    read -p "Enter full path of the project directory to backup: " project_dir
    if [ ! -d "$project_dir" ]; then
        echo "Project directory does not exist!"
        return 1
    fi
    local temp_backup_dir="${backup_dir}_temp"
    mkdir -p "$temp_backup_dir" || { echo "Failed to create temporary backup directory"; return 1; }
    if $backup_code; then
        cp -a "$project_dir" "$temp_backup_dir/"
    fi
    if $backup_db; then
        read -p "Enter database name: " db_name
        read -p "Enter database user: " db_user
        read -s -p "Enter database password: " db_pass
        echo ""
        mysqldump -u "$db_user" -p"$db_pass" "$db_name" > "$temp_backup_dir/db_dump.sql"
    fi
    tar -czf "${backup_dir}.tar.gz" -C "$(dirname "$temp_backup_dir")" "$(basename "$temp_backup_dir")"
    rm -rf "$temp_backup_dir"
    echo -e "${GREEN}Backup created: ${backup_dir}.tar.gz${NC}"
    echo -e "Full path: $(realpath "${backup_dir}.tar.gz")\n"
}

restore_site() {
    local backup_file=$1
    read -p "Enter domain for database restore (if applicable): " restore_domain
    echo -e "\n${YELLOW}Restoring from: ${backup_file}${NC}"
    if [[ "$backup_file" == */* ]]; then
        local restore_dir
        restore_dir=$(dirname "$backup_file")
    else
        local restore_dir="$BACKUP_DIR"
        echo -e "Using default backup location: $restore_dir"
    fi
    if [[ "$backup_file" == *.tar.gz ]]; then
        tar -xzf "$backup_file" -C "$WEB_ROOT"
    elif [[ "$backup_file" == *.zip ]]; then
        unzip "$backup_file" -d "$WEB_ROOT"
    else
        echo "Unsupported format - use .tar.gz or .zip"
        return 1
    fi
    if [ -n "$restore_domain" ] && [ -f "${WEB_ROOT}/${restore_domain}/db_dump.sql" ]; then
        read -p "Found database dump for ${restore_domain}. Restore database? [y/N] " restore_db
        if [[ "$restore_db" =~ ^[Yy] ]]; then
            mysql -h "$db_host" -u "$db_user" -p"$db_pass" "$db_name" < "${WEB_ROOT}/${restore_domain}/db_dump.sql"
        fi
    fi
    echo -e "${GREEN}Restore completed!${NC}"
}

setup_ssl() {
    local domain=$1
    sudo apt install -y certbot python3-certbot-nginx
    sudo certbot --nginx -d "$domain" --register-unsafely-without-email --agree-tos
    sudo systemctl reload nginx
    echo -e "${GREEN}SSL certificate installed for ${domain}${NC}"
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
            echo "8) Exit"
            read -p "Select operation [1-8]: " choice
            case $choice in
                1) create_site ;;
                2) delete_site ;;
                3) move_project ;;
                4) clone_project ;;
                5) read -p "Enter domain to backup: " d; backup_site "$d" ;;
                6) read -p "Enter backup path: " p; restore_site "$p" ;;
                7) read -p "Enter domain for SSL: " d; setup_ssl "$d" ;;
                8) exit 0 ;;
                *) echo "Invalid option!" ;;
            esac
            read -p "Press Enter to continue..."
        done
        ;;
esac
