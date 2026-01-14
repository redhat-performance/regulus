/**
 * Dashboard JavaScript - Interactive charts and data loading
 */

// Global variables
let allResults = [];
let filteredResults = [];
let filterOptions = {};
let charts = {};

// Initialize dashboard on page load
document.addEventListener('DOMContentLoaded', function() {
    console.log('Dashboard initializing...');
    loadSummary();
    loadFilters();
    loadOverviewData();

    // Setup comparison field change handler
    document.getElementById('compareField').addEventListener('change', updateComparisonOptions);
});

// Show/hide loading overlay
function showLoading() {
    document.getElementById('loadingOverlay').style.display = 'block';
}

function hideLoading() {
    document.getElementById('loadingOverlay').style.display = 'none';
}

// Load summary statistics with optional filters
async function loadSummary() {
    try {
        // Pass current filters to summary endpoint
        const params = buildFilterParams();
        const response = await fetch(`/api/summary?${params.toString()}`);
        const data = await response.json();

        // Update summary cards
        document.getElementById('totalReports').textContent = data.reports.total_reports || 0;
        document.getElementById('totalResults').textContent = data.reports.total_iterations || 0;
        document.getElementById('totalBenchmarks').textContent = data.reports.benchmarks.length || 0;

        // Format date range
        if (data.reports.date_range) {
            const start = new Date(data.reports.date_range.earliest).toLocaleDateString();
            const end = new Date(data.reports.date_range.latest).toLocaleDateString();
            document.getElementById('dateRange').textContent = start === end ? start : `${start} - ${end}`;
        } else {
            document.getElementById('dateRange').textContent = 'N/A';
        }
    } catch (error) {
        console.error('Error loading summary:', error);
    }
}

// Load available filters
async function loadFilters() {
    try {
        const response = await fetch('/api/filters');
        filterOptions = await response.json();

        // Populate filter dropdowns - Row 1
        populateSelect('filterBenchmark', filterOptions.benchmark || []);
        populateSelect('filterModel', filterOptions.model || []);
        populateSelect('filterNic', filterOptions.nic || []);
        populateSelect('filterArch', filterOptions.arch || []);
        populateSelect('filterProtocol', filterOptions.protocol || []);
        populateSelect('filterTestType', filterOptions.test_type || []);
        populateSelect('filterCpu', filterOptions.cpu || []);

        // Populate filter dropdowns - Row 2
        populateSelect('filterKernel', filterOptions.kernel || []);
        populateSelect('filterRcos', filterOptions.rcos || []);
        populateSelect('filterTopo', filterOptions.topo || []);
        populateSelect('filterPerf', filterOptions.perf || []);
        populateSelect('filterOffload', filterOptions.offload || []);

        // Populate filter dropdowns - Row 3
        populateSelect('filterThreads', filterOptions.threads || []);
        populateSelect('filterScaleUp', filterOptions.pods_per_worker || []);
        populateSelect('filterScaleOut', filterOptions.scale_out_factor || []);
        populateSelect('filterWsize', filterOptions.wsize || []);

        // Setup event listeners for dynamic filter updates
        setupDynamicFilters();
    } catch (error) {
        console.error('Error loading filters:', error);
    }
}

// Setup event listeners for cascading/dynamic filters
function setupDynamicFilters() {
    const filterIds = [
        'filterBenchmark', 'filterModel', 'filterNic', 'filterArch',
        'filterProtocol', 'filterTestType', 'filterCpu', 'filterKernel',
        'filterRcos', 'filterTopo', 'filterPerf', 'filterOffload',
        'filterThreads', 'filterScaleUp', 'filterScaleOut', 'filterWsize'
    ];

    filterIds.forEach(id => {
        const element = document.getElementById(id);
        if (element) {
            element.addEventListener('change', updateDynamicFilters);
        }
    });
}

// Update filter options based on current selections (cascading filters)
async function updateDynamicFilters() {
    try {
        const params = buildFilterParams();
        const response = await fetch(`/api/dynamic_filters?${params.toString()}`);
        const dynamicOptions = await response.json();

        // Update each filter dropdown with new options
        populateSelect('filterBenchmark', dynamicOptions.benchmark || []);
        populateSelect('filterModel', dynamicOptions.model || []);
        populateSelect('filterNic', dynamicOptions.nic || []);
        populateSelect('filterArch', dynamicOptions.arch || []);
        populateSelect('filterProtocol', dynamicOptions.protocol || []);
        populateSelect('filterTestType', dynamicOptions.test_type || []);
        populateSelect('filterCpu', dynamicOptions.cpu || []);
        populateSelect('filterKernel', dynamicOptions.kernel || []);
        populateSelect('filterRcos', dynamicOptions.rcos || []);
        populateSelect('filterTopo', dynamicOptions.topo || []);
        populateSelect('filterPerf', dynamicOptions.perf || []);
        populateSelect('filterOffload', dynamicOptions.offload || []);
        populateSelect('filterThreads', dynamicOptions.threads || []);
        populateSelect('filterScaleUp', dynamicOptions.pods_per_worker || []);
        populateSelect('filterScaleOut', dynamicOptions.scale_out_factor || []);
        populateSelect('filterWsize', dynamicOptions.wsize || []);
    } catch (error) {
        console.error('Error updating dynamic filters:', error);
    }
}

// Populate select dropdown
function populateSelect(selectId, options) {
    const select = document.getElementById(selectId);
    const isMultiple = select.hasAttribute('multiple');
    const currentValues = isMultiple ?
        Array.from(select.selectedOptions).map(opt => opt.value) :
        [select.value];

    // Clear and populate
    select.innerHTML = '';

    // Add "All" option only for single-select
    if (!isMultiple) {
        select.innerHTML = '<option value="">All</option>';
    }

    options.forEach(opt => {
        const option = document.createElement('option');
        option.value = opt;
        option.textContent = opt;
        select.appendChild(option);
    });

    // Restore previous selection if still valid
    if (isMultiple) {
        currentValues.forEach(val => {
            if (val && options.includes(val)) {
                const option = select.querySelector(`option[value="${val}"]`);
                if (option) option.selected = true;
            }
        });
    } else if (currentValues[0] && options.includes(currentValues[0])) {
        select.value = currentValues[0];
    }
}

