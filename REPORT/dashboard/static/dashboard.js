/**
 * Dashboard JavaScript - Interactive charts and data loading
 */

// Global variables
let allResults = [];
let filteredResults = [];
let filterOptions = {};
let charts = {};
let applyFiltersTimeout = null;

// Row selection state (for filter bookmarking)
let selectedRow = null;
let savedFilterState = null;
let currentResults = [];  // Store current results for row selection

// Initialize dashboard on page load
document.addEventListener('DOMContentLoaded', function() {
    console.log('Dashboard initializing...');
    loadReportFiles();  // Load available report files
    loadSummary();
    loadFilters();
    loadResultsTable();

    // Setup comparison field change handler
    document.getElementById('compareField').addEventListener('change', updateComparisonOptions);

    // Setup collapse toggle icon rotation for Report Files
    const reportFilesCollapse = document.getElementById('reportFilesCollapse');
    const reportFilesToggle = document.getElementById('reportFilesToggle');

    reportFilesCollapse.addEventListener('shown.bs.collapse', function() {
        reportFilesToggle.setAttribute('aria-expanded', 'true');
    });

    reportFilesCollapse.addEventListener('hidden.bs.collapse', function() {
        reportFilesToggle.setAttribute('aria-expanded', 'false');
    });

    // Setup collapse toggle icon rotation for Date Range
    const dateRangeCollapse = document.getElementById('dateRangeCollapse');
    const dateRangeToggle = document.getElementById('dateRangeToggle');

    dateRangeCollapse.addEventListener('shown.bs.collapse', function() {
        dateRangeToggle.setAttribute('aria-expanded', 'true');
    });

    dateRangeCollapse.addEventListener('hidden.bs.collapse', function() {
        dateRangeToggle.setAttribute('aria-expanded', 'false');
    });
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

// Load available report files
async function loadReportFiles() {
    try {
        const response = await fetch('/api/list_files');
        const data = await response.json();

        if (data.success && data.files) {
            const select = document.getElementById('filterReportFiles');
            select.innerHTML = '';  // Clear loading message

            // Add options for each file
            data.files.forEach(file => {
                const option = document.createElement('option');
                option.value = file.filename;
                option.textContent = file.filename;
                option.title = `${file.total_iterations} iterations, ${file.benchmarks.join(', ')}`;
                select.appendChild(option);
            });

            console.log(`Loaded ${data.files.length} report files`);
        }
    } catch (error) {
        console.error('Error loading report files:', error);
        const select = document.getElementById('filterReportFiles');
        select.innerHTML = '<option value="">Error loading files</option>';
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

        // After updating filter options, apply the filters with debouncing
        // This prevents multiple rapid filter applications
        debouncedApplyFilters();
    } catch (error) {
        console.error('Error updating dynamic filters:', error);
    }
}

// Debounced version of applyFilters to prevent too many rapid calls
function debouncedApplyFilters() {
    // Clear any pending timeout
    if (applyFiltersTimeout) {
        clearTimeout(applyFiltersTimeout);
    }

    // Set a new timeout to apply filters after a short delay
    applyFiltersTimeout = setTimeout(() => {
        applyFilters();
    }, 300); // 300ms debounce delay
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

    // Add "All" option for both single and multi-select
    const allOption = document.createElement('option');
    allOption.value = '';
    allOption.textContent = 'All';
    select.appendChild(allOption);

    // Create a map for quick lookup and add all options
    const optionElements = new Map();
    options.forEach(opt => {
        const option = document.createElement('option');
        option.value = opt;
        option.textContent = opt;
        select.appendChild(option);
        optionElements.set(opt, option);
    });

    // Restore previous selection if still valid
    if (isMultiple) {
        // For multi-select, restore all valid selections
        let hasValidSelection = false;
        currentValues.forEach(val => {
            if (val === '') {
                // Restore "All" selection
                allOption.selected = true;
                hasValidSelection = true;
            } else if (optionElements.has(val)) {
                // Restore specific value using the element from our map
                optionElements.get(val).selected = true;
                hasValidSelection = true;
            }
        });

        // If no valid selections were restored, select "All" by default
        if (!hasValidSelection) {
            allOption.selected = true;
        }
    } else {
        // For single-select, restore if value is still valid
        if (currentValues[0] && options.includes(currentValues[0])) {
            select.value = currentValues[0];
        } else {
            // Default to "All" if previous value no longer valid
            select.value = '';
        }
    }
}

// Helper to get select value (handles both single and multi-select)
function getSelectValue(selectId) {
    const select = document.getElementById(selectId);
    if (select.hasAttribute('multiple')) {
        // Multi-select: return array of selected values
        const values = Array.from(select.selectedOptions).map(opt => opt.value);

        // If "All" is selected or nothing is selected, return empty array (meaning show all)
        if (values.length === 0 || values.includes('')) {
            return [];
        }

        // Otherwise return the specific selected values
        return values;
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
        date_range_days: getSelectValue('filterDateRange'),
        selected_files: getSelectValue('filterReportFiles')
    };
}

// Save current filter state (for row selection bookmark)
function saveFilterState() {
    return getCurrentFilters();
}

// Restore filter state from saved snapshot
function restoreFilterState(filterState) {
    if (!filterState) return;

    // Map of filter keys to select element IDs
    const filterMap = {
        benchmark: 'filterBenchmark',
        model: 'filterModel',
        nic: 'filterNic',
        arch: 'filterArch',
        protocol: 'filterProtocol',
        test_type: 'filterTestType',
        cpu: 'filterCpu',
        kernel: 'filterKernel',
        rcos: 'filterRcos',
        topo: 'filterTopo',
        perf: 'filterPerf',
        offload: 'filterOffload',
        threads: 'filterThreads',
        pods_per_worker: 'filterScaleUp',
        scale_out_factor: 'filterScaleOut',
        wsize: 'filterWsize',
        date_range_days: 'filterDateRange',
        selected_files: 'filterReportFiles'
    };

    // Restore each filter value
    for (const [key, selectId] of Object.entries(filterMap)) {
        const select = document.getElementById(selectId);
        if (!select) continue;

        const value = filterState[key];
        const isMultiple = select.hasAttribute('multiple');

        if (isMultiple) {
            // Multi-select: set selected options
            Array.from(select.options).forEach(option => {
                option.selected = Array.isArray(value) && value.includes(option.value);
            });
        } else {
            // Single-select: set value
            select.value = value || '';
        }
    }

    // Apply the restored filters
    applyFilters();
}

// Apply filters from a result row (set all filters to match the row)
function applyRowFilters(result) {
    const filterMap = {
        benchmark: 'filterBenchmark',
        model: 'filterModel',
        nic: 'filterNic',
        arch: 'filterArch',
        protocol: 'filterProtocol',
        test_type: 'filterTestType',
        cpu: 'filterCpu',
        kernel: 'filterKernel',
        rcos: 'filterRcos',
        topo: 'filterTopo',
        perf: 'filterPerf',
        offload: 'filterOffload',
        threads: 'filterThreads',
        pods_per_worker: 'filterScaleUp',
        scale_out_factor: 'filterScaleOut',
        wsize: 'filterWsize'
    };

    // Set each filter to match the row's value
    for (const [key, selectId] of Object.entries(filterMap)) {
        const select = document.getElementById(selectId);
        if (!select) continue;

        const value = result[key];
        const isMultiple = select.hasAttribute('multiple');

        if (isMultiple) {
            // Multi-select: select only this value
            Array.from(select.options).forEach(option => {
                option.selected = (option.value === value || option.value === String(value));
            });
        } else {
            // Single-select: set value
            select.value = value || '';
        }
    }

    // Apply the row filters
    applyFilters();
}

// Handle row selection/deselection
function handleRowSelection(rowIndex, result) {
    const rowElement = document.querySelector(`#resultsTable tbody tr[data-row-index="${rowIndex}"]`);
    if (!rowElement) return;

    console.log('handleRowSelection called:', { rowIndex, selectedRow, hasSavedState: !!savedFilterState });

    // Check if clicking a different row while one is selected
    if (selectedRow !== null && selectedRow !== rowIndex) {
        console.log('Different row clicked while one is selected - ignoring');
        // Do nothing - must deselect current row first
        return;
    }

    // Check if deselecting current row
    if (selectedRow === rowIndex) {
        // Deselect: restore saved filter state
        console.log('Deselecting row, restoring filters');
        restoreFilterState(savedFilterState);
        selectedRow = null;
        savedFilterState = null;
        rowElement.classList.remove('row-selected');
    } else {
        // Select: save current filters and apply row filters
        console.log('Selecting row, saving filters and applying row filters');
        savedFilterState = saveFilterState();
        selectedRow = 0;  // After filtering, selected row will be at index 0
        rowElement.classList.add('row-selected');
        applyRowFilters(result);
    }
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
        date_range_days: 'Date Range',
        selected_files: 'Report Files'
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
async function clearFilters() {
    const filterIds = [
        'filterBenchmark', 'filterModel', 'filterNic', 'filterArch',
        'filterProtocol', 'filterTestType', 'filterCpu', 'filterKernel',
        'filterRcos', 'filterTopo', 'filterPerf', 'filterOffload',
        'filterThreads', 'filterScaleUp', 'filterScaleOut', 'filterWsize',
        'filterDateRange', 'filterReportFiles'
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

    // Refresh all filter options to show all available values
    await updateDynamicFilters();

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

    // Store results globally for row selection
    currentResults = results;

    // Note: We DON'T clear selectedRow/savedFilterState here anymore
    // They need to persist across re-renders to allow deselection

    // Now clear and repopulate the tbody
    const tbody = document.querySelector('#resultsTable tbody');
    tbody.innerHTML = '';

    results.forEach((result, index) => {
        const row = tbody.insertRow();
        const filePath = result.regulus_data || '';

        // Add row index for selection tracking
        row.setAttribute('data-row-index', index);

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
            <td>
                <span class="test-number-select"
                      style="cursor: pointer; text-decoration: underline; color: #0d6efd;"
                      title="Click to filter to this test"
                      onclick="handleRowSelection(${index}, currentResults[${index}])">
                    ${index + 1}
                </span>
            </td>
            <td>
                <span class="badge bg-primary badge-benchmark clickable-file"
                      title="Click to browse: ${filePath}"
                      style="cursor: pointer;"
                      onclick="openFileBrowser('${filePath.replace(/'/g, "\\'")}')">
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

    // Re-apply row highlighting if a row is selected
    if (selectedRow !== null) {
        const selectedRowElement = document.querySelector(`#resultsTable tbody tr[data-row-index="${selectedRow}"]`);
        if (selectedRowElement) {
            selectedRowElement.classList.add('row-selected');
        }
    }
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

        if (result.success) {
            const message = `Loaded ${result.total_reports} report(s) with ${result.total_results} result(s)`;
            alert('Reports reloaded successfully!\n' + message);
            location.reload();
        } else {
            const errorMsg = result.error || 'Unknown error';
            alert('Error reloading reports:\n' + errorMsg);
        }
    } catch (error) {
        console.error('Error reloading reports:', error);
        alert('Error reloading reports: ' + error.message);
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

// ============================================================================
// File Browser Functions
// ============================================================================

let currentBrowserPath = '';
let currentFileContent = '';
let drawerWidth = localStorage.getItem('drawer_width') || '40%';
let isResizing = false;

// Temporary storage for root paths while editing
let tempRootPaths = [];
let tempActiveIndex = 0;

// Open settings modal
function openSettings() {
    // Load all saved paths from localStorage
    tempRootPaths = [];
    let index = 1;
    while (true) {
        const savedPath = localStorage.getItem(`regulus_root_${index}`);
        if (savedPath) {
            tempRootPaths.push(savedPath);
            index++;
        } else {
            break;
        }
    }

    // If no paths exist, start with one empty entry
    if (tempRootPaths.length === 0) {
        tempRootPaths = [''];
    }

    // Load active index (localStorage uses 1-based, convert to 0-based)
    const savedActiveIndex = parseInt(localStorage.getItem('active_root_index') || '1');
    tempActiveIndex = savedActiveIndex - 1; // Convert to 0-based
    if (tempActiveIndex < 0 || tempActiveIndex >= tempRootPaths.length) {
        tempActiveIndex = 0;
    }

    // Render the paths
    renderRootPaths();

    // Show modal
    const modal = new bootstrap.Modal(document.getElementById('settingsModal'));
    modal.show();
}

// Render root paths dynamically
function renderRootPaths() {
    const container = document.getElementById('rootPathsList');
    container.innerHTML = '';

    tempRootPaths.forEach((path, index) => {
        const itemDiv = document.createElement('div');
        itemDiv.className = 'root-path-item d-flex align-items-center gap-2';
        itemDiv.onclick = (e) => {
            if (e.target.tagName !== 'INPUT' && e.target.tagName !== 'BUTTON') {
                selectRootPath(index);
            }
        };

        const radioInput = document.createElement('input');
        radioInput.className = 'form-check-input flex-shrink-0';
        radioInput.type = 'radio';
        radioInput.name = 'activeRoot';
        radioInput.checked = (index === tempActiveIndex);
        radioInput.onclick = (e) => {
            e.stopPropagation();
            selectRootPath(index);
        };

        const pathInput = document.createElement('input');
        pathInput.type = 'text';
        pathInput.className = 'form-control form-control-sm';
        pathInput.value = path;
        pathInput.placeholder = '/home/user/regulus-project';
        pathInput.onclick = (e) => e.stopPropagation();
        pathInput.oninput = (e) => {
            tempRootPaths[index] = e.target.value;
        };

        const deleteBtn = document.createElement('button');
        deleteBtn.type = 'button';
        deleteBtn.className = 'btn btn-sm btn-outline-danger flex-shrink-0';
        deleteBtn.innerHTML = '−';
        deleteBtn.title = 'Remove this path';
        deleteBtn.onclick = (e) => {
            e.stopPropagation();
            removeRootPath(index);
        };

        itemDiv.appendChild(radioInput);
        itemDiv.appendChild(pathInput);
        itemDiv.appendChild(deleteBtn);
        container.appendChild(itemDiv);
    });
}

// Select a root path as active
function selectRootPath(index) {
    tempActiveIndex = index;
    renderRootPaths();
}

// Add a new root path
function addRootPath() {
    tempRootPaths.push('');
    renderRootPaths();
}

// Remove a root path
function removeRootPath(index) {
    if (tempRootPaths.length <= 1) {
        alert('You must have at least one path entry.');
        return;
    }

    tempRootPaths.splice(index, 1);

    // Adjust active index if needed
    if (tempActiveIndex >= tempRootPaths.length) {
        tempActiveIndex = tempRootPaths.length - 1;
    }

    renderRootPaths();
}

// Save all settings
function saveSettings() {
    // Clear all existing root paths from localStorage
    let i = 1;
    while (localStorage.getItem(`regulus_root_${i}`)) {
        localStorage.removeItem(`regulus_root_${i}`);
        i++;
    }

    // Save only non-empty paths
    let saveIndex = 1;
    const nonEmptyPaths = [];
    tempRootPaths.forEach((path, index) => {
        const trimmedPath = path.trim();
        if (trimmedPath) {
            localStorage.setItem(`regulus_root_${saveIndex}`, trimmedPath);
            nonEmptyPaths.push({ index: saveIndex, originalIndex: index });
            saveIndex++;
        }
    });

    // Adjust and save active index (map old index to new index)
    let newActiveIndex = 1;
    for (let i = 0; i < nonEmptyPaths.length; i++) {
        if (nonEmptyPaths[i].originalIndex === tempActiveIndex) {
            newActiveIndex = nonEmptyPaths[i].index;
            break;
        }
    }
    localStorage.setItem('active_root_index', newActiveIndex.toString());

    // Save the active path as 'regulus_root' for backward compatibility
    const activePath = localStorage.getItem(`regulus_root_${newActiveIndex}`) || '';
    if (activePath) {
        localStorage.setItem('regulus_root', activePath);
    }

    // Close the modal
    const modal = bootstrap.Modal.getInstance(document.getElementById('settingsModal'));
    modal.hide();

    // Show confirmation
    alert('Settings saved successfully!');
}

// Get the active Regulus Root path
function getFirstRegulusRoot() {
    // Get the active root index (which path is selected)
    const activeIndex = parseInt(localStorage.getItem('active_root_index') || '1');
    const activePath = localStorage.getItem(`regulus_root_${activeIndex}`);

    if (activePath && activePath.trim()) {
        return activePath.trim();
    }

    // Fallback: find first non-empty path
    for (let i = 1; i <= 5; i++) {
        const path = localStorage.getItem(`regulus_root_${i}`);
        if (path && path.trim()) {
            return path.trim();
        }
    }

    // Final fallback to old single regulus_root
    return localStorage.getItem('regulus_root') || '';
}

// Get all non-empty Regulus Root paths
function getAllRegulusRoots() {
    const roots = [];
    for (let i = 1; i <= 5; i++) {
        const path = localStorage.getItem(`regulus_root_${i}`);
        if (path && path.trim()) {
            roots.push({ id: i, path: path.trim() });
        }
    }
    return roots;
}

// Open file browser at a specific path
async function openFileBrowser(relativePath) {
    const regulusRoot = getFirstRegulusRoot();

    if (!regulusRoot) {
        alert('Please configure Regulus Root Path in Settings first!');
        openSettings();
        return;
    }

    // Extract directory path from full path
    const dirPath = relativePath.substring(0, relativePath.lastIndexOf('/'));

    currentBrowserPath = dirPath;
    const success = await loadDirectoryListing(dirPath);

    // Only show drawer if loading succeeded
    if (success) {
        document.getElementById('fileBrowserDrawer').classList.add('open');
        document.body.classList.add('drawer-open');
    }
}

// Load directory listing
async function loadDirectoryListing(path) {
    const regulusRoot = getFirstRegulusRoot();

    try {
        const response = await fetch('/api/list_directory', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                regulus_root: regulusRoot,
                path: path
            })
        });

        const data = await response.json();

        if (!data.success) {
            alert('Error loading directory: ' + data.error);
            // Clear any previous file list content
            document.getElementById('fileList').innerHTML = '';
            return false;
        }

        // Update current path display
        document.getElementById('currentPath').textContent = path || '/';

        // Show file list, hide file viewer
        document.getElementById('fileList').style.display = 'block';
        document.getElementById('fileViewer').style.display = 'none';

        // Render file list
        renderFileList(data.items, path);

        return true;

    } catch (error) {
        console.error('Error loading directory:', error);
        alert('Error loading directory: ' + error.message);
        // Clear any previous file list content
        document.getElementById('fileList').innerHTML = '';
        return false;
    }
}

// Render file list
function renderFileList(items, currentPath) {
    const fileList = document.getElementById('fileList');
    fileList.innerHTML = '';

    // Add parent directory link if not at root
    if (currentPath && currentPath !== '/') {
        const parentDiv = document.createElement('div');
        parentDiv.className = 'file-list-item directory';
        parentDiv.innerHTML = '<span class="icon">📁</span><span>..</span>';
        parentDiv.onclick = () => {
            const parentPath = currentPath.substring(0, currentPath.lastIndexOf('/'));
            loadDirectoryListing(parentPath);
        };
        fileList.appendChild(parentDiv);
    }

    // Render items
    items.forEach(item => {
        const itemDiv = document.createElement('div');
        itemDiv.className = 'file-list-item ' + (item.is_directory ? 'directory' : 'file');

        const icon = item.is_directory ? '📁' : '📄';
        const sizeText = item.is_directory ? '' : ` (${formatFileSize(item.size)})`;

        itemDiv.innerHTML = `<span class="icon">${icon}</span><span>${item.name}${sizeText}</span>`;

        itemDiv.onclick = () => {
            if (item.is_directory) {
                loadDirectoryListing(item.path);
            } else {
                loadFile(item.path);
            }
        };

        fileList.appendChild(itemDiv);
    });
}

// Format file size
function formatFileSize(bytes) {
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
    return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
}

// Load and display file contents
async function loadFile(path) {
    const regulusRoot = getFirstRegulusRoot();

    try {
        showLoading();

        const response = await fetch('/api/read_file', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                regulus_root: regulusRoot,
                path: path
            })
        });

        const data = await response.json();

        if (!data.success) {
            alert('Error reading file: ' + data.error);
            return;
        }

        // Update current path
        document.getElementById('currentPath').textContent = path;

        // Show file viewer, hide file list
        document.getElementById('fileList').style.display = 'none';
        document.getElementById('fileViewer').style.display = 'block';

        // Display file content
        currentFileContent = data.content;
        document.getElementById('fileContent').textContent = data.content;

    } catch (error) {
        console.error('Error reading file:', error);
        alert('Error reading file: ' + error.message);
    } finally {
        hideLoading();
    }
}

