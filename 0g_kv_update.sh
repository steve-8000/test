#!/bin/bash

# Stop the 0gkv service
echo "Stopping 0gkv service..."
sudo systemctl stop 0gkv

# Backup the config file
echo "Backing up config.toml..."
cp $HOME/0g-storage-kv/run/config.toml $HOME/config.toml.backup

# Remove the old directory
echo "Removing old 0g-storage-kv directory..."
rm -r $HOME/0g-storage-kv

# Clone the repository
echo "Cloning 0g-storage-kv repository..."
git clone -b v1.2.2 https://github.com/0glabs/0g-storage-kv.git

# Change to the repository directory
cd $HOME/0g-storage-kv

# Stash any local changes
echo "Stashing local changes..."
git stash

# Fetch all tags
echo "Fetching all tags..."
git fetch --all --tags

# Checkout the specific commit
echo "Checking out commit f11f432..."
git checkout bf66c78

# Update submodules
echo "Updating submodules..."
git submodule update --init

# Build the project
echo "Building the project..."
cargo build --release

# Restore the config file
echo "Restoring config.toml..."
mv $HOME/config.toml.backup $HOME/0g-storage-kv/run/config.toml

# Reload the systemd daemon
echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

# Enable and start the 0gkv service
echo "Enabling and starting 0gkv service..."
sudo systemctl enable 0gkv
sudo systemctl start 0gkv

# Follow the service logs
echo "Following 0gkv service logs..."
sudo journalctl -u 0gkv -f -o cat
