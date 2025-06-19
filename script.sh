#!/bin/bash

# Gensyn Installation Script
# Description: Complete installation script for Gensyn mining node setup
# Author: Auto-generated installation script
# Current Date and Time (UTC - YYYY-MM-DD HH:MM:SS formatted): 2025-06-19 13:33:25
# Current User's Login: arookiecoder-ip

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Installation report arrays
declare -a INSTALL_REPORTS=()

# Function to log installation results
log_install_report() {
    local component="$1"
    local status="$2"
    local details="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S UTC')
    
    INSTALL_REPORTS+=("$timestamp | $component | $status | $details")
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if a service is running
check_service() {
    local service_name="$1"
    if systemctl is-active --quiet "$service_name" && systemctl is-enabled --quiet "$service_name"; then
        return 0
    else
        return 1
    fi
}

# Function to check if a directory exists
check_directory() {
    [[ -d "$1" ]]
}

# Function to check if a file exists
check_file() {
    [[ -f "$1" ]]
}

# Function to clone repository with gist support
clone_repository() {
    local url="$1"
    local destination="$2"
    local temp_dir=$(mktemp -d)
    
    if [[ "$url" == *"gist.github.com"* ]]; then
        # Auto-add .git if not already present
        if [[ "$url" != *".git" ]]; then
            url="${url}.git"
            echo -e "${YELLOW}🔍 Auto-detected Gist URL, added .git extension${NC}"
        fi
        
        if git clone "$url" "$temp_dir" >/dev/null 2>&1; then
            if [[ -n "$destination" ]]; then
                # Ensure destination exists
                mkdir -p "$destination" 2>/dev/null || true
                # Copy contents, not move directory
                if cp -r "$temp_dir"/* "$destination/" 2>/dev/null; then
                    rm -rf "$temp_dir" 2>/dev/null || true
                    return 0
                else
                    echo -e "${RED}❌ Failed to copy files to destination${NC}"
                    rm -rf "$temp_dir" 2>/dev/null || true
                    return 1
                fi
            fi
            rm -rf "$temp_dir" 2>/dev/null || true
            return 0
        else
            echo -e "${RED}❌ Failed to clone Gist repository${NC}"
            rm -rf "$temp_dir" 2>/dev/null || true
            return 1
        fi
    else
        if git clone "$url" "$temp_dir" >/dev/null 2>&1; then
            if [[ -n "$destination" ]]; then
                mkdir -p "$destination" 2>/dev/null || true
                if cp -r "$temp_dir"/* "$destination/" 2>/dev/null; then
                    rm -rf "$temp_dir" 2>/dev/null || true
                    return 0
                else
                    echo -e "${RED}❌ Failed to copy files to destination${NC}"
                    rm -rf "$temp_dir" 2>/dev/null || true
                    return 1
                fi
            fi
            rm -rf "$temp_dir" 2>/dev/null || true
            return 0
        else
            echo -e "${RED}❌ Failed to clone repository${NC}"
            rm -rf "$temp_dir" 2>/dev/null || true
            return 1
        fi
    fi
}

# Function to display header
display_header() {
    clear
    echo -e "${PURPLE}============================================================${NC}"
    echo -e "${WHITE}              GENSYN MINING NODE SETUP${NC}"
    echo -e "${PURPLE}============================================================${NC}"
    echo -e "${CYAN}Automated installation script for Gensyn mining node${NC}"
    echo -e "${YELLOW}This script will install and configure all required components${NC}"
    echo -e "${PURPLE}============================================================${NC}\n"
}

# Function to check system requirements
check_system_requirements() {
    echo -e "${CYAN}Checking system requirements...${NC}"
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        echo -e "${RED}❌ This script should not be run as root. Please run as a regular user with sudo privileges.${NC}"
        exit 1
    fi
    
    # Check if sudo is available
    if ! command_exists sudo; then
        echo -e "${RED}❌ sudo is required but not installed. Please install sudo first.${NC}"
        exit 1
    fi
    
    # Check sudo privileges
    if ! sudo -n true 2>/dev/null; then
        echo -e "${YELLOW}⚠️  This script requires sudo privileges. You may be prompted for your password.${NC}"
        sudo -v
    fi
    
    # Check internet connectivity
    if ! ping -c 1 google.com >/dev/null 2>&1; then
        echo -e "${RED}❌ No internet connection detected. Please check your network connection.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ System requirements check passed${NC}\n"
}

# Start installation
display_header
check_system_requirements

echo -e "${CYAN}[1/12] System Update${NC}"
echo "==========================================================="
echo -e "${YELLOW}Updating package lists and upgrading system packages...${NC}"
sudo apt update && sudo apt upgrade -y
log_install_report "System Update" "SUCCESS" "Package lists updated and system upgraded"
echo -e "${GREEN}✅ System update completed${NC}\n"

echo -e "${CYAN}[2/12] Essential Packages Installation${NC}"
echo "==========================================================="
echo -e "${YELLOW}Installing essential packages (curl, wget, git, unzip, software-properties-common)...${NC}"
sudo apt install -y curl wget git unzip software-properties-common build-essential
log_install_report "Essential Packages" "SUCCESS" "curl, wget, git, unzip, software-properties-common, build-essential installed"
echo -e "${GREEN}✅ Essential packages installed${NC}\n"

echo -e "${CYAN}[3/12] Docker Installation${NC}"
echo "==========================================================="
if command_exists docker; then
    echo -e "${GREEN}Docker is already installed${NC}"
    docker --version
    log_install_report "Docker" "ALREADY_INSTALLED" "Docker was already present on the system"
else
    echo -e "${YELLOW}Installing Docker...${NC}"
    # Add Docker's official GPG key
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    
    # Add the repository to Apt sources
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    
    # Install Docker Engine
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    log_install_report "Docker" "SUCCESS" "Docker installed and user added to docker group"
    echo -e "${GREEN}✅ Docker installed successfully${NC}"
    echo -e "${YELLOW}⚠️  Please log out and log back in for docker group changes to take effect${NC}"
fi
echo ""

echo -e "${CYAN}[4/12] Docker Compose Installation${NC}"
echo "==========================================================="
if command_exists docker-compose || docker compose version >/dev/null 2>&1; then
    echo -e "${GREEN}Docker Compose is already available${NC}"
    if command_exists docker-compose; then
        docker-compose --version
    else
        docker compose version
    fi
    log_install_report "Docker Compose" "ALREADY_INSTALLED" "Docker Compose was already available"
else
    echo -e "${YELLOW}Installing Docker Compose...${NC}"
    # Docker Compose is now included with Docker installation as a plugin
    # But let's install the standalone version as well for compatibility
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    log_install_report "Docker Compose" "SUCCESS" "Docker Compose standalone version installed"
    echo -e "${GREEN}✅ Docker Compose installed successfully${NC}"
fi
echo ""

echo -e "${CYAN}[5/12] Python 3 and pip Installation${NC}"
echo "==========================================================="
if command_exists python3; then
    echo -e "${GREEN}Python 3 is already installed${NC}"
    python3 --version
    log_install_report "Python 3" "ALREADY_INSTALLED" "Python 3 was already present"
else
    echo -e "${YELLOW}Installing Python 3...${NC}"
    sudo apt install -y python3 python3-pip python3-venv python3-dev
    log_install_report "Python 3" "SUCCESS" "Python 3 and related packages installed"
    echo -e "${GREEN}✅ Python 3 installed successfully${NC}"
fi

if command_exists pip3; then
    echo -e "${GREEN}pip3 is already installed${NC}"
    pip3 --version
    log_install_report "pip3" "ALREADY_INSTALLED" "pip3 was already present"
else
    echo -e "${YELLOW}Installing pip3...${NC}"
    sudo apt install -y python3-pip
    log_install_report "pip3" "SUCCESS" "pip3 installed"
    echo -e "${GREEN}✅ pip3 installed successfully${NC}"
fi
echo ""

echo -e "${CYAN}[6/12] Node.js and npm Installation${NC}"
echo "==========================================================="
if command_exists node; then
    echo -e "${GREEN}Node.js is already installed${NC}"
    node --version
    log_install_report "Node.js" "ALREADY_INSTALLED" "Node.js was already present"
else
    echo -e "${YELLOW}Installing Node.js and npm...${NC}"
    # Install Node.js LTS via NodeSource repository
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt-get install -y nodejs
    log_install_report "Node.js" "SUCCESS" "Node.js and npm installed via NodeSource"
    echo -e "${GREEN}✅ Node.js installed successfully${NC}"
fi

if command_exists npm; then
    echo -e "${GREEN}npm is already installed${NC}"
    npm --version
    log_install_report "npm" "ALREADY_INSTALLED" "npm was already present"
else
    echo -e "${YELLOW}npm should have been installed with Node.js${NC}"
    log_install_report "npm" "WARNING" "npm not found after Node.js installation"
fi
echo ""

echo -e "${CYAN}[7/12] Go Programming Language Installation${NC}"
echo "==========================================================="
if command_exists go; then
    echo -e "${GREEN}Go is already installed${NC}"
    go version
    log_install_report "Go" "ALREADY_INSTALLED" "Go was already present"
else
    echo -e "${YELLOW}Installing Go...${NC}"
    # Get the latest Go version
    GO_VERSION=$(curl -s https://api.github.com/repos/golang/go/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
    GO_VERSION=${GO_VERSION#go}
    
    # Download and install Go
    wget https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz
    rm go${GO_VERSION}.linux-amd64.tar.gz
    
    # Add Go to PATH
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    echo 'export GOPATH=$HOME/go' >> ~/.bashrc
    echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.bashrc
    
    # Source bashrc to make Go available immediately
    export PATH=$PATH:/usr/local/go/bin
    export GOPATH=$HOME/go
    export PATH=$PATH:$GOPATH/bin
    
    log_install_report "Go" "SUCCESS" "Go ${GO_VERSION} installed and PATH configured"
    echo -e "${GREEN}✅ Go installed successfully${NC}"
fi
echo ""

echo -e "${CYAN}[8/12] NVIDIA Docker Setup${NC}"
echo "==========================================================="
echo -e "${YELLOW}Setting up NVIDIA Container Toolkit for GPU support...${NC}"

# Check if NVIDIA GPU is present
if lspci | grep -i nvidia >/dev/null 2>&1; then
    echo -e "${GREEN}NVIDIA GPU detected${NC}"
    
    # Install NVIDIA drivers if not present
    if ! command_exists nvidia-smi; then
        echo -e "${YELLOW}Installing NVIDIA drivers...${NC}"
        sudo apt install -y nvidia-driver-535 nvidia-utils-535
        echo -e "${YELLOW}⚠️  NVIDIA drivers installed. A reboot may be required.${NC}"
    else
        echo -e "${GREEN}NVIDIA drivers already installed${NC}"
        nvidia-smi --query-gpu=name --format=csv,noheader
    fi
    
    # Install NVIDIA Container Toolkit
    if ! command_exists nvidia-ctk; then
        echo -e "${YELLOW}Installing NVIDIA Container Toolkit...${NC}"
        distribution=$(. /etc/os-release;echo $ID$VERSION_ID) \
            && curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
            && curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
                sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
                sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
        
        sudo apt-get update
        sudo apt-get install -y nvidia-container-toolkit
        
        # Configure Docker to use NVIDIA runtime
        sudo nvidia-ctk runtime configure --runtime=docker
        sudo systemctl restart docker
        
        log_install_report "NVIDIA Docker" "SUCCESS" "NVIDIA Container Toolkit installed and configured"
        echo -e "${GREEN}✅ NVIDIA Container Toolkit installed${NC}"
    else
        echo -e "${GREEN}NVIDIA Container Toolkit already installed${NC}"
        log_install_report "NVIDIA Docker" "ALREADY_INSTALLED" "NVIDIA Container Toolkit was already present"
    fi
else
    echo -e "${YELLOW}⚠️  No NVIDIA GPU detected. Skipping NVIDIA Docker setup.${NC}"
    log_install_report "NVIDIA Docker" "SKIP" "No NVIDIA GPU detected"
fi
echo ""

echo -e "${CYAN}[9/12] Email Configuration (MSMTP)${NC}"
echo "==========================================================="
echo -e "${YELLOW}Setting up email notifications...${NC}"

# Install msmtp
if ! command_exists msmtp; then
    sudo apt install -y msmtp msmtp-mta
    log_install_report "MSMTP" "SUCCESS" "MSMTP installed"
else
    echo -e "${GREEN}MSMTP already installed${NC}"
    log_install_report "MSMTP" "ALREADY_INSTALLED" "MSMTP was already present"
fi

# Configure msmtp
read -p "Do you want to configure email notifications? (y/n): " configure_email
if [[ "$configure_email" =~ ^[Yy]$ ]]; then
    read -p "Enter your email address: " user_email
    read -p "Enter your SMTP server (e.g., smtp.gmail.com): " smtp_server
    read -p "Enter SMTP port (usually 587 for TLS): " smtp_port
    read -s -p "Enter your email password or app password: " email_password
    echo ""
    
    # Create msmtp configuration
    cat > ~/.msmtprc << EOF
# Configuration created by Gensyn Installation Script
# Date: 2025-06-19 13:33:25 UTC
# User: arookiecoder-ip

defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        ~/.msmtp.log

account        default
host           $smtp_server
port           $smtp_port
from           $user_email
user           $user_email
password       $email_password
EOF
    
    chmod 600 ~/.msmtprc
    
    # Test email configuration
    echo "Test email from Gensyn installation script" | msmtp "$user_email" && \
    echo -e "${GREEN}✅ Email configuration successful${NC}" || \
    echo -e "${YELLOW}⚠️  Email test failed. Please check your configuration.${NC}"
    
    log_install_report "Email Config" "SUCCESS" "Email notifications configured for $user_email"
else
    log_install_report "Email Config" "SKIP" "User chose not to configure email"
fi
echo ""

echo -e "${CYAN}[10/12] Gensyn CLI Installation${NC}"
echo "==========================================================="
echo -e "${YELLOW}Installing Gensyn CLI...${NC}"

# Check if gensyn CLI is already installed
if command_exists gensyn; then
    echo -e "${GREEN}Gensyn CLI is already installed${NC}"
    gensyn --version 2>/dev/null || echo "Gensyn CLI present but version check failed"
    log_install_report "Gensyn CLI" "ALREADY_INSTALLED" "Gensyn CLI was already present"
else
    echo -e "${YELLOW}Downloading and installing Gensyn CLI...${NC}"
    # Create installation directory
    mkdir -p ~/gensyn
    cd ~/gensyn
    
    # Download Gensyn CLI (adjust URL as needed)
    # Note: Replace with actual Gensyn CLI download URL when available
    echo -e "${YELLOW}⚠️  Please provide the Gensyn CLI download URL or installation method${NC}"
    read -p "Enter Gensyn CLI download URL (or press Enter to skip): " gensyn_url
    
    if [[ -n "$gensyn_url" ]]; then
        wget "$gensyn_url" -O gensyn-cli.tar.gz
        tar -xzf gensyn-cli.tar.gz
        sudo cp gensyn /usr/local/bin/
        sudo chmod +x /usr/local/bin/gensyn
        log_install_report "Gensyn CLI" "SUCCESS" "Gensyn CLI installed from provided URL"
        echo -e "${GREEN}✅ Gensyn CLI installed${NC}"
    else
        log_install_report "Gensyn CLI" "SKIP" "No download URL provided"
        echo -e "${YELLOW}⚠️  Gensyn CLI installation skipped${NC}"
    fi
    
    cd ~
fi
echo ""

echo -e "\n${CYAN}[11/12] Additional Files Setup${NC}"
echo "==========================================================="

# 1. MSMTP Configuration (Main Directory) - handled in previous step
echo -e "MSMTP configuration handled in previous step."

# 2. Gensyn Crash Script (rl-swarm directory) - Always ask and update
read -p "Enter Gensyn crash script repository URL or Gist URL (or press Enter to skip): " CRASH_SCRIPT_URL
if [[ -n "$CRASH_SCRIPT_URL" ]]; then
    echo -e "${YELLOW}📥 Processing crash script URL...${NC}"
    mkdir -p ~/rl-swarm 2>/dev/null || true
    
    if clone_repository "$CRASH_SCRIPT_URL" ~/rl-swarm; then
        echo -e "${GREEN}✅ Crash script files downloaded successfully${NC}"
        echo -e "${YELLOW}📁 Files in ~/rl-swarm/:${NC}"
        ls -la ~/rl-swarm/ 2>/dev/null || echo "Directory listing failed"
        log_install_report "Gensyn Crash Script" "SUCCESS" "Downloaded/Updated to ~/rl-swarm/"
    else
        echo -e "${RED}❌ Failed to download crash script files${NC}"
        log_install_report "Gensyn Crash Script" "FAILED" "Failed to clone crash script repository"
    fi
else
    log_install_report "Gensyn Crash Script" "SKIP" "No URL provided"
fi

# 3. Swarm PEM File (rl-swarm directory) - Always ask and update
read -p "Enter Swarm PEM file repository URL or Gist URL (or press Enter to skip): " PEM_FILE_URL
if [[ -n "$PEM_FILE_URL" ]]; then
    echo -e "${YELLOW}📥 Processing PEM file URL...${NC}"
    mkdir -p ~/rl-swarm 2>/dev/null || true
    
    if clone_repository "$PEM_FILE_URL" ~/rl-swarm; then
        echo -e "${GREEN}✅ PEM files downloaded successfully${NC}"
        echo -e "${YELLOW}📁 Files in ~/rl-swarm/:${NC}"
        ls -la ~/rl-swarm/ 2>/dev/null || echo "Directory listing failed"
        log_install_report "Swarm PEM File" "SUCCESS" "Downloaded/Updated to ~/rl-swarm/"
    else
        echo -e "${RED}❌ Failed to download PEM files${NC}"
        log_install_report "Swarm PEM File" "FAILED" "Failed to clone PEM file repository"
    fi
else
    log_install_report "Swarm PEM File" "SKIP" "No URL provided"
fi

# 4. Create main execution script
echo -e "${YELLOW}Creating main execution script...${NC}"
cat > ~/.rl-swarm.sh << 'EOF'
#!/bin/bash

# Main RL-Swarm execution script
# This script manages the RL-Swarm mining process

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
SWARM_DIR="$HOME/rl-swarm"
LOG_FILE="$HOME/rl-swarm/swarm.log"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    echo -e "$1"
}

# Function to start RL-Swarm
start_swarm() {
    log_message "${GREEN}Starting RL-Swarm...${NC}"
    cd "$SWARM_DIR"
    
    # Check if crash monitoring script exists
    if [[ -f "run_and_alert.sh" ]]; then
        chmod +x run_and_alert.sh
        ./run_and_alert.sh
    elif [[ -f "crash_monitor.sh" ]]; then
        chmod +x crash_monitor.sh
        ./crash_monitor.sh
    else
        log_message "${YELLOW}No specific crash monitoring script found. Running generic start.${NC}"
        # Add your specific RL-Swarm start command here
        echo "Please configure your RL-Swarm start command"
    fi
}

# Function to stop RL-Swarm
stop_swarm() {
    log_message "${YELLOW}Stopping RL-Swarm...${NC}"
    # Add stop commands as needed
    pkill -f "rl-swarm" 2>/dev/null || true
    log_message "${GREEN}RL-Swarm stopped${NC}"
}

# Function to check status
check_status() {
    if pgrep -f "rl-swarm" >/dev/null; then
        log_message "${GREEN}RL-Swarm is running${NC}"
    else
        log_message "${RED}RL-Swarm is not running${NC}"
    fi
}

# Main execution
case "$1" in
    start)
        start_swarm
        ;;
    stop)
        stop_swarm
        ;;
    status)
        check_status
        ;;
    restart)
        stop_swarm
        sleep 2
        start_swarm
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
EOF

chmod +x ~/.rl-swarm.sh
log_install_report "Main Script" "SUCCESS" "Created ~/.rl-swarm.sh execution script"
echo -e "${GREEN}✅ Main execution script created at ~/.rl-swarm.sh${NC}"
echo ""

echo -e "\n${CYAN}[12/12] Final Verification${NC}"
echo "==========================================================="

# System Information (with timeouts to prevent hanging)
HOSTNAME=$(timeout 3 hostname 2>/dev/null || echo "gcloud")
UPTIME=$(timeout 3 uptime -p 2>/dev/null || echo "System active")
MEMORY=$(timeout 3 free -h 2>/dev/null | awk '/^Mem:/{print $2}' || echo "Unknown")
DISK_USAGE=$(timeout 3 df -h / 2>/dev/null | awk 'NR==2{print $5}' || echo "Unknown")
LOAD_AVERAGE=$(timeout 3 uptime 2>/dev/null | awk -F'load average:' '{print $2}' | xargs || echo "Unknown")

echo -e "${WHITE}System Information:${NC}"
echo -e "  Hostname: $HOSTNAME"
echo -e "  Uptime: $UPTIME"
echo -e "  Memory: $MEMORY"
echo -e "  Disk Usage: $DISK_USAGE"
echo -e "  Load Average: $LOAD_AVERAGE"
echo ""

# Component verification
echo -e "${WHITE}Component Verification:${NC}"

declare -a INSTALLED_COMPONENTS=()
declare -a FAILED_COMPONENTS=()

# Docker verification
echo -n "  Docker: "
if command_exists docker; then
    if timeout 10 sudo docker run --rm hello-world >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Working${NC}"
        INSTALLED_COMPONENTS+=("Docker")
    else
        echo -e "${YELLOW}⚠️  Installed but not working properly${NC}"
        FAILED_COMPONENTS+=("Docker")
    fi
else
    echo -e "${RED}❌ Not installed${NC}"
    FAILED_COMPONENTS+=("Docker")
fi

# Docker Compose verification
echo -n "  Docker Compose: "
if command_exists docker-compose || docker compose version >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Installed${NC}"
    INSTALLED_COMPONENTS+=("Docker Compose")
else
    echo -e "${RED}❌ Not installed${NC}"
    FAILED_COMPONENTS+=("Docker Compose")
fi

# Python verification
echo -n "  Python 3: "
if command_exists python3; then
    PYTHON_VERSION=$(python3 --version 2>&1)
    echo -e "${GREEN}✅ $PYTHON_VERSION${NC}"
    INSTALLED_COMPONENTS+=("Python 3")
else
    echo -e "${RED}❌ Not installed${NC}"
    FAILED_COMPONENTS+=("Python 3")
fi

# pip verification
echo -n "  pip3: "
if command_exists pip3; then
    echo -e "${GREEN}✅ Installed${NC}"
    INSTALLED_COMPONENTS+=("pip3")
else
    echo -e "${RED}❌ Not installed${NC}"
    FAILED_COMPONENTS+=("pip3")
fi

# Node.js verification
echo -n "  Node.js: "
if command_exists node; then
    NODE_VERSION=$(node --version 2>&1)
    echo -e "${GREEN}✅ $NODE_VERSION${NC}"
    INSTALLED_COMPONENTS+=("Node.js")
else
    echo -e "${RED}❌ Not installed${NC}"
    FAILED_COMPONENTS+=("Node.js")
fi

# npm verification
echo -n "  npm: "
if command_exists npm; then
    NPM_VERSION=$(npm --version 2>&1)
    echo -e "${GREEN}✅ $NPM_VERSION${NC}"
    INSTALLED_COMPONENTS+=("npm")
else
    echo -e "${RED}❌ Not installed${NC}"
    FAILED_COMPONENTS+=("npm")
fi

# Go verification
echo -n "  Go: "
if command_exists go; then
    GO_VERSION=$(go version 2>&1)
    echo -e "${GREEN}✅ $GO_VERSION${NC}"
    INSTALLED_COMPONENTS+=("Go")
else
    echo -e "${RED}❌ Not installed${NC}"
    FAILED_COMPONENTS+=("Go")
fi

# Git verification
echo -n "  Git: "
if command_exists git; then
    GIT_VERSION=$(git --version 2>&1)
    echo -e "${GREEN}✅ $GIT_VERSION${NC}"
    INSTALLED_COMPONENTS+=("Git")
else
    echo -e "${RED}❌ Not installed${NC}"
    FAILED_COMPONENTS+=("Git")
fi

# MSMTP verification
echo -n "  MSMTP: "
if command_exists msmtp; then
    if check_file "$HOME/.msmtprc"; then
        echo -e "${GREEN}✅ Installed and configured${NC}"
        INSTALLED_COMPONENTS+=("MSMTP")
    else
        echo -e "${YELLOW}⚠️  Installed but not configured${NC}"
        INSTALLED_COMPONENTS+=("MSMTP")
    fi
else
    echo -e "${RED}❌ Not installed${NC}"
    FAILED_COMPONENTS+=("MSMTP")
fi

# NVIDIA verification
echo -n "  NVIDIA Support: "
if command_exists nvidia-smi; then
    if timeout 5 nvidia-smi >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Available${NC}"
        INSTALLED_COMPONENTS+=("NVIDIA Support")
    else
        echo -e "${YELLOW}⚠️  Drivers installed but not working${NC}"
        FAILED_COMPONENTS+=("NVIDIA Support")
    fi
else
    echo -e "${YELLOW}⚠️  Not available${NC}"
    # Not adding to failed since it's optional
fi

# Gensyn CLI verification
echo -n "  Gensyn CLI: "
if command_exists gensyn; then
    echo -e "${GREEN}✅ Installed${NC}"
    INSTALLED_COMPONENTS+=("Gensyn CLI")
else
    echo -e "${RED}❌ Not installed${NC}"
    FAILED_COMPONENTS+=("Gensyn CLI")
fi

# Additional files verification - Check for crash script files
crash_script_found=false
if check_directory "$HOME/rl-swarm"; then
    # Check if any files were added to rl-swarm directory
    total_files=$(find "$HOME/rl-swarm" -type f 2>/dev/null | wc -l)
    
    # Look for common crash script files
    for file in "run_and_alert.sh" "crash_monitor.sh" "alert.sh" "monitor.sh" "crash.sh" "gensyn_crash.sh"; do
        if check_file "$HOME/rl-swarm/$file"; then
            crash_script_found=true
            break
        fi
    done
    
    # Also check for any .sh files that might be crash scripts
    if [ "$crash_script_found" = false ] && [ "$total_files" -gt 0 ]; then
        if find "$HOME/rl-swarm" -name "*.sh" -type f 2>/dev/null | grep -v "run_rl_swarm.sh" | grep -q .; then
            crash_script_found=true
        fi
    fi
fi

echo -n "  Crash Scripts: "
if [ "$crash_script_found" = true ]; then
    echo -e "${GREEN}✅ Found${NC}"
    INSTALLED_COMPONENTS+=("Crash Scripts")
else
    echo -e "${YELLOW}⚠️  Not found${NC}"
    FAILED_COMPONENTS+=("Crash Scripts")
fi

# Check for PEM files
pem_file_found=false
if check_directory "$HOME/rl-swarm"; then
    if find "$HOME/rl-swarm" -name "*.pem" -type f 2>/dev/null | grep -q .; then
        pem_file_found=true
    fi
fi

echo -n "  PEM Files: "
if [ "$pem_file_found" = true ]; then
    echo -e "${GREEN}✅ Found${NC}"
    INSTALLED_COMPONENTS+=("PEM Files")
else
    echo -e "${YELLOW}⚠️  Not found${NC}"
    FAILED_COMPONENTS+=("PEM Files")
fi

# Main execution script verification
echo -n "  Main Script: "
if check_file "$HOME/.rl-swarm.sh"; then
    echo -e "${GREEN}✅ Created${NC}"
    INSTALLED_COMPONENTS+=("Main Script")
else
    echo -e "${RED}❌ Not created${NC}"
    FAILED_COMPONENTS+=("Main Script")
fi

echo ""

# Service status checks (optional)
echo -e "${WHITE}Service Status:${NC}"
for service in "docker" "ssh"; do
    echo -n "  $service: "
    if check_service "$service"; then
        echo -e "${GREEN}✅ Running${NC}"
    else
        echo -e "${YELLOW}⚠️  Not running or not enabled${NC}"
    fi
done

echo ""

# Calculate success rate
TOTAL_COMPONENTS=$((${#INSTALLED_COMPONENTS[@]} + ${#FAILED_COMPONENTS[@]}))
if [ $TOTAL_COMPONENTS -gt 0 ]; then
    SUCCESS_PERCENTAGE=$(( ${#INSTALLED_COMPONENTS[@]} * 100 / $TOTAL_COMPONENTS ))
else
    SUCCESS_PERCENTAGE=0
fi

echo -e "${WHITE}Installation Summary:${NC}"
echo -e "  Total Components: $TOTAL_COMPONENTS"
echo -e "  Successfully Installed: ${#INSTALLED_COMPONENTS[@]}"
echo -e "  Failed/Missing: ${#FAILED_COMPONENTS[@]}"
echo -e "  Success Rate: $SUCCESS_PERCENTAGE%"

if [ $SUCCESS_PERCENTAGE -ge 80 ]; then
    echo -e "\n${GREEN}🎉 Installation completed successfully!${NC}"
elif [ $SUCCESS_PERCENTAGE -ge 60 ]; then
    echo -e "\n${YELLOW}⚠️  Installation completed with some issues.${NC}"
else
    echo -e "\n${RED}❌ Installation completed with significant issues.${NC}"
fi

# Display failed components if any
if [ ${#FAILED_COMPONENTS[@]} -gt 0 ]; then
    echo -e "\n${RED}Failed/Missing Components:${NC}"
    for component in "${FAILED_COMPONENTS[@]}"; do
        echo -e "  - $component"
    done
fi

echo ""
echo -e "${WHITE}Installation Report:${NC}"
echo "==========================================================="
for report in "${INSTALL_REPORTS[@]}"; do
    echo "$report"
done

echo ""
echo -e "${CYAN}Next Steps:${NC}"
echo "1. Log out and log back in to apply docker group changes"
echo "2. Reboot the system if NVIDIA drivers were installed"
echo "3. Run: ~/.rl-swarm.sh start  # To start the RL-Swarm process"
echo "4. Run: ~/.rl-swarm.sh status # To check the status"
echo "5. Check ~/rl-swarm/ directory for additional configuration files"
echo ""
echo -e "${GREEN}Installation script completed at $(date)${NC}"
echo -e "${YELLOW}Generated on: 2025-06-19 13:33:25 UTC by arookiecoder-ip${NC}"