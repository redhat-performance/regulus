#!/bin/bash
# Test the Regulus MCP server using the MCP inspector

# Source ES configuration from parent REPORT directory
# Priority: ES_URL env var > /secret > lab.config
if [ -z "${ES_URL:-}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

# Set ES_INDEX if not already set
export ES_INDEX="${ES_INDEX:-regulus-results}"

# Activate virtual environment
source .venv/bin/activate

# Install inspector if not already installed
pip install mcp 2>/dev/null

# Run inspector
echo "Starting MCP Inspector..."
echo "This will open an interactive interface to test the MCP server"
echo ""
mcp dev regulus_es_mcp.py
