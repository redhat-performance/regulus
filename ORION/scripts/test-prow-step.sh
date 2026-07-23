#!/bin/bash
# Prow Step Simulation Wrapper
#
# This script simulates the Prow environment to test openshift-qe-orion-regulus-commands.sh locally.
# It sets up all environment variables and mock secrets that Prow would provide.
#
# Usage:
#   1. copy this script to release/ci-operator/step-registry/openshift-qe/orion/regulus
#   2. ./test-prow-step.sh                              # Auto-discover latest batch
#      ./test-prow-step.sh test-batch-2026-07-08        # Specific batch
#      MATCH="threads=128" ./test-prow-step.sh          # With filters
#
# Prerequisites:
#   - ES credentials available (will prompt if not found)
#   - Mock data in ES (run 'make create-mock && make push-batch' in regulus/ORION/)
#

set -o errexit
set -o nounset
set -o pipefail

echo "════════════════════════════════════════════════════════════════════════════════"
echo "🧪 Prow Step Local Simulation"
echo "════════════════════════════════════════════════════════════════════════════════"
echo ""

# ── Parse arguments ────────────────────────────────────────────────────────────────
BATCH_ID="${1:-}"

# ── Prow Environment Variables (from ref.yaml defaults) ───────────────────────────
export REGULUS_REPO="${REGULUS_REPO:-https://github.com/redhat-performance/regulus.git}"
export REGULUS_BRANCH="${REGULUS_BRANCH:-main}"
export ORION_REPO="${ORION_REPO:-https://github.com/cloud-bulldozer/orion.git}"
export ORION_TAG="${ORION_TAG:-latest}"
export BATCH_ID="${BATCH_ID}"
export MATCH="${MATCH:-}"
export IGNORE="${IGNORE:-}"
#export ES_BENCHMARK_INDEX="${ES_BENCHMARK_INDEX:-regulus-results-mock}"
export ES_BENCHMARK_INDEX="${ES_BENCHMARK_INDEX:-regulus-results-write}"
export LOOKBACK="${LOOKBACK:-90d}"
export DEBUG="${DEBUG:-false}"

# ── Prow Directories ───────────────────────────────────────────────────────────────
export ARTIFACT_DIR="${ARTIFACT_DIR:-/tmp/prow-artifacts-$(date +%Y%m%d-%H%M%S)}"
export SHARED_DIR="${SHARED_DIR:-/tmp/prow-shared}"

mkdir -p "$ARTIFACT_DIR"
mkdir -p "$SHARED_DIR"

# ── Mock Prow Secrets ──────────────────────────────────────────────────────────────
SECRET_DIR="/tmp/prow-secret-perfscale-prod"
mkdir -p "$SECRET_DIR"

if [[ -z "${ES_SERVER:-}" ]]; then
    echo "ES connection setup:"
    read -p "ES Host (e.g., myhost:9200): " ES_HOST
    read -p "ES Username (empty if no auth): " ES_USERNAME
    if [[ -n "$ES_USERNAME" ]]; then
        read -sp "ES Password: " ES_PASSWORD
        echo ""
    else
        ES_PASSWORD=""
    fi

    if [[ -z "$ES_HOST" ]]; then
        echo "ERROR: ES Host is required."
        exit 1
    fi

    echo -n "$ES_HOST" > "$SECRET_DIR/host"
    echo -n "$ES_USERNAME" > "$SECRET_DIR/username"
    echo -n "$ES_PASSWORD" > "$SECRET_DIR/password"

    if [[ -n "$ES_USERNAME" ]] && [[ -n "$ES_PASSWORD" ]]; then
        export ES_SERVER="https://${ES_USERNAME}:${ES_PASSWORD}@${ES_HOST}"
    else
        export ES_SERVER="http://${ES_HOST}"
    fi
fi

# Ensure /secret/perfscale-prod points to our mock secrets
if [[ ! -e "/secret/perfscale-prod" ]] || [[ "$(readlink -f /secret/perfscale-prod 2>/dev/null)" != "$(readlink -f "$SECRET_DIR")" ]]; then
    if [[ $EUID -eq 0 ]]; then
        mkdir -p /secret
        ln -sfn "$SECRET_DIR" /secret/perfscale-prod
        echo "Created symlink /secret/perfscale-prod -> $SECRET_DIR"
    else
        read -p "Create /secret/perfscale-prod symlink with sudo? (y/n): " CREATE_SYMLINK
        if [[ "$CREATE_SYMLINK" =~ ^[Yy] ]]; then
            sudo mkdir -p /secret
            sudo ln -sfn "$SECRET_DIR" /secret/perfscale-prod
        else
            echo "ERROR: Cannot proceed without /secret/perfscale-prod/"
            exit 1
        fi
    fi
    echo ""
fi

# ── Display Test Configuration ────────────────────────────────────────────────────
echo "Test Configuration:"
echo "  REGULUS_REPO   = $REGULUS_REPO"
echo "  REGULUS_BRANCH = $REGULUS_BRANCH"
echo "  ORION_REPO           = $ORION_REPO"
echo "  ORION_TAG            = $ORION_TAG"
echo "  ES_BENCHMARK_INDEX   = $ES_BENCHMARK_INDEX"
echo "  LOOKBACK             = $LOOKBACK"
echo "  DEBUG                = $DEBUG"
if [[ -n "$BATCH_ID" ]]; then
    echo "  BATCH_ID             = $BATCH_ID"
else
    echo "  BATCH_ID             = (auto-discover)"
fi
if [[ -n "$MATCH" ]]; then
    echo "  MATCH                = $MATCH"
fi
if [[ -n "$IGNORE" ]]; then
    echo "  IGNORE               = $IGNORE"
fi
echo ""
echo "Directories:"
echo "  ARTIFACT_DIR         = $ARTIFACT_DIR"
echo "  SHARED_DIR           = $SHARED_DIR"
echo "  SECRET_DIR           = /secret/perfscale-prod -> $SECRET_DIR"
echo ""
echo "════════════════════════════════════════════════════════════════════════════════"
echo ""

read -p "▶️  Run openshift-qe-orion-regulus-commands.sh with this configuration? (y/n): " RUN_TEST
if [[ ! "$RUN_TEST" =~ ^[Yy] ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "════════════════════════════════════════════════════════════════════════════════"
echo "🚀 Executing openshift-qe-orion-regulus-commands.sh"
echo "════════════════════════════════════════════════════════════════════════════════"
echo ""

# Get the directory where this script lives (step-registry location)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Execute the commands.sh script
"$SCRIPT_DIR/openshift-qe-orion-regulus-commands.sh"
EXIT_CODE=$?

echo ""
echo "════════════════════════════════════════════════════════════════════════════════"
echo "📊 Test Complete"
echo "════════════════════════════════════════════════════════════════════════════════"
echo "Exit code: $EXIT_CODE"
echo "Artifacts: $ARTIFACT_DIR"
echo ""

if [[ $EXIT_CODE -eq 0 ]]; then
    echo "✅ SUCCESS"
else
    echo "❌ FAILED (exit code $EXIT_CODE)"
fi

exit $EXIT_CODE
