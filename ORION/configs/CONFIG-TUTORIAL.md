# Orion Configuration Tutorial - Understanding Every Field

This tutorial teaches you how to read and understand Orion YAML configuration files. We'll break down each field line-by-line with examples.

---

## Table of Contents

- [Anatomy of a Configuration File](#anatomy-of-a-configuration-file)
- [Top-Level Structure](#top-level-structure)
- [Test-Level Fields](#test-level-fields)
- [Metadata Section](#metadata-section)
- [Metrics Section](#metrics-section)
- [Complete Annotated Example](#complete-annotated-example)
- [Common Patterns](#common-patterns)
- [Hands-On Exercises](#hands-on-exercises)

---

## Anatomy of a Configuration File

An Orion config file has this basic structure:

```yaml
tests:                          # List of tests to analyze
  - name: test-name-here        # First test definition
    timestamp: field-name
    uuid_field: field-name
    version_field: field-name

    metadata:                   # Filters to select data
      key: value

    metrics:                    # Metrics to monitor
      - name: metric-name       # First metric
        metric_of_interest: field
        direction: number
        threshold: number

  - name: another-test          # Second test (optional)
    # ... same structure
```

Let's break down each part!

---

## Top-Level Structure

### `tests:`

```yaml
tests:
  - name: ...
  - name: ...
```

**What it is:** A YAML list (array) of test configurations

**Why it exists:** Allows you to define multiple tests in one config file

**Example use cases:**
- One test for throughput, another for transactions
- Separate tests for different network topologies
- Different test configurations with different thresholds

**Important:** The `-` (dash) indicates a list item. Each test is a separate item in the list.

---

## Test-Level Fields

These fields define **how Orion finds and organizes your data**.

### `name:` (string, required)

```yaml
name: "regulus-throughput"
```

**What it is:** A unique identifier for this test configuration

**Where it appears:**
- In Orion's console output
- In report headings
- In log files

**Naming tips:**
- Use descriptive names: `internode-tcp-throughput` not `test1`
- Use hyphens, not spaces: `my-test` not `my test`
- Include test category: `regulus-dataplane-throughput`

**Examples:**
```yaml
name: "regulus-throughput"              # Generic
name: "internode-tcp-throughput"        # Category-specific
name: "mlx5-nic-performance"            # Hardware-specific
```

---

### `timestamp:` (string, required)

```yaml
timestamp: "@timestamp"
```

**What it is:** The name of the field in your Elasticsearch/OpenSearch documents that contains the timestamp

**Why it's needed:** Orion uses this to:
- Sort test runs chronologically
- Create time-series analysis
- Show when regressions occurred

**For Regulus:** Always use `"@timestamp"`

**Format expected:** ISO 8601 format
```
2026-06-02T00:13:25.441141
2026-07-02T14:30:00.000000Z
```

**Common mistakes:**
```yaml
timestamp: "@timestamp"     # ✓ Correct (with quotes)
timestamp: @timestamp       # ✗ Wrong (YAML treats @ as special)
timestamp: "timestamp"      # ✗ Wrong (missing @ symbol)
```

---

### `uuid_field:` (string, required)

```yaml
uuid_field: "iteration_id"
```

**What it is:** The field containing a unique identifier for each test iteration/sample

**Why it's needed:** Orion uses this to:
1. Query specific test iterations from Elasticsearch
2. Group results by test sample
3. Fetch detailed data for detected regressions

**For Regulus:** Use `"iteration_id"` (NOT `"run_id"`!)

**Important Regulus Data Hierarchy:**
```
run_id          → Crucible invocation (groups multiple tests together)
  ├─ test 1     → Test with specific fingerprint (benchmark, unit, topology, etc.)
  │    ├─ iteration_id (unique test sample) ← USE THIS for uuid_field
  │    ├─ iteration_id (another test sample)
  │    └─ iteration_id (another test sample)
  └─ test 2     → Different test
       ├─ iteration_id (unique test sample)
       └─ iteration_id (unique test sample)
```

**Why `iteration_id` not `run_id`:**
- `run_id` groups multiple tests together (wrong granularity)
- `iteration_id` identifies each individual test result (correct granularity)
- Orion needs unique identifier per data point, which is `iteration_id`

**Critical requirement:** This field MUST have a `.keyword` subfield in Elasticsearch

**Why `.keyword` matters:**
```
Orion queries:  iteration_id.keyword = "abc-123-def-456"
                            ^^^^^^^^
                         This subfield must exist!
```

**Elasticsearch mapping needed:**
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

**Common field names:**
- `iteration_id` (Regulus - unique per test sample)
- `uuid` (OpenShift CI)
- `test_id` (custom pipelines)

---

### `version_field:` (string, required)

```yaml
version_field: "rcos"
```

**What it is:** The field containing version/build information

**Why it's needed:** Orion uses this to:
- Label changepoints in reports: "Changepoint at version X.Y.Z"
- Show "Previous version" and "Current version" in regression reports
- Group test runs by version for display

**For Regulus:** Use `"rcos"` (RHCOS version)

**Important:** This is just for **display and grouping** - Orion doesn't care about version semantics

**What it can contain:**
```yaml
# Any of these work:
"4.14.0-rc.1"                  # Semantic version
"2026-07-02-nightly"           # Date-based build
"commit-abc123"                # Git commit
"1.0"                          # Simple version
"production"                   # Environment label
```

**Can all runs have the same version?** Yes! Orion will still detect regressions.

**Examples:**
```yaml
version_field: "rcos"              # Regulus RHCOS version
version_field: "kernel_version"    # Linux kernel version
version_field: "build_id"          # CI build number
version_field: "git_commit"        # Git SHA
```

---

## Metadata Section

The `metadata:` section contains **filters** that determine which documents to analyze.

### How Metadata Works

```yaml
metadata:
  benchmark: uperf
  unit: Gbps
  topology: internode
```

**What this does:** Orion will only analyze documents where:
```
benchmark == "uperf" AND
unit == "Gbps" AND
topology == "internode"
```

**Elasticsearch query generated:**
```json
{
  "query": {
    "bool": {
      "must": [
        {"term": {"benchmark": "uperf"}},
        {"term": {"unit": "Gbps"}},
        {"term": {"topology": "internode"}}
      ]
    }
  }
}
```

### Two Key Concepts

#### 1. **Inclusion** (what you add)
Fields you list in `metadata:` are used as **query filters**.

```yaml
metadata:
  benchmark: uperf
  unit: Gbps
```
→ Only analyzes documents with `benchmark=uperf` AND `unit=Gbps`

#### 2. **Exclusion** (what you omit)
Fields NOT listed are **ignored** - they don't affect the query.

```yaml
metadata:
  benchmark: uperf
  unit: Gbps
  # execution_label: NOT included
  # regulus_git_branch: NOT included
```
→ All `execution_label` values included (default, non-accelerated, etc.)
→ All `regulus_git_branch` values included (main, dpu-lab, etc.)

### Required Metadata Fields

**For Regulus, always include:**

```yaml
metadata:
  benchmark: uperf          # REQUIRED - selects test tool
  unit: Gbps                # REQUIRED - selects metric type
```

**Why these are required:**
- `benchmark` - Distinguishes uperf from other tools (fio, iperf3, etc.)
- `unit` - Distinguishes throughput (Gbps) from transactions (trans-sec) from connections (conn-sec)

### Optional Metadata Fields

**Include ONLY if you want separate analysis per value:**

```yaml
metadata:
  benchmark: uperf
  unit: Gbps
  topology: internode      # Optional - analyze internode separately from intranode
  protocol: tcp            # Optional - analyze TCP separately from UDP
```

**Effect of adding optional fields:**

**Without topology filter:**
```yaml
metadata:
  benchmark: uperf
  unit: Gbps
```
→ Analyzes ALL topologies together (internode + intranode combined)

**With topology filter:**
```yaml
metadata:
  benchmark: uperf
  unit: Gbps
  topology: internode
```
→ Analyzes ONLY internode tests (intranode excluded)

### Common Regulus Metadata Fields

| Field | Values | Include if... |
|-------|--------|---------------|
| `benchmark` | `uperf` | Always (required) |
| `unit` | `Gbps`, `trans-sec`, `conn-sec` | Always (required) |
| `topology` | `internode`, `intranode` | You want separate analysis per topology |
| `protocol` | `tcp`, `udp` | You want separate analysis per protocol |
| `nic` | `mlx5_0`, `X550`, `bond-bf3` | Analyzing specific hardware (usually too specific) |
| `threads` | `1`, `2`, `4` | Testing thread scaling (usually too specific) |
| `wsize` | `64`, `1024`, `8192` | Testing different workloads (usually too specific) |

**Fields to EXCLUDE (informational only):**
- `execution_label` - Just a run context label
- `regulus_git_branch` - Unless filtering by branch
- `batch_id` - Internal batch identifier
- `iteration_id` - Internal iteration number
- `arch`, `kernel`, `model` - Unless testing across different systems

### Metadata Best Practices

**✓ Good - Minimal filtering:**
```yaml
metadata:
  benchmark: uperf
  unit: Gbps
```
→ Maximum data points, robust analysis

**✓ Good - Category filtering:**
```yaml
metadata:
  benchmark: uperf
  unit: Gbps
  topology: internode
  protocol: tcp
```
→ Reasonable grouping, still enough data points

**✗ Bad - Over-filtering:**
```yaml
metadata:
  benchmark: uperf
  unit: Gbps
  topology: internode
  protocol: tcp
  nic: mlx5_0
  threads: 1
  wsize: 64
```
→ Too specific! May have only 2-3 data points, unreliable analysis

---

## Metrics Section

The `metrics:` section defines **what to monitor** for regressions.

```yaml
metrics:
  - name: throughput_mean
    metric_of_interest: mean
    direction: -1
    threshold: 5
    labels:
      - "[Jira: NETWORK-123]"
```

### `name:` (metric identifier)

```yaml
- name: throughput_mean
```

**What it is:** An identifier for this specific metric

**Where it appears:**
- In Orion's dataframe columns: `throughput_mean_mean`
- In console output
- In regression reports

**Naming tips:**
- Descriptive: `throughput_mean` not `metric1`
- Use underscores: `cpu_utilization` not `cpu-utilization`
- Include metric type: `latency_p99`, `throughput_mean`

**Multiple metrics example:**
```yaml
metrics:
  - name: throughput_mean      # First metric
    # ...
  - name: cpu_utilization      # Second metric
    # ...
  - name: stddev_pct           # Third metric
    # ...
```

---

### `metric_of_interest:` (field name)

```yaml
metric_of_interest: mean
```

**What it is:** The name of the field in your Elasticsearch documents containing the actual metric value

**Why it's needed:** Tells Orion which field to analyze for regressions

**For Regulus, common values:**
- `mean` - Average throughput/performance
- `busy_cpu` - CPU utilization percentage
- `stddev_pct` - Standard deviation percentage
- `min`, `max` - Min/max values

**How Orion uses it:**
1. Queries Elasticsearch for documents matching metadata filters
2. Extracts the `metric_of_interest` field value from each document
3. Creates a time series of these values
4. Runs regression detection algorithm on the time series

**Example document:**
```json
{
  "@timestamp": "2026-07-02T10:00:00",
  "iteration_id": "abc-123",
  "benchmark": "uperf",
  "unit": "Gbps",
  "mean": 8.543,           ← metric_of_interest: mean
  "busy_cpu": 45.2,        ← metric_of_interest: busy_cpu
  "stddev_pct": 2.1        ← metric_of_interest: stddev_pct
}
```

**Column name in Orion dataframe:**
```
{metric.name}_{metric_of_interest}
```
Example: `throughput_mean_mean`, `cpu_utilization_busy_cpu`

---

### `direction:` (integer: -1, 0, or 1)

```yaml
direction: -1
```

**What it is:** Defines what kind of changes to detect as regressions

**Values:**
- `-1` - Detect only **DECREASES** (lower is worse)
- `1` - Detect only **INCREASES** (higher is worse)
- `0` - Detect **BOTH** increases and decreases

**How it works:**

**direction: -1** (lower is worse)
```
8.5 Gbps → 6.4 Gbps   ✓ Regression detected (24.7% decrease)
8.5 Gbps → 10.2 Gbps  ✗ Ignored (increase, not a regression)
```

**direction: 1** (higher is worse)
```
45% CPU → 65% CPU     ✓ Regression detected (44.4% increase)
45% CPU → 30% CPU     ✗ Ignored (decrease, not a regression)
```

**direction: 0** (detect both)
```
8.5 Gbps → 6.4 Gbps   ✓ Detected (24.7% decrease)
8.5 Gbps → 10.2 Gbps  ✓ Detected (20.0% increase)
```

**For Regulus network tests:**

```yaml
# Throughput (higher is better, lower is worse)
- name: throughput
  metric_of_interest: mean
  direction: -1              # ← Use -1 for performance metrics

# CPU utilization (lower is better, higher is worse)
- name: cpu
  metric_of_interest: busy_cpu
  direction: 1               # ← Use 1 for overhead metrics

# Debugging (see all changes)
- name: throughput
  metric_of_interest: mean
  direction: 0               # ← Use 0 for testing/debugging
```

**Common patterns:**

| Metric Type | Direction | Reason |
|-------------|-----------|--------|
| Throughput (Gbps) | `-1` | Lower throughput = regression |
| Bandwidth (MB/s) | `-1` | Lower bandwidth = regression |
| Transactions/sec | `-1` | Fewer transactions = regression |
| Latency (ms) | `1` | Higher latency = regression |
| CPU utilization (%) | `1` | Higher CPU = regression |
| Error count | `1` | More errors = regression |
| Standard deviation (%) | `1` | Higher variance = regression |

---

### `threshold:` (number, percentage)

```yaml
threshold: 5
```

**What it is:** Minimum percentage change required to report a regression

**Unit:** Percentage points (not multiplier)

**How it works:**
```
threshold: 5 means:
  - Ignore changes < 5%
  - Report changes ≥ 5%
```

**Examples:**

**threshold: 5**
```
8.5 Gbps → 8.1 Gbps   = 4.7% drop   → Ignored (below threshold)
8.5 Gbps → 8.0 Gbps   = 5.9% drop   → Reported (meets threshold)
8.5 Gbps → 6.4 Gbps   = 24.7% drop  → Reported (exceeds threshold)
```

**threshold: 10**
```
8.5 Gbps → 7.8 Gbps   = 8.2% drop   → Ignored (below threshold)
8.5 Gbps → 7.5 Gbps   = 11.8% drop  → Reported (meets threshold)
```

**Choosing the right threshold:**

**Too low (threshold: 1)**
```
Pro: Catches small regressions
Con: Generates noise, many false alarms
Use: Debugging, very stable environments
```

**Balanced (threshold: 5-10)**
```
Pro: Catches meaningful regressions, minimal noise
Con: May miss small but real issues
Use: Production monitoring (RECOMMENDED)
```

**Too high (threshold: 20)**
```
Pro: Only catastrophic failures reported
Con: Misses most real regressions
Use: Very noisy environments only
```

**Recommended thresholds by metric:**

| Metric | Threshold | Reasoning |
|--------|-----------|-----------|
| Network throughput | `5` | Network performance is relatively stable |
| Transaction rate | `5` | Similar to throughput |
| CPU utilization | `10` | CPU can vary more, need higher threshold |
| Latency | `10-15` | Latency is inherently more variable |
| Standard deviation | `15` | Variance metrics are noisy |

**Production example:**
```yaml
metrics:
  - name: throughput
    metric_of_interest: mean
    direction: -1
    threshold: 5              # Catch meaningful 5%+ drops

  - name: cpu
    metric_of_interest: busy_cpu
    direction: 1
    threshold: 10             # Allow 10% CPU variance
```

---

### `labels:` (optional, list of strings)

```yaml
labels:
  - "[Jira: NETWORK-123]"
  - "[Team: Performance]"
  - "[Priority: High]"
```

**What it is:** Tags/annotations attached to this metric

**Why it exists:**
- Categorize regressions
- Link to tracking tickets
- Filter in reports
- Organize multi-team monitoring

**Format:** Free-form strings (use any format you want)

**Common patterns:**

**Jira/GitHub issues:**
```yaml
labels:
  - "[Jira: NETWORK-789]"
  - "[GitHub: #1234]"
```

**Team/ownership:**
```yaml
labels:
  - "[Team: Networking]"
  - "[Owner: alice@example.com]"
```

**Priority/severity:**
```yaml
labels:
  - "[Priority: P0]"
  - "[Severity: Critical]"
```

**Test metadata:**
```yaml
labels:
  - "[Category: Dataplane]"
  - "[Topology: Internode]"
```

**Can be empty:**
```yaml
labels: []           # Valid - no labels
# OR omit entirely
```

---

## Complete Annotated Example

Let's walk through a complete real-world config with detailed annotations:

```yaml
# tests: is the top-level key
# Everything below is a YAML list (note the - dashes)
tests:

  # First test configuration
  - name: regulus-throughput
    # ↑ Identifier - appears in reports as "regulus-throughput"

    timestamp: "@timestamp"
    # ↑ Field name in ES containing timestamp
    # For Regulus, always "@timestamp"

    uuid_field: "iteration_id"
    # ↑ Field name containing unique run ID
    # Orion will query: run_id.keyword = "abc-123-..."
    # MUST have .keyword subfield in ES mapping!

    version_field: "rcos"
    # ↑ Field name containing version info
    # Shows up in reports: "Changepoint at version X"
    # For Regulus: RHCOS version string

    metadata:
      # ↑ FILTERS - only documents matching ALL of these are analyzed

      benchmark: uperf
      # ↑ REQUIRED - filter to uperf test results only
      # Excludes: fio, iperf3, other benchmarks

      unit: Gbps
      # ↑ REQUIRED - filter to throughput (Gbps) tests only
      # Excludes: trans-sec (transactions), conn-sec (connections)

      # Note: We did NOT include topology, protocol, nic, etc.
      # This means ALL topologies/protocols/NICs are analyzed together
      # More data points = more robust regression detection

    metrics:
      # ↑ List of metrics to monitor - can have multiple

      - name: throughput_mean
        # ↑ Identifier for this metric
        # Will create column: throughput_mean_mean

        metric_of_interest: mean
        # ↑ Which field in ES to analyze
        # Orion extracts doc["mean"] for each test run

        direction: -1
        # ↑ Alert on DECREASES only
        # -1 = lower is worse (correct for throughput)
        # If throughput drops, it's a regression
        # If throughput increases, ignore (that's good!)

        threshold: 5
        # ↑ Only report changes ≥ 5%
        # 8.5 → 8.1 Gbps = 4.7% → ignored
        # 8.5 → 8.0 Gbps = 5.9% → reported

        labels:
          - "[Jira: Networking / Throughput]"
          # ↑ Tag for categorization/tracking

      # Second metric (CPU monitoring)
      - name: cpu_utilization
        metric_of_interest: busy_cpu
        # ↑ Different field: extracts doc["busy_cpu"]

        direction: 1
        # ↑ Alert on INCREASES only
        # 1 = higher is worse (correct for CPU)
        # If CPU goes up, it's a regression

        threshold: 10
        # ↑ Higher threshold (CPU is more variable)

        labels:
          - "[Jira: Networking / CPU]"
```

**What this config does:**

1. **Finds data:**
   - Queries ES for documents where `benchmark=uperf` AND `unit=Gbps`
   - Extracts `iteration_id`, `@timestamp`, `rcos`, `mean`, `busy_cpu` fields

2. **Creates time series:**
   - Sorts by `@timestamp`
   - Creates 2 time series:
     - `throughput_mean_mean` from `mean` field
     - `cpu_utilization_busy_cpu` from `busy_cpu` field

3. **Detects regressions:**
   - Runs Hunter algorithm on both time series
   - For throughput: only report if it drops ≥5%
   - For CPU: only report if it increases ≥10%

4. **Reports results:**
   - Shows test name: "regulus-throughput"
   - Shows version at changepoint
   - Tags with Jira labels for tracking

---

## Common Patterns

### Pattern 1: Single Metric Monitoring

**Use case:** Just want to monitor throughput, nothing else

```yaml
tests:
  - name: simple-throughput
    timestamp: "@timestamp"
    uuid_field: "iteration_id"
    version_field: "rcos"

    metadata:
      benchmark: uperf
      unit: Gbps

    metrics:
      - name: throughput
        metric_of_interest: mean
        direction: -1
        threshold: 5
```

**Pros:** Simple, fast, easy to understand
**Cons:** Misses CPU/stability issues

---

### Pattern 2: Multi-Metric Monitoring

**Use case:** Monitor throughput, CPU, and stability together

```yaml
tests:
  - name: comprehensive-monitoring
    timestamp: "@timestamp"
    uuid_field: "iteration_id"
    version_field: "rcos"

    metadata:
      benchmark: uperf
      unit: Gbps

    metrics:
      - name: throughput
        metric_of_interest: mean
        direction: -1
        threshold: 5

      - name: cpu
        metric_of_interest: busy_cpu
        direction: 1
        threshold: 10

      - name: stability
        metric_of_interest: stddev_pct
        direction: 1
        threshold: 15
```

**Pros:** Comprehensive, catches multiple issue types
**Cons:** More complex, more alerts to triage

---

### Pattern 3: Multiple Test Types

**Use case:** Monitor throughput AND transactions AND connections

```yaml
tests:
  # Test 1: Throughput (Gbps)
  - name: regulus-throughput
    timestamp: "@timestamp"
    uuid_field: "iteration_id"
    version_field: "rcos"
    metadata:
      benchmark: uperf
      unit: Gbps
    metrics:
      - name: throughput
        metric_of_interest: mean
        direction: -1
        threshold: 5

  # Test 2: Transactions (trans-sec)
  - name: regulus-transactions
    timestamp: "@timestamp"
    uuid_field: "iteration_id"
    version_field: "rcos"
    metadata:
      benchmark: uperf
      unit: trans-sec
    metrics:
      - name: transactions
        metric_of_interest: mean
        direction: -1
        threshold: 5

  # Test 3: Connections (conn-sec)
  - name: regulus-connections
    timestamp: "@timestamp"
    uuid_field: "iteration_id"
    version_field: "rcos"
    metadata:
      benchmark: uperf
      unit: conn-sec
    metrics:
      - name: connections
        metric_of_interest: mean
        direction: -1
        threshold: 5
```

**Pros:** Comprehensive coverage of all test types
**Cons:** Longer config file, multiple reports

---

### Pattern 4: Category-Based Filtering

**Use case:** Analyze internode TCP separately from other topologies

```yaml
tests:
  - name: internode-tcp
    timestamp: "@timestamp"
    uuid_field: "iteration_id"
    version_field: "rcos"

    metadata:
      benchmark: uperf
      unit: Gbps
      topology: internode    # ← Added category filter
      protocol: tcp          # ← Added category filter

    metrics:
      - name: throughput
        metric_of_interest: mean
        direction: -1
        threshold: 5
```

**Pros:** Focused analysis per category
**Cons:** Need separate config for each category

---

## Hands-On Exercises

### Exercise 1: Read and Explain

**Given this config:**
```yaml
tests:
  - name: my-test
    timestamp: "@timestamp"
    uuid_field: "test_id"
    version_field: "build"
    metadata:
      tool: iperf3
      type: bandwidth
    metrics:
      - name: speed
        metric_of_interest: bits_per_second
        direction: -1
        threshold: 10
```

**Questions:**
1. What field contains the timestamp?
2. What field contains the unique test ID?
3. What filters are applied to select data?
4. What metric value is analyzed?
5. Will this detect increases, decreases, or both?
6. What's the minimum percentage change to report?

**Answers:**
1. `@timestamp`
2. `test_id` (must have `.keyword` subfield)
3. Documents where `tool=iperf3` AND `type=bandwidth`
4. The `bits_per_second` field value
5. Decreases only (`direction: -1`)
6. 10% or more

---

### Exercise 2: Spot the Mistake

**What's wrong with this config?**
```yaml
tests:
  - name: broken-test
    timestamp: timestamp        # Missing quotes and @ symbol
    uuid_field: "iteration_id"
    version_field: "version"

    metadata:
      benchmark: uperf
      unit: Gbps
      execution_label: default  # Over-filtering!
      batch_id: "batch-123"     # Over-filtering!
      nic: mlx5_0               # Over-filtering!
      threads: 1                # Over-filtering!

    metrics:
      - name: throughput
        metric_of_interest: mean
        direction: 0            # Catches both directions; use -1 to flag only decreases
        threshold: 1            # Too sensitive for production
```

**Issues:**
1. `timestamp: timestamp` should be `timestamp: "@timestamp"`
2. Too many metadata filters (execution_label, batch_id, nic, threads)
   - Will return very few documents
   - Unreliable regression detection
3. `threshold: 1` too sensitive - should be 5-10 for production

**Fixed version:**
```yaml
tests:
  - name: fixed-test
    timestamp: "@timestamp"     # ✓ Fixed
    uuid_field: "iteration_id"
    version_field: "version"

    metadata:
      benchmark: uperf
      unit: Gbps
      # Removed over-filtering - more data points!

    metrics:
      - name: throughput
        metric_of_interest: mean
        direction: -1           # ✓ Fixed
        threshold: 5            # ✓ Fixed
```

---

### Exercise 3: Build Your Own

**Scenario:** You want to monitor:
- Latency tests (higher latency is bad)
- Only for UDP protocol
- Alert on changes ≥ 15%
- Tag with "[Team: Networking]"

**Try writing the config yourself, then check below!**

<details>
<summary>Click to see solution</summary>

```yaml
tests:
  - name: udp-latency-monitoring
    timestamp: "@timestamp"
    uuid_field: "iteration_id"
    version_field: "rcos"

    metadata:
      benchmark: uperf
      unit: usec              # Latency unit (microseconds)
      protocol: udp           # Filter to UDP only

    metrics:
      - name: latency
        metric_of_interest: mean
        direction: 1          # Higher latency is worse
        threshold: 15         # Alert on ≥15% increases
        labels:
          - "[Team: Networking]"
```

</details>

---

## Quick Reference Card

```yaml
tests:
  - name: "test-identifier"              # Shows in reports
    timestamp: "@timestamp"              # Timestamp field (Regulus: always this)
    uuid_field: "iteration_id"                 # Unique ID (needs .keyword!)
    version_field: "rcos"                # Version field (Regulus: RHCOS version)

    metadata:                            # FILTERS (AND logic)
      benchmark: uperf                   # REQUIRED
      unit: Gbps                         # REQUIRED
      # Add more only for category splits

    metrics:
      - name: "metric-name"              # Metric identifier
        metric_of_interest: mean         # ES field to analyze
        direction: -1                    # -1=decreases, 1=increases, 0=both
        threshold: 5                     # Min % change to report
        labels:                          # Optional tags
          - "[Tag: Value]"
```

---

## Next Steps

Now that you understand config files, try:

1. **Read production configs:** Open `configs/regulus-dataplane.yaml` and identify each field
2. **Modify a config:** Copy `configs/regulus-simple.yaml` and adjust the threshold
3. **Create your own:** Build a config for your specific use case
4. **Test it:** Run with mock data using `make test`

**Further reading:**
- [CONFIGURATION-FIELDS.md](./CONFIGURATION-FIELDS.md) - Complete field reference
- [README-REGULUS.md](./README-REGULUS.md) - Full Regulus guide
- [configs/README.md](../configs/README.md) - All available configs explained

---

## Summary

**Key takeaways:**
1. **Test-level fields** (name, timestamp, uuid_field, version_field) define HOW to find data
2. **Metadata section** defines WHICH data to analyze (filters)
3. **Metrics section** defines WHAT to monitor (regressions)
4. **Include minimal metadata** - only filter on meaningful categories
5. **Use direction: 0** to flag changes in either direction (Regulus default)
6. **Use direction: -1 or 1** to flag only decreases or only increases
7. **Set realistic thresholds** - 5-10% for production

You're now ready to read, understand, and create Orion configuration files!
