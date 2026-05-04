#!/bin/bash
#
# verify-cpu-metrics.sh - Verify CPU metrics in result-summary.txt match crucible data
#
# This script verifies that the CPU metrics reported in result-summary.txt accurately
# reflect the actual CPU usage from the crucible/opensearch database. It always queries
# opensearch directly to verify against the source of truth (it intentionally ignores
# new-gen-summary.txt to catch cases where that file may have been generated incorrectly).
#
# Features:
#   - Extracts CPU values from YAML-format result-summary.txt (supports multiple iterations)
#   - Always queries crucible/opensearch HTTP API directly (source of truth)
#   - Groups periods by iteration and averages samples correctly
#   - Reports per-iteration differences and maximum mismatch
#   - Categorizes severity: MINOR (<0.1%), MODERATE (0.1-1.0%), MAJOR (>1.0%)
#
# Usage:
#   verify-cpu-metrics.sh [RUN_DIR]
#
# Arguments:
#   RUN_DIR        Path to run directory containing result-summary.txt and new-gen-summary.txt
#                  Can be relative or absolute path. Defaults to current directory if not specified.
#
# Exit Codes:
#   0 = Success (CPU values match or difference < 0.1%)
#   1 = Moderate mismatch (difference between 0.1% and 1.0%)
#   2 = Major mismatch (difference > 1.0%)
#
# Examples:
#   # Verify a specific run (relative path)
#   cd /path/to/regulus && source bootstrap.sh
#   verify-cpu-metrics.sh 1_GROUP/PAO/4IP/INTER-NODE/TCP/2-POD/run-fri-nicmode-ovs-2025-12-12-22:06:28
#
#   # Verify using absolute path
#   verify-cpu-metrics.sh /full/path/to/run-directory
#
#   # Verify current directory
#   cd 1_GROUP/PAO/4IP/INTER-NODE/TCP/2-POD/run-fri-nicmode-ovs-2025-12-12-22:06:28
#   verify-cpu-metrics.sh .
#
#   # Use in fixme workflow (verify after fixing)
#   cd 1_GROUP/PAO/4IP/INTER-NODE/TCP/2-POD
#   fixme run-fri-nicmode-ovs-2025-12-12-22:06:28
#   verify-cpu-metrics.sh run-fri-nicmode-ovs-2025-12-12-22:06:28
#
#   # Verify all runs in a directory
#   for run in run-*/; do
#       echo "Verifying $run..."
#       verify-cpu-metrics.sh "$run"
#       echo ""
#   done
#
#   # Check exit code programmatically
#   if verify-cpu-metrics.sh run-xxx; then
#       echo "CPU metrics verified successfully"
#   else
#       echo "CPU metrics verification failed (exit code: $?)"
#   fi
#
# Requirements:
#   - jq command (for JSON parsing of crucible responses)
#   - bc command (for floating point arithmetic)
#   - Access to crucible/opensearch HTTP API (default: http://localhost:3000)
#   - Run directory must contain result-summary.txt
#   - Run must be indexed in crucible database (crucible index <blob-dir>)
#
# Environment Variables:
#   CRUCIBLE_API_URL   Crucible HTTP API endpoint (default: http://localhost:3000)
#   REG_ROOT           Regulus root directory (auto-detected if not set)
#

# Don't use set -e because bc/comparison commands may return non-zero without indicating failure
# and we want the script to complete even if some queries fail

