# Generate Performance Reports

Generate comprehensive HTML and PDF reports from performance comparison data.

## When to Use
- User asks for a report comparing batches
- User wants HTML or PDF output
- User needs professional presentation of results

## What This Skill Does

1. **Create HTML Report**
   - Professional styling with gradient headers
   - Responsive card-based summary layout
   - Color-coded performance indicators:
     - Green for winners/advantages
     - Red for losers/deficits
     - Blue for informational (CPU metrics)
   - Detailed comparison tables
   - Executive summary with key findings

2. **Include Critical Sections**
   - **Executive Summary**
     - Overall results and win rates
     - CPU efficiency highlights
     - Key findings bullet points
   - **Performance by Workload Type**
     - Summary cards for each category
     - Throughput averages
     - CPU averages
     - CPU efficiency metrics (Gbps/CPU or trans/CPU)
   - **Detailed Comparison Tables**
     - One table per category
     - Columns: Test params, DPU metrics, NIC-mode metrics, differences
     - CPU data: Busy CPUs, efficiency ratios
   - **Key Insights**
     - Topology-specific patterns
     - CPU efficiency advantages
     - Use case recommendations
   - **Footnotes**
     - Unmatched test configurations
     - Data source information

3. **CPU Metrics in All Sections**
   - Display busy CPU counts
   - Calculate efficiency (throughput per CPU)
   - Show CPU savings/overhead
   - Highlight efficiency leaders

4. **Generate PDF Version**
   - Use Google Chrome headless for conversion
   - Preserve all styling and tables
   - Print-ready format (1.9M typical size)
   - Command: `google-chrome --headless --disable-gpu --print-to-pdf=OUTPUT.pdf file://INPUT.html`

## File Naming Convention

Use descriptive names that indicate:
- What's being compared (DPU vs NIC-mode)
- Dataset identifier (BF3)
- Report type (FULL_COMPARISON)
- Format (.html or .pdf)

Example: `DPU_vs_NIC-mode_BF3_FULL_COMPARISON.html`

## Important Notes

- Always include CPU consumption data in all categories
- Use consistent card format across all workload types
- Maintain numerical precision (1-2 decimal places for Gbps, whole numbers for trans/sec)
- Green highlight CPU efficiency when one side is clearly better
- Don't overwrite existing reports - use new filenames for variants
