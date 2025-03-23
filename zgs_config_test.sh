#!/bin/bash

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
