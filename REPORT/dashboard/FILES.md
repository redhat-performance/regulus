# Dashboard Files Reference

Complete reference of all files in the dashboard directory.

## Directory Structure

```
dashboard/
├── __init__.py              # Package initialization
├── data_loader.py           # JSON report loading and parsing
├── aggregator.py            # Analytics and aggregation engine
├── dashboard_app.py         # Flask web application
├── run_dashboard.py         # CLI entry point
├── launch_dashboard         # Bash launcher script
├── requirements.txt         # Python dependencies
├── static/
│   └── dashboard.js         # Frontend JavaScript
├── templates/
│   └── dashboard.html       # Dashboard HTML template
└── docs/
    ├── README.md            # Main documentation
    ├── QUICKSTART.md        # Quick start guide
    ├── USAGE_GUIDE.md       # Comprehensive usage guide
    ├── CHANGELOG.md         # Version history
    └── FILES.md             # This file
```

## Core Python Modules

### `__init__.py`
**Purpose:** Package initialization and exports
**Exports:**
- `DashboardApp`
- `create_app`
- `ReportLoader`
- `ReportFilter`
- `BenchmarkResult`
- `BenchmarkAggregator`

**Usage:**
```python
from dashboard import create_app, ReportLoader
```

---

### `data_loader.py` (348 lines)
**Purpose:** Load and parse JSON reports

**Classes:**
- `BenchmarkResult` - Single test iteration result
  - Fields: file_path, benchmark, iteration_id, model, kernel, mean, etc.

- `ReportMetadata` - Report file metadata
  - Fields: file_path, total_results, benchmarks, timestamp, etc.

- `ReportLoader` - Main loader class
  - `load_report(path)` - Load single report
  - `load_multiple_reports(paths)` - Load multiple reports
  - `load_from_directory(dir, pattern)` - Load all reports from directory
  - `extract_benchmark_results(report)` - Extract flattened results
  - `extract_all_results()` - Get all results from loaded reports
  - `get_summary_stats()` - Overall statistics

- `ReportFilter` - Filter benchmark results
  - `filter_by_benchmark(results, benchmark)` - Filter by type
  - `filter_by_tag(results, tag_name, tag_value)` - Filter by tag
  - `filter_by_date_range(results, start, end)` - Filter by date
  - `get_unique_values(results, field)` - Get unique field values

**Dependencies:** None (standard library only)

**Usage:**
```python
from data_loader import ReportLoader

loader = ReportLoader()
loader.load_from_directory('/tmp/reports')
results = loader.extract_all_results()
```

---

### `aggregator.py` (292 lines)
**Purpose:** Analytics and statistical aggregations

**Classes:**
- `TrendDataPoint` - Single trend data point
  - Fields: timestamp, mean, stddev, count, label

- `ComparisonResult` - Comparison result
  - Fields: config_a, config_b, metric, mean_a, mean_b, difference, percent_change, better

- `BenchmarkAggregator` - Main aggregation engine
  - `get_trend_over_time(metric, group_by, benchmark)` - Time-series trends
  - `compare_configurations(field, value_a, value_b, metric, benchmark)` - Compare two configs
  - `get_statistics_by_group(group_by, metric, benchmark)` - Grouped statistics
  - `get_top_performers(metric, top_n, benchmark, ascending)` - Top N results
  - `get_configuration_matrix(field_x, field_y, metric, benchmark)` - 2D matrix
  - `get_benchmark_summary()` - Overall summary
  - `filter_results(**kwargs)` - Filter with multiple criteria

**Dependencies:** `data_loader.BenchmarkResult`

**Usage:**
```python
from aggregator import BenchmarkAggregator

agg = BenchmarkAggregator(results)
trends = agg.get_trend_over_time(metric='mean', group_by='model')
comparison = agg.compare_configurations('model', 'e810', 'e910')
```

---

### `dashboard_app.py` (320 lines)
**Purpose:** Flask web application with REST API

**Classes:**
- `DashboardApp` - Main application class
  - `__init__(reports_dir, host, port)` - Initialize app
  - `load_reports(reports_dir)` - Load reports from directory
  - `run(debug)` - Start Flask server
  - `_setup_routes()` - Configure API endpoints
  - `_result_to_dict(result)` - Convert result to JSON

