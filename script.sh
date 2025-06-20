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
echo -e "${GREEN}                  🚀 GENSYN NODE SETUP 🚀                     ${NC}"
echo -e "${CYAN}===========================================================${NC}"
echo ""

# Current date and time in UTC with specified format
echo -e "Code Updated at 5:05pm,20/06/2025 +5:30"
CURRENT_DATE=$(date -u +"%Y-%m-%d %H:%M:%S")
CURRENT_USER=$(whoami)
echo -e "${BLUE}Current Date and Time (UTC - YYYY-MM-DD HH:MM:SS formatted): ${NC}$CURRENT_DATE"
echo -e "${BLUE}Current User's Login: ${NC}$CURRENT_USER"
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

# Function to install Google Drive CLI tools with better error handling
install_gdrive_tools() {
    echo -e "\n${CYAN}Installing Google Drive CLI tools...${NC}"
    local rclone_success=false
    
    # Install rclone (supports Google Drive)
    if command_exists rclone; then
        RCLONE_VERSION=$(rclone version | head -n 1)
        log_install_report "rclone" "SKIP" "Already installed - $RCLONE_VERSION"
        rclone_success=true
    else
        echo -e "${YELLOW}Installing rclone...${NC}"
        if curl https://rclone.org/install.sh | sudo bash; then
            RCLONE_VERSION=$(rclone version | head -n 1)
            log_install_report "rclone" "SUCCESS" "$RCLONE_VERSION"
            rclone_success=true
        else
            log_install_report "rclone" "FAILED" "Failed to install rclone"
        fi
    fi
    
    # Try to install gdown using different approaches
    echo -e "${YELLOW}Installing gdown...${NC}"
    
    # Method 0: Check if already installed
    if command_exists gdown; then
        echo -e "${GREEN}gdown is already installed${NC}"
        log_install_report "gdown" "SKIP" "Already installed"
    # Method 1: Try apt first (for Debian/Ubuntu systems)
    elif sudo apt-get install -y python3-gdown 2>/dev/null; then
        echo -e "${GREEN}Installed gdown via apt${NC}"
        log_install_report "gdown" "SUCCESS" "Installed via apt"
    # Method 2: Try using a virtual environment
    else
        echo -e "${YELLOW}Attempting to install gdown in a virtual environment...${NC}"
        
        # Make sure python3-venv is installed
        sudo apt-get install -y python3-venv python3-full
        
        # Create virtual environment in ~/.gdown_venv
        python3 -m venv ~/.gdown_venv
        
        # Install gdown in the virtual environment
        if ~/.gdown_venv/bin/pip install gdown; then
            echo -e "${GREEN}Installed gdown in virtual environment${NC}"
            
            # Create wrapper script in /usr/local/bin
            cat > /tmp/gdown_wrapper.sh << 'EOF'
#!/bin/bash
~/.gdown_venv/bin/gdown "$@"
EOF
            sudo mv /tmp/gdown_wrapper.sh /usr/local/bin/gdown
            sudo chmod +x /usr/local/bin/gdown
            
            log_install_report "gdown" "SUCCESS" "Installed in virtual environment with wrapper"
        else
            log_install_report "gdown" "FAILED" "Failed to install in virtual environment"
        fi
    fi
    
    return 0  # Continue even if gdown fails, as rclone is sufficient
}

