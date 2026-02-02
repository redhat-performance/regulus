# Regulus/Crucible Performance Benchmark Report Generator

A sophisticated Python-based tool for collecting, processing, and visualizing performance benchmark results from distributed test runs. Supports uperf, iperf, trafficgen, and fio benchmarks with multi-iteration and multi-result capabilities.

## Quick Start

```bash
# Basic usage - generate all formats
cd $REG_ROOT
build_report/build_report --formats html csv json --output my-report

# Scan specific directory
build_report/build_report --root /path/to/results --output report-name

# Single format
build_report/build_report --formats html --output performance-summary
```

**Outputs:**
- `my-report.json` - Structured data with schema validation
- `my-report.html` - Interactive report with filtering, charts, tables
- `my-report.csv` - Tabular data with clickable hyperlinks

**Note:** A web-based interactive dashboard for visualizing multiple reports is available at `REPORT/dashboard/`. See `REPORT/dashboard/README.md` for details.

## Architecture Overview

### 6-Stage ETL Pipeline

```
Input: result-summary.txt files
   ↓
[1] FILE DISCOVERY → [2] CONTENT PARSING → [3] RULE APPLICATION
   ↓                      ↓                      ↓
[4] DATA EXTRACTION → [5] TRANSFORMATION → [6] OUTPUT GENERATION
   ↓                      ↓                      ↓
Output: JSON/HTML/CSV/XML reports
```

### Directory Structure

```
build_report/
├── build_report              # Bash entry point (sets PYTHONPATH, invokes Python)
├── reg-report.py            # Python CLI entry point
├── factories.py             # Factory pattern for orchestrator creation
│
├── models/                  # Data models and enums
│   ├── data_models.py      # FileInfo, TestIteration, ProcessedResult, etc.
│   └── enums.py            # SchemaVersion, ResultStatus
│
├── interfaces/              # Protocol definitions (contracts)
│   └── protocols.py        # Interfaces for all components
│
├── schema/                  # JSON schema management
│   ├── schema_manager.py   # Schema validation and upgrades
│   └── versions/           # v1.0, v1.1, v2.0 schemas
│
├── discovery/               # File finding and traversal
│   └── file_discovery.py   # Recursive directory scanning (depth 8)
│
├── parsing/                 # Content reading
│   └── content_parser.py   # UTF-8 file reading with caching
│
├── rules/                   # Regex extraction rules
│   └── rule_engine.py      # Built-in rules for uperf, iperf, trafficgen
│
├── extraction/              # Data extraction from files
│   └── data_extractor.py   # Multi-iteration, multi-result extraction
│
├── transformation/          # Data processing
│   └── data_transformer.py # Structure data, calculate statistics
│
├── output/                  # Report generation
│   └── generators.py       # JSON, HTML, CSV, XML generators
│
└── orchestration/           # Workflow coordination
    └── orchestrator.py     # Standard, Batch, Parallel orchestrators
```

**Total:** 25 Python files implementing a complete ETL pipeline

## Key Components

### 1. Data Models (`models/data_models.py`)

- **`FileInfo`** (lines 29-34) - File metadata (path, size, modified_time)
- **`TestIteration`** (lines 88-105) - Single test iteration with params and results
- **`MultiResultExtractedData`** (lines 108-125) - File with multiple iterations
- **`ProcessedResult`** (lines 63-68) - Final transformed output
- **`SchemaInfo`** (lines 72-81) - Schema version metadata

### 2. Rule Engine (`rules/rule_engine.py`)

**Built-in Benchmark Rules:**
- **Default** (lines 24-32): Basic fields (benchmark, run-id, result)
- **Trafficgen** (lines 34-50): Network traffic generation metrics
  - Extracts: period_length, samples, mean, min, max, stddev
  - Metadata: tags, iteration-id, sample-id, period ranges

**Features:**
- File-based rule loading from JSON (lines 75-163)
- Dynamic runtime rule modification (lines 165-224)
- Configurable per-benchmark rule sets

### 3. Data Extractor (`extraction/data_extractor.py`)

**Multi-Format Support:**
- **Uperf results** (lines 219-272): Gbps/Mbps throughput, CPU utilization
- **Iperf results** (lines 275-328): rx-Gbps, tx-Gbps metrics
- **Trafficgen results** (lines 330-345): Generic traffic metrics

