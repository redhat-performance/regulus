# Orion Regulus

Automated regression detection for Regulus network performance tests using [Orion](https://github.com/cloud-bulldozer/orion).

## Description

The "API" between Regulus and Orion — ES index content, mapping, fingerprint definitions, tracked metrics — is evolving. This tool lets us develop and test that API independently of the primary ci-tools/Prow environment, where iteration is slow and changes require step-registry PRs. Prow clones the Regulus repo and runs from `ORION/`.

**Source and sink are decoupled through the ES index mapping:**
- **Source (Regulus)** — pushes test results to ES. When fingerprint fields change (new fields added, fields renamed), Regulus updates the ES index mapping accordingly.
- **Sink (this tool)** — reads the current ES index mapping and discovers fingerprint fields dynamically. No hardcoded field lists, no coordination needed with the source.

This means Regulus can evolve its test parameters independently — as long as it updates the index mapping, the analysis side adapts automatically.

**How Orion and the data source work together:**

The simplest Orion workflow uses static YAML configs (see [Orion/examples](https://github.com/cloud-bulldozer/orion/tree/main/examples)). Regulus has many evolving test variations, so this tool generates configs dynamically:

```
Regulus (source)          Elasticsearch              This tool (sink)
─────────────────    ───────────────────────    ─────────────────────────
Runs tests           Stores results +           Reads index mapping
  ↓                  index mapping                ↓
Pushes results         ↑            ↓           Discovers fingerprint fields
  with batch_id ──→  Documents   Mapping ──→    Queries batch documents
                                                  ↓
                                                Groups by fingerprint
                                                  ↓
                                                Generates Orion config
                                                  per fingerprint
                                                  ↓
                                    ←───────── Orion queries historical
                                                  data for comparison
                                                  ↓
                                                Reports regressions
                                                  (throughput + CPU)
```

## Quick Start

```bash
# Install dependencies
make setup

# Set ES connection (persists to .makerc)
make set-es ES_SERVER=http://your-es:9200

# Analyze latest batch (auto-discover)
make analyze

# Analyze specific batch
make analyze BATCH_ID=test-batch-2026-07-08

# Cross-version analysis (ignore rcos from fingerprint)
make analyze BATCH_ID=test-batch-2026-07-08 IGNORE='rcos'

# Filter to specific tests within batch
make analyze BATCH_ID=test-batch-2026-07-08 MATCH='threads=128'
```

Run `make help` for all available targets.

## Tracked Metrics

Both metrics use `direction: 0` (flag changes in either direction):

| Metric | ES Field | Threshold | Detects |
|--------|----------|-----------|---------|
| `throughput` | `mean` | 5% | Throughput changes |
| `cpu_cost` | `busy_cpu` | 10% | CPU usage changes |

A fingerprint is flagged if **either** metric triggers a changepoint.

## Key Concepts

- **Fingerprint** — the set of fields that uniquely identify a test type. Discovered dynamically from ES mapping, not hardcoded. See [FINGERPRINT-DEFINITION.md](FINGERPRINT-DEFINITION.md).
- **batch_id** — identifies which new tests to analyze (input selector, not part of fingerprint).
- **MATCH** — filter documents within a batch by field values (e.g., `threads=128`).
- **IGNORE** — exclude fields from fingerprint for grouping (e.g., `rcos` for cross-version analysis).

## Testing

```bash
# Full test cycle: generate mock data → push to ES → analyze → validate
make test-full

# Test Prow CI entry point locally
make test-prow

# Re-validate last test results
make verify-test
```

Mock data includes 5 fingerprints covering: stable, throughput regression, throughput improvement, rcos mismatch, and CPU-only regression.

## Installation

```bash
git clone https://github.com/redhat-performance/regulus.git
cd regulus/ORION
make setup    # installs orion + python dependencies
```

Requires Python 3.11+ and Elasticsearch/OpenSearch with Regulus test data.

## Prow CI Integration

Prow clones the Regulus repo and runs `ORION/scripts/prow-entry.sh`, which bridges Prow environment variables to `analyze-batch.py` CLI arguments. No bundled copy of the analyzer exists in the step registry — this directory is the single source of truth.

## Directory Structure

```
ORION/
├── scripts/
│   ├── analyze-batch.py          # Core analyzer (source of truth for dev and Prow)
│   ├── prow-entry.sh             # Prow CI entry point
│   ├── validate-test-results.sh  # Test expectations (single source of truth)
│   ├── verify-mapping.py         # Verify ES index mapping
│   ├── verify-batch.py           # Verify batch data quality
│   ├── list-batches.py           # List batch IDs in ES
│   └── run-it                    # Podman wrapper for Orion container
├── unit-test/
│   ├── generate-batch-test-data.py  # Generate mock test data (5 fingerprints)
│   ├── generate-mock-data.py        # Base mock data generator
│   └── json-to-bulk.py             # Convert JSON to ES bulk format
├── configs/
│   ├── README.md                 # Config concepts
│   └── CONFIG-TUTORIAL.md        # Orion config tutorial
├── docs/                         # Additional documentation
├── Makefile                      # All targets (make help)
├── CLAUDE.md                     # Project reference for Claude Code sessions
├── FINGERPRINT-DEFINITION.md     # Fingerprint field definitions
└── requirements.txt              # Python dependencies
```

## Documentation

- **[FINGERPRINT-DEFINITION.md](FINGERPRINT-DEFINITION.md)** — Fingerprint fields, tracked metrics, exclusion set
- **[configs/CONFIG-TUTORIAL.md](configs/CONFIG-TUTORIAL.md)** — How Orion configs work
- **[CLAUDE.md](CLAUDE.md)** — Project reference (architecture, pitfalls, Prow details)

## Author

Hugh Nhan (https://github.com/HughNhan)

Based on [Orion](https://github.com/cloud-bulldozer/orion) from the cloud-bulldozer team.
