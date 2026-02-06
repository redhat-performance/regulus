#!/bin/bash
# Build and run the Regulus ES CLI container

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="regulus-es-cli"

# Source ES configuration from parent REPORT directory
# Priority: ES_URL env var > /secret > lab.config
if [ -z "${ES_URL:-}" ]; then
    REG_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

    if [ -d "/secret" ]; then
        # Container environment with secrets mounted
        ES_USER=$(cat /secret/username 2>/dev/null || echo "")
        ES_PASSWORD=$(cat /secret/password 2>/dev/null || echo "")
        ES_HOST=$(cat /secret/host 2>/dev/null || echo "")

        if [ -n "$ES_HOST" ]; then
            if [ -n "$ES_USER" ] && [ -n "$ES_PASSWORD" ]; then
                export ES_URL="https://${ES_USER}:${ES_PASSWORD}@${ES_HOST}"
            else
                export ES_URL="https://${ES_HOST}"
            fi
        fi
    elif [ -f "$REG_ROOT/lab.config" ]; then
        # Source from lab.config
        source "$REG_ROOT/lab.config"
        if [ -z "${ES_URL:-}" ]; then
            echo "ERROR: ES_URL not defined in lab.config" >&2
            exit 1
        fi
    else
        echo "ERROR: ES_URL environment variable not set and no configuration found" >&2
        echo "Please set ES_URL or configure lab.config" >&2
        exit 1
    fi
fi

# ES_INDEX is hardcoded in es_integration/es_config.py as 'regulus-results-*'
# It should NOT be overridden unless you understand rollover index architecture
# Uncomment below only if you're an expert modifying the infrastructure:
# ES_INDEX="${ES_INDEX:-regulus-results-*}"

# Check if image exists, build if not
if ! podman image exists "$IMAGE_NAME" 2>/dev/null; then
    echo "Building container image: $IMAGE_NAME"
    # Build from REPORT directory to include es_integration/es_config.py in context
    REPORT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
    podman build -t "$IMAGE_NAME" -f "$SCRIPT_DIR/Dockerfile" "$REPORT_DIR"
    echo "Image built successfully"
else
    echo "Using existing image: $IMAGE_NAME"
fi

# Run the container with ES credentials
# ES_INDEX comes from hardcoded default in es_config.py, not passed as env var
podman run --rm \
    -e ES_URL="$ES_URL" \
    "$IMAGE_NAME" "$@"
