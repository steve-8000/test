#!/bin/bash

echo "=== CPU info ==="
lscpu | grep -E 'Model name|Socket|Thread|Core|CPU MHz'

echo ""
echo "=== Memory info ==="
free -h

echo ""
echo "=== Disk info ==="
df -h
