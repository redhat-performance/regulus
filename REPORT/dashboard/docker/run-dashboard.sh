#!/bin/bash
set -e

# Configuration
IMAGE="regulus-dashboard:latest"
CONTAINER_NAME="regulus-dashboard"
PORT="${PORT:-5000}"
DATA_DIR="/tmp/regulus-data"

echo "================================================"
echo "  Regulus Performance Dashboard"
echo "================================================"
echo ""

# Check if podman is installed
if ! command -v podman &> /dev/null; then
    echo "Error: podman not found"
    echo "Please install podman: sudo dnf install podman"
    exit 1
fi

# Check if image exists locally
if ! podman image inspect $IMAGE > /dev/null 2>&1; then
    echo "Error: Image '$IMAGE' not found locally"
    echo ""
    echo "Please build the image first:"
    echo "  ./build.sh"
    echo ""
    echo "Or pull from registry:"
    echo "  podman pull quay.io/username/regulus-dashboard:latest"
    exit 1
fi

# Create data directory if it doesn't exist
if [ ! -d "$DATA_DIR" ]; then
    echo "Creating data directory: $DATA_DIR"
    mkdir -p "$DATA_DIR"
    echo ""
fi

# Remove existing container if present
if podman ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Removing existing container..."
    podman rm -f $CONTAINER_NAME > /dev/null 2>&1
fi

echo "Starting dashboard..."

# :Z = SELinux relabel for private container use (RHEL/Fedora)
podman run -d \
    --name $CONTAINER_NAME \
    -p ${PORT}:5000 \
    -v ${DATA_DIR}:/app/data:Z \
    --restart unless-stopped \
    $IMAGE

# Wait a moment for startup
sleep 3

# Check if container is running
if ! podman ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo ""
    echo "Error: Container failed to start"
    echo "Logs:"
    podman logs $CONTAINER_NAME
    exit 1
fi

echo ""
echo "================================================"
echo "✓ Dashboard running!"
echo "================================================"
echo ""
echo "  URL:           http://localhost:${PORT}"
echo "  Data location: ${DATA_DIR}"
echo "  Container:     ${CONTAINER_NAME}"
echo ""

# Show current files
if [ -n "$(ls -A ${DATA_DIR}/*.json 2>/dev/null)" ]; then
    echo "JSON files in ${DATA_DIR}:"
    ls -lh ${DATA_DIR}/*.json
else
    echo "Checking for sample data..."
    sleep 2
    if [ -n "$(ls -A ${DATA_DIR}/*.json 2>/dev/null)" ]; then
        echo "Sample files copied to ${DATA_DIR}:"
        ls -lh ${DATA_DIR}/*.json
    else
        echo "No files in ${DATA_DIR} yet"
        echo "(Add JSON files or restart container to copy samples)"
    fi
fi

echo ""
echo "Usage:"
echo "  1. Open browser:      http://localhost:${PORT}"
echo "  2. Add your reports:  cp my-report.json ${DATA_DIR}/"
echo "  3. Remove samples:    rm ${DATA_DIR}/*.json"
echo "  4. Click 'Reload' button in the dashboard"
echo ""
echo "Management:"
echo "  podman logs ${CONTAINER_NAME}        # View logs"
echo "  podman logs -f ${CONTAINER_NAME}     # Follow logs"
echo "  podman restart ${CONTAINER_NAME}     # Restart"
echo "  podman stop ${CONTAINER_NAME}        # Stop"
echo "  podman rm -f ${CONTAINER_NAME}       # Remove"
echo ""
echo "Data directory:"
echo "  ls -lh ${DATA_DIR}"
echo "================================================"
