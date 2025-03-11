#!/bin/bash

# Script to automate the update of 0gchaind on Ubuntu

# Exit on any error
set -e

# Define colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting 0gchaind update process...${NC}"

# Stop the 0gd service
echo "Stopping 0gd service..."
sudo systemctl stop 0gd || {
    echo -e "${RED}Failed to stop 0gd service. Ensure it’s running or check permissions.${NC}"
    exit 1
}

# Navigate to home directory
cd $HOME

# Check if the repository already exists
if [ -d "0g-chain" ]; then
    echo "Repository already exists. Pulling latest changes..."
    cd 0g-chain
    git fetch origin
    git checkout 351c2cb || {
        echo -e "${RED}Failed to checkout commit 351c2cb. Check if the commit exists.${NC}"
        exit 1
    }
    git pull
else
    echo "Cloning 0g-chain repository..."
    git clone https://github.com/0glabs/0g-chain.git || {
        echo -e "${RED}Failed to clone repository. Check network or permissions.${NC}"
        exit 1
    }
    cd 0g-chain
    git checkout 351c2cb || {
        echo -e "${RED}Failed to checkout commit 351c2cb. Check if the commit exists.${NC}"
        exit 1
    }
fi

# Build the binary
echo "Building 0gchaind..."
make install || {
    echo -e "${RED}Failed to build 0gchaind. Ensure dependencies (e.g., Go) are installed.${NC}"
    exit 1
}

# Move the binary to /usr/local/bin
echo "Moving 0gchaind to /usr/local/bin..."
sudo mv $HOME/go/bin/0gchaind /usr/local/bin/0gchaind || {
    echo -e "${RED}Failed to move 0gchaind. Check permissions or disk space.${NC}"
    exit 1
}

# Navigate to the binary directory (optional, since we moved it)
cd $HOME/go/bin
0gchaind --version
# Restart the 0gd service
echo "Restarting 0gd service..."
sudo systemctl restart 0gd || {
    echo -e "${RED}Failed to restart 0gd service. Check service configuration.${NC}"
    exit 1
}
