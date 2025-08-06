#!/bin/bash

# Prompt user for port number
read -p "Enter the port you want to expose Node Exporter on (default: 9100): " HOST_PORT
HOST_PORT=${HOST_PORT:-9100}  # Set default to 9100 if input is empty

# Define constants
CONTAINER_NAME="node_exporter"
IMAGE_NAME="prom/node-exporter:latest"
CONTAINER_PORT=9100

echo "🔄 Checking if Docker is installed..."
if ! command -v docker &> /dev/null
then
    echo "🚀 Docker is not installed. Installing..."
    sudo apt update
    sudo apt install -y docker.io
    sudo systemctl enable docker
    sudo systemctl start docker
else
    echo "✅ Docker is already installed."
fi

echo "🔄 Removing existing node_exporter container if it exists..."
if [ "$(docker ps -aq -f name=$CONTAINER_NAME)" ]; then
    docker rm -f $CONTAINER_NAME
fi

echo "📦 Pulling the latest node_exporter image..."
docker pull $IMAGE_NAME

echo "🚀 Running the node_exporter container..."
docker run -d \
  --name $CONTAINER_NAME \
  --restart unless-stopped \
  -p $HOST_PORT:$CONTAINER_PORT \
  --net="host" \
  --pid="host" \
  -v "/:/host:ro,rslave" \
  $IMAGE_NAME \
  --path.rootfs=/host

echo "✅ Node Exporter is now running!"
echo "🌐 You can access it at: http://localhost:$HOST_PORT/metrics"
