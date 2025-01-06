#!/bin/bash

# Install necessary packages
echo "Installing necessary packages..."
cd && rm -rf $HOME/storage_0gchain_snapshot.lz4 && sudo apt-get install wget lz4 aria2 pv -y

# Prompt user for snapshot selection
echo "Please select the snapshot to download:"
echo "1) Server 1 : Standard Storage Contract Snapshot"
echo "2) Server 2 : Standard Storage Contract Snapshot"
read -p "Enter the number (1 or 2): " snapshot_choice

# Set the URL based on user input
case $snapshot_choice in
  1)
    snapshot_url="http://snapshot_2.zstake.xyz/downloads/storage_0gchain_snapshot.lz4"
    ;;
  2)
    snapshot_url="http://snapshot_2.zstake.xyz/downloads/storage_0gchain_snapshot.lz4"
    ;;
  *)
    echo "Invalid choice. Exiting."
    exit 1
    ;;
esac

# Download the selected snapshot with aria2
echo "Downloading the snapshot..."
aria2c -x 16 -s 16 $snapshot_url

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
lz4 -c -d storage_0gchain_snapshot
