#!/bin/bash

echo "Changing to home directory..."
cd $HOME

echo "Removing old 0g-chain directory..."
rm -rf 0g-chain

echo "Downloading the latest 0gchaind binary..."
wget -O 0gchaind https://github.com/0glabs/0g-chain/releases/download/v0.4.0/0gchaind-linux-v0.4.0

echo "Making the binary executable..."
chmod +x $HOME/0gchaind

echo "Moving the binary to the appropriate location..."
sudo mv $HOME/0gchaind $(which 0gchaind)

echo "Fetching active peers..."
PEERS=$(curl -s -X POST https://0gchain.josephtran.xyz -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"net_info","params":[],"id":1}' | jq -r '.result.peers[] | select(.connection_status.SendMonitor.Active == true) | "\(.node_info.id)@\(if .node_info.listen_addr | contains("0.0.0.0") then .remote_ip + ":" + (.node_info.listen_addr | sub("tcp://0.0.0.0:"; "")) else .node_info.listen_addr | sub("tcp://"; "") end)"' | tr '\n' ',' | sed 's/,$//' | awk '{print "\"" $0 "\""}')

echo "Updating configuration file with new peers..."
sed -i "s/^persistent_peers *=.*/persistent_peers = $PEERS/" "$HOME/.0gchain/config/config.toml"

if [ $? -eq 0 ]; then
    echo "Configuration file updated successfully with new peers."
else
    echo "Failed to update configuration file."
    exit 1
fi

echo "Stopping 0gd service..."
sudo systemctl stop 0gd

echo "Reloading systemd manager configuration..."
sudo systemctl daemon-reload

echo "Enabling 0gd service to start on boot..."
sudo systemctl enable 0gd

echo "Starting 0gd service..."
sudo systemctl start 0gd

echo "Script execution completed."
