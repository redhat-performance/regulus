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
├── makefile                   # Central REPORT operations (delegates to build_report/)
├── assembly/                  # Scripts to merge inventory data into reports
│   └── assemble_report.sh     # Main assembly script
├── build_report/              # Report generation and dashboard
│   ├── makefile               # Dashboard, flattening, and ElasticSearch operations
│   ├── build_report           # Main report generation script
│   ├── dashboard/             # Web dashboard application
│   │   ├── run_dashboard.py   # Flask dashboard server
│   │   ├── data_loader.py     # Report loading logic
│   │   ├── templates/         # HTML templates
│   │   ├── static/            # JS/CSS assets
│   │   └── test_data/         # Sample benchmark data (16 JSON files, 318 results)
│   └── es_integration/        # ElasticSearch integration
│       ├── ES-README.md       # Complete ElasticSearch user guide
│       ├── README.md          # Technical implementation notes
│       ├── flatten_to_es.py   # Convert reports to NDJSON format
│       └── es_mapping_template.json
└── docker/                    # Docker-related files for containerized the dashboard
```

---

## Makefile Architecture

The reporting system uses a **three-level makefile delegation pattern**:

```
Root makefile (regulus/)
    ↓ delegates to
REPORT/makefile
    ↓ delegates to
REPORT/build_report/makefile
```

### Key Differences by Level

| Aspect | Root makefile | REPORT/makefile | build_report/makefile |
|--------|---------------|-----------------|----------------------|
| **Prefix** | `report-*` targets | No prefix | No prefix |
| **Purpose** | Convenience wrappers | Orchestration with REG_ROOT | Implementation details |
| **Data Context** | Production (regulus/) | Production (REG_ROOT) | Test data by default |
| **Example** | `make report-dashboard` | `make dashboard` | `make dashboard` |

---

## Target Reference

### Location-Dependent Targets

Some targets behave **differently** depending on where they're invoked:

#### 1. Dashboard Targets

| Command | Working Directory | Reports Directory | Data Type | # Files | # Results |
|---------|------------------|-------------------|-----------|---------|-----------|
| `make dashboard` | `REPORT/build_report/` | `dashboard/test_data/` | Test/Mock | 16 | 318 |
| `make dashboard` | `REPORT/` | `$(REG_ROOT)` = `../` | Production | Varies | Varies |
| `make report-dashboard` | `regulus/` (root) | `regulus/` | Production | Varies | Varies |

**Why the difference?**
- `build_report/Makefile` sets `REPORTS_DIR ?= $(TEST_DATA_DIR)` (defaults to test data)
- `REPORT/Makefile` passes `REPORTS_DIR=$(REG_ROOT)` (production data)
- Root makefile delegates to `REPORT/Makefile`

**Example usage:**
```bash
# Start dashboard with test data (for development)
cd REPORT/build_report
make dashboard

# Start dashboard with production data
cd REPORT
make dashboard

