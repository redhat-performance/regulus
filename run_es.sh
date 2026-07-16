#!/bin/bash
# ElasticSearch Integration Script for CI/Production
# This script handles ES setup and data upload
# All ES_* credential determination happens HERE (outside $REG_ROOT/REPORT/)
#
# Usage:
#   ./run_es.sh              # Full workflow (setup + upload)
#   ./run_es.sh --setup-only # Only setup (template + ILM), skip upload
#   ./run_es.sh --skip-setup # Only upload, skip setup
#
# Run env: Runs on the Crucible controller (which is on the bastion in Prow CI environments)
#

set -e  # Exit on error
set -u  # Exit on undefined variable

# ============================================================================
# Parse Command Line Arguments
# ============================================================================

SKIP_SETUP=false
SETUP_ONLY=false

for arg in "$@"; do
    case $arg in
        --skip-setup)
            SKIP_SETUP=true
            shift
            ;;
        --setup-only)
            SETUP_ONLY=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --setup-only  Only run one-time setup (template + ILM), skip upload"
            echo "  --skip-setup  Skip ILM policy setup, only upload data (template still applied)"
            echo "  --help        Show this help message"
            echo ""
            echo "Default (no options): Run full workflow (setup + upload)"
            exit 0
            ;;
        *)
            # Unknown option
            ;;
    esac
done

# Determine REG_ROOT
REG_ROOT="${REG_ROOT:-$(cd "$(dirname "$0")" && pwd)}"
echo "REG_ROOT: $REG_ROOT"

# ============================================================================
# ES Configuration (from lab.config)
# ============================================================================

# Source lab.config (single source of truth)
if [ ! -f "$REG_ROOT/lab.config" ]; then
    echo "ERROR: $REG_ROOT/lab.config not found"
    echo "  Run: bash bin/reg-smart-config"
    exit 1
fi

source "$REG_ROOT/lab.config"

# Validate required ES variables
if [ -z "${ES_PROTOCOL:-}" ] || [ -z "${ES_HOST:-}" ]; then
    echo "ERROR: lab.config must define ES_PROTOCOL and ES_HOST"
    echo "  Run: bash bin/reg-smart-config"
    exit 1
fi

# Build ES_URL with proper URL encoding for special characters in passwords
if [ -n "${ES_USER:-}" ] && [ -n "${ES_PASSWORD:-}" ]; then
    ES_URL=$(ES_USER="$ES_USER" ES_PASSWORD="$ES_PASSWORD" python3 -c "
import os, urllib.parse
user = os.environ['ES_USER']
pwd = os.environ['ES_PASSWORD']
print('${ES_PROTOCOL}://' + urllib.parse.quote(user, safe='') + ':' + urllib.parse.quote(pwd, safe='') + '@${ES_HOST}')
")
else
    ES_URL="${ES_PROTOCOL}://${ES_HOST}"
fi

# Display configuration (sanitize credentials)
if [ -n "${ES_USER:-}" ]; then
    ES_URL_DISPLAY="${ES_PROTOCOL}://***:***@${ES_HOST}"
else
    ES_URL_DISPLAY="${ES_URL}"
fi

echo "=============================================="
echo "  ElasticSearch Configuration"
echo "=============================================="
echo "ES_PROTOCOL: $ES_PROTOCOL"
echo "ES_HOST:     $ES_HOST"
echo "ES_USER:     ${ES_USER:+***}"
echo "ES_PASSWORD: ${ES_PASSWORD:+***}"
echo "ES_URL:      $ES_URL_DISPLAY"
echo "=============================================="

# Export for makefile
export ES_URL

# ============================================================================
# Navigate to build_report directory
# ============================================================================

cd "$REG_ROOT/REPORT"

# ============================================================================
# Step 1: Check ES Connection
# ============================================================================

make es-check || {
    echo "ERROR: Cannot connect to ElasticSearch"
    exit 1
}

# ============================================================================
# Step 2: One-Time Setup (Template + ILM)
# ============================================================================

if [ "$SKIP_SETUP" = false ]; then
    echo "Applying ES template and ILM policy..."
    make es-template 2>&1 | grep -E "^✓|^ERROR" || true
    make es-ilm-policy 2>&1 | grep -E "^✓|^ERROR" || true
fi

if [ "$SETUP_ONLY" = true ]; then
    echo "✓ Setup complete (template + ILM policy configured)"
    echo "To upload data: $0 --skip-setup"
    exit 0
fi

# ============================================================================
# Step 3: Upload Data to ElasticSearch
# ============================================================================

echo "Uploading data to ES..."
make es-upload || {
    echo "ERROR: Failed to upload data to ES"
    exit 1
}

# ============================================================================
# Success Summary
# ============================================================================

echo "✓ Upload complete"
