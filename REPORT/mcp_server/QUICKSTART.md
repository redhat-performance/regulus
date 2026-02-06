# Regulus ES CLI - Quick Start

## What is This?

A command-line tool to interact with your Regulus benchmark data in ElasticSearch without needing to remember curl commands or makefile targets.

## Quick Start (Containerized - Recommended)

```bash
cd $REG_ROOT/REPORT/build_report/mcp_server

# Show all valid search keywords (benchmarks, models, NICs, etc.)
./show_keywords.sh

# List all upload batches
./build_and_run.sh list-batches

# Get batch details
./build_and_run.sh batch-info <batch-uuid>

# Search benchmarks
./build_and_run.sh search --benchmark uperf --model OVNK
./build_and_run.sh search --min-throughput 90

# Compare two batches
./build_and_run.sh compare <batch1-uuid> <batch2-uuid>

# Delete a bad batch
./build_and_run.sh delete <batch-uuid>

# Show index statistics
./build_and_run.sh stats
```

## Common Use Cases

### 1. Find Bad Upload

```bash
# List all batches to see which ones exist
./build_and_run.sh list-batches

# Check details of suspicious batch
./build_and_run.sh batch-info <batch-uuid>

# If it's bad, delete it
./build_and_run.sh delete <batch-uuid>
```

### 2. Compare Performance

```bash
# Get two batch IDs from list-batches
./build_and_run.sh list-batches

# Compare them
./build_and_run.sh compare <batch1-uuid> <batch2-uuid>
```

### 3. Search for Specific Results

```bash
# Find all OVNK benchmarks with E810 NIC
./build_and_run.sh search --model OVNK --nic E810

# Find high-performance results (80-100 Gbps)
./build_and_run.sh search --min-throughput 80 --max-throughput 100 --size 20

# Find all uperf stream tests
./build_and_run.sh search --benchmark uperf --test-type stream

# Find intranode TCP benchmarks
./build_and_run.sh search --topology intranode --protocol tcp

# Find DPU results with 4 CPUs
./build_and_run.sh search --model DPU --cpu 4

# Complex query: OVNK + intranode + tcp + stream + high throughput
./build_and_run.sh search --model OVNK --topology intranode --protocol tcp \
  --test-type stream --min-throughput 90
```

## Configuration

By default, uses ES credentials from `lab.config`:

```bash
# Only ES_URL needs to be configured
export ES_URL='https://admin:password@other-es-host.com'
./build_and_run.sh list-batches
```

**Note**: ES_INDEX is hardcoded as `regulus-results-*` to query across all rollover indices. It cannot be overridden without modifying `es_integration/es_config.py` (expert-level only).

## How It Works

1. First run: Automatically builds a container image with all dependencies
2. Subsequent runs: Reuses existing image (instant startup)
3. No local Python dependencies needed
4. Container is ephemeral - no state persisted

## Files Created

- `Dockerfile` - Container definition
- `requirements.txt` - Python dependencies
- `build_and_run.sh` - Convenience wrapper
- `es_cli.py` - Main CLI application
- `regulus_es_mcp.py` - MCP server (shared backend)

## Full Documentation

See `README.md` for:
- Claude Desktop integration (macOS/Windows only)
- Manual Python installation
- MCP server details
- Troubleshooting