// Helper to get select value (handles both single and multi-select)
function getSelectValue(selectId) {
    const select = document.getElementById(selectId);
    if (select.hasAttribute('multiple')) {
        // Multi-select: return array of selected values (or empty array)
        return Array.from(select.selectedOptions).map(opt => opt.value);
    } else {
        // Single-select: return value or empty string
        return select.value || '';
    }
}

// Get current filter values as object
function getCurrentFilters() {
    return {
        benchmark: getSelectValue('filterBenchmark'),
        model: getSelectValue('filterModel'),
        nic: getSelectValue('filterNic'),
        arch: getSelectValue('filterArch'),
        protocol: getSelectValue('filterProtocol'),
        test_type: getSelectValue('filterTestType'),
        cpu: getSelectValue('filterCpu'),
        kernel: getSelectValue('filterKernel'),
        rcos: getSelectValue('filterRcos'),
        topo: getSelectValue('filterTopo'),
        perf: getSelectValue('filterPerf'),
        offload: getSelectValue('filterOffload'),
        threads: getSelectValue('filterThreads'),
        pods_per_worker: getSelectValue('filterScaleUp'),
        scale_out_factor: getSelectValue('filterScaleOut'),
        wsize: getSelectValue('filterWsize'),
        date_range_days: getSelectValue('filterDateRange')
    };
}

// Build URL params from filters
function buildFilterParams(additionalParams = {}) {
    const params = new URLSearchParams();
    const filters = getCurrentFilters();

    // Add filters (handle both single values and arrays)
    for (const [key, value] of Object.entries(filters)) {
        if (Array.isArray(value)) {
            // Multi-select: join with comma if has values
            if (value.length > 0) {
                params.append(key, value.join(','));
            }
        } else if (value) {
            // Single-select: add if not empty
            params.append(key, value);
        }
    }

    // Add any additional params
    for (const [key, value] of Object.entries(additionalParams)) {
        if (value) {
            params.append(key, value);
        }
    }

    return params;
}

// Build chart title with active filters
function buildChartTitleWithFilters(baseTitle) {
    const filters = getCurrentFilters();
    const activeFilters = [];

    // Human-readable labels for filter fields
    const filterLabels = {
        benchmark: 'Benchmark',
        model: 'Datapath',
        nic: 'NIC',
        arch: 'Architecture',
        protocol: 'Protocol',
        test_type: 'Test Type',
        cpu: 'CPU',
        kernel: 'Kernel',
        rcos: 'RCOS',
        topo: 'Topology',
        perf: 'Performance',
        offload: 'Offload',
        threads: 'Threads',
        pods_per_worker: 'Scale Up',
        scale_out_factor: 'Scale Out',
        wsize: 'Wsize',
        date_range_days: 'Date Range'
    };

    // Build list of active filters
    for (const [key, value] of Object.entries(filters)) {
        const label = filterLabels[key] || key;

        if (Array.isArray(value)) {
            // Multi-select: show if has values
            if (value.length > 0) {
                activeFilters.push(`${label}=${value.join(',')}`);
            }
        } else if (value && value !== '') {
            // Single-select: show if not empty
            if (key === 'date_range_days') {
                activeFilters.push(`${label}=${value} days`);
            } else {
                activeFilters.push(`${label}=${value}`);
            }
        }
    }

    // Build complete title
    if (activeFilters.length > 0) {
        return `${baseTitle} | ${activeFilters.join(', ')}`;
    }
    return baseTitle;
}

// Apply filters
async function applyFilters() {
    const params = buildFilterParams();

    try {
        showLoading();
        const response = await fetch(`/api/results?${params.toString()}`);
        filteredResults = await response.json();

        // Reload summary statistics with current filters
        loadSummary();

        // Reload current tab data
        const activeTab = document.querySelector('.nav-link.active').id;
        if (activeTab === 'overview-tab') {
            loadOverviewData();
        } else if (activeTab === 'scale-tab') {
            loadScaleChart();
        } else if (activeTab === 'trends-tab') {
            loadTrends();
        } else if (activeTab === 'results-tab') {
            loadResultsTable();
        } else if (activeTab === 'comparison-tab') {
            // Refresh comparison values based on new filters
            updateComparisonOptions();
        }
    } catch (error) {
        console.error('Error applying filters:', error);
    } finally {
        hideLoading();
    }
}

// Clear all filters
function clearFilters() {
    const filterIds = [
        'filterBenchmark', 'filterModel', 'filterNic', 'filterArch',
        'filterProtocol', 'filterTestType', 'filterCpu', 'filterKernel',
        'filterRcos', 'filterTopo', 'filterPerf', 'filterOffload',
        'filterThreads', 'filterScaleUp', 'filterScaleOut', 'filterWsize',
        'filterDateRange'
    ];

    filterIds.forEach(id => {
        const select = document.getElementById(id);
        if (select.hasAttribute('multiple')) {
            // Multi-select: deselect all options
            Array.from(select.options).forEach(opt => opt.selected = false);
        } else {
            // Single-select: set to empty
            select.value = '';
        }
    });

    applyFilters();
}