# Auto-detect REG_ROOT if not set
if [ -z "$REG_ROOT" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    export REG_ROOT="$(dirname "$SCRIPT_DIR")"
    echo "[WARN] REG_ROOT not set. Auto-detected: $REG_ROOT" >&2
fi

# Load HTTP API optimization if available
if [ -f "${REG_ROOT}/bin/crucible-opensearch-fast.sh" ]; then
    source "${REG_ROOT}/bin/crucible-opensearch-fast.sh"
fi

# Ensure CRUCIBLE_API_URL is set
: ${CRUCIBLE_API_URL:=http://localhost:3000}
export CRUCIBLE_API_URL

# Parse arguments
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    cat <<'EOF'
Usage: verify-cpu-metrics.sh [RUN_DIR]

Verify CPU metrics in result-summary.txt match crucible/opensearch data.

ARGUMENTS:
  RUN_DIR              Path to run directory (relative or absolute)
                       Must be actual path - does NOT search recursively like fixme
                       Defaults to current directory if not specified

OPTIONS:
  --help, -h           Show this help message

EOF
    exit 0
fi

RUN_DIR="${1:-.}"

if [ ! -d "$RUN_DIR" ]; then
    echo "Error: Run directory not found: $RUN_DIR" >&2
    exit 1
fi

RESULT_SUMMARY="$RUN_DIR/result-summary.txt"
NEW_GEN_SUMMARY="$RUN_DIR/new-gen-summary.txt"

if [ ! -f "$RESULT_SUMMARY" ]; then
    echo "Error: result-summary.txt not found in $RUN_DIR" >&2
    exit 1
fi

echo "=========================================="
echo "Verifying CPU Metrics"
echo "=========================================="
echo "Run: $RUN_DIR"
echo ""

# Check if jq is available (needed for crucible queries, not for YAML parsing)
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed" >&2
    exit 1
fi

# Extract reported CPU values from result-summary.txt (YAML format)
# The CPU value is embedded in result lines like: "result: (...) CPU: 0.6691"
# There may be multiple iterations, each with their own CPU value
REPORTED_CPUS=$(grep -oP 'CPU:\s+\K[0-9.]+' "$RESULT_SUMMARY" 2>/dev/null)

if [ -z "$REPORTED_CPUS" ]; then
    echo "❌ Could not extract CPU values from result-summary.txt"
    echo ""
    echo "Showing CPU-related lines:"
    grep -i "cpu" "$RESULT_SUMMARY" 2>/dev/null | head -10
    exit 1
fi

# Count how many iterations
REPORTED_CPU_COUNT=$(echo "$REPORTED_CPUS" | wc -l)
echo "📄 Reported CPU values in result-summary.txt ($REPORTED_CPU_COUNT iterations):"
echo "$REPORTED_CPUS" | awk '{print "   " $0 "%"}'
echo ""

# Always query crucible/opensearch directly for true verification
# NOTE: We intentionally ignore new-gen-summary.txt to verify against source of truth
echo "📡 Querying crucible/opensearch database for actual CPU (source of truth)..."
echo ""

# Extract period IDs from result-summary.txt (YAML format)
# Look for lines like: "primary period-id: 47979C92-D94E-11F0-8EA2-85E573AED17C"
PERIODS=$(grep -oP 'primary period-id:\s+\K[A-F0-9-]+' "$RESULT_SUMMARY" 2>/dev/null)

if [ -z "$PERIODS" ]; then
    echo "❌ Could not extract period IDs from result-summary.txt"
    exit 1
fi

PERIOD_COUNT=$(echo "$PERIODS" | wc -l)
echo "Found $PERIOD_COUNT period(s) to verify"

# Pre-flight checks: Verify run is ready for verification
echo ""
echo "Checking verification prerequisites..."

# 1. Check if crucible HTTP API is accessible
if ! curl -s -m 5 "${CRUCIBLE_API_URL}/api/v1/runs" >/dev/null 2>&1; then
    echo "❌ Cannot reach crucible HTTP API at ${CRUCIBLE_API_URL}"
    echo ""
    echo "💡 Troubleshooting:"
    echo "   - Check if crucible is running"
    echo "   - Verify CRUCIBLE_API_URL is correct (current: ${CRUCIBLE_API_URL})"
    echo "   - Try: curl ${CRUCIBLE_API_URL}/api/v1/runs"
    exit 1
fi
echo "✓ Crucible HTTP API accessible"

# 2. Extract run-id from blob directory or archive
BLOB_DIRS=($(find "$RUN_DIR" -maxdepth 1 -type d \( -name "iperf--*" -o -name "uperf--*" \) 2>/dev/null))
BLOB_ARCHIVES=($(find "$RUN_DIR" -maxdepth 1 -type f \( -name "iperf--*.tgz" -o -name "uperf--*.tgz" \) 2>/dev/null))

if [ ${#BLOB_DIRS[@]} -eq 0 ] && [ ${#BLOB_ARCHIVES[@]} -eq 0 ]; then
    echo "❌ No benchmark blobs found (neither directories nor .tgz archives)"
    echo ""
    echo "💡 This run appears incomplete - verification cannot proceed"
    exit 1
fi

# Extract run-id from first blob (directory or archive)
if [ ${#BLOB_DIRS[@]} -gt 0 ]; then
    FIRST_BLOB=$(basename "${BLOB_DIRS[0]}")
else
    FIRST_BLOB=$(basename "${BLOB_ARCHIVES[0]%.tgz}")
fi

RUN_ID=$(echo "$FIRST_BLOB" | grep -oP '(?<=--)[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')

if [ -z "$RUN_ID" ]; then
    echo "❌ Could not extract run-id from blob name: $FIRST_BLOB"
    exit 1
fi
echo "✓ Run ID: $RUN_ID"

# 3. Check if run is indexed in crucible database
CRUCIBLE_RUN_IDS=$(curl -s "${CRUCIBLE_API_URL}/api/v1/runs" 2>/dev/null | grep -o '"[0-9a-f-]*"' | tr -d '"')
if ! echo "$CRUCIBLE_RUN_IDS" | grep -q "^${RUN_ID}$"; then
    echo "❌ Run not indexed in crucible database"
    echo ""
    echo "💡 Run needs to be indexed first:"
    if [ ${#BLOB_ARCHIVES[@]} -gt 0 ] && [ ${#BLOB_DIRS[@]} -eq 0 ]; then
        echo "   - Blobs are compressed (.tgz) - need extraction and indexing"
        echo "   - Run: fixme $(basename "$RUN_DIR")"
    else
        echo "   - Run: crucible index $RUN_DIR/${FIRST_BLOB}"
        echo "   - Or run: fixme $(basename "$RUN_DIR")"
    fi
    exit 1
fi
echo "✓ Run indexed in crucible database"

# 4. Warn if blobs are compressed (verification will work but slower than after fixme)
if [ ${#BLOB_ARCHIVES[@]} -gt 0 ] && [ ${#BLOB_DIRS[@]} -eq 0 ]; then
    echo "⚠️  Blobs are compressed - verification will query database only"
    echo "   (This is fine, but fixme would extract and optimize summaries)"
fi

echo ""

# Extract hostnames from nodeSelector files
HOSTNAMES=()
for file in "$RUN_DIR"/nodeSelector-*.json; do
    if [ -f "$file" ]; then
        hostname=$(basename "$file" | sed 's/nodeSelector-//; s/.json//')
        HOSTNAMES+=("$hostname")
    fi
done

if [ ${#HOSTNAMES[@]} -eq 0 ]; then
    echo "⚠️  No nodeSelector files found - will query all nodes"
    QUERY_BREAKOUT=""
else
    echo "Worker nodes: ${HOSTNAMES[*]}"
    QUERY_BREAKOUT="hostname"
fi

# Query crucible for each period and collect CPU values
# Group periods into iterations based on result-summary.txt structure
declare -a ACTUAL_CPUS
readarray -t PERIOD_ARRAY <<< "$PERIODS"
readarray -t REPORTED_ARRAY <<< "$REPORTED_CPUS"

# Calculate number of samples per iteration (periods / iterations)
SAMPLES_PER_ITERATION=$(( PERIOD_COUNT / REPORTED_CPU_COUNT ))

if [ $SAMPLES_PER_ITERATION -lt 1 ]; then
    SAMPLES_PER_ITERATION=1
fi

echo "Detected $REPORTED_CPU_COUNT iteration(s) with $SAMPLES_PER_ITERATION sample(s) each"
echo ""

# Query and average CPU for each iteration
for (( iter=0; iter<REPORTED_CPU_COUNT; iter++ )); do
    ITER_CPU_SUM=0
    ITER_SAMPLES=0

    # Calculate which periods belong to this iteration
    START_IDX=$(( iter * SAMPLES_PER_ITERATION ))
    END_IDX=$(( START_IDX + SAMPLES_PER_ITERATION ))

    echo "Iteration $((iter+1)):"

    for (( pidx=START_IDX; pidx<END_IDX && pidx<PERIOD_COUNT; pidx++ )); do
        PERIOD="${PERIOD_ARRAY[$pidx]}"
        echo -n "  Querying period ${PERIOD:0:8}... "

        # Query crucible for CPU metric
        if [ ${#HOSTNAMES[@]} -eq 0 ]; then
            # No hostnames - query all
            CPU_VALUE=$(curl -s -X POST "${CRUCIBLE_API_URL}/api/v1/metric-data" \
                -H 'Content-Type: application/json' \
                -d "{\"period\": \"$PERIOD\", \"source\": \"mpstat\", \"type\": \"Busy-CPU\"}" 2>/dev/null | \
                jq -r '.values[][].value' 2>/dev/null | head -1)
        else
            # Query for each hostname and sum
            CPU_VALUE=0
            for hostname in "${HOSTNAMES[@]}"; do
                HOST_CPU=$(curl -s -X POST "${CRUCIBLE_API_URL}/api/v1/metric-data" \
                    -H 'Content-Type: application/json' \
                    -d "{\"period\": \"$PERIOD\", \"source\": \"mpstat\", \"type\": \"Busy-CPU\", \"breakout\": \"hostname=$hostname\"}" 2>/dev/null | \
                    jq -r ".values[\"<$hostname>\"][].value" 2>/dev/null)

                if [ -n "$HOST_CPU" ]; then
                    CPU_VALUE=$(echo "$CPU_VALUE + $HOST_CPU" | bc 2>/dev/null)
                fi
            done
        fi

        if [ -n "$CPU_VALUE" ] && [ "$CPU_VALUE" != "null" ]; then
            echo "${CPU_VALUE}%"
            ITER_CPU_SUM=$(echo "$ITER_CPU_SUM + $CPU_VALUE" | bc 2>/dev/null)
            ((ITER_SAMPLES++))
        else
            echo "ERROR (no data)"
        fi
    done

    # Calculate average for this iteration
    if [ $ITER_SAMPLES -gt 0 ]; then
        ITER_AVG=$(echo "scale=4; $ITER_CPU_SUM / $ITER_SAMPLES" | bc 2>/dev/null)
        ACTUAL_CPUS+=("$ITER_AVG")
        echo "  → Iteration $((iter+1)) average: ${ITER_AVG}%"
    else
        echo "  → ERROR: No data for iteration $((iter+1))"
        ACTUAL_CPUS+=("")
    fi
    echo ""
done

# Display actual values
echo "📊 Actual CPU values from crucible/opensearch ($REPORTED_CPU_COUNT iterations):"
for (( i=0; i<${#ACTUAL_CPUS[@]}; i++ )); do
    echo "   ${ACTUAL_CPUS[$i]}%"
done
echo ""

# Compare iteration by iteration
MAX_DIFF=0
ALL_MATCH=true

for i in "${!REPORTED_ARRAY[@]}"; do
    if [ $i -lt ${#ACTUAL_CPUS[@]} ]; then
        REPORTED=${REPORTED_ARRAY[$i]}
        ACTUAL=${ACTUAL_CPUS[$i]}

        if [ -z "$ACTUAL" ]; then
            echo "⚠️  Iteration $((i+1)): No data from crucible"
            ALL_MATCH=false
            continue
        fi

        DIFF=$(echo "$ACTUAL - $REPORTED" | bc 2>/dev/null)
        ABS_DIFF=$(echo "$DIFF" | tr -d '-')

        # Track maximum difference
        if (( $(echo "$ABS_DIFF > $MAX_DIFF" | bc -l 2>/dev/null) )); then
            MAX_DIFF=$ABS_DIFF
        fi

        # Check if this iteration matches
        if (( $(echo "$ABS_DIFF >= 0.01" | bc -l 2>/dev/null) )); then
            ALL_MATCH=false
            echo "   Iteration $((i+1)): ${REPORTED}% vs ${ACTUAL}% (diff: ${DIFF}%)"
        fi
    fi
done

if [ "$ALL_MATCH" = true ]; then
    echo "✅ VERIFIED: All CPU values match (verified against crucible/opensearch)"
    exit 0
else
    echo ""
    echo "⚠️  MISMATCH: Maximum difference = ${MAX_DIFF}%"

    # Categorize the difference
    if (( $(echo "$MAX_DIFF < 0.1" | bc -l 2>/dev/null) )); then
        echo "   Severity: MINOR (< 0.1%)"
        exit 0
    elif (( $(echo "$MAX_DIFF < 1.0" | bc -l 2>/dev/null) )); then
        echo "   Severity: MODERATE (0.1% - 1.0%)"
        exit 1
    else
        echo "   Severity: MAJOR (> 1.0%)"
        echo ""
        echo "💡 Recommendation: Run fixme to regenerate CPU metrics"
        exit 2
    fi
fi
