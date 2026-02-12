FROM docker:27.0-dind

# Build arguments for runtime versions
ARG JAVA_VERSION=21
ARG MAVEN_VERSION=3.9.6
ARG NODE_VERSION=20
ARG PYTHON_VERSION=3.11

# Install base dependencies and build tools
RUN apk add --no-cache \
    bash \
    curl \
    wget \
    git \
    make \
    gcc \
    g++ \
    libc-dev \
    ca-certificates \
    tar \
    gzip \
    unzip \
    zip \
    && rm -rf /var/cache/apk/*

# Note: Docker Desktop on ARM already has QEMU support built-in
# No need to install QEMU separately - it will use the host's emulation

# Install multiple Java versions (8, 11, 17, 21)
# Note: Java 25 will be added when available in Alpine repos
RUN apk add --no-cache \
    openjdk8 \
    openjdk8-jdk \
    openjdk11 \
    openjdk11-jdk \
    openjdk17 \
    openjdk17-jdk \
    openjdk21 \
    openjdk21-jdk \
    && rm -rf /var/cache/apk/*

# Set default JAVA_HOME to Java 21 (can be changed dynamically)
ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk
ENV PATH="${JAVA_HOME}/bin:${PATH}"

# Store paths to all Java installations for easy switching
ENV JAVA_8_HOME=/usr/lib/jvm/java-8-openjdk
ENV JAVA_11_HOME=/usr/lib/jvm/java-11-openjdk
ENV JAVA_17_HOME=/usr/lib/jvm/java-17-openjdk
ENV JAVA_21_HOME=/usr/lib/jvm/java-21-openjdk

# Install Maven
RUN cd /tmp && \
    wget https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz && \
    tar xzf apache-maven-${MAVEN_VERSION}-bin.tar.gz && \
    mv apache-maven-${MAVEN_VERSION} /opt/maven && \
    rm apache-maven-${MAVEN_VERSION}-bin.tar.gz

ENV MAVEN_HOME=/opt/maven
ENV PATH="${MAVEN_HOME}/bin:${PATH}"

# Install Gradle
RUN cd /tmp && \
    wget https://services.gradle.org/distributions/gradle-8.5-bin.zip && \
    unzip gradle-8.5-bin.zip && \
    mv gradle-8.5 /opt/gradle && \
    rm gradle-8.5-bin.zip

ENV GRADLE_HOME=/opt/gradle
ENV PATH="${GRADLE_HOME}/bin:${PATH}"

# Install Node.js and npm
RUN apk add --no-cache nodejs npm && rm -rf /var/cache/apk/*

# Install Yarn
RUN npm install -g yarn

# Install Python and pip
RUN apk add --no-cache python3 py3-pip && rm -rf /var/cache/apk/*

# Create symlink for python command
RUN ln -sf /usr/bin/python3 /usr/bin/python

# Create directories for persistent caches
RUN mkdir -p /workspace \
    /root/.m2/repository \
    /root/.npm \
    /root/.cache/pip \
    /root/.gradle \
    /root/.testcontainers \
    /var/log

# Configure Docker daemon
RUN mkdir -p /etc/docker && \
    echo '{ \
  "storage-driver": "overlay2", \
  "default-address-pools": [{"base":"172.80.0.0/16","size":24}], \
  "data-root": "/var/lib/docker" \
}' > /etc/docker/daemon.json

# Set environment variables for testcontainers and Docker
ENV DOCKER_HOST=unix:///var/run/docker.sock \
    TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE=/var/run/docker.sock \
    DOCKER_DEFAULT_PLATFORM=linux/amd64 \
    TESTCONTAINERS_RYUK_DISABLED=false \
    TESTCONTAINERS_CHECKS_DISABLE=false \
    MAVEN_OPTS="-XX:+TieredCompilation -XX:TieredStopAtLevel=1" \
    NODE_OPTIONS="--max-old-space-size=4096"

# Set working directory
WORKDIR /workspace

# Copy startup scripts
COPY start-dockerd.sh /usr/local/bin/start-dockerd.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY detect-java-version.sh /usr/local/bin/detect-java-version.sh
COPY switch-java-version.sh /usr/local/bin/switch-java-version.sh

# Make scripts executable
RUN chmod +x /usr/local/bin/start-dockerd.sh \
    /usr/local/bin/entrypoint.sh \
    /usr/local/bin/detect-java-version.sh \
    /usr/local/bin/switch-java-version.sh

# Verify installations
RUN echo "=== Verifying Java 8 ===" && /usr/lib/jvm/java-8-openjdk/bin/java -version && \
    echo "=== Verifying Java 11 ===" && /usr/lib/jvm/java-11-openjdk/bin/java -version && \
    echo "=== Verifying Java 17 ===" && /usr/lib/jvm/java-17-openjdk/bin/java -version && \
    echo "=== Verifying Java 21 ===" && /usr/lib/jvm/java-21-openjdk/bin/java -version && \
    echo "=== Default Java ===" && java -version && \
    echo "=== Maven ===" && mvn --version && \
    echo "=== Gradle ===" && gradle --version && \
    echo "=== Node ===" && node --version && \
    echo "=== npm ===" && npm --version && \
    echo "=== Python ===" && python --version && \
    echo "=== pip ===" && pip --version

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Default command
CMD ["bash", "-c", "echo 'DinD test runner ready. Specify a command to run.'"]
