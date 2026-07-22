# Test Validation Guide

## Overview

The Orion Regulus test framework includes automated validation to ensure regression detection is working correctly. This allows you to run tests and get clear PASS/FAIL feedback.

## Quick Start

Run the full test cycle with automated validation:

```bash
make test-full
```

Expected output:
```
✅ TEST PASSED - All results match expectations!

Results breakdown:
  ✅ Fingerprint 1 (threads=16):  STABLE (expected)
  ⚠️  Fingerprint 2 (threads=32):  REGRESSION DETECTED (expected -25% drop)
  ✅ Fingerprint 3 (threads=64):  STABLE (expected +20% improvement, not alerted)
```

Exit code: `0` = PASS, `1` = FAIL

## Test Workflow

### 1. Full Automated Test

```bash
make test-full
```

This command:
1. Cleans previous test data (`make clean`)
2. Generates new mock data with controlled scenarios (`make create-mock`)
3. Pushes data to Elasticsearch (`make push-batch`)
4. Runs Orion batch analysis
5. Validates results against expectations
6. Reports PASS/FAIL with exit code

### 2. Standalone Validation

After running any analysis, validate the results:

```bash
make verify-test
```

This validates the most recent analysis results from `/tmp/test-results.txt`.

### 3. Manual Workflow

For step-by-step control:

```bash
# Step 1: Generate mock data
make create-mock

# Step 2: Push to Elasticsearch
make push-batch

# Step 3: Run analysis
make analyze BATCH_ID=test-batch-2026-07-08

# Step 4: Validate results
make verify-test
```

## Expected Test Results

The mock data generator creates 3 fingerprints:

| Fingerprint | threads | Scenario | Expected Result |
|-------------|---------|----------|-----------------|
| A | 16 | Stable baseline | ✅ STABLE |
| B | 32 | 25% regression | ⚠️ REGRESSION DETECTED |
| C | 64 | 20% improvement | ✅ STABLE (improvements not alerted by default) |

**Validation criteria:**
- Expected: 2 stable, 1 regression, 0 errors
- Test PASSES if actual matches expected
- Test FAILS otherwise

## Exit Codes

Both `make test-full` and `make verify-test` return:
- **Exit 0**: Test PASSED - all expectations met
- **Exit 1**: Test FAILED - expectations not met

This makes the tests suitable for CI/CD pipelines:

```bash
# In CI/CD pipeline
make test-full
if [ $? -eq 0 ]; then
    echo "Regression detection working correctly"
    exit 0
else
    echo "Regression detection test failed"
    exit 1
fi
```

## Validation Logic

The validation script counts occurrences of:
- `✅ STABLE` - fingerprints with no regression
- `⚠️  REGRESSION DETECTED` - fingerprints with detected regressions
- `❌ ERROR` - fingerprints that failed analysis (excluding "Errors: 0")

Counts are compared to expected values:
```bash
EXPECTED_STABLE=2
EXPECTED_REGRESSIONS=1
EXPECTED_ERRORS=0
```

## Troubleshooting

### Test fails with wrong counts

**Problem:** Got different numbers than expected (2 stable, 1 regression, 0 errors)

**Solutions:**
1. Check if mock data was generated correctly:
   ```bash
   jq '[.[] | select(.batch_id | startswith("test-batch-"))] | length' \
       unit-test/generated/batch-mocked-data.json
   ```
   Should show 3 documents (one per fingerprint)

2. Verify data was pushed to Elasticsearch:
   ```bash
   make list-batches
   ```
   Should show your test-batch-YYYY-MM-DD

3. Check fingerprint matching by reviewing test output:
   ```bash
   cat /tmp/test-results.txt | grep "Documents in batch"
   ```
   Each fingerprint should have historical baseline data

### Regression not detected

**Problem:** All fingerprints show "✅ STABLE" even though mock data has 25% drop

**Root cause:** Fingerprint mismatch - historical data doesn't match test batch

**Solution:** All 16 fingerprint fields must match exactly:
- benchmark, unit, model, topology, protocol, nic, test_type
- threads, wsize, performance_profile, kernel, rcos, arch
- cpu, pods_per_worker, scale_out_factor

Check generated data:
```bash
jq -r '.[] | select(.threads == 32) | 
       "threads=\(.threads) kernel=\(.kernel) cpu=\(.cpu)"' \
    unit-test/generated/batch-mocked-data.json | head -5
```

All should have identical kernel, cpu, etc.

### Exit code always 0 even when test fails

**Problem:** Test shows "❌ TEST FAILED" but exit code is 0

**Solution:** This shouldn't happen with the current Makefile. Verify:
```bash
make test-full; echo "Exit code: $?"
```

If exit code is wrong, check Makefile line 260 has `exit 1` in the else clause.

## Custom Validation

To create custom validation for your own test scenarios:

1. **Generate custom mock data:**
   Edit `unit-test/generate-batch-test-data.py` to create different scenarios

2. **Update expected values:**
   Edit `scripts/validate-test-results.sh`:
   ```bash
   EXPECTED_STABLE=3      # Change based on your scenarios
   EXPECTED_REGRESSIONS=2 # Change based on your scenarios
   EXPECTED_ERRORS=0
   ```

3. **Run validation:**
   ```bash
   make test-full
   ```

## Integration with CI/CD

### Jenkins Pipeline

```groovy
stage('Orion Regression Test') {
    steps {
        sh 'make test-full'
    }
}
```

### GitHub Actions

```yaml
- name: Test Orion Regression Detection
  run: make test-full
```

### GitLab CI

```yaml
test:
  script:
    - make test-full
```

## Files Involved

- `Makefile` - test-full and verify-test targets
- `scripts/validate-test-results.sh` - Validation logic
- `unit-test/generate-batch-test-data.py` - Mock data generator
- `/tmp/test-results.txt` - Analysis results (temporary)

## Reference

For more information:
- See `make help` for all available targets
- See `unit-test/README-BATCH-TEST.md` for mock data generation details
- See `scripts/analyze-batch.py --help` for analysis options
