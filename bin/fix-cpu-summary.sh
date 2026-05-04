#!/bin/bash
#
# fix-cpu-summary.sh - Fix CPU metrics in previous benchmark runs
#
# This script fixes the bug where reg-gen-summary couldn't find nodeSelector files
# and collected CPU from all nodes instead of just the worker nodes.
#
# Features:
#   - Automatically extracts compressed blobs (.tgz files)
#   - Re-indexes missing runs into crucible database
#   - Fixes CPU metrics to only include worker nodes
#   - Uses HTTP API for fast run ID checking
#   - Force re-fix option to regenerate already-fixed runs
#
# Usage:
#   Recommended: source bootstrap.sh first, then run fixme
#   fixme [--dryrun] [--force] [--port PORT] [RUN_DIR]
#
# Options:
#   --dryrun       Report what would be fixed without making changes
#   --force        Force re-fix even if run appears already fixed
#                  Use when you want to regenerate summaries with updated
#                  scripts or when you suspect the fix was incomplete
#   --port PORT    Crucible HTTP API port (default: 3000)
#
# Examples:
#   # Check what needs fixing
#   cd /path/to/regulus && source bootstrap.sh
#   cd 2_GROUP/PAO/4DPU/INTER-NODE/TCP/2-POD-GU
#   fixme --dryrun
#
#   # Fix all runs in current directory
#   fixme
#
#   # Force re-fix a specific run (regenerate even if already fixed)
#   fixme --force run-30pod-2026-05-01-17:34:37
#
#   # Force re-fix all runs in current directory
#   fixme --force
#

# Auto-detect REG_ROOT if not set (assumes fixme is in bin/ subdirectory)
if [ -z "$REG_ROOT" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    export REG_ROOT="$(dirname "$SCRIPT_DIR")"
    echo "[WARN] REG_ROOT not set. Auto-detected: $REG_ROOT" >&2
    echo "[WARN] For best results, source bootstrap.sh first" >&2
fi

set -e

DRYRUN=false
FORCE=false
SPECIFIC_RUN_DIR=""
CRUCIBLE_PORT=3000

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry|--dryrun|--dry-run)
            DRYRUN=true
            shift
            ;;
        --force|-f)
            FORCE=true
            shift
            ;;
        --port)
            if [ -z "$2" ] || [[ "$2" =~ ^- ]]; then
                echo "Error: --port requires a port number"
                exit 1
            fi
            CRUCIBLE_PORT="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS] [RUN_DIR]"
            echo ""
            echo "Fix CPU metrics in benchmark runs by re-running reg-gen-summary"
            echo "with proper nodeSelector files."
            echo ""
            echo "Options:"
            echo "  --dryrun       Report what would be fixed without making changes"
            echo "  --force        Force re-fix even if run appears already fixed"
            echo "                 By default, fixme skips runs that have worker hostnames"
            echo "                 in new-gen-summary.txt (indicating they were already fixed)."
            echo "                 Use --force to regenerate summaries anyway."
            echo ""
            echo "                 Use cases for --force:"
            echo "                   - Regenerate summaries after updating reg-gen-summary script"
            echo "                   - Re-fix runs where the previous fix may have been incomplete"
            echo "                   - Update CPU metrics after changing nodeSelector files"
            echo "                   - Verify CPU metrics match crucible data"
            echo ""
            echo "  --port PORT    Crucible HTTP API port (default: 3000)"
            echo "  --help         Show this help message"
            echo ""
            echo "Arguments:"
            echo "  RUN_DIR        Specific run directory to fix (e.g., run-30proc-2026-05-01-14:42:51)"
            echo "                 If not specified, all run-* directories will be processed"
            echo ""
            echo "Examples:"
            echo "  # Check what needs fixing"
            echo "  fixme --dryrun"
            echo ""
            echo "  # Fix all runs needing repair"
            echo "  fixme"
            echo ""
            echo "  # Force re-fix a specific run"
            echo "  fixme --force run-30pod-2026-05-01-17:34:37"
            echo ""
            echo "  # Force re-fix all runs in current directory"
            echo "  fixme --force"
            exit 0
            ;;
        -*)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
        *)
            # This is a positional argument (run directory)
            SPECIFIC_RUN_DIR="$1"
            shift
            ;;
    esac
