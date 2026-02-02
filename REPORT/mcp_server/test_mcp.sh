#!/bin/bash
# Test the Regulus MCP server using the MCP inspector

# Set environment variables
export ES_URL='https://admin:nKNQ9=vw_bwaSy1@search-perfscale-pro-wxrjvmobqs7gsyi3xvxkqmn7am.us-west-2.es.amazonaws.com'
export ES_INDEX='regulus-results'

# Activate virtual environment
source .venv/bin/activate

# Install inspector if not already installed
pip install mcp 2>/dev/null

# Run inspector
echo "Starting MCP Inspector..."
echo "This will open an interactive interface to test the MCP server"
echo ""
mcp dev regulus_es_mcp.py
