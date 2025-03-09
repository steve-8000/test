#!/bin/bash

# Function to display the menu
show_menu() {
    echo "===== Installation Menu ====="
    echo "1. Install 0g-storage-node"
    echo "2. Clear cache"
    echo "3. Set Miner Key"
    echo "4. Select RPC Endpoint"
    echo "5. Node Run & Show Logs"
    echo "6. Exit"
    echo "============================"
}

# Function for Option 1: Install 0g-storage-node
install_node() {
    echo "Installing 0g-storage-node..."
    rm -r $HOME/0g-storage-node
    sudo apt-get update
    sudo apt-get install -y cargo git clang cmake build-essential openssl pkg-config libssl-dev
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source $HOME/.cargo/env
    git clone -b v0.8.5 https://github.com/0glabs/0g-storage-node.git
    cd $HOME/0g-storage-node
    git stash
    git fetch --all --tags
    git checkout 898350e
    git submodule update --init
    cargo build --release
    rm -rf $HOME/0g-storage-node/run/config.toml
    curl -o $HOME/0g-storage-node/run/config.toml https://raw.githubusercontent.com/zstake-xyz/test/refs/heads/main/0g_storage_turbo.toml
    nano $HOME/0g-storage-node/run/config.toml

    sudo tee /etc/systemd/system/zgs.service > /dev/null <<EOF
[Unit]
Description=ZGS Node
After=network.target

[Service]
User=$USER
WorkingDirectory=$HOME/0g-storage-node/run
ExecStart=$HOME/0g-storage-node/target/release/zgs_node --config $HOME/0g-storage-node/run/config.toml
Restart=on-failure
RestartSec=10
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable zgs
    echo "Installation completed. You can start the service with 'sudo systemctl start zgs'."
}

# Function for Option 2: Clear cache
clear_cache() {
    echo "Clearing cache..."
    rm -rf /var/log/syslog.1
    sudo sh -c 'echo > /var/log/syslog'
    echo "Cache cleared."
}

# Function for Option 3: Set Miner Key
set_miner_key() {
    echo "Please enter your Miner Key:"
    read miner_key
    sed -i "s|^miner_key = .*|miner_key = \"$miner_key\"|g" ~/0g-storage-node/run/config.toml
    sudo systemctl stop zgs
    sudo systemctl daemon-reload
    sudo systemctl enable zgs
    echo "Miner Key updated. You can start the service with 'sudo systemctl start zgs'."
}

# Function for Option 4: Select RPC Endpoint
select_rpc() {
    echo "Select an RPC Endpoint:"
    echo "1. https://evmrpc-testnet.0g.ai"
    echo "2. https://16600.rpc.thirdweb.com"
    echo "3. https://og-testnet-evm.itrocket.net:443"
    read -p "Enter your choice (1-3): " rpc_choice

    case $rpc_choice in
        1) rpc="https://evmrpc-testnet.0g.ai" ;;
        2) rpc="https://16600.rpc.thirdweb.com" ;;
        3) rpc="https://og-testnet-evm.itrocket.net:443" ;;
        *) echo "Invalid choice. Exiting."; return ;;
    esac

    sed -i "s|^blockchain_rpc_endpoint = .*|blockchain_rpc_endpoint = \"$rpc\"|g" ~/0g-storage-node/run/config.toml
    sudo systemctl stop zgs
    sudo systemctl daemon-reload
    sudo systemctl enable zgs
    echo "RPC Endpoint set to $rpc. You can start the service with 'sudo systemctl start zgs'."
}

# Function for Option 5: Show Logs
show_logs() {
    echo "Displaying logs..."
    sudo systemctl daemon-reload && sudo systemctl enable zgs && sudo systemctl start zgs
    tail -f ~/0g-storage-node/run/log/zgs.log.$(TZ=UTC date +%Y-%m-%d) & 
    source <(curl -s https://raw.githubusercontent.com/zstake-xyz/test/refs/heads/main/zgs_test.sh)
}

# Main loop
while true; do
    show_menu
    read -p "Select an option (1-6): " choice
    case $choice in
        1) install_node ;;
        2) clear_cache ;;
        3) set_miner_key ;;
        4) select_rpc ;;
        5) show_logs ;;
        6) echo "Exiting..."; exit 0 ;;
        *) echo "Invalid option. Please try again." ;;
    esac
    echo ""
done
