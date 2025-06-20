#!/bin/bash

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
NC='\033[0m' # No Color

# Headline
echo -e "\n${CYAN}===========================================================${NC}"
echo -e "${GREEN}                  🚀 GENSYN NODE SETUP 🚀  342                 ${NC}"
echo -e "${CYAN}===========================================================${NC}"
echo ""

# Ask for confirmation to continue
read -p "Do you want to start setting up the Gensyn Node? (y/n): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo -e "\n❌ Setup aborted by user. Exiting..."
    exit 1
fi

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to log installation report
log_install_report() {
    local component="$1"
    local status="$2"
    local details="$3"
    
    if [[ "$status" == "SUCCESS" ]]; then
        echo -e "${GREEN}✅ $component${NC} - $details"
    elif [[ "$status" == "SKIP" ]]; then
        echo -e "${YELLOW}⏭️  $component${NC} - $details"
    else
        echo -e "${RED}❌ $component${NC} - $details"
    fi
}

# Function to install Google Drive CLI tools
install_gdrive_tools() {
    echo -e "\n${CYAN}Installing Google Drive CLI tools...${NC}"
    
    # Install rclone (supports Google Drive)
    if command_exists rclone; then
        RCLONE_VERSION=$(rclone version | head -n 1)
        log_install_report "rclone" "SKIP" "Already installed - $RCLONE_VERSION"
    else
        if curl https://rclone.org/install.sh | sudo bash >/dev/null 2>&1; then
            RCLONE_VERSION=$(rclone version | head -n 1)
            log_install_report "rclone" "SUCCESS" "$RCLONE_VERSION"
        else
            log_install_report "rclone" "FAILED" "Failed to install rclone"
            return 1
        fi
    fi
    
    # Install gdown (Python tool for Google Drive)
    if pip3 show gdown >/dev/null 2>&1; then
        GDOWN_VERSION=$(pip3 show gdown | grep "Version" | awk '{print $2}')
        log_install_report "gdown" "SKIP" "Already installed - v$GDOWN_VERSION"
    else
        if pip3 install gdown >/dev/null 2>&1; then
            GDOWN_VERSION=$(pip3 show gdown | grep "Version" | awk '{print $2}')
            log_install_report "gdown" "SUCCESS" "v$GDOWN_VERSION"
        else
            log_install_report "gdown" "FAILED" "Failed to install gdown"
            return 1
        fi
    fi
    
    return 0
}

