# ElasticSearch Integration

This directory contains tools for flattening benchmark reports into ElasticSearch-compatible format.

## Overview

The dashboard's report.json files have a nested structure that works well for the web dashboard but isn't ideal for ElasticSearch, Grafana, or MCP servers. This tooling flattens the nested structure into a simple, flat format suitable for time-series analysis.

## Architecture

```
REPORT/
├── dashboard/
│   └── data_loader.py       # Shared data loading logic
├── es_integration/          # This directory
│   ├── flatten_to_es.py      # Flattening script (imports from ../dashboard/data_loader.py)
│   ├── detect_platform.sh    # Auto-detect ElasticSearch vs OpenSearch
│   ├── debug_upload_errors.py # Upload error diagnostics
│   ├── es_mapping_template.json      # ElasticSearch field mappings
│   ├── opensearch_mapping_template.json  # OpenSearch field mappings
│   └── README.md            # This file
└── build_report/            # Core report generation (peer tool)
```

**Key Design Principle**: Both the dashboard and ES flattener import from the same `dashboard/data_loader.py` module. This ensures consistency - any changes to the BenchmarkResult dataclass automatically propagate to both consumers.

## Files

### flatten_to_es.py

Main script that converts report.json files to NDJSON format for ElasticSearch bulk API.

**Features**:
- Imports from `dashboard/data_loader.py` for consistent parsing
- Converts BenchmarkResult objects to flat documents
- Generates NDJSON format (newline-delimited JSON)
- Supports both file output and direct ES upload
- Processes single files or entire directories

### es_mapping_template.json

ElasticSearch index template defining proper field types:
- `keyword` for categorical data (model, nic, kernel, etc.)
- `integer` for counts and scale parameters
- `float` for performance metrics
- `date` for timestamps

## Usage

### Basic Usage

```bash
# Convert single report to NDJSON
python3 elasticsearch/flatten_to_es.py report.json -o report.ndjson

# Process all reports in test_data directory
python3 elasticsearch/flatten_to_es.py dashboard/test_data/ -o all_reports.ndjson
```

### Upload to ElasticSearch

```bash
# Direct upload (requires `pip install elasticsearch`)
python3 elasticsearch/flatten_to_es.py report.json \
    --es-host localhost:9200 \
    --es-index benchmark-results

# Upload with authentication
python3 elasticsearch/flatten_to_es.py dashboard/test_data/ \
    --es-host localhost:9200 \
    --es-index benchmark-results \
    --es-user elastic \
    --es-password changeme
```

### Apply Index Template

Before uploading data, apply the mapping template:

```bash
# Using curl
curl -X PUT "localhost:9200/_index_template/benchmark-results-template" \
  -H 'Content-Type: application/json' \
  -d @elasticsearch/es_mapping_template.json

# Or using ElasticSearch Python client
from elasticsearch import Elasticsearch
import json

es = Elasticsearch(['localhost:9200'])
with open('elasticsearch/es_mapping_template.json') as f:
    template = json.load(f)
    es.indices.put_index_template(name='benchmark-results-template', body=template)
```

## Data Schema

Each benchmark result is flattened into a single document:

```json
{
  "@timestamp": "2026-01-22T10:30:00Z",
  "regulus_data": "/path/to/result-summary.json",
  "run_id": "run123",
  "iteration_id": "iter456",
  "benchmark": "uperf",
  "test_type": "stream",
  "protocol": "tcp",
  "model": "OVNK",
  "nic": "CX7",
  "arch": "sapphire_rapids",
  "cpu": "Intel-8480",
  "kernel": "5.14.0-362",
  "rcos": "4.14",
  "topology": "pod2pod",
  "performance_profile": "latency-performance",
  "offload": "on",
  "threads": 16,
  "wsize": 65536,
  "rsize": 65536,
  "pods_per_worker": 4,
  "scale_out_factor": 2,
  "mean": 94.5,
  "min": 92.1,
  "max": 96.8,
  "stddev": 1.2,
  "stddev_pct": 1.3,
  "unit": "Gbps",
  "busy_cpu": 8.4,
  "samples_count": 10
}
```

## Integration with Dashboard

The flattening script reuses the dashboard's data loading logic:

```python
# In flatten_to_es.py
from dashboard.data_loader import ReportLoader, BenchmarkResult

loader = ReportLoader()
loader.load_report('report.json')
results = loader.extract_all_results()  # List[BenchmarkResult]

# Convert each BenchmarkResult to flat ES document
for result in results:
    doc = flattener.flatten_result(result)
```

This means:
- Changes to BenchmarkResult automatically apply to both systems
- Same parsing logic = consistent data interpretation
- No duplication of report parsing code

## Tracking Data Schema Changes

When modifying `dashboard/data_loader.py`:

1. **Adding new fields**: Update both `BenchmarkResult` dataclass AND `es_mapping_template.json`
2. **Changing field types**: Update `es_mapping_template.json` to match
3. **Document changes**: Add entry to dashboard/data_loader.py comments

Example:
```python
# dashboard/data_loader.py
@dataclass
class BenchmarkResult:
    # ... existing fields ...
    new_field: Optional[str] = None  # v1.1.0: Added support for new_field
```

Then update `es_mapping_template.json`:
```json
{
  "properties": {
    "new_field": {
      "type": "keyword"
    }
  }
}
```

## Grafana Integration

After data is in ElasticSearch, create Grafana dashboards:

1. Add ElasticSearch as data source in Grafana
2. Create queries using the flat schema:
   ```
   Index: benchmark-results-*
   Time field: @timestamp
   Metrics: avg(mean), max(mean), etc.
   Group by: model, nic, kernel, etc.
   ```

3. Example queries:
   - Performance by model: `avg(mean) GROUP BY model`
   - Scaling analysis: `avg(mean) GROUP BY pods_per_worker`
   - Time series: `avg(mean) OVER TIME`

## MCP Server Integration

The flattened format is also suitable for MCP (Model Context Protocol) servers. The flat structure makes it easy to:

- Query benchmark results by any dimension
- Build time-series analyses
- Compare configurations
- Track performance trends

## Troubleshooting

### Import Error: Cannot import dashboard.data_loader

Make sure you're running from the `REPORT` directory or use the makefile targets:

```bash
cd REPORT
make flatten
# Or:
python3 es_integration/flatten_to_es.py ...
```

### ElasticSearch connection failed

Check that ElasticSearch is running:
```bash
curl http://localhost:9200
```

### Field type mismatch

If you get field type errors, you may need to delete and recreate the index:
```bash
curl -X DELETE "localhost:9200/benchmark-results-*"
# Then reapply the index template
```

## Future Enhancements

Potential improvements (pending feedback from MCP and Grafana teams):

1. **Add computed fields**: CPU efficiency, performance per core, etc.
2. **Aggregations**: Pre-compute common aggregations
3. **Data retention policies**: ILM (Index Lifecycle Management) for old data
4. **Additional metadata**: Git commit hash, build version, etc.
5. **Dashboard refactoring**: If flattened format stabilizes, refactor dashboard to use it too

## Development Notes

This is an early phase implementation (Option B approach):
- Original `report.json` remains unchanged
- Flattened version is a separate post-processing step
- Allows iteration based on feedback from consumers
- Once format stabilizes (2-3 months), consider refactoring dashboard to use flattened version

## Support

For issues or questions:
- Check existing dashboard/data_loader.py documentation
- Verify ElasticSearch version compatibility
- Test with dashboard/test_data first