// Load overview data
async function loadOverviewData() {
    try {
        showLoading();

        // Determine unit filter based on test type (same logic as Trends tab)
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
            // No specific test type selected - show all units
            unitFilter = null;
            unitLabel = 'Performance Metric';
        }

        // Fetch raw results for client-side aggregation to track file paths
        const params = buildFilterParams();
        const response = await fetch(`/api/results?${params.toString()}`);
        const results = await response.json();

        // Filter by unit if specified
        let filtered = results;
        if (unitFilter) {
            filtered = results.filter(r => r.unit && r.unit.includes(unitFilter));
        }

        // Group by model
        const modelGroups = {};
        for (const result of filtered) {
            const modelKey = result.model || 'unknown';
            const mean = result.mean;
            const filePath = result.regulus_data;

            if (mean !== null && mean !== undefined) {
                if (!modelGroups[modelKey]) {
                    modelGroups[modelKey] = { means: [], filePaths: [] };
                }
                modelGroups[modelKey].means.push(mean);
                if (filePath) {
                    modelGroups[modelKey].filePaths.push(filePath);
                }
            }
        }

        // Calculate model statistics and file paths
        const modelStats = {};
        const modelFilePaths = {};
        for (const [key, data] of Object.entries(modelGroups)) {
            if (data.means.length > 0) {
                const mean = data.means.reduce((a, b) => a + b, 0) / data.means.length;
                const stddev = data.means.length > 1
                    ? Math.sqrt(data.means.reduce((sum, val) => sum + Math.pow(val - mean, 2), 0) / data.means.length)
                    : 0;

                modelStats[key] = {
                    mean: mean,
                    stddev: stddev,
                    min: Math.min(...data.means),
                    max: Math.max(...data.means),
                    count: data.means.length
                };

                // File path: if single result, use it; otherwise "aggregated"
                modelFilePaths[key] = data.filePaths.length === 1 ? data.filePaths[0] : 'aggregated';
            }
        }

        // Group by kernel
        const kernelGroups = {};
        for (const result of filtered) {
            const kernelKey = result.kernel || 'unknown';
            const mean = result.mean;
            const filePath = result.regulus_data;

            if (mean !== null && mean !== undefined) {
                if (!kernelGroups[kernelKey]) {
                    kernelGroups[kernelKey] = { means: [], filePaths: [] };
                }
                kernelGroups[kernelKey].means.push(mean);
                if (filePath) {
                    kernelGroups[kernelKey].filePaths.push(filePath);
                }
            }
        }

        // Calculate kernel statistics and file paths
        const kernelStats = {};
        const kernelFilePaths = {};
        for (const [key, data] of Object.entries(kernelGroups)) {
            if (data.means.length > 0) {
                const mean = data.means.reduce((a, b) => a + b, 0) / data.means.length;
                const stddev = data.means.length > 1
                    ? Math.sqrt(data.means.reduce((sum, val) => sum + Math.pow(val - mean, 2), 0) / data.means.length)
                    : 0;

                kernelStats[key] = {
                    mean: mean,
                    stddev: stddev,
                    min: Math.min(...data.means),
                    max: Math.max(...data.means),
                    count: data.means.length
                };

                // File path: if single result, use it; otherwise "aggregated"
                kernelFilePaths[key] = data.filePaths.length === 1 ? data.filePaths[0] : 'aggregated';
            }
        }

        // Render charts with file paths
        const unitSuffix = unitFilter ? ` (${unitFilter})` : ' (All Profiles)';
        const modelTitle = buildChartTitleWithFilters(`Performance by Model${unitSuffix}`);
        renderBarChart('chartByModel', modelStats, modelTitle, 'Model', unitLabel, modelFilePaths);

        const kernelTitle = buildChartTitleWithFilters(`Performance by Kernel${unitSuffix}`);
        renderBarChart('chartByKernel', kernelStats, kernelTitle, 'Kernel', unitLabel, kernelFilePaths);

        // Load top performers with the same unit filter
        const topParams = buildFilterParams({ top_n: 10, unit_filter: unitFilter });
        const topResponse = await fetch(`/api/top_performers?${topParams.toString()}`);
        const topPerformers = await topResponse.json();
        renderTopPerformersTable(topPerformers);

    } catch (error) {
        console.error('Error loading overview data:', error);
    } finally {
        hideLoading();
    }
}

