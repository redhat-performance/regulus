# Templates for New Test Types

This directory contains templates for creating new mock data test types beyond throughput (Gbps).

## Available Templates

1. **connections-template.json** - Connections per second tests
2. **latency-template.json** - Latency/response time tests
3. **packet-loss-template.json** - Packet loss percentage tests
4. **cpu-efficiency-template.json** - CPU efficiency metrics

## How to Use Templates

### Step 1: Choose a Template

```bash
cp mocked-up-data/templates/connections-template.json \
   mocked-up-data/scenarios/07-my-new-test.json
```

### Step 2: Customize the Template

Edit the file to adjust:
- Number of samples
- Baseline values
- Regression severity
- Metadata (topology, protocol, nic, etc.)
- Timestamps

### Step 3: Convert to NDJSON

```bash
./scripts/json-to-bulk.py \
  mocked-up-data/scenarios/07-my-new-test.json \
  mocked-up-data/bulk-index/07-my-new-test.ndjson
```

### Step 4: Create Matching Orion Config

```bash
cp configs/regulus-mock-regression.yaml \
   configs/regulus-mock-my-new-test.yaml

# Edit to match your test's metadata and unit
vi configs/regulus-mock-my-new-test.yaml
```

### Step 5: Index and Test

```bash
# Index to OpenSearch
curl -X POST 'http://localhost:9200/_bulk' \
  -H 'Content-Type: application/x-ndjson' \
  --data-binary '@mocked-up-data/bulk-index/07-my-new-test.ndjson'

# Run Orion
cd /path/to/orion
./run-it --config ./configs/regulus-mock-my-new-test.yaml \
  --hunter-analyze \
  --benchmark-index=regulus-results-mock* \
  --metadata-index=regulus-results-mock*
```

## Template Details

### connections-template.json

**Purpose:** Test connections per second performance

**Unit:** `connections-sec`

**Baseline:** 50,000 connections/sec

**Scenario:** Sudden 25% regression (50k → 37.5k)

**Use Case:**
- Connection establishment performance
- Load balancer testing
- Service mesh performance

**Example Config Metadata:**
```yaml
metadata:
  benchmark: uperf
  unit: connections-sec
  topology: internode
  protocol: tcp
  test_type: crr
  mock_data: true
```

---

### latency-template.json

**Purpose:** Test response time / latency

**Unit:** `ms` (milliseconds)

**Baseline:** 0.45 ms

**Scenario:** Sudden 50% latency increase (0.45 ms → 0.675 ms)

**Use Case:**
- Network latency monitoring
- Service response time
- RPC performance

**Important:** For latency, **increases are bad**, so use `direction: -1` in config but note that higher values = regression.

**Example Config Metadata:**
```yaml
metadata:
  benchmark: uperf
  unit: ms
  topology: pod-to-pod
  protocol: tcp
  test_type: rr
  mock_data: true

metrics:
  - name: latency_regression
    metric_of_interest: mean
    direction: -1  # Catch increases (higher latency = worse)
    threshold: 10   # 10% increase triggers detection
```

---

### packet-loss-template.json

**Purpose:** Test packet loss percentage

**Unit:** `pct` (percentage)

**Baseline:** 0.01% (very low loss)

**Scenario:** Sudden increase to 0.15% (15x worse)

**Use Case:**
- Network reliability
- UDP performance
- Quality of service

**Note:** Like latency, increases are bad. Use `direction: -1` to catch increases.

---

### cpu-efficiency-template.json

**Purpose:** Test throughput per CPU utilization

**Unit:** `Gbps-per-cpu`

**Baseline:** 0.25 Gbps per % CPU

**Scenario:** Efficiency decreases 20% (same throughput, more CPU)

**Use Case:**
- Performance per watt
- Resource efficiency
- Scalability testing

## Creating Custom Templates

### Method 1: Modify Existing Template