# Function to download file from Google Drive
download_from_gdrive() {
    local drive_url="$1"
    local destination="$2"
    
    # Extract file ID from Google Drive URL
    local file_id=""
    
    # Format: https://drive.google.com/file/d/FILE_ID/view
    if [[ "$drive_url" =~ drive\.google\.com/file/d/([^/]+) ]]; then
        file_id="${BASH_REMATCH[1]}"
    # Format: https://drive.google.com/open?id=FILE_ID
    elif [[ "$drive_url" =~ drive\.google\.com/open\?id=([^&]+) ]]; then
        file_id="${BASH_REMATCH[1]}"
    # Format: https://docs.google.com/document/d/FILE_ID/edit
    elif [[ "$drive_url" =~ docs\.google\.com/\w+/d/([^/]+) ]]; then
        file_id="${BASH_REMATCH[1]}"
    fi
    
    if [[ -z "$file_id" ]]; then
        echo "Invalid Google Drive URL format"
        return 1
    fi
    
    # Try multiple download methods
    local success=false
    
    # Method 1: gdown
    if command_exists gdown; then
        if gdown --id "$file_id" -O "$destination" >/dev/null 2>&1; then
            success=true
        fi
    fi
    
    # Method 2: wget with direct link
    if [[ "$success" == "false" ]]; then
        local direct_url="https://drive.google.com/uc?export=download&id=$file_id"
        if wget --no-check-certificate "$direct_url" -O "$destination" >/dev/null 2>&1; then
            success=true
        fi
    fi
    
    # Method 3: curl with direct link
    if [[ "$success" == "false" ]]; then
        local direct_url="https://drive.google.com/uc?export=download&id=$file_id"
        if curl -L -o "$destination" "$direct_url" >/dev/null 2>&1; then
            success=true
        fi
    fi
    
    if [[ "$success" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# Function to clone gist or regular git repository
clone_repository() {
    local url="$1"
    local destination="$2"
    local temp_dir=$(mktemp -d)
    
    # Check if it's a Google Drive URL
    if [[ "$url" == *"drive.google.com"* ]]; then
        # For Google Drive URLs, try to download the file
        if download_from_gdrive "$url" "$temp_dir/downloaded_file" >/dev/null 2>&1; then
            if [[ -n "$destination" ]]; then
                # Create destination directory if it doesn't exist
                mkdir -p "$destination" 2>/dev/null || true
                
                # Copy files from temp directory to destination
                if cp -r "$temp_dir"/* "$destination/" 2>/dev/null; then
                    rm -rf "$temp_dir" 2>/dev/null || true
                    return 0
                else
                    # If copy fails, try move
                    if mv "$temp_dir"/* "$destination/" 2>/dev/null; then
                        rm -rf "$temp_dir" 2>/dev/null || true
                        return 0
                    fi
                fi
            else
                # If no destination specified, just verify the download worked
                rm -rf "$temp_dir" 2>/dev/null || true
                return 0
            fi
        fi
        
        # Cleanup on failure
        rm -rf "$temp_dir" 2>/dev/null || true
        return 1
    # Check if it's a gist URL
    elif [[ "$url" == *"gist.github.com"* ]]; then
        # For gists, we need to append .git to clone
        local git_url="$url"
        if [[ ! "$git_url" == *".git" ]]; then
            git_url="${git_url}.git"
        fi
        
        # Try to clone the gist
        if git clone "$git_url" "$temp_dir" >/dev/null 2>&1; then
            if [[ -n "$destination" ]]; then
                # Create destination directory if it doesn't exist
                mkdir -p "$destination" 2>/dev/null || true
                
                # Copy files from temp directory to destination
                if cp -r "$temp_dir"/* "$destination/" 2>/dev/null; then
                    rm -rf "$temp_dir" 2>/dev/null || true
                    return 0
                else
                    # If copy fails, try move
                    if mv "$temp_dir" "$destination" 2>/dev/null; then
                        return 0
                    fi
                fi
            else
                # If no destination specified, just verify the clone worked
                rm -rf "$temp_dir" 2>/dev/null || true
                return 0
            fi
        fi
        
        # Cleanup on failure
        rm -rf "$temp_dir" 2>/dev/null || true
        return 1
    else
        # Regular git repository
        if [[ -n "$destination" ]]; then
            if git clone "$url" "$destination" >/dev/null 2>&1; then
                return 0
            fi
        else
            if git clone "$url" "$temp_dir" >/dev/null 2>&1; then
                rm -rf "$temp_dir" 2>/dev/null || true
                return 0
            fi
        fi
        return 1
    fi
}

# Function to download single file from gist or Google Drive
download_file() {
    local url="$1"
    local destination="$2"
    
    # Check if it's a Google Drive URL
    if [[ "$url" == *"drive.google.com"* ]]; then
        if download_from_gdrive "$url" "$destination"; then
            return 0
        else
            return 1
        fi
    # Check if it's a gist URL
    elif [[ "$url" == *"gist.github.com"* ]]; then
        # Extract username and gist ID from different gist URL formats
        # Format 1: https://gist.github.com/username/gist_id
        # Format 2: https://gist.github.com/gist_id
        
        local username=""
        local gist_id=""
        
        # Remove protocol and domain
        local path_part=$(echo "$url" | sed 's|https://gist.github.com/||' | sed 's|http://gist.github.com/||')
        
        # Split by forward slash
        IFS='/' read -ra URL_PARTS <<< "$path_part"
        
        if [ ${#URL_PARTS[@]} -eq 2 ]; then
            # Format: username/gist_id
            username="${URL_PARTS[0]}"
            gist_id="${URL_PARTS[1]}"
        elif [ ${#URL_PARTS[@]} -eq 1 ]; then
            # Format: gist_id only
            gist_id="${URL_PARTS[0]}"
            # Try to extract username from the original URL or use a default
            username=$(echo "$url" | grep -o '/[^/]*/' | sed 's|/||g' | head -n1)
            if [[ -z "$username" ]]; then
                username="anonymous"
            fi
        else
            echo "Invalid gist URL format"
            return 1
        fi
        
        # Clean gist_id (remove any trailing parameters)
        gist_id=$(echo "$gist_id" | sed 's/[?#].*//')
        
        # Try multiple methods to download the gist
        local success=false
        
        # Method 1: Try with username
        if [[ -n "$username" && "$username" != "anonymous" ]]; then
            local raw_url="https://gist.githubusercontent.com/$username/$gist_id/raw/"
            if curl -s -f "$raw_url" -o "$destination" 2>/dev/null; then
                success=true
            fi
        fi
        
        # Method 2: Try without username (for anonymous gists)
        if [[ "$success" == "false" ]]; then
            local raw_url="https://gist.githubusercontent.com/$gist_id/raw/"
            if curl -s -f "$raw_url" -o "$destination" 2>/dev/null; then
                success=true
            fi
        fi
        
        # Method 3: Try to get the raw URL by scraping the gist page
        if [[ "$success" == "false" ]]; then
            local raw_url=$(curl -s "$url" | grep -o 'https://gist.githubusercontent.com/[^"]*' | head -n1)
            if [[ -n "$raw_url" ]]; then
                if curl -s -f "$raw_url" -o "$destination" 2>/dev/null; then
                    success=true
                fi
            fi
        fi
        
        # Method 4: Use GitHub API to get the raw content
        if [[ "$success" == "false" ]]; then
            local api_url="https://api.github.com/gists/$gist_id"
            local raw_content=$(curl -s "$api_url" | grep -o '"raw_url":"[^"]*' | head -n1 | sed 's/"raw_url":"//')
            if [[ -n "$raw_content" ]]; then
                if curl -s -f "$raw_content" -o "$destination" 2>/dev/null; then
                    success=true
                fi
            fi
        fi
        
        if [[ "$success" == "true" ]]; then
            return 0
        else
            return 1
        fi
    # Regular GitHub URL
    elif [[ "$url" == *"github.com"* && ! "$url" == *"gist.github.com"* ]]; then
        # Convert GitHub URL to raw content URL
        raw_url=$(echo "$url" | sed 's|github.com|raw.githubusercontent.com|' | sed 's|/blob/||')
        if [[ ! "$raw_url" == *"/main/"* ]] && [[ ! "$raw_url" == *"/master/"* ]]; then
            raw_url="${raw_url}/main"
        fi
        
        # Try to download
        if curl -s -f "$raw_url" -o "$destination" 2>/dev/null; then
            return 0
        else
            return 1
        fi
    fi
    
    return 1
}

# Function to verify installation
verify_installation() {
    local component="$1"
    local command_to_check="$2"
    local additional_check="$3"
    
    if command_exists "$command_to_check"; then
        if [[ -n "$additional_check" ]]; then
            if eval "$additional_check" >/dev/null 2>&1; then
                INSTALLED_COMPONENTS+=("$component")
                return 0
            else
                FAILED_COMPONENTS+=("$component")
                return 1
            fi
        else
            INSTALLED_COMPONENTS+=("$component")
            return 0
        fi
    else
        FAILED_COMPONENTS+=("$component")
        return 1
    fi
}

# Function to check service status
check_service() {
    local service_name="$1"
    if systemctl is-active --quiet "$service_name" && systemctl is-enabled --quiet "$service_name"; then
        return 0
    else
        return 1
    fi
}

# Function to check file exists
check_file() {
    local file_path="$1"
    if [[ -f "$file_path" ]]; then
        return 0
    else
        return 1
    fi
}

# Function to check directory exists
check_directory() {
    local dir_path="$1"
    if [[ -d "$dir_path" ]]; then
        return 0
    else
        return 1
    fi
}

# Arrays to track installation status
declare -a INSTALLED_COMPONENTS=()
declare -a FAILED_COMPONENTS=()

echo -e "\n${BLUE}📦 INSTALLATION PROGRESS REPORTS${NC}"
echo -e "${CYAN}===========================================================${NC}"

# System Update
echo -e "\n${CYAN}[1/12] System Update & Essential Packages${NC}"
if sudo apt-get update >/dev/null 2>&1 && sudo apt-get upgrade -y >/dev/null 2>&1; then
    log_install_report "System Update" "SUCCESS" "System updated successfully"
else
    log_install_report "System Update" "FAILED" "Failed to update system"
fi

if sudo apt install screen curl iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip -y >/dev/null 2>&1; then
    log_install_report "Essential Packages" "SUCCESS" "All essential packages installed"
else
    log_install_report "Essential Packages" "FAILED" "Some essential packages failed to install"
fi

# Google Drive Tools Installation
echo -e "\n${CYAN}[1.5/12] Google Drive Tools Installation${NC}"
install_gdrive_tools
if [ $? -eq 0 ]; then
    log_install_report "Google Drive Tools" "SUCCESS" "Installed successfully"
else
    log_install_report "Google Drive Tools" "FAILED" "Failed to install Google Drive tools"
fi

# Docker Installation
echo -e "\n${CYAN}[2/12] Docker Installation${NC}"
if command_exists docker; then
    log_install_report "Docker" "SKIP" "Already installed - $(docker --version 2>/dev/null || echo 'version unknown')"
else
    # Remove old Docker versions silently
    for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do 
        sudo apt-get remove -y $pkg >/dev/null 2>&1 || true
    done

    # Primary installation method
    if sudo apt install apt-transport-https ca-certificates curl software-properties-common -y >/dev/null 2>&1 && \
       curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg >/dev/null 2>&1 && \
       echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null && \
       sudo apt update >/dev/null 2>&1 && \
       sudo apt install docker-ce docker-ce-cli containerd.io -y >/dev/null 2>&1; then
        
        sudo systemctl enable docker >/dev/null 2>&1
        sudo systemctl start docker >/dev/null 2>&1
        sudo usermod -aG docker $USER >/dev/null 2>&1
        
        if sudo docker run hello-world >/dev/null 2>&1; then
            DOCKER_VERSION=$(docker --version 2>/dev/null || echo "version unknown")
            log_install_report "Docker" "SUCCESS" "$DOCKER_VERSION - Service running"
        else
            log_install_report "Docker" "FAILED" "Installed but functionality test failed"
        fi
    else
        # Fallback installation
        if sudo apt remove -y docker docker-engine docker.io containerd runc >/dev/null 2>&1 && \
           sudo mkdir -p /etc/apt/keyrings >/dev/null 2>&1 && \
           curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg >/dev/null 2>&1 && \
           echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null && \
           sudo apt update >/dev/null 2>&1 && \
           sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1; then
            
            sudo systemctl enable docker >/dev/null 2>&1
            sudo systemctl start docker >/dev/null 2>&1
            sudo usermod -aG docker $USER >/dev/null 2>&1
            
            if sudo docker run hello-world >/dev/null 2>&1; then
                DOCKER_VERSION=$(docker --version 2>/dev/null || echo "version unknown")
                log_install_report "Docker (Fallback)" "SUCCESS" "$DOCKER_VERSION - Service running"
            else
                log_install_report "Docker (Fallback)" "FAILED" "Installed but functionality test failed"
            fi
        else
            log_install_report "Docker" "FAILED" "Both primary and fallback installation methods failed"
        fi
    fi
fi

# Python Installation
echo -e "\n${CYAN}[3/12] Python Installation${NC}"
if sudo apt-get install python3 python3-pip python3-venv python3-dev -y >/dev/null 2>&1; then
    PYTHON_VERSION=$(python3 --version 2>/dev/null || echo "version unknown")
    PIP_VERSION=$(pip3 --version 2>/dev/null || echo "version unknown")
    log_install_report "Python3" "SUCCESS" "$PYTHON_VERSION"
    log_install_report "pip3" "SUCCESS" "$PIP_VERSION"
else
    log_install_report "Python3" "FAILED" "Failed to install Python packages"
fi

# Node.js Installation
echo -e "\n${CYAN}[4/12] Node.js Installation${NC}"
if command_exists node; then
    NODE_VERSION=$(node --version 2>/dev/null || echo "version unknown")
    log_install_report "Node.js" "SKIP" "Already installed - $NODE_VERSION"
else
    if curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - >/dev/null 2>&1 && \
       sudo apt-get install -y nodejs >/dev/null 2>&1; then
        NODE_VERSION=$(node --version 2>/dev/null || echo "version unknown")
        log_install_report "Node.js" "SUCCESS" "$NODE_VERSION"
    else
        log_install_report "Node.js" "FAILED" "Failed to install Node.js"
    fi
fi

# Yarn Installation
echo -e "\n${CYAN}[5/12] Yarn Installation${NC}"
if command_exists yarn; then
    YARN_VERSION=$(yarn --version 2>/dev/null || echo "version unknown")
    log_install_report "Yarn" "SKIP" "Already installed - v$YARN_VERSION"
else
    if sudo npm install -g yarn >/dev/null 2>&1; then
        YARN_VERSION=$(yarn --version 2>/dev/null || echo "version unknown")
        log_install_report "Yarn (npm)" "SUCCESS" "v$YARN_VERSION"
    else
        # Alternative yarn installation
        if curl -o- -L https://yarnpkg.com/install.sh | bash >/dev/null 2>&1; then
            export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"
            YARN_VERSION=$(yarn --version 2>/dev/null || echo "version unknown")
            log_install_report "Yarn (alternative)" "SUCCESS" "v$YARN_VERSION"
        else
            log_install_report "Yarn" "FAILED" "Both installation methods failed"
        fi
    fi
fi

# Git Repository Cloning
echo -e "\n${CYAN}[6/12] Main Repository (rl-swarm)${NC}"
if [ -d "rl-swarm" ]; then
    log_install_report "rl-swarm Repository" "SKIP" "Directory already exists"
else
    if git clone https://github.com/gensyn-ai/rl-swarm/ >/dev/null 2>&1; then
        chmod +x ~/rl-swarm/run_rl_swarm.sh 2>/dev/null || true
        chmod +x ~/rl-swarm/run_and_alert.sh 2>/dev/null || true
        log_install_report "rl-swarm Repository" "SUCCESS" "Cloned and permissions set"
    else
        log_install_report "rl-swarm Repository" "FAILED" "Failed to clone repository"
    fi
fi

# UFW Firewall
echo -e "\n${CYAN}[7/12] Firewall Configuration${NC}"
if sudo apt install ufw -y >/dev/null 2>&1; then
    sudo ufw --force enable >/dev/null 2>&1
    sudo ufw allow 22 >/dev/null 2>&1
    sudo ufw allow 3000/tcp >/dev/null 2>&1
    log_install_report "UFW Firewall" "SUCCESS" "Enabled with SSH (22) and port 3000 allowed"
else
    log_install_report "UFW Firewall" "FAILED" "Failed to install or configure UFW"
fi

# Cloudflare Tunnel
echo -e "\n${CYAN}[8/12] Cloudflare Tunnel${NC}"
if command_exists cloudflared; then
    CLOUDFLARED_VERSION=$(cloudflared --version 2>/dev/null | head -n1 || echo "version unknown")
    log_install_report "Cloudflared" "SKIP" "Already installed - $CLOUDFLARED_VERSION"
else
    if wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb && \
       sudo dpkg -i cloudflared-linux-amd64.deb >/dev/null 2>&1; then
        rm cloudflared-linux-amd64.deb 2>/dev/null || true
        CLOUDFLARED_VERSION=$(cloudflared --version 2>/dev/null | head -n1 || echo "version unknown")
        log_install_report "Cloudflared" "SUCCESS" "$CLOUDFLARED_VERSION"
    else
        log_install_report "Cloudflared" "FAILED" "Failed to download or install"
    fi
fi

# Configuration Files Download
echo -e "\n${CYAN}[9/12] Configuration Files${NC}"
mkdir -p $HOME/rl-swarm/hivemind_exp/configs/mac/ 2>/dev/null || true

if curl -o $HOME/rl-swarm/hivemind_exp/configs/mac/grpo-qwen-2.5-0.5b-deepseek-r1.yaml https://raw.githubusercontent.com/arookiecoder-ip/Gensyn-AI-Errors-Solution/main/grpo-qwen-2.5-0.5b-deepseek-r1.yaml >/dev/null 2>&1; then
    log_install_report "Config File (YAML)" "SUCCESS" "Downloaded to configs/mac/"
else
    log_install_report "Config File (YAML)" "FAILED" "Failed to download configuration"
fi

if curl -L https://raw.githubusercontent.com/arookiecoder-ip/Gensyn-AI-Node-Monitoring/main/run_rl_swarm.sh -o ~/rl-swarm/run_rl_swarm.sh >/dev/null 2>&1; then
    log_install_report "Monitoring Script" "SUCCESS" "Downloaded run_rl_swarm.sh"
else
    log_install_report "Monitoring Script" "FAILED" "Failed to download monitoring script"
fi

# Email Tools - FIXED SECTION WITH DEBCONF PRESEED
echo -e "\n${CYAN}[10/12] Email Tools${NC}"

# Pre-configure msmtp to avoid interactive prompts (THIS IS THE FIX)
echo -e "${YELLOW}📧 Pre-configuring msmtp to avoid interactive prompts...${NC}"
echo "msmtp msmtp/armorsupport boolean false" | sudo debconf-set-selections 2>/dev/null || true

# Install dependencies with DEBIAN_FRONTEND=noninteractive
if DEBIAN_FRONTEND=noninteractive sudo -E apt-get update >/dev/null 2>&1 && \
   DEBIAN_FRONTEND=noninteractive sudo -E apt-get install -y expect msmtp curl >/dev/null 2>&1; then
    log_install_report "Email Tools" "SUCCESS" "expect, msmtp, curl installed"
else
    log_install_report "Email Tools" "FAILED" "Failed to install email tools"
fi

# =============================================================================
# INTERACTIVE MSMTP CONFIGURATION
# =============================================================================

echo -e "\n${CYAN}[10.1/12] MSMTP Email Configuration${NC}"
echo -e "${CYAN}===========================================================${NC}"

# Always ask for MSMTP configuration (overwrite if exists)
if [ -f ~/.msmtprc ]; then
    echo -e "${YELLOW}⚠️  Existing ~/.msmtprc will be overwritten${NC}"
fi

echo -e "\n${YELLOW}📧 MSMTP Email Configuration Setup${NC}"
echo -e "${BLUE}Choose how you want to configure MSMTP:${NC}"
echo -e "  ${CYAN}1)${NC} Pull configuration from GitHub/Google Drive"
echo -e "  ${CYAN}2)${NC} Paste configuration directly"
echo -e "  ${CYAN}3)${NC} Create template file (edit manually later)"
echo -e "  ${CYAN}4)${NC} Skip MSMTP configuration"
echo ""

while true; do
    read -p "Enter your choice (1-4): " msmtp_choice
    case $msmtp_choice in
        1)
            echo -e "\n${YELLOW}📥 Configuration from GitHub/Google Drive${NC}"
            echo -e "${BLUE}Enter URL from one of these sources:${NC}"
            echo -e "  ${GREEN}•${NC} GitHub repository file"
            echo -e "  ${GREEN}•${NC} GitHub Gist"
            echo -e "  ${GREEN}•${NC} Google Drive shared file"
            echo ""
            read -p "Enter URL: " config_url
            read -p "Enter file path in repository (leave blank for direct files): " file_path
            
            if [[ -n "$config_url" ]]; then
                success=false
                
                if [[ "$config_url" == *"drive.google.com"* ]]; then
                    # Google Drive URL
                    if download_from_gdrive "$config_url" ~/.msmtprc; then
                        chmod 600 ~/.msmtprc
                        log_install_report "MSMTP Config (Google Drive)" "SUCCESS" "Downloaded from Google Drive"
                        success=true
                    fi
                elif [[ "$config_url" == *"gist.github.com"* ]]; then
                    # Gist URL
                    if download_file "$config_url" ~/.msmtprc; then
                        chmod 600 ~/.msmtprc
                        log_install_report "MSMTP Config (Gist)" "SUCCESS" "Downloaded from gist"
                        success=true
                    fi
                elif [[ "$config_url" == *"github.com"* ]]; then
                    # GitHub repository file
                    if [[ -n "$file_path" ]]; then
                        # Convert GitHub URL to raw content URL
                        raw_url=$(echo "$config_url" | sed 's|github.com|raw.githubusercontent.com|' | sed 's|/blob/||')
                        if [[ ! "$raw_url" == *"/main/"* ]] && [[ ! "$raw_url" == *"/master/"* ]]; then
                            raw_url="${raw_url}/main"
                        fi
                        full_url="${raw_url}/${file_path}"
                        
                        echo -e "Downloading from: ${CYAN}$full_url${NC}"
                        if curl -o ~/.msmtprc "$full_url" >/dev/null 2>&1; then
                            chmod 600 ~/.msmtprc
                            log_install_report "MSMTP Config (GitHub)" "SUCCESS" "Downloaded from $config_url"
                            success=true
                        fi
                    else
                        # Try downloading directly
                        if download_file "$config_url" ~/.msmtprc; then
                            chmod 600 ~/.msmtprc
                            log_install_report "MSMTP Config (GitHub)" "SUCCESS" "Downloaded from $config_url"
                            success=true
                        fi
                    fi
                fi
                
                if [[ "$success" == "false" ]]; then
                    echo -e "${RED}❌ Failed to download configuration${NC}"
                    echo -e "Please check the URL and file path. Creating template instead..."
                    msmtp_choice=3
                    continue
                fi
            else
                echo -e "${RED}❌ Invalid input. Creating template instead...${NC}"
                msmtp_choice=3
                continue
            fi
            break
            ;;
        2)
            echo -e "\n${YELLOW}📝 Direct Configuration Input${NC}"
            echo -e "${BLUE}Please paste your MSMTP configuration below.${NC}"
            echo -e "${BLUE}Press Ctrl+D on a new line when finished:${NC}"
            echo ""
            
            # Read multi-line input
            config_content=""
            while IFS= read -r line; do
                config_content+="$line"$'\n'
            done
            
            if [[ -n "$config_content" ]]; then
                echo "$config_content" > ~/.msmtprc
                chmod 600 ~/.msmtprc
                log_install_report "MSMTP Config (Pasted)" "SUCCESS" "Configuration saved from user input"
            else
                echo -e "${RED}❌ No configuration provided. Creating template instead...${NC}"
                msmtp_choice=3
                continue
            fi
            break
            ;;
        3)
            echo -e "\n${YELLOW}📄 Creating Template Configuration${NC}"
            cat > ~/.msmtprc << 'EOF'