// Render bar chart
function renderBarChart(canvasId, statsData, title, xAxisLabel, yAxisLabel, filePaths = {}) {
    const ctx = document.getElementById(canvasId);

    // Destroy existing chart if it exists
    if (charts[canvasId]) {
        charts[canvasId].destroy();
    }

    const labels = Object.keys(statsData);
    const means = labels.map(label => statsData[label].mean);
    const stddevs = labels.map(label => statsData[label].stddev);

    // Get file paths for each label
    const filePathArray = labels.map(label => filePaths[label] || 'aggregated');

    // Default y-axis label if not provided
    const yLabel = yAxisLabel || 'Throughput (Gbps)';

    charts[canvasId] = new Chart(ctx, {
        type: 'bar',
        data: {
            labels: labels,
            datasets: [{
                label: 'Mean Performance',
                data: means,
                backgroundColor: 'rgba(102, 126, 234, 0.8)',
                borderColor: 'rgba(102, 126, 234, 1)',
                borderWidth: 1,
                filePaths: filePathArray
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            onClick: (event, activeElements) => {
                if (activeElements.length > 0) {
                    const element = activeElements[0];
                    const index = element.index;
                    const filePath = filePathArray[index];

                    if (filePath && filePath !== 'aggregated') {
                        // Create temporary element for visual feedback
                        const tempElement = document.createElement('span');
                        tempElement.textContent = 'Copied!';
                        tempElement.style.position = 'fixed';
                        tempElement.style.left = event.native.clientX + 'px';
                        tempElement.style.top = event.native.clientY + 'px';
                        tempElement.style.backgroundColor = '#28a745';
                        tempElement.style.color = 'white';
                        tempElement.style.padding = '5px 10px';
                        tempElement.style.borderRadius = '4px';
                        tempElement.style.zIndex = '10000';
                        document.body.appendChild(tempElement);

                        copyToClipboard(filePath, tempElement);

                        setTimeout(() => {
                            if (document.body.contains(tempElement)) {
                                document.body.removeChild(tempElement);
                            }
                        }, 2000);
                    }
                }
            },
            plugins: {
                title: {
                    display: true,
                    text: title,
                    font: {
                        size: 14
                    }
                },
                legend: {
                    display: false
                },
                tooltip: {
                    callbacks: {
                        afterLabel: function(context) {
                            const filePath = filePathArray[context.dataIndex];
                            if (filePath === 'aggregated') {
                                return 'Source: aggregated';
                            } else if (filePath) {
                                return 'File: ' + filePath;
                            }
                            return '';
                        }
                    }
                },
                datalabels: {
                    anchor: 'end',
                    align: 'top',
                    formatter: function(value) {
                        return value.toFixed(2);
                    },
                    font: {
                        weight: 'bold',
                        size: 11
                    }
                }
            },
            scales: {
                y: {
                    beginAtZero: true,
                    title: {
                        display: true,
                        text: yLabel
                    }
                },
                x: {
                    title: {
                        display: true,
                        text: xAxisLabel
                    }
                }
            }
        },
        plugins: [ChartDataLabels]
    });
}

// Render top performers table
function renderTopPerformersTable(performers) {
    const tbody = document.querySelector('#topPerformersTable tbody');
    tbody.innerHTML = '';

    performers.forEach((result, index) => {
        const row = tbody.insertRow();
        const filePath = result.regulus_data || '';

        row.innerHTML = `
            <td>${index + 1}</td>
            <td>
                <span class="badge bg-primary badge-benchmark clickable-file"
                      title="${filePath}"
                      style="cursor: pointer;"
                      onclick="copyToClipboard('${filePath.replace(/'/g, "\\'")}', this)">
                    ${result.benchmark || '-'}
                </span>
            </td>
            <td>${result.model || '-'}</td>
            <td>${result.nic || '-'}</td>
            <td>${result.kernel || '-'}</td>
            <td>${result.topo || '-'}</td>
            <td><strong>${result.mean ? result.mean.toFixed(2) : '-'}</strong></td>
            <td>${result.unit || '-'}</td>
            <td>${result.busy_cpu ? result.busy_cpu.toFixed(1) : '-'}</td>
        `;
    });
}

// Load scale chart data
async function loadScaleChart() {
    const scaleBy = document.getElementById('scaleBy').value;
    const testType = getSelectValue('filterTestType');

    try {
        showLoading();

        // Determine unit filter based on test type (same logic as Overview and Trends)
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
            // No specific test type selected - default to Gbps for throughput tests
            unitFilter = 'Gbps';
            unitLabel = 'Throughput (Gbps)';
        }

        // Check for 2D scaling: Detect if ScaleUp or Wsize filter is "All" (empty)
        const scaleUpFilter = getSelectValue('filterScaleUp');
        const wsizeFilter = getSelectValue('filterWsize');

        // Determine secondary dimension (maximum 2 dimensions)
        // Secondary dimension must be:
        // 1. Different from the primary dimension (scaleBy)
        // 2. Have its filter set to "All" (empty)
        let secondaryDim = null;
        let secondaryDimField = null;

        // Check each potential secondary dimension
        // Priority: ScaleUp first, then Wsize
        if (scaleBy !== 'pods_per_worker' && (!scaleUpFilter || scaleUpFilter === '')) {
            secondaryDim = 'pods_per_worker';
            secondaryDimField = 'ScaleUp';
        } else if (scaleBy !== 'wsize' && (!wsizeFilter || wsizeFilter === '')) {
            secondaryDim = 'wsize';
            secondaryDimField = 'Wsize';
        }

        // Get display name for the scaling dimension
        const scaleByLabels = {
            'threads': 'Threads',
            'wsize': 'Wsize',
            'pods_per_worker': 'ScaleUp',
            'scale_out_factor': 'ScaleOut'
        };

        // Axis labels WITH units (for axis display)
        const scaleByAxisLabels = {
            'threads': 'Threads',
            'wsize': 'Wsize (Bytes)',
            'pods_per_worker': 'ScaleUp',
            'scale_out_factor': 'ScaleOut'
        };

        const scaleLabel = scaleByLabels[scaleBy] || scaleBy;
        const scaleAxisLabel = scaleByAxisLabels[scaleBy] || scaleBy;

        // Secondary dimension axis label with units
        const secondaryAxisLabel = secondaryDim === 'wsize' ? 'Wsize (Bytes)' : secondaryDimField;

        if (secondaryDim && secondaryDim !== scaleBy) {
            // 2D Scaling: Load raw results and group by both dimensions
            await loadScale2D(scaleBy, scaleLabel, scaleAxisLabel, secondaryDim, secondaryDimField, secondaryAxisLabel, unitFilter, unitLabel);
        } else {
            // 1D Scaling: Use existing single-dimension logic
            await loadScale1D(scaleBy, scaleLabel, scaleAxisLabel, unitFilter, unitLabel);
        }

    } catch (error) {
        console.error('Error loading scale chart:', error);
    } finally {
        hideLoading();
    }
}

// 1D scaling (existing single-dimension logic)
async function loadScale1D(scaleBy, scaleLabel, scaleAxisLabel, unitFilter, unitLabel) {
    // Fetch raw results for client-side aggregation to track file paths
    const params = buildFilterParams();
    const response = await fetch(`/api/results?${params.toString()}`);
    const results = await response.json();

    // Filter by unit if specified
    let filtered = results;
    if (unitFilter) {
        filtered = results.filter(r => r.unit && r.unit.includes(unitFilter));
    }

    // Group results by the scaling dimension
    const grouped = {};
    for (const result of filtered) {
        const dimValue = result[scaleBy];
        const mean = result.mean;
        const busyCpu = result.busy_cpu;
        const filePath = result.regulus_data;

        if (dimValue !== null && dimValue !== undefined && mean !== null && mean !== undefined) {
            const key = String(dimValue);
            if (!grouped[key]) {
                grouped[key] = { means: [], busyCpus: [], filePaths: [] };
            }
            grouped[key].means.push(mean);
            if (busyCpu !== null && busyCpu !== undefined) {
                grouped[key].busyCpus.push(busyCpu);
            }
            if (filePath) {
                grouped[key].filePaths.push(filePath);
            }
        }
    }

    // Calculate stats and determine file paths
    const perfStats = {};
    const busyCpuStats = {};
    const perfFilePaths = {};
    const busyCpuFilePaths = {};

    for (const [key, data] of Object.entries(grouped)) {
        // Performance stats
        if (data.means.length > 0) {
            const mean = data.means.reduce((a, b) => a + b, 0) / data.means.length;
            const stddev = data.means.length > 1
                ? Math.sqrt(data.means.reduce((sum, val) => sum + Math.pow(val - mean, 2), 0) / data.means.length)
                : 0;

            perfStats[key] = {
                mean: mean,
                stddev: stddev,
                min: Math.min(...data.means),
                max: Math.max(...data.means),
                count: data.means.length
            };

            // File path: if single result, use it; otherwise "aggregated"
            perfFilePaths[key] = data.filePaths.length === 1 ? data.filePaths[0] : 'aggregated';
        }

        // BusyCPU stats
        if (data.busyCpus.length > 0) {
            const mean = data.busyCpus.reduce((a, b) => a + b, 0) / data.busyCpus.length;
            const stddev = data.busyCpus.length > 1
                ? Math.sqrt(data.busyCpus.reduce((sum, val) => sum + Math.pow(val - mean, 2), 0) / data.busyCpus.length)
                : 0;

            busyCpuStats[key] = {
                mean: mean,
                stddev: stddev,
                min: Math.min(...data.busyCpus),
                max: Math.max(...data.busyCpus),
                count: data.busyCpus.length
            };

            busyCpuFilePaths[key] = data.filePaths.length === 1 ? data.filePaths[0] : 'aggregated';
        }
    }

    // Render performance chart (left side)
    const perfBaseTitle = `Performance by ${scaleLabel}`;
    const perfTitle = buildChartTitleWithFilters(perfBaseTitle);
    renderBarChart('scaleChart', perfStats, perfTitle, scaleAxisLabel, unitLabel, perfFilePaths);

    // Render busy_cpu chart (right side)
    const busyCpuBaseTitle = `BusyCPU by ${scaleLabel}`;
    const busyCpuTitle = buildChartTitleWithFilters(busyCpuBaseTitle);
    renderBarChart('scaleBusyCpuChart', busyCpuStats, busyCpuTitle, scaleAxisLabel, 'BusyCPU (num cpus)', busyCpuFilePaths);
}

// 2D scaling (grouped bar chart with 2 dimensions)
async function loadScale2D(primaryDim, primaryLabel, primaryAxisLabel, secondaryDim, secondaryLabel, secondaryAxisLabel, unitFilter, unitLabel) {
    // Fetch raw results with current filters
    const params = buildFilterParams();
    const response = await fetch(`/api/results?${params.toString()}`);
    const results = await response.json();

    // Filter by unit if specified
    let filtered = results;
    if (unitFilter) {
        filtered = results.filter(r => r.unit && r.unit.includes(unitFilter));
    }

    // Group results by both dimensions
    const grouped = {};
    for (const result of filtered) {
        const primaryVal = result[primaryDim];
        const secondaryVal = result[secondaryDim];
        const mean = result.mean;
        const busyCpu = result.busy_cpu;
        const filePath = result.regulus_data;

        if (primaryVal !== null && primaryVal !== undefined &&
            secondaryVal !== null && secondaryVal !== undefined &&
            mean !== null && mean !== undefined) {

            const primaryKey = String(primaryVal);
            const secondaryKey = String(secondaryVal);

            if (!grouped[primaryKey]) {
                grouped[primaryKey] = {};
            }
            if (!grouped[primaryKey][secondaryKey]) {
                grouped[primaryKey][secondaryKey] = { means: [], busyCpus: [], filePaths: [] };
            }

            grouped[primaryKey][secondaryKey].means.push(mean);
            if (busyCpu !== null && busyCpu !== undefined) {
                grouped[primaryKey][secondaryKey].busyCpus.push(busyCpu);
            }
            if (filePath) {
                grouped[primaryKey][secondaryKey].filePaths.push(filePath);
            }
        }
    }

    // Calculate averages for each combination
    const primaryValues = Object.keys(grouped).sort((a, b) => {
        // Sort numerically if possible, otherwise alphabetically
        const numA = parseFloat(a);
        const numB = parseFloat(b);
        if (!isNaN(numA) && !isNaN(numB)) return numA - numB;
        return a.localeCompare(b);
    });

    // Get all unique secondary values
    const secondaryValuesSet = new Set();
    for (const primary of primaryValues) {
        for (const secondary of Object.keys(grouped[primary])) {
            secondaryValuesSet.add(secondary);
        }
    }
    const secondaryValues = Array.from(secondaryValuesSet).sort((a, b) => {
        const numA = parseFloat(a);
        const numB = parseFloat(b);
        if (!isNaN(numA) && !isNaN(numB)) return numA - numB;
        return a.localeCompare(b);
    });

    // Build datasets for grouped bar chart (Performance)
    const perfDatasets = secondaryValues.map((secVal, idx) => {
        const data = primaryValues.map(primVal => {
            const group = grouped[primVal] && grouped[primVal][secVal];
            if (group && group.means.length > 0) {
                return group.means.reduce((a, b) => a + b, 0) / group.means.length;
            }
            return null;
        });

        // Collect filePaths for each primary value
        const filePaths = primaryValues.map(primVal => {
            const group = grouped[primVal] && grouped[primVal][secVal];
            if (group && group.filePaths && group.filePaths.length > 0) {
                return group.filePaths[0]; // Use first file path
            }
            return null;
        });

        const colors = [
            'rgba(102, 126, 234, 0.8)',
            'rgba(118, 75, 162, 0.8)',
            'rgba(237, 100, 166, 0.8)',
            'rgba(255, 154, 158, 0.8)',
            'rgba(250, 208, 196, 0.8)',
            'rgba(76, 175, 80, 0.8)',
            'rgba(255, 193, 7, 0.8)',
            'rgba(3, 169, 244, 0.8)'
        ];

        return {
            label: `${secondaryLabel}=${secVal}`,
            data: data,
            filePaths: filePaths,
            backgroundColor: colors[idx % colors.length],
            borderColor: colors[idx % colors.length].replace('0.8', '1'),
            borderWidth: 1
        };
    });

    // Build datasets for grouped bar chart (BusyCPU)
    const busyCpuDatasets = secondaryValues.map((secVal, idx) => {
        const data = primaryValues.map(primVal => {
            const group = grouped[primVal] && grouped[primVal][secVal];
            if (group && group.busyCpus.length > 0) {
                return group.busyCpus.reduce((a, b) => a + b, 0) / group.busyCpus.length;
            }
            return null;
        });

        // Collect filePaths for each primary value
        const filePaths = primaryValues.map(primVal => {
            const group = grouped[primVal] && grouped[primVal][secVal];
            if (group && group.filePaths && group.filePaths.length > 0) {
                return group.filePaths[0]; // Use first file path
            }
            return null;
        });

        const colors = [
            'rgba(102, 126, 234, 0.8)',
            'rgba(118, 75, 162, 0.8)',
            'rgba(237, 100, 166, 0.8)',
            'rgba(255, 154, 158, 0.8)',
            'rgba(250, 208, 196, 0.8)',
            'rgba(76, 175, 80, 0.8)',
            'rgba(255, 193, 7, 0.8)',
            'rgba(3, 169, 244, 0.8)'
        ];

        return {
            label: `${secondaryLabel}=${secVal}`,
            data: data,
            filePaths: filePaths,
            backgroundColor: colors[idx % colors.length],
            borderColor: colors[idx % colors.length].replace('0.8', '1'),
            borderWidth: 1
        };
    });

    // Render performance chart (left side)
    const perfTitle = buildChartTitleWithFilters(`Performance by ${primaryLabel} & ${secondaryLabel}`);
    renderGroupedBarChart('scaleChart', primaryValues, perfDatasets, perfTitle, primaryAxisLabel, unitLabel);

    // Render busy_cpu chart (right side)
    const busyCpuTitle = buildChartTitleWithFilters(`BusyCPU by ${primaryLabel} & ${secondaryLabel}`);
    renderGroupedBarChart('scaleBusyCpuChart', primaryValues, busyCpuDatasets, busyCpuTitle, primaryAxisLabel, 'BusyCPU (num cpus)');
}

// Render grouped bar chart (for 2D scaling)
function renderGroupedBarChart(canvasId, labels, datasets, title, xAxisLabel, yAxisLabel) {
    const ctx = document.getElementById(canvasId);

    // Destroy existing chart if it exists
    if (charts[canvasId]) {
        charts[canvasId].destroy();
    }

    charts[canvasId] = new Chart(ctx, {
        type: 'bar',
        data: {
            labels: labels,
            datasets: datasets
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            onClick: (event, activeElements) => {
                if (activeElements.length > 0) {
                    const element = activeElements[0];
                    const datasetIndex = element.datasetIndex;
                    const index = element.index;
                    const dataset = datasets[datasetIndex];

                    // Get the file path from the dataset
                    if (dataset.filePaths && dataset.filePaths[index]) {
                        const filePath = dataset.filePaths[index];
                        // Use the existing copyToClipboard function
                        // Create a temporary element for the visual feedback
                        const tempElement = document.createElement('span');
                        tempElement.textContent = 'Copied!';
                        tempElement.style.position = 'fixed';
                        tempElement.style.left = event.native.clientX + 'px';
                        tempElement.style.top = event.native.clientY + 'px';
                        tempElement.style.backgroundColor = '#28a745';
                        tempElement.style.color = 'white';
                        tempElement.style.padding = '5px 10px';
                        tempElement.style.borderRadius = '4px';
                        tempElement.style.zIndex = '10000';
                        document.body.appendChild(tempElement);

                        copyToClipboard(filePath, tempElement);

                        setTimeout(() => {
                            if (document.body.contains(tempElement)) {
                                document.body.removeChild(tempElement);
                            }
                        }, 2000);
                    }
                }
            },
            plugins: {
                title: {
                    display: true,
                    text: title,
                    font: {
                        size: 14
                    }
                },
                legend: {
                    display: true,
                    position: 'top'
                },
                tooltip: {
                    callbacks: {
                        afterLabel: function(context) {
                            const datasetIndex = context.datasetIndex;
                            const index = context.dataIndex;
                            const dataset = datasets[datasetIndex];

                            // Add file path to tooltip if available
                            if (dataset.filePaths && dataset.filePaths[index]) {
                                return 'File: ' + dataset.filePaths[index];
                            }
                            return '';
                        }
                    }
                },
                datalabels: {
                    display: true,
                    anchor: 'end',
                    align: 'top',
                    formatter: function(value) {
                        if (value === null || value === undefined) return '';
                        return value.toFixed(2);
                    },
                    font: {
                        weight: 'bold',
                        size: 10
                    },
                    color: '#333'
                }
            },
            scales: {
                y: {
                    beginAtZero: true,
                    title: {
                        display: true,
                        text: yAxisLabel
                    }
                },
                x: {
                    title: {
                        display: true,
                        text: xAxisLabel
                    }
                }
            }
        },
        plugins: [ChartDataLabels]
    });
}

// Load trends data
async function loadTrends() {
    const groupBy = document.getElementById('trendGroupBy').value;
    const testType = getSelectValue('filterTestType');

    try {
        showLoading();

        // Determine unit filter based on test type
        // This prevents mixing incompatible units (Gbps vs transactions-sec vs pps)
        let unitFilter = null;
        if (testType === 'rr') {
            unitFilter = 'transactions-sec';
        } else if (testType === 'crr') {
            unitFilter = 'connections-sec';
        } else if (testType === 'pps') {
            unitFilter = 'pps';
        } else if (testType === 'stream' || testType === 'bidirec') {
            unitFilter = 'Gbps';
        } else {
            // No specific test type selected - default to Gbps for throughput tests
            unitFilter = 'Gbps';
        }

        // Build filter params with appropriate unit filter
        const params = buildFilterParams({
            metric: 'mean',
            group_by: groupBy,
            unit_filter: unitFilter
        });

        const response = await fetch(`/api/trends?${params.toString()}`);
        const trendsData = await response.json();

        renderTrendChart(trendsData);
    } catch (error) {
        console.error('Error loading trends:', error);
    } finally {
        hideLoading();
    }
}

// Render trend chart
function renderTrendChart(trendsData) {
    console.log('renderTrendChart called with data:', trendsData);

    const ctx = document.getElementById('trendChart');
    if (!ctx) {
        console.error('Canvas element trendChart not found');
        return;
    }

    if (charts['trendChart']) {
        charts['trendChart'].destroy();
    }

    // Check if we have data
    if (!trendsData || Object.keys(trendsData).length === 0) {
        console.warn('No trend data available');
        return;
    }

    // Prepare datasets
    const datasets = [];
    const colors = [
        'rgba(102, 126, 234, 1)',
        'rgba(118, 75, 162, 1)',
        'rgba(237, 100, 166, 1)',
        'rgba(255, 154, 158, 1)',
        'rgba(250, 208, 196, 1)'
    ];

    let colorIndex = 0;
    for (const [groupKey, dataPoints] of Object.entries(trendsData)) {
        console.log(`Processing group ${groupKey} with ${dataPoints.length} points`);

        const data = dataPoints.map(dp => ({
            x: new Date(dp.timestamp),
            y: dp.mean
        }));

        datasets.push({
            label: groupKey,
            data: data,
            borderColor: colors[colorIndex % colors.length],
            backgroundColor: colors[colorIndex % colors.length].replace('1)', '0.1)'),
            borderWidth: 2,
            tension: 0.1,
            fill: false
        });

        colorIndex++;
    }

    console.log('Creating chart with', datasets.length, 'datasets');

    // Determine y-axis label based on test type filter
    const testType = getSelectValue('filterTestType');
    let yAxisLabel = 'Performance Metric';
    if (testType === 'rr') {
        yAxisLabel = 'Transactions per Second';
    } else if (testType === 'crr') {
        yAxisLabel = 'Connections per Second';
    } else if (testType === 'pps') {
        yAxisLabel = 'Packets per Second';
    } else if (testType === 'stream' || testType === 'bidirec') {
        yAxisLabel = 'Throughput (Gbps)';
    } else {
        // Default - assume Gbps throughput
        yAxisLabel = 'Throughput (Gbps)';
    }

    try {
        // Hide legend if only showing "all" (no grouping)
        const showLegend = !(datasets.length === 1 && datasets[0].label === 'all');

        charts['trendChart'] = new Chart(ctx, {
            type: 'line',
            data: { datasets: datasets },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    title: {
                        display: true,
                        text: 'Performance Trends Over Time'
                    },
                    legend: {
                        display: showLegend
                    }
                },
                scales: {
                    x: {
                        type: 'time',
                        time: {
                            unit: 'day'
                        },
                        title: {
                            display: true,
                            text: 'Date'
                        }
                    },
                    y: {
                        beginAtZero: true,
                        title: {
                            display: true,
                            text: yAxisLabel
                        }
                    }
                }
            }
        });
        console.log('Chart created successfully');
    } catch (error) {
        console.error('Error creating chart:', error);
    }
}

