#!/bin/bash
set -e

# Start Docker daemon
/usr/local/bin/start-dockerd.sh

# Detect and switch to required Java version
echo ""
echo "=== Detecting Required Java Version ==="
WORKDIR=${WORKDIR:-/workspace}
DETECTED_JAVA_VERSION=$(/usr/local/bin/detect-java-version.sh "$WORKDIR")
echo "Detected Java version: $DETECTED_JAVA_VERSION"

# Switch to the detected Java version
eval "$(/usr/local/bin/switch-java-version.sh "$DETECTED_JAVA_VERSION")"

echo ""

# Pre-pull images if specified
if [ -n "$PREPULL_IMAGES" ]; then
    echo ""
    echo "=== Pre-pulling Docker images ==="
    IFS=',' read -ra IMAGES <<< "$PREPULL_IMAGES"
    for IMAGE in "${IMAGES[@]}"; do
        IMAGE=$(echo "$IMAGE" | xargs)  # Trim whitespace
        echo "Pulling $IMAGE with platform linux/amd64..."
        docker pull --platform linux/amd64 "$IMAGE" || {
            echo "Warning: Failed to pull $IMAGE, continuing..."
        }
    done
    echo "✓ Pre-pull complete"
fi

# Display environment info if DEBUG is enabled
if [ "$DEBUG" = "true" ]; then
    echo ""
    echo "=== Environment Information ==="
    echo "DOCKER_HOST: $DOCKER_HOST"
    echo "DOCKER_DEFAULT_PLATFORM: $DOCKER_DEFAULT_PLATFORM"
    echo "TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE: $TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE"
    echo "WORKDIR: ${WORKDIR:-/workspace}"
    echo "MAVEN_OPTS: $MAVEN_OPTS"
    echo "NODE_OPTIONS: $NODE_OPTIONS"

    echo ""
    echo "=== Runtime Versions ==="
    java -version 2>&1 | head -n 1
    mvn --version | head -n 1
    node --version
    npm --version
    python --version
    echo ""
fi

# Change to working directory
WORKDIR=${WORKDIR:-/workspace}
if [ -d "$WORKDIR" ]; then
    cd "$WORKDIR"
    echo "Working directory: $(pwd)"
else
    echo "Warning: Working directory $WORKDIR does not exist, staying in $(pwd)"
fi

# Execute the command passed as arguments
echo ""
echo "=== Executing Command ==="
echo "Command: $@"
echo ""

# Execute the command and capture exit code
set +e
"$@"
EXIT_CODE=$?
set -e

# Cleanup containers (but not images - they're in the persistent volume)
if [ "$EXIT_CODE" -eq 0 ]; then
    echo ""
    echo "=== Command completed successfully (exit code: $EXIT_CODE) ==="
else
    echo ""
    echo "=== Command failed with exit code: $EXIT_CODE ==="
fi

# Optional: Clean up running containers
if [ "$CLEANUP_CONTAINERS" = "true" ]; then
    echo ""
    echo "=== Cleaning up containers ==="
    docker ps -q | xargs -r docker stop || true
    docker ps -aq | xargs -r docker rm || true
    echo "✓ Cleanup complete"
fi

exit $EXIT_CODE