**Key Capabilities:**
- Multiple iterations per file (lines 102-139)
- Multiple results per iteration (lines 184-217)
- Sample-level data extraction (lines 166-182)
- Key tag extraction: model, perf, offload, kernel, rcos, cpu, topo (lines 375-386)

### 4. Output Generators (`output/generators.py`)

#### JSON Generator (lines 20-61)
- Schema-compliant output
- Generation metadata
- Benchmark summaries

#### HTML Generator (lines 562-1701) - **Most Sophisticated**
- **Interactive regex filter** with live match count (lines 1571-1666)
- **Summary cards** showing total files, iterations, success rate (lines 696-738)
- **Per-benchmark sections** with statistics (lines 741-776)
- **Detailed metrics tables** - one row per iteration (lines 929-1000)
- **File hyperlinks** to source files (lines 979-984)
- **Kernel/RCOS version display** (lines 638-656)
- **Bootstrap CSS + Chart.js** integration
- **Responsive design**

#### CSV Generator (lines 198-431)
- **One row per iteration** (not per file!)
- **Clickable hyperlinks** using Excel HYPERLINK formula (lines 306-308)
- **Columns:** file, benchmark, model, perf, config, cpu, test_type, threads, wsize, rsize, samples, mean, unit, busyCPU, stddev%, iteration_id, protocol
- **Custom parameter detection** for iperf tests (lines 373-383)

#### XML Generator (lines 432-502)
- Alternative structured format

### 5. Orchestrators (`orchestration/orchestrator.py`)

Three orchestrator types:

1. **`ReportOrchestrator`** (lines 18-168) - Standard sequential processing
2. **`BatchReportOrchestrator`** (lines 170-226) - Multiple directories
3. **`ParallelReportOrchestrator`** (lines 228-325) - Concurrent with ThreadPoolExecutor

**Statistics Tracked:**
- Files discovered/processed/failed
- Total duration
- Average processing time per file
- Success rate percentage

## Input Format

Expected `result-summary.txt` format:

```
benchmark: uperf
run-id: 550e8400-e29b-41d4-a716-446655440000
tags: model=e810 perf=baseline offload=on kernel=5.14 rcos=4.12 cpu=icx topo=linear
common params: protocol=tcp nthreads=4

iteration-id: 7A3B9C2E-1234-5678-90AB-CDEF12345678
unique params: test-type=stream wsize=65536 rsize=65536
sample-id: F1E2D3C4-5678-90AB-CDEF-123456789ABC
period range: begin: 10 end: 70
period length: 60.0 seconds
result: (uperf::Gbps) samples: 98.5 99.2 98.8 mean: 98.83 min: 98.5 max: 99.2 stddev: 0.29 stddevpct: 0.29 CPU: 45.2

iteration-id: 8B4C0D3F-2345-6789-01BC-DEF123456789
unique params: test-type=stream wsize=131072 rsize=131072
sample-id: A2B3C4D5-6789-01BC-DEF1-23456789ABCD
period range: begin: 80 end: 140
period length: 60.0 seconds
result: (uperf::Gbps) samples: 99.1 99.5 99.3 mean: 99.30 min: 99.1 max: 99.5 stddev: 0.17 stddevpct: 0.17 CPU: 46.8
result: (iperf::rx-Gbps) samples: 50.2 50.5 mean: 50.35 min: 50.2 max: 50.5 stddev: 0.15 stddevpct: 0.30
```

## Output Formats

### JSON Structure

```json
{
  "schema_info": {
    "version": "2.0",
    "description": "Performance benchmark results"
  },
  "generation_info": {
    "total_results": 150,
    "successful_results": 148,
    "timestamp": "2025-01-17T10:30:00",
    "benchmarks": ["uperf", "iperf", "trafficgen"]
  },
  "results": [
    {
      "file_path": "/path/to/result-summary.txt",
      "benchmark": "uperf",
      "run_id": "550e8400...",
      "common_params": {"protocol": "tcp", "nthreads": "4"},
      "key_tags": {"model": "e810", "perf": "baseline"},
      "total_iterations": 2,
      "iterations": [
        {
          "iteration_id": "7A3B9C2E...",
          "unique_params": {"test-type": "stream", "wsize": "65536"},
          "samples": [{"sample_id": "F1E2D3C4...", "begin": 10, "end": 70}],
          "results": [
            {
              "type": "Gbps",
              "mean": 98.83,
              "min": 98.5,
              "max": 99.2,
              "stddev": 0.29,
              "stddevpct": 0.29,
              "busyCPU": 45.2
            }
          ]
        }
      ]
    }
  ]
}
```