# MSMTP Configuration File
# Created on: 2025-06-19 13:08:37 UTC
# User: arookiecoder-ip
# 
# Edit this file with your email settings
# For Gmail, you'll need an "App Password" instead of your regular password
# Enable 2FA first, then generate an app password at: https://myaccount.google.com/apppasswords

defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        ~/.msmtp.log

# Gmail Configuration
account        gmail
host           smtp.gmail.com
port           587
from           your-email@gmail.com
user           your-email@gmail.com
password       your-app-password

# Outlook/Hotmail Configuration (alternative)
account        outlook
host           smtp-mail.outlook.com
port           587
from           your-email@outlook.com
user           your-email@outlook.com
password       your-password

# Yahoo Configuration (alternative)
account        yahoo
host           smtp.mail.yahoo.com
port           587
from           your-email@yahoo.com
user           your-email@yahoo.com
password       your-app-password

# Custom SMTP Configuration (alternative)
account        custom
host           smtp.your-domain.com
port           587
from           your-email@your-domain.com
user           your-email@your-domain.com
password       your-password

# Set default account (change to gmail, outlook, yahoo, or custom)
account default : gmail

# Uncomment and modify for debugging
# logfile ~/.msmtp.log
EOF
            chmod 600 ~/.msmtprc
            log_install_report "MSMTP Config (Template)" "SUCCESS" "Template created - requires manual editing"
            echo -e "${YELLOW}⚠️  Please edit ~/.msmtprc with your actual email settings${NC}"
            break
            ;;
        4)
            log_install_report "MSMTP Config" "SKIP" "Configuration skipped by user"
            break
            ;;
        *)
            echo -e "${RED}❌ Invalid choice. Please enter 1, 2, 3, or 4.${NC}"
            ;;
    esac
