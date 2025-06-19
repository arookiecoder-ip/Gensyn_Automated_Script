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
echo -e "${GREEN}                  🚀 GENSYN NODE SETUP 🚀                   ${NC}"
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

# Function to clone gist or regular git repository
clone_repository() {
    local url="$1"
    local destination="$2"
    local temp_dir=$(mktemp -d)
    
    # Check if it's a gist URL
    if [[ "$url" == *"gist.github.com"* ]]; then
        # Extract gist ID and clone
        if git clone "$url.git" "$temp_dir" >/dev/null 2>&1; then
            if [[ -n "$destination" ]]; then
                mv "$temp_dir" "$destination" 2>/dev/null || cp -r "$temp_dir"/* "$destination/" 2>/dev/null
            fi
            return 0
        else
            rm -rf "$temp_dir" 2>/dev/null
            return 1
        fi
    else
        # Regular git repository
        if git clone "$url" "$destination" >/dev/null 2>&1; then
            return 0
        else
            return 1
        fi
    fi
}

# Function to download single file from gist
download_gist_file() {
    local gist_url="$1"
    local destination="$2"
    
    # Convert gist URL to raw content URL
    if [[ "$gist_url" == *"gist.github.com"* ]]; then
        # Extract gist ID
        gist_id=$(echo "$gist_url" | sed 's/.*gist.github.com\/[^\/]*\///g' | sed 's/\/.*//g')
        
        # Try to get raw content
        raw_url="https://gist.githubusercontent.com/arookiecoder-ip/${gist_id}/raw/"
        
        if curl -s "$raw_url" -o "$destination" 2>/dev/null; then
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

# Email Tools
echo -e "\n${CYAN}[10/12] Email Tools${NC}"
if sudo apt update >/dev/null 2>&1 && DEBIAN_FRONTEND=noninteractive sudo apt install expect msmtp curl -y >/dev/null 2>&1; then
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
echo -e "  ${CYAN}1)${NC} Pull configuration from GitHub repository or Gist"
echo -e "  ${CYAN}2)${NC} Paste configuration directly"
echo -e "  ${CYAN}3)${NC} Create template file (edit manually later)"
echo -e "  ${CYAN}4)${NC} Skip MSMTP configuration"
echo ""

while true; do
    read -p "Enter your choice (1-4): " msmtp_choice
    case $msmtp_choice in
        1)
            echo -e "\n${YELLOW}📥 GitHub Repository/Gist Configuration${NC}"
            read -p "Enter GitHub repository URL or Gist URL for MSMTP config: " github_repo
            read -p "Enter file path in repository (e.g., .msmtprc or msmtprc) [default: .msmtprc]: " file_path
            file_path=${file_path:-.msmtprc}
            
            if [[ -n "$github_repo" ]]; then
                success=false
                
                # Try gist download first
                if [[ "$github_repo" == *"gist.github.com"* ]]; then
                    if download_gist_file "$github_repo" ~/.msmtprc; then
                        chmod 600 ~/.msmtprc
                        log_install_report "MSMTP Config (Gist)" "SUCCESS" "Downloaded from gist"
                        success=true
                    fi
                fi
                
                # If gist failed or not a gist, try regular repo
                if [[ "$success" == "false" ]]; then
                    # Convert GitHub URL to raw content URL
                    raw_url=$(echo "$github_repo" | sed 's|github.com|raw.githubusercontent.com|' | sed 's|/blob/||')
                    if [[ ! "$raw_url" == *"/main/"* ]] && [[ ! "$raw_url" == *"/master/"* ]]; then
                        raw_url="${raw_url}/main"
                    fi
                    full_url="${raw_url}/${file_path}"
                    
                    echo -e "Downloading from: ${CYAN}$full_url${NC}"
                    if curl -o ~/.msmtprc "$full_url" >/dev/null 2>&1; then
                        chmod 600 ~/.msmtprc
                        log_install_report "MSMTP Config (GitHub)" "SUCCESS" "Downloaded from $github_repo"
                        success=true
                    fi
                fi
                
                if [[ "$success" == "false" ]]; then
                    echo -e "${RED}❌ Failed to download from GitHub/Gist${NC}"
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

