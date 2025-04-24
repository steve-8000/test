#!/bin/bash

# Display a prominent message
echo "#######################################################"
echo "#                                                     #"
echo "#    INSTALLING THE SNAPSHOT OF                       #"
echo "#    0G LABS STORAGE NODE - V3                        #"
echo "#                                                     #"
echo "#######################################################"
echo ""

# Navigate to the user's home directory
cd $HOME

# Stop the zgs service
sudo systemctl stop zgs

# Remove the existing snapshot file if it exists
rm -rf $HOME/storage_standard_snapshot.lz4

# Remove the existing db directory if it exists
rm -rf $HOME/0g-storage-node/run/db

# Update package lists
sudo apt update

# Install required tools: tar, lz4, wget, and pv
sudo apt install -y tar lz4 wget pv

# Download the snapshot file to $HOME with progress display
wget -P $HOME http://snapshot.zstake.xyz/downloads/storage_standard_snapshot.lz4

# Extract the snapshot to the target directory with progress visibility
# Create the directory structure if it doesn't exist
mkdir -p $HOME/0g-storage-node/run/db
lz4 -d $HOME/storage_standard_snapshot.lz4 -c | pv | tar -x -C $HOME/0g-storage-node/run/db

# Restart the zgs service
sudo systemctl restart zgs

echo "Snapshot restoration completed."
