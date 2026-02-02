# Dashboard Test Data

This directory contains mockup JSON files for testing the dashboard functionality.

## Test Files Overview

### 1. mock-report-ovnk-cx7.json
- **Timestamp**: 2025-01-15 10:30
- **Benchmarks**: uperf, iperf
- **Configuration**:
  - Model: OVNK
  - NIC: CX7
  - Architecture: emerald_rapid
  - Kernel: 5.14.0-570.49.1.el9_6.x86_64
  - RCOS: 4.16
  - Topology: intranode
  - Performance: tuned
  - Offload: on
- **Results**: 95.4 Gbps (stream), 125K transactions/sec (rr), 94.2 Gbps (iperf)

### 2. mock-report-dpu-cx6.json
- **Timestamp**: 2025-01-16 14:20
- **Benchmarks**: uperf, trafficgen
- **Configuration**:
  - Model: DPU
  - NIC: CX6
  - Architecture: sapphire_rapids
  - Kernel: 5.14.0-580.12.1.el9_7.x86_64
  - RCOS: 4.17
  - Topology: internode
  - Performance: performance
  - Offload: on
- **Results**: 88.5 Gbps (stream), 85.3/85.1 Gbps (bidirec), 15.5M pps (trafficgen)

### 3. mock-report-sriov-e810.json
- **Timestamp**: 2025-01-17 09:45
- **Benchmarks**: uperf, iperf
- **Configuration**:
  - Model: SRIOV
  - NIC: E810
  - Architecture: ice_lake
  - Kernel: 5.14.0-570.49.1.el9_6.x86_64
  - RCOS: 4.16
  - Topology: intranode
  - Performance: balanced
  - Offload: off
- **Results**: 78.3 Gbps (stream), 98K transactions/sec (rr), 76.8 Gbps (iperf)

### 4. mock-report-macvlan-e910.json
- **Timestamp**: 2025-01-18 16:10
- **Benchmarks**: iperf
- **Configuration**:
  - Model: MACVLAN
  - NIC: E910
  - Architecture: emerald_rapid
  - Kernel: 5.14.0-580.12.1.el9_7.x86_64
  - RCOS: 4.17
  - Topology: intranode
  - Performance: powersave
  - Offload: on
- **Results**: 72.5 Gbps (stream), 70.1/69.8 Gbps (bidirec)

### 5. mock-report-ovnk-cx7-later.json
- **Timestamp**: 2025-01-19 11:30 (Later date for trend testing)
- **Benchmarks**: uperf
- **Configuration**:
  - Model: OVNK
  - NIC: CX7
  - Architecture: emerald_rapid
  - Kernel: 5.14.0-580.12.1.el9_7.x86_64 (Newer kernel)
  - RCOS: 4.17
  - Topology: intranode
  - Performance: tuned
  - Offload: on
