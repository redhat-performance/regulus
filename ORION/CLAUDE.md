# Orion Regulus Development Guide

## What This Tool Does

Automated regression detection for Regulus network performance tests. Wraps the [cloud-bulldozer/orion](https://github.com/cloud-bulldozer/orion) changepoint detection tool to handle Regulus's hundreds of dynamic test variations without static configs.

**Core workflow:** Query ES by batch_id → discover unique fingerprints → generate Orion configs per fingerprint → run Hunter changepoint detection → report regressions.

## Architecture

### Dynamic Fingerprint Discovery

Fingerprint fields are **not hardcoded**. The tool queries the ES `_mapping` API and subtracts `NON_FINGERPRINT_FIELDS` (metrics, IDs, timestamps, metadata). Any new field added to the ES mapping automatically becomes a fingerprint field.

`NON_FINGERPRINT_FIELDS` is defined in three files — keep them in sync:
- `scripts/analyze-batch.py`
- `scripts/verify-batch.py`
- `scripts/verify-mapping.py`

### Dual Metric Tracking

Two metrics tracked per fingerprint, both with `direction: 0` (flag changes in either direction):

| Metric | ES Field | Aggregation | Threshold |
|--------|----------|-------------|-----------|
| `throughput` | `mean` | `avg` | 5% |
| `cpu_cost` | `busy_cpu` | `avg` | 10% |

**Critical: Both metrics MUST have `agg: {agg_type: avg}` in the Orion config.** Without it, Orion's standard batch path assigns all documents to the first metric only (due to a "first match wins" break in `get_results_batch` at matcher.py:631). The `agg` block routes metrics through the aggregation path which runs each independently.

### Prow CI Integration

This directory is the **source of truth** for the Prow CI step. The Prow step (`openshift-qe-orion-regulus`) clones the Regulus repo and runs `ORION/scripts/prow-entry.sh`, which bridges Prow env vars to `analyze-batch.py` CLI args.

```
Prow commands.sh → clones Regulus repo → cd ORION → scripts/prow-entry.sh → scripts/analyze-batch.py
```

There is no bundled copy of the analyzer in the step registry.

### Orion Invocation

`analyze-batch.py` auto-detects pip-installed `orion` CLI vs podman `run-it` script. Install orion from GitHub (not PyPI — `pip install orion` is a different package):
```
pip3 install git+https://github.com/cloud-bulldozer/orion.git
```

## Key Files

```
scripts/
  analyze-batch.py        # Core analyzer — source of truth for dev and Prow
  prow-entry.sh           # Prow CI entry point (bridges env vars → CLI args)
  verify-mapping.py       # Verify ES index mapping compatibility
  verify-batch.py         # Verify batch data quality
  validate-test-results.sh # Single source of truth for test expectations
  list-batches.py         # Format batch listing output
  run-it                  # Podman wrapper for Orion container

unit-test/
  generate-batch-test-data.py  # Generate 5-fingerprint mock test data
  generate-mock-data.py        # Base mock data generator class
  json-to-bulk.py              # Convert JSON to ES bulk format

configs/
  README.md               # Dynamic config approach documentation
  CONFIG-TUTORIAL.md       # Orion config tutorial

Makefile                   # All targets (run `make help`)
FINGERPRINT-DEFINITION.md  # Fingerprint field definitions and tracked metrics
requirements.txt           # Python deps (orion from GitHub)
```

## Make Targets

```bash
make help              # Show all targets with descriptions

# Production
make analyze BATCH_ID=... [MATCH=...] [IGNORE=...]
make list-batches      # List batches in ES
make show-mapping      # Raw ES mapping JSON
make verify-mapping    # Validate mapping compatibility
make verify-batch BATCH_ID=...

# Testing
make test-full         # Full cycle: create mock → push → analyze → validate
make test-prow         # Simulate Prow CI locally
make verify-test       # Re-validate last test results
make create-mock       # Generate mock data
make push-batch        # Push mock data to ES
make clean-mock        # Delete mock data from ES
make setup             # Install Python deps (skip-if-installed)
```

## Test Expectations

Mock data has 5 fingerprints (threads=16/32/64/128/256). Expected results: **2 stable, 3 regressions**.

| Fingerprint | Threads | Expected | Why |
|-------------|---------|----------|-----|
| A | 16 | STABLE | Normal throughput and CPU |
| B | 32 | REGRESSION | Throughput -25% |
| C | 64 | CHANGEPOINT | Throughput +20% (flagged because direction=0) |
| D | 128 | STABLE | Different rcos from historical → no baseline match |
| E | 256 | REGRESSION | busy_cpu doubled (50% vs ~25%), throughput stable |

**Test expectations live in ONE place:** `scripts/validate-test-results.sh`. Both `make test-full` and `make verify-test` call it. Do not duplicate expectations elsewhere.

## Testing Approaches Compared

Three ways to test the regression analysis pipeline, from narrowest to most realistic:

| | `make test-full` | `make test-prow` | `test-prow-step.sh` |
|---|---|---|---|
| **What it tests** | Analyzer directly | `prow-entry.sh` wrapper | Actual `commands.sh` that Prow runs |
| **Calls** | `analyze-batch.py` | `prow-entry.sh` | `openshift-qe-orion-regulus-commands.sh` |
| **Data setup** | Creates & pushes mock data | Expects data already in ES | Expects data already in ES |
| **ES credentials** | `ES_SERVER` make var | `ES_SERVER` make var | Interactive prompt; creates mock `/secret/perfscale-prod` |
| **Secrets simulation** | None | None | Creates `/tmp/prow-secret-perfscale-prod/` and symlinks to `/secret/perfscale-prod` |
| **ES index** | `regulus-results-mock` | `regulus-results-mock` | `regulus-results-mock` |
| **Validates results** | `validate-test-results.sh` | Checks `/tmp/prow-artifacts/` | Checks timestamped `ARTIFACT_DIR` |

**Typical sequence:** run `test-full` first (generates + pushes mock data, validates analyzer), then `test-prow` (reuses same data, validates Prow bridge). Use `test-prow-step.sh` for full end-to-end Prow simulation.

**`test-prow-step.sh` usage:** lives in `ORION/scripts/` but must be copied to the step-registry directory (`release/ci-operator/step-registry/openshift-qe/orion/regulus/`) to run, since it calls `commands.sh` from that location.

**Note:** `test-prow-step.sh` creates `/secret/perfscale-prod` via symlink. This can cause `make es-*` commands in `REPORT/` to fail because `SOURCE_ES_CONFIG` sees `/secret/` and tries to read credentials from it instead of falling through to `lab.config`.

## Common Pitfalls

- **`pip install orion`** installs the wrong package (epistimio/orion). Use `pip3 install git+https://github.com/cloud-bulldozer/orion.git`.
- **Orion metrics without `agg` block**: Both metrics sharing the same documents will break — second metric gets zero data. Always use `agg: {agg_type: avg}`.
- **Exit code 1 from `make analyze`**: Expected when regressions are detected — this is the success signal for "found problems."
- **`make setup` noise**: Uses skip-if-installed check and `-q` flag to stay quiet.
- **ES index for testing**: `regulus-results-mock` (set via `TEST_INDEX`). Production: `regulus-results-*`.

## ES Configuration

Saved in `.makerc` (gitignored). Set with:
```bash
make set-es ES_SERVER=http://your-es:9200
```

Default: `ES_SERVER=http://localhost:9200`, `ES_INDEX=regulus-results-*`

## Prow Entry Point Details

`scripts/prow-entry.sh` accepts these env vars:
- `ES_SERVER` — direct URL (for local testing), OR reads from `/secret/perfscale-prod/{username,password,host}` (Prow)
- `BATCH_ID` — batch to analyze (empty = auto-discover latest)
- `ES_BENCHMARK_INDEX` — index pattern (default: `regulus-results-*`)
- `MATCH`, `IGNORE`, `LOOKBACK`, `DEBUG` — passed through to analyze-batch.py
- `ARTIFACT_DIR` — copies configs/output here for Prow artifacts