### HTML Output Features

- **Interactive regex filtering** - Live match count with error handling
- **Summary statistics cards** - Total files, iterations, success rate
- **Per-benchmark sections** - Individual statistics per benchmark type
- **Sortable tables** - One row per iteration with all metrics
- **Clickable file links** - Direct navigation to source files
- **Chart.js visualizations** - Performance trends and distributions
- **Responsive design** - Works on desktop and mobile

### CSV Output

```csv
file,benchmark,model,perf,config,cpu,test_type,threads,wsize,rsize,samples,mean,unit,busyCPU,stddev%,iteration_id,protocol
=HYPERLINK("http://host:8000/path/file.txt","file.txt"),uperf,e810,baseline,"3,2,linear",icx,"tcp, stream",4,65536,65536,3,98.83,Gbps,45.2,0.29,7A3B9C2E...,tcp
```

**Features:**
- One row per iteration (not per file)
- Excel-compatible HYPERLINK formulas
- Config shorthand: "pods-per-worker,scale_out_factor,topo"
- Custom parameter detection for non-standard iperf tests

## CLI Options

```bash
build_report/build_report [OPTIONS]

Options:
  --root DIR           Directory to scan (default: '.')
  --output NAME        Base name for output files (default: 'report')
  --formats FORMATS    Output formats: json, html, csv (can specify multiple)
  --base-url URL       Base URL for CSV hyperlinks (auto-generated if not provided)
```

## Special Features

1. **Multi-Iteration Support** - Handles multiple test iterations per file with different parameters
2. **Multi-Result Support** - Multiple result types per iteration (e.g., uperf + iperf in same test)
3. **Regex Filtering** - Interactive HTML filtering with live match count and error handling
4. **Hyperlinked CSV** - Excel-compatible HYPERLINK formulas for easy navigation
5. **Key Tags Extraction** - Automatically extracts model, perf, offload, kernel, RCOS, CPU, topo tags
6. **Config Shorthand** - Compact format "pods-per-worker,scale_out_factor,topo" (e.g., "3,2,linear")
7. **Custom Parameter Detection** - Identifies iperf tests with non-standard passthrough parameters
8. **Schema Versioning** - Support for v1.0, v1.1, v2.0 with upgrade paths
9. **Parallel Processing** - Optional multi-threaded file processing (`ParallelReportOrchestrator`)
10. **Content Caching** - Optional caching based on file modification time

## Architecture Patterns

### Dependency Injection
All components use protocol-based interfaces (`interfaces/protocols.py`) for loose coupling:
- `FileDiscoveryInterface`
- `ContentParserInterface`
- `RuleEngineInterface`
- `DataExtractorInterface`
- `DataTransformerInterface`
- `OutputGeneratorInterface`
- `SchemaManagerInterface`

### Factory Pattern
`factories.py` creates orchestrators with injected dependencies, enabling easy testing and extension.

### Protocol-Based Design
All interfaces defined as Python Protocols (PEP 544) for structural subtyping and duck typing.

## Extension Points

### Adding New Benchmark Types

1. **Add extraction rules** in `rules/rule_engine.py`:
```python
def _initialize_builtin_rules(self) -> None:
    self.rule_sets["mybench"] = BenchmarkRuleSet(
        benchmark_type="mybench",
        metadata_rules=[...],
        result_rules=[...]
    )
```

2. **Add result parsing** in `extraction/data_extractor.py`:
```python
def _extract_mybench_results(self, content: str) -> List[Dict[str, Any]]:
    # Custom parsing logic
    pass
```

3. **Update HTML/CSV generators** in `output/generators.py` if needed

### Adding New Output Formats

Implement `OutputGeneratorInterface` and add to `MultiFormatGenerator`:
```python
class MyFormatGenerator:
    def generate(self, results: List[ProcessedResult], output_path: str) -> None:
        # Implementation
        pass
```