- **Results**: 97.8 Gbps (stream), 128K transactions/sec (rr)
- **Purpose**: Shows performance improvement over time (compare with #1)

### 6. mock-report-ovnk-cx6.json
- **Timestamp**: 2025-01-14 08:15
- **Benchmarks**: uperf
- **Configuration**:
  - Model: OVNK
  - NIC: CX6 (Different from #1 for comparison)
  - Architecture: emerald_rapid
  - Kernel: 5.14.0-570.49.1.el9_6.x86_64
  - RCOS: 4.16
  - Topology: intranode
  - Performance: tuned
  - Offload: on
- **Results**: 82.6 Gbps (stream), 115K transactions/sec (rr)
- **Purpose**: Compare CX6 vs CX7 performance for OVNK model

### 7. mock-report-dpu-cx7.json
- **Timestamp**: 2025-01-16 18:45
- **Benchmarks**: uperf
- **Configuration**:
  - Model: DPU
  - NIC: CX7
  - Architecture: emerald_rapid
  - Kernel: 5.14.0-580.12.1.el9_7.x86_64
  - RCOS: 4.17
  - Topology: internode
  - Performance: performance
  - Offload: on
- **Results**: 92.1 Gbps (stream), 89.5/89.3 Gbps (bidirec)
- **Purpose**: Compare DPU performance across different NICs

## Data Coverage for Testing

### Filter Coverage:
- **Benchmarks**: uperf, iperf, trafficgen
- **Models**: OVNK, DPU, SRIOV, MACVLAN
- **NICs**: CX6, CX7, E810, E910
- **Architectures**: emerald_rapid, sapphire_rapids, ice_lake
- **Kernels**: 5.14.0-570.49.1.el9_6.x86_64, 5.14.0-580.12.1.el9_7.x86_64
- **RCOS**: 4.16, 4.17
- **CPUs**: 40, 58, 112
- **Topologies**: intranode, internode
- **Performance**: tuned, performance, balanced, powersave
- **Offload**: on, off
- **Protocols**: tcp, udp
- **Test Types**: stream, rr, bidirec, pps

### Timeline Coverage:
- Jan 14, 08:15 - OVNK CX6 (baseline)
- Jan 15, 10:30 - OVNK CX7
- Jan 16, 14:20 - DPU CX6
- Jan 16, 18:45 - DPU CX7
- Jan 17, 09:45 - SRIOV E810
- Jan 18, 16:10 - MACVLAN E910
- Jan 19, 11:30 - OVNK CX7 (newer kernel)

## Test Scenarios

### Scenario 1: Overview Tab Testing
1. Load all mock files
2. Check "Performance by Datapath Model" chart shows 4 models (OVNK, DPU, SRIOV, MACVLAN)
3. Check "Performance by Kernel" chart shows 2 kernel versions
4. Check "Top 10 Performers" table shows top results (OVNK CX7 later should be #1 at 97.8 Gbps)

### Scenario 2: Filter Testing
**Test all 12 filters:**
1. Filter by Model=OVNK → should show 3 results (files #1, #5, #6)
2. Filter by NIC=CX7 → should show 2 results (files #1, #5, #7)
3. Filter by Architecture=emerald_rapid → should show 5 results
4. Filter by Kernel=5.14.0-570 → should show 3 results
5. **Combined filters**: Model=OVNK + NIC=CX7 → should show 2 results (files #1, #5)

### Scenario 3: Trends Tab Testing
1. No grouping: Shows all results over time (Jan 14-19)
2. Group by Model: Shows 4 lines (OVNK, DPU, SRIOV, MACVLAN)
3. Group by Kernel: Shows 2 lines (5.14.0-570 vs 5.14.0-580)
4. **With filter**: Filter Model=OVNK, then group by NIC → Shows CX6 vs CX7 trend over time
   - CX6 starts at 82.6 Gbps (Jan 14)
   - CX7 starts at 95.4 Gbps (Jan 15)
   - CX7 improves to 97.8 Gbps (Jan 19 with newer kernel)

### Scenario 4: Comparison Tab Testing
**Test Cases:**
1. **Compare NICs (CX6 vs CX7) for OVNK**:
   - Filter: Model=OVNK, Benchmark=uperf, Test-Type=stream
   - Compare Field: NIC
   - Value A: CX6 → 82.6 Gbps
   - Value B: CX7 → Average of 95.4 and 97.8 = 96.6 Gbps
   - Expected: CX7 is ~17% better

2. **Compare Models (OVNK vs DPU) on CX7**:
   - Filter: NIC=CX7
   - Compare Field: model
   - Value A: OVNK → Average 96.6 Gbps
   - Value B: DPU → 92.1 Gbps
   - Expected: OVNK is ~4.9% better

3. **Compare Kernels for OVNK CX7**:
   - Filter: Model=OVNK, NIC=CX7
   - Compare Field: kernel
   - Value A: 5.14.0-570 → 95.4 Gbps
   - Value B: 5.14.0-580 → 97.8 Gbps
   - Expected: Newer kernel is ~2.5% better

4. **Compare Architectures**:
   - Compare Field: arch
   - Value A: ice_lake (SRIOV E810) → 78.3 Gbps
   - Value B: emerald_rapid (OVNK CX7) → 96.6 Gbps
   - Expected: emerald_rapid is ~23% better

### Scenario 5: Results Table Testing
1. Load all results → should show 17 iterations total
2. Search for "stream" → filters to stream test types
3. Sort by Mean (descending) → OVNK CX7 97.8 should be first
4. Filter Model=DPU → table updates to show only DPU results
5. Use DataTable search for "bidirec" → shows bidirectional tests

### Scenario 6: Performance Profiling Testing
Compare performance modes:
1. Filter Perf=tuned → OVNK results (95.4-97.8 Gbps)
2. Filter Perf=performance → DPU results (88.5-92.1 Gbps)
3. Filter Perf=balanced → SRIOV results (78.3 Gbps)
4. Filter Perf=powersave → MACVLAN results (72.5 Gbps)
Expected: tuned/performance > balanced > powersave

### Scenario 7: Topology Analysis
1. Filter Topo=intranode → OVNK, SRIOV, MACVLAN
2. Filter Topo=internode → DPU
Expected: Intranode generally shows better performance

## How to Use

1. **Copy test data to a test directory**:
```bash
mkdir -p /tmp/dashboard-test
cp dashboard/test_data/*.json /tmp/dashboard-test/
```

2. **Start the dashboard**:
```bash
python3 dashboard/run_dashboard.py --reports /tmp/dashboard-test --port 5000
```

3. **Access the dashboard**:
Open browser to http://localhost:5000

4. **Run through test scenarios** as outlined above

## Expected Summary Statistics

When all 7 files are loaded:

- **Total Reports**: 7
- **Total Results**: 10 files (some reports contain multiple result files)
- **Total Iterations**: 17 iterations
- **Benchmark Types**: 3 (uperf, iperf, trafficgen)
- **Date Range**: Jan 14, 2025 - Jan 19, 2025
- **Models**: 4 (OVNK, DPU, SRIOV, MACVLAN)
- **NICs**: 4 (CX6, CX7, E810, E910)
- **Architectures**: 3 (emerald_rapid, sapphire_rapids, ice_lake)

## Performance Rankings (Stream Tests)

1. OVNK + CX7 + emerald_rapid + kernel 580: **97.8 Gbps** ⭐
2. OVNK + CX7 + emerald_rapid + kernel 570: **95.4 Gbps**
3. DPU + CX7 + emerald_rapid: **92.1 Gbps**
4. DPU + CX6 + sapphire_rapids: **88.5 Gbps**
5. OVNK + CX6 + emerald_rapid: **82.6 Gbps**
6. SRIOV + E810 + ice_lake: **78.3 Gbps**
7. MACVLAN + E910 + emerald_rapid: **72.5 Gbps**
