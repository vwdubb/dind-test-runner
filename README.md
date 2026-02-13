# DinD Test Runner

A Docker-in-Docker (DinD) test environment for running integration tests that require Docker containers. Provides isolated, reproducible test environments with automatic Java version detection and persistent build caches.

## TLDR

Run integration tests with Docker containers in an isolated environment without polluting your host Docker setup.

**Quick Start:**
```bash
# Pull the pre-built image
docker pull vwdubb/dind-test-runner:latest

# Run your tests (from your project directory)
docker run --rm --privileged -t \
  -v "$(pwd):/workspace:cached" \
  -v dind-maven-cache:/root/.m2/repository \
  -v dind-docker-images:/var/lib/docker \
  vwdubb/dind-test-runner:latest \
  mvn test

# Or use the dind-test wrapper script (after installing)
dind-test run mvn test
```

**Key Features:** Auto-detects Java versions (8/11/17/21), supports multi-module Maven projects, works with Testcontainers, persistent caches for faster builds, cross-platform (ARM/x86_64).

## Features

- **Docker-in-Docker**: Run Docker containers within your tests without polluting your host Docker environment
- **Multi-Java Support**: Automatically detects and switches between Java 8, 11, 17, and 21
- **Multi-Module Projects**: Intelligently handles Maven multi-module projects with different Java versions
- **Persistent Caches**: Speeds up builds with persistent Maven, npm, pip, and Gradle caches
- **Cross-Platform**: Works on both ARM (Apple Silicon) and x86_64 architectures
- **Build Tool Support**: Maven, Gradle, npm, yarn, pytest, and more
- **Testcontainers Compatible**: Full support for Testcontainers framework
- **Image Pre-pulling**: Pre-pull Docker images to speed up test execution

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Java Version Detection](#java-version-detection)
- [Commands Reference](#commands-reference)
- [Usage Examples](#usage-examples)
- [Multi-Module Projects](#multi-module-projects)
- [Configuration](#configuration)
- [Architecture](#architecture)
- [Troubleshooting](#troubleshooting)

## Installation

You can either use the pre-built Docker image or build it yourself.

### Option 1: Use Pre-built Image (Recommended)

The image is available on Docker Hub at `vwdubb/dind-test-runner:latest`.

```bash
# Pull the image
docker pull vwdubb/dind-test-runner:latest

# Run tests directly
docker run --rm --privileged -t \
  -v "$(pwd):/workspace:cached" \
  -v "$HOME/.m2/settings.xml:/root/.m2/settings.xml:ro" \
  -v dind-maven-cache:/root/.m2/repository \
  -v dind-docker-images:/var/lib/docker \
  vwdubb/dind-test-runner:latest \
  mvn test
```

See [Using Docker Directly](#using-docker-directly-without-dind-test-script) for more usage examples.

### Option 2: Build from Source

#### 1. Clone or Copy Files

Copy the dind-test-runner directory to a location on your system:

```bash
# Example: Copy to ~/.docker/dind-test-runner
cp -r dind-test-runner ~/.docker/
```

#### 2. Add to PATH

Add the dind-test script to your PATH for easy access:

```bash
# Option 1: Create symlink in /usr/local/bin
sudo ln -s ~/.docker/dind-test-runner/dind-test /usr/local/bin/dind-test

# Option 2: Add to PATH in your shell profile (~/.bashrc, ~/.zshrc)
export PATH="$HOME/.docker/dind-test-runner:$PATH"
```

#### 3. Initialize

Build the Docker image:

```bash
dind-test init
```

This will build the image with all Java versions (8, 11, 17, 21) and build tools pre-installed.

**Note:** If you want to use the pre-built image instead of building locally, you can skip the `dind-test init` step and pull from Docker Hub as shown in Option 1.

## Quick Start

```bash
# Navigate to your project directory
cd /path/to/your/project

# Run tests (Java version auto-detected)
dind-test run mvn test

# Run with specific test class
dind-test run mvn test -Dtest=MyIntegrationTest

# Run npm tests
dind-test run npm test

# Run pytest
dind-test run pytest tests/

# Open interactive shell for debugging
dind-test shell
```

## Java Version Detection

The test runner automatically detects the required Java version from your project configuration.

### Detection Priority (highest to lowest)

1. **Environment Variable**: `JAVA_VERSION` environment variable
2. **`.java-version` File**: Project root `.java-version` file
3. **Maven `pom.xml`**: `<java.version>`, `<maven.compiler.source>`, or `<maven.compiler.target>`
4. **Gradle**: `sourceCompatibility` or `targetCompatibility`
5. **Default**: Java 21

### Multi-Module Projects

For Maven multi-module projects with different Java versions across modules, the runner uses the **highest version** found to ensure all modules can build successfully.

**Example:**
```
my-project/
├── pom.xml (no version specified)
├── module-a/pom.xml (Java 8)
├── module-b/pom.xml (Java 11)
└── module-c/pom.xml (Java 17)
```
**Detected version: Java 17** (highest across all modules)

### Supported Java Versions

- **Java 8** (1.8)
- **Java 11**
- **Java 17**
- **Java 21** (default)

**Note:** Java 22+ projects will automatically use Java 21 until newer versions become available in Alpine Linux repositories.

### Manual Override

You can override the detected version:

```bash
# Using environment variable
dind-test run -e JAVA_VERSION=11 -- mvn test

# Using .java-version file
echo "17" > .java-version
dind-test run mvn test
```

## Commands Reference

### `dind-test init`

Initialize the DinD test runner by building the Docker image.

```bash
dind-test init
```

### `dind-test run <command>`

Run a test command in the DinD environment.

```bash
dind-test run [options] <command>
```

**Options:**
- `--prepull <images>`: Pre-pull comma-separated list of Docker images
- `--workdir <path>`: Set working directory (default: `/workspace`)
- `--debug`: Enable debug output
- `--cleanup`: Clean up containers after run

**Examples:**
```bash
# Basic test run
dind-test run mvn test

# Pre-pull images before running tests
dind-test run --prepull mysql:5.7,redis:latest -- mvn test

# Enable debug output
dind-test run --debug mvn test

# Clean up containers after run
dind-test run --cleanup mvn test
```

### `dind-test shell`

Open an interactive shell in the DinD environment for debugging.

```bash
dind-test shell
```

Inside the shell:
- Docker daemon is running
- Your project is mounted at `/workspace`
- Run commands manually (e.g., `mvn test`, `docker ps`)

### `dind-test status`

Show status of the test runner including images, volumes, and disk usage.

```bash
dind-test status
```

### `dind-test clean`

Clean up Docker images inside DinD (preserves volumes and caches).

```bash
dind-test clean
```

### `dind-test clean-all`

**⚠️ Nuclear option**: Remove all persistent volumes including all caches.

```bash
dind-test clean-all
```

This will remove:
- Maven cache (`~/.m2/repository`)
- npm cache
- pip cache
- Gradle cache
- Docker images volume

### `dind-test help`

Display help message with usage information.

```bash
dind-test help
```

## Usage Examples

### Maven Projects

```bash
# Run all tests
dind-test run mvn test

# Run specific test class
dind-test run mvn test -Dtest=MyIntegrationTest

# Run tests in specific module
dind-test run mvn test -pl my-module

# Run with specific Maven profile
dind-test run mvn test -P integration-tests

# Skip unit tests, run only integration tests
dind-test run mvn verify -DskipUnitTests
```

### Gradle Projects

```bash
# Run all tests
dind-test run gradle test

# Run specific test
dind-test run gradle test --tests MyIntegrationTest

# Run integration tests
dind-test run gradle integrationTest
```

### npm/Node.js Projects

```bash
# Run npm tests
dind-test run npm test

# Run with specific script
dind-test run npm run test:integration

# Run yarn tests
dind-test run yarn test
```

### Python Projects

```bash
# Run pytest
dind-test run pytest tests/

# Run with specific markers
dind-test run pytest -m integration

# Run with coverage
dind-test run pytest --cov=myapp tests/
```

### Testcontainers

```bash
# Pre-pull images for faster test execution
dind-test run --prepull mysql:8.0,postgres:15 -- mvn test

# Run Testcontainers-based tests
dind-test run mvn test -Dtest=DatabaseIntegrationTest
```

### Docker Compose Tests

```bash
# Run tests with docker-compose
dind-test run bash -c "docker-compose up -d && mvn test && docker-compose down"

# Interactive debugging
dind-test shell
# Inside shell:
$ docker-compose up -d
$ mvn test
$ docker-compose logs
$ docker-compose down
```

## Multi-Module Projects

### Maven Multi-Module Support

The test runner intelligently handles Maven multi-module projects:

1. **Scans all modules** for Java version configuration
2. **Selects the highest version** to ensure compatibility
3. **Caches dependencies** across module builds

**Example Project Structure:**
```
my-multi-module-project/
├── pom.xml (parent, no version)
├── api-module/pom.xml (no version, inherits from parent)
├── client-sdk/pom.xml (Java 8)
├── integration-tests/pom.xml (Java 11)
└── service-app/pom.xml (Java 17)
```

**Detection Result:** Java 17

### Per-Module Testing

```bash
# Test specific module
dind-test run mvn test -pl service-app

# Test multiple modules
dind-test run mvn test -pl service-app,integration-tests

# Test with dependencies
dind-test run mvn test -pl service-app -am
```

## Configuration

### Project-Level Configuration

#### `.java-version` File

Create a `.java-version` file in your project root to explicitly specify the Java version:

```bash
echo "17" > .java-version
```

Supported formats:
- `8`, `11`, `17`, `21`
- `1.8` (automatically normalized to `8`)

#### Maven `pom.xml`

```xml
<properties>
    <java.version>17</java.version>
    <!-- OR -->
    <maven.compiler.source>17</maven.compiler.source>
    <maven.compiler.target>17</maven.compiler.target>
</properties>
```

#### Gradle `build.gradle`

```groovy
sourceCompatibility = '17'
targetCompatibility = '17'
```

Or Kotlin DSL (`build.gradle.kts`):
```kotlin
java {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}
```

### Environment Variables

You can pass environment variables to customize behavior:

```bash
# Override Java version
dind-test run -e JAVA_VERSION=11 -- mvn test

# Set custom working directory
dind-test run -e WORKDIR=/workspace/subdir -- mvn test

# Enable debug mode
dind-test run -e DEBUG=true -- mvn test

# Auto-cleanup containers
dind-test run -e CLEANUP_CONTAINERS=true -- mvn test

# Maven options
dind-test run -e MAVEN_OPTS="-Xmx2g" -- mvn test

# Node options
dind-test run -e NODE_OPTIONS="--max-old-space-size=8192" -- npm test
```

### Maven Settings.xml Support

The `dind-test` script automatically mounts your Maven `settings.xml` file if it exists:

**Default Behavior:**
- Automatically mounts `~/.m2/settings.xml` if the file exists
- Read-only mount to prevent accidental modifications
- Silently skips if file doesn't exist (no error)

**Custom Settings File:**
```bash
# Use a different settings.xml file
MAVEN_SETTINGS_FILE=/path/to/custom/settings.xml dind-test run mvn test
```

**Disable Settings Mounting:**
```bash
# Disable mounting settings.xml
MAVEN_SETTINGS_FILE=none dind-test run mvn test
```

**For Docker-only Usage:**

If using Docker directly without the `dind-test` script, you can manually mount your settings.xml:

```bash
# With settings.xml
docker run --rm --privileged \
  -v "$(pwd):/workspace:cached" \
  -v "$HOME/.m2/settings.xml:/root/.m2/settings.xml:ro" \
  -v dind-maven-cache:/root/.m2/repository \
  -v dind-docker-images:/var/lib/docker \
  vwdubb/dind-test-runner:latest \
  mvn test

# Without settings.xml (omit the -v line)
docker run --rm --privileged \
  -v "$(pwd):/workspace:cached" \
  -v dind-maven-cache:/root/.m2/repository \
  -v dind-docker-images:/var/lib/docker \
  vwdubb/dind-test-runner:latest \
  mvn test
```

**For docker-compose Usage:**

Uncomment the settings.xml line in `docker-compose.yml` if you want it always mounted:

```yaml
volumes:
  # ...other volumes...

  # Uncomment to always mount Maven settings.xml:
  - ~/.m2/settings.xml:/root/.m2/settings.xml:ro
```

### Persistent Volumes

The following directories are persisted across runs for faster builds:

- **Maven**: `/root/.m2/repository` → `dind-maven-cache`
- **npm**: `/root/.npm` → `dind-npm-cache`
- **pip**: `/root/.cache/pip` → `dind-pip-cache`
- **Gradle**: `/root/.gradle` → `dind-gradle-cache`
- **Docker**: `/var/lib/docker` → `dind-docker-images`
- **Testcontainers**: `/root/.testcontainers`

## Architecture

### How It Works

1. **Docker-in-Docker**: Uses the official `docker:dind` image as base
2. **Volume Mounting**: Your project directory is mounted at `/workspace`
3. **Persistent Caches**: Build caches are stored in named Docker volumes
4. **Java Detection**: Automatically detects required Java version on startup
5. **Java Switching**: Dynamically switches `JAVA_HOME` and `PATH` before running tests
6. **Isolated Environment**: Tests run in complete isolation from your host system

### Container Naming

Containers are named based on your project directory:

```
dind-test-runner-<project-name>
```

Example: If you run from `/Users/me/my-project`, the container name is `dind-test-runner-my-project`.

### Network Configuration

- **Docker network**: Default bridge network
- **Address pool**: `172.80.0.0/16` (avoids conflicts with common ranges)
- **Subnet size**: `/24` per container

## Troubleshooting

### Java Version Not Detected

**Problem:** Tests are running with wrong Java version.

**Solutions:**
1. Add `.java-version` file to project root
2. Verify `pom.xml` has `<java.version>` or `<maven.compiler.source>`
3. Manually override: `dind-test run -e JAVA_VERSION=17 -- mvn test`
4. Enable debug: `dind-test run --debug mvn test` to see detection output

### Docker Images Not Building

**Problem:** Testcontainers can't build or pull images.

**Solutions:**
1. Pre-pull images: `dind-test run --prepull mysql:8.0,redis:latest -- mvn test`
2. Check network connectivity inside container: `dind-test shell` then `docker pull mysql:8.0`
3. Ensure Docker daemon started: Look for "Docker daemon started" in output

### Tests Run Slowly

**Problem:** Tests are slower than expected.

**Solutions:**
1. Pre-pull images to avoid pulling during test execution
2. Use persistent volumes (enabled by default)
3. Check cache volumes: `dind-test status`
4. Clean up old images: `dind-test clean`

### Out of Disk Space

**Problem:** Docker running out of disk space.

**Solutions:**
1. Clean unused images: `dind-test clean`
2. Check disk usage: `dind-test status`
3. Nuclear option (removes all caches): `dind-test clean-all`

### Port Conflicts

**Problem:** Container ports conflicting with host.

**Solution:** The DinD environment is isolated, so ports inside containers don't conflict with host. If you need to expose ports, use `docker run -p` inside the DinD environment.

### Maven Dependencies Not Cached

**Problem:** Maven downloads dependencies every time.

**Solutions:**
1. Check volume exists: `dind-test status`
2. Verify mounting: `dind-test shell` then `ls -la /root/.m2/repository`
3. Rebuild image: `dind-test clean-all` then `dind-test init`

### Multi-Module Project Issues

**Problem:** Wrong Java version for multi-module project.

**Solutions:**
1. The runner uses the **highest** version found across all modules
2. Override explicitly with `.java-version` file in project root
3. Check detection: `detect-java-version.sh /path/to/project`

### ARM/M1 Mac Issues

**Problem:** Tests fail on Apple Silicon with architecture errors.

**Solutions:**
1. Pre-pull with platform flag: `docker pull --platform linux/amd64 mysql:8.0`
2. Use `--platform linux/amd64` in your Dockerfiles
3. QEMU emulation is built into Docker Desktop for Mac

## Advanced Usage

### Using Docker Directly (Without dind-test Script)

If you prefer to use Docker commands directly instead of the `dind-test` wrapper script, you can work with the image and docker-compose directly.

#### Option 1: Using docker-compose

```bash
# Navigate to the dind-test-runner directory
cd /path/to/dind-test-runner

# Build the image
docker-compose build

# Run tests from your project directory
# Replace /path/to/your/project with your actual project path
docker-compose run --rm \
  -v "/path/to/your/project:/workspace:cached" \
  dind-test-runner \
  mvn test

# Open interactive shell
docker-compose run --rm \
  -v "/path/to/your/project:/workspace:cached" \
  dind-test-runner \
  bash
```

#### Option 2: Using docker run directly

```bash
# Build the image
cd /path/to/dind-test-runner
docker build -t dind-test-runner:latest .

# Run tests (basic)
docker run --rm --privileged -t \
  -v "/path/to/your/project:/workspace:cached" \
  -v "$HOME/.m2/settings.xml:/root/.m2/settings.xml:ro" \
  -v dind-maven-cache:/root/.m2/repository \
  -v dind-docker-images:/var/lib/docker \
  dind-test-runner:latest \
  mvn test

# Run tests with environment variables
docker run --rm --privileged -t \
  -v "/path/to/your/project:/workspace:cached" \
  -v "$HOME/.m2/settings.xml:/root/.m2/settings.xml:ro" \
  -v dind-maven-cache:/root/.m2/repository \
  -v dind-npm-cache:/root/.npm \
  -v dind-pip-cache:/root/.cache/pip \
  -v dind-gradle-cache:/root/.gradle \
  -v dind-docker-images:/var/lib/docker \
  -e JAVA_VERSION=17 \
  -e DEBUG=true \
  dind-test-runner:latest \
  mvn test

# Run with image pre-pulling
docker run --rm --privileged -t \
  -v "/path/to/your/project:/workspace:cached" \
  -v "$HOME/.m2/settings.xml:/root/.m2/settings.xml:ro" \
  -v dind-maven-cache:/root/.m2/repository \
  -v dind-docker-images:/var/lib/docker \
  -e PREPULL_IMAGES="mysql:8.0,postgres:15" \
  dind-test-runner:latest \
  mvn test

# Interactive shell
docker run -it --rm --privileged \
  -v "/path/to/your/project:/workspace:cached" \
  -v dind-maven-cache:/root/.m2/repository \
  -v dind-docker-images:/var/lib/docker \
  dind-test-runner:latest \
  bash
```

#### Option 3: Using a Pre-built Image

If the image is published to a container registry:

```bash
# Pull the image
docker pull vwdubb/dind-test-runner:latest

# Run tests
docker run --rm --privileged -t \
  -v "$(pwd):/workspace:cached" \
  -v "$HOME/.m2/settings.xml:/root/.m2/settings.xml:ro" \
  -v dind-maven-cache:/root/.m2/repository \
  -v dind-docker-images:/var/lib/docker \
  vwdubb/dind-test-runner:latest \
  mvn test
```

#### Required Docker Run Options

When using `docker run` directly, these options are required:

- **`--privileged`**: Required for Docker-in-Docker to work
- **`-t`**: Allocate a pseudo-TTY for colorful output (recommended)
- **`-v /path/to/project:/workspace:cached`**: Mount your project directory
- **`-v $HOME/.m2/settings.xml:/root/.m2/settings.xml:ro`**: Mount Maven settings (if exists)
- **`-v dind-docker-images:/var/lib/docker`**: Persist Docker images between runs

#### Optional Persistent Volumes

For better performance, mount these cache volumes:

```bash
-v dind-maven-cache:/root/.m2/repository    # Maven dependencies
-v dind-npm-cache:/root/.npm                # npm packages
-v dind-pip-cache:/root/.cache/pip          # Python packages
-v dind-gradle-cache:/root/.gradle          # Gradle cache
```

#### Colorful Output

To get colorful, formatted output when using Docker directly, use the `-t` flag to allocate a pseudo-TTY:

```bash
# With -t flag for color output
docker run --rm --privileged -t \
  -v "$(pwd):/workspace:cached" \
  vwdubb/dind-test-runner:latest \
  mvn test

# Without -t (plain output)
docker run --rm --privileged \
  -v "$(pwd):/workspace:cached" \
  vwdubb/dind-test-runner:latest \
  mvn test
```

**For Maven specifically**, you can also force colored output:

```bash
docker run --rm --privileged -t \
  -v "$(pwd):/workspace:cached" \
  -e MAVEN_OPTS="-Dstyle.color=always" \
  vwdubb/dind-test-runner:latest \
  mvn test
```

**For npm/yarn**, enable color mode:

```bash
docker run --rm --privileged -t \
  -v "$(pwd):/workspace:cached" \
  -e FORCE_COLOR=1 \
  vwdubb/dind-test-runner:latest \
  npm test
```

**For pytest**, use the `--color=yes` flag:

```bash
docker run --rm --privileged -t \
  -v "$(pwd):/workspace:cached" \
  vwdubb/dind-test-runner:latest \
  pytest --color=yes tests/
```

**Note:** The `dind-test` script automatically handles TTY allocation, so colorful output works out of the box when using the wrapper script.

#### Environment Variables for Docker Run

```bash
-e JAVA_VERSION=17              # Override detected Java version
-e WORKDIR=/workspace/subdir    # Set working directory
-e DEBUG=true                   # Enable debug output
-e CLEANUP_CONTAINERS=true      # Auto-cleanup containers after run
-e PREPULL_IMAGES="img1,img2"   # Pre-pull Docker images
-e MAVEN_OPTS="-Xmx2g"         # Maven JVM options
-e NODE_OPTIONS="--max-old-space-size=8192"  # Node.js options
```

#### Publishing the Image

To share the image with your team or CI/CD:

```bash
# Tag for your registry
docker tag dind-test-runner:latest vwdubb/dind-test-runner:latest

# Push to registry
docker push vwdubb/dind-test-runner:latest

# Team members can pull and use
docker pull vwdubb/dind-test-runner:latest
docker run --rm --privileged -t \
  -v "$(pwd):/workspace:cached" \
  -v "$HOME/.m2/settings.xml:/root/.m2/settings.xml:ro" \
  -v dind-maven-cache:/root/.m2/repository \
  -v dind-docker-images:/var/lib/docker \
  vwdubb/dind-test-runner:latest \
  mvn test
```

#### Docker Compose for CI/CD

Create a `docker-compose.override.yml` in your project:

```yaml
version: '3.8'

services:
  test-runner:
    image: dind-test-runner:latest
    privileged: true
    volumes:
      - .:/workspace:cached
      - maven-cache:/root/.m2/repository
      - docker-images:/var/lib/docker
    environment:
      - JAVA_VERSION=17
    working_dir: /workspace

volumes:
  maven-cache:
  docker-images:
```

Then run:

```bash
docker-compose run --rm test-runner mvn test
```

### Custom Docker Daemon Configuration

Edit `daemon.json` by modifying the Dockerfile:

```json
{
  "storage-driver": "overlay2",
  "default-address-pools": [{"base":"172.80.0.0/16","size":24}],
  "data-root": "/var/lib/docker"
}
```

### Running Multiple Projects Simultaneously

Each project gets its own named container, so you can run tests for multiple projects in parallel:

```bash
# Terminal 1
cd /path/to/project-a
dind-test run mvn test

# Terminal 2
cd /path/to/project-b
dind-test run mvn test
```

### Debugging Inside Container

```bash
# Open shell
dind-test shell

# Inside container:
# Check Java version
java -version

# Check Docker
docker ps
docker images

# Check environment
env | grep JAVA

# Run tests manually
mvn test -X  # Maven debug mode
```

### CI/CD Integration

Example GitHub Actions workflow:

```yaml
name: Integration Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install dind-test
        run: |
          curl -O https://example.com/dind-test-runner.tar.gz
          tar xzf dind-test-runner.tar.gz
          export PATH="$PWD/dind-test-runner:$PATH"
          dind-test init

      - name: Run Integration Tests
        run: dind-test run --cleanup mvn verify
```

## Files Reference

### Core Files

- **`dind-test`**: Main CLI script
- **`Dockerfile`**: Docker image definition
- **`docker-compose.yml`**: Docker Compose configuration
- **`entrypoint.sh`**: Container entrypoint script
- **`start-dockerd.sh`**: Docker daemon startup script
- **`detect-java-version.sh`**: Java version detection script
- **`switch-java-version.sh`**: Java version switching script

### Detection Scripts

#### `detect-java-version.sh`

Detects Java version from project configuration. Can be run standalone:

```bash
/path/to/detect-java-version.sh /path/to/project
# Output: 17
```

#### `switch-java-version.sh`

Switches to a specific Java version. Usage inside container:

```bash
eval "$(/usr/local/bin/switch-java-version.sh 17)"
```

## Contributing

Contributions welcome! Please ensure:

1. Scripts are POSIX-compliant (use `/bin/sh` where possible)
2. Test on both ARM and x86_64 architectures
3. Update this README with any new features

## License

This tool is provided as-is for use in development and CI/CD environments.

## Changelog

### Version 1.0
- Initial release
- Support for Java 8, 11, 17, 21
- Multi-module Maven project support
- Automatic Java version detection
- Persistent build caches
- Testcontainers support
