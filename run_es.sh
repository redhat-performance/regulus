#!/bin/bash
# ElasticSearch Integration Script for CI/Production
# This script handles ES setup and data upload
# All ES_* credential determination happens HERE (outside $REG_ROOT/REPORT/)
#
# Usage:
#   ./run_es.sh              # Full workflow (setup + upload)
#   ./run_es.sh --setup-only # Only setup (template + ILM), skip upload
#   ./run_es.sh --skip-setup # Only upload, skip setup

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
            echo "  --skip-setup  Skip one-time setup, only upload data"
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
# ES Configuration Determination (OUTSIDE REPORT/)
# ============================================================================

# Note: Do NOT initialize ES_URL here - check if it's already set from environment
ES_INDEX="${ES_INDEX:-regulus-results}"

# Priority 1: ES_URL directly provided (simplest case)
if [ -n "${ES_URL:-}" ]; then
    echo "Mode: Using ES_URL from environment variable"
    # ES_URL already set, nothing to do

# Priority 2: ci-tools (Prow) secrets (production)
elif [ -d "/secret" ]; then
    echo "Mode: Production - Reading credentials from /secret/*"
    ES_USER=$(cat /secret/username 2>/dev/null || echo "")
    ES_PASSWORD=$(cat /secret/password 2>/dev/null || echo "")
    ES_HOST=$(cat /secret/host 2>/dev/null || echo "")

    if [ -z "$ES_HOST" ]; then
        echo "ERROR: /secret/host is empty or not readable"
        exit 1
    fi

    # Build ES_URL (production always uses HTTPS)
    if [ -n "$ES_USER" ] && [ -n "$ES_PASSWORD" ]; then
        ES_URL="https://${ES_USER}:${ES_PASSWORD}@${ES_HOST}"
    else
        ES_URL="https://${ES_HOST}"
    fi

# Priority 3: lab.config (development/testing)
elif [ -f "$REG_ROOT/lab.config" ]; then
    echo "Mode: Development - Reading ES_URL from lab.config"
    source "$REG_ROOT/lab.config"

    # lab.config must provide ES_URL directly
    if [ -z "${ES_URL:-}" ]; then
        echo "ERROR: lab.config must define ES_URL"
        echo "  Example: ES_URL=\"https://user:password@host.example.com\""
        exit 1
    fi

# No credentials available
else
    echo "ERROR: No ES configuration found."
    echo "  - No ES_URL environment variable"
    echo "  - No /secret/ directory (Kubernetes secrets)"
    echo "  - No $REG_ROOT/lab.config file"
    exit 1
fi

# ============================================================================
# Validate ES Configuration
# ============================================================================

if [ -z "$ES_URL" ]; then
    echo "ERROR: ES_URL could not be determined"
    exit 1
fi

# Extract host from ES_URL for display (hide credentials)
ES_URL_DISPLAY=$(echo "$ES_URL" | sed -E 's|(https?://)([^:]+):([^@]+)@|\1***:***@|')

echo "=============================================="
echo "  ElasticSearch Configuration"
echo "=============================================="
echo "ES_URL:      $ES_URL_DISPLAY"
echo "ES_INDEX:    $ES_INDEX"
echo "=============================================="

# Export for makefile
export ES_URL
export ES_INDEX

# ============================================================================
# Navigate to build_report directory
# ============================================================================

cd "$REG_ROOT/REPORT/build_report"

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

echo "✓ Upload complete to index: $ES_INDEX"
