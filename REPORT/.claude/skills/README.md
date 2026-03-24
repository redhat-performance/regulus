# Performance Analysis Skills

This directory contains specialized skills for network performance analysis using OpenSearch data.

## Available Skills

### 1. extract-data-correctly.md ⚠️ CRITICAL
**READ THIS FIRST** - Proper data extraction from report.json files.
- Fields can be in `common_params` OR `unique_params`
- Always check BOTH locations
- Prevents data loss and incomplete comparisons
- **We've been tripped up by this multiple times!**

### 2. query-performance-data.md
Query and search performance benchmark data from OpenSearch.
- Search by batch, topology, protocol, test type
- Filter and sort results
- Extract throughput and CPU metrics

### 3. compare-batches.md
Compare performance between two batches (e.g., DPU vs NIC-mode).
- Match tests by configuration parameters
- Calculate throughput and CPU differences
- Generate win/loss statistics
- Category-specific analysis

### 4. generate-reports.md
Generate comprehensive HTML and PDF performance reports.
- Professional styled HTML with charts
- CPU efficiency analysis in all sections
- PDF conversion using Chrome headless
- Executive summaries and recommendations

### 5. manage-batches.md
List, inspect, and manage test batches in OpenSearch.
- List all batches with metadata
- Get batch statistics
- Query batch details
- Index management operations

### 6. analyze-cpu-efficiency.md
Analyze CPU consumption and efficiency metrics.
- Calculate Gbps/CPU or trans/CPU ratios
- Compare CPU savings between datapaths
- Identify best/worst efficiency configurations
- Topology-specific CPU patterns

## How to Use Skills

Skills are invoked automatically by Claude Code when relevant to your request. You don't need to explicitly call them.

### Examples:

**"Show me the highest throughput for internode TCP stream"**
→ Uses `query-performance-data` skill

**"Compare DPU with NIC-mode batches"**
→ Uses `compare-batches` skill

**"Generate an HTML report comparing the two batches"**
→ Uses `generate-reports` skill

**"How many batches do we have in OpenSearch?"**
→ Uses `manage-batches` skill

**"What's the CPU efficiency difference between DPU and NIC-mode?"**
→ Uses `analyze-cpu-efficiency` skill

## Project Context

- **OpenSearch URL**: http://localhost:9200
- **Index Pattern**: regulus-results-*
- **Write Alias**: regulus-results-write
- **Data Fields**: topology, protocol, test_type, threads, wsize, cpu, performance_profile, mean, busy_cpu, batch_id

## Related Documentation

- `MCP_API_USAGE_GUIDE.md` - MCP API reference
- `QUICK_REFERENCE.md` - Query patterns
- `es_integration/` - OpenSearch integration code
