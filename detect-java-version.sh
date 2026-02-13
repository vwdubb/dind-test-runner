#!/bin/bash
# Detect required Java version from project configuration
# Returns: 8, 11, 17, or 21 (defaults to 21 if not detected)

set -e

WORKDIR=${1:-$(pwd)}

# Function to detect Java version from Maven pom.xml (supports multi-module projects)
detect_from_maven() {
    local pom_file="$WORKDIR/pom.xml"

    if [ ! -f "$pom_file" ]; then
        return 1
    fi

    # Look for <java.version>, <maven.compiler.source>, or <maven.compiler.target>
    # Using sed instead of grep -P for BusyBox compatibility
    local java_version=$(sed -n 's/.*<java\.version>\([^<]*\)<\/java\.version>.*/\1/p' "$pom_file" 2>/dev/null | head -1)

    if [ -z "$java_version" ]; then
        java_version=$(sed -n 's/.*<maven\.compiler\.source>\([^<]*\)<\/maven\.compiler\.source>.*/\1/p' "$pom_file" 2>/dev/null | head -1)
    fi

    if [ -z "$java_version" ]; then
        java_version=$(sed -n 's/.*<maven\.compiler\.target>\([^<]*\)<\/maven\.compiler\.target>.*/\1/p' "$pom_file" 2>/dev/null | head -1)
    fi

    # Check <maven.compiler.release> (Java 9+ replacement for source/target)
    if [ -z "$java_version" ]; then
        java_version=$(sed -n 's/.*<maven\.compiler\.release>\([^<]*\)<\/maven\.compiler\.release>.*/\1/p' "$pom_file" 2>/dev/null | head -1)
    fi

    # For multi-module projects, always check all modules and use the HIGHEST version
    # found across root and all modules (modules may override the parent version)
    local modules=$(sed -n 's/.*<module>\([^<]*\)<\/module>.*/\1/p' "$pom_file" 2>/dev/null)

    if [ -n "$modules" ]; then
        # Normalize root version for comparison
        local max_version=0
        if [ -n "$java_version" ]; then
            if [[ "$java_version" =~ ^1\.([0-9]+) ]]; then
                max_version="${BASH_REMATCH[1]}"
            else
                max_version=$(echo "$java_version" | cut -d'.' -f1)
            fi
        fi

        # Iterate through each module and find the highest Java version
        while IFS= read -r module; do
            if [ -n "$module" ] && [ -f "$WORKDIR/$module/pom.xml" ]; then
                local module_version=""
                module_version=$(sed -n 's/.*<java\.version>\([^<]*\)<\/java\.version>.*/\1/p' "$WORKDIR/$module/pom.xml" 2>/dev/null | head -1)

                if [ -z "$module_version" ]; then
                    module_version=$(sed -n 's/.*<maven\.compiler\.source>\([^<]*\)<\/maven\.compiler\.source>.*/\1/p' "$WORKDIR/$module/pom.xml" 2>/dev/null | head -1)
                fi

                if [ -z "$module_version" ]; then
                    module_version=$(sed -n 's/.*<maven\.compiler\.target>\([^<]*\)<\/maven\.compiler\.target>.*/\1/p' "$WORKDIR/$module/pom.xml" 2>/dev/null | head -1)
                fi

                if [ -z "$module_version" ]; then
                    module_version=$(sed -n 's/.*<maven\.compiler\.release>\([^<]*\)<\/maven\.compiler\.release>.*/\1/p' "$WORKDIR/$module/pom.xml" 2>/dev/null | head -1)
                fi

                # Normalize version (e.g., "1.8" -> "8")
                if [ -n "$module_version" ]; then
                    if [[ "$module_version" =~ ^1\.([0-9]+) ]]; then
                        module_version="${BASH_REMATCH[1]}"
                    else
                        module_version=$(echo "$module_version" | cut -d'.' -f1)
                    fi

                    # Keep track of the highest version
                    if [ "$module_version" -gt "$max_version" ] 2>/dev/null; then
                        max_version="$module_version"
                    fi
                fi
            fi
        done <<< "$modules"

        # Use the highest version found across root + all modules
        if [ "$max_version" -gt 0 ] 2>/dev/null; then
            java_version="$max_version"
        fi
    fi

    if [ -n "$java_version" ]; then
        # Extract major version (e.g., "11" from "11.0.1" or "1.8" -> "8")
        if [[ "$java_version" =~ ^1\.([0-9]+) ]]; then
            echo "${BASH_REMATCH[1]}"
        else
            echo "$java_version" | cut -d'.' -f1
        fi
        return 0
    fi

    return 1
}

