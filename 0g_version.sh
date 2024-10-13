#!/bin/bash

echo "Checking version of 0gchaind..."
cd $HOME/0gchaind
0gchaind version

echo "Checking version for 0g-storage-node..."
cd $HOME/0g-storage-node
git log --decorate=short --oneline | grep "tag: v" | head -n 1

echo "Checking version for 0g-storage-client..."
cd $HOME/0g-storage-client
git log --decorate=short --oneline | grep "tag: v" | head -n 1

echo "Checking version for 0g-da-node..."
cd $HOME/0g-da-node
git log --decorate=short --oneline | grep "tag: v" | head -n 1

echo "Checking version for 0g-da-client..."
cd $HOME/0g-da-client
git log --decorate=short --oneline | grep "tag: v" | head -n 1

echo "Checking version for 0g-storage-kv..."
cd $HOME/0g-storage-kv
git log --decorate=short --oneline | grep "tag: v" | head -n 1
cd