done

# Additional Files Setup
echo -e "\n${CYAN}[11/12] Additional Files Setup${NC}"

# 1. MSMTP Configuration (Main Directory) - handled in previous step
echo -e "MSMTP configuration handled in previous step."

# 2. Gensyn Crash Script (rl-swarm directory)
# Ask for Crash Script URL if not already set
if [[ -z "$CRASH_SCRIPT_URL" ]]; then
  echo -e "\n${YELLOW}📥 Gensyn Crash Script Setup${NC}"
  echo -e "${BLUE}Enter URL from one of these sources:${NC}"
  echo -e "  ${GREEN}•${NC} GitHub repository"
  echo -e "  ${GREEN}•${NC} GitHub Gist"
  echo -e "  ${GREEN}•${NC} Google Drive shared file"
  echo ""
  read -p "Enter URL (or press Enter to skip): " CRASH_SCRIPT_URL
  if [[ -z "$CRASH_SCRIPT_URL" ]]; then
    log_install_report "Gensyn Crash Script" "SKIP" "No URL provided"
  fi
fi

if [[ -n "$CRASH_SCRIPT_URL" ]]; then
    mkdir -p ~/rl-swarm 2>/dev/null || true
    
    # Use temporary directory to avoid conflicts
    temp_crash_dir=$(mktemp -d)
    if [[ "$CRASH_SCRIPT_URL" == *"drive.google.com"* ]]; then
        # Handle Google Drive URL
        if download_from_gdrive "$CRASH_SCRIPT_URL" "$temp_crash_dir/crash_script"; then
            cp "$temp_crash_dir/crash_script" ~/rl-swarm/ 2>/dev/null || true
            chmod +x ~/rl-swarm/crash_script 2>/dev/null || true
            rm -rf "$temp_crash_dir" 2>/dev/null || true
            log_install_report "Gensyn Crash Script (Google Drive)" "SUCCESS" "Downloaded and made executable"
        else
            rm -rf "$temp_crash_dir" 2>/dev/null || true
            log_install_report "Gensyn Crash Script" "FAILED" "Failed to download from Google Drive"
        fi
    elif clone_repository "$CRASH_SCRIPT_URL" "$temp_crash_dir"; then
        cp -r "$temp_crash_dir"/* ~/rl-swarm/ 2>/dev/null || true
        rm -rf "$temp_crash_dir" 2>/dev/null || true

        # Check for any .sh files and make them executable
        if find ~/rl-swarm/ -maxdepth 1 -type f -name "*.sh" | grep -q .; then
            find ~/rl-swarm/ -maxdepth 1 -type f -name "*.sh" -exec chmod +x {} \;
            log_install_report "Gensyn Crash Script" "SUCCESS" "Downloaded and script(s) made executable"
        else
            log_install_report "Gensyn Crash Script" "SUCCESS" "Downloaded (no .sh files to make executable)"
        fi
    else
        rm -rf "$temp_crash_dir" 2>/dev/null || true
        log_install_report "Gensyn Crash Script" "FAILED" "Failed to clone crash script repository"
    fi
else
    log_install_report "Gensyn Crash Script" "SKIP" "No URL provided"
fi

# 3. Swarm PEM File (rl-swarm directory)
# Ask for PEM File URL separately
echo -e "\n${YELLOW}📥 Swarm PEM File Setup${NC}"
echo -e "${BLUE}Enter URL from one of these sources:${NC}"
echo -e "  ${GREEN}•${NC} GitHub repository"
echo -e "  ${GREEN}•${NC} GitHub Gist"
echo -e "  ${GREEN}•${NC} Google Drive shared file"
echo ""
read -p "Enter URL (or press Enter to skip): " PEM_FILE_URL
if [[ -n "$PEM_FILE_URL" ]]; then
    mkdir -p ~/rl-swarm 2>/dev/null || true
    
    # Use temporary directory to avoid conflicts
    temp_pem_dir=$(mktemp -d)
    if [[ "$PEM_FILE_URL" == *"drive.google.com"* ]]; then
        # Handle Google Drive URL
        if download_from_gdrive "$PEM_FILE_URL" "$temp_pem_dir/pem_file"; then
            cp "$temp_pem_dir/pem_file" ~/rl-swarm/ 2>/dev/null || true
            rm -rf "$temp_pem_dir" 2>/dev/null || true
            log_install_report "Swarm PEM File (Google Drive)" "SUCCESS" "Downloaded to ~/rl-swarm/"
        else
            rm -rf "$temp_pem_dir" 2>/dev/null || true
            log_install_report "Swarm PEM File" "FAILED" "Failed to download from Google Drive"
        fi
    elif clone_repository "$PEM_FILE_URL" "$temp_pem_dir"; then
        # Copy files from temp directory to rl-swarm directory
        cp -r "$temp_pem_dir"/* ~/rl-swarm/ 2>/dev/null || true
        rm -rf "$temp_pem_dir" 2>/dev/null || true
        log_install_report "Swarm PEM File" "SUCCESS" "Downloaded/Updated to ~/rl-swarm/"
    else
        rm -rf "$temp_pem_dir" 2>/dev/null || true
        log_install_report "Swarm PEM File" "FAILED" "Failed to clone PEM file repository"
    fi
else
    log_install_report "Swarm PEM File" "SKIP" "No URL provided"
fi

echo -e "\n${GREEN}🚀 Your Gensyn Node setup is complete!${NC}"