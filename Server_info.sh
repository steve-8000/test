#!/bin/bash

echo "=== CPU 정보 ==="
lscpu | grep -E 'Model name|Socket|Thread|Core|CPU MHz'

echo ""
echo "=== 메모리 정보 ==="
free -h

echo ""
echo "=== 디스크 정보 ==="
df -h
