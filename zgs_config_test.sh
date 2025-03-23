#!/bin/bash

# Function to check if a command exists
command_exists() {
    if ! command -v "$1" &> /dev/null; then
        echo "Error: $1 is not installed or not found in PATH."
        return 1
    fi
    return 0
}

# Function to check if a directory exists
check_directory() {
    if [ ! -d "$1" ]; then
        echo "Error: Directory $1 does not exist."
        return 1
    fi
    return 0
}

# Function to check if a file exists
check_file() {
    if [ ! -f "$1" ]; then
        echo "Error: File $1 does not exist."
        return 1
    fi
    return 0
}

echo "Checking version of 0gchaind..."
if check_directory "$HOME/0gchaind"; then
    cd "$HOME/0gchaind" || exit 1
    if command_exists "0gchaind"; then
        0gchaind version || echo "Error: Failed to get 0gchaind version."
    fi
fi

echo "Checking version for 0g-storage-node..."
if check_directory "$HOME/0g-storage-node"; then
    cd "$HOME/0g-storage-node" || exit 1
    if command_exists "git"; then
        echo "Latest tagged version:"
        git log --decorate=short --oneline | grep "tag: v" | head -n 1 || echo "Error: No tagged version found or git command failed."
        echo "Latest commit:"
        git log -1 --pretty=oneline || echo "Error: Failed to get latest commit."
    fi
fi

echo "Checking version for 0g-storage-client..."
if check_directory "$HOME/0g-storage-client"; then
    cd "$HOME/0g-storage-client" || exit 1
    if command_exists "git"; then
        git log --decorate=short --oneline | grep "tag: v" | head -n 1 || echo "Error: No tagged version found or git command failed."
    fi
fi

echo "Checking version for 0g-da-node..."
if check_directory "$HOME/0g-da-node"; then
    cd "$HOME/0g-da-node" || exit 1
    if command_exists "git"; then
        git log --decorate=short --oneline | grep "tag: v" | head -n 1 || echo "Error: No tagged version found or git command failed."
    fi
fi

echo "Checking version for 0g-da-client..."
if check_directory "$HOME/0g-da-client"; then
    cd "$HOME/0g-da-client" || exit 1
    if command_exists "git"; then
        git log --decorate=short --oneline | grep "tag: v" | head -n 1 || echo "Error: No tagged version found or git command failed."
    fi
fi

echo "Checking version for 0g-storage-kv..."
if check_directory "$HOME/0g-storage-kv"; then
    cd "$HOME/0g-storage-kv" || exit 1
    if command_exists "git"; then
        git log --decorate=short --oneline | grep "tag: v" | head -n 1 || echo "Error: No tagged version found or git command failed."
    fi
fi

# Return to home directory
cd "$HOME" || echo "Error: Could not return to $HOME."

# Define the configuration files
CONFIG_FILE="$HOME/0g-storage-node/run/config.toml"
TESTNET_CONFIG_FILE="$HOME/0g-storage-node/run/config-testnet-turbo.toml"

# Define the pattern to search for
PATTERN="^(network_boot_nodes|network_dir|network_enr_address|network_enr_tcp_port|network_enr_udp_port|network_libp2p_port|network_discovery_port|rpc_listen_address|rpc_enabled|db_dir|log_config_file|log_contract_address|mine_contract_address|reward_contract_address|log_sync_start_block_number|blockchain_rpc_endpoint|auto_sync_enabled|find_peer_timeout)"

# Print progress and extract configuration parameters
echo "Starting to extract configuration parameters from $CONFIG_FILE"
if check_file "$CONFIG_FILE"; then
    grep -E "$PATTERN" "$CONFIG_FILE" || echo "Error: Failed to extract parameters from $CONFIG_FILE."
    echo "Finished extracting from $CONFIG_FILE"
else
    echo "Skipping extraction from $CONFIG_FILE due to error."
fi

echo "Starting to extract configuration parameters from $TESTNET_CONFIG_FILE"
if check_file "$TESTNET_CONFIG_FILE"; then
    grep -E "$PATTERN" "$TESTNET_CONFIG_FILE" || echo "Error: Failed to extract parameters from $TESTNET_CONFIG_FILE."
    echo "Finished extracting from $TESTNET_CONFIG_FILE"
else
    echo "Skipping extraction from $TESTNET_CONFIG_FILE due to error."
fi