// Update comparison options when field changes
async function updateComparisonOptions() {
    const field = document.getElementById('compareField').value;

    try {
        // Build params with all current filters
        const params = buildFilterParams({ field: field });

        // Fetch available values for the comparison field based on current filters
        const response = await fetch(`/api/comparison_values?${params.toString()}`);
        const options = await response.json();

        populateSelect('compareValueA', options);
        populateSelect('compareValueB', options);

        // Remove "All" option from comparison selects
        document.getElementById('compareValueA').remove(0);
        document.getElementById('compareValueB').remove(0);

        // Set different defaults if possible
        if (options.length >= 2) {
            document.getElementById('compareValueA').value = options[0];
            document.getElementById('compareValueB').value = options[1];
        }
    } catch (error) {
        console.error('Error loading comparison values:', error);
        // Fallback to using filterOptions if API call fails
        const options = filterOptions[field] || [];
        populateSelect('compareValueA', options);
        populateSelect('compareValueB', options);
        document.getElementById('compareValueA').remove(0);
        document.getElementById('compareValueB').remove(0);
        if (options.length >= 2) {
            document.getElementById('compareValueA').value = options[0];
            document.getElementById('compareValueB').value = options[1];
        }
    }
}

// Run comparison
async function runComparison() {
    const field = document.getElementById('compareField').value;
    const valueA = document.getElementById('compareValueA').value;
    const valueB = document.getElementById('compareValueB').value;

    if (!valueA || !valueB) {
        alert('Please select both values to compare');
        return;
    }

    try {
        showLoading();

        // Build params with all current filters
        const params = buildFilterParams({
            field: field,
            value_a: valueA,
            value_b: valueB,
            metric: 'mean'
        });

        const response = await fetch(`/api/compare?${params.toString()}`);
        const comparison = await response.json();

        renderComparisonResults(comparison);
    } catch (error) {
        console.error('Error running comparison:', error);
    } finally {
        hideLoading();
    }
}