// Back to file list
function backToFileList() {
    // Simply hide file viewer and show file list (preserves scroll position)
    document.getElementById('fileViewer').style.display = 'none';
    document.getElementById('fileList').style.display = 'block';

    // Update path display back to directory
    document.getElementById('currentPath').textContent = currentBrowserPath || '/';
}

// Copy file content to clipboard
function copyFileContent() {
    navigator.clipboard.writeText(currentFileContent).then(() => {
        alert('File content copied to clipboard!');
    }).catch(err => {
        console.error('Failed to copy:', err);
        alert('Failed to copy file content');
    });
}

// Close file browser drawer
function closeFileBrowser() {
    document.getElementById('fileBrowserDrawer').classList.remove('open');
    document.body.classList.remove('drawer-open');
}

// Initialize drawer resize functionality
document.addEventListener('DOMContentLoaded', function() {
    const drawer = document.getElementById('fileBrowserDrawer');
    const handle = document.getElementById('drawerResizeHandle');

    // Set initial drawer width
    setDrawerWidth(drawerWidth);

    // Mouse down on resize handle
    handle.addEventListener('mousedown', function(e) {
        isResizing = true;
        document.body.style.cursor = 'ew-resize';
        document.body.style.userSelect = 'none';
        e.preventDefault();
    });

    // Mouse move - resize drawer
    document.addEventListener('mousemove', function(e) {
        if (!isResizing) return;

        // Calculate new width based on mouse position
        const newWidth = window.innerWidth - e.clientX;
        const minWidth = 300; // Minimum 300px
        const maxWidth = window.innerWidth * 0.8; // Maximum 80% of screen

        if (newWidth >= minWidth && newWidth <= maxWidth) {
            const widthPx = newWidth + 'px';
            setDrawerWidth(widthPx);
            drawerWidth = widthPx;
        }
    });

    // Mouse up - stop resizing
    document.addEventListener('mouseup', function() {
        if (isResizing) {
            isResizing = false;
            document.body.style.cursor = '';
            document.body.style.userSelect = '';

            // Save to localStorage
            localStorage.setItem('drawer_width', drawerWidth);
        }
    });
});

// Set drawer width using CSS variable
function setDrawerWidth(width) {
    document.documentElement.style.setProperty('--drawer-width', width);
}
