#!/bin/bash
# Show all valid search keywords from ElasticSearch

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="regulus-es-cli"
ES_URL="${ES_URL:-https://admin:nKNQ9=vw_bwaSy1@search-perfscale-pro-wxrjvmobqs7gsyi3xvxkqmn7am.us-west-2.es.amazonaws.com}"
ES_INDEX="${ES_INDEX:-regulus-results}"

# Check if image exists, build if not
if ! podman image exists "$IMAGE_NAME" 2>/dev/null; then
    echo "Building container image: $IMAGE_NAME"
    podman build -t "$IMAGE_NAME" "$SCRIPT_DIR"
    echo "Image built successfully"
fi

# Run the keywords script
podman run --rm \
    -e ES_URL="$ES_URL" \
    -e ES_INDEX="$ES_INDEX" \
    --entrypoint python \
    "$IMAGE_NAME" es_show_keywords.py
