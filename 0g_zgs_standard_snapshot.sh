#!/bin/bash

# Install necessary packages
echo "Installing necessary packages..."
cd && rm -rf $HOME/storage_0gchain_snapshot.lz4 && sudo apt-get install wget lz4 aria2 pv -y
# Download the snapshot with aria2
echo "Downloading the snapshot..."
aria2c -x 16 -s 16 http://snapshot_2.zstake.xyz/downloads/storage_0gchain_snapshot.lz4

# Stop the zgs service
echo "Stopping the zgs service..."
sudo systemctl stop zgs

# Remove old data
echo "Removing old data..."
rm -r $HOME/0g-storage-node/run/db
rm -r $HOME/0g-storage-node/run/log
rm -r $HOME/0g-storage-node/run/network

# Extract the new snapshot
echo "Extracting the new snapshot..."
lz4 -c -d storage_0gchain_snapshot.lz4 | pv | tar -x -C $HOME/0g-storage-node/run

echo "Process completed successfully!"
