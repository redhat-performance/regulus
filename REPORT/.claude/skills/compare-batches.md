# Compare Performance Batches

Compare performance results between two batches (e.g., DPU vs NIC-mode) with matching test configurations.

## When to Use
- User asks to compare DPU with NIC-mode (or OVNK)
- User wants to see which datapath performs better
- User needs analysis across matching test configurations

## What This Skill Does

1. **Identify Matching Tests**
   - Match tests by these criteria:
     - topology (internode/intranode)
     - protocol (tcp/udp)
     - test_type (stream/rr/crr)
     - threads
     - wsize
     - cpu
     - performance_profile (single-numa-node vs None)
   - Count total matches and coverage percentage

2. **Calculate Metrics**
   - Throughput difference (Gbps or trans/sec)
   - Throughput difference percentage
   - CPU consumption (busy_cpu) for each batch
   - CPU efficiency (Gbps/CPU or trans/CPU)
   - Win/loss count by category

3. **Categorize Results**
   - Group by workload type:
     - Internode TCP Stream
     - Intranode TCP Stream
     - Internode Request-Response (TCP/UDP RR)
     - Intranode Request-Response (TCP/UDP RR)
   - Calculate averages per category
   - Identify best/worst performers

4. **Generate Analysis**
   - Overall win rate
   - Average performance advantage/deficit
   - CPU efficiency comparison
   - Key findings and patterns
   - Recommendations based on topology

## Process

1. Fetch all results from batch 1
2. Fetch all results from batch 2
3. Match tests by all criteria (not just some)
4. For each match, calculate:
   - Throughput difference
   - CPU difference
   - Efficiency metrics
5. Group results by category
6. Generate summary statistics
7. Create comparison tables

## Output

Provide:
- Summary: X/Y matching configs (Z% coverage)
- Win/loss breakdown
- Category-specific analysis
- Detailed comparison tables with CPU data
- Footnotes explaining unmatched tests
