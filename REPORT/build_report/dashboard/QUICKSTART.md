# Dashboard Quick Start Guide

Get the performance dashboard up and running in 3 simple steps!

## Prerequisites

- Python 3.6+
- Flask 2.0+

## Step 1: Install Dependencies

```bash
# Install Flask
pip install flask

# Or install from requirements file
cd dashboard
pip install -r requirements.txt
```

**Verify Installation:**
```bash
python3 -c "import flask; print('Flask', flask.__version__, 'installed!')"
```

## Step 2: Generate Some Reports

First, generate JSON reports using the build_report tool:

```bash
# Navigate to your test results directory
cd $REG_ROOT

# Generate JSON reports
build_report/build_report --formats json --output my-report

# This creates: my-report.json
```

Repeat this for multiple test runs to have more data to visualize.

## Step 3: Launch the Dashboard

**Recommended Method:**
```bash
# From the build_report directory
cd /path/to/build_report
python3 dashboard/run_dashboard.py --reports /path/to/reports

# Example:
cd /home/hnhan/CLAUDE-PROJOECTS/report-proj/regulus/REPORT/build_report
python3 dashboard/run_dashboard.py --reports /tmp/reports
```

**Alternative - Using the launcher script:**
```bash
./dashboard/launch_dashboard --reports /tmp/reports
```

**Command-line Options:**
```bash
--reports DIR    # Directory containing JSON reports (default: current directory)
--port PORT      # Port to use (default: 5000)
--host HOST      # Host to bind (default: 0.0.0.0)
--debug          # Enable debug mode with auto-reload
```

## Step 4: Open Your Browser

The dashboard will show you the URL when it starts:

```
============================================================
Starting Performance Dashboard
============================================================
Dashboard URL: http://0.0.0.0:5000
Reports directory: /tmp/reports
Template directory: .../dashboard/templates
Static directory: .../dashboard/static
Loaded reports: 2
Total results: 15
============================================================
```

**Access the dashboard at:**
- **http://localhost:5000** (from the same machine)
- **http://YOUR_SERVER_IP:5000** (from another machine on the network)
- Example: http://10.26.9.237:5000

**What You'll See:**
- Summary statistics cards at the top (Reports, Results, Benchmarks, Date Range)
- Interactive charts showing performance by model and kernel
- Tabs for different views (Overview, Trends, Comparison, Results)
- Filter controls to narrow down data

## Using the Dashboard

### Filtering Data

Use the filter dropdowns to narrow down results:
- **Benchmark**: Filter by uperf, iperf, or trafficgen
- **Model**: Filter by network adapter model
- **Kernel**: Filter by kernel version
- **Topology**: Filter by network topology
- **Performance**: Filter by performance baseline

### Viewing Trends

1. Click the **Trends** tab
2. Select a grouping option (Model, Kernel, or Topology)
3. View the time-series chart showing performance over time

### Comparing Configurations

1. Click the **Comparison** tab
2. Select what to compare (Model, Kernel, Topology, or Performance)
3. Choose two values to compare
4. Click **Compare** to see the results

### Browsing All Results

1. Click the **Results Table** tab
2. Use the search box to find specific results
3. Click column headers to sort
4. Use pagination to browse through results

## Example Workflow

### Scenario: Compare two network adapter models

```bash
# 1. Generate reports for both models
cd /data/e810-tests
build_report/build_report --formats json --output e810-report

cd /data/e910-tests
build_report/build_report --formats json --output e910-report

# 2. Copy both reports to a common directory
mkdir /tmp/comparison-reports
cp /data/e810-tests/e810-report.json /tmp/comparison-reports/
cp /data/e910-tests/e910-report.json /tmp/comparison-reports/

# 3. Launch dashboard
./launch_dashboard --reports /tmp/comparison-reports
```

Now in the dashboard:
1. Go to **Comparison** tab
2. Select "Model" as compare field
3. Select "e810" as Value A
4. Select "e910" as Value B
5. Click **Compare**

You'll see a side-by-side comparison with percentage difference!

### Scenario: Track performance regression over time

```bash
# 1. Generate reports from multiple test runs over different dates
# (Reports automatically include timestamp from generation_info)

# 2. Put all reports in one directory
ls /data/historical-reports/
# week1-report.json
# week2-report.json
# week3-report.json
# week4-report.json

# 3. Launch dashboard
./launch_dashboard --reports /data/historical-reports

# 4. In the dashboard:
#    - Go to Trends tab
#    - Select "Group by Kernel" or "No Grouping"
#    - View the time-series chart
```

## Troubleshooting

### "No reports found"
- Make sure you've generated reports with `--formats json`
- Check that JSON files are in the specified directory
- Schema files (`*_schema.json`) are automatically ignored

### "Address already in use"
- Another service is using port 5000
- Use a different port: `./launch_dashboard --port 8080`

### Empty charts
- Check that reports contain data
- Apply filters to narrow down to specific benchmark type
- Click "Reload Reports" to refresh data

### Flask not found
- Install Flask: `pip install flask`
- Use Python 3.9 or higher

## Tips

- **Multiple Reports**: The dashboard works best with multiple reports to compare
- **Date Range**: Reports include timestamps for trend analysis
- **Filters**: Filters persist across tabs
- **Reload**: Use "Reload Reports" button to update data without restarting
- **API Access**: All data is available via REST API endpoints (see README.md)

## Next Steps

- Read the full [README.md](README.md) for detailed documentation
- Explore API endpoints for programmatic access
- Check out the comparison and trend analysis features
- Filter and drill down into specific test configurations

Enjoy analyzing your performance benchmarks!