# Or from root
cd regulus
make report-dashboard
```

#### 2. Flatten Targets

| Command | Working Directory | Input | Output | Purpose |
|---------|------------------|-------|--------|---------|
| `make flatten-test` | `REPORT/build_report/` | `test_data/*.json` | `/tmp/test_reports.ndjson` | Test ES format |
| `make flatten` | `REPORT/build_report/` | `REPORTS_DIR` | `OUTPUT_DIR/reports.ndjson` | Custom flatten |
| `make flatten` | `REPORT/` | `$(REG_ROOT)` | `$(REG_ROOT)/reports.ndjson` | Production flatten |
| `make report-flatten` | `regulus/` (root) | `regulus/` | `regulus/reports.ndjson` | Production flatten |

**Example usage:**
```bash
# Flatten test data (quick validation)
cd REPORT/build_report
make flatten-test

# Flatten production data
cd regulus
make report-flatten

# Flatten custom directory
cd REPORT/build_report
make flatten REPORTS_DIR=/path/to/reports OUTPUT_DIR=/output/path
```

#### 3. ElasticSearch Upload Targets

| Command | Working Directory | Data Source | ES Index | Purpose |
|---------|------------------|-------------|----------|---------|
| `make es-upload` | `REPORT/build_report/` | `REPORTS_DIR` (test) | `benchmark-results` | Upload test |
| `make es-upload` | `REPORT/` | `$(REG_ROOT)` | `$(ES_INDEX)` | Upload prod |
| `make report-es-upload` | `regulus/` (root) | `regulus/` | `$(ES_INDEX)` | Upload prod |

**Example usage:**
```bash
# Upload test data to ElasticSearch
cd REPORT/build_report
make es-upload ES_HOST=localhost:9200

# Upload production data
cd regulus
make report-es-upload ES_HOST=prod-es:9200 ES_INDEX=my-benchmarks
```

### Location-Independent Targets

These targets produce the **same behavior** regardless of where they're called:

#### Report Generation

| Target | Root | REPORT/ | build_report/ | Description |
|--------|------|---------|---------------|-------------|
| `report-summary` | ✓ | - | - | Generate report.json, HTML, CSV |
| `summary` | - | ✓ | - | Generate report.json, HTML, CSV |
| `report-summary-with-testbed-info` | ✓ | - | - | Generate report with inventory data |
| `summary-with-testbed-info` | - | ✓ | - | Generate report with inventory data |

**Example usage:**
```bash
# From root
cd regulus
make report-summary

# From REPORT/
cd REPORT
make summary

# With testbed/inventory information
cd regulus
make report-summary-with-testbed-info
```

#### Dashboard Management

| Target | Root | REPORT/ | build_report/ | Description |
|--------|------|---------|---------------|-------------|
| `report-dashboard-stop` | ✓ | - | - | Stop all dashboard instances |
| `dashboard-stop` | - | ✓ | ✓ | Stop all dashboard instances |
| `report-dashboard-restart` | ✓ | - | - | Restart dashboard |
| `dashboard-restart` | - | ✓ | ✓ | Restart dashboard |

**Example usage:**
```bash
# Stop dashboard from anywhere
make dashboard-stop    # or make report-dashboard-stop from root

# Restart dashboard
make dashboard-restart
```

#### ElasticSearch Operations

| Target | Root | REPORT/ | build_report/ | Description |
|--------|------|---------|---------------|-------------|
| `es-check` | - | ✓ | ✓ | Verify ES connection |
| `es-template` | - | ✓ | ✓ | Apply ES index template |
| `report-es-full` | ✓ | - | - | Complete ES workflow (generate → flatten → upload) |
| `es-full` | - | ✓ | - | Complete ES workflow |

---

## Understanding Data Contexts

### Test Data (Mock Data)

**Location:** `REPORT/build_report/dashboard/test_data/`

**Characteristics:**
- 16 JSON files with mock benchmark results
- 318 total benchmark iterations
- Contains diverse scenarios for testing dashboard features
- Safe for development and testing

**When to use:**
- Dashboard development and testing
- Validating new features
- Learning the system
- ES format validation

**How to use:**
```bash
cd REPORT/build_report
make dashboard              # View test data in dashboard
make flatten-test           # Convert to ES format
make es-setup              # Upload to test ES instance
```

### Production Data (Real Benchmarks)

**Location:** `regulus/` (or wherever benchmark results are generated)

**Characteristics:**
- Real benchmark results from actual test runs
- Number of files and results varies based on what's been run
- Contains actual performance data from your infrastructure

**When to use:**
- Analyzing real benchmark results
- Generating production reports
- Publishing results to ElasticSearch
- Creating final HTML/CSV reports

**How to use:**
```bash
cd regulus
make report-summary                        # Generate report
make report-dashboard                      # View in dashboard
make report-es-full ES_HOST=prod-es:9200   # Upload to production ES
```

---

## Common Workflows

### 1. Generate a Quick Report

```bash
cd regulus
make report-summary

# Outputs:
# - report.json      (machine-readable, unflatten format)
# - reports.ndjson   (flatten NDJSON for ElasticSearch)
# - report.html      (human-readable)
# - report.csv       (spreadsheet-friendly)
```

**Note:** The `summary` target now generates BOTH unflatten (report.json) and flatten (reports.ndjson) outputs in one step, ensuring the flatten input is always the just-created report.json (safe and predictable).

### 2. Generate Report with Testbed Information

```bash
cd regulus
make report-summary-with-testbed-info

# Merges inventory data (CPU, RAM, NIC details) into report.json
# Uses assembly/assemble_report.sh
```

### 3. View Reports Interactively

```bash
# Option 1: View test data (development)
cd REPORT/build_report
make dashboard
# Open http://localhost:5000

# Option 2: View production data
cd regulus
make report-dashboard
# Open http://localhost:5000
```

### 4. Upload to ElasticSearch (Complete Workflow)

```bash
cd regulus

# Set environment variables (optional, defaults shown)
export ES_HOST=localhost:9200
export ES_INDEX=regulus-results

# Run complete workflow
make report-es-full

# This runs:
# 1. make report-summary         (generate report.json + reports.ndjson)
# 2. make es-template             (apply ES index template)
# 3. make es-upload               (upload to ES)
```

**Note:** The `summary` target now generates both report.json and reports.ndjson, so there's no separate flatten step needed.

For detailed ElasticSearch documentation, see `REPORT/build_report/es_integration/ES-README.md`.

### 5. Development: Test Dashboard Changes

```bash
cd REPORT/build_report

# Edit dashboard files
vim dashboard/templates/index.html
vim dashboard/static/dashboard.js

# Restart dashboard with test data
make dashboard-restart

# View at http://localhost:5000
```

### 6. Validate ElasticSearch Format

```bash
cd REPORT/build_report

# Flatten test data
make flatten-test

# View NDJSON output
head -20 /tmp/test_reports.ndjson

# Create human-readable version
make flatten-pretty
cat /tmp/test_reports_pretty.json
```

---

## Configuration Variables

### REPORT/makefile

| Variable | Default | Description |
|----------|---------|-------------|
| `REG_ROOT` | `$(shell cd .. && pwd)` | Root directory of regulus project |
| `ES_HOST` | `localhost:9200` | ElasticSearch host:port |
| `ES_INDEX` | `regulus-results` | ElasticSearch index name |

### build_report/makefile

| Variable | Default | Description |
|----------|---------|-------------|
| `REPORTS_DIR` | `$(TEST_DATA_DIR)` | Directory containing JSON reports |
| `OUTPUT_DIR` | `/tmp` | Output directory for generated files |
| `ES_HOST` | `localhost:9200` | ElasticSearch host:port |
| `ES_INDEX` | `regulus-results` | ElasticSearch index name |
| `ES_USER` | (empty) | ElasticSearch username (optional) |
| `ES_PASSWORD` | (empty) | ElasticSearch password (optional) |

### Overriding Variables

```bash
# Example: Dashboard with custom reports directory
cd REPORT/build_report
make dashboard REPORTS_DIR=/custom/path/to/reports

# Example: Upload to custom ES instance
cd regulus
make report-es-upload \
  ES_HOST=prod-es.example.com:9200 \
  ES_INDEX=prod-benchmarks \
  ES_USER=admin \
  ES_PASSWORD=secret
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

**Possible causes:**
1. No `*.json` files in the reports directory
2. JSON files are named `*_schema.json` (these are filtered out)
3. Dashboard is looking in the wrong directory

**Check:**
```bash
# See where dashboard is looking
make dashboard  # Check the output for "Loading reports from: ..."

# Verify JSON files exist
ls -la dashboard/test_data/*.json  # For test data
ls -la report*.json                # For production data
```

### Understanding File Count Differences

If dashboard shows fewer reports than expected, remember:
- Files named `*_schema.json` are intentionally excluded
- Each `report.json` can contain multiple benchmark iterations
- "Loaded Reports" = number of JSON files
- "Total Results" = number of benchmark iterations across all files

---

## Quick Reference

```bash
# From regulus/ (root):
make report-summary                         # Generate report
make report-summary-with-testbed-info       # Generate with inventory
make report-dashboard                       # View in browser (production)
make report-dashboard-stop                  # Stop dashboard
make report-flatten                         # Convert to NDJSON
make report-es-full                         # Upload to ElasticSearch

# From REPORT/:
make summary                                # Generate report
make summary-with-testbed-info              # Generate with inventory
make dashboard                              # View in browser (production)
make flatten                                # Convert to NDJSON
make es-full                                # Upload to ElasticSearch

# From REPORT/build_report/:
make dashboard                              # View test data
make flatten-test                           # Flatten test data
make flatten-pretty                         # Human-readable JSON
make es-setup                               # Setup test ES instance
make test                                   # Run validation tests
```

---

## Additional Documentation

- **ElasticSearch Integration:** See `build_report/es_integration/ES-README.md` - Complete guide for ES setup, upload, and management
- **Dashboard Development:** See `build_report/dashboard/README.md` and related docs
- **Report Generation:** See `build_report/README.md`
- **Assembly Scripts:** See `assembly/assemble_report.sh`

---

*Last updated: 2026-01-24*
