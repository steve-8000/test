#!/bin/bash

# 명령어 배열
commands=(
    "sudo journalctl -u 0gda -f -o cat | grep -E 'success|block..'"
    "tail -f ~/0g-storage-node/run/log/zgs.log.\$(TZ=UTC date +%Y-%m-%d) | grep 'sync to block number'"
    "tail -f ~/0g-storage-node/run/log/zgs.log.\$(TZ=UTC date +%Y-%m-%d) | grep 'connected=responsed in'"
    "tail -f ~/0g-da-client/run/run.log | grep 'number'"
)

# 무한 루프
while true; do
    for cmd in "${commands[@]}"; do
        echo "실행 중: $cmd"
        eval $cmd &
        sleep 2
        pkill -P $$
    done
done

