#!/bin/bash
set -e

# Dashboard startup script with built-in report copying
# This mirrors the container behavior for native deployment

DASHBOARD_DIR="$(cd "$(dirname "$0")" && pwd)"
GENERATED_DIR="$(dirname "$DASHBOARD_DIR")/generated"
DATA_DIR="${DATA_DIR:-/tmp/regulus-data}"

echo "================================================"
echo "  Regulus Performance Dashboard"
echo "================================================"
echo ""

# Create data directory if it doesn't exist
mkdir -p "$DATA_DIR"

# Check if generated/ has built-in reports to copy
if [ -d "$GENERATED_DIR" ] && [ "$(ls -A "$GENERATED_DIR"/*.json 2>/dev/null)" ]; then
    echo "→ Found built-in reports in $GENERATED_DIR"

    # Check if data directory is empty
    if [ ! "$(ls -A "$DATA_DIR"/*.json 2>/dev/null)" ]; then
        echo "→ Data directory is empty, copying built-in reports..."
        cp "$GENERATED_DIR"/*.json "$DATA_DIR/" 2>/dev/null || true

        # Verify files were copied
        FILE_COUNT=$(ls "$DATA_DIR"/*.json 2>/dev/null | wc -l)
        if [ "$FILE_COUNT" -gt 0 ]; then
            echo "✓ Copied $FILE_COUNT built-in report(s) to $DATA_DIR"
        else
            echo "⚠ No files were copied"
        fi
    else
        echo "→ Found existing data in $DATA_DIR, preserving existing files"
        echo "   To use built-in reports, clear the directory first:"
        echo "   rm $DATA_DIR/*.json"
    fi
else
    echo "→ No built-in reports found in $GENERATED_DIR"
    echo "   Run 'make report' to generate reports first"
fi

echo ""
echo "Available JSON reports in $DATA_DIR:"
ls -lh "$DATA_DIR"/*.json 2>/dev/null || echo "  (none found)"
echo ""

echo "Starting dashboard..."
echo "Data directory: $DATA_DIR"
echo "Dashboard URL: http://0.0.0.0:${PORT:-5000}"
echo "================================================"
echo ""

# Start dashboard with all reports from DATA_DIR
# Pass any additional arguments from command line
cd "$DASHBOARD_DIR"
if [ -n "$PORT" ]; then
    exec python3 run_dashboard.py --reports "$DATA_DIR" --port "$PORT" "$@"
else
    exec python3 run_dashboard.py --reports "$DATA_DIR" "$@"
fi
