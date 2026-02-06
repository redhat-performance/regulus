# Regulus ElasticSearch Integration - Current State

**Last Updated**: 2026-02-06
**Session**: ISM rollover fixes and schema documentation

---

## System Architecture

### ElasticSearch/OpenSearch Configuration
- **Platform**: OpenSearch (AWS managed)
- **ES URL**: Configured in `../lab.config`
- **Index Pattern**: `regulus-results-*` (rollover indices)
- **Current Index**: `regulus-results-000001`
- **Write Alias**: `regulus-results-write` (upload target)
- **Documents**: 471 total (2 batches)

### Index Lifecycle Management (ISM)
- **Policy**: `regulus-ism-policy` (no-delete version for CCR compatibility)
- **States**: hot → warm → replicated (NO delete phase)
- **Status**: Active, rollover ready
- **Rollover Conditions**: 30 days age or document count threshold
- **Critical Setting**: `index.plugins.index_state_management.rollover_alias: "regulus-results-write"`

---

## Recent Fixes (Current Session)

### 1. Fixed ISM Rollover Setup
**Problem**: Index created without `rollover_alias` setting, causing ISM failures
**Fix**: Updated `makefile` line 541 in `es-bootstrap-index` target
```makefile
# Before:
-d '{"aliases": {"$(ES_WRITE_ALIAS)": {"is_write_index": true}}}'

# After:
-d '{"aliases": {"$(ES_WRITE_ALIAS)": {"is_write_index": true}}, "settings": {"index.plugins.index_state_management.rollover_alias": "$(ES_WRITE_ALIAS)"}}'
```

### 2. Fixed es-list-execution-labels
**Problem**: Queried `execution_label.keyword` but field is mapped as `keyword` type (no `.keyword` subfield)
**Fix**: Changed query from `execution_label.keyword` to `execution_label` (line 408)
**Also fixed**: Rewrote inline Python script to one-liner to avoid backslash syntax errors

### 3. Added Schema Documentation
**Files Updated**:
- `es_integration/opensearch_mapping_template.json`
- `es_integration/es_mapping_template.json`

**Added `_meta` section** with field descriptions:
- **cpu**: "Number of CPUs allocated to one pod in Kubernetes resource (count, not percentage). Suffix '(Gu)' indicates guaranteed CPUs"
- **busy_cpu**: "Sum of busy CPU count from both client and server worker nodes involved in the test (count, not percentage)"
- **execution_label**: "Test execution label (e.g., dpu-accelerated, non-accelerated)"
- Other fields documented: batch_id, run_id, iteration_id, mean, stddev, unit

### 4. Fixed MCP Server Container Build
**Problem**: Dockerfile couldn't access `es_integration/es_config.py` from parent directory
**Fix**:
- Changed build context from `mcp_server/` to `REPORT/` in `build_and_run.sh`
- Updated Dockerfile COPY paths to be relative to REPORT directory
- Container now properly shares config between makefile tools and MCP server

---

## Critical Field Definitions

### CPU vs busy_cpu (Important!)
- **cpu**: Number of CPUs allocated **per pod** in K8s resource spec
  - Example: `52` = 52 CPUs per pod
  - Example: `6(Gu)` = 6 guaranteed CPUs per pod
  - Type: Count, NOT percentage

- **busy_cpu**: **Total** busy CPU count across **both client AND server worker nodes**
  - Example: `118.99` = ~119 CPU cores busy across all nodes involved
  - Type: Count, NOT percentage
  - Represents actual CPU consumption during test

### Execution Labels
- **dpu-accelerated**: DPU model tests (277 docs)
- **non-accelerated**: OVNK model tests (194 docs)

### Models
- **DPU**: DPU-accelerated mode (no traditional NIC)
- **OVNK**: OVN-Kubernetes with BF3 NIC (baseline)

---

## Current Data

### Batches
1. `a83cdb3f-b6cc-49bc-ab45-0497326876d4`: 277 docs (dpu-accelerated)
2. `2f96f666-adb0-44e6-ae8b-a2f2052ed976`: 194 docs (non-accelerated)

### Benchmarks
- **uperf**: 409 docs (primary benchmark)
- **iperf**: 62 docs (secondary benchmark)

### Performance Highlights
- **Highest busy_cpu**: 118.99 CPUs (DPU, 88.97 Gbps)
- **Lowest busy_cpu**: 0.40 CPUs (DPU UDP crr tests)
- **Best throughput**: 301.67 Gbps (DPU, 86.93 busy CPUs)

---

## Key Files and Locations

### Makefile (`REPORT/makefile`)
Main entry point for all operations:
- `make es-bootstrap-index`: Create rollover index with ISM policy
- `make es-upload`: Upload data to ES
- `make es-full`: Complete workflow (summary → template → upload)
- `make es-list-execution-labels`: List execution labels
- `make es-ilm-explain`: Check ISM policy status
- `make summary`: Generate reports (unflatten + flatten)

### Templates
- `es_integration/opensearch_mapping_template.json`: OpenSearch template (with _meta docs)
- `es_integration/es_mapping_template.json`: ElasticSearch template (with _meta docs)