// Render comparison results
function renderComparisonResults(comparison) {
    const resultsDiv = document.getElementById('comparisonResults');

    const percentChange = comparison.percent_change.toFixed(2);
    const isPositive = comparison.percent_change > 0;
    const betterClass = comparison.better === 'config_b' ? 'comparison-better' :
                       comparison.better === 'config_a' ? 'comparison-worse' : '';

    resultsDiv.innerHTML = `
        <div class="comparison-result ${betterClass}">
            <h5>Comparison Results</h5>
            <div class="row">
                <div class="col-md-6">
                    <h6>${comparison.config_a}</h6>
                    <p class="h4">${comparison.mean_a.toFixed(2)} Gbps</p>
                </div>
                <div class="col-md-6">
                    <h6>${comparison.config_b}</h6>
                    <p class="h4">${comparison.mean_b.toFixed(2)} Gbps</p>
                </div>
            </div>
            <hr>
            <div class="mt-3">
                <strong>Difference:</strong> ${comparison.difference.toFixed(2)} Gbps
                (${isPositive ? '+' : ''}${percentChange}%)
                <br>
                <strong>Better Configuration:</strong>
                ${comparison.better === 'equal' ? 'Equal performance' : comparison[comparison.better]}
            </div>
        </div>
    `;
}

