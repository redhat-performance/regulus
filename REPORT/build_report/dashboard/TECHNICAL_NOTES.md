# Technical Notes - Performance Benchmark Dashboard

**Last Updated:** November 21, 2025

This document contains technical implementation details, architectural patterns, and recent changes to help future development sessions quickly understand the codebase.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Key Implementation Patterns](#key-implementation-patterns)
3. [Chart Rendering System](#chart-rendering-system)
4. [Filter System](#filter-system)
5. [Recent Major Changes](#recent-major-changes)
6. [Critical Code Locations](#critical-code-locations)
7. [Common Tasks and Patterns](#common-tasks-and-patterns)

---

## Architecture Overview

### Data Flow

```
JSON Reports
    ↓
ReportLoader.load_from_directory()        [data_loader.py]
    ↓
BenchmarkResult[] (in-memory)
    ↓
BenchmarkAggregator                       [aggregator.py]
    ↓
Flask REST API Endpoints                  [dashboard_app.py]
    ↓
Frontend JavaScript (dashboard.js)
    ↓
Chart.js Visualizations
```

### Client-Side vs Server-Side Aggregation

**Important Decision:** Charts use **client-side aggregation** instead of server-side for file path tracking.

**Why:**
- Charts need to display source file paths in tooltips
- Charts need click-to-copy functionality for file paths
- Aggregation status ("aggregated" vs specific file) must be determined at render time

**Pattern:**
1. Fetch raw results from `/api/results` with filters
2. Aggregate on client side (JavaScript) while tracking file paths
3. Render charts with file path data embedded in datasets

---

## Key Implementation Patterns

### 1. File Path Tracking Pattern

**Location:** `dashboard.js` - Overview, Scale tabs

**Problem:** Charts show aggregated data but users need to know which report file each data point came from.

**Solution:**
```javascript
// During client-side aggregation
const grouped = {};
for (const result of filtered) {
    const key = result[groupBy];
    if (!grouped[key]) {
        grouped[key] = { means: [], filePaths: [] };
    }
    grouped[key].means.push(result.mean);
    if (result.file_path) {
        grouped[key].filePaths.push(result.file_path);
    }
}

// Determine aggregation status
const filePaths = {};
for (const [key, data] of Object.entries(grouped)) {
    // Single file: show actual path; Multiple files: show "aggregated"
    filePaths[key] = data.filePaths.length === 1
        ? data.filePaths[0]
        : 'aggregated';
}

// Pass to chart renderer
renderBarChart(canvasId, stats, title, xAxisLabel, yAxisLabel, filePaths);
```

**Chart Configuration:**
```javascript
// Embed file paths in dataset
datasets: [{
    label: 'Mean Performance',
    data: means,
    filePaths: filePathArray  // Custom property
}]

// Show in tooltip
tooltip: {
    callbacks: {
        afterLabel: function(context) {
            const filePath = filePathArray[context.dataIndex];
            return filePath === 'aggregated'
                ? 'Source: aggregated'
                : 'File: ' + filePath;
        }
    }
}

// Click-to-copy handler
onClick: (event, activeElements) => {
    if (activeElements.length > 0) {
        const index = activeElements[0].index;
        const filePath = filePathArray[index];
        if (filePath && filePath !== 'aggregated') {
            copyToClipboard(filePath, tempElement);
        }
    }
}
```

### 2. Label Separation Pattern (Chart Titles vs Axis Labels)

**Location:** `dashboard.js:584-669` (loadScaleChart function)

**Problem:** Chart titles should be clean (no units), but axes should show units for clarity.

**Solution:** Separate label mappings

```javascript
// For chart TITLES (no units)
const scaleByLabels = {
    'threads': 'Threads',
    'wsize': 'Wsize',              // Clean, no (Bytes)
    'pods_per_worker': 'ScaleUp',
    'scale_out_factor': 'ScaleOut'
};

// For AXIS labels (with units)
const scaleByAxisLabels = {
    'threads': 'Threads',
    'wsize': 'Wsize (Bytes)',      // Includes unit
    'pods_per_worker': 'ScaleUp',
    'scale_out_factor': 'ScaleOut'
};

const scaleLabel = scaleByLabels[scaleBy];        // For title
const scaleAxisLabel = scaleByAxisLabels[scaleBy]; // For axis

// Pass both to rendering functions
renderBarChart('scaleChart', perfStats, title, scaleAxisLabel, unitLabel, filePaths);
//                                                 ^^^^^^^^^^^^^^
//                                           Axis label has units
```

**Result:**
- Chart title: "Performance by Wsize" (clean)
- X-axis label: "Wsize (Bytes)" (informative)

### 3. Multi-Select Filter Pattern

**Location:** `dashboard.html` - Filter section, `dashboard.js` - getSelectValue()

**Implementation:**
```html
<!-- Multi-select filter (note the 'multiple' attribute) -->
<select class="form-select form-select-sm" id="filterModel" multiple size="3" onchange="applyFilters()">
</select>
```

```javascript
function getSelectValue(selectId) {
    const select = document.getElementById(selectId);
    if (select.hasAttribute('multiple')) {
        // Multi-select: return array of selected values
        return Array.from(select.selectedOptions).map(opt => opt.value);
    } else {
        // Single-select: return single value
        return select.value || '';
    }
}

// Build URL params
function buildFilterParams(additionalParams = {}) {
    const params = new URLSearchParams();
    const filters = getCurrentFilters();

    for (const [key, value] of Object.entries(filters)) {
        if (Array.isArray(value)) {
            // Multi-select: join with comma
            if (value.length > 0) {
                params.append(key, value.join(','));
            }
        } else if (value) {
            // Single-select: add if not empty
            params.append(key, value);
        }
    }
    return params;
}
```

**Current Multi-Select Filters:**
- Model (Datapath)
- NIC
- Arch

**Note:** Can be extended to other filters by adding `multiple size="3"` to the select element.

### 4. 2D Scaling Chart Pattern

**Location:** `dashboard.js:764-920` (loadScale2D function)

**Problem:** Need to show performance scaling across TWO dimensions simultaneously (e.g., Threads × ScaleUp).

**Solution:** Grouped bar chart with secondary dimension as legend

```javascript
// Detect 2D scaling: Secondary dimension filter must be "All" (empty)
const scaleUpFilter = getSelectValue('filterScaleUp');
let secondaryDim = null;

if (scaleBy !== 'pods_per_worker' && (!scaleUpFilter || scaleUpFilter === '')) {
    secondaryDim = 'pods_per_worker';
    secondaryDimField = 'ScaleUp';
}

// Group by BOTH dimensions
for (const result of filtered) {
    const primaryVal = result[primaryDim];
    const secondaryVal = result[secondaryDim];

    if (!grouped[primaryVal]) {
        grouped[primaryVal] = {};
    }
    if (!grouped[primaryVal][secondaryVal]) {
        grouped[primaryVal][secondaryVal] = { means: [], filePaths: [] };
    }
    grouped[primaryVal][secondaryVal].means.push(mean);
}

// Create one dataset per secondary dimension value
const datasets = secondaryValues.map((secVal, idx) => ({
    label: `${secondaryLabel}=${secVal}`,  // e.g., "ScaleUp=2"
    data: primaryValues.map(primVal => {
        // Calculate mean for this combination
        return grouped[primVal]?.[secVal]?.means.reduce((a,b)=>a+b,0) /
               grouped[primVal]?.[secVal]?.means.length || null;
    }),
    backgroundColor: colors[idx % colors.length]
}));
```

---

## Chart Rendering System

### Chart.js Configuration

**Global Settings:**
- Type: `'bar'` or `'line'`
- Responsive: `true`
- Maintain Aspect Ratio: `false` (allows flexible height)
- Plugins: ChartDataLabels (shows values on bars)

### Standard Bar Chart Template

**File:** `dashboard.js` - `renderBarChart()` function

```javascript
function renderBarChart(canvasId, statsData, title, xAxisLabel, yAxisLabel, filePaths = {}) {
    // Destroy existing chart
    if (charts[canvasId]) {
        charts[canvasId].destroy();
    }

    // Extract data and labels
    const labels = Object.keys(statsData);
    const means = labels.map(label => statsData[label].mean);
    const filePathArray = labels.map(label => filePaths[label] || 'aggregated');

    charts[canvasId] = new Chart(ctx, {
        type: 'bar',
        data: {
            labels: labels,
            datasets: [{
                label: 'Mean Performance',
                data: means,
                filePaths: filePathArray  // Custom property for file paths
            }]
        },
        options: {
            onClick: (event, activeElements) => { /* click-to-copy handler */ },
            plugins: {
                title: { display: true, text: title },
                tooltip: { callbacks: { afterLabel: /* show file path */ } },
                datalabels: {
                    anchor: 'end',
                    align: 'top',
                    formatter: (value) => value.toFixed(2)
                }
            },
            scales: {
                y: { beginAtZero: true, title: { text: yAxisLabel } },
                x: { title: { text: xAxisLabel } }
            }
        },
        plugins: [ChartDataLabels]  // Enable data labels
    });
}
```

### Grouped Bar Chart Template

**File:** `dashboard.js` - `renderGroupedBarChart()` function

Used for 2D scaling visualizations. Similar to renderBarChart but supports multiple datasets.

---

## Filter System

### Filter Architecture

**Frontend Filters:** `dashboard.html` lines 173-277
**Backend Filtering:** `dashboard_app.py` - `_apply_filters()` method

### Filter Fields and Types

| Field | Type | Backend Field | Notes |
|-------|------|---------------|-------|
| Benchmark | Single | `benchmark` | Test tool (uperf, iperf, etc.) |
| Datapath | Multi | `model` | OVNK, DPU, SRIOV, MACVLAN |
| NIC | Multi | `nic` | CX5, CX6, CX7, E810, E910 |
| Arch | Multi | `arch` | CPU architecture |
| Protocol | Single | `protocol` | tcp, udp |
| Test Type | Single | `test_type` | stream, rr, crr, bidirec, pps |
| CPU | Single | `cpu` | CPU model |
| Kernel | Single | `kernel` | Kernel version |
| RCOS | Single | `rcos` | RHCOS version |
| Topo | Single | `topo` | Topology |
| Perf | Single | `perf` | Performance profile |
| Offload | Single | `offload` | Offload settings |
| Threads | Single | `threads` | Thread count |
| ScaleUp | Single | `pods_per_worker` | Pods per worker |
| ScaleOut | Single | `scale_out_factor` | Scale out factor |
| Wsize | Single | `wsize` | Write size |
| Date Range | Single | `date_range_days` | Last N days |

### Unit Filtering Logic

**Problem:** Different test types use different units (Gbps vs transactions-sec vs pps).

**Solution:** Automatic unit filtering based on test type

```javascript
const testType = getSelectValue('filterTestType');
let unitFilter = null;
let unitLabel = 'Performance Metric';

if (testType === 'rr') {
    unitFilter = 'transactions-sec';
    unitLabel = 'Transactions per Second';
} else if (testType === 'crr') {
    unitFilter = 'connections-sec';
    unitLabel = 'Connections per Second';
} else if (testType === 'pps') {
    unitFilter = 'pps';
    unitLabel = 'Packets per Second';
} else if (testType === 'stream' || testType === 'bidirec') {
    unitFilter = 'Gbps';
    unitLabel = 'Throughput (Gbps)';
} else {
    // Default to Gbps
    unitFilter = 'Gbps';
    unitLabel = 'Throughput (Gbps)';
}

// Filter results
const filtered = results.filter(r => r.unit && r.unit.includes(unitFilter));
```

**Note:** Uses `.includes()` to match partial units like "tx-Gbps", "rx-Gbps", "sum-Gbps".

---

## Recent Major Changes

### Change 1: File Path Tracking on All Charts (Nov 21, 2025)

**Files Modified:**
- `dashboard.js` - Overview tab (loadOverviewData)
- `dashboard.js` - Scale tab (loadScale1D, loadScale2D)
- `dashboard.js` - renderBarChart, renderGroupedBarChart

**What Changed:**
- Switched from server-side `/api/statistics` to client-side aggregation
- Charts now track file paths during aggregation
- Added file path tooltips to all charts
- Added click-to-copy functionality for file paths
- File paths show "aggregated" when data comes from multiple reports

**Key Code Locations:**
- `dashboard.js:293-431` - loadOverviewData (client-side aggregation)
- `dashboard.js:673-762` - loadScale1D (1D scaling with file paths)
- `dashboard.js:765-920` - loadScale2D (2D scaling with file paths)

### Change 2: Chart Title and Axis Label Separation (Nov 21, 2025)

**Files Modified:**
- `dashboard.js:636-656` - Label mappings
- `dashboard.js:673` - loadScale1D function signature
- `dashboard.js:765` - loadScale2D function signature

**What Changed:**
- Separated title labels (clean, no units) from axis labels (with units)
- Chart titles no longer show "(Bytes)" or "(Gbps)"
- X/Y axis labels properly show units where appropriate

**Example:**
- Before: Title = "Performance by Wsize (Bytes) | Protocol=tcp"
- After: Title = "Performance by Wsize | Protocol=tcp", X-axis = "Wsize (Bytes)"

### Change 3: BusyCPU Unit Correction (Nov 21, 2025)

**Files Modified:**
- `dashboard.js:761` - loadScale1D BusyCPU chart
- `dashboard.js:919` - loadScale2D BusyCPU chart

**What Changed:**
- Changed y-axis label from "BusyCPU (%)" to "BusyCPU (num cpus)"

**Reason:** BusyCPU represents number of CPUs used, not a percentage.

### Change 4: 2D Scaling Support (Nov 2025)

**Files Added/Modified:**
- `dashboard.js:764-920` - loadScale2D function
- `dashboard.js:922-1034` - renderGroupedBarChart function
- `dashboard.js:614-656` - 2D detection logic

**What Changed:**
- Added automatic detection of 2D scaling scenarios
- Implemented grouped bar charts for 2D data
- Supports up to 2 dimensions (primary + secondary)
- Secondary dimension must have filter set to "All"

**Supported 2D Combinations:**
- Threads × ScaleUp
- Threads × Wsize
- ScaleUp × Wsize
- ScaleOut × any other dimension

---

## Critical Code Locations

### Frontend JavaScript (`dashboard.js`)

| Function | Lines | Purpose |
|----------|-------|---------|
| `loadOverviewData()` | 293-431 | Overview tab: Model/Kernel charts, Top Performers |
| `loadScaleChart()` | 584-669 | Scale tab controller, 1D/2D detection |
| `loadScale1D()` | 673-762 | 1D scaling charts (single dimension) |
| `loadScale2D()` | 765-920 | 2D scaling charts (two dimensions) |
| `renderBarChart()` | 434-552 | Standard bar chart renderer |
| `renderGroupedBarChart()` | 922-1034 | Grouped bar chart for 2D data |
| `buildChartTitleWithFilters()` | 186-236 | Dynamic chart titles with filter tags |
| `getCurrentFilters()` | 136-156 | Extract all filter values |
| `buildFilterParams()` | 159-184 | Build URL query params from filters |
| `copyToClipboard()` | 1410-1441 | Clipboard utility with visual feedback |

### Backend Python

| File | Key Functions | Purpose |
|------|---------------|---------|
| `dashboard_app.py` | `_setup_routes()` | All REST API endpoints |
| | `_apply_filters()` | Server-side filtering logic |
| | `_result_to_dict()` | BenchmarkResult → JSON |
| `data_loader.py` | `ReportLoader.load_from_directory()` | Load JSON reports |
| | `ReportFilter` class | Filter helper methods |
| `aggregator.py` | `BenchmarkAggregator` | Analytics and statistics |

---

## Common Tasks and Patterns

### Adding a New Filter

1. **Add HTML Select Element** (`dashboard.html`)
```html
<select class="form-select form-select-sm" id="filterNewField" onchange="applyFilters()">
    <option value="">All</option>
</select>
```

2. **Add to Filter Population** (`dashboard.js:56-85`)
```javascript
populateSelect('filterNewField', filterOptions.new_field || []);
```

3. **Add to getCurrentFilters()** (`dashboard.js:136-156`)
```javascript
return {
    // ... existing filters
    new_field: getSelectValue('filterNewField')
};
```

4. **Add to Backend Filter Params** (`dashboard_app.py` - all API endpoints)
```python
filter_params = {
    # ... existing params
    'new_field': request.args.get('new_field')
}
```

5. **Add to Filter Fields List** (`dashboard_app.py:409-413`)
```python
filter_fields = [
    # ... existing fields
    'new_field'
]
```

### Adding a New Chart

1. **Add Canvas to HTML** (`dashboard.html`)
```html
<canvas id="newChart"></canvas>
```

2. **Create Rendering Function** (`dashboard.js`)
```javascript
async function loadNewChart() {
    const params = buildFilterParams();
    const response = await fetch(`/api/new_endpoint?${params.toString()}`);
    const data = await response.json();
    renderBarChart('newChart', data, title, xLabel, yLabel);
}
```

3. **Add API Endpoint** (`dashboard_app.py`)
```python
@self.app.route('/api/new_endpoint')
def api_new_endpoint():
    # Filter results
    # Aggregate data
    # Return JSON
```

4. **Wire Up Tab/Button**
```javascript
document.getElementById('new-tab').addEventListener('shown.bs.tab', function() {
    loadNewChart();
});
```

### Debugging Chart Issues

**Chart not displaying:**
1. Check browser console (F12) for JavaScript errors
2. Verify canvas element exists: `document.getElementById('chartId')`
3. Check API response: `curl http://localhost:5000/api/endpoint`
4. Verify data format matches Chart.js expectations

**Wrong data displayed:**
1. Check filter params: `buildFilterParams()`
2. Verify backend filtering: Print `filtered` variable
3. Check aggregation logic: Ensure correct grouping

**File paths not showing:**
1. Ensure client-side aggregation (not server-side `/api/statistics`)
2. Verify `filePaths` array passed to chart renderer
3. Check tooltip callback implementation

---

## Important Conventions

### Naming Conventions

**Chart Canvas IDs:**
- Use descriptive names: `chartByModel`, `scaleChart`, `trendChart`
- Store in `charts` object: `charts[canvasId] = new Chart(...)`

**API Endpoints:**
- Use `/api/` prefix for all API routes
- Use query parameters for filters: `/api/results?model=OVNK&nic=CX7`

**Filter Field Names:**
- Frontend: `filterBenchmark`, `filterModel`, etc.
- Backend: `benchmark`, `model`, etc. (no "filter" prefix)
- Use underscore_case in backend: `pods_per_worker`
- Use camelCase in JavaScript: `podsPerWorker`

### Unit Display Rules

**Chart Titles:** No units (clean, concise)
**Axis Labels:** Include units in parentheses: "Wsize (Bytes)", "Throughput (Gbps)"
**Table Headers:** No units (unless ambiguous)
**Tooltip Values:** Show units: "95.3 Gbps", "2048 Bytes"

### BusyCPU Display

**Correct:** "BusyCPU (num cpus)"
**Incorrect:** "BusyCPU (%)"

**Reason:** The metric represents the number of CPUs utilized, not a percentage.

---

## Testing Checklist

When making changes, test these scenarios:

- [ ] Overview tab loads with multiple models/kernels
- [ ] Scale tab 1D: Threads, Wsize, ScaleUp, ScaleOut
- [ ] Scale tab 2D: Threads × ScaleUp, Wsize × ScaleUp
- [ ] Trends tab with grouping (Model, Kernel, Topo)
- [ ] Comparison tab with different field types
- [ ] Results table with filtering and sorting
- [ ] Multi-select filters (Model, NIC, Arch)
- [ ] Date range filter (7, 30, 90 days)
- [ ] Clear Filters button
- [ ] Reload Reports button
- [ ] File path tooltips show correctly
- [ ] Click-to-copy works for non-aggregated data points
- [ ] Charts show "aggregated" for multi-source data
- [ ] Chart titles exclude units
- [ ] Axis labels include units
- [ ] BusyCPU shows "num cpus" not "%"

---

## Future Considerations

### Potential Enhancements

1. **Backend Optimization**
   - Consider caching aggregated data for faster chart rendering
   - Implement pagination for large result sets
   - Add database backend for better query performance

2. **Frontend Improvements**
   - Add chart export (PNG, SVG, CSV)
   - Implement chart zoom/pan for large datasets
   - Add chart comparison mode (side-by-side)
   - Support custom date range picker

3. **Feature Additions**
   - Statistical significance testing for comparisons
   - Anomaly detection and highlighting
   - Regression analysis and trend lines
   - Custom calculated metrics

### Known Limitations

1. **Memory Usage:** All results loaded in memory (scales to ~10K results comfortably)
2. **Chart Performance:** Chart.js can slow down with >500 data points per chart
3. **Concurrent Users:** Flask dev server is single-threaded
4. **Real-time Updates:** Manual reload required (no WebSocket support)

---

## Quick Reference

### Start Dashboard
```bash
cd /home/user/CLAUDE-PROJOECTS/report-proj/regulus/REPORT/build_report
python3 dashboard/run_dashboard.py --reports dashboard/test_data
```

### Key Files
- Frontend JS: `dashboard/static/dashboard.js` (1459 lines)
- HTML Template: `dashboard/templates/dashboard.html` (500 lines)
- Backend App: `dashboard/dashboard_app.py` (542 lines)
- Data Loader: `dashboard/data_loader.py` (580 lines)
- Aggregator: `dashboard/aggregator.py` (442 lines)

### API Quick Test
```bash
curl http://localhost:5000/api/summary | python3 -m json.tool
curl http://localhost:5000/api/filters | python3 -m json.tool
curl "http://localhost:5000/api/results?model=SRIOV&nic=CX7" | python3 -m json.tool
```

---

**End of Technical Notes**
