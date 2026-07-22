#!/bin/bash
# Prow CI entry point for orion-regulus batch analysis
#
# Called by openshift-qe-orion-regulus-commands.sh after cloning the Regulus repo.
# Bridges Prow environment variables to analyze-batch.py CLI arguments.
#
# Expected Prow env vars:
#   BATCH_ID            - batch to analyze (empty = auto-discover latest)
#   MATCH               - filter tests (e.g. "threads=128")
#   IGNORE              - exclude fingerprint fields (e.g. "rcos kernel")
#   ES_BENCHMARK_INDEX  - ES index pattern (default: regulus-results-*)
#   LOOKBACK            - historical lookback (default: 90d)
#   DEBUG               - "true" to enable debug output
#   ARTIFACT_DIR        - Prow artifact directory
#
# ES credentials (one of):
#   ES_SERVER env var           - use directly (for local testing)
#   Mounted secrets at /secret/perfscale-prod/{username,password,host}  (Prow)
#
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$REPO_ROOT"

# ── Resolve ES server ────────────────────────────────────────────────────────
if [[ -n "${ES_SERVER:-}" ]]; then
    echo "ES server: (from environment)"
else
    ES_PASSWORD=$(cat "/secret/perfscale-prod/password" 2>/dev/null || echo "")
    ES_USERNAME=$(cat "/secret/perfscale-prod/username" 2>/dev/null || echo "")
    ES_HOST=$(cat "/secret/perfscale-prod/host" 2>/dev/null || echo "")

    if [[ -z "$ES_USERNAME" ]] || [[ -z "$ES_PASSWORD" ]] || [[ -z "$ES_HOST" ]]; then
        echo "❌ ERROR: ES_SERVER not set and credentials not found in /secret/perfscale-prod/" >&2
        exit 1
    fi

    ES_SERVER="https://${ES_USERNAME}:${ES_PASSWORD}@${ES_HOST}"
    echo "ES host: ${ES_HOST}"
fi
echo "ES index: ${ES_BENCHMARK_INDEX:-regulus-results-*}"

# ── Build analyze-batch.py command ────────────────────────────────────────────
CMD=("./scripts/analyze-batch.py")
CMD+=("--es-server" "${ES_SERVER}")
CMD+=("--es-index" "${ES_BENCHMARK_INDEX:-regulus-results-*}")
CMD+=("--lookback" "${LOOKBACK:-90d}")

[[ -n "${BATCH_ID:-}" ]] && CMD+=("--batch-id" "${BATCH_ID}")
[[ -n "${MATCH:-}" ]] && CMD+=("--match" "${MATCH}")
[[ -n "${IGNORE:-}" ]] && CMD+=("--ignore" "${IGNORE}")
[[ "${DEBUG:-false}" == "true" ]] && CMD+=("--debug")

echo "Running: ${CMD[*]}"
echo ""

# ── Run analysis ──────────────────────────────────────────────────────────────
set +e
"${CMD[@]}" | tee "${ARTIFACT_DIR}/orion-regulus-output.txt"
status=${PIPESTATUS[0]}
set -e

# ── Copy artifacts ────────────────────────────────────────────────────────────
echo ""
echo "Copying artifacts to ${ARTIFACT_DIR}..."
cp generated-configs/*.yaml "${ARTIFACT_DIR}/" 2>/dev/null || true
cp generated-orion/*.json "${ARTIFACT_DIR}/" 2>/dev/null || true
cp generated-orion/*.csv "${ARTIFACT_DIR}/" 2>/dev/null || true

# ── Handle exit codes ─────────────────────────────────────────────────────────
if [[ $status -eq 0 ]]; then
    echo "✅ SUCCESS: No regressions detected"
    exit 0
fi

if [[ $status -eq 3 ]]; then
    echo "ℹ️  No results to analyze (exit code 3)"
    exit 0
fi

echo "❌ FAILURE: Regressions detected (exit code ${status})"
exit $status
