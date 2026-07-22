# Mock Data Guide for Orion Development

This guide explains how to generate and use mock Regulus test data for developing and testing Orion's regression detection capabilities.

## Table of Contents

- [Why Mock Data?](#why-mock-data)
- [Quick Start](#quick-start)
- [Mock Data Scenarios](#mock-data-scenarios)
- [Generation Options](#generation-options)
- [Indexing to OpenSearch](#indexing-to-opensearch)
- [Testing with Orion](#testing-with-orion)
- [Understanding Results](#understanding-results)
- [Advanced Usage](#advanced-usage)
- [Troubleshooting](#troubleshooting)

## Why Mock Data?

Without controlled test data, it's difficult to:

1. **Verify detection algorithms work** - Real data may not have regressions
2. **Test edge cases** - Gradual degradation, improvements, outliers
3. **Develop new features** - Need predictable data to test against
4. **Tune thresholds** - Understand sensitivity without waiting for real issues
5. **Document behavior** - Show examples of what triggers detection

Mock data solves this by providing **controlled scenarios** that trigger specific Orion behaviors.

## Quick Start

### 1. Generate Mock Data

```bash
# Generate all scenarios (recommended for first time)
cd .
./scripts/generate-mock-data.py --scenario all --output mock-all.json

# This creates ~180 documents across all scenarios
```

### 2. Index to OpenSearch

```bash
# Index with authentication
./scripts/generate-mock-data.py \
  --scenario all \
  --index-to-opensearch \
  --es-server http://your-opensearch:9200 \
  --es-user admin \
  --es-password your-password

# Or set environment variable to avoid typing password
export ES_SERVER=http://your-opensearch:9200
./scripts/generate-mock-data.py --scenario all --index-to-opensearch
```

### 3. Verify Data Indexed

```bash
# Check document count
curl "http://your-opensearch:9200/regulus-results-mock/_count"

# Expected result: ~180 documents for "all" scenario
```

### 4. Run Orion Tests

```bash
# Test sudden regression detection
cd /path/to/orion
./run-it --config ./configs/regulus-mock-regression.yaml \
  --hunter-analyze \
  --benchmark-index=regulus-results-mock* \
  --metadata-index=regulus-results-mock*

# Or run full test suite
export ORION_DIR=/path/to/orion
./scripts/test-mock-data.sh
```

## Mock Data Scenarios

The generator creates six different scenarios to test various detection capabilities:

### 1. Stable Baseline (No Detection Expected)

**Scenario:** `stable`
**Purpose:** Verify Orion doesn't false-positive on normal variance

```bash
./scripts/generate-mock-data.py --scenario stable --samples 30
```

**Characteristics:**
- 30 samples with normal Gaussian noise
- Mean: 8.5 Gbps ± 0.3 Gbps
- No sustained changes
- **Expected Orion Result:** "No regressions found" ✓

**Use Case:** Baseline testing, false-positive verification

---

### 2. Sudden Regression (Detection Expected)

**Scenario:** `regression`
**Purpose:** Test detection of sudden performance drops

```bash
./scripts/generate-mock-data.py --scenario regression --samples 30
```

**Characteristics:**
- 15 baseline samples at 8.5 Gbps
- **Sudden 25% drop** to 6.4 Gbps
- 15 regressed samples
- Metadata: `topology=internode, protocol=tcp, nic=mlx5_0`
- **Expected Orion Result:** Changepoint detected ✓

**Use Case:** Verify basic regression detection works

**Config:** `configs/regulus-mock-regression.yaml`

---

### 3. Gradual Degradation (Detection Expected)

**Scenario:** `gradual`
**Purpose:** Test detection of slow performance decline

```bash
./scripts/generate-mock-data.py --scenario gradual --samples 40
```

**Characteristics:**
- Linear degradation from 8.5 Gbps to 5.95 Gbps
- **30% total degradation** over 40 samples
- Metadata: `topology=pod-to-pod, protocol=tcp, nic=mlx5_1`
- **Expected Orion Result:** Changepoint detected ✓

**Use Case:** Memory leaks, gradual resource exhaustion

**Config:** `configs/regulus-mock-gradual.yaml`

---

### 4. Performance Improvement (Detection with direction=0)

**Scenario:** `improvement`
**Purpose:** Test detection of performance gains

```bash
./scripts/generate-mock-data.py --scenario improvement --samples 30
```

**Characteristics:**
- 15 baseline samples at 8.5 Gbps
- **20% improvement** to 10.2 Gbps
- 15 improved samples
- Metadata: `topology=internode, protocol=udp, nic=ens1f0`
- **Expected Orion Result:** Changepoint detected (if `direction: 0`) ✓

**Use Case:** Optimization verification, A/B testing

**Config:** `configs/regulus-mock-improvement.yaml`

---

### 5. Intermittent Outliers (No Detection Expected)

**Scenario:** `intermittent`
**Purpose:** Verify Hunter ignores temporary issues

```bash
./scripts/generate-mock-data.py --scenario intermittent --samples 30
```

**Characteristics:**
- 30 samples with normal performance
- **3 random outliers** (30% drops)
- Outliers are isolated, not sustained
- Metadata: `topology=internode, protocol=tcp, nic=bond0`
- **Expected Orion Result:** "No regressions found" ✓

**Use Case:** Verify robustness to transient issues

**Config:** `configs/regulus-mock-intermittent.yaml`

**Why This Matters:** Hunter's EDivisive algorithm should distinguish temporary anomalies from sustained regressions. This scenario validates that behavior.

---

### 6. Multi-Metric (Detection in All Metrics)

**Scenario:** `multi-metric`
**Purpose:** Test simultaneous monitoring of multiple metrics

```bash
./scripts/generate-mock-data.py --scenario multi-metric --samples 30
```

**Characteristics:**
- **Three metrics:** throughput (Gbps), transactions (trans/sec), connections (conn/sec)
- Each metric: 15 baseline + 15 regressed samples
- 20% regression in all metrics
- Metadata: `topology=internode, protocol=tcp, threads=4`
- **Expected Orion Result:** Changepoints in all 3 metrics ✓

**Use Case:** Comprehensive monitoring, correlated failures

**Config:** `configs/regulus-mock-multimetric.yaml`

---

## Generation Options

### Basic Options

```bash
# Specify number of samples
./scripts/generate-mock-data.py --scenario stable --samples 60

# Change time range (start N days in the past)
./scripts/generate-mock-data.py --scenario regression --days 60

# Custom output file
./scripts/generate-mock-data.py --scenario all --output my-test-data.json
```

### Generate All Scenarios

```bash
# Creates data for all 6 scenarios
./scripts/generate-mock-data.py --scenario all --samples 30

# Total documents: ~180 (varies by scenario)
# - stable: 30 docs
# - regression: 30 docs
# - gradual: 40 docs (more samples for gradual changes)
# - improvement: 30 docs
# - intermittent: 30 docs
# - multi-metric: 90 docs (3 metrics × 30 samples each)
```

## Indexing to OpenSearch

### Direct Indexing

```bash
# Index directly during generation
./scripts/generate-mock-data.py \
  --scenario all \
  --index-to-opensearch \
  --es-server http://localhost:9200 \
  --es-index regulus-results-mock
```

### With Authentication

```bash
# Basic auth
./scripts/generate-mock-data.py \
  --scenario all \
  --index-to-opensearch \
  --es-server https://your-opensearch:9200 \
  --es-user admin \
  --es-password 'YourPassword123'
```

### Index Existing JSON File

If you already generated JSON and want to index it:

```bash
# Using curl with bulk API
curl -X POST "http://localhost:9200/_bulk" \
  -H "Content-Type: application/x-ndjson" \
  --data-binary "@mock-data.ndjson"

# Note: You need to convert JSON array to NDJSON format first
```

### Verify Indexing

```bash
# Count documents
curl "http://localhost:9200/regulus-results-mock/_count?pretty"

# Search for specific scenario
curl "http://localhost:9200/regulus-results-mock/_search?pretty" \
  -H 'Content-Type: application/json' -d '{
  "query": {"term": {"nic": "mlx5_0"}},
  "size": 1
}'

# Check aggregations
curl "http://localhost:9200/regulus-results-mock/_search?size=0&pretty" \
  -H 'Content-Type: application/json' -d '{
  "aggs": {
    "by_nic": {"terms": {"field": "nic", "size": 10}},
    "by_topology": {"terms": {"field": "topology", "size": 10}}
  }
}'
```

## Testing with Orion

### Individual Scenario Tests

```bash
cd /path/to/orion

# Test 1: Sudden Regression
./run-it --config ./configs/regulus-mock-regression.yaml \
  --hunter-analyze \
  --benchmark-index=regulus-results-mock* \
  --metadata-index=regulus-results-mock* \
  --debug

# Test 2: Gradual Degradation
./run-it --config ./configs/regulus-mock-gradual.yaml \
  --hunter-analyze \
  --benchmark-index=regulus-results-mock* \
  --metadata-index=regulus-results-mock*

# Test 3: Improvement Detection
./run-it --config ./configs/regulus-mock-improvement.yaml \
  --hunter-analyze \
  --benchmark-index=regulus-results-mock* \
  --metadata-index=regulus-results-mock*

# Test 4: Intermittent Outliers (should NOT detect)
./run-it --config ./configs/regulus-mock-intermittent.yaml \
  --hunter-analyze \
  --benchmark-index=regulus-results-mock* \
  --metadata-index=regulus-results-mock*

# Test 5: Multi-Metric
./run-it --config ./configs/regulus-mock-multimetric.yaml \
  --hunter-analyze \
  --benchmark-index=regulus-results-mock* \
  --metadata-index=regulus-results-mock*
```

### Automated Test Suite

```bash
# Run all tests automatically
export ORION_DIR=/path/to/orion
export ES_SERVER=http://localhost:9200
export ES_INDEX=regulus-results-mock

./scripts/test-mock-data.sh
```

The test suite will:
1. Run all 5 test scenarios
2. Capture output to `output/mock-tests/`
3. Verify expected vs actual detection results
4. Provide summary report

## Understanding Results

### Expected Outcomes

| Scenario | Expected Result | What to Look For |
|----------|----------------|------------------|
| Stable | No detection | "No regressions found" |
| Regression | Detection | Changepoint at sample ~15 |
| Gradual | Detection | Changepoint detected |
| Improvement | Detection (dir=0) | Changepoint detected as increase |
| Intermittent | No detection | Outliers ignored |
| Multi-metric | 3 detections | One per metric type |

### Interpreting Orion Output

**Success - Detection Found:**
```
Changepoint detected at index 15
Regression: 8.5 Gbps → 6.4 Gbps (-24.7%)
```

**Success - No Detection (when expected):**
```
No regressions found
Hunter analyzed 30 samples with no sustained changepoints
```

**Possible Issue - No Detection (when expected):**
```
No regressions found
```
Possible causes:
- Insufficient samples (try `--samples 40` or more)
- Threshold too high (lower `threshold: 5` to `threshold: 3`)
- Wrong direction setting (use `direction: 0` for both)

### Debug Mode

```bash
# Add --debug for detailed output
./run-it --config configs/regulus-mock-regression.yaml \
  --hunter-analyze \
  --benchmark-index=regulus-results-mock* \
  --metadata-index=regulus-results-mock* \
  --debug
```

This shows:
- Data retrieval from OpenSearch
- Number of samples analyzed
- Statistical calculations
- EDivisive algorithm execution
- Changepoint detection details

## Advanced Usage

### Custom Scenarios

Modify `generate-mock-data.py` to create custom scenarios:

```python
# Example: Severe regression (50% drop)
docs = generator.generate_sudden_regression(
    metric_type='throughput',
    num_baseline=20,
    num_regressed=20,
    regression_pct=50.0,  # 50% drop
    test_config={'topology': 'internode', 'protocol': 'tcp', 'nic': 'custom'}
)
```

### Multiple Test Variations

Create data with different hardware configurations:

```python
# Generate data for different NICs
for nic in ['mlx5_0', 'mlx5_1', 'ens1f0', 'ens1f1']:
    docs = generator.generate_sudden_regression(
        test_config={'topology': 'internode', 'protocol': 'tcp', 'nic': nic}
    )
    all_documents.extend(docs)
```

### Time-Based Analysis

```bash
# Generate data over longer time period
./scripts/generate-mock-data.py \
  --scenario gradual \
  --days 90 \
  --samples 90

# This creates 90 days of gradual degradation
```

### Threshold Tuning

Test different threshold values:

```yaml
# In your config file
metrics:
  - name: sensitive_detection
    threshold: 2    # More sensitive (2% change)

  - name: normal_detection
    threshold: 5    # Normal (5% change)

  - name: conservative_detection
    threshold: 10   # Conservative (10% change)
```

## Troubleshooting

### Issue: "No UUID present for given metadata"

**Cause:** Metadata filters don't match generated data

**Solution:** Check your config's metadata section matches the generated data:

```bash
# Check what metadata exists in your mock data
curl "http://localhost:9200/regulus-results-mock/_search?size=1&pretty" \
  -H 'Content-Type: application/json' -d '{
  "query": {"term": {"mock_data": true}},
  "_source": ["topology", "protocol", "nic", "benchmark", "unit"]
}'
```

Ensure your config matches:
```yaml
metadata:
  benchmark: uperf      # Must match
  unit: Gbps            # Must match
  topology: internode   # Must match if present in data
  protocol: tcp         # Must match if present in data
  nic: mlx5_0          # Must match if present in data
  mock_data: true      # Important!
```

### Issue: No Changepoint Detected (When Expected)

**Possible Causes:**

1. **Insufficient samples**
   ```bash
   # Generate more samples
   ./scripts/generate-mock-data.py --scenario regression --samples 60
   ```

2. **Threshold too high**
   ```yaml
   # Lower threshold in config
   threshold: 3  # Instead of 5
   ```

3. **Wrong direction**
   ```yaml
   # For improvements or bidirectional
   direction: 0  # Instead of -1
   ```

4. **Regression too small**
   - Modify generator to create larger regression (30-40%)

### Issue: Changepoint Detected (When NOT Expected)

**For Intermittent Scenario:**

This might indicate:
- Too many outliers generated (check `num_outliers` parameter)
- Outliers clustered together instead of spread out
- Threshold too low

**Solution:**
```python
# In generate-mock-data.py, adjust:
docs = generator.generate_intermittent_issues(
    num_samples=40,    # More samples
    num_outliers=2,    # Fewer outliers
    outlier_drop_pct=20.0  # Smaller drops
)
```

### Issue: Index Already Exists with Old Data

**Clear and reindex:**

```bash
# Delete old index
curl -X DELETE "http://localhost:9200/regulus-results-mock"

# Regenerate and reindex
./scripts/generate-mock-data.py \
  --scenario all \
  --index-to-opensearch
```

### Issue: Authentication Failed

**Check credentials:**

```bash
# Test OpenSearch connection
curl -u admin:password "http://localhost:9200/_cluster/health?pretty"

# Use environment variables
export ES_USER=admin
export ES_PASSWORD=yourpassword

# Or pass explicitly
./scripts/generate-mock-data.py \
  --index-to-opensearch \
  --es-user admin \
  --es-password yourpassword
```

## Best Practices

### 1. Start with "all" Scenario

```bash
# Generate all scenarios first
./scripts/generate-mock-data.py --scenario all --index-to-opensearch
```

This gives you a complete test suite to validate Orion behavior.

### 2. Use Descriptive Index Names

```bash
# Separate indices for different test purposes
--es-index regulus-results-mock-dev     # Development testing
--es-index regulus-results-mock-prod    # Production validation
--es-index regulus-results-mock-v2      # After Orion updates
```

### 3. Version Your Mock Data

```bash
# Save generated data for reproducibility
./scripts/generate-mock-data.py --scenario all --output mock-data-v1.json

# Later, regenerate with same parameters for consistency
```

### 4. Document Expected Results

Create a test matrix:

```markdown
| Config | Scenario | Expected | Actual | Pass |
|--------|----------|----------|--------|------|
| regression | Sudden drop | DETECT | DETECT | ✓ |
| intermittent | Outliers | NO_DETECT | NO_DETECT | ✓ |
```

### 5. Clean Up Between Tests

```bash
# Delete mock indices when done
curl -X DELETE "http://localhost:9200/regulus-results-mock*"
```

## Next Steps

1. **Generate mock data**: `./scripts/generate-mock-data.py --scenario all --index-to-opensearch`
2. **Run test suite**: `./scripts/test-mock-data.sh`
3. **Verify detection**: Check that regressions are detected and outliers ignored
4. **Tune configs**: Adjust thresholds based on results
5. **Develop features**: Use mock data to test new Orion capabilities

## References

- [Orion Documentation](https://github.com/cloud-bulldozer/orion)
- [Hunter/EDivisive Algorithm](https://github.com/apache/otava)
- [Main README](../README.md)
- [Scaling Strategy](SCALING-STRATEGY.md)
