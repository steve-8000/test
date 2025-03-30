#!/bin/bash

echo "#######################################################"
echo "#                                                     #"
echo "#    INSTALLING THE SNAPSHOT OF                       #"
echo "#    0G LABS STORAGE NODE - TURBO CONTRACT        #"
echo "#                                                     #"
echo "#######################################################"
echo ""

cd $HOME
sudo systemctl stop zgs
rm -rf $HOME/storage_turbo_snapshot.lz4
rm -rf $HOME/0g-storage-node/run/db
sudo apt update
sudo apt install -y tar lz4 wget pv
wget -P $HOME http://snapshot_v1.zstake.xyz/downloads/storage_turbo_snapshot.lz4
mkdir -p $HOME/0g-storage-node/run/db
lz4 -d $HOME/storage_turbo_snapshot.lz4 -c | pv | tar -x -C $HOME/0g-storage-node/run/db
sudo systemctl restart zgs

echo "Snapshot restoration completed."
