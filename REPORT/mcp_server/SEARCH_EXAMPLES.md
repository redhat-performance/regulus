# Search Query Examples

## Understanding Benchmark Metrics

### CPU Metric Interpretation

**IMPORTANT**: The `CPU` value shown in search results is **NOT a percentage**.

- **CPU is an aggregated sum** of CPU utilization across all CPUs (in mpstat terms: sum of % busy)
- **Example**: `CPU: 44.8` means 44.8 CPU-equivalents of work were consumed
- If you have 52 CPUs each running at 50% busy, this would show as `CPU: 26.0`
- If you have 4 CPUs each running at 100% busy, this would show as `CPU: 4.0`

### Internode Test Architecture

- **Each internode benchmark uses 2 workers** (one sender, one receiver on different nodes)
- When you see `CPUs: 2` in the configuration, that's per worker
- **Total CPU allocation** for an internode test = 2 workers × CPUs per worker
- The `CPU` busy metric represents aggregated utilization across both workers

### Example Analysis

```
Throughput: 329.80 Gbps, CPU: 44.8
CPUs: 2 (per worker)
Topology: internode
```

**Interpretation**:
- Total CPUs allocated: 2 workers × 2 CPUs/worker = 4 CPUs
- CPU busy: 44.8 CPU-equivalents consumed
- This indicates heavy utilization beyond just the 4 allocated CPUs (likely spreading to other cores)
- Efficiency: 329.80 Gbps / 44.8 CPU = 7.36 Gbps per CPU-equivalent

---

## All Available Filters

Run `./show_keywords.sh` to see current valid values for each filter.

### Filter Reference

| Filter | Example Values | Description |
|--------|----------------|-------------|
| `--benchmark` | `uperf`, `iperf` | Benchmark tool used |
| `--model` | `OVNK`, `DPU`, `SRIOV` | Network datapath model |
| `--nic` | `E810`, `CX6`, `CX7`, `BF3` | NIC hardware type |
| `--topology` | `intranode`, `internode` | Pod placement topology |
| `--protocol` | `tcp`, `udp` | Network protocol |
| `--test-type` | `stream`, `rr`, `crr` | Benchmark test type |
| `--kernel` | `5.14.0-570.49.1.el9_6.x86_64` | Kernel version |
| `--arch` | `INTEL(R)_XEON(R)_GOLD_6548Y+` | CPU architecture |
| `--cpu` | `4`, `26`, `52` | CPU count |
| `--execution-label` | `baseline-q1`, `non-accelerated`, `weekly-run-2025-w01` | Campaign/experiment label |
| `--min-throughput` | `90`, `1000000` | Minimum throughput value |
| `--max-throughput` | `100`, `5000000` | Maximum throughput value |
| `--size` | `10`, `50`, `100` | Number of results to return |

## Basic Queries

### By Benchmark Type
```bash
# All uperf results
./build_and_run.sh search --benchmark uperf

# All iperf results
./build_and_run.sh search --benchmark iperf
```

### By Datapath Model
```bash
# All OVN-Kubernetes results
./build_and_run.sh search --model OVNK

# All DPU results
./build_and_run.sh search --model DPU

# All SR-IOV results
./build_and_run.sh search --model SRIOV
```

### By NIC Type
```bash
# All Intel E810 results
./build_and_run.sh search --nic E810

# All Mellanox CX6 results
./build_and_run.sh search --nic CX6

# All BlueField-3 results
./build_and_run.sh search --nic BF3
```

### By Topology
```bash
# All intranode (same node) tests
./build_and_run.sh search --topology intranode

# All internode (different nodes) tests
./build_and_run.sh search --topology internode
```

### By Protocol
```bash
# All TCP tests
./build_and_run.sh search --protocol tcp

# All UDP tests
./build_and_run.sh search --protocol udp
```

### By Test Type
```bash
# All stream (throughput) tests
./build_and_run.sh search --test-type stream

# All request-response tests
./build_and_run.sh search --test-type rr

# All connection rate tests
./build_and_run.sh search --test-type crr
```

## Throughput-Based Queries

### High Performance Results
```bash
# Results with throughput > 90 (Gbps typically)
./build_and_run.sh search --min-throughput 90

# Top 20 high-performance results
./build_and_run.sh search --min-throughput 90 --size 20

# Results in range 80-100
./build_and_run.sh search --min-throughput 80 --max-throughput 100

# Top 50 results across all benchmarks
./build_and_run.sh search --size 50
```

### Low Performance Results (for debugging)
```bash
# Results with throughput < 10
./build_and_run.sh search --max-throughput 10

# Results in range 0-1 (potential failures)
./build_and_run.sh search --max-throughput 1
```

## Combined Queries

### Network Configuration Analysis
```bash
# OVNK + intranode + TCP
./build_and_run.sh search --model OVNK --topology intranode --protocol tcp

# DPU + internode + UDP
./build_and_run.sh search --model DPU --topology internode --protocol udp

# SRIOV + intranode + TCP + stream
./build_and_run.sh search --model SRIOV --topology intranode \
  --protocol tcp --test-type stream
```

