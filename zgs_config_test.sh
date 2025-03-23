#!/bin/bash
echo "Checking version of 0gchaind..."
cd $HOME/0gchaind
0gchaind version

echo "Checking version for 0g-storage-node..."
cd $HOME/0g-storage-node
git log --decorate=short --oneline | grep "tag: v" | head -n 1

echo "Checking version for 0g-storage-client..."
cd $HOME/0g-storage-client
git log --decorate=short --oneline | grep "tag: v" | head -n 1

echo "Checking version for 0g-da-node..."
cd $HOME/0g-da-node
git log --decorate=short --oneline | grep "tag: v" | head -n 1

echo "Checking version for 0g-da-client..."
cd $HOME/0g-da-client
git log --decorate=short --oneline | grep "tag: v" | head -n 1

echo "Checking version for 0g-storage-kv..."
cd $HOME/0g-storage-kv
git log --decorate=short --oneline | grep "tag: v" | head -n 1
cd

# Define the configuration files
CONFIG_FILE="$HOME/0g-storage-node/run/config.toml"
TESTNET_CONFIG_FILE="$HOME/0g-storage-node/run/config-testnet-turbo.toml"

# Define the pattern to search for
PATTERN="^(network_boot_nodes|network_dir|network_enr_address|network_enr_tcp_port|network_enr_udp_port|network_libp2p_port|network_discovery_port|rpc_listen_address|rpc_enabled|db_dir|log_config_file|log_contract_address|mine_contract_address|reward_contract_address|log_sync_start_block_number|blockchain_rpc_endpoint|auto_sync_enabled|find_peer_timeout)"

# Print progress
echo "Starting to extract configuration parameters from $CONFIG_FILE"
grep -E "$PATTERN" "$CONFIG_FILE"
echo "Finished extracting from $CONFIG_FILE"

echo "Starting to extract configuration parameters from $TESTNET_CONFIG_FILE"
grep -E "$PATTERN" "$TESTNET_CONFIG_FILE"
echo "Finished extracting from $TESTNET_CONFIG_FILE"
