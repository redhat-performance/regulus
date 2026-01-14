#!/bin/bash
set -e

IMAGE_NAME="regulus-dashboard"
VERSION="${1:-latest}"
REGISTRY="${CONTAINER_REGISTRY:-}"

echo "================================================"
echo "  Building Regulus Dashboard Image"
echo "================================================"
echo ""

# Check if podman is installed
if ! command -v podman &> /dev/null; then
    echo "Error: podman not found"
    echo "Please install podman: sudo dnf install podman"
    exit 1
fi

# Check if we're in the docker directory
if [ ! -f "Dockerfile" ]; then
    echo "Error: Dockerfile not found in current directory"
    echo "Please run this script from regulus/REPORT/docker/"
    exit 1
fi

# Check if dashboard code exists (in parent directory)
if [ ! -d "../build_report/dashboard" ]; then
    echo "Error: Dashboard code not found at ../build_report/dashboard"
    echo "Please ensure dashboard code exists"
    exit 1
fi

# Check if sample data exists
if [ ! -d "sample_data" ] || [ -z "$(ls -A sample_data/*.json 2>/dev/null)" ]; then
    echo "Warning: No JSON files found in sample_data/"
    echo ""
    echo "The image will start with no initial sample data."
    echo "Users will need to add their own JSON files to /tmp/regulus-data/"
    echo ""
    echo "To include sample data:"
    echo "  cp ../build_report/dashboard/test_data/*.json sample_data/"
    echo ""
    read -p "Continue without sample data? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

if [ -d "sample_data" ] && [ -n "$(ls -A sample_data/*.json 2>/dev/null)" ]; then
    echo "Sample JSON files to include in image:"
    ls -lh sample_data/*.json
    echo ""
fi

echo "Building image..."
echo "Build context: $(pwd)/.."
echo "Dockerfile: $(pwd)/Dockerfile"
echo ""

# Build from parent directory so we can access both docker/ and build_report/
podman build \
    --file Dockerfile \
    --tag ${IMAGE_NAME}:${VERSION} \
    --tag ${IMAGE_NAME}:latest \
    --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
    --build-arg VCS_REF=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown") \
    ..

echo ""
echo "================================================"
echo "✓ Build complete!"
echo "================================================"
echo ""
echo "Image: ${IMAGE_NAME}:${VERSION}"
echo ""
echo "Test locally:"
echo "  ./run-dashboard.sh"
echo ""
echo "Or manually:"
echo "  podman run --rm -p 5000:5000 -v /tmp/regulus-data:/app/data:Z ${IMAGE_NAME}:${VERSION}"
echo ""
echo "Or use compose:"
echo "  podman-compose up"
echo ""

if [ -n "$REGISTRY" ]; then
    echo "Push to registry:"
    echo "  podman tag ${IMAGE_NAME}:${VERSION} ${REGISTRY}/${IMAGE_NAME}:${VERSION}"
    echo "  podman push ${REGISTRY}/${IMAGE_NAME}:${VERSION}"
    echo ""
fi
