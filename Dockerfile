FROM ubuntu:22.04

# Build arguments for runtime versions
ARG JAVA_VERSION=21
ARG MAVEN_VERSION=3.9.6
ARG GRADLE_VERSION=8.5
ARG NODE_MAJOR=20

ENV DEBIAN_FRONTEND=noninteractive

# Base build tools and utilities (build-essential provides gcc/g++/make/libc6-dev,
# needed to compile native node modules like node-sass from source on arm64).
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    curl \
    wget \
    git \
    build-essential \
    ca-certificates \
    gnupg \
    lsb-release \
    tar \
    gzip \
    unzip \
    zip \
    iptables \
    && rm -rf /var/lib/apt/lists/*

# Prefer legacy iptables — dockerd-in-a-container is more reliable with it.
RUN update-alternatives --set iptables /usr/sbin/iptables-legacy || true && \
    update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy || true

# Docker engine (provides dockerd for DinD) from Docker's official apt repo.
RUN install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc && \
    chmod a+r /etc/apt/keyrings/docker.asc && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu jammy stable" \
      > /etc/apt/sources.list.d/docker.list && \
    apt-get update && apt-get install -y --no-install-recommends \
      docker-ce \
      docker-ce-cli \
      containerd.io \
      docker-buildx-plugin \
      docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# Multiple JDKs (8, 11, 17, 21) via Ubuntu's openjdk packages.
RUN apt-get update && apt-get install -y --no-install-recommends \
    openjdk-8-jdk \
    openjdk-11-jdk \
    openjdk-17-jdk \
    openjdk-21-jdk \
    && rm -rf /var/lib/apt/lists/*

# Ubuntu installs JDKs at /usr/lib/jvm/java-<v>-openjdk-<arch> (arch-suffixed).
# Create stable, arch-independent symlinks so JAVA_HOME paths and the
# switch-java-version.sh script work unchanged across amd64/arm64.
RUN for v in 8 11 17 21; do \
      real="$(ls -d /usr/lib/jvm/java-${v}-openjdk-* 2>/dev/null | head -1)"; \
      if [ -n "$real" ]; then ln -sfn "$real" /usr/lib/jvm/java-${v}-openjdk; fi; \
    done

# Default JAVA_HOME to Java 21 (switched dynamically at runtime by entrypoint).
ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk
ENV PATH="${JAVA_HOME}/bin:${PATH}"

# Stable paths to each JDK for switch-java-version.sh.
ENV JAVA_8_HOME=/usr/lib/jvm/java-8-openjdk
ENV JAVA_11_HOME=/usr/lib/jvm/java-11-openjdk
ENV JAVA_17_HOME=/usr/lib/jvm/java-17-openjdk
ENV JAVA_21_HOME=/usr/lib/jvm/java-21-openjdk

# Maven
RUN cd /tmp && \
    wget -q https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz && \
    tar xzf apache-maven-${MAVEN_VERSION}-bin.tar.gz && \
    mv apache-maven-${MAVEN_VERSION} /opt/maven && \
    rm apache-maven-${MAVEN_VERSION}-bin.tar.gz

ENV MAVEN_HOME=/opt/maven
ENV PATH="${MAVEN_HOME}/bin:${PATH}"

# Gradle
RUN cd /tmp && \
    wget -q https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip && \
    unzip -q gradle-${GRADLE_VERSION}-bin.zip && \
    mv gradle-${GRADLE_VERSION} /opt/gradle && \
    rm gradle-${GRADLE_VERSION}-bin.zip

ENV GRADLE_HOME=/opt/gradle
ENV PATH="${GRADLE_HOME}/bin:${PATH}"

# Node.js (NodeSource) + npm, then Yarn. Note: build tools that pin their own Node
# (frontend-maven-plugin) download it themselves; this is the general-purpose Node.
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    npm install -g yarn && \
    rm -rf /var/lib/apt/lists/*

# Python 3.10 (Ubuntu 22.04 default) + pip. 3.10 keeps the legacy node-gyp used by
# node-sass working (3.11+ removed the 'rU' open mode it relies on).
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-distutils \
    && rm -rf /var/lib/apt/lists/* && \
    ln -sf /usr/bin/python3 /usr/bin/python

# Persistent cache directories
RUN mkdir -p /workspace \
    /root/.m2/repository \
    /root/.npm \
    /root/.cache/pip \
    /root/.gradle \
    /root/.testcontainers \
    /var/log

# Docker daemon configuration
RUN mkdir -p /etc/docker && \
    printf '%s\n' '{' \
    '  "storage-driver": "overlay2",' \
    '  "default-address-pools": [{"base":"172.80.0.0/16","size":24}],' \
    '  "data-root": "/var/lib/docker"' \
    '}' > /etc/docker/daemon.json

ENV DOCKER_HOST=unix:///var/run/docker.sock \
    JAVA_TOOL_OPTIONS="-Dapi.version=1.44" \
    TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE=/var/run/docker.sock \
    DOCKER_DEFAULT_PLATFORM=linux/amd64 \
    TESTCONTAINERS_RYUK_DISABLED=false \
    TESTCONTAINERS_CHECKS_DISABLE=false \
    MAVEN_OPTS="-XX:+TieredCompilation -XX:TieredStopAtLevel=1" \
    NODE_OPTIONS="--max-old-space-size=4096"

WORKDIR /workspace

# Startup scripts
COPY start-dockerd.sh /usr/local/bin/start-dockerd.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY detect-java-version.sh /usr/local/bin/detect-java-version.sh
COPY switch-java-version.sh /usr/local/bin/switch-java-version.sh

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

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["bash", "-c", "echo 'DinD test runner ready. Specify a command to run.'"]