# 2. Gensyn Crash Script (rl-swarm directory) - Always ask and update
read -p "Enter Gensyn crash script repository URL or Gist URL (or press Enter to skip): " CRASH_SCRIPT_URL
if [[ -n "$CRASH_SCRIPT_URL" ]]; then
    mkdir -p ~/rl-swarm 2>/dev/null || true
    
    # Use temporary directory to avoid conflicts
    temp_crash_dir=$(mktemp -d)
    if clone_repository "$CRASH_SCRIPT_URL" "$temp_crash_dir"; then
        # Copy files from temp directory to rl-swarm directory
        cp -r "$temp_crash_dir"/* ~/rl-swarm/ 2>/dev/null || true
        rm -rf "$temp_crash_dir" 2>/dev/null || true
        log_install_report "Gensyn Crash Script" "SUCCESS" "Downloaded/Updated to ~/rl-swarm/"
    else
        rm -rf "$temp_crash_dir" 2>/dev/null || true
        log_install_report "Gensyn Crash Script" "FAILED" "Failed to clone crash script repository"
    fi
else
    log_install_report "Gensyn Crash Script" "SKIP" "No URL provided"
fi

# 3. Swarm PEM File (rl-swarm directory) - Always ask and update
read -p "Enter Swarm PEM file repository URL or Gist URL (or press Enter to skip): " PEM_FILE_URL
if [[ -n "$PEM_FILE_URL" ]]; then
    mkdir -p ~/rl-swarm 2>/dev/null || true
    
    # Use temporary directory to avoid conflicts
    temp_pem_dir=$(mktemp -d)
    if clone_repository "$PEM_FILE_URL" "$temp_pem_dir"; then
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

# =============================================================================
# COMPREHENSIVE VERIFICATION & FINAL REPORT
# =============================================================================

echo -e "\n${CYAN}[12/12] Final Verification${NC}"
echo -e "${CYAN}===========================================================${NC}"

# Reset arrays for final verification
INSTALLED_COMPONENTS=()
FAILED_COMPONENTS=()

# Verify system packages
SYSTEM_PACKAGES=("curl" "git" "wget" "jq" "make" "gcc" "nano" "tmux" "htop" "tar" "unzip")
VERIFIED_PACKAGES=0
for package in "${SYSTEM_PACKAGES[@]}"; do
    if command_exists "$package"; then
        ((VERIFIED_PACKAGES++))
        INSTALLED_COMPONENTS+=("$package")
    else
        FAILED_COMPONENTS+=("$package")
    fi
done
log_install_report "System Packages" "SUCCESS" "$VERIFIED_PACKAGES/${#SYSTEM_PACKAGES[@]} packages verified"

# Docker verification
if command_exists docker; then
    if sudo docker run --rm hello-world >/dev/null 2>&1; then
        if check_service "docker"; then
            log_install_report "Docker Service" "SUCCESS" "Running and enabled"
            INSTALLED_COMPONENTS+=("Docker")
        else
            log_install_report "Docker Service" "FAILED" "Not running properly"
            FAILED_COMPONENTS+=("Docker Service")
        fi
    else
        log_install_report "Docker Functionality" "FAILED" "Docker command works but hello-world test failed"
        FAILED_COMPONENTS+=("Docker Functionality")
    fi
else
    log_install_report "Docker Service" "FAILED" "Docker not installed"
    FAILED_COMPONENTS+=("Docker")
fi

# Python verification
if command_exists python3 && command_exists pip3; then
    log_install_report "Python Environment" "SUCCESS" "Python3 and pip3 available"
    INSTALLED_COMPONENTS+=("Python Environment")
else
    log_install_report "Python Environment" "FAILED" "Missing Python components"
    FAILED_COMPONENTS+=("Python Environment")
fi

# Node.js/Yarn verification
if command_exists node && command_exists npm; then
    if command_exists yarn; then
        log_install_report "Node.js Environment" "SUCCESS" "Node.js, npm, and yarn available"
        INSTALLED_COMPONENTS+=("Node.js Environment")
    else
        log_install_report "Node.js Environment" "PARTIAL" "Node.js and npm available, yarn missing"
        FAILED_COMPONENTS+=("Yarn")
    fi
else
    log_install_report "Node.js Environment" "FAILED" "Missing Node.js components"
    FAILED_COMPONENTS+=("Node.js Environment")
fi

# Repository verification
if check_directory "$HOME/rl-swarm" && check_file "$HOME/rl-swarm/run_rl_swarm.sh"; then
    if check_file "$HOME/rl-swarm/hivemind_exp/configs/mac/grpo-qwen-2.5-0.5b-deepseek-r1.yaml"; then
        log_install_report "Project Structure" "SUCCESS" "All files and configurations in place"
        INSTALLED_COMPONENTS+=("Project Structure")
    else
        log_install_report "Project Structure" "PARTIAL" "Repository cloned but config missing"
        FAILED_COMPONENTS+=("Config File")
    fi
else
    log_install_report "Project Structure" "FAILED" "Repository or scripts missing"
    FAILED_COMPONENTS+=("Project Structure")
fi

# UFW verification
if command_exists ufw; then
    if sudo ufw status | grep -q "Status: active" 2>/dev/null; then
        log_install_report "UFW Firewall" "SUCCESS" "Active and configured"
        INSTALLED_COMPONENTS+=("UFW Firewall")
    else
        log_install_report "UFW Firewall" "FAILED" "Installed but not active"
        FAILED_COMPONENTS+=("UFW Status")
    fi
else
    log_install_report "UFW Firewall" "FAILED" "Not installed"
    FAILED_COMPONENTS+=("UFW Firewall")
fi

# Cloudflared verification
if command_exists cloudflared; then
    log_install_report "Cloudflared" "SUCCESS" "Installed and available"
    INSTALLED_COMPONENTS+=("Cloudflared")
else
    log_install_report "Cloudflared" "FAILED" "Not installed"
    FAILED_COMPONENTS+=("Cloudflared")
fi

# MSMTP verification
if check_file ~/.msmtprc; then
    if [[ $(stat -c %a ~/.msmtprc 2>/dev/null) == "600" ]]; then
        # Check if it's still the template or has been configured
        if grep -q "your-email@gmail.com" ~/.msmtprc 2>/dev/null; then
            log_install_report "MSMTP Configuration" "PARTIAL" "Template created - needs manual configuration"
            FAILED_COMPONENTS+=("MSMTP Config")
        else
            log_install_report "MSMTP Configuration" "SUCCESS" "Configuration file ready with proper permissions"
            INSTALLED_COMPONENTS+=("MSMTP Configuration")
        fi
    else
        log_install_report "MSMTP Configuration" "FAILED" "File exists but permissions are incorrect"
        FAILED_COMPONENTS+=("MSMTP Permissions")
    fi
else
    log_install_report "MSMTP Configuration" "SKIP" "No configuration file created"
fi

# Additional files verification - Check for crash script files
crash_script_found=false
if check_directory "$HOME/rl-swarm"; then
    # Look for common crash script files
    for file in "run_and_alert.sh" "crash_monitor.sh" "alert.sh" "monitor.sh"; do
        if check_file "$HOME/rl-swarm/$file"; then
            crash_script_found=true
            break
        fi
    done
fi

if [ "$crash_script_found" = true ]; then
    log_install_report "Gensyn Crash Script Files" "SUCCESS" "Crash script files found in ~/rl-swarm/"
    INSTALLED_COMPONENTS+=("Gensyn Crash Script Files")
else
    log_install_report "Gensyn Crash Script Files" "SKIP" "No crash script files detected"
fi

# Additional files verification - Check for PEM files
pem_files_found=false
if check_directory "$HOME/rl-swarm"; then
    # Look for PEM files
    if find "$HOME/rl-swarm" -name "*.pem" -type f | grep -q .; then
        pem_files_found=true
    fi
fi

if [ "$pem_files_found" = true ]; then
    log_install_report "Swarm PEM Files" "SUCCESS" "PEM files found in ~/rl-swarm/"
    INSTALLED_COMPONENTS+=("Swarm PEM Files")
else
    log_install_report "Swarm PEM Files" "SKIP" "No PEM files detected"
fi

# =============================================================================
# FINAL SUMMARY REPORT
# =============================================================================

echo -e "\n${CYAN}===========================================================${NC}"
echo -e "${BLUE}                📊 FINAL INSTALLATION REPORT 📊            ${NC}"
echo -e "${CYAN}===========================================================${NC}"

# Calculate success percentage
TOTAL_COMPONENTS=$((${#INSTALLED_COMPONENTS[@]} + ${#FAILED_COMPONENTS[@]}))
if [ $TOTAL_COMPONENTS -gt 0 ]; then
    SUCCESS_PERCENTAGE=$(( ${#INSTALLED_COMPONENTS[@]} * 100 / $TOTAL_COMPONENTS ))
else
    SUCCESS_PERCENTAGE=0
fi

SETUP_TIME="2025-06-19 13:08:37 UTC"
echo -e "\n${BLUE}📅 Setup completed: ${SETUP_TIME}${NC}"
echo -e "${BLUE}👤 Setup by: arookiecoder-ip${NC}"
echo -e "${BLUE}📈 Success Rate: ${SUCCESS_PERCENTAGE}% (${#INSTALLED_COMPONENTS[@]}/${TOTAL_COMPONENTS})${NC}"

echo -e "\n${GREEN}✅ SUCCESSFULLY INSTALLED (${#INSTALLED_COMPONENTS[@]})${NC}"
for component in "${INSTALLED_COMPONENTS[@]}"; do
    echo -e "   ${GREEN}✓${NC} $component"
done

if [ ${#FAILED_COMPONENTS[@]} -gt 0 ]; then
    echo -e "\n${RED}❌ FAILED OR MISSING (${#FAILED_COMPONENTS[@]})${NC}"
    for component in "${FAILED_COMPONENTS[@]}"; do
        echo -e "   ${RED}✗${NC} $component"
    done
fi

echo -e "\n${BLUE}🎯 READY TO USE:${NC}"
echo -e "   ${CYAN}cd ~/rl-swarm${NC}"
echo -e "   ${CYAN}./run_rl_swarm.sh${NC}"

echo -e "\n${YELLOW}⚠️  IMPORTANT NEXT STEPS:${NC}"
echo -e "   1. Logout and login (or run: ${CYAN}newgrp docker${NC})"
if check_file ~/.msmtprc && grep -q "your-email@gmail.com" ~/.msmtprc 2>/dev/null; then
    echo -e "   2. ${YELLOW}REQUIRED:${NC} Edit ~/.msmtprc with your email settings"
fi
echo -e "   3. Test Docker: ${CYAN}docker run hello-world${NC}"
echo -e "   4. Test email (if configured): ${CYAN}echo 'Test' | msmtp your-email@domain.com${NC}"

# Generate setup report
REPORT_FILE="$HOME/gensyn_setup_report_$(date +%Y%m%d_%H%M%S).txt"
{
    echo "Gensyn Node Setup Report"
    echo "========================"
    echo "Date: $SETUP_TIME"
    echo "User: arookiecoder-ip"
    echo "Success Rate: ${SUCCESS_PERCENTAGE}%"
    echo ""
    echo "Successfully Installed (${#INSTALLED_COMPONENTS[@]}):"
    for component in "${INSTALLED_COMPONENTS[@]}"; do
        echo "  ✓ $component"
    done
    echo ""
    if [ ${#FAILED_COMPONENTS[@]} -gt 0 ]; then
        echo "Failed Components (${#FAILED_COMPONENTS[@]}):"
        for component in "${FAILED_COMPONENTS[@]}"; do
            echo "  ✗ $component"
        done
        echo ""
    fi
    echo "Files and Directories:"
    if check_directory "$HOME/rl-swarm"; then
        echo "  ✓ ~/rl-swarm/ directory exists"
    fi
    if check_file ~/.msmtprc; then
        echo "  ✓ ~/.msmtprc configuration exists"
    fi
    if [ "$crash_script_found" = true ]; then
        echo "  ✓ Crash script files found in ~/rl-swarm/"
    fi
    if [ "$pem_files_found" = true ]; then
        echo "  ✓ PEM files found in ~/rl-swarm/"
    fi
    echo ""
    echo "Next Steps:"
    echo "1. Logout and login again for Docker group permissions"
    if check_file ~/.msmtprc && grep -q "your-email@gmail.com" ~/.msmtprc 2>/dev/null; then
        echo "2. IMPORTANT: Configure ~/.msmtprc with your email settings"
    fi
    echo "3. Navigate to ~/rl-swarm and run ./run_rl_swarm.sh"
} > "$REPORT_FILE"

echo -e "\n${BLUE}📄 Report saved: ${REPORT_FILE}${NC}"

echo -e "\n${CYAN}===========================================================${NC}"
echo -e "${GREEN}                    🔔 SETUP COMPLETE! 🔔                  ${NC}"
echo -e "${CYAN}===========================================================${NC}"

if [ ${#FAILED_COMPONENTS[@]} -eq 0 ]; then
    echo -e "\n${GREEN}🎉 Perfect! All components installed successfully!${NC}"
else
    echo -e "\n${YELLOW}⚠️  Setup completed with ${#FAILED_COMPONENTS[@]} issues. Please review and fix the failed components.${NC}"
fi

echo -e "\n${GREEN}🚀 Your Gensyn Node setup is complete!${NC}"