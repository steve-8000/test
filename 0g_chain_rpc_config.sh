#!/bin/bash

echo "Updating pruning settings..."
sed -i -e "s/^pruning *=.*/pruning = \"custom\"/" $HOME/.0gchain/config/app.toml
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"100\"/" $HOME/.0gchain/config/app.toml
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"50\"/" $HOME/.0gchain/config/app.toml
echo "Pruning settings updated."

echo "Updating minimum gas prices..."
sed -i 's|minimum-gas-prices =.*|minimum-gas-prices = "0.00025ua0gi"|g' $HOME/.0gchain/config/app.toml
echo "Minimum gas prices updated."

echo "Updating indexer settings..."
sed -i -e "s/^indexer *=.*/indexer = \"kv\"/" $HOME/.0gchain/config/config.toml
echo "Indexer settings updated."

echo "Fetching active peers..."
PEERS=$(curl -s -X POST https://0gchain.josephtran.xyz -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"net_info","params":[],"id":1}' | jq -r '.result.peers[] | select(.connection_status.SendMonitor.Active == true) | "\(.node_info.id)@\(if .node_info.listen_addr | contains("0.0.0.0") then .remote_ip + ":" + (.node_info.listen_addr | sub("tcp://0.0.0.0:"; "")) else .node_info.listen_addr | sub("tcp://"; "") end)"' | tr '\n' ',' | sed 's/,$//' | awk '{print "\"" $0 "\""}')
echo "Active peers fetched."

echo "Updating persistent peers..."
sed -i "s/^persistent_peers *=.*/persistent_peers = $PEERS/" "$HOME/.0gchain/config/config.toml"
if [ $? -eq 0 ]; then
    echo "Configuration file updated successfully with new peers."
else
    echo "Failed to update configuration file."
    exit 1
fi

echo "Restarting 0gd service..."
sudo systemctl stop 0gd
sudo systemctl daemon-reload
sudo systemctl enable 0gd
sudo systemctl start 0gd
