#!/bin/bash
set -e

echo "================================================"
echo "  Regulus Performance Dashboard"
echo "================================================"

# Check if data directory is empty
if [ ! "$(ls -A /app/data 2>/dev/null)" ]; then
    echo "→ Data directory is empty"
    if [ -d "/app/initial_data" ] && [ "$(ls -A /app/initial_data/*.json 2>/dev/null)" ]; then
        echo "→ Copying initial sample JSON files to /app/data..."
        cp /app/initial_data/*.json /app/data/ 2>/dev/null || true
        
        # Verify files were copied
        FILE_COUNT=$(ls /app/data/*.json 2>/dev/null | wc -l)
        if [ "$FILE_COUNT" -gt 0 ]; then
            echo "✓ Copied $FILE_COUNT sample file(s)"
            echo ""
            echo "Sample files are now in your host directory:"
            echo "  /tmp/regulus-data/"
            echo ""
            echo "To remove sample files:"
            echo "  rm /tmp/regulus-data/*.json"
        else
            echo "⚠ No files were copied"
        fi
    else
        echo "→ No initial sample data found"
        echo "→ Add JSON files to /tmp/regulus-data/ to get started"
    fi
else
    echo "→ Found existing data in /app/data"
fi

# List available JSON files
echo ""
echo "Available JSON reports:"
ls -lh /app/data/*.json 2>/dev/null || echo "  (none found)"

echo ""
echo "Dashboard starting on port 5000..."
echo "Data directory: /app/data (mounted from host)"
echo "================================================"
echo ""

# Execute the command passed to docker run
exec "$@"