```bash
# Copy an existing template
cp mocked-up-data/templates/connections-template.json my-template.json

# Edit values
python3 << 'EOF'
import json

with open('my-template.json', 'r') as f:
    data = json.load(f)

# Modify baseline values
for doc in data:
    # Adjust your metric
    doc['mean'] = doc['mean'] * 2.0  # Example: double the baseline
    doc['unit'] = 'my-custom-unit'

with open('my-template.json', 'w') as f:
    json.dump(data, f, indent=2)
EOF
```

### Method 2: Use Generator Script

Modify `scripts/generate-mock-data.py` to add new metric type:

```python
# In generate-mock-data.py, add to self.baselines:

self.baselines = {
    # ... existing entries ...
    'my_custom_metric': {
        'mean': 1000,  # Your baseline value
        'stddev': 50,  # Standard deviation
        'unit': 'my-unit',
        'benchmark': 'uperf',
    }
}
```

Then regenerate:

```bash
./scripts/generate-mock-data.py --scenario regression \
  --output mocked-up-data/scenarios/my-custom-test.json
```

## Common Customizations

### Change Regression Severity

In template JSON, modify the "regressed" samples (typically second half):

```python
# For 30 docs with changepoint at sample 15:
# Baseline: samples 0-14
# Regressed: samples 15-29

import json
with open('template.json', 'r') as f:
    data = json.load(f)

baseline_mean = 50000  # connections/sec
regression_pct = 40.0  # 40% drop instead of 25%

for i, doc in enumerate(data):
    if i >= 15:  # Second half (regressed)
        doc['mean'] = baseline_mean * (1 - regression_pct / 100)
        doc['min'] = doc['mean'] * 0.95
        doc['max'] = doc['mean'] * 1.05

with open('template.json', 'w') as f:
    json.dump(data, f, indent=2)
```

### Change Number of Samples

```bash
# Generate 60 samples instead of 30
./scripts/generate-mock-data.py --scenario regression --samples 60 \
  --output mocked-up-data/scenarios/regression-60samples.json
```

### Change Metadata (Test Configuration)

Edit the JSON to change topology, protocol, NIC, etc.:

```python
import json
with open('template.json', 'r') as f:
    data = json.load(f)

for doc in data:
    doc['topology'] = 'pod-to-pod'  # Change from internode
    doc['nic'] = 'ens1f1'          # Change NIC
    doc['threads'] = 8             # Change thread count

with open('template.json', 'w') as f:
    json.dump(data, f, indent=2)
```

### Change Timestamps

```python
from datetime import datetime, timedelta
import json

with open('template.json', 'r') as f:
    data = json.load(f)

start_time = datetime.utcnow() - timedelta(days=7)  # Start 7 days ago

for i, doc in enumerate(data):
    timestamp = start_time + timedelta(hours=i * 2)  # Every 2 hours
    doc['@timestamp'] = timestamp.strftime('%Y-%m-%dT%H:%M:%S.%fZ')

with open('template.json', 'w') as f:
    json.dump(data, f, indent=2)
```

## Example: Creating Connections Test

Complete example from scratch:

```bash
# 1. Copy template
cp mocked-up-data/templates/connections-template.json \
   mocked-up-data/scenarios/07-connections-regression.json

# 2. (Optional) Customize values
# ... edit file as needed ...

# 3. Convert to NDJSON
./scripts/json-to-bulk.py \
  mocked-up-data/scenarios/07-connections-regression.json \
  mocked-up-data/bulk-index/07-connections-regression.ndjson

# 4. Create Orion config
cat > configs/regulus-mock-connections.yaml << 'EOF'
tests:
  - name: mock-connections-regression
    timestamp: "@timestamp"
    uuid_field: "run_id"
    version_field: "rcos"
    metadata:
      benchmark: uperf
      unit: connections-sec
      topology: internode
      protocol: tcp
      test_type: crr
      mock_data: true

    metrics:
      - name: connections_regression_detection
        metric_of_interest: mean
        direction: -1
        threshold: 5
        labels:
          - "[Mock Test] Connections Regression"
EOF

# 5. Index to OpenSearch
curl -X POST 'http://localhost:9200/_bulk' \
  -H 'Content-Type: application/x-ndjson' \
  --data-binary '@mocked-up-data/bulk-index/07-connections-regression.ndjson'

# 6. Run Orion
cd /path/to/orion
./run-it --config ./configs/regulus-mock-connections.yaml \
  --hunter-analyze \
  --benchmark-index=regulus-results-mock* \
  --metadata-index=regulus-results-mock*
```

