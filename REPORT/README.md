# REPORT - Benchmark Report Generation and Analysis

This directory contains the complete reporting infrastructure for the Regulus benchmark framework.

## Table of Contents

1. [Directory Structure](#directory-structure)
2. [Makefile Architecture](#makefile-architecture)
3. [Target Reference](#target-reference)
4. [Understanding Data Contexts](#understanding-data-contexts)
5. [Common Workflows](#common-workflows)

---

## Directory Structure

```
REPORT/
├── README.md                  # This file
├── makefile                   # Central REPORT operations
├── generated/                 # Output directory for generated reports
├── assembly/                  # Scripts to merge inventory data into reports
│   └── assemble_report.sh     # Main assembly script
├── build_report/              # Core report generation (6-stage ETL pipeline)
│   ├── build_report           # Main report generation script
│   ├── reg-report.py          # Python CLI entry point
│   ├── factories.py           # Factory pattern for orchestrator creation
│   ├── models/                # Data models and enums
│   ├── interfaces/            # Protocol definitions (contracts)
│   ├── schema/                # JSON schema management
│   ├── discovery/             # File finding and traversal
│   ├── parsing/               # Content reading
│   ├── rules/                 # Regex extraction rules
│   ├── extraction/            # Data extraction from files
│   ├── transformation/        # Data processing
│   ├── output/                # Report generation (JSON, HTML, CSV)
│   └── orchestration/         # Workflow coordination
├── dashboard/                 # Web dashboard application (peer tool)
│   ├── run_dashboard.py       # Flask dashboard server
│   ├── data_loader.py         # Report loading logic
│   ├── templates/             # HTML templates
│   ├── static/                # JS/CSS assets
│   ├── test_data/             # Sample benchmark data (16 JSON files, 318 results)
│   └── docker/                # Docker containerization for dashboard
├── es_integration/            # ElasticSearch integration (peer tool)
│   ├── README.md              # ElasticSearch integration guide
│   ├── flatten_to_es.py       # Convert reports to NDJSON format
│   ├── detect_platform.sh     # Auto-detect ES vs OpenSearch
│   ├── debug_upload_errors.py # Upload error diagnostics
│   ├── es_mapping_template.json      # ElasticSearch template
│   └── opensearch_mapping_template.json  # OpenSearch template
└── mcp_server/                # MCP server for ES queries (peer tool)
    ├── regulus_es_mcp.py      # FastMCP server with 6 ES tools
    ├── es_cli.py              # CLI wrapper for all MCP tools
    ├── es_show_keywords.py    # Display valid filter values
    └── README.md              # MCP server documentation
```

---

## Makefile Architecture

The reporting system uses a **two-level makefile delegation pattern**:

```
Root makefile (regulus/)
    ↓ delegates to
REPORT/makefile
```

### Key Differences by Level

| Aspect | Root makefile | REPORT/makefile |
|--------|---------------|-----------------|
| **Prefix** | `report-*` targets | No prefix |
| **Purpose** | Convenience wrappers | Direct implementation |
| **Data Context** | Production (regulus/) | Production (REG_ROOT) |
| **Example** | `make report-dashboard` | `make dashboard` |

---

## Target Reference

All report targets can be invoked from two locations:

### Report Generation

| Target | From Root | From REPORT/ | Description |
|--------|-----------|--------------|-------------|
| `report-summary` | ✓ | - | Generate report.json, reports.ndjson, HTML, CSV |
| `summary` | - | ✓ | Generate report.json, reports.ndjson, HTML, CSV |
| `report-summary-with-testbed-info` | ✓ | - | Generate report with inventory data |
| `summary-with-testbed-info` | - | ✓ | Generate report with inventory data |

### Dashboard Management

| Target | From Root | From REPORT/ | Description |
|--------|-----------|--------------|-------------|
| `report-dashboard` | ✓ | - | Start dashboard with reports from generated/ |
| `dashboard` | - | ✓ | Start dashboard with reports from generated/ |
| `report-dashboard-stop` | ✓ | - | Stop all dashboard instances |
| `dashboard-stop` | - | ✓ | Stop all dashboard instances |
| `report-dashboard-restart` | ✓ | - | Restart dashboard |
| `dashboard-restart` | - | ✓ | Restart dashboard |

### ElasticSearch Operations

| Target | From Root | From REPORT/ | Description |
|--------|-----------|--------------|-------------|
| `es-check` | - | ✓ | Verify ES connection |
| `es-template` | - | ✓ | Apply ES index template |
| `es-upload` | - | ✓ | Upload reports.ndjson to ES |
| `report-es-full` | ✓ | - | Complete ES workflow (generate → template → upload) |
| `es-full` | - | ✓ | Complete ES workflow (generate → template → upload) |
| `es-index-stats` | - | ✓ | Show ES index statistics |
| `es-template-info` | - | ✓ | Show ES template details |
| `es-index-mapping` | - | ✓ | Show current index mapping |
| `es-list-batches` | - | ✓ | List all upload batches |
| `es-show-last-batch` | - | ✓ | Show most recent batch |
| `es-batch-count` | - | ✓ | Count documents in batch (requires ES_BATCH_ID) |
| `es-batch-info` | - | ✓ | Show batch details (requires ES_BATCH_ID) |
| `es-delete-batch` | - | ✓ | Delete batch (requires ES_BATCH_ID) |

---

## Understanding Data Flow

### Generated Reports

**Location:** `REPORT/generated/`

All report generation targets output to this directory:
- `report.json` - Unflatten benchmark results with full structure
- `reports.ndjson` - Flatten NDJSON format for ElasticSearch
- `report.html` - Interactive HTML report
- `report.csv` - Spreadsheet-friendly CSV
- `report_schema.json` - JSON schema validation file

### Test Data for Dashboard Development

**Location:** `REPORT/dashboard/test_data/`

**Characteristics:**
- 16 JSON files with mock benchmark results
- 318 total benchmark iterations
- Contains diverse scenarios for testing dashboard features
- Safe for development and testing

**Usage:**
```bash
cd REPORT
python3 dashboard/run_dashboard.py --reports dashboard/test_data
# Open http://localhost:5000
```

### Production Workflow

```bash
# 1. Generate reports
cd regulus
make report-summary                    # Creates REPORT/generated/*.{json,ndjson,html,csv}

# 2. View in dashboard
make report-dashboard                  # Loads from REPORT/generated/

# 3. Upload to ElasticSearch
make report-es-full                    # Complete workflow: generate → template → upload
```

---

## Common Workflows

### 1. Generate Reports

```bash
cd regulus
make report-summary

# Outputs to REPORT/generated/:
# - report.json      (unflatten format with full structure)
# - reports.ndjson   (flatten NDJSON for ElasticSearch)
# - report.html      (interactive HTML with charts)
# - report.csv       (spreadsheet-friendly)
```

### 2. Generate Report with Testbed Information

```bash
cd regulus
make report-summary-with-testbed-info

# Merges inventory data (CPU, RAM, NIC details) into report
# Outputs to REPORT/generated/report-with-testbed-info.json
```

### 3. View Reports in Dashboard

```bash
cd regulus
make report-dashboard
# Open http://localhost:5000

# Dashboard loads reports from REPORT/generated/
# Stop with: make report-dashboard-stop
```

### 4. Upload to ElasticSearch

```bash
cd regulus

# Option 1: Complete workflow (recommended)
make report-es-full
# Runs: summary → es-template → es-upload

# Option 2: Step by step
make report-summary        # Generate reports
cd REPORT
make es-template           # Apply index template
make es-upload             # Upload to ES
```

For detailed ElasticSearch documentation, see `REPORT/es_integration/README.md`.

### 5. Manage Upload Batches

Each upload is assigned a unique `batch_id` (UUID) for tracking and selective deletion.

```bash
cd REPORT

# List all upload batches
make es-list-batches

# Show most recent batch
make es-show-last-batch

# Get batch details
make es-batch-info ES_BATCH_ID=<uuid>

# Delete a batch (with confirmation)
make es-delete-batch ES_BATCH_ID=<uuid>
```

### 6. Development: Test Dashboard with Mock Data

```bash
cd REPORT

# Start dashboard with test data
python3 dashboard/run_dashboard.py --reports dashboard/test_data

# Edit dashboard files
vim dashboard/templates/index.html
vim dashboard/static/dashboard.js

# Reload browser to see changes
```

---

## Configuration

### Environment Variables

ElasticSearch configuration is determined with the following priority:

1. **ES_URL environment variable** (if already set)
2. **/secret directory** (Kubernetes/Prow production secrets)
3. **lab.config file** (development/testing)

**lab.config example:**
```bash
export ES_URL='https://user:password@host.example.com'
export ES_INDEX='regulus-results'
```

### Makefile Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `REG_ROOT` | `$(shell cd .. && pwd)` | Root directory of regulus project |
| `ES_INDEX` | `regulus-results` | ElasticSearch index name |

**Override example:**
```bash
cd regulus
make report-es-full ES_INDEX=my-custom-index
```

---

## Tips and Troubleshooting

### Dashboard Port Conflicts

**Problem:** Dashboard fails with "Address already in use"

**Solution:**
```bash
# Stop all running dashboard instances
make dashboard-stop

# Or manually find and kill
ss -lntp | grep :5000
kill <PID>
```

### Viewing Dashboard Logs

```bash
# Test data dashboard
tail -f /tmp/dashboard-test.log

# Or use makefile target
cd REPORT/build_report
make dashboard-logs
```

### Dashboard Shows No Results

**Check:**
```bash
# Verify generated reports exist
ls -la generated/

# Dashboard loads from generated/ by default
# Or specify custom directory:
python3 dashboard/run_dashboard.py --reports /custom/path
```

### ElasticSearch Connection Issues

**Check configuration priority:**
```bash
# 1. Check if ES_URL is in environment
echo $ES_URL

# 2. Check lab.config
grep ES_URL ../lab.config

# 3. Check /secret directory (production only)
ls -la /secret/
```

---

## Quick Reference

```bash
# From regulus/ (root):
make report-summary                   # Generate all reports
make report-summary-with-testbed-info # Generate with inventory
make report-dashboard                 # View in browser
make report-dashboard-stop            # Stop dashboard
make report-es-full                   # Complete ES workflow

# From REPORT/:
make summary                          # Generate all reports
make summary-with-testbed-info        # Generate with inventory
make dashboard                        # View in browser
make es-check                         # Verify ES connection
make es-template                      # Apply ES index template
make es-upload                        # Upload to ES
make es-full                          # Complete ES workflow
make es-list-batches                  # List all batches
make es-delete-batch ES_BATCH_ID=<uuid>  # Delete batch

# Dashboard development:
cd REPORT
python3 dashboard/run_dashboard.py --reports dashboard/test_data
```

---

## Additional Documentation

- **Core Report Generation:** `build_report/README.md` - 6-stage ETL pipeline details
- **Dashboard:** `dashboard/README.md` - Web dashboard features and API
- **ElasticSearch Integration:** `es_integration/README.md` - ES/OpenSearch setup and usage
- **MCP Server:** `mcp_server/README.md` - Claude-integrated ES query tools
- **Assembly Scripts:** `assembly/assemble_report.sh` - Inventory merging

---

*Last updated: 2026-02-02*
