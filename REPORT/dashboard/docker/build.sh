#!/bin/bash
#
# build.sh - Build the Regulus Dashboard container image
#
# Usage:
#   ./build.sh              # Build with default tag
#   ./build.sh mytag        # Build with custom tag
#

set -e

# Change to REPORT directory (build context must be REPORT/)
cd "$(dirname "$0")/../.."

# Determine image tag
TAG="${1:-latest}"
IMAGE_NAME="regulus-dashboard"
FULL_TAG="${IMAGE_NAME}:${TAG}"

echo "================================================"
echo "  Building Regulus Dashboard Container"
echo "================================================"
echo ""
echo "Image: ${FULL_TAG}"
echo "Build context: $(pwd)"
echo "Dockerfile: dashboard/docker/Dockerfile"
echo ""

# Build the image using podman (system default)
echo "→ Building container image..."
podman build \
    -f dashboard/docker/Dockerfile \
    -t "${FULL_TAG}" \
    .

echo ""
echo "================================================"
echo "✓ Build complete!"
echo "================================================"
echo ""
echo "Image: ${FULL_TAG}"
echo ""
echo "To run the dashboard:"
echo "  cd dashboard/docker"
echo "  podman-compose up"
echo ""
echo "Or run manually:"
echo "  podman run -p 5000:5000 -v /tmp/regulus-data:/app/data:Z ${FULL_TAG}"
echo ""
echo "Then open: http://localhost:5000"
echo "================================================"
