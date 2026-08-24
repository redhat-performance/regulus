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

# Count results
STABLE=$(grep -c "✅ STABLE" "$RESULTS_FILE" 2>/dev/null || echo 0)
REGRESSIONS=$(grep -c "⚠️  REGRESSION DETECTED" "$RESULTS_FILE" 2>/dev/null || echo 0)
ERRORS=$(grep "❌ ERROR" "$RESULTS_FILE" 2>/dev/null | grep -v "Errors: 0" | wc -l)

# Expected values for mock test (with rcos included in fingerprint)
EXPECTED_STABLE=2
EXPECTED_REGRESSIONS=3
EXPECTED_ERRORS=0

echo "Expected: $EXPECTED_STABLE stable, $EXPECTED_REGRESSIONS regression, $EXPECTED_ERRORS errors"
echo "Got:      $STABLE stable, $REGRESSIONS regression(s), $ERRORS error(s)"
echo ""

if [ "$STABLE" -eq "$EXPECTED_STABLE" ] && [ "$REGRESSIONS" -eq "$EXPECTED_REGRESSIONS" ] && [ "$ERRORS" -eq "$EXPECTED_ERRORS" ]; then
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo "✅ TEST PASSED - All results match expectations!"
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo ""
    echo "Results breakdown:"
    echo "  ✅ Fingerprint 1 (threads=16):   STABLE (expected)"
    echo "  ⚠️  Fingerprint 2 (threads=32):   REGRESSION (throughput -25%)"
    echo "  ⚠️  Fingerprint 3 (threads=64):   CHANGEPOINT (throughput +20%)"
    echo "  ✅ Fingerprint 4 (threads=128):  STABLE (rcos mismatch, no baseline)"
    echo "  ⚠️  Fingerprint 5 (threads=256):  REGRESSION (busy_cpu doubled)"
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
    if [ "$REGRESSIONS" -ne "$EXPECTED_REGRESSIONS" ]; then
        echo "  - Regressions: expected $EXPECTED_REGRESSIONS, got $REGRESSIONS"
    fi
    if [ "$ERRORS" -ne "$EXPECTED_ERRORS" ]; then
        echo "  - Errors: expected $EXPECTED_ERRORS, got $ERRORS"
    fi
    echo ""
    exit 1
fi
