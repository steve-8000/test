#!/bin/bash

echo "Stopping 0G-DA service..."
sudo systemctl stop 0gda

echo "Backing up existing configuration..."
cp $HOME/0g-da-node/config.toml $HOME/da_config.toml.backup

echo "Navigating to the 0G-DA node directory..."
cd $HOME/0g-da-node

echo "Stashing any local changes..."
git stash

echo "Fetching all tags..."
git fetch --all --tags

echo "Checking out specific commit..."
git checkout f6f2e3e

echo "Updating submodules..."
git submodule update --init

echo "Building the project..."
cargo build --release

echo "Restoring configuration backup..."
mv $HOME/da_config.toml.backup $HOME/0g-da-node/config.toml

echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

echo "Enabling the 0G-DA service..."
sudo systemctl enable 0gda

echo "Starting the 0G-DA service..."
sudo systemctl start 0gda

echo "Tailing the service logs..."
sudo journalctl -u 0gda -f -o cat
