#!/bin/bash

echo ""
echo "🛰️  BANGCODE Block Checker | Support by Maouam's Node Lab Team"
echo "================================================================"
echo ""

# Show node version
if [ -d "$HOME/0g-storage-node" ]; then
    cd "$HOME/0g-storage-node"
    VERSION=$(git describe --tags --abbrev=0 2>/dev/null)
    echo -e "📦 Node Version: \033[1;32m${VERSION:-Unknown}\033[0m"
else
    echo -e "📦 Node Version: \033[1;31mNot Found\033[0m"
fi

# Extract RPC URL from config.toml
CONFIG_RPC=$(grep 'blockchain_rpc_endpoint' ~/0g-storage-node/run/config.toml | cut -d '"' -f2)
echo -e "🔗 Your RPC in config.toml: \033[1;34m$CONFIG_RPC\033[0m"
echo ""

prev_block=""
prev_time=""
while true; do 
    LOCAL_RESPONSE=$(curl -s -X POST http://127.0.0.1:5678 -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"zgs_getStatus","params":[],"id":1}')
    logSyncHeight=$(echo "$LOCAL_RESPONSE" | jq '.result.logSyncHeight' 2>/dev/null)
    connectedPeers=$(echo "$LOCAL_RESPONSE" | jq '.result.connectedPeers' 2>/dev/null)

    NETWORK_RESPONSE=$(curl -s -m 5 -X POST "$CONFIG_RPC" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}')
    latestBlockHex=$(echo "$NETWORK_RESPONSE" | jq -r '.result' 2>/dev/null)

    # Validate and sanitize values
    [[ "$logSyncHeight" =~ ^[0-9]+$ ]] || logSyncHeight=0
    [[ "$connectedPeers" =~ ^[0-9]+$ ]] || connectedPeers=0
    latestBlock=$((16#${latestBlockHex:2}))

    block_diff=$((latestBlock - logSyncHeight))
    current_time=$(date +%s)
    bps="N/A"
    eta_display="N/A"

    if [[ "$prev_block" =~ ^[0-9]+$ && "$prev_time" =~ ^[0-9]+$ && "$logSyncHeight" -gt "$prev_block" ]]; then
        delta_block=$((logSyncHeight - prev_block))
        delta_time=$((current_time - prev_time))

        if (( delta_time > 0 )); then
            bps=$(echo "scale=2; $delta_block / $delta_time" | bc)
            if (( $(echo "$bps > 0" | bc -l) )); then
                eta_sec=$(echo "$block_diff / $bps" | bc)
                if (( eta_sec < 60 )); then
                    eta_display="$eta_sec sec"
                elif (( eta_sec < 3600 )); then
                    eta_display="$((eta_sec / 60)) min"
                elif (( eta_sec < 86400 )); then
                    eta_display="$((eta_sec / 3600)) hr"
                else
                    eta_display="$((eta_sec / 86400)) day(s)"
                fi
            fi
        fi
    fi

    prev_block=$logSyncHeight
    prev_time=$current_time

    # Color indicator
    if (( block_diff <= 5 )); then
        diff_color="\033[32m"
    elif (( block_diff <= 20 )); then
        diff_color="\033[33m"
    else
        diff_color="\033[31m"
    fi

    printf "Local Block: \033[32m%-7s\033[0m | Network Block: \033[33m%-7s\033[0m %b(Behind %s)\033[0m | Peers: \033[34m%-3s\033[0m" \
        "$logSyncHeight" "$latestBlock" "$diff_color" "$block_diff" "$connectedPeers"

    printf "  ||  Speed: \033[36m%-6s blocks/s\033[0m | ETA: \033[35m%s\033[0m\n" "$bps" "$eta_display"

    sleep 1
done