done

log_info() {
    echo "[INFO] $1"
}

log_warn() {
    echo "[WARN] $1"
}

log_error() {
    echo "[ERROR] $1"
}

log_dryrun() {
    echo "[DRYRUN] $1"
}

# Find all test directories (directories containing run-* subdirectories)
# Excludes directories that are themselves run-* directories
find_test_dirs() {
    # Find all run-* directories, get their parent directories, and make unique
    find "$PWD" -type d -name "run-*" 2>/dev/null | while read -r run_dir; do
        parent=$(dirname "$run_dir")
        # Make sure parent itself is not a run-* directory
        parent_name=$(basename "$parent")
        if [[ ! "$parent_name" =~ ^run- ]]; then
            echo "$parent"
        fi
    done | sort -u
}

# Check if new-gen-summary.txt has empty hostnames (indicates bug)
# Returns 0 if NEEDS FIX (empty hostnames), 1 if OK (has hostnames)
check_needs_fix() {
    local run_dir="$1"
    local summary_file="$run_dir/new-gen-summary.txt"

    # If summary doesn't exist, needs fix
    if [ ! -f "$summary_file" ]; then
        return 0
    fi

    # Extract lines between "Hostnames:" and "CPUs:"
    # If there are hostname entries, they appear as "  hostname.example.com"
    local hostname_count=$(sed -n '/^Hostnames:/,/^CPUs:/p' "$summary_file" | \
                          grep -E "^\s+[a-zA-Z0-9.-]+\.[a-zA-Z]+$" | \
                          wc -l)

    if [ "$hostname_count" -eq 0 ]; then
        # Empty hostnames - NEEDS FIX
        return 0
    else
        # Has hostnames - OK
        return 1
    fi
}