## Dependencies

**Required:**
- Python 3.9+
- Standard library: `pathlib`, `json`, `csv`, `xml`, `re`, `datetime`, `concurrent.futures`

**Optional:**
- `jsonschema` - For JSON schema validation
- Chart.js (CDN) - For HTML report charts

## Performance Characteristics

- **File Discovery:** Recursively scans up to depth 8, stops when match found
- **Processing:** Handles ~100+ files efficiently in sequential mode
- **Parallel Mode:** ThreadPoolExecutor for concurrent processing of large datasets
- **Caching:** Optional content caching reduces re-reads on unchanged files
- **Memory:** Processes files incrementally, doesn't load entire dataset into memory

## Workflow Details

### Stage 1: File Discovery (`discovery/file_discovery.py`)
- Recursively scans directory tree up to depth 8
- Finds files matching pattern (default: "result-summary.txt")
- Stops descending when a match is found in a directory
- Returns `FileInfo` objects with path, size, modified_time

### Stage 2: Content Parsing (`parsing/content_parser.py`)
- Reads file contents with UTF-8 encoding
- Optional caching based on modification time
- Handles encoding errors gracefully

### Stage 3: Rule Selection (`rules/rule_engine.py`)
- Extracts benchmark type from content (e.g., "trafficgen", "iperf")
- Retrieves appropriate regex extraction rules for that benchmark

### Stage 4: Data Extraction (`extraction/data_extractor.py`)
- Applies regex patterns to extract:
  - Benchmark metadata (run-id, tags, common params)
  - Multiple test iterations per file
  - Multiple results per iteration (uperf, iperf, trafficgen)
  - Sample data (sample-id, period ranges, duration)
  - Performance metrics (mean, min, max, stddev, throughput)

### Stage 5: Data Transformation (`transformation/data_transformer.py`)
- Converts raw extracted data into structured format
- Generates test descriptions
- Calculates summary statistics
- Adds processing metadata and timestamps

### Stage 6: Output Generation (`output/generators.py`)
- **JSON**: Schema-validated JSON with metadata
- **HTML**: Interactive reports with regex filtering, tables, charts
- **CSV**: One row per iteration with clickable file links
- **XML**: Alternative structured format

## Schema Versions

### v1.0 (Basic)
- Simple structure with file paths and results
- Minimal metadata

### v1.1 (Enhanced)
- Added generation metadata
- Benchmark summaries
- Success rate tracking

### v2.0 (Advanced)
- Full JSON schema validation
- Custom benchmark schemas
- Upgrade path from v1.0/v1.1
- Enhanced error reporting

## Common Use Cases

### 1. Generate All Reports
```bash
build_report/build_report --formats html csv json --output full-report
```

### 2. HTML Only for Quick Review
```bash
build_report/build_report --formats html --output quick-view
```

### 3. CSV for Excel Analysis
```bash
build_report/build_report --formats csv --output excel-export
```

### 4. Scan Specific Test Directory
```bash
build_report/build_report --root /data/perf-tests/2025-01 --output jan-results
```

## Troubleshooting

### No Files Found
- Check that `result-summary.txt` files exist in the target directory
- Verify directory depth < 8 (configurable in `file_discovery.py`)

### Regex Errors in HTML
- Use the interactive regex tester in the HTML report
- Check for escaped characters and valid regex syntax

### Schema Validation Failures
- Ensure `jsonschema` is installed for v2.0 validation
- Check that extracted data matches expected schema format

### CSV Links Not Working
- Verify `--base-url` is set correctly
- Ensure HTTP server is running on the specified port (default: 8000)

## Future Enhancements

- Support for additional benchmark types (fio, netperf, etc.)
- Real-time streaming updates for long-running scans
- Database backend for historical tracking
- RESTful API for programmatic access
- Advanced filtering and grouping in HTML reports
- Export to Grafana/Prometheus formats

## Contributing

When adding features:
1. Follow the protocol-based interface pattern
2. Add appropriate unit tests
3. Update schema versions if data model changes
4. Document new extraction rules in `regex-filter-guide.md`
5. Update this README with new capabilities

## License

[Add license information]

## Contact

[Add contact/support information]
