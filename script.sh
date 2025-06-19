#!/bin/bash

# Headline
echo -e "\n\e[1;36m===========================================================\e[0m"
echo -e "\e[1;32m                  🚀 GENSYN NODE SETUP 🚀                   \e[0m"
echo -e "\e[1;36m===========================================================\e[0m"
echo ""

# Ask for confirmation to continue
read -p "Do you want to start setting up the Gensyn Node? (y/n): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo -e "\n❌ Setup aborted by user. Exiting..."
    exit 1
fi

# Your full setup script goes below
# (Paste the previous full script here starting from: `sudo apt-get update && sudo apt-get upgrade -y`)


#!/bin/bash

# Update and install essential packages
sudo apt-get update && sudo apt-get upgrade -y
sudo apt install screen curl iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev -y

# Remove old Docker versions
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get remove -y $pkg; done

# Docker installation (first method)
sudo apt install apt-transport-https ca-certificates curl software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io -y
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER

# Fallback Docker installation (if first fails)
sudo apt remove -y docker docker-engine docker.io containerd runc
sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable docker
sudo systemctl start docker
docker --version
sudo docker run hello-world
sudo usermod -aG docker $USER
newgrp docker

# Python installation
sudo apt-get install python3 python3-pip python3-venv python3-dev -y

# Node.js and Yarn
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs
sudo npm install -g yarn
curl -o- -L https://yarnpkg.com/install.sh | bash
export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"
source ~/.bashrc

# Git clone main repo
git clone https://github.com/gensyn-ai/rl-swarm/
chmod +x ~/rl-swarm/run_rl_swarm.sh
chmod +x ~/rl-swarm/run_and_alert.sh

# UFW firewall config
sudo apt install ufw -y
sudo ufw allow 22
sudo ufw allow 3000/tcp

# Cloudflare Tunnel install
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb

# Download config for rl-swarm
curl -o $HOME/rl-swarm/hivemind_exp/configs/mac/grpo-qwen-2.5-0.5b-deepseek-r1.yaml https://raw.githubusercontent.com/arookiecoder-ip/Gensyn-AI-Errors-Solution/main/grpo-qwen-2.5-0.5b-deepseek-r1.yaml
curl -L https://raw.githubusercontent.com/arookiecoder-ip/Gensyn-AI-Node-Monitoring/main/run_rl_swarm.sh -o ~/rl-swarm/run_rl_swarm.sh

# Email and automation tools
sudo apt update
sudo apt install expect msmtp curl -y
chmod 600 ~/.msmtprc

# First Git repo input
read -p "Enter a Git repository URL to clone into the current directory: " GIT_URL_1
if [[ -n "$GIT_URL_1" ]]; then
    git clone "$GIT_URL_1"
    echo "✅ Repository cloned successfully!"
else
    echo "⚠️ No URL provided. Skipping clone."
fi

# Second Git repo input
read -p "Enter another GitHub repository URL to clone: " GIT_URL_2
if [[ -n "$GIT_URL_2" ]]; then
    git clone "$GIT_URL_2"
    echo "✅ Second repository cloned successfully!"
else
    echo "⚠️ No second URL provided. Skipping."
fi

echo -e "\n🎉 All setup steps completed! You can now proceed with your workflow."
