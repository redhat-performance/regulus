# Quick Start: Orion Regulus Testing

## One-Command Test

The fastest way to verify Orion regression detection is working:

```bash
make test-full
```

This command:
1. ✅ Generates mock data (3 fingerprints with controlled scenarios)
2. ✅ Pushes data to Elasticsearch
3. ✅ Runs Orion batch analysis
4. ✅ Validates results automatically
5. ✅ Reports PASS/FAIL with proper exit code

### Expected Output

```
================================================================================
✅ TEST PASSED - All results match expectations!
================================================================================

Results breakdown:
  ✅ Fingerprint 1 (threads=16):  STABLE (expected)
  ⚠️  Fingerprint 2 (threads=32):  REGRESSION DETECTED (expected -25% drop)
  ✅ Fingerprint 3 (threads=64):  STABLE (expected +20% improvement, not alerted)
```

Exit code: **0** (success)

## What Gets Tested

The mock data generator creates 3 test scenarios:

### Fingerprint A (threads=16) - Stable Performance
- **Historical baseline:** 20 samples around 8.5 Gbps
- **New test:** 1 sample around 8.5 Gbps
- **Expected result:** ✅ STABLE (no change)

### Fingerprint B (threads=32) - Performance Regression
- **Historical baseline:** 20 samples around 8.5 Gbps
- **New test:** 1 sample around 6.4 Gbps (25% drop!)
- **Expected result:** ⚠️ REGRESSION DETECTED

### Fingerprint C (threads=64) - Performance Improvement
- **Historical baseline:** 20 samples around 8.5 Gbps
- **New test:** 1 sample around 10.2 Gbps (20% improvement!)
- **Expected result:** ✅ STABLE (improvements not alerted by default)

## Common Workflows

### Daily CI/CD Testing

```bash
# Run in continuous integration
make test-full
if [ $? -eq 0 ]; then
    echo "Regression detection working correctly"
else
    echo "ALERT: Regression detection test failed!"
    exit 1
fi
```

### Manual Step-by-Step

```bash
# Step 1: Clean previous test data (if any)
make clean-mock

# Step 2: Generate mock data
make create-mock

# Step 3: Inspect generated data
jq '.[0] | {batch_id, threads, mean, unit}' \
    unit-test/generated/batch-mocked-data.json

# Step 4: Push to Elasticsearch
make push-batch

# Step 5: Verify data in ES
make list-batches

# Step 6: Run analysis
BATCH_ID=$(jq -r '[.[] | select(.batch_id | startswith("test-batch-"))] | .[0].batch_id' \
    unit-test/generated/batch-mocked-data.json)
make analyze BATCH_ID=$BATCH_ID

# Step 7: Validate results
make verify-test

# Step 8: Clean up after testing
make clean-mock
```

### Production Batch Analysis

```bash
# Analyze a real production batch
make analyze BATCH_ID=your-actual-batch-id

# Optional: Validate if you have expected results
make verify-test
```

## Cleanup

### Clean Mock Test Data

```bash
# Remove all mock data from ES and local files
make clean-mock
```

This removes:
- Mock batches from Elasticsearch (batch_id starting with `test-batch-` or `historical-`)
- All files in `unit-test/generated/`
- All files in `unit-test/backup/`

### Clean Generated Configs/Outputs Only

```bash
# Clean Orion configs and outputs (keep mock data)
make clean
```

This removes:
- `generated-configs/*` - Auto-generated Orion configs
- `generated-orion/*` - Orion analysis outputs

## File Locations

After running `make test-full`:

- **Generated mock data:** `unit-test/generated/batch-mocked-data.json`
- **Bulk ES data:** `unit-test/generated/batch-mocked-data.ndjson`
- **Analysis results:** `/tmp/test-results.txt`
- **Orion configs:** `generated-configs/`
- **Orion outputs:** `generated-orion/`

## Troubleshooting

### Test fails immediately

```bash
# Check if ES is accessible
curl -s http://your-es-server:9200/_cluster/health | jq .

# Verify Makefile configuration
make help
```

### Test runs but shows wrong results

```bash
# Check generated data
jq '[.[] | select(.batch_id | startswith("test-batch-"))] | 
    group_by(.threads) | 
    map({threads: .[0].threads, count: length, mean: (map(.mean) | add / length)})' \
    unit-test/generated/batch-mocked-data.json

# Should show 3 groups (threads: 16, 32, 64) with different means
```

### No regression detected

This usually means fingerprint mismatch between historical and test data.

```bash
# Check fingerprint consistency
jq -r '.[] | select(.threads == 32) | 
       "kernel=\(.kernel) cpu=\(.cpu) arch=\(.arch)"' \
    unit-test/generated/batch-mocked-data.json | sort -u

# Should show only ONE unique combination (all identical)
```

## Next Steps

Once `make test-full` passes:

1. **Production Testing:**
   - Use `make analyze BATCH_ID=real-batch` for production batches
   - See `make list-batches` to discover available batches

2. **Custom Thresholds:**
   - Edit configs in `generated-configs/` to adjust sensitivity
   - Re-run analysis with custom config

3. **CI/CD Integration:**
   - Add `make test-full` to your pipeline
   - Use exit code for pass/fail determination

4. **Deep Dive:**
   - Read `docs/TEST-VALIDATION.md` for complete validation guide
   - Read `unit-test/README-BATCH-TEST.md` for mock data details
   - Read `README.md` for full Orion Regulus documentation

## Need Help?

```bash
# Show all available commands
make help

# Show validation script usage
./scripts/validate-test-results.sh --help

# Show analyzer usage
./scripts/analyze-batch.py --help
```

For issues, check:
- `docs/TROUBLESHOOTING.md` - Common issues and solutions
- `docs/TEST-VALIDATION.md` - Validation details
- `unit-test/README-BATCH-TEST.md` - Mock data generation