# Function to download file from Google Drive using available tools
download_from_gdrive() {
    local drive_url="$1"
    local destination="$2"
    local destination_dir=$(dirname "$destination")
    
    # Ensure destination directory exists
    mkdir -p "$destination_dir" 2>/dev/null || true
    
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
    
    echo -e "${YELLOW}Downloading file with ID: ${NC}$file_id"
    
    # Try multiple download methods
    local success=false
    
    # Method 1: gdown (if available in PATH or via our wrapper)
    if command_exists gdown; then
        echo -e "${CYAN}Trying download with gdown...${NC}"
        if gdown --id "$file_id" -O "$destination"; then
            success=true
            echo -e "${GREEN}Download successful with gdown${NC}"
        fi
    fi
    
    # Method 2: wget with direct link
    if [[ "$success" == "false" ]]; then
        echo -e "${CYAN}Trying download with wget...${NC}"
        local confirm_param=""
        # Add confirmation parameter for large files
        if command_exists wget; then
            local direct_url="https://drive.google.com/uc?export=download&id=$file_id"
            if wget --no-check-certificate "$direct_url" -O "$destination"; then
                success=true
                echo -e "${GREEN}Download successful with wget${NC}"
            fi
        fi
    fi
    
    # Method 3: curl with direct link
    if [[ "$success" == "false" ]]; then
        echo -e "${CYAN}Trying download with curl...${NC}"
        local direct_url="https://drive.google.com/uc?export=download&id=$file_id"
        if curl -L -o "$destination" "$direct_url"; then
            success=true
            echo -e "${GREEN}Download successful with curl${NC}"
        fi
    fi
    
    if [[ "$success" == "true" ]]; then
        return 0
    else
        echo -e "${RED}All download methods failed${NC}"
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
        echo -e "${YELLOW}Detected Google Drive URL${NC}"
        # For Google Drive URLs, try to download the file
        if download_from_gdrive "$url" "$temp_dir/downloaded_file"; then
            if [[ -n "$destination" ]]; then
                # Create destination directory if it doesn't exist
                mkdir -p "$destination" 2>/dev/null || true
                
                # Copy files from temp directory to destination
                if cp -r "$temp_dir"/* "$destination/" 2>/dev/null; then
                    rm -rf "$temp_dir" 2>/dev/null || true
                    echo -e "${GREEN}Files copied from Google Drive to destination${NC}"
                    return 0
                else
                    # If copy fails, try move
                    if mv "$temp_dir"/* "$destination/" 2>/dev/null; then
                        rm -rf "$temp_dir" 2>/dev/null || true
                        echo -e "${GREEN}Files moved from Google Drive to destination${NC}"
                        return 0
                    fi
                fi
            else
                # If no destination specified, just verify the download worked
                rm -rf "$temp_dir" 2>/dev/null || true
                echo -e "${GREEN}Download from Google Drive verified${NC}"
                return 0
            fi
        fi
        
        # Cleanup on failure
        rm -rf "$temp_dir" 2>/dev/null || true
        echo -e "${RED}Failed to download from Google Drive${NC}"
        return 1
    # Check if it's a gist URL
    elif [[ "$url" == *"gist.github.com"* ]]; then
        echo -e "${YELLOW}Detected GitHub Gist URL${NC}"
        # For gists, we need to append .git to clone
        local git_url="$url"
        if [[ ! "$git_url" == *".git" ]]; then
            git_url="${git_url}.git"
        fi
        
        # Try to clone the gist
        echo -e "${CYAN}Cloning gist from: ${NC}$git_url"
        if git clone "$git_url" "$temp_dir"; then
            if [[ -n "$destination" ]]; then
                # Create destination directory if it doesn't exist
                mkdir -p "$destination" 2>/dev/null || true
                
                # Copy files from temp directory to destination
                if cp -r "$temp_dir"/* "$destination/" 2>/dev/null; then
                    rm -rf "$temp_dir" 2>/dev/null || true
                    echo -e "${GREEN}Gist files copied to destination${NC}"
                    return 0
                else
                    # If copy fails, try move
                    if mv "$temp_dir" "$destination" 2>/dev/null; then
                        echo -e "${GREEN}Gist moved to destination${NC}"
                        return 0
                    fi
                fi
            else
                # If no destination specified, just verify the clone worked
                rm -rf "$temp_dir" 2>/dev/null || true
                echo -e "${GREEN}Gist clone verified${NC}"
                return 0
            fi
        fi
        
        # Cleanup on failure
        rm -rf "$temp_dir" 2>/dev/null || true
        echo -e "${RED}Failed to clone gist${NC}"
        return 1
    else
        echo -e "${YELLOW}Detected regular GitHub repository URL${NC}"
        # Regular git repository
        if [[ -n "$destination" ]]; then
            echo -e "${CYAN}Cloning repository to: ${NC}$destination"
            if git clone "$url" "$destination"; then
                echo -e "${GREEN}Repository cloned successfully${NC}"
                return 0
            fi
        else
            echo -e "${CYAN}Cloning repository for verification${NC}"
            if git clone "$url" "$temp_dir"; then
                rm -rf "$temp_dir" 2>/dev/null || true
                echo -e "${GREEN}Repository clone verified${NC}"
                return 0
            fi
        fi
        echo -e "${RED}Failed to clone repository${NC}"
        return 1
    fi
}

# Function to download single file from gist, GitHub or Google Drive
download_file() {
    local url="$1"
    local destination="$2"
    
    # Check if it's a Google Drive URL
    if [[ "$url" == *"drive.google.com"* ]]; then
        echo -e "${YELLOW}Downloading file from Google Drive${NC}"
        if download_from_gdrive "$url" "$destination"; then
            echo -e "${GREEN}File downloaded successfully from Google Drive${NC}"
            return 0
        else
            echo -e "${RED}Failed to download file from Google Drive${NC}"
            return 1
        fi
    # Check if it's a gist URL
    elif [[ "$url" == *"gist.github.com"* ]]; then
        echo -e "${YELLOW}Downloading file from GitHub Gist${NC}"
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
        
        echo -e "${CYAN}Extracted Gist ID: ${NC}$gist_id"
        
        # Try multiple methods to download the gist
        local success=false
        
        # Method 1: Try with username
        if [[ -n "$username" && "$username" != "anonymous" ]]; then
            local raw_url="https://gist.githubusercontent.com/$username/$gist_id/raw/"
            echo -e "${CYAN}Trying URL: ${NC}$raw_url"
            if curl -s -f "$raw_url" -o "$destination"; then
                success=true
                echo -e "${GREEN}Downloaded with username method${NC}"
            fi
        fi
        
        # Method 2: Try without username (for anonymous gists)
        if [[ "$success" == "false" ]]; then
            local raw_url="https://gist.githubusercontent.com/$gist_id/raw/"
            echo -e "${CYAN}Trying URL: ${NC}$raw_url"
            if curl -s -f "$raw_url" -o "$destination"; then
                success=true
                echo -e "${GREEN}Downloaded with anonymous gist method${NC}"
            fi
        fi
        
        # Method 3: Try to get the raw URL by scraping the gist page
        if [[ "$success" == "false" ]]; then
            echo -e "${CYAN}Trying to scrape raw URL from gist page${NC}"
            local raw_url=$(curl -s "$url" | grep -o 'https://gist.githubusercontent.com/[^"]*' | head -n1)
            if [[ -n "$raw_url" ]]; then
                echo -e "${CYAN}Found raw URL: ${NC}$raw_url"
                if curl -s -f "$raw_url" -o "$destination"; then
                    success=true
                    echo -e "${GREEN}Downloaded with scraped URL method${NC}"
                fi
            fi
        fi
        
        # Method 4: Use GitHub API to get the raw content
        if [[ "$success" == "false" ]]; then
            echo -e "${CYAN}Trying GitHub API method${NC}"
            local api_url="https://api.github.com/gists/$gist_id"
            echo -e "${CYAN}API URL: ${NC}$api_url"
            local raw_content=$(curl -s "$api_url" | grep -o '"raw_url":"[^"]*' | head -n1 | sed 's/"raw_url":"//')
            if [[ -n "$raw_content" ]]; then
                echo -e "${CYAN}Found raw content URL: ${NC}$raw_content"
                if curl -s -f "$raw_content" -o "$destination"; then
                    success=true
                    echo -e "${GREEN}Downloaded with GitHub API method${NC}"
                fi
            fi
        fi
        
        if [[ "$success" == "true" ]]; then
            return 0
        else
            echo -e "${RED}All gist download methods failed${NC}"
            return 1
        fi
    # Regular GitHub URL
    elif [[ "$url" == *"github.com"* && ! "$url" == *"gist.github.com"* ]]; then
        echo -e "${YELLOW}Downloading file from GitHub repository${NC}"
        # Convert GitHub URL to raw content URL
        raw_url=$(echo "$url" | sed 's|github.com|raw.githubusercontent.com|' | sed 's|/blob/||')
        if [[ ! "$raw_url" == *"/main/"* ]] && [[ ! "$raw_url" == *"/master/"* ]]; then
            raw_url="${raw_url}/main"
        fi
        
        echo -e "${CYAN}Converted to raw URL: ${NC}$raw_url"
        
        # Try to download
        if curl -s -f "$raw_url" -o "$destination"; then
            echo -e "${GREEN}Downloaded successfully from GitHub${NC}"
            return 0
        else
            # Try master branch if main fails
            raw_url=$(echo "$url" | sed 's|github.com|raw.githubusercontent.com|' | sed 's|/blob/||' | sed 's|/main/|/master/|')
            echo -e "${CYAN}Trying master branch: ${NC}$raw_url"
            if curl -s -f "$raw_url" -o "$destination"; then
                echo -e "${GREEN}Downloaded successfully from GitHub (master branch)${NC}"
                return 0
            else
                echo -e "${RED}Failed to download from GitHub${NC}"
                return 1
            fi
        fi
    elif [[ "$url" =~ ^https?:// ]]; then
        # Direct URL download (not GitHub or Google Drive)
        echo -e "${YELLOW}Downloading from direct URL${NC}"
        if curl -s -f "$url" -o "$destination"; then
            echo -e "${GREEN}Downloaded successfully from URL${NC}"
            return 0
        else
            echo -e "${RED}Failed to download from URL${NC}"
            return 1
        fi
    else
        echo -e "${RED}Invalid URL format: ${NC}$url"
        return 1
    fi
}

# Function to validate URL
validate_url() {
    local url="$1"
    if [[ -z "$url" ]]; then
        return 1
    elif [[ "$url" =~ ^https?:// ]]; then
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
if sudo apt-get update && sudo apt-get upgrade -y; then
    log_install_report "System Update" "SUCCESS" "System updated successfully"
else
    log_install_report "System Update" "FAILED" "Failed to update system"
fi

if sudo apt install screen curl iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip -y; then
    log_install_report "Essential Packages" "SUCCESS" "All essential packages installed"
else
    log_install_report "Essential Packages" "FAILED" "Some essential packages failed to install"
fi

# Google Drive Tools Installation
echo -e "\n${CYAN}[1.5/12] Google Drive Tools Installation${NC}"
install_gdrive_tools
if [ $? -eq 0 ]; then
    log_install_report "Google Drive Tools" "SUCCESS" "At least one tool installed successfully"
else
    log_install_report "Google Drive Tools" "FAILED" "Failed to install Google Drive tools"
fi

# Docker Installation
echo -e "\n${CYAN}[2/12] Docker Installation${NC}"
if command_exists docker; then
    log_install_report "Docker" "SKIP" "Already installed - $(docker --version || echo 'version unknown')"
else
    # Remove old Docker versions silently
    for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do 
        sudo apt-get remove -y $pkg || true
    done

    # Primary installation method
    if sudo apt install apt-transport-https ca-certificates curl software-properties-common -y && \
       curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
       echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null && \
       sudo apt update && \
       sudo apt install docker-ce docker-ce-cli containerd.io -y; then
        
        sudo systemctl enable docker
        sudo systemctl start docker
        sudo usermod -aG docker $USER
        
        if sudo docker run hello-world; then
            DOCKER_VERSION=$(docker --version || echo "version unknown")
            log_install_report "Docker" "SUCCESS" "$DOCKER_VERSION - Service running"
        else
            log_install_report "Docker" "FAILED" "Installed but functionality test failed"
        fi
    else
        # Fallback installation
        if sudo apt remove -y docker docker-engine docker.io containerd runc && \
           sudo mkdir -p /etc/apt/keyrings && \
           curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
           echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null && \
           sudo apt update && \
           sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; then
            
            sudo systemctl enable docker
            sudo systemctl start docker
            sudo usermod -aG docker $USER
            
            if sudo docker run hello-world; then
                DOCKER_VERSION=$(docker --version || echo "version unknown")
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
if sudo apt-get install python3 python3-pip python3-venv python3-dev -y; then
    PYTHON_VERSION=$(python3 --version || echo "version unknown")
    PIP_VERSION=$(pip3 --version || echo "version unknown")
    log_install_report "Python3" "SUCCESS" "$PYTHON_VERSION"
    log_install_report "pip3" "SUCCESS" "$PIP_VERSION"
else
    log_install_report "Python3" "FAILED" "Failed to install Python packages"
fi

# Node.js Installation
echo -e "\n${CYAN}[4/12] Node.js Installation${NC}"
if command_exists node; then
    NODE_VERSION=$(node --version || echo "version unknown")
    log_install_report "Node.js" "SKIP" "Already installed - $NODE_VERSION"
else
    if curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - && \
       sudo apt-get install -y nodejs; then
        NODE_VERSION=$(node --version || echo "version unknown")
        log_install_report "Node.js" "SUCCESS" "$NODE_VERSION"
    else
        log_install_report "Node.js" "FAILED" "Failed to install Node.js"
    fi
fi

# Yarn Installation
echo -e "\n${CYAN}[5/12] Yarn Installation${NC}"
if command_exists yarn; then
    YARN_VERSION=$(yarn --version || echo "version unknown")
    log_install_report "Yarn" "SKIP" "Already installed - v$YARN_VERSION"
else
    if sudo npm install -g yarn; then
        YARN_VERSION=$(yarn --version || echo "version unknown")
        log_install_report "Yarn (npm)" "SUCCESS" "v$YARN_VERSION"
    else
        # Alternative yarn installation
        if curl -o- -L https://yarnpkg.com/install.sh | bash; then
            export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"
            YARN_VERSION=$(yarn --version || echo "version unknown")
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
    if git clone https://github.com/gensyn-ai/rl-swarm/; then
        chmod +x ~/rl-swarm/run_rl_swarm.sh 2>/dev/null || true
        log_install_report "rl-swarm Repository" "SUCCESS" "Cloned and permissions set"
    else
        log_install_report "rl-swarm Repository" "FAILED" "Failed to clone repository"
    fi
fi

# UFW Firewall
echo -e "\n${CYAN}[7/12] Firewall Configuration${NC}"
if sudo apt install ufw -y; then
    sudo ufw --force enable
    sudo ufw allow 22
    sudo ufw allow 3000/tcp
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
       sudo dpkg -i cloudflared-linux-amd64.deb; then
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

if curl -o $HOME/rl-swarm/hivemind_exp/configs/mac/grpo-qwen-2.5-0.5b-deepseek-r1.yaml https://raw.githubusercontent.com/arookiecoder-ip/Gensyn-AI-Errors-Solution/main/grpo-qwen-2.5-0.5b-deepseek-r1.yaml; then
    log_install_report "Config File (YAML)" "SUCCESS" "Downloaded to configs/mac/"
else
    log_install_report "Config File (YAML)" "FAILED" "Failed to download configuration"
fi

if curl -L https://raw.githubusercontent.com/arookiecoder-ip/Gensyn-AI-Node-Monitoring/main/run_rl_swarm.sh -o ~/rl-swarm/run_rl_swarm.sh; then
    log_install_report "Main Script Modification" "SUCCESS" "Downloaded run_rl_swarm.sh"
else
    log_install_report "Main Script Modification" "FAILED" "Failed to download monitoring script"
fi

# Email Tools - FIXED SECTION WITH DEBCONF PRESEED
echo -e "\n${CYAN}[10/12] Email Tools${NC}"

# Pre-configure msmtp to avoid interactive prompts (THIS IS THE FIX)
echo -e "${YELLOW}📧 Pre-configuring msmtp to avoid interactive prompts...${NC}"
echo "msmtp msmtp/armorsupport boolean false" | sudo debconf-set-selections 2>/dev/null || true

# Install dependencies with DEBIAN_FRONTEND=noninteractive
if DEBIAN_FRONTEND=noninteractive sudo -E apt-get update && \
   DEBIAN_FRONTEND=noninteractive sudo -E apt-get install -y expect msmtp curl; then
    log_install_report "Email Tools" "SUCCESS" "expect, msmtp, curl installed"
else
    log_install_report "Email Tools" "FAILED" "Failed to install email tools"
fi

# =============================================================================
# MSMTP CONFIGURATION - SIMPLIFIED TO LINK INPUT ONLY
# =============================================================================

echo -e "\n${CYAN}[10.1/12] MSMTP Email Configuration${NC}"
echo -e "${CYAN}===========================================================${NC}"

# Always warn if msmtprc exists
if [ -f ~/.msmtprc ]; then
    echo -e "${YELLOW}⚠️  Existing ~/.msmtprc will be overwritten${NC}"
fi

echo -e "\n${YELLOW}📧 MSMTP Email Configuration Setup${NC}"
echo -e "${BLUE}Enter the URL for your MSMTP configuration:${NC}"
echo -e "- GitHub repository"
echo -e "- GitHub Gist"
echo -e "- Google Drive shared file"
echo -e "(Press Enter to skip)"
echo ""

read -p "Enter URL: " config_url
if [[ -z "$config_url" ]]; then
    log_install_report "MSMTP Config" "SKIP" "No URL provided"
else
    # Validate URL format
    if ! [[ "$config_url" =~ ^https?:// ]]; then
        echo -e "${RED}❌ Invalid URL format.${NC}"
        log_install_report "MSMTP Config" "FAILED" "Invalid URL format"
    else
        # Download based on URL type
        if [[ "$config_url" == *"drive.google.com"* ]]; then
            if download_from_gdrive "$config_url" ~/.msmtprc; then
                chmod 600 ~/.msmtprc
                log_install_report "MSMTP Config" "SUCCESS" "Downloaded from Google Drive"
            else
                log_install_report "MSMTP Config" "FAILED" "Failed to download from Google Drive"
            fi
        elif [[ "$config_url" == *"gist.github.com"* ]]; then
            if download_file "$config_url" ~/.msmtprc; then
                chmod 600 ~/.msmtprc
                log_install_report "MSMTP Config" "SUCCESS" "Downloaded from gist"
            else
                log_install_report "MSMTP Config" "FAILED" "Failed to download from gist"
            fi
        else
            # Try as a GitHub file or direct URL
            if download_file "$config_url" ~/.msmtprc; then
                chmod 600 ~/.msmtprc
                log_install_report "MSMTP Config" "SUCCESS" "Downloaded configuration"
            else
                log_install_report "MSMTP Config" "FAILED" "Failed to download configuration"
            fi
        fi
    fi
fi

# Additional Files Setup
echo -e "\n${CYAN}[11/12] Additional Files Setup${NC}"

# 1. MSMTP Configuration (Main Directory) - handled in previous step
echo -e "MSMTP configuration handled in previous step."

# 2. Gensyn Crash Script (rl-swarm directory)
echo -e "\n${YELLOW}📥 Gensyn Crash Script Setup${NC}"
echo -e "${BLUE}Enter the URL for Gensyn crash script:${NC}"
echo -e "(Press Enter to skip)"
echo ""

read -p "Enter URL: " alert_script_URL
if [[ -z "$alert_script_URL" ]]; then
    log_install_report "Gensyn Crash Script" "SKIP" "No URL provided"
else
    mkdir -p ~/rl-swarm 2>/dev/null || true

    if ! [[ "$alert_script_URL" =~ ^https?:// ]]; then
        echo -e "${RED}❌ Invalid URL format.${NC}"
        log_install_report "Gensyn Crash Script" "FAILED" "Invalid URL format"
    else
        # Use temporary directory to avoid conflicts
        temp_crash_dir=$(mktemp -d)
        if [[ "$alert_script_URL" == *"drive.google.com"* ]]; then
            # Handle Google Drive URL
            if download_from_gdrive "$alert_script_URL" "$temp_crash_dir/run_and_alert.sh"; then
                cp "$temp_crash_dir/run_and_alert.sh" ~/rl-swarm/ 2>/dev/null || true
                chmod +x ~/rl-swarm/run_and_alert.sh 2>/dev/null || true
                rm -rf "$temp_crash_dir" 2>/dev/null || true
                log_install_report "Gensyn Crash Script" "SUCCESS" "Downloaded from Google Drive and made executable"
            else
                rm -rf "$temp_crash_dir" 2>/dev/null || true
                log_install_report "Gensyn Crash Script" "FAILED" "Failed to download from Google Drive"
            fi
        elif clone_repository "$alert_script_URL" "$temp_crash_dir"; then
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
            log_install_report "Gensyn Crash Script" "FAILED" "Failed to clone/download script"
        fi
    fi
fi

# 3. Swarm PEM File (rl-swarm directory)
echo -e "\n${YELLOW}📥 Swarm PEM File Setup${NC}"
echo -e "${BLUE}Enter the URL for Swarm PEM file:${NC}"
echo -e "(Press Enter to skip)"
echo ""

read -p "Enter URL: " PEM_FILE_URL
if [[ -z "$PEM_FILE_URL" ]]; then
    log_install_report "Swarm PEM File" "SKIP" "No URL provided"
else
    mkdir -p ~/rl-swarm 2>/dev/null || true
    
    if ! [[ "$PEM_FILE_URL" =~ ^https?:// ]]; then
        echo -e "${RED}❌ Invalid URL format.${NC}"
        log_install_report "Swarm PEM File" "FAILED" "Invalid URL format"
    else
        # Use temporary directory to avoid conflicts
        temp_pem_dir=$(mktemp -d)
        if [[ "$PEM_FILE_URL" == *"drive.google.com"* ]]; then
            # Handle Google Drive URL
            if download_from_gdrive "$PEM_FILE_URL" "$temp_pem_dir/swarm.pem"; then
                cp "$temp_pem_dir/swarm.pem" ~/rl-swarm/ 2>/dev/null || true
                rm -rf "$temp_pem_dir" 2>/dev/null || true
                log_install_report "Swarm PEM File" "SUCCESS" "Downloaded from Google Drive to ~/rl-swarm/"
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
            log_install_report "Swarm PEM File" "FAILED" "Failed to clone/download PEM file"
        fi
    fi
fi

echo -e "\n${GREEN}🚀 Your Gensyn Node setup is complete!${NC}"