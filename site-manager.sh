#!/bin/bash
# Comprehensive Server & Site Management Tool v1.0

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

# ---------- Core Functions ----------
show_header() {
    clear
    echo -e "${BLUE}"
    echo "=============================================="
    echo "        WELCOME TO SITE MANAGER TOOL"
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
    local get_version=$2
    local user=$(get_current_user)
    
    if command -v $tool &>/dev/null; then
        version=""
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
                version=$(sudo -u $user -i composer --version 2>/dev/null | awk '{print $3}')
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
    
    # PHP Version Selection
    PS3="Select PHP version: "
    select php_version in 8.4 8.3 8.2 8.1; do
        [ -n "$php_version" ] && break
        echo "Invalid selection!"
    done

    # Install components
    sudo apt update
    
    # Nginx
    if ! command -v nginx &>/dev/null; then
        echo "Installing Nginx..."
        sudo apt install -y nginx
        sudo systemctl enable nginx
    fi

    # PHP
    echo "Installing PHP $php_version..."
    sudo apt install -y php$php_version-fpm \
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
        php$php_version-zip

    # MySQL
    if ! command -v mysqld &>/dev/null; then
        echo "Installing MySQL..."
        sudo apt install -y mysql-server
        
        echo -e "\n${YELLOW}Setting MySQL root password:${NC}"
        sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$DB_ROOT_PASS';"
        sudo mysql_secure_installation
    fi

    # Node.js and npm
    if ! command -v node &>/dev/null; then
        echo "Installing Node.js and npm..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt install -y nodejs
        
        # Verify npm installation
        if ! command -v npm &>/dev/null; then
            echo "Installing npm separately..."
            sudo apt install -y npm
        fi
    fi

    # Composer installation with shell detection
    if ! command -v composer &>/dev/null; then
        echo "Installing Composer..."
        php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
        sudo php composer-setup.php --install-dir=/usr/local/bin --filename=composer
        rm composer-setup.php

        # Detect shell configuration
        detect_shell_config() {
            case $(basename "$SHELL") in
                bash*)  echo "$HOME/.bashrc" ;;
                zsh*)   echo "$HOME/.zshrc" ;;
                fish*)  echo "$HOME/.config/fish/config.fish" ;;
                *)      echo "$HOME/.profile" ;;
            esac
        }

        config_file=$(detect_shell_config)
        
        # Verify PATH configuration
        if ! echo "$PATH" | grep -q "/usr/local/bin"; then
            echo -e "\n${YELLOW}Composer installed to /usr/local/bin which is not in your PATH${NC}"
            echo "Detected shell configuration file: $config_file"
            
            read -p "Add /usr/local/bin to PATH? [Y/n] " response
            if [[ ! "$response" =~ ^[Nn] ]]; then
                read -p "Enter path to shell config file [$config_file]: " custom_file
                config_file=${custom_file:-$config_file}
                
                echo "Adding to $config_file..."
                echo -e "\n# Added by Site Manager\nexport PATH=\"\$PATH:/usr/local/bin\"" | tee -a "$config_file"
                
                # Load new PATH
                if [ -f "$config_file" ]; then
                    source "$config_file"
                else
                    echo "Could not source $config_file - please restart your shell"
                fi
            else
                echo "You may need to add /usr/local/bin to your PATH manually"
            fi
        fi
    fi

    # Configure permissions
    echo "Configuring permissions..."
    sudo mkdir -p $WEB_ROOT
    sudo chown -R $USER:www-data $WEB_ROOT
    sudo chmod -R 775 $WEB_ROOT
    sudo usermod -aG www-data $USER
    
    echo -e "\n${GREEN}Server setup complete!${NC}"
    echo "Note: You may need to log out and back in for group changes to take effect"
}