### MCP Server
- `mcp_server/regulus_es_mcp.py`: MCP server for Claude Desktop (not used on Linux)
- `mcp_server/es_cli.py`: CLI for containerized queries
- `mcp_server/build_and_run.sh`: Build and run container

### Shared Config
- `es_integration/es_config.py`: Centralized ES configuration
  - `ES_INDEX = "regulus-results-*"` (query pattern)
  - `ES_WRITE_ALIAS = "regulus-results-write"` (upload target)

---

## Common Workflows

### Bootstrap New Index (Complete Setup)
```bash
cd REPORT
make es-bootstrap-index  # Creates index + ISM policy + template + write alias
```

### Upload Data
```bash
cd REPORT
make summary             # Generate report.json and reports.ndjson
make es-upload          # Upload to ES via write alias
```

### Query Data (Fast - Use Container CLI)
```bash
cd REPORT/mcp_server
./build_and_run.sh stats
./build_and_run.sh list-batches
./build_and_run.sh search --execution-label dpu-accelerated --size 10
./build_and_run.sh batch-info <batch-id>
```

### Check ISM Status
```bash
cd REPORT
make es-ilm-explain
```

---

## Architecture Decisions

### Why Rollover Indices?
- Enables automatic index lifecycle management
- Supports Cross-Cluster Replication (CCR)
- Better performance than single large index
- Easier to manage retention policies

### Why No Delete Phase?
- CCR compatibility (follower clusters need time to replicate)
- Manual deletion gives more control
- Prevents accidental data loss

### Why Write Alias?
- Abstracts away rollover index numbers
- Upload always goes to current "hot" index
- Queries use pattern (`regulus-results-*`) to search all indices

### Why Both Templates?
- `opensearch_mapping_template.json`: For OpenSearch (ISM-based)
- `es_mapping_template.json`: For ElasticSearch (ILM-based)
- Different lifecycle management approaches

---

## Known Issues/Limitations

### Performance
- Claude Code queries take ~30 seconds (my processing overhead, not ES)
- Direct container CLI is instant (<1 second)
- Recommendation: Use container CLI for quick queries, use Claude for analysis

### Environment
- Claude Desktop not supported on Linux servers
- MCP server exists but can't be used with Claude Desktop
- Container CLI (`build_and_run.sh`) is the best alternative

### Field Mapping Confusion
- Some fields are `keyword` type (no `.keyword` subfield needed)
- Some fields are `text` with `.keyword` subfield (like `batch_id`)
- Check template or use aggregations without `.keyword` suffix first

---

## Verification Commands

### Check Everything is Working
```bash
# Index exists and has data
make es-index-stats

# Write alias points to correct index
curl -s "${ES_URL}/_cat/aliases/regulus-results-write?v"

# ISM policy is attached and working
make es-ilm-explain

# rollover_alias setting is present
curl -s "${ES_URL}/regulus-results-000001/_settings?flat_settings=true" | grep rollover_alias

# Data is queryable
./mcp_server/build_and_run.sh stats
```

### Expected State
- Index: `regulus-results-000001` with 471 docs
- Write alias: `regulus-results-write` → `regulus-results-000001`
- ISM: Policy attached, enabled, no failures
- Setting: `index.plugins.index_state_management.rollover_alias: "regulus-results-write"`

---

## Next Steps / TODO

### If Continuing This Work
1. Monitor ISM rollover (check when it triggers)
2. Test rollover by adding more data or manually triggering
3. Verify new index (000002) gets created with proper settings
4. Consider adding more field documentation to `_meta`

### If Starting Fresh
1. Read this file to understand current state
2. Verify system status with commands above
3. Check git log for recent commits
4. Review makefile targets with `make help`

---

## Quick Reference

### ES Configuration Variables
```bash
BASE_NAME=regulus-results              # Infrastructure constant for rollover
ES_INDEX=regulus-results-*            # Query pattern (read from all indices)
ES_WRITE_ALIAS=regulus-results-write  # Upload target (current hot index)
```

### ISM Policy States
```
hot (30d) → warm (7d) → replicated (indefinite)
```

### Field Types to Remember
- `cpu`, `execution_label`, `benchmark`, `model`: `keyword` (no .keyword needed)
- `batch_id`: `text` with `.keyword` subfield (use .keyword for aggregations)
- `mean`, `busy_cpu`, `stddev`: `float`
- `threads`, `wsize`, `pods_per_worker`: `integer`

---

## Git Status at Session End

**Modified files**:
- `REPORT/makefile` (es-bootstrap-index fix, es-list-execution-labels fix)
- `REPORT/es_integration/opensearch_mapping_template.json` (_meta documentation)
- `REPORT/es_integration/es_mapping_template.json` (_meta documentation)
- `REPORT/mcp_server/Dockerfile` (build context fix)
- `REPORT/mcp_server/build_and_run.sh` (build context fix)

**Commit ready**: Yes, all changes tested and verified

---

## Contact/References

- Makefile help: `cd REPORT && make help`
- Container CLI help: `./mcp_server/build_and_run.sh --help`
- ES config: Check `es_integration/es_config.py` for centralized settings
- ISM policy files: `es_integration/opensearch_ism_policy*.json`
