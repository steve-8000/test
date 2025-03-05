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
git checkout 898350e271f917d1a6e8abf9396f3d98e8bebe1d

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
tail -f ~/0g-storage-node/run/log/zgs.log.$(TZ=UTC date +%Y-%m-%d)