**Functions:**
- `create_app(reports_dir, host, port)` - Factory function

**Routes:**
- `GET /` - Dashboard HTML page
- `GET /api/summary` - Summary statistics
- `GET /api/results` - All results (filterable)
- `GET /api/trends` - Time-series trends
- `GET /api/compare` - Configuration comparison
- `GET /api/statistics` - Grouped statistics
- `GET /api/top_performers` - Top N results
- `GET /api/matrix` - Configuration matrix
- `GET /api/filters` - Available filter values
- `POST /api/reload` - Reload reports

**Dependencies:**
- Flask
- `data_loader`
- `aggregator`

**Usage:**
```python
from dashboard_app import create_app

app = create_app(reports_dir='/tmp/reports')
app.run()
```

---

### `run_dashboard.py` (106 lines)
**Purpose:** CLI entry point

**Features:**
- Command-line argument parsing
- Directory validation
- JSON file detection
- User confirmation prompts
- Error handling

**Arguments:**
- `--reports DIR` - Reports directory (default: current)
- `--host HOST` - Host to bind (default: 0.0.0.0)
- `--port PORT` - Port to use (default: 5000)
- `--debug` - Enable debug mode

**Usage:**
```bash
python3 run_dashboard.py --reports /tmp/reports --port 8080
```

---

## Scripts

### `launch_dashboard`
**Purpose:** Bash wrapper script
**Lines:** 15

**Features:**
- Sets PYTHONPATH automatically
- Passes arguments to run_dashboard.py
- Works from any directory

**Usage:**
```bash
./launch_dashboard --reports /tmp/reports
```

---

## Frontend Files

### `templates/dashboard.html` (345 lines)
**Purpose:** Main dashboard UI template

**Sections:**
- Head: CSS imports (Bootstrap, DataTables)
- Navigation bar with reload button
- Summary statistics cards (4 cards)
- Filter controls (5 dropdowns + clear button)
- Tab navigation (4 tabs)
- Tab content:
  - Overview: Charts and top performers table
  - Trends: Time-series chart with grouping
  - Comparison: Side-by-side comparison form
  - Results: Searchable/sortable table
- Loading overlay
- Script imports: Bootstrap, jQuery, DataTables, Chart.js, custom JS

**Technologies:**
- Bootstrap 5.3.0 (styling, components)
- Chart.js 4.4.0 (charts)
- DataTables 1.13.6 (tables)
- jQuery 3.7.0 (required by DataTables)

---

### `static/dashboard.js` (507 lines)
**Purpose:** Frontend JavaScript logic

**Functions:**
- `loadSummary()` - Load summary statistics
- `loadFilters()` - Load filter options
- `applyFilters()` - Apply global filters
- `clearFilters()` - Reset all filters
- `loadOverviewData()` - Load overview charts and tables
- `loadTrends()` - Load trend chart data
- `runComparison()` - Execute comparison
- `loadResultsTable()` - Load results table
- `renderBarChart()` - Render bar chart
- `renderTrendChart()` - Render time-series chart
- `renderComparisonResults()` - Show comparison results
- `renderTopPerformersTable()` - Populate top performers table
- `renderResultsTable()` - Populate results table with DataTables
- `reloadReports()` - Reload data via API
- `showLoading()` / `hideLoading()` - Loading overlay control
- `populateSelect()` - Populate dropdown options
- `updateComparisonOptions()` - Update comparison value dropdowns

**Global Variables:**
- `allResults` - All loaded results
- `filteredResults` - Currently filtered results
- `filterOptions` - Available filter values
- `charts` - Chart.js instances

**Event Handlers:**
- Page load: Initialize dashboard
- Filter change: Apply filters
- Tab change: Load tab-specific data
- Comparison field change: Update value options

---

## Documentation

### `README.md` (400+ lines)
**Purpose:** Complete feature and API documentation

**Sections:**
1. Features overview
2. Quick start guide
3. Command-line options
4. Dashboard views (4 tabs)
5. Filters and usage
6. API endpoints (8 endpoints with examples)
7. Architecture details
8. Development guide
9. Dependencies
10. Troubleshooting (comprehensive)
11. Performance notes
12. Future enhancements

**Audience:** Developers and users

---

### `QUICKSTART.md` (200+ lines)
**Purpose:** Step-by-step getting started guide

