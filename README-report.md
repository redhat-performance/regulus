# Regulus Report Generation and Analysis

This document describes the REPORT/ directory structure and tools for generating, analyzing, and querying Regulus benchmark results.

## Overview

The REPORT/ directory contains a complete ETL (Extract, Transform, Load) pipeline and analysis tools for Regulus benchmark data:

- **build_report/** - Core report generation engine (6-stage ETL pipeline)
- **dashboard/** - Web-based interactive dashboard for visualizing reports
- **es_integration/** - ElasticSearch/OpenSearch integration for data warehousing
- **mcp_server/** - Model Context Protocol server for AI-powered queries via Claude Desktop

## Quick Start

### Generate a Report

```bash
cd $REG_ROOT
make summary
```

This generates:
- `REPORT/generated/report.json` - Complete structured report
- `REPORT/generated/report.html` - Human-readable HTML report
- `REPORT/generated/report.csv` - CSV export for spreadsheet analysis

### View in Dashboard

```bash
cd $REG_ROOT
make report-dashboard
# Opens at http://localhost:5001
```

The dashboard provides:
- Side-by-side comparison of multiple reports
- Interactive filtering and sorting
- Visual performance analysis
- Export capabilities

### Upload to ElasticSearch

```bash
cd $REG_ROOT
make es-upload
```

Upload results to ElasticSearch/OpenSearch for:
- Long-term trend analysis
- Cross-run comparisons
- Advanced querying and aggregations

### Query via AI (Multiple Options)

The MCP server works with multiple AI frontends:

**Option 1: Claude Desktop** (macOS, Windows)
- Natural language queries through Claude AI
- Best for interactive exploration

**Option 2: Cline** (VS Code Extension - All Platforms)
- AI coding assistant integrated into VS Code
- Works on Linux, macOS, Windows
- Great for developers

**Option 3: Standalone CLI** (All Platforms)
- Direct command-line access
- No AI frontend required
- Fastest for scripting

Example queries:
- "Show me all DPU benchmarks with throughput > 300 Gbps"
- "Compare the last two upload batches"
- "What's the average performance by NIC type?"

See `REPORT/mcp_server/README.md` for setup instructions for each option.

---

## Directory Structure

```
REPORT/
├── build_report/        # Core report generation (ETL pipeline)
│   ├── discovery/       # Discover test run artifacts
│   ├── extraction/      # Extract metrics from run data
│   ├── transformation/  # Transform/normalize data
│   ├── orchestration/   # Coordinate the pipeline stages
│   ├── output/          # Generate output formats (JSON, HTML, CSV)
│   ├── parsing/         # Parse tool-specific outputs
│   ├── rules/           # Data validation and business rules
│   ├── schema/          # JSON schema definitions and versioning
│   ├── models/          # Data models (BenchmarkResult, etc.)
│   └── interfaces/      # Shared interfaces and protocols
│
├── dashboard/           # Interactive web dashboard
│   ├── run_dashboard.py     # Flask application
│   ├── dashboard_app.py     # Core dashboard logic
│   ├── data_loader.py       # Report loading utilities
│   ├── aggregator.py        # Data aggregation functions
│   ├── templates/           # HTML templates
│   ├── static/              # JavaScript, CSS
│   ├── docker/              # Containerized deployment
│   └── test_data/           # Sample reports for testing
│
├── es_integration/      # ElasticSearch/OpenSearch integration
│   ├── flatten_to_es.py     # Convert reports to ES format
│   ├── detect_platform.sh   # Auto-detect ES vs OpenSearch
│   ├── es_mapping_template.json        # ES mapping
│   ├── opensearch_mapping_template.json # OpenSearch mapping
│   └── README.md            # Integration documentation
│
├── mcp_server/          # MCP server for Claude Desktop
│   ├── regulus_es_mcp.py    # MCP server implementation
│   ├── es_cli.py            # Standalone CLI wrapper
│   ├── build_and_run.sh     # Containerized execution
│   └── README.md            # Setup and usage guide
│
├── makefile             # Main orchestration makefile
└── generated/           # Output directory for reports
```

---

## Report Generation Pipeline

The `build_report/` ETL pipeline consists of 6 stages:

### 1. Discovery
Scans the filesystem to discover test run directories and artifacts.

### 2. Extraction
Extracts raw metrics from tool-specific outputs:
- uperf results
- iperf3 results
- CPU utilization
- System configuration

### 3. Transformation
Normalizes and enriches data:
- Unit conversions
- Field standardization
- Metadata extraction from file paths
- Testbed information integration

### 4. Orchestration
Coordinates the pipeline execution:
- Manages stage dependencies
- Handles errors and retries
- Aggregates results from multiple runs

### 5. Output
Generates multiple output formats:
- **JSON**: Structured data for programmatic access
- **HTML**: Human-readable report with formatting
- **CSV**: Spreadsheet-compatible export

### 6. Schema Validation
Validates output against versioned JSON schemas to ensure data consistency.

---

## Common Workflows

### 1. Generate Report from Latest Test Runs

```bash
cd $REG_ROOT

# Generate basic report
make summary

# Generate report with testbed info
make summary-with-testbed-info

# Flatten report for ElasticSearch
make flatten
```

### 2. Compare Multiple Test Runs

```bash
# Generate reports for each test run
cd $REG_ROOT
make summary

# Launch dashboard
make report-dashboard

# Load multiple reports in the web UI
# Navigate to http://localhost:5001
```

### 3. Upload Results to ElasticSearch

```bash
cd $REG_ROOT

# Configure ES_URL in lab.config
# Then upload
make es-upload

# Verify upload
make es-index-stats

# Delete a batch if needed
make es-delete-batch BATCH_ID=your-batch-uuid
```

### 4. Query Historical Data

```bash
cd $REG_ROOT/REPORT/mcp_server

# Using containerized CLI
./build_and_run.sh search --model DPU --topology internode

# List all batches
./build_and_run.sh list-batches

# Compare two batches
./build_and_run.sh compare batch1-uuid batch2-uuid

# Show statistics
./build_and_run.sh stats
```

---

## Configuration

### lab.config

Configure ElasticSearch connection in `$REG_ROOT/lab.config`:

```bash
# ElasticSearch/OpenSearch Configuration
export ES_URL="https://username:password@your-es-host.amazonaws.com"
export ES_INDEX="regulus-results"
```

### Report Generation Options

```bash
# Custom output location
make summary OUTPUT=/path/to/output

# Generate specific formats only
make summary FORMATS="json html"

# Include testbed metadata
make summary-with-testbed-info
```

---

## ElasticSearch Integration

### Index Structure

Each benchmark result is stored as a flat document with fields:

- **Test identification**: `benchmark`, `test_type`, `protocol`
- **Infrastructure**: `model`, `nic`, `arch`, `cpu`, `kernel`, `rcos`
- **Configuration**: `topology`, `performance_profile`, `offload`, `threads`, `wsize`, `rsize`
- **Performance metrics**: `mean`, `min`, `max`, `stddev`, `unit`, `busy_cpu`
- **Metadata**: `batch_id`, `run_id`, `@timestamp`, `regulus_git_branch`

### Understanding Metrics

**CPU Metric (`busy_cpu`)**: This is **NOT a percentage**. It represents the **aggregated sum of CPU utilization** across all CPUs (mpstat: sum of % busy). For example, `busy_cpu: 44.8` means 44.8 CPU-equivalents of work were consumed.

**Internode Tests**: Each internode benchmark uses 2 workers (sender + receiver on different nodes). When `cpu: 2` is shown in configuration, that's per worker, so total CPUs allocated = 4. The `busy_cpu` metric reflects aggregated utilization across both workers.

See `REPORT/mcp_server/SEARCH_EXAMPLES.md` for detailed metric interpretation.

### Search Examples

```bash
# Search by model and NIC
./build_and_run.sh search --model OVNK --nic BF3

# Filter by performance
./build_and_run.sh search --min-throughput 5000000 --test-type rr

# Combine multiple filters
./build_and_run.sh search \
  --model DPU \
  --topology internode \
  --protocol tcp \
  --wsize 32768
```

See `REPORT/mcp_server/SEARCH_EXAMPLES.md` for more examples.

---

## Dashboard Features

The interactive dashboard (`REPORT/dashboard/`) provides:

### Multi-Report Comparison
- Load multiple JSON reports simultaneously
- Side-by-side performance comparison
- Color-coded performance deltas

### Filtering & Sorting
- Filter by benchmark type, model, NIC, topology
- Sort by any column
- Search across all fields

### Data Export
- Export filtered results to CSV
- Generate comparison reports
- Share analysis with team

### Visualization
- Performance trend charts
- Distribution histograms
- Comparative bar charts

---

## MCP Server (Claude Desktop Integration)

The MCP server enables natural language queries of ElasticSearch data through Claude Desktop.

### Available Tools

1. **list_batches** - List all upload batches
2. **get_batch_info** - Get details about a specific batch
3. **search_benchmarks** - Search with filters (20+ filter options)
4. **compare_batches** - Compare performance between batches
5. **delete_batch** - Delete a batch with confirmation
6. **get_index_stats** - View index statistics

### Setup

See `REPORT/mcp_server/README.md` for complete setup instructions.

**Note:** Claude Desktop is only available for macOS and Windows. Linux users should use the standalone CLI (`es_cli.py` or `build_and_run.sh`).

---

## Makefile Targets

### Report Generation

```bash
make summary                    # Generate basic report
make summary-with-testbed-info  # Include testbed metadata
make flatten                    # Flatten to ES format
```

### Dashboard

```bash
make report-dashboard           # Launch web dashboard
make report-dashboard-docker    # Launch containerized dashboard
```

### ElasticSearch

```bash
make es-upload                  # Upload report to ES
make es-index-stats             # Show index statistics
make es-list-batches            # List all batches
make es-show-keywords           # Show valid filter values
make es-delete-batch BATCH_ID=uuid  # Delete a batch
```

### Debugging

```bash
make es-debug                   # Debug ES connection
make es-test-upload             # Test upload with sample data
```

---

## Troubleshooting

### Report Generation Issues

**Problem:** `make summary` fails with "No runs found"

**Solution:** Ensure test runs completed successfully and have results in their `latest/` directories.

---

**Problem:** Report missing expected benchmarks

**Solution:** Check discovery logs. Some runs may have failed extraction due to incomplete data.

---

### Dashboard Issues

**Problem:** Dashboard doesn't load reports

**Solution:**
- Verify report.json exists in `REPORT/generated/`
- Check console for JavaScript errors
- Ensure proper JSON formatting with `jq . report.json`

---

### ElasticSearch Issues

**Problem:** `make es-upload` fails with connection error

**Solution:**
- Verify `ES_URL` is set in `lab.config`
- Test connection: `curl -u user:pass $ES_URL`
- Check firewall/network access

---

**Problem:** Upload succeeds but no data visible

**Solution:**
- Check batch ID from upload output
- Verify with: `./build_and_run.sh list-batches`
- Check ES index with: `make es-index-stats`

---

## Advanced Usage

### Custom Report Formats

Extend the output stage to add new formats:

```python
# In REPORT/build_report/output/
class MyCustomFormatter:
    def format(self, results: List[BenchmarkResult]) -> str:
        # Custom formatting logic
        pass
```

### Custom Extraction Rules

Add new metric extractors in `REPORT/build_report/extraction/`:

```python
class MyToolExtractor:
    def extract(self, run_dir: Path) -> List[BenchmarkResult]:
        # Custom extraction logic
        pass
```

### Integration with Other Systems

Use the data loader library for custom integrations:

```python
from REPORT.dashboard.data_loader import ReportLoader

loader = ReportLoader()
results = loader.load_report("path/to/report.json")

for result in results:
    # Process results
    send_to_grafana(result)
```

---

## Schema Versioning

Reports include schema version metadata for compatibility tracking:

```json
{
  "schema_version": "1.0.0",
  "generated_at": "2026-02-02T18:30:00Z",
  "regulus_git_branch": "main",
  "results": [...]
}
```

Schema changes are tracked in `REPORT/build_report/schema/versions/`.

---

## Contributing

When adding new features to the REPORT pipeline:

1. Follow the existing stage pattern (discovery → extraction → transformation → output)
2. Add schema definitions for new fields
3. Update this documentation
4. Add test cases with sample data
5. Ensure backward compatibility with existing reports

---

## Further Reading

- **Build Report**: `REPORT/build_report/README.md` - Detailed ETL pipeline documentation
- **Dashboard**: `REPORT/dashboard/README.md` - Dashboard features and deployment
- **ES Integration**: `REPORT/es_integration/README.md` - ElasticSearch setup and mapping
- **MCP Server**: `REPORT/mcp_server/README.md` - Claude Desktop integration guide
- **Search Examples**: `REPORT/mcp_server/SEARCH_EXAMPLES.md` - Query examples

---

## Support

For issues or questions:
- Check the troubleshooting section above
- Review component-specific READMEs in subdirectories
- File issues at: https://github.com/redhat-performance/regulus/issues
