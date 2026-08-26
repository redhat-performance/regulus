#!/bin/bash
# Validate that test results match expectations

RESULTS_FILE="${1:-/tmp/test-results.txt}"

if [ ! -f "$RESULTS_FILE" ]; then
    echo "❌ Results file not found: $RESULTS_FILE"
    exit 1
fi

echo "════════════════════════════════════════════════════════════════════════════════"
echo "🔍 Validating Test Results"
echo "════════════════════════════════════════════════════════════════════════════════"
echo ""

# Count results — match the output format from analyze-batch.py
STABLE=$(grep -c "✅ STABLE" "$RESULTS_FILE" 2>/dev/null || true)
IMPROVED=$(grep -c "📈 IMPROVED" "$RESULTS_FILE" 2>/dev/null || true)
REGRESSIONS=$(grep -c "⚠️  REGRESSED" "$RESULTS_FILE" 2>/dev/null || true)
ERRORS=$(grep "❌ ERROR" "$RESULTS_FILE" 2>/dev/null | grep -v "Errors: 0" | wc -l)

# Expected values for mock test (with rcos included in fingerprint)
# 6 fingerprints:
#   A (threads=16):  stable baseline         → STABLE
#   B (threads=32):  throughput -25%          → REGRESSED
#   C (threads=64):  throughput +20%          → IMPROVED
#   D (threads=128): rcos mismatch, no match  → STABLE
#   E (threads=256): cpu_cost doubled         → REGRESSED
#   F (multibench):  composite -25%           → REGRESSED
EXPECTED_STABLE=2
EXPECTED_IMPROVED=1
EXPECTED_REGRESSIONS=3
EXPECTED_ERRORS=0

echo "Expected: $EXPECTED_STABLE stable, $EXPECTED_IMPROVED improved, $EXPECTED_REGRESSIONS regression, $EXPECTED_ERRORS errors"
echo "Got:      $STABLE stable, $IMPROVED improved, $REGRESSIONS regression(s), $ERRORS error(s)"
echo ""

if [ "$STABLE" -eq "$EXPECTED_STABLE" ] && [ "$IMPROVED" -eq "$EXPECTED_IMPROVED" ] && [ "$REGRESSIONS" -eq "$EXPECTED_REGRESSIONS" ] && [ "$ERRORS" -eq "$EXPECTED_ERRORS" ]; then
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo "✅ TEST PASSED - All results match expectations!"
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo ""
    echo "Results breakdown:"
    echo "  ✅ Fingerprint 1 (threads=16):   STABLE (expected)"
    echo "  ⚠️  Fingerprint 2 (threads=32):   REGRESSED (throughput -25%)"
    echo "  📈 Fingerprint 3 (threads=64):   IMPROVED (throughput +20%)"
    echo "  ✅ Fingerprint 4 (threads=128):  STABLE (rcos mismatch, no baseline)"
    echo "  ⚠️  Fingerprint 5 (threads=256):  REGRESSED (cpu_cost doubled)"
    echo "  ⚠️  Fingerprint 6 (multibench):   REGRESSED (composite -25%)"
    echo ""
    exit 0
else
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo "❌ TEST FAILED - Results do not match expectations!"
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo ""
    echo "Differences:"
    if [ "$STABLE" -ne "$EXPECTED_STABLE" ]; then
        echo "  - Stable: expected $EXPECTED_STABLE, got $STABLE"
    fi
    if [ "$IMPROVED" -ne "$EXPECTED_IMPROVED" ]; then
        echo "  - Improved: expected $EXPECTED_IMPROVED, got $IMPROVED"
    fi
    if [ "$REGRESSIONS" -ne "$EXPECTED_REGRESSIONS" ]; then
        echo "  - Regressions: expected $EXPECTED_REGRESSIONS, got $REGRESSIONS"
    fi
    if [ "$ERRORS" -ne "$EXPECTED_ERRORS" ]; then
        echo "  - Errors: expected $EXPECTED_ERRORS, got $ERRORS"
    fi
    echo ""
    exit 1
fi
