#!/bin/bash

# Combined log monitoring script
tail -f ~/0g-storage-node/run/log/zgs.log.$(TZ=UTC date +%Y-%m-%d) | grep -E "sync to block number|connected=" | awk '{print "[Storage Node] " $0}' &
sudo journalctl -u 0gda -f -o cat | grep -E "entrance|responsed in" | awk '{print "[DA Node] " $0}' &
tail -f ~/0g-da-client/run/run.log | grep "number" | awk '{print "[DA Client] " $0}' &

wait