// Load results table
async function loadResultsTable() {
    try {
        showLoading();

        // Use buildFilterParams to include ALL filters
        const params = buildFilterParams();

        const response = await fetch(`/api/results?${params.toString()}`);
        const results = await response.json();

        renderResultsTable(results);
    } catch (error) {
        console.error('Error loading results table:', error);
    } finally {
        hideLoading();
    }
}

// Render results table
function renderResultsTable(results) {
    // Destroy existing DataTable first (before touching the DOM)
    if ($.fn.DataTable.isDataTable('#resultsTable')) {
        $('#resultsTable').DataTable().clear().destroy();
    }

    // Now clear and repopulate the tbody
    const tbody = document.querySelector('#resultsTable tbody');
    tbody.innerHTML = '';

    results.forEach((result, index) => {
        const row = tbody.insertRow();
        const filePath = result.regulus_data || '';

        // Config column: pods-per-worker,scale_out_factor,topo
        const ppw = result.pods_per_worker || '?';
        const sof = result.scale_out_factor || '?';
        const topo = result.topo || '?';
        const config = `${ppw},${sof},${topo}`;

        // TestType column: protocol,test-type
        const protocol = result.protocol || '?';
        const testType = result.test_type || '?';
        const testTypeComposite = `${protocol},${testType}`;

        row.innerHTML = `
            <td>${index + 1}</td>
            <td>
                <span class="badge bg-primary badge-benchmark clickable-file"
                      title="${filePath}"
                      style="cursor: pointer;"
                      onclick="copyToClipboard('${filePath.replace(/'/g, "\\'")}', this)">
                    ${result.benchmark || '-'}
                </span>
            </td>
            <td>${result.nic || '-'}</td>
            <td>${result.arch || '-'}</td>
            <td>${result.kernel || '-'}</td>
            <td>${result.model || '-'}</td>
            <td>${config}</td>
            <td>${result.cpu || '-'}</td>
            <td>${testTypeComposite}</td>
            <td>${result.threads || '-'}</td>
            <td>${result.wsize || '-'}</td>
            <td data-order="${result.mean || 0}"><strong>${result.mean ? result.mean.toFixed(2) : '-'}</strong></td>
            <td>${result.unit || '-'}</td>
            <td>${result.busy_cpu !== null && result.busy_cpu !== undefined ? result.busy_cpu.toFixed(1) : '-'}</td>
        `;
    });

    // Create fresh DataTable
    $('#resultsTable').DataTable({
        pageLength: 25,
        order: [[11, 'desc']], // Sort by mean by default (column 11)
        language: {
            search: "Search results:"
        }
    });
}

