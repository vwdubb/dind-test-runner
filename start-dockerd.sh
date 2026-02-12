#!/bin/bash
set -e

echo "=== Starting Docker-in-Docker Daemon ==="

# Check if Docker daemon is already running
if docker info > /dev/null 2>&1; then
    echo "Docker daemon is already running"
    docker version
    exit 0
fi

# Docker Desktop on ARM already has QEMU support built-in
# We just need to make sure containers specify --platform linux/amd64 when needed
echo "Note: Using Docker Desktop's built-in QEMU support for x86_64 containers"

# Start Docker daemon in background
# Note: storage-driver and data-root are configured in /etc/docker/daemon.json
echo "Starting Docker daemon..."
dockerd \
  --host=unix:///var/run/docker.sock \
  --host=tcp://0.0.0.0:2375 \
  > /var/log/dockerd.log 2>&1 &

DOCKERD_PID=$!
echo "Docker daemon started with PID: $DOCKERD_PID"

# Wait for Docker daemon to be ready (120 second timeout)
echo "Waiting for Docker daemon to be ready..."
TIMEOUT=120
ELAPSED=0

while [ $ELAPSED -lt $TIMEOUT ]; do
    if docker info > /dev/null 2>&1; then
        echo "✓ Docker daemon is ready!"
        break
    fi
    sleep 1
    ELAPSED=$((ELAPSED + 1))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "✗ Docker daemon failed to start within ${TIMEOUT} seconds"
    echo "=== Docker daemon logs ==="
    cat /var/log/dockerd.log
    exit 1
fi

# Display Docker version and info
echo ""
echo "=== Docker Version ==="
docker version

echo ""
echo "=== Docker Info ==="
docker info | grep -E "Operating System|Architecture|Server Version|Storage Driver|Default Platform" || docker info

# x86_64 emulation is handled by Docker Desktop
echo ""
echo "✓ Docker daemon ready (x86_64 support via Docker Desktop)"

# Display disk usage
echo ""
echo "=== Docker Disk Usage ==="
docker system df || echo "Could not get disk usage"

echo ""
echo "=== Docker daemon fully initialized and ready ==="