### Hardware-Specific Queries
```bash
# E810 + OVNK + intranode
./build_and_run.sh search --nic E810 --model OVNK --topology intranode

# BF3 + DPU + high throughput
./build_and_run.sh search --nic BF3 --model DPU --min-throughput 80

# 4 CPUs + DPU model
./build_and_run.sh search --cpu 4 --model DPU
```

### Benchmark-Specific Analysis
```bash
# uperf + stream + high throughput
./build_and_run.sh search --benchmark uperf --test-type stream --min-throughput 80

# uperf + rr (request-response) + intranode
./build_and_run.sh search --benchmark uperf --test-type rr --topology intranode

# iperf + TCP + internode
./build_and_run.sh search --benchmark iperf --protocol tcp --topology internode
```

### Complex Multi-Filter Queries
```bash
# Full stack specification: OVNK + BF3 + intranode + TCP + stream + high perf
./build_and_run.sh search \
  --model OVNK \
  --nic BF3 \
  --topology intranode \
  --protocol tcp \
  --test-type stream \
  --min-throughput 90 \
  --size 20

# DPU + 4 CPUs + internode + UDP + rr
./build_and_run.sh search \
  --model DPU \
  --cpu 4 \
  --topology internode \
  --protocol udp \
  --test-type rr

# uperf + E810 + OVNK + TCP + throughput range
./build_and_run.sh search \
  --benchmark uperf \
  --nic E810 \
  --model OVNK \
  --protocol tcp \
  --min-throughput 50 \
  --max-throughput 100
```

## Performance Analysis Queries

### Find Best Performers
```bash
# Top 10 overall
./build_and_run.sh search --size 10

# Top 10 intranode
./build_and_run.sh search --topology intranode --size 10

# Top 10 internode
./build_and_run.sh search --topology internode --size 10

# Best OVNK performance
./build_and_run.sh search --model OVNK --size 5

# Best DPU performance
./build_and_run.sh search --model DPU --size 5
```

### Compare Topologies
```bash
# Best intranode TCP stream
./build_and_run.sh search --topology intranode --protocol tcp --test-type stream --size 5

# Best internode TCP stream
./build_and_run.sh search --topology internode --protocol tcp --test-type stream --size 5
```

### Compare Protocols
```bash
# TCP performance
./build_and_run.sh search --protocol tcp --test-type stream --size 10

# UDP performance
./build_and_run.sh search --protocol udp --test-type stream --size 10
```

### Compare NICs
```bash
# E810 performance
./build_and_run.sh search --nic E810 --test-type stream --size 5

# CX6 performance
./build_and_run.sh search --nic CX6 --test-type stream --size 5

# BF3 performance
./build_and_run.sh search --nic BF3 --test-type stream --size 5
```

## Campaign/Execution Label Queries

**Use Case**: Compare performance across different test campaigns, baselines, or weekly runs.

### Filter by Execution Label
```bash
# All results from a specific campaign
./build_and_run.sh search --execution-label non-accelerated

# Baseline campaign results
./build_and_run.sh search --execution-label baseline-q1-2025

# Weekly regression run
./build_and_run.sh search --execution-label weekly-run-2025-w01
```

### Compare Campaigns (Manual)
```bash
# Get baseline performance
./build_and_run.sh search --execution-label baseline-q1 --model DPU --topology internode --size 10

# Get optimized performance
./build_and_run.sh search --execution-label optimized-q1 --model DPU --topology internode --size 10

# Compare outputs manually to see performance delta
```

### Campaign-Specific Analysis
```bash
# Best DPU results from non-accelerated campaign
./build_and_run.sh search --execution-label non-accelerated --model DPU --size 5

# Best DPU results from accelerated campaign
./build_and_run.sh search --execution-label dpu-accelerated --model DPU --size 5

# Weekly run internode TCP stream results
./build_and_run.sh search --execution-label weekly-run-2025-w05 --topology internode --protocol tcp --test-type stream
```

## Debugging and Investigation

### Find Anomalies
```bash
# Very low throughput (potential problems)
./build_and_run.sh search --max-throughput 1 --size 20

# Specific kernel version issues
./build_and_run.sh search --kernel 5.14.0-570.49.1.el9_6.x86_64 --max-throughput 10
```

### Environment-Specific
```bash
# Specific CPU count
./build_and_run.sh search --cpu 26

# Specific architecture
./build_and_run.sh search --arch "INTEL(R)_XEON(R)_GOLD_6548Y+"

# Specific kernel + model
./build_and_run.sh search --kernel 5.14.0-570.49.1.el9_6.x86_64 --model OVNK
```

## Tips

1. **Always run `./show_keywords.sh` first** to see valid values
2. **Start broad, then narrow down** - begin with single filters, add more as needed
3. **Use `--size` to control output** - default is 10, max is 100
4. **Combine throughput ranges with other filters** for targeted analysis
5. **Results are sorted by throughput** - highest performance first
6. **Check the count** - "Found X total results" tells you match count before size limit

## Getting Help

```bash
# See all search options
./build_and_run.sh search --help

# See valid keyword values
./show_keywords.sh
```