// Reload reports
async function reloadReports() {
    try {
        showLoading();

        const response = await fetch('/api/reload', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({})
        });

        const result = await response.json();

        if (result.status === 'success') {
            alert('Reports reloaded successfully: ' + result.message);
            location.reload();
        } else {
            alert('Error reloading reports: ' + result.message);
        }
    } catch (error) {
        console.error('Error reloading reports:', error);
        alert('Error reloading reports');
    } finally {
        hideLoading();
    }
}

// Copy file path to clipboard
function copyToClipboard(text, element) {
    // Fallback method for HTTP (non-HTTPS) contexts
    const textArea = document.createElement('textarea');
    textArea.value = text;
    textArea.style.position = 'fixed';
    textArea.style.left = '-9999px';
    document.body.appendChild(textArea);
    textArea.select();

    try {
        const successful = document.execCommand('copy');
        document.body.removeChild(textArea);

        if (successful) {
            // Show visual feedback
            const originalText = element.textContent;
            element.textContent = 'Copied!';
            element.style.backgroundColor = '#28a745';

            setTimeout(function() {
                element.textContent = originalText;
                element.style.backgroundColor = '';
            }, 1500);
        } else {
            alert('Failed to copy file path to clipboard');
        }
    } catch (err) {
        document.body.removeChild(textArea);
        console.error('Failed to copy to clipboard:', err);
        alert('Failed to copy: ' + text);
    }
}

// Tab change handler - load data when switching tabs
document.querySelectorAll('[data-bs-toggle="tab"]').forEach(tab => {
    tab.addEventListener('shown.bs.tab', function(event) {
        const tabId = event.target.id;

        if (tabId === 'scale-tab') {
            loadScaleChart();
        } else if (tabId === 'trends-tab') {
            loadTrends();
        } else if (tabId === 'results-tab') {
            loadResultsTable();
        } else if (tabId === 'comparison-tab') {
            updateComparisonOptions();
        }
    });
});
