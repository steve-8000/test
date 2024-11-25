#!/bin/bash

# Stop the zgs service
sudo systemctl stop zgs

# Backup the current config file
cp $HOME/0g-storage-node/run/config.toml $HOME/0g-storage-node/run/config.toml.backup

# Navigate to the project directory
cd $HOME/0g-storage-node

# Stash any local changes
git stash

# Fetch all updates and tags
git fetch --all --tags

# Checkout the specific commit
git checkout 27366a5

# Update submodules
git submodule update --init

# Build the project
cargo build --release

# Restore the config file
cp $HOME/0g-storage-node/run/config.toml.backup $HOME/0g-storage-node/run/config.toml

# Reload the systemd manager configuration
sudo systemctl daemon-reload

# Enable and start the zgs service
sudo systemctl enable zgs
sudo systemctl start zgs

# Monitor the service status
while true; do
    response=$(curl -s -X POST http://localhost:5678 -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"zgs_getStatus","params":[],"id":1}')
    logSyncHeight=$(echo $response | jq '.result.logSyncHeight')
    connectedPeers=$(echo $response | jq '.result.connectedPeers')
    echo -e "logSyncHeight: \033[32m$logSyncHeight\033[0m, connectedPeers: \033[34m$connectedPeers\033[0m"
    sleep 5
done
