#!/bin/bash

while true; do 
  local_height=$(0gchaind status | jq -r .sync_info.latest_block_height)
  response=$(curl -s -X POST https://evmrpc-testnet.0g.ai \
    -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}')
    hex_height=$(echo "$response" | jq -r '.result') 
  network_height=$((hex_height))  
  blocks_left=$((network_height - local_height))
  echo -e "\033[1;38mYour node height:\033[0m \033[1;34m$local_height\033[0m | \033[1;35mNetwork height:\033[0m \033[1;36m$network_height\033[0m | \033[1;29mBlocks left:\033[0m \033[1;31m$blocks_left\033[0m"

  sleep 5
done
