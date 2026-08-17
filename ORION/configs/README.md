# Orion Configuration

## template.yaml

The static Orion config template. Fingerprint fields are defined as `{{ field }}` Jinja2 placeholders, each guarded by `{% if field is defined %}` so fields can be excluded via `IGNORE`.

At runtime, `analyze-batch.py` passes fingerprint values via `--input-vars` and Orion renders the template per fingerprint. No per-fingerprint config files are generated.

A self-detect fallback (`--use-self-detect`) generates configs on-the-fly without the template, but is not the primary method.

## Usage

```bash
# Analyze a batch (uses template.yaml)
make analyze BATCH_ID=test-batch-2026-07-08

# Cross-version analysis (ignore rcos field from fingerprint)
make analyze BATCH_ID=test-batch-2026-07-08 IGNORE='rcos'

# Filter to specific tests within batch
make analyze BATCH_ID=test-batch-2026-07-08 MATCH='threads=128'

# Fallback: self-detect mode (generates per-fingerprint configs)
make analyze BATCH_ID=test-batch-2026-07-08 SELF_DETECT=1
```

## Adding a New Fingerprint Field

1. Add the field to the Regulus ES mapping template
2. Add `{{ new_field }}` to `template.yaml` (with `{% if is defined %}` guard)
3. Document it in [FINGERPRINT-DEFINITION.md](../FINGERPRINT-DEFINITION.md)

The startup drift check validates that the template covers all ES mapping fields. If a field exists in the mapping but not in the template, the analyzer exits with an error.

## Orion Config Structure

The template defines:
- `name`: `fingerprint-{{ fp_index }}`
- `timestamp`: `@timestamp`
- `uuid_field`: `iteration_id`
- `metadata`: All fingerprint field placeholders
- `metrics`: Two tracked metrics (throughput and cpu_cost) with batch label

### Tracked Metrics

| Metric | ES Field | Aggregation | `direction` | `threshold` | Meaning |
|--------|----------|-------------|-------------|-------------|---------|
| `throughput` | `mean` | `avg` | `0` | `5` | Alert on throughput changes (either direction) |
| `cpu_cost` | `busy_cpu` | `avg` | `0` | `10` | Alert on CPU changes (either direction) |

## See Also

- **[DESIGN-TEMPLATE.md](DESIGN-TEMPLATE.md)** - Design doc for the template approach
- **[FINGERPRINT-DEFINITION.md](../FINGERPRINT-DEFINITION.md)** - Fingerprint field definitions
- **[analyze-batch.py](../scripts/analyze-batch.py)** - Batch analysis tool
- **[Makefile](../Makefile)** - All available targets
