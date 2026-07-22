# Batch Analyzer Test Data

Test data for validating the `analyze-batch.py` tool with multiple fingerprints.

## Overview

The `generate-batch-test-data.py` script creates a realistic test scenario:

- **Historical data:** 60 documents (3 fingerprints × 20 samples each, spanning 30 days)
- **New batch:** 3 documents (1 per fingerprint, submitted today)
- **Batch ID:** User-specified (e.g., `test-batch-2026-07-06`)

## Test Scenario

### Fingerprint A: threads=16 (STABLE)
- **Historical:** 20 samples of stable performance (~8.5 Gbps ± 0.3)
- **New batch:** 1 sample continuing stable performance
- **Expected result:** ✅ No regression detected

### Fingerprint B: threads=32 (REGRESSION)
- **Historical:** 20 samples of stable performance (~8.5 Gbps ± 0.3)
- **New batch:** 1 sample with **25% performance drop** (~6.4 Gbps)
- **Expected result:** ⚠️ Regression detected

### Fingerprint C: threads=64 (IMPROVEMENT)
- **Historical:** 20 samples of stable performance (~8.5 Gbps ± 0.3)
- **New batch:** 1 sample with **20% improvement** (~10.2 Gbps)
- **Expected result:** ⬆️ Performance improvement (if direction=0)

## Common Fingerprint Fields

All three fingerprints share these fields (only `threads` differs):

```yaml
benchmark: uperf
unit: Gbps
model: OVNK
topology: internode
protocol: tcp
nic: mlx5_0
test_type: stream
wsize: 32768
performance_profile: None
kernel: 5.14.0-5XX.XXX.1.el9_6.x86_64
rcos: 9.6.20260615-0
arch: Intel(R)_Xeon(R)_Gold_6130_CPU_@_2.10GHz
cpu: "50-60" (random)
pods_per_worker: "1"
scale_out_factor: "1"
```

**Key difference:** `threads` field varies (16, 32, 64)

## Usage

### Generate Test Data

```bash
cd unit-test

# Generate test data to JSON file
./generate-batch-test-data.py \
  --batch-id "test-batch-2026-07-06" \
  --output generated/batch-test-data.json

# Generate and index to Elasticsearch
./generate-batch-test-data.py \
  --batch-id "test-batch-2026-07-06" \
  --index-to-es \
  --es-server http://localhost:9200 \
  --es-index regulus-results-mock
```

### Verify Data Structure

```bash
# Count documents
python3 -c "import json; data=json.load(open('generated/batch-test-data.json')); print(f'Total: {len(data)} documents')"

# Show batch IDs
python3 -c "import json; data=json.load(open('generated/batch-test-data.json')); batches=set(d['batch_id'] for d in data); print('Batch IDs:'); [print(f'  {b}') for b in batches]"

# Show new batch tests
python3 -c "import json; data=json.load(open('generated/batch-test-data.json')); tests=[(d['threads'], d['mean']) for d in data if d['batch_id']=='test-batch-2026-07-06']; print('New batch tests:'); [print(f'  threads={t}, mean={m:.2f} Gbps') for t,m in tests]"
```

### Test analyze-batch.py

Once the data is indexed to Elasticsearch:

```bash
# Run batch analyzer
../scripts/analyze-batch.py \
  --batch-id "test-batch-2026-07-06" \
  --es-server http://localhost:9200 \
  --es-index regulus-results-mock
```

**Expected output:**

```
Discovered 3 unique fingerprints in batch 'test-batch-2026-07-06':
  1. Fingerprint (threads=16): STABLE
  2. Fingerprint (threads=32): REGRESSION DETECTED (25% drop)
  3. Fingerprint (threads=64): IMPROVEMENT (20% gain)
```

## Data Structure

Each document contains:

```json
{
  "@timestamp": "2026-07-06T...",
  "batch_id": "test-batch-2026-07-06" | "historical-a-{uuid}",
  "iteration_id": "{unique-uuid}",
  "run_id": "{unique-uuid}",
  "benchmark": "uperf",
  "unit": "Gbps",
  "model": "OVNK",
  "topology": "internode",
  "protocol": "tcp",
  "nic": "mlx5_0",
  "test_type": "stream",
  "threads": 16 | 32 | 64,
  "wsize": 32768,
  "performance_profile": "None",
  "kernel": "5.14.0-...",
  "rcos": "9.6.20260615-0",
  "arch": "Intel(R)_Xeon(R)_Gold_6130_CPU_@_2.10GHz",
  "cpu": "50-60",
  "pods_per_worker": "1",
  "scale_out_factor": "1",
  "mean": 6.38 | 8.46 | 10.20,
  "min": ...,
  "max": ...,
  "stddev": 0.3,
  "sample_count": 150,
  "busy_cpu": 0.0,
  "mock_data": true
}
```

## Fingerprint Extraction

The analyze-batch.py tool should extract these fingerprints:

**Fingerprint A:**
```python
{
  'benchmark': 'uperf',
  'unit': 'Gbps',
  'model': 'OVNK',
  'topology': 'internode',
  'protocol': 'tcp',
  'nic': 'mlx5_0',
  'test_type': 'stream',
  'threads': 16,  # ← Unique
  'wsize': 32768,
  'performance_profile': 'None',
  'kernel': '5.14.0-...',
  'rcos': '9.6.20260615-0',
  'arch': 'Intel(R)_Xeon(R)_Gold_6130_CPU_@_2.10GHz',
  'cpu': '50-60',
  'pods_per_worker': '1',
  'scale_out_factor': '1'
}
```

**Fingerprints B and C:** Same as A, except `threads: 32` and `threads: 64`

## Validation Checklist

When testing analyze-batch.py:

- [ ] Discovers exactly 3 unique fingerprints
- [ ] Each fingerprint has correct field values
- [ ] Queries historical data (batch_id != "test-batch-2026-07-06")
- [ ] Generates 3 temporary Orion configs
- [ ] Runs Orion 3 times (once per fingerprint)
- [ ] Detects regression for threads=32
- [ ] Shows stable for threads=16
- [ ] Shows improvement for threads=64 (if direction=0)
- [ ] Aggregates results into unified report

## Customization

Generate different scenarios:

```bash
# More historical samples for better baseline
./generate-batch-test-data.py \
  --batch-id "test-batch-001" \
  --historical-samples 50

# Different batch ID
./generate-batch-test-data.py \
  --batch-id "production-2026-07-06-morning"
```

## See Also

- **[FINGERPRINT-DEFINITION.md](../FINGERPRINT-DEFINITION.md)** - Complete fingerprint field definitions
- **[generate-mock-data.py](generate-mock-data.py)** - Original mock data generator
- **[analyze-batch.py](../scripts/analyze-batch.py)** - Batch analyzer tool (to be implemented)