**Sections:**
1. Prerequisites
2. Installation steps
3. Launching dashboard
4. Using the interface
5. Common workflows (3 examples)
6. Troubleshooting tips

**Audience:** First-time users

---

### `USAGE_GUIDE.md` (500+ lines)
**Purpose:** Comprehensive usage documentation

**Sections:**
1. Getting started
2. Dashboard interface walkthrough
3. Detailed tab documentation
4. Common workflows (4 examples)
5. Complete API reference
6. Tips and tricks (8 tips)
7. Best practices

**Audience:** Regular users and advanced users

---

### `CHANGELOG.md` (200+ lines)
**Purpose:** Version history and release notes

**Sections:**
1. Version 1.0.0 release notes
2. Features added
3. Fixes applied
4. Technical details
5. Known limitations
6. Future enhancements
7. Credits

**Audience:** Developers and maintainers

---

### `FILES.md`
**Purpose:** This document - complete file reference

**Audience:** Developers

---

## Configuration Files

### `requirements.txt`
**Purpose:** Python package dependencies

**Contents:**
```
Flask>=2.3.0
```

**Usage:**
```bash
pip install -r requirements.txt
```

---

## File Statistics

| Category | Files | Total Lines |
|----------|-------|-------------|
| Python Core | 4 | ~1,066 |
| Python CLI | 2 | ~121 |
| Frontend | 2 | ~852 |
| Documentation | 5 | ~1,400+ |
| Configuration | 1 | ~5 |
| **Total** | **14** | **~3,444+** |

### Lines of Code Breakdown
- **Backend (Python)**: ~1,187 lines
- **Frontend (HTML/JS)**: ~852 lines
- **Documentation**: ~1,400+ lines
- **Code-to-Docs Ratio**: 1:0.7 (well-documented)

---

## File Dependencies

```
run_dashboard.py
    └── dashboard_app.py
            ├── data_loader.py
            └── aggregator.py
                    └── data_loader.py

dashboard.html
    └── dashboard.js
```

---

## Import Map

```python
# Package exports
dashboard/__init__.py
    ├── DashboardApp (from dashboard_app)
    ├── create_app (from dashboard_app)
    ├── ReportLoader (from data_loader)
    ├── ReportFilter (from data_loader)
    ├── BenchmarkResult (from data_loader)
    └── BenchmarkAggregator (from aggregator)

# Internal imports
dashboard_app.py
    ├── from data_loader import ReportLoader, ReportFilter, BenchmarkResult
    └── from aggregator import BenchmarkAggregator

aggregator.py
    └── from data_loader import BenchmarkResult

data_loader.py
    └── (no dashboard imports, uses stdlib only)
```

---

## Testing Files

**Note:** No unit tests included in v1.0.0

Sample test structure for future:
```
tests/
├── test_data_loader.py
├── test_aggregator.py
├── test_dashboard_app.py
└── fixtures/
    └── sample_reports/
```

---

## Maintenance

### Adding New Features

1. **New Data Field**: Update `BenchmarkResult` in `data_loader.py`
2. **New Aggregation**: Add method to `BenchmarkAggregator` in `aggregator.py`
3. **New API Endpoint**: Add route in `dashboard_app.py`
4. **New Chart**: Add function in `dashboard.js` and HTML in `dashboard.html`

### Code Style
- Python: PEP 8
- JavaScript: Standard JS conventions
- Documentation: Markdown

### Version Control
- Update `CHANGELOG.md` for each change
- Tag releases with version numbers
- Keep documentation in sync with code

---

## Quick Reference

**Most Important Files:**
1. `run_dashboard.py` - Start here
2. `dashboard_app.py` - Core application
3. `data_loader.py` - Data processing
4. `README.md` - Main documentation
5. `QUICKSTART.md` - Getting started

**For Development:**
- Backend: `data_loader.py`, `aggregator.py`, `dashboard_app.py`
- Frontend: `dashboard.html`, `dashboard.js`
- CLI: `run_dashboard.py`

**For Users:**
- `QUICKSTART.md` - Getting started
- `USAGE_GUIDE.md` - How to use
- `README.md` - Reference

**For Troubleshooting:**
- `README.md` - Troubleshooting section
- `CHANGELOG.md` - Known issues
- Startup output - Shows paths and diagnostics
