#!/bin/bash
# ElasticSearch Cleanup Script (DEBUG/DEVELOPMENT ONLY)
#
# WARNING: This is a debug/development tool for cleaning up ES indices during testing.
#          DO NOT use in production environments. There is no justification for
#          production use - data in production should be managed via ILM/ISM policies.
#
# Removes ILM/ISM policies, index templates, and indices
# All ES_* credential determination happens HERE (outside REPORT/)
#
# Usage:
#   ./cleanup_es.sh                    # Interactive mode with confirmations
#   ./cleanup_es.sh --all              # Delete everything (policy + template + indices)
#   ./cleanup_es.sh --policy           # Delete only ILM/ISM policy
#   ./cleanup_es.sh --template         # Delete only index template
#   ./cleanup_es.sh --indices          # Delete only indices matching pattern
#   ./cleanup_es.sh --force            # Skip confirmations (dangerous!)

set -e  # Exit on error
set -u  # Exit on undefined variable

# ============================================================================
# Parse Command Line Arguments
# ============================================================================

DELETE_POLICY=false
DELETE_TEMPLATE=false
DELETE_INDICES=false
DELETE_ALL=false
FORCE=false

if [ $# -eq 0 ]; then
    # No arguments = interactive mode
    DELETE_ALL=true
else
    for arg in "$@"; do
        case $arg in
            --all)
                DELETE_ALL=true
                shift
                ;;
            --policy)
                DELETE_POLICY=true
                shift
                ;;
            --template)
                DELETE_TEMPLATE=true
                shift
                ;;
            --indices)
                DELETE_INDICES=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --all        Delete everything (policy + template + indices)"
                echo "  --policy     Delete only ILM/ISM policy"
                echo "  --template   Delete only index template"
                echo "  --indices    Delete only indices matching pattern"
                echo "  --force      Skip confirmations (dangerous!)"
                echo "  --help       Show this help message"
                echo ""
                echo "Default (no options): Interactive mode with confirmations"
                echo ""
                echo "Examples:"
                echo "  $0                    # Interactive cleanup"
                echo "  $0 --all --force      # Delete everything without confirmation"
                echo "  $0 --indices          # Delete only indices (with confirmation)"
                exit 0
                ;;
            *)
                echo "Unknown option: $arg"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
fi

# If --all is set, enable all deletions
if [ "$DELETE_ALL" = true ]; then
    DELETE_POLICY=true
    DELETE_TEMPLATE=true
    DELETE_INDICES=true
fi

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

# Export for detect_platform.sh
export ES_URL
export ES_INDEX

# ============================================================================
# Detect Platform
# ============================================================================

cd "$REG_ROOT/REPORT/build_report"

echo ""
echo "Detecting ElasticSearch/OpenSearch platform..."
eval $(es_integration/detect_platform.sh)
echo "Detected platform: $PLATFORM (version $VERSION)"

# ============================================================================
# Build curl command (auth is embedded in ES_URL)
# ============================================================================

CURL_CMD="curl -s"

# ============================================================================
# Confirmation Function
# ============================================================================

confirm() {
    local message="$1"

    if [ "$FORCE" = true ]; then
        echo "$message [FORCED]"
        return 0
    fi

    echo ""
    read -p "$message (yes/no): " response
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            echo "Skipped."
            return 1
            ;;
    esac
}

# ============================================================================
# Delete ILM/ISM Policy
# ============================================================================

if [ "$DELETE_POLICY" = true ]; then
    echo ""
    echo "=============================================="
    echo "  Delete ILM/ISM Policy"
    echo "=============================================="
    echo "Platform: $PLATFORM"
    echo "Policy: $POLICY_NAME"
    echo "Endpoint: $ES_URL$POLICY_ENDPOINT/$POLICY_NAME"

    if confirm "Delete ILM/ISM policy '$POLICY_NAME'?"; then
        RESPONSE=$($CURL_CMD -X DELETE "$ES_URL$POLICY_ENDPOINT/$POLICY_NAME")
        echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"

        if echo "$RESPONSE" | grep -q '"acknowledged".*:.*true'; then
            echo "✓ Policy deleted successfully"
        else
            echo "⚠ Policy deletion response (may not exist):"
            echo "$RESPONSE"
        fi
    fi
fi

# ============================================================================
# Delete Index Template
# ============================================================================

if [ "$DELETE_TEMPLATE" = true ]; then
    echo ""
    echo "=============================================="
    echo "  Delete Index Template"
    echo "=============================================="
    echo "Template: regulus-template"
    echo "Endpoint: $ES_URL/_index_template/regulus-template"

    if confirm "Delete index template 'regulus-template'?"; then
        RESPONSE=$($CURL_CMD -X DELETE "$ES_URL/_index_template/regulus-template")
        echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"

        if echo "$RESPONSE" | grep -q '"acknowledged".*:.*true'; then
            echo "✓ Template deleted successfully"
        else
            echo "⚠ Template deletion response (may not exist):"
            echo "$RESPONSE"
        fi
    fi
fi

# ============================================================================
# Delete Indices
# ============================================================================

if [ "$DELETE_INDICES" = true ]; then
    echo ""
    echo "=============================================="
    echo "  Delete Indices"
    echo "=============================================="
    echo "Index pattern: ${ES_INDEX}*"
    echo ""

    # List matching indices first
    echo "Matching indices:"
    INDICES=$($CURL_CMD "$ES_URL/_cat/indices/${ES_INDEX}*?h=index" 2>/dev/null || echo "")

    if [ -z "$INDICES" ]; then
        echo "  No indices found matching pattern: ${ES_INDEX}*"
    else
        echo "$INDICES" | while read -r index; do
            [ -n "$index" ] && echo "  - $index"
        done
        echo ""

        if confirm "Delete ALL indices matching '${ES_INDEX}*'?"; then
            RESPONSE=$($CURL_CMD -X DELETE "$ES_URL/${ES_INDEX}*")
            echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"

            if echo "$RESPONSE" | grep -q '"acknowledged".*:.*true'; then
                echo "✓ Indices deleted successfully"
            else
                echo "⚠ Indices deletion response:"
                echo "$RESPONSE"
            fi
        fi
    fi
fi

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "=============================================="
echo "  Cleanup Summary"
echo "=============================================="
echo ""

if [ "$DELETE_POLICY" = true ]; then
    echo "✓ Policy cleanup: Attempted"
fi

if [ "$DELETE_TEMPLATE" = true ]; then
    echo "✓ Template cleanup: Attempted"
fi

if [ "$DELETE_INDICES" = true ]; then
    echo "✓ Indices cleanup: Attempted"
fi

echo ""
echo "Verification commands:"
echo "  Check remaining indices:  curl $ES_URL/_cat/indices"
echo "  Check template:           curl $ES_URL/_index_template/regulus-template"
echo "  Check policy:             curl $ES_URL$POLICY_ENDPOINT/$POLICY_NAME"
echo "=============================================="
