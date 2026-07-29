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

# ── Developer debug overrides (edit here to iterate without Prow approval) ───
DEBUG_IGNORE=""
DEBUG_MATCH=""

if [[ -n "${DEBUG_IGNORE}" ]] || [[ -n "${DEBUG_MATCH}" ]]; then
    echo "⚠️  DEBUG OVERRIDE active — using DEBUG_IGNORE/DEBUG_MATCH instead of Prow env"
    echo "   DEBUG_IGNORE=\"${DEBUG_IGNORE}\""
    echo "   DEBUG_MATCH=\"${DEBUG_MATCH}\""
    IGNORE="${DEBUG_IGNORE}"
    MATCH="${DEBUG_MATCH}"
fi

# ── Resolve ES server ────────────────────────────────────────────────────────
if [[ -n "${ES_SERVER:-}" ]]; then
    echo "ES server: (from environment)"
else
    ES_PASSWORD=$(cat "/secret/perfscale-prod/password" 2>/dev/null || echo "")
    ES_USER=$(cat "/secret/perfscale-prod/username" 2>/dev/null || echo "")
    ES_HOST=$(cat "/secret/perfscale-prod/host" 2>/dev/null || echo "")

    if [[ -z "$ES_USER" ]] || [[ -z "$ES_PASSWORD" ]] || [[ -z "$ES_HOST" ]]; then
        echo "❌ ERROR: ES_SERVER not set and credentials not found in /secret/perfscale-prod/" >&2
        exit 1
    fi

    ES_SERVER=$(ES_USER="$ES_USER" ES_PASSWORD="$ES_PASSWORD" ES_HOST="$ES_HOST" python3 -c "
import os, urllib.parse
user = urllib.parse.quote(urllib.parse.unquote(os.environ['ES_USER']), safe='')
pwd = urllib.parse.quote(urllib.parse.unquote(os.environ['ES_PASSWORD']), safe='')
print('https://' + user + ':' + pwd + '@' + os.environ['ES_HOST'])
")
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

REDACTED_CMD="${CMD[*]}"
REDACTED_CMD=$(echo "$REDACTED_CMD" | sed -E 's|https?://[^@]*@|https://***:***@|g')
echo "Running: ${REDACTED_CMD}"
echo ""

# ── Run analysis ──────────────────────────────────────────────────────────────
set +e
"${CMD[@]}" | tee "${ARTIFACT_DIR}/orion-regulus-output.txt"
status=${PIPESTATUS[0]}
set -e

# ── Copy artifacts ────────────────────────────────────────────────────────────
echo ""
echo "Copying artifacts to ${ARTIFACT_DIR}..."
rm -f "${ARTIFACT_DIR}"/orion-config-*.yaml "${ARTIFACT_DIR}"/*.json "${ARTIFACT_DIR}"/*.csv 2>/dev/null || true
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
