#!/bin/bash
#
# crucible-opensearch-fast.sh - Fast metric queries using Crucible HTTP API
#
# This module provides drop-in replacements for crucible CLI commands
# using direct HTTP API calls to bypass CLI startup overhead (~7s → ~0.05s).
#
# Usage:
#   source crucible-opensearch-fast.sh
#   result=$(get_metric_fast --source mpstat --type Busy-CPU --period $PERIOD_ID ...)
#

# Crucible HTTP API connection settings
CRUCIBLE_API_HOST="${CRUCIBLE_API_HOST:-localhost}"
CRUCIBLE_API_PORT="${CRUCIBLE_API_PORT:-3000}"
CRUCIBLE_API_URL="http://${CRUCIBLE_API_HOST}:${CRUCIBLE_API_PORT}"

# Enable/disable fast path (set to 0 to always use CLI)
USE_FAST_API=${USE_FAST_API:-1}

# Debug mode
DEBUG_FAST_API=${DEBUG_FAST_API:-0}

debug_log() {
    if [ "$DEBUG_FAST_API" = "1" ]; then
        echo "[API-DEBUG] $*" >&2
    fi
}

# Get metric via Crucible HTTP API (bypasses CLI startup overhead)
# Usage: get_metric_http_api PERIOD_ID SOURCE TYPE [BREAKOUT]
get_metric_http_api() {
    local period_id="$1"
    local source="$2"
    local type="$3"
    local breakout="$4"

    debug_log "Querying via HTTP API: period=$period_id source=$source type=$type breakout=$breakout"

    # Build JSON payload
    local json_payload="{\"period\": \"${period_id}\", \"source\": \"${source}\", \"type\": \"${type}\""

    if [ -n "$breakout" ]; then
        json_payload="${json_payload}, \"breakout\": \"${breakout}\""
    fi

    json_payload="${json_payload}}"

    debug_log "POST ${CRUCIBLE_API_URL}/api/v1/metric-data"
    debug_log "Payload: $json_payload"

    # Query the HTTP API via POST
    local result=$(curl -s -X POST "${CRUCIBLE_API_URL}/api/v1/metric-data" \
        -H 'Content-Type: application/json' \
        -d "$json_payload" 2>/dev/null)

    if [ -z "$result" ] || echo "$result" | grep -q "error"; then
        debug_log "HTTP API query failed or returned error"
        return 1
    fi

    debug_log "HTTP API query successful"
    echo "$result"
    return 0
}

# Fast wrapper for "crucible get metric" command
# Attempts HTTP API first, falls back to CLI
get_metric_fast() {
    if [ "$USE_FAST_API" != "1" ]; then
        debug_log "Fast path disabled, using CLI"
        command crucible get metric "$@"
        return $?
    fi

    # Parse arguments
    local source="" type="" period="" breakout="" output_format="json"
    local orig_args=("$@")

    while [[ $# -gt 0 ]]; do
        case $1 in
            --source)
                source="$2"
                shift 2
                ;;
            --type)
                type="$2"
                shift 2
                ;;
            --period)
                period="$2"
                shift 2
                ;;
            --breakout)
                breakout="$2"
                shift 2
                ;;
            --output-format)
                output_format="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    # Try HTTP API if we have required parameters
    if [ -n "$source" ] && [ -n "$type" ] && [ -n "$period" ]; then
        debug_log "Trying HTTP API fast path"
        local result
        result=$(get_metric_http_api "$period" "$source" "$type" "$breakout")
        if [ $? -eq 0 ] && [ -n "$result" ]; then
            debug_log "HTTP API query successful"
            echo "$result"
            return 0
        else
            debug_log "HTTP API query failed, falling back to CLI"
        fi
    fi

    # Fallback to CLI
    debug_log "Using crucible CLI (slow path)"
    command crucible get metric "${orig_args[@]}"
}

# Export functions
export -f get_metric_fast
export -f get_metric_http_api
export -f debug_log

if [ "$DEBUG_FAST_API" = "1" ]; then
    debug_log "Crucible HTTP API fast query module loaded (${CRUCIBLE_API_URL})"
fi
