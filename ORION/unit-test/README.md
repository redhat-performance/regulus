# Unit Test Directory

Test data generation and utilities for Orion Regulus batch analyzer.

## Directory Structure

```
unit-test/
├── README.md                          # This file
├── README-BATCH-TEST.md               # Batch test data documentation
├── generated/                         # Generated test data
│   └── batch-test-data.json           # Current test data (63 docs)
├── templates/                         # Document templates
│   ├── connections-template.json
│   ├── latency-template.json
│   ├── packet-loss-template.json
│   └── cpu-efficiency-template.json
├── backup/                            # Real data backups
│   ├── aws/                           # AWS ES backups
│   └── local/                         # Local ES backups
├── generate-batch-test-data.py        # Test data generator
├── json-to-bulk.py                    # ES bulk indexing utility
├── pull-from-opensearch.py            # ES data extraction utility
├── Makefile                           # Make targets for common tasks
├── MAKEFILE-QUICK-REF.md              # Makefile quick reference
└── index-mapping-example.json         # ES index mapping example
```

## Quick Usage

### Generate Test Data

```bash
# Generate test data with 3 fingerprints
./generate-batch-test-data.py \
  --batch-id "test-batch-2026-07-08" \
  --output generated/batch-test-data.json \
  --historical-samples 20

# Generate and index to ES directly
./generate-batch-test-data.py \
  --batch-id "test-batch-2026-07-08" \
  --index-to-es \
  --es-server "http://localhost:9200" \
  --es-index "regulus-results-mock"
```

### What It Generates

The test data includes **3 fingerprints** with controlled scenarios:

1. **Fingerprint A (threads=16)**: STABLE
   - 20 historical samples @ ~8.5 Gbps
   - 1 new batch sample continuing stable performance
   - Expected: ✅ No regression

2. **Fingerprint B (threads=32)**: REGRESSION
   - 20 historical samples @ ~8.5 Gbps
   - 1 new batch sample @ ~6.4 Gbps (-25% drop)
   - Expected: ⚠️ Regression detected

3. **Fingerprint C (threads=64)**: IMPROVEMENT
   - 20 historical samples @ ~8.5 Gbps
   - 1 new batch sample @ ~10.2 Gbps (+20% gain)
   - Expected: ⬆️ Improvement (if direction=0)

**Total**: 63 documents (3 × 21 samples each)

### Run Batch Analyzer

```bash
# After indexing test data to ES
cd ..
make analyze \
  BATCH_ID=test-batch-2026-07-08 \
  ES_SERVER=http://localhost:9200 \
  ES_INDEX=regulus-results-mock

# Expected output:
# - Discovers 3 fingerprints
# - Detects 1 regression (threads=32)
# - Reports 2 stable (threads=16, 64)
```

## Utilities

### json-to-bulk.py

Convert JSON array to NDJSON bulk format for ES indexing:

```bash
./json-to-bulk.py \
  --input generated/batch-test-data.json \
  --output bulk-data.ndjson \
  --index regulus-results-mock
```

### pull-from-opensearch.py

Extract data from ES for backup or analysis:

```bash
./pull-from-opensearch.py \
  --es-server http://localhost:9200 \
  --index regulus-results-* \
  --query '{"match": {"batch_id": "test-batch-001"}}' \
  --output backup/mybatch.json
```

## Test Data Fields

All generated documents include the complete dynamic fingerprint:

1. benchmark
2. unit
3. model
4. topology
5. protocol
6. nic
7. test_type
8. threads
9. wsize
10. performance_profile
11. kernel
12. rcos
13. arch
14. cpu
15. pods_per_worker
16. scale_out_factor

Plus Orion-required fields:
- `@timestamp` - Timestamp field
- `iteration_id` - UUID field
- `batch_id` - Batch identifier
- `mean`, `min`, `max`, `stddev`, `samples` - Performance metrics

## See Also

- **README-BATCH-TEST.md** - Detailed batch test data documentation
- **MAKEFILE-QUICK-REF.md** - Makefile targets reference
- **../README.md** - Main README with Quick Start
- **../FINGERPRINT-DEFINITION.md** - dynamic fingerprint reference
- **../docs/QUICK-START-TESTING.md** - Testing workflow guide
- **../docs/MOCK-DATA-GUIDE.md** - Mock data generation guide