# Re-index a crucible run by importing the benchmark blob back into the database
reindex_crucible_run() {
    local run_id="$1"
    local run_dir="$2"
    local extracted_for_reindex=false
    local extracted_dir=""

    # Find the benchmark blob directory (iperf--*, uperf--*, etc.)
    local blob_dirs=($(find "$run_dir" -maxdepth 1 -type d \( -name "iperf--*" -o -name "uperf--*" -o -name "*--*--$run_id" \) 2>/dev/null))

    # Also check for .tgz archives (only extract if directory doesn't exist)
    if [ ${#blob_dirs[@]} -eq 0 ]; then
        local blob_archives=($(find "$run_dir" -maxdepth 1 -type f \( -name "iperf--*.tgz" -o -name "uperf--*.tgz" -o -name "*--*--$run_id.tgz" \) 2>/dev/null))

        if [ ${#blob_archives[@]} -gt 0 ]; then
            local archive="${blob_archives[0]}"
            extracted_dir="${archive%.tgz}"

            if [ ! -d "$extracted_dir" ]; then
                log_info "    Found compressed blob, extracting..."
                local start_time=$(date +%s)
                if tar --force-local -xzf "$archive" -C "$run_dir" 2>&1; then
                    local end_time=$(date +%s)
                    local elapsed=$((end_time - start_time))
                    log_info "    ✓ Extraction completed in ${elapsed}s"
                    extracted_for_reindex=true
                else
                    log_error "    Failed to extract archive: $(basename "$archive")"
                    return 1
                fi
            else
                log_info "    Blob directory already exists (skipping extraction)"
            fi

            # Re-check for extracted directory
            blob_dirs=($(find "$run_dir" -maxdepth 1 -type d \( -name "iperf--*" -o -name "uperf--*" -o -name "*--*--$run_id" \) 2>/dev/null))
        fi
    fi

    if [ ${#blob_dirs[@]} -eq 0 ]; then
        log_error "    Could not find benchmark blob directory for run-id: $run_id"
        return 1
    fi

    # Get the full absolute path to the blob directory
    local blob_dir=$(realpath "${blob_dirs[0]}")

    if [ -z "$blob_dir" ] || [ ! -d "$blob_dir" ]; then
        log_error "    Invalid blob directory path: $blob_dir"
        return 1
    fi

    # Run crucible index
    log_info "    Running: crucible index $blob_dir"
    local index_start=$(date +%s)
    if crucible index "$blob_dir" >/dev/null 2>&1; then
        local index_end=$(date +%s)
        local index_elapsed=$((index_end - index_start))
        log_info "    ✓ Successfully re-indexed run: $run_id (took ${index_elapsed}s)"

        # Clean up extracted directory if we extracted it for re-indexing
        if [ "$extracted_for_reindex" = true ] && [ -n "$extracted_dir" ] && [ -d "$extracted_dir" ]; then
            log_info "    Cleaning up extracted directory (keeping .tgz)..."
            rm -rf "$extracted_dir"
        fi

        return 0
    else
        log_error "    ✗ Failed to re-index run: $run_id"

        # Clean up extracted directory even on failure
        if [ "$extracted_for_reindex" = true ] && [ -n "$extracted_dir" ] && [ -d "$extracted_dir" ]; then
            log_info "    Cleaning up extracted directory after failed re-index..."
            rm -rf "$extracted_dir"
        fi

        return 1
    fi
}

# Delete a run from crucible database
delete_crucible_run() {
    local run_id="$1"

    log_info "    Removing run from crucible database..."
    crucible delete run --run "$run_id" >/dev/null 2>&1
    return $?
}

# Fetch all run IDs from crucible database via HTTP API (much faster than CLI)
fetch_all_crucible_runs() {
    CRUCIBLE_RUN_IDS=$(curl -s "http://localhost:${CRUCIBLE_PORT}/api/v1/runs" 2>/dev/null | grep -o '"[0-9a-f-]*"' | tr -d '"')
    if [ -z "$CRUCIBLE_RUN_IDS" ]; then
        log_warn "Could not fetch run IDs from crucible HTTP API (port ${CRUCIBLE_PORT}), falling back to CLI checks"
        return 1
    fi
    return 0
}

# Check if a run exists in crucible database (using cached list from HTTP API)
check_crucible_has_run() {
    local run_id="$1"

    # If we have cached run IDs from HTTP API, use them (fast)
    if [ -n "$CRUCIBLE_RUN_IDS" ]; then
        echo "$CRUCIBLE_RUN_IDS" | grep -q "^${run_id}$"
        return $?
    fi

    # Fallback to CLI method (slow)
    crucible get result --run "$run_id" >/dev/null 2>&1
    return $?
}

# Extract run-id from benchmark blob directory name
# Format: iperf--2026-05-01_21:34:48_UTC--27dd981f-e0c9-4895-a0f2-adbc095dba4b
#                                           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
extract_run_id() {
    local blob_dir="$1"
    echo "$blob_dir" | grep -oP '(?<=--)[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
}

# Find all test directories
if [ -n "$SPECIFIC_RUN_DIR" ]; then
    # If specific run dir provided, find its parent test directory
    if [[ "$SPECIFIC_RUN_DIR" = /* ]]; then
        TEST_DIRS=($(dirname "$SPECIFIC_RUN_DIR"))
    else
        # Find the run dir and get its parent
        FOUND_RUN=$(find "$PWD" -type d -name "$SPECIFIC_RUN_DIR" 2>/dev/null | head -1)
        if [ -z "$FOUND_RUN" ]; then
            log_error "Could not find run directory: $SPECIFIC_RUN_DIR"
            exit 1
        fi
        TEST_DIRS=($(dirname "$FOUND_RUN"))
    fi
else
    # Find all test directories
    mapfile -t TEST_DIRS < <(find_test_dirs)

    if [ ${#TEST_DIRS[@]} -eq 0 ]; then
        log_warn "No test directories (with run-* subdirectories) found"
        exit 0
    fi
fi

log_info "Found ${#TEST_DIRS[@]} test directory(ies)"

# Fetch all crucible run IDs once via HTTP API (much faster than CLI)
log_info "Fetching run IDs from crucible database..."
fetch_all_crucible_runs

if [ "$DRYRUN" = true ]; then
    echo ""
    log_dryrun "DRY RUN MODE - no changes will be made"
fi
echo ""

# Global arrays to track runs for final report
RUNS_NEED_FIX=()
RUNS_NEED_FIX_REINDEX=()
RUNS_NEED_FIX_UNTAR=()
RUNS_ALREADY_OK=()
RUNS_NO_RESULTS=()
RUNS_REINDEX_FAILED=()
RUNS_INCOMPLETE=()

# Process each test directory
for TEST_DIR in "${TEST_DIRS[@]}"; do
    echo "========================================"
    log_info "Processing test directory: $TEST_DIR"
    echo "========================================"
    echo ""

    cd "$TEST_DIR"

    # Check if nodeSelector files exist
    if ! ls nodeSelector-*.json >/dev/null 2>&1; then
        log_warn "No nodeSelector-*.json files found in $TEST_DIR"
        log_warn "Skipping this test directory"
        echo ""
        continue
    fi

    WORKER_NODES=($(ls nodeSelector-*.json | sed 's/nodeSelector-//; s/.json//'))
    log_info "Worker nodes: ${WORKER_NODES[*]}"
    echo ""

    # Determine which run directories to process
    if [ -n "$SPECIFIC_RUN_DIR" ]; then
        RUN_DIR_NAME=$(basename "$SPECIFIC_RUN_DIR")
        if [ ! -d "$RUN_DIR_NAME" ]; then
            log_error "Run directory not found: $RUN_DIR_NAME"
            continue
        fi
        RUN_DIRS=("$RUN_DIR_NAME")
        log_info "Processing specific run: ${RUN_DIRS[0]}"
    else
        # Find all run-* directories (only at this level, no recursion)
        RUN_DIRS=($(find . -maxdepth 1 -type d -name "run-*" | sed 's|^\./||' | sort))

        if [ ${#RUN_DIRS[@]} -eq 0 ]; then
            log_warn "No run-* directories found in $TEST_DIR"
            echo ""
            continue
        fi

        log_info "Found ${#RUN_DIRS[@]} run directories"
    fi
    echo ""

for DIR in "${RUN_DIRS[@]}"; do
    echo "Checking: $DIR"

    # Initialize extraction tracking for this run
    EXTRACTED_BLOBS_THIS_RUN=()
    HAS_COMPRESSED_BLOB=false

    # Check if this is a complete run (must have result-summary.txt in run dir or blob)
    HAS_RESULT_SUMMARY=false
    if [ -f "$DIR/result-summary.txt" ]; then
        HAS_RESULT_SUMMARY=true
    elif find "$DIR" -maxdepth 2 -name "result-summary.txt" 2>/dev/null | grep -q .; then
        HAS_RESULT_SUMMARY=true
    fi

    if [ "$HAS_RESULT_SUMMARY" = false ]; then
        log_warn "  Incomplete run (no result-summary.txt) - skipping"
        RUNS_INCOMPLETE+=("$TEST_DIR/$DIR")
        echo ""
        continue
    fi

    # Check for iperf/uperf result blobs (directories or .tgz archives)
    BLOB_DIRS=($(find "$DIR" -maxdepth 1 -type d \( -name "iperf--*" -o -name "uperf--*" \) 2>/dev/null))
    BLOB_ARCHIVES=($(find "$DIR" -maxdepth 1 -type f \( -name "iperf--*.tgz" -o -name "uperf--*.tgz" \) 2>/dev/null))

    BLOB_COUNT=$((${#BLOB_DIRS[@]} + ${#BLOB_ARCHIVES[@]}))

    if [ "$BLOB_COUNT" -eq 0 ]; then
        log_warn "  No benchmark blobs - skipping"
        RUNS_NO_RESULTS+=("$TEST_DIR/$DIR")
        echo ""
        continue
    fi

    # Extract any .tgz archives (only if blob directory doesn't exist)
    if [ ${#BLOB_ARCHIVES[@]} -gt 0 ]; then
        for archive in "${BLOB_ARCHIVES[@]}"; do
            extracted_dir="${archive%.tgz}"
            if [ -d "$extracted_dir" ]; then
                log_info "  Blob directory already exists: $(basename "$extracted_dir") (skipping extraction)"
                BLOB_DIRS+=("$extracted_dir")
            else
                # Mark that this run has a compressed blob
                HAS_COMPRESSED_BLOB=true

                if [ "$DRYRUN" = true ]; then
                    # In dry-run, skip extraction but continue processing
                    # check_needs_fix() will determine if already fixed or needs fixing
                    log_info "  Archive compressed (skipping extraction in dry-run)"
                else
                    log_info "  Extracting compressed blob: $(basename "$archive")"
                    start_time=$(date +%s)
                    if tar --force-local -xzf "$archive" -C "$DIR" 2>&1; then
                        end_time=$(date +%s)
                        elapsed=$((end_time - start_time))
                        # Add extracted directory to BLOB_DIRS and track for cleanup
                        if [ -d "$extracted_dir" ]; then
                            BLOB_DIRS+=("$extracted_dir")
                            EXTRACTED_BLOBS_THIS_RUN+=("$extracted_dir")
                            log_info "  ✓ Extraction completed in ${elapsed}s"
                        else
                            log_error "  ✗ Extraction failed - directory not found: $(basename "$extracted_dir")"
                        fi
                    else
                        log_error "  ✗ Failed to extract archive: $(basename "$archive")"
                    fi
                fi
            fi
        done
    fi

    log_info "  Found $BLOB_COUNT benchmark blob(s)"

    # Extract run-id from blob directory or archive name
    if [ ${#BLOB_DIRS[@]} -gt 0 ]; then
        FIRST_BLOB=$(basename "${BLOB_DIRS[0]}")
    elif [ ${#BLOB_ARCHIVES[@]} -gt 0 ]; then
        # Use archive name (remove .tgz extension)
        FIRST_BLOB=$(basename "${BLOB_ARCHIVES[0]%.tgz}")
    else
        FIRST_BLOB=""
    fi

    RUN_ID=$(extract_run_id "$FIRST_BLOB")

    if [ -z "$RUN_ID" ]; then
        log_error "  Could not extract run-id from blob name: $FIRST_BLOB"
        log_error "  Cannot process this run"

        # Clean up any extracted blobs before continuing
        if [ ${#EXTRACTED_BLOBS_THIS_RUN[@]} -gt 0 ]; then
            log_info "  Cleaning up extracted blobs..."
            for blob_dir in "${EXTRACTED_BLOBS_THIS_RUN[@]}"; do
                [ -d "$blob_dir" ] && rm -rf "$blob_dir"
            done
        fi

        echo ""
        continue
    fi

    log_info "  Run ID: $RUN_ID"

    # Check if this run needs fixing by examining new-gen-summary.txt
    # Force mode bypasses the check and always treats runs as needing fix
    if [ "$FORCE" = true ] || check_needs_fix "$DIR"; then
        if [ "$FORCE" = true ]; then
            log_warn "  → FORCE FIX (--force specified)"
        else
            log_warn "  → NEEDS FIX (empty hostnames in summary)"
        fi

        # Show current CPU value from horizontal.txt if it exists
        CURRENT_CPU=""
        if [ -f "$DIR/horizontal.txt" ]; then
            CURRENT_CPU=$(grep "^CPU:" "$DIR/horizontal.txt" 2>/dev/null | cut -d: -f2 | awk '{print $1}')
            if [ -n "$CURRENT_CPU" ]; then
                log_warn "  Current (incorrect) CPU: $CURRENT_CPU% (all nodes)"
            fi
        fi

        # Check if run exists in crucible database (needed for reg-gen-summary)
        NEEDS_REINDEX=false
        if check_crucible_has_run "$RUN_ID"; then
            log_info "  ✓ Run exists in crucible database"
            # Categorize based on whether blob needs extraction (dry-run only)
            if [ "$DRYRUN" = true ] && [ "$HAS_COMPRESSED_BLOB" = true ]; then
                RUNS_NEED_FIX_UNTAR+=("$DIR (CPU: ${CURRENT_CPU:-N/A}%)")
            else
                RUNS_NEED_FIX+=("$DIR (CPU: ${CURRENT_CPU:-N/A}%)")
            fi
        else
            log_warn "  ✗ Run NOT in crucible database - needs re-index"
            NEEDS_REINDEX=true
            # Categorize: if compressed blob in dry-run, categorize as UNTAR, otherwise as REINDEX
            if [ "$DRYRUN" = true ] && [ "$HAS_COMPRESSED_BLOB" = true ]; then
                RUNS_NEED_FIX_UNTAR+=("$DIR (CPU: ${CURRENT_CPU:-N/A}%, needs reindex)")
            else
                RUNS_NEED_FIX_REINDEX+=("$DIR (CPU: ${CURRENT_CPU:-N/A}%)")
            fi

            if [ "$DRYRUN" = true ]; then
                # Find blob directory for display
                BLOB_SAMPLE=$(find "$DIR" -maxdepth 1 -type d \( -name "iperf--*" -o -name "uperf--*" \) 2>/dev/null | head -1)
                if [ -n "$BLOB_SAMPLE" ]; then
                    BLOB_PATH=$(cd "$BLOB_SAMPLE" && pwd)
                    log_dryrun "  Would run: crucible index $BLOB_PATH"
                fi
            else
                log_info "  Re-indexing run into crucible..."
                if reindex_crucible_run "$RUN_ID" "$DIR"; then
                    log_info "  ✓ Re-indexed successfully"
                else
                    log_error "  ✗ Re-indexing failed for run: $DIR (run-id: $RUN_ID)"
                    log_error "  Stopping execution - fix the re-indexing issue before continuing"

                    # Clean up any extracted blobs before exiting
                    if [ ${#EXTRACTED_BLOBS_THIS_RUN[@]} -gt 0 ]; then
                        log_info "  Cleaning up extracted blobs..."
                        for blob_dir in "${EXTRACTED_BLOBS_THIS_RUN[@]}"; do
                            [ -d "$blob_dir" ] && rm -rf "$blob_dir"
                        done
                    fi

                    exit 1
                fi
            fi
        fi

        if [ "$DRYRUN" = true ]; then
            # Check if nodeSelector files exist in run directory
            if ! ls "$DIR"/nodeSelector-*.json >/dev/null 2>&1; then
                log_warn "  ✗ No nodeSelector files in run directory - cannot fix"
            else
                log_dryrun "  Would do:"
                log_dryrun "    - Delete old summary files"
                log_dryrun "    - Run reg-gen-summary (will find worker nodes)"
                log_dryrun "    - Regenerate horizontal.txt with correct CPU"
                log_dryrun "    - Backup result-summary.txt as result-summary.before"
                log_dryrun "    - Update result-summary.txt with correct CPU"
                if [ "$NEEDS_REINDEX" = true ]; then
                    log_dryrun "    - Delete run from crucible database"
                fi
            fi
        else
            # Actually perform the fix
            log_info "  Fixing..."

            # Check if nodeSelector files already exist in run directory
            if ! ls "$DIR"/nodeSelector-*.json >/dev/null 2>&1; then
                log_error "  ✗ No nodeSelector files in run directory"
                log_error "  Cannot fix without nodeSelector files - skipping"

                # Clean up any extracted blobs before continuing
                if [ ${#EXTRACTED_BLOBS_THIS_RUN[@]} -gt 0 ]; then
                    log_info "  Cleaning up extracted blobs..."
                    for blob_dir in "${EXTRACTED_BLOBS_THIS_RUN[@]}"; do
                        [ -d "$blob_dir" ] && rm -rf "$blob_dir"
                    done
                fi

                echo ""
                continue
            fi

            # Delete old summary files
            log_info "    Removing old summary files..."
            rm -f "$DIR"/new-summary-*.txt
            rm -f "$DIR"/show-summary-*.txt
            rm -f "$DIR"/horizontal.txt
            rm -f "$DIR"/new-gen-summary.txt

            # Enter run directory and regenerate
            FIX_SUCCESS=false
            (
                cd "$DIR"

                log_info "    Running reg-gen-summary..."
                rgs_start=$(date +%s)
                # Use tee to show output and save to file
                reg-gen-summary 2>&1 | tee new-gen-summary.txt
                rgs_end=$(date +%s)
                rgs_elapsed=$((rgs_end - rgs_start))

                # Verify hostnames were found
                if [ -f new-gen-summary.txt ]; then
                    HOST_COUNT=$(grep -E "^\s+[a-zA-Z0-9.-]+\.[a-zA-Z]+$" new-gen-summary.txt 2>/dev/null | wc -l)
                    if [ "$HOST_COUNT" -gt 0 ]; then
                        log_info "    ✓ Found $HOST_COUNT worker node(s) (took ${rgs_elapsed}s)"
                    else
                        log_warn "    ⚠ No worker nodes detected - CPU may still be wrong (took ${rgs_elapsed}s)"
                    fi
                fi

                # Regenerate horizontal.txt
                if ls new-summary-*.txt >/dev/null 2>&1; then
                    log_info "    Running horizontal.sh..."
                    bash "${REG_ROOT}/bin/horizontal.sh" new-summary-*.txt > horizontal.txt 2>/dev/null || \
                    bash ../../bin/horizontal.sh new-summary-*.txt > horizontal.txt 2>/dev/null || \
                    bash ../../../bin/horizontal.sh new-summary-*.txt > horizontal.txt 2>/dev/null || true
                fi

                # Backup original result-summary.txt BEFORE copying from blob
                if [ -f result-summary.txt ] && [ ! -f result-summary.before ]; then
                    log_info "    Backing up original result-summary.txt..."
                    cp result-summary.txt result-summary.before
                fi

                # Copy result-summary.txt from blob to run directory
                find . -name result-summary.txt -exec cp {} . \; 2>/dev/null || true

                # Re-add CPU to result-summary.txt
                if [ -f horizontal.txt ] && [ -f result-summary.txt ]; then
                    if [ -x "${REG_ROOT}/bin/reg-add-cpu-result.py" ]; then
                        log_info "    Updating result-summary.txt..."
                        "${REG_ROOT}/bin/reg-add-cpu-result.py" horizontal.txt result-summary.txt result-summary.tmp 2>/dev/null && \
                        mv result-summary.tmp result-summary.txt || true
                    fi
                fi

            ) && FIX_SUCCESS=true

            if [ "$FIX_SUCCESS" = true ]; then
                log_info "  ✓ Fixed successfully"

                # Show new CPU value
                if [ -f "$DIR/horizontal.txt" ]; then
                    NEW_CPU=$(grep "^CPU:" "$DIR/horizontal.txt" 2>/dev/null | cut -d: -f2 | awk '{print $1}')
                    if [ -n "$NEW_CPU" ]; then
                        log_info "  New (correct) CPU: $NEW_CPU% (worker nodes only)"
                    fi
                fi

                # If we had to re-index, remove the run from crucible database
                if [ "$NEEDS_REINDEX" = true ]; then
                    if delete_crucible_run "$RUN_ID"; then
                        log_info "    ✓ Removed run from crucible database"
                    else
                        log_warn "    Failed to remove run from crucible database"
                    fi
                fi
            else
                log_error "  ✗ Fix failed"
            fi
        fi
    else
        log_info "  → Already OK (has worker nodes in summary)"

        # Show current CPU value
        CURRENT_CPU=""
        if [ -f "$DIR/horizontal.txt" ]; then
            CURRENT_CPU=$(grep "^CPU:" "$DIR/horizontal.txt" 2>/dev/null | cut -d: -f2 | awk '{print $1}')
            if [ -n "$CURRENT_CPU" ]; then
                log_info "  CPU: $CURRENT_CPU%"
            fi
        fi

        RUNS_ALREADY_OK+=("$DIR (CPU: ${CURRENT_CPU:-N/A}%)")
    fi

    # Clean up extracted blobs (keep .tgz archives)
    if [ ${#EXTRACTED_BLOBS_THIS_RUN[@]} -gt 0 ]; then
        log_info "  Cleaning up extracted blobs (keeping .tgz archives)..."
        for blob_dir in "${EXTRACTED_BLOBS_THIS_RUN[@]}"; do
            if [ -d "$blob_dir" ]; then
                log_info "    Removing: $(basename "$blob_dir")"
                rm -rf "$blob_dir"
            fi
        done
    fi

    echo ""
done

# End of test directory loop
done

echo ""
echo "========================================"
log_info "GLOBAL Summary:"
echo "  Needs fix:            ${#RUNS_NEED_FIX[@]}"
echo "  Needs fix + reindex:  ${#RUNS_NEED_FIX_REINDEX[@]}"
echo "  Needs fix + untar:    ${#RUNS_NEED_FIX_UNTAR[@]}"
echo "  Already OK:           ${#RUNS_ALREADY_OK[@]}"
echo "  No results:           ${#RUNS_NO_RESULTS[@]}"
echo "  Incomplete:           ${#RUNS_INCOMPLETE[@]}"
echo "  Reindex failed:       ${#RUNS_REINDEX_FAILED[@]}"
echo "========================================"

# Detailed report
if [ "$DRYRUN" = true ]; then
    echo ""
    echo "========================================"
    echo "DETAILED REPORT"
    echo "========================================"

    if [ ${#RUNS_NEED_FIX[@]} -gt 0 ]; then
        echo ""
        echo "Runs that NEED FIX:"
        for run in "${RUNS_NEED_FIX[@]}"; do
            echo "  - $run"
        done
    fi

    if [ ${#RUNS_NEED_FIX_REINDEX[@]} -gt 0 ]; then
        echo ""
        echo "Runs that NEED FIX + REINDEX (not in crucible DB):"
        for run in "${RUNS_NEED_FIX_REINDEX[@]}"; do
            echo "  - $run"
        done
    fi

    if [ ${#RUNS_NEED_FIX_UNTAR[@]} -gt 0 ]; then
        echo ""
        echo "Runs that NEED FIX + UNTAR (compressed, run without --dryrun to fix):"
        for run in "${RUNS_NEED_FIX_UNTAR[@]}"; do
            echo "  - $run"
        done
    fi

    if [ ${#RUNS_ALREADY_OK[@]} -gt 0 ]; then
        echo ""
        echo "Runs that are ALREADY OK:"
        for run in "${RUNS_ALREADY_OK[@]}"; do
            echo "  - $run"
        done
    fi

    if [ ${#RUNS_NO_RESULTS[@]} -gt 0 ]; then
        echo ""
        echo "Runs with NO RESULTS (skipped):"
        for run in "${RUNS_NO_RESULTS[@]}"; do
            echo "  - $run"
        done
    fi

    if [ ${#RUNS_INCOMPLETE[@]} -gt 0 ]; then
        echo ""
        echo "Runs that are INCOMPLETE (terminated prematurely):"
        for run in "${RUNS_INCOMPLETE[@]}"; do
            echo "  - $run"
        done
    fi

    if [ ${#RUNS_REINDEX_FAILED[@]} -gt 0 ]; then
        echo ""
        echo "Runs where RE-INDEX FAILED:"
        for run in "${RUNS_REINDEX_FAILED[@]}"; do
            echo "  - $run"
        done
    fi

    echo ""
    echo "========================================"
fi

if [ ${#RUNS_REINDEX_FAILED[@]} -gt 0 ]; then
    echo ""
    log_warn "${#RUNS_REINDEX_FAILED[@]} run(s) could not be re-indexed"
    log_warn "Check the error messages above for details"
fi

if [ "$DRYRUN" = true ] && [ $((${#RUNS_NEED_FIX[@]} + ${#RUNS_NEED_FIX_REINDEX[@]} + ${#RUNS_NEED_FIX_UNTAR[@]})) -gt 0 ]; then
    echo ""
    log_dryrun "Re-run without --dryrun to apply fixes"
fi
