#!/bin/bash

cd
sudo systemctl stop 0gkv
rm -r 0g-storage-kv

echo "Updating system..."
sudo apt update && sudo apt upgrade -y

echo "Cloning repository..."
git clone -b v1.2.2 https://github.com/0glabs/0g-storage-kv.git
cd $HOME/0g-storage-kv

echo "Stashing any local changes..."
git stash

echo "Fetching all tags..."
git fetch --all --tags

echo "Checking out commit 0f1510a..."
git checkout 30d1714

echo "Updating submodules..."
git submodule update --init

echo "Building the project..."
cargo build --release

echo "Removing existing config file..."
rm -rf $HOME/0g-storage-kv/run/config.toml

echo "Downloading new config file..."
curl -o $HOME/0g-storage-kv/run/config.toml https://raw.githubusercontent.com/zstake-xyz/test/main/0g_kv_config.toml

echo "Creating systemd service file..."
sudo tee /etc/systemd/system/0gkv.service > /dev/null <<EOF
[Unit]
Description=0G-KV Node
After=network.target

[Service]
User=root
WorkingDirectory=/root/0g-storage-kv/run
ExecStart=/root/0g-storage-kv/target/release/zgs_kv --config /root/0g-storage-kv/run/config.toml
Restart=always
RestartSec=10
LimitNOFILE=65535
StandardOutput=journal
StandardError=journal
SyslogIdentifier=zgs_kv

[Install]
WantedBy=multi-user.target
EOF

echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

echo "Enabling the service..."
sudo systemctl enable 0gkv

echo "Starting the service..."
sudo systemctl start 0gkv

echo "Tailing the service logs..."
sudo journalctl -u 0gkv -f -o cat