Expected output:
```
Changepoint detected at index 15
Connections regression: 50000 → 37500 (-25.0%)
```

## Supported Units

Based on Regulus test types:

| Unit | Description | Baseline Example | Direction |
|------|-------------|------------------|-----------|
| `Gbps` | Throughput | 8.5 Gbps | -1 (lower is bad) |
| `transactions-sec` | Transactions/sec | 15,000 | -1 (lower is bad) |
| `connections-sec` | Connections/sec | 50,000 | -1 (lower is bad) |
| `ms` | Latency | 0.45 ms | -1 (higher is bad) |
| `pct` | Packet loss | 0.01% | -1 (higher is bad) |
| `Gbps-per-cpu` | Efficiency | 0.25 | -1 (lower is bad) |
| `MB` | Memory usage | 512 MB | Depends on context |

**Note on Direction:**
- `direction: -1` = Only detect decreases (or increases for inverse metrics like latency)
- `direction: 1` = Only detect increases
- `direction: 0` = Detect both increases and decreases

## Best Practices

1. **Use realistic baselines** - Match actual Regulus test values
2. **Appropriate stddev** - 2-5% of mean is typical
3. **Meaningful metadata** - Match actual test configurations
4. **Consistent timestamps** - 2-hour intervals is common
5. **Flag as mock** - Always include `"mock_data": true`
6. **Document expected results** - Note what detection you expect

## Template Validation

Before using a template:

```bash
# Check JSON is valid
jq '.' mocked-up-data/scenarios/my-new-test.json > /dev/null && echo "Valid JSON"

# Count documents
jq 'length' mocked-up-data/scenarios/my-new-test.json

# Check required fields
jq '.[0] | keys' mocked-up-data/scenarios/my-new-test.json

# Verify mean values
jq '[.[] | .mean] | {min: min, max: max, avg: (add/length)}' \
  mocked-up-data/scenarios/my-new-test.json
```

## Troubleshooting

### Config doesn't match data

**Problem:** "No UUID present for given metadata"

**Solution:** Ensure config metadata matches template metadata exactly:

```bash
# Check what's in the data
jq '.[0] | {unit: .unit, topology: .topology, protocol: .protocol}' \
  mocked-up-data/scenarios/my-test.json

# Update config to match
```

### Wrong detection direction

**Problem:** Improvement detected when expecting regression

**Solution:** Check `direction` in config:
- For metrics where **lower = worse**: `direction: -1`
- For metrics where **higher = worse** (latency): `direction: -1` but invert logic

### Timestamps too old

**Problem:** Data not in lookback window

**Solution:** Regenerate with recent timestamps:

```python
from datetime import datetime, timedelta
import json

with open('old-template.json', 'r') as f:
    data = json.load(f)

now = datetime.utcnow()
for i, doc in enumerate(data):
    timestamp = now - timedelta(hours=(len(data) - i) * 2)
    doc['@timestamp'] = timestamp.strftime('%Y-%m-%dT%H:%M:%S.%fZ')

with open('new-template.json', 'w') as f:
    json.dump(data, f, indent=2)
```

## Contributing Templates

If you create a useful template:

1. Add it to `templates/` directory
2. Document it in this README
3. Create example config in `configs/`
4. Add to main documentation

---

**Need help?** See [MOCK-DATA-README.md](../MOCK-DATA-README.md) or [docs/MOCK-DATA-GUIDE.md](../docs/MOCK-DATA-GUIDE.md)