# ---------- Site Management Functions ----------
create_site() {
    local CURRENT_USER=$(get_current_user)
    read -p "Enter domain name (e.g., example.test): " domain
    read -p "Project path relative to ${WEB_ROOT}: " path
    read -p "Is this a Laravel project? [y/N]: " laravel
    
    full_path="${WEB_ROOT}/${path}"
    
    # Create directory structure
    sudo mkdir -p "$full_path"
    sudo chown -R $CURRENT_USER:www-data "$full_path"
    sudo chmod -R 775 "$full_path"
    
    # Laravel specific setup
    if [[ "$laravel" =~ ^[Yy] ]]; then
        check_composer "$CURRENT_USER"
        
        # Verify directory permissions
        sudo -u "$CURRENT_USER" touch "$full_path/permission_test" || {
            echo "ERROR: User $CURRENT_USER cannot write to $full_path"
            exit 1
        }
        sudo -u "$CURRENT_USER" rm "$full_path/permission_test"

        # Install Laravel project
        if [ -z "$(ls -A "$full_path")" ]; then
            echo "Installing Laravel project..."
            sudo -u "$CURRENT_USER" -i bash -c \
                "cd '$full_path' && composer create-project --prefer-dist laravel/laravel ."
            
            [ $? -ne 0 ] && { echo "Laravel installation failed!"; exit 1; }
        fi
        document_root="${full_path}/public"
    else
        document_root="$full_path"
        sudo touch "${document_root}/index.php"
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
    
    # Get document root from config
    document_root=$(grep -m1 "root " "$config_file" | awk '{print $2}' | tr -d ';')
    [[ "$document_root" == *"/public" ]] && project_root=$(dirname "$document_root") || project_root="$document_root"

    echo -e "\n${RED}WARNING: This will permanently delete:${NC}"
    echo "• Domain configuration: $config_file"
    echo "• Hosts entry: $domain"
    echo "• Project files: $project_root"
    
    read -p "Are you sure you want to do this? [y/N] " confirm
    [[ ! "$confirm" =~ ^[Yy] ]] && { echo "Deletion cancelled"; return; }

    # Remove configs
    sudo rm -f "$config_file"
    sudo rm -f "${NGINX_DIR}/sites-enabled/${domain}"
    sudo sed -i "/${domain}/d" /etc/hosts

    # Handle files
    if [ -d "$project_root" ]; then
        read -p "Delete project files? [y/N] " delete_files
        if [[ "$delete_files" =~ ^[Yy] ]]; then
            sudo rm -rfv "$project_root"
        fi
    fi

    sudo systemctl reload nginx
    echo -e "${GREEN}Project ${domain} removed!${NC}"
    echo -e "${GREEN}Project $project_root removed!${NC}"
}

move_project() {
    local CURRENT_USER=$(get_current_user)
    read -p "Enter full path to project: " source_path
    read -p "Enter domain name: " domain
    
    project_name=$(basename "$source_path")
    target_path="${WEB_ROOT}/${project_name}"
    
    sudo rsync -a "$source_path/" "$target_path/"
    sudo chown -R $CURRENT_USER:www-data "$target_path"
    setup_nginx "$domain" "$target_path"
    echo -e "${GREEN}Project moved to: ${target_path}${NC}"
}

clone_project() {
    local CURRENT_USER=$(get_current_user)
    read -p "Git repository URL: " repo_url
    read -p "Enter domain name: " domain
    
    project_name=$(basename "$repo_url" .git)
    target_path="${WEB_ROOT}/${project_name}"
    
    # Create directory with proper permissions
    sudo mkdir -p "$target_path"
    sudo chown -R "$CURRENT_USER:www-data" "$target_path"
    sudo chmod -R 775 "$target_path"
    
    # Clone repository
    sudo -u "$CURRENT_USER" git clone "$repo_url" "$target_path"
    setup_nginx "$domain" "$target_path"
    echo -e "${GREEN}Project cloned to: ${target_path}${NC}"
}

setup_nginx() {
    local domain=$1
    local root_path=$2
    
    cat << EOF | sudo tee "${NGINX_DIR}/sites-available/${domain}" > /dev/null
server {
    listen 80;
    server_name ${domain};
    root ${root_path};
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcpi-php.conf;
        fastcgi_pass unix:/run/php/php${php_version}-fpm.sock;
        include fastcgi_params;
    }

    access_log /var/log/nginx/${domain}-access.log;
    error_log /var/log/nginx/${domain}-error.log;
}
EOF

    sudo ln -sf "../sites-available/${domain}" "${NGINX_DIR}/sites-enabled/"
    echo "127.0.0.1 ${domain}" | sudo tee -a /etc/hosts > /dev/null
    sudo nginx -t && sudo systemctl reload nginx
}

# ---------- Backup/Restore Functions ----------
backup_site() {
    local domain=$1
    local backup_file="${BACKUP_DIR}/${domain}_$(date +%Y%m%d%H%M).tar.gz"
    
    mkdir -p "$BACKUP_DIR"
    sudo tar -czf "$backup_file" -C "$WEB_ROOT" "$domain"
    echo -e "${GREEN}Backup created: ${backup_file}${NC}"
}

restore_site() {
    local backup_file=$1
    sudo tar -xzf "$backup_file" -C "$WEB_ROOT"
    echo -e "${GREEN}Restored from: ${backup_file}${NC}"
}

# ---------- SSL Functions ----------
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