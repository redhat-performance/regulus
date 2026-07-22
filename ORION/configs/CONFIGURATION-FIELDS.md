# Orion Configuration Fields for Regulus

This guide explains what each field in the Orion YAML configuration does and what's required for Regulus data.

## Table of Contents
- [Required Test-Level Fields](#required-test-level-fields)
- [Required Metric Fields](#required-metric-fields)
- [Metadata Fields](#metadata-fields)
- [Data Field Mappings](#data-field-mappings)
- [Analysis Algorithms](#analysis-algorithms)
- [Common Issues and Solutions](#common-issues-and-solutions)

---

## Required Test-Level Fields

### `name` (string, required)
**Purpose**: Unique identifier for this test configuration
**Example**: `"regulus-throughput-tcp"`
**Usage**: Shows up in Orion output and logs

### `timestamp` (string, required)
**Purpose**: Tells Orion which field in your data contains the timestamp
**For Regulus**: Use `"@timestamp"`
**Important**: Must be in ISO 8601 format (e.g., `2026-06-02T00:13:25.441141`)

### `uuid_field` (string, required)
**Purpose**: Unique identifier for each test iteration/sample
**For Regulus**: Use `"iteration_id"`

**Important Regulus Data Hierarchy:**
```
run_id          → Crucible invocation (groups multiple tests)
  ├─ test 1     → Test with unique fingerprint (benchmark, unit, topology, etc.)
  │    ├─ iteration_id (unique per test iteration) ← USE THIS for uuid_field
  │    └─ iteration_id (another test iteration)
  └─ test 2     → Different test
       └─ iteration_id (unique per test iteration)
```

**Critical Requirements**:
- This field MUST be mapped with `.keyword` subfield in OpenSearch/Elasticsearch
- Each document must have a unique value
- Use `iteration_id` (not `run_id`) for Regulus - this is the unique identifier per test iteration

### `version_field` (string, required)
**Purpose**: Field containing version/build information for grouping and display
**For Regulus**: Use `"rcos"` (or any field that identifies the software version)
**Important**:
- This is just for display/grouping - Orion doesn't care about the semantics
- All test runs can have the same value
- Shows up in regression reports as "Previous version" and "Changepoint at"

---

## Required Metric Fields

### `name` (string, required)
**Purpose**: Identifier for this specific metric
**Example**: `"throughput"`, `"latency"`, `"connections"`
**Important**: Orion creates a column named `{name}_{metric_of_interest}` in the dataframe

### `metric_of_interest` (string, required)
**Purpose**: Which field in your data contains the actual metric value
**For Regulus**: Usually `"mean"` (but could be `"min"`, `"max"`, `"stddev"`)
**Important**: This is the value that EDivisive will analyze for regressions

### `direction` (integer, required)
**Purpose**: Defines what kind of changes to detect as regressions
**Values**:
- `1` - Detect only INCREASES (higher is worse) - e.g., latency, errors
- `-1` - Detect only DECREASES (lower is worse) - e.g., throughput, bandwidth
- `0` - Detect both increases and decreases

**For Regulus Network Tests**: Use `-1` because:
- Throughput dropping is bad (lower Gbps = regression)
- Bandwidth dropping is bad
- Transaction rate dropping is bad

### `threshold` (number, required)
**Purpose**: Minimum percentage change to consider significant
**Example**: `5` means ignore changes smaller than 5%
**Recommendation**:
- Network throughput: `5` to `10` (catches meaningful drops)
- Latency: `10` to `20` (more tolerant of variance)

### `labels` (array of strings, optional)
**Purpose**: Tags for categorizing/filtering regressions in reports
**Example**: `["[Jira: NETWORK-123]", "[Team: Perf]"]`
**Usage**: Helps organize regressions when you have many tests

---

## Metadata Fields

### `metadata` section (object, required)
**Purpose**: Filters that define which documents to analyze

The `metadata` section has **two uses**:

#### 1. **As Filters** (what you include)
Fields listed here are used as **query filters** to select which documents to analyze.

**For Regulus**, always include:
```yaml
metadata:
  benchmark: uperf          # REQUIRED - selects test type
  unit: Gbps               # REQUIRED - selects metric unit
```

**Optionally include** (to create separate analyses per combination):
```yaml
metadata:
  benchmark: uperf
  unit: Gbps
  topology: internode      # OPTIONAL - analyze internode separately
  protocol: tcp            # OPTIONAL - analyze TCP separately
  nic: mlx5_0             # OPTIONAL - analyze specific NIC
```

#### 2. **As Documentation** (what you exclude)
Fields NOT listed are ignored - they don't filter or affect analysis.

**Common Regulus fields to EXCLUDE**:
- `execution_label` - just a run identifier, not a test dimension
- `regulus_git_branch` - unless you want to filter by branch
- `batch_id` - internal ID, not meaningful for analysis
- `iteration_id` - internal ID
- `arch`, `kernel`, `model` - unless testing across different hardware

### Key Principle: "Only Filter What Matters"

**Good** - Separate analysis per test type:
```yaml
metadata:
  benchmark: uperf
  unit: Gbps
  topology: internode  # Want separate analysis for internode vs intranode
  protocol: tcp        # Want separate analysis for TCP vs UDP
```

**Bad** - Over-filtering leads to too little data:
```yaml
metadata:
  benchmark: uperf
  unit: Gbps
  topology: internode
  protocol: tcp
  nic: mlx5_0
  threads: 1           # TOO SPECIFIC! May not have enough data points
  wsize: 64            # TOO SPECIFIC!
```

---

## Data Field Mappings

### OpenSearch/Elasticsearch Index Mapping Requirements

**Critical**: The `uuid_field` (`iteration_id` for Regulus) MUST have a `.keyword` subfield.

**Correct mapping** (what Orion expects):
```json
{
  "mappings": {
    "properties": {
      "iteration_id": {
        "type": "text",
        "fields": {
          "keyword": {
            "type": "keyword"
          }
        }
      }
    }
  }
}
```

**Why**: Orion queries with `iteration_id.keyword` for exact matching. If your field is just `type: keyword` without a `.keyword` subfield, queries will return 0 results.

**To fix an existing index**:
```bash
# Delete the index
curl -X DELETE "http://localhost:9200/regulus-results-mock"

# Create with proper mapping
curl -X PUT "http://localhost:9200/regulus-results-mock" -H 'Content-Type: application/json' -d '{
  "mappings": {
    "properties": {
      "iteration_id": {
        "type": "text",
        "fields": {
          "keyword": {
            "type": "keyword"
          }
        }
      }
    }
  }
}'

# Re-index your data
```

---

## Analysis Algorithms

Orion supports three regression detection algorithms. Choose based on your use case:

### Hunter (EDivisive) - RECOMMENDED for Regulus ✓

**Command:**
```bash
./scripts/run-it --config configs/regulus.yaml --hunter-analyze --lookback=7d
```

**When to use:**
- Daily/weekly performance monitoring
- Detecting sustained performance regressions
- Production regression alerts

**Pros:**
- ✓ Accurately detects sustained changes (-24.5% in tests)
- ✓ Ignores temporary outliers (low false positive rate)
- ✓ Best for long-term trend analysis

**Cons:**
- Requires 20-30+ data points
- Struggles with gradual degradation

---

### CMR (Comparing Mean Responses) - For CI/CD

**Command:**
```bash
./scripts/run-it --config configs/regulus.yaml --cmr --lookback=10d
```

**When to use:**
- CI/CD pipeline quality gates
- Quick "is this run bad?" checks
- Before/after upgrade comparisons

**Pros:**
- ✓ Simple and fast
- ✓ Works with just 2 data points
- ✓ Easy to understand

**Cons:**
- Can underestimate severity (averages good+bad data)
- Not suitable for continuous monitoring

---

### Anomaly Detection (IsolationForest) - Use With Caution ⚠

**Command:**
```bash
./scripts/run-it --config configs/regulus.yaml \
  --anomaly-detection --anomaly-window 5 --min-anomaly-percent 10
```

**When to use:**
- Finding intermittent issues
- Detecting unusual test runs
- Real-time anomaly alerts

**Pros:**
- ✓ Detects temporary spikes/dips
- ✓ Good for outlier detection

**Cons:**
- More prone to false positives
- May have issues with NaN values
- Not ideal for regression detection

---

**Recommendation:** Use `--hunter-analyze` for Regulus. It's been tested and proven most accurate for network performance regression detection.

See [README-REGULUS.md](./README-REGULUS.md#analysis-algorithms) for detailed comparison and test results.

---

## Common Issues and Solutions

### Issue: "No regressions found" but data shows clear drop

**Possible Causes**:

1. **Wrong `direction` value**
   - Solution: Use `direction: 0` to detect changes in either direction
   - Use `-1` (lower is worse) or `1` (higher is worse) for single-direction detection

2. **`threshold` too high**
   - Solution: Lower threshold (try `5` instead of `10`)
   - Check: Are your regressions smaller than the threshold?

3. **Empty dataframe (0 rows)**
   - Cause: `iteration_id.keyword` field mapping issue
   - Solution: See [Data Field Mappings](#data-field-mappings) above

4. **Reporting bug** (if using older Orion)
   - The condition in `orion/reporting/report.py:182` should be `> 0` not `< 0`
   - This bug filters out valid regressions with `direction: -1`

### Issue: "No UUID present" error

**Cause**: Metadata filtering is too restrictive
**Solution**:
- Remove fields from `metadata` section that aren't common to all your data
- Only include fields you actually want to filter on

### Issue: Not enough data points for analysis

**Cause**: Too many filters in `metadata` section
**Solution**:
- Remove some filters
- Combine multiple test variations into one config
- Need at least 20-30 data points for reliable EDivisive analysis

---

## Complete Working Example

```yaml
tests:
  - name: regulus-internode-tcp-throughput
    timestamp: "@timestamp"
    uuid_field: "iteration_id"
    version_field: "rcos"

    metadata:
      benchmark: uperf
      unit: Gbps
      topology: internode
      protocol: tcp
      # Note: NOT filtering by nic, threads, wsize
      # This groups all variations together for more robust analysis

    metrics:
      - name: throughput
        metric_of_interest: mean
        direction: 0         # Flag changes in either direction
        threshold: 5         # Ignore changes < 5%
        labels:
          - "[Jira: NETWORK-789]"
          - "[Team: Regulus]"
```

### Command Line Usage

```bash
./scripts/run-it \
  --config configs/regulus-internode-tcp.yaml \
  --metadata-index regulus-results \
  --benchmark-index regulus-results \
  --hunter-analyze \
  --lookback 30d
```

**CLI Arguments**:
- `--metadata-index`: Index to query for UUIDs (iteration_ids)
- `--benchmark-index`: Index to query for metric data
- `--hunter-analyze`: Use EDivisive algorithm
- `--lookback`: How far back to look for data (e.g., `30d`, `7d`)

---

## Field Reference Summary

| Field | Required | Location | Purpose | Regulus Value |
|-------|----------|----------|---------|---------------|
| `name` | Yes | Test | Test identifier | Your choice |
| `timestamp` | Yes | Test | Timestamp field | `"@timestamp"` |
| `uuid_field` | Yes | Test | Unique iteration ID | `"iteration_id"` |
| `version_field` | Yes | Test | Version field | `"rcos"` |
| `benchmark` | Yes | Metadata | Test type filter | `"uperf"` |
| `unit` | Yes | Metadata | Metric unit filter | `"Gbps"`, `"trans-sec"`, etc. |
| `name` | Yes | Metric | Metric identifier | `"throughput"` |
| `metric_of_interest` | Yes | Metric | Value field | `"mean"` |
| `direction` | Yes | Metric | Regression type | `0` (both directions) |
| `threshold` | Yes | Metric | Min % change | `5` to `10` |

---

## Advanced: Understanding How Orion Processes Data

1. **Query Phase**: Orion queries `metadata-index` with filters from `metadata` section to get matching `iteration_id`s
2. **Data Phase**: Orion queries `benchmark-index` for those specific `iteration_id`s to get metric values
3. **DataFrame**: Orion creates a pandas DataFrame with columns: `[iteration_id, {metric_name}_{metric_of_interest}, timestamp, buildUrl, {version_field}]`
4. **Analysis**: EDivisive analyzes the time series to find changepoints
5. **Filtering**: Changepoints are filtered by `direction`, `threshold`, and ACK status
6. **Reporting**: Remaining changepoints are formatted and displayed

This is why:
- `uuid_field` needs `.keyword` subfield (for querying in step 1)
- `metadata` filters matter (they determine what data is included in step 1)
- `direction` matters (filters out wrong-direction changes in step 5)

**Note**: Use `iteration_id` for Regulus (not `run_id`). Each iteration is a unique test sample, while `run_id` groups multiple tests together.

---

## See Also

- [Orion Official Configuration Docs](https://github.com/cloud-bulldozer/orion/blob/main/docs/configuration.md)
- [Mock Data Generator Guide](./MOCK-DATA-GUIDE.md) - For testing configurations
- [Scaling Strategy](./SCALING-STRATEGY.md) - For handling many test variations
