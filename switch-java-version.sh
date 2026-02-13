#!/bin/bash
# Switch to a specific Java version
# Usage: switch-java-version.sh <version>
# Example: switch-java-version.sh 17

set -e

REQUESTED_VERSION=$1

if [ -z "$REQUESTED_VERSION" ]; then
    echo "Error: Java version not specified"
    echo "Usage: switch-java-version.sh <8|11|17|21>"
    exit 1
fi

# Normalize version: extract major version number
# Handles formats like "17", "17.0.1", "1.8", "1.8.0_292"
# Using sed for BusyBox compatibility
if echo "$REQUESTED_VERSION" | grep -q '^1\.[0-9]'; then
    # Legacy format (1.8, 1.8.0_292) -> extract minor as major
    REQUESTED_VERSION=$(echo "$REQUESTED_VERSION" | sed 's/^1\.\([0-9]*\).*/\1/')
else
    # Modern format (11, 17.0.1, 21) -> extract first number
    REQUESTED_VERSION=$(echo "$REQUESTED_VERSION" | sed 's/^\([0-9]*\).*/\1/')
fi

# Map to available versions (8, 11, 17, 21 are installed)
case "$REQUESTED_VERSION" in
    8)
        JAVA_VERSION=8
        ;;
    9|10|11)
        JAVA_VERSION=11
        ;;
    12|13|14|15|16|17)
        JAVA_VERSION=17
        ;;
    18|19|20|21)
        JAVA_VERSION=21
        ;;
    *)
        echo "Warning: Unsupported Java version $REQUESTED_VERSION, defaulting to Java 21"
        JAVA_VERSION=21
        ;;
esac

# Set JAVA_HOME based on version
case "$JAVA_VERSION" in
    8)
        export JAVA_HOME=/usr/lib/jvm/java-8-openjdk
        ;;
    11)
        export JAVA_HOME=/usr/lib/jvm/java-11-openjdk
        ;;
    17)
        export JAVA_HOME=/usr/lib/jvm/java-17-openjdk
        ;;
    21)
        export JAVA_HOME=/usr/lib/jvm/java-21-openjdk
        ;;
esac

# Update PATH
export PATH="$JAVA_HOME/bin:$PATH"

# Verify Java version
if [ -x "$JAVA_HOME/bin/java" ]; then
    # Output status to stderr so it doesn't interfere with eval
    echo "✓ Switched to Java $JAVA_VERSION" >&2
    echo "  JAVA_HOME: $JAVA_HOME" >&2
    java -version 2>&1 | head -1 >&2
else
    echo "Error: Java $JAVA_VERSION not found at $JAVA_HOME" >&2
    exit 1
fi

# Export for current shell and subprocesses (stdout only for eval)
echo "export JAVA_HOME=$JAVA_HOME"
echo "export PATH=$JAVA_HOME/bin:\$PATH"