# Function to detect Java version from Gradle build files
detect_from_gradle() {
    local gradle_file=""

    # Check for build.gradle.kts (Kotlin) or build.gradle (Groovy)
    if [ -f "$WORKDIR/build.gradle.kts" ]; then
        gradle_file="$WORKDIR/build.gradle.kts"
    elif [ -f "$WORKDIR/build.gradle" ]; then
        gradle_file="$WORKDIR/build.gradle"
    else
        return 1
    fi

    # Look for sourceCompatibility or targetCompatibility
    # Using sed/awk for BusyBox compatibility
    local java_version=$(sed -n 's/.*sourceCompatibility.*VERSION_\([0-9][0-9]*\).*/\1/p' "$gradle_file" 2>/dev/null | head -1)

    if [ -z "$java_version" ]; then
        java_version=$(sed -n 's/.*targetCompatibility.*VERSION_\([0-9][0-9]*\).*/\1/p' "$gradle_file" 2>/dev/null | head -1)
    fi

    if [ -z "$java_version" ]; then
        # Try string format: sourceCompatibility = "11"
        java_version=$(sed -n 's/.*sourceCompatibility.*["\x27]\([0-9][0-9]*\)["\x27].*/\1/p' "$gradle_file" 2>/dev/null | head -1)
    fi

    if [ -z "$java_version" ]; then
        java_version=$(sed -n 's/.*targetCompatibility.*["\x27]\([0-9][0-9]*\)["\x27].*/\1/p' "$gradle_file" 2>/dev/null | head -1)
    fi

    # Try toolchain API: java.toolchain.languageVersion.set(JavaLanguageVersion.of(17))
    if [ -z "$java_version" ]; then
        java_version=$(sed -n 's/.*JavaLanguageVersion\.of(\([0-9][0-9]*\)).*/\1/p' "$gradle_file" 2>/dev/null | head -1)
    fi

    # Try Kotlin DSL shorthand: jvmToolchain(17)
    if [ -z "$java_version" ]; then
        java_version=$(sed -n 's/.*jvmToolchain(\([0-9][0-9]*\)).*/\1/p' "$gradle_file" 2>/dev/null | head -1)
    fi

    if [ -n "$java_version" ]; then
        echo "$java_version"
        return 0
    fi

    return 1
}

# Function to detect Java version from .java-version file
detect_from_java_version_file() {
    local java_version_file="$WORKDIR/.java-version"

    if [ ! -f "$java_version_file" ]; then
        return 1
    fi

    local java_version=$(cat "$java_version_file" | head -1 | tr -d '[:space:]')

    # Extract major version
    if [[ "$java_version" =~ ^1\.([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo "$java_version" | cut -d'.' -f1
    fi
    return 0
}

# Function to detect from environment variable
detect_from_env() {
    if [ -n "$JAVA_VERSION" ]; then
        echo "$JAVA_VERSION"
        return 0
    fi
    return 1
}

# Main detection logic (priority order)
detected_version=""

# 1. Check environment variable (highest priority - manual override)
if detected_version=$(detect_from_env); then
    echo "$detected_version"
    exit 0
fi

# 2. Check .java-version file
if detected_version=$(detect_from_java_version_file); then
    echo "$detected_version"
    exit 0
fi

# 3. Check Maven pom.xml
if detected_version=$(detect_from_maven); then
    echo "$detected_version"
    exit 0
fi

# 4. Check Gradle build files
if detected_version=$(detect_from_gradle); then
    echo "$detected_version"
    exit 0
fi

# Default to Java 21 if nothing detected
echo "21"
exit 0
