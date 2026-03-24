# Analyze CPU Efficiency

Analyze CPU consumption and efficiency metrics from performance test results.

## When to Use
- User asks about CPU usage or efficiency
- User wants to compare CPU consumption between datapaths
- User needs CPU efficiency metrics (throughput per CPU)

## What This Skill Does

1. **Extract CPU Metrics**
   - `busy_cpu` field: Number of CPUs actively processing during test
   - `cpu` field: CPU allocation configuration (e.g., "2", "29", "58(Gu)")
   - Calculate efficiency ratios

2. **Calculate Efficiency Metrics**

   **For Stream Tests (Gbps):**
   - Efficiency = mean (Gbps) / busy_cpu
   - Units: Gbps per CPU
   - Higher is better

   **For Request-Response Tests (trans/sec):**
   - Efficiency = mean (trans/sec) / busy_cpu
   - Units: transactions per CPU
   - Higher is better

3. **CPU Comparison Analysis**
   - Average busy CPUs per datapath
   - CPU savings/overhead percentage
   - Efficiency ratio comparison
   - Identify configurations with best efficiency

4. **Category-Specific Analysis**

   **Internode Stream:**
   - Typically shows significant CPU savings for DPU
   - DPU: ~39 busy CPUs, 6.99 Gbps/CPU
   - NIC-mode: ~59.5 busy CPUs, 3.93 Gbps/CPU

   **Intranode Stream:**
   - DPU still saves CPUs but NIC-mode has higher total throughput
   - Trade-off: CPU efficiency vs absolute performance

   **Request-Response:**
   - Variable results depending on topology
   - Measure in transactions per CPU
   - Consider both throughput and CPU consumption

5. **Key Observations to Report**
   - CPU savings percentage (e.g., "34.5% fewer CPUs")
   - Efficiency improvement (e.g., "78% better CPU efficiency")
   - Best/worst efficiency configurations
   - Topology-specific patterns

## Example Analysis

```python
# For a set of matching tests
dpu_total_tp = sum(dpu_gbps)
dpu_total_cpu = sum(dpu_busy_cpu)
dpu_efficiency = dpu_total_tp / dpu_total_cpu

nic_total_tp = sum(nic_gbps)
nic_total_cpu = sum(nic_busy_cpu)
nic_efficiency = nic_total_tp / nic_total_cpu

cpu_savings_pct = (nic_total_cpu - dpu_total_cpu) / nic_total_cpu * 100
efficiency_improvement = (dpu_efficiency / nic_efficiency - 1) * 100
```

## Important Notes

- All 39 matching tests in recent comparison have CPU data
- CPU efficiency is a critical metric alongside throughput
- Hardware offload (DPU) typically shows CPU savings for internode traffic
- Kernel optimizations (NIC-mode) may use more CPUs but deliver higher throughput for intranode traffic
- Report both absolute CPU counts AND efficiency ratios
