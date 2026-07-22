# Orion Configuration

This directory previously contained static Orion YAML configuration examples.

**Static configs are no longer needed.** The batch analyzer dynamically discovers fingerprint fields from the ES index mapping and generates Orion configs on-the-fly.

## Usage

```bash
# Analyze a batch (auto-discovers all fingerprints)
make analyze BATCH_ID=test-batch-2026-07-08

# Cross-version analysis (ignore rcos field from fingerprint)
make analyze BATCH_ID=test-batch-2026-07-08 IGNORE='rcos'

# Filter to specific tests within batch
make analyze BATCH_ID=test-batch-2026-07-08 MATCH='threads=128'
```

## How Dynamic Discovery Works

1. Query ES `_mapping` API for the index
2. Subtract `NON_FINGERPRINT_FIELDS` exclusion set (metrics, IDs, timestamps, metadata)
3. Remaining fields = fingerprint fields
4. Generate Orion YAML configs per unique fingerprint combination
5. Run Orion analysis for each

Adding a new field to Regulus's ES mapping template automatically makes it a fingerprint field — zero changes to the analysis tools.

## Configuration Concepts

### Orion Config Structure

Every generated Orion config has:
- `timestamp`: `@timestamp`
- `uuid_field`: `iteration_id`
- `metadata`: All fingerprint field values for this test
- `metrics`: Two tracked metrics (throughput and cpu_cost)

### Tracked Metrics

| Metric | ES Field | Aggregation | `direction` | `threshold` | Meaning |
|--------|----------|-------------|-------------|-------------|---------|
| `throughput` | `mean` | `avg` | `0` | `5` | Alert on throughput changes (either direction) |
| `cpu_cost` | `busy_cpu` | `avg` | `0` | `10` | Alert on CPU changes (either direction) |

## See Also

- **[FINGERPRINT-DEFINITION.md](../FINGERPRINT-DEFINITION.md)** - Fingerprint field definitions
- **[analyze-batch.py](../scripts/analyze-batch.py)** - Dynamic batch analysis tool
- **[Makefile](../Makefile)** - All available targets
