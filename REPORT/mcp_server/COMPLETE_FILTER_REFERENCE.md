# Complete Search Filter Reference

## All Available Filters (21 total)

### String Filters (exact match)

| Filter | CLI Argument | Example Values | ES Field |
|--------|-------------|----------------|----------|
| Benchmark | `--benchmark` | `uperf`, `iperf` | `benchmark` |
| Model | `--model` | `OVNK`, `DPU`, `SRIOV`, `MACVLAN` | `model` |
| NIC | `--nic` | `E810`, `CX6`, `CX7`, `BF3`, `X550` | `nic` |
| Topology | `--topology` | `intranode`, `internode` | `topology` |
| Protocol | `--protocol` | `tcp`, `udp` | `protocol` |
| Test Type | `--test-type` | `stream`, `rr`, `crr` | `test_type` |
| Kernel | `--kernel` | `5.14.0-570.49.1.el9_6.x86_64` | `kernel` |
| RCOS | `--rcos` | `9.6.20250925-0` | `rcos` |
| Architecture | `--arch` | `INTEL(R)_XEON(R)_GOLD_6548Y+` | `arch` |
| CPU Count | `--cpu` | `4`, `26`, `52`, `4(Gu)` | `cpu` |
| Performance Profile | `--performance-profile` | `single-numa-node`, `performance` | `performance_profile` |
| Offload | `--offload` | `on`, `off` | `offload` |

### Integer Filters (exact match)

| Filter | CLI Argument | Example Values | ES Field |
|--------|-------------|----------------|----------|
| Threads | `--threads` | `1`, `32`, `64` | `threads` |
| Write Size | `--wsize` | `64`, `512`, `1024`, `32768` | `wsize` |
| Read Size | `--rsize` | `512`, `1024`, `8192` | `rsize` |
| Pods Per Worker | `--pods-per-worker` | `1`, `4`, `6`, `13` | `pods_per_worker` |
| Scale Out Factor | `--scale-out-factor` | (integer) | `scale_out_factor` |

### Range Filters

| Filter | CLI Argument | Example Values | ES Field |
|--------|-------------|----------------|----------|
| Min Throughput | `--min-throughput` | `90`, `1000000` | `mean` (>=) |
| Max Throughput | `--max-throughput` | `100`, `5000000` | `mean` (<=) |

### Display Control

| Filter | CLI Argument | Default | Max | Description |
|--------|-------------|---------|-----|-------------|
| Result Count | `--size` | 10 | 100 | Number of results to return |

## Quick Reference Guide

### Show All Valid Values

```bash
# Always run this first to see what values are available
./show_keywords.sh
```

### Basic Single-Filter Queries

```bash
# By benchmark tool
./build_and_run.sh search --benchmark uperf

# By network model
./build_and_run.sh search --model OVNK

# By NIC hardware
./build_and_run.sh search --nic BF3

# By topology
./build_and_run.sh search --topology intranode

# By protocol
./build_and_run.sh search --protocol tcp

# By test type
./build_and_run.sh search --test-type stream

# By thread count
./build_and_run.sh search --threads 64

# By write size
./build_and_run.sh search --wsize 1024

# By read size
./build_and_run.sh search --rsize 512

# By pods per worker
./build_and_run.sh search --pods-per-worker 13

# By performance profile
./build_and_run.sh search --performance-profile single-numa-node

# By RCOS version
./build_and_run.sh search --rcos 9.6.20250925-0
```

### Multi-Filter Combinations

```bash
# Network stack: OVNK + BF3 + intranode + TCP
./build_and_run.sh search --model OVNK --nic BF3 --topology intranode --protocol tcp

# Performance tuning: 64 threads + single-numa-node + stream
./build_and_run.sh search --threads 64 --performance-profile single-numa-node --test-type stream

# Scaling: 13 pods/worker + internode + TCP + rr
./build_and_run.sh search --pods-per-worker 13 --topology internode --protocol tcp --test-type rr

# Complete specification (12 filters)
./build_and_run.sh search \
  --benchmark uperf \
  --model OVNK \
  --nic BF3 \
  --topology intranode \
  --protocol tcp \
  --test-type stream \
  --kernel 5.14.0-570.49.1.el9_6.x86_64 \
  --rcos 9.6.20250925-0 \
  --performance-profile single-numa-node \
  --threads 64 \
  --pods-per-worker 1 \
  --min-throughput 90 \
  --size 20
```

### Throughput Ranges

```bash
# High performance (>90)
./build_and_run.sh search --min-throughput 90

# Specific range (80-100)
./build_and_run.sh search --min-throughput 80 --max-throughput 100

# Low performance for debugging (<10)
./build_and_run.sh search --max-throughput 10

# Combined with other filters
./build_and_run.sh search --test-type stream --min-throughput 80 --model OVNK
```

## Understanding Field Values

### CPU Count Format
- Plain numbers: `4`, `26`, `52` - Regular CPU count
- With `(Gu)`: `4(Gu)`, `26(Gu)` - Guaranteed CPUs (from resource limits)

### Topology
- `intranode` - Pods on same worker node (lower latency)
- `internode` - Pods on different worker nodes (realistic network path)

### Test Types
- `stream` - Throughput/bandwidth tests
- `rr` - Request-response (latency) tests
- `crr` - Connection rate tests

### Performance Profiles
- `single-numa-node` - NUMA-aware performance tuning
- `performance` - General performance tuning
- `None` - No specific profile applied

## Tips for Effective Searching

1. **Start Broad, Then Narrow**
   ```bash
   # Start with general query
   ./build_and_run.sh search --model OVNK

   # Add filters based on results
   ./build_and_run.sh search --model OVNK --topology intranode

   # Further refine
   ./build_and_run.sh search --model OVNK --topology intranode --protocol tcp --test-type stream
   ```

2. **Use Size to Control Output**
   ```bash
   # Quick check (default 10)
   ./build_and_run.sh search --model OVNK

   # More comprehensive (50 results)
   ./build_and_run.sh search --model OVNK --size 50

   # Full dataset (100 max)
   ./build_and_run.sh search --model OVNK --size 100
   ```

3. **Check Total Count**
   - Output shows: "Found X total results (showing Y)"
   - X = total matches in database
   - Y = results displayed (limited by --size)
   - If X > Y, increase --size to see more

4. **Performance Analysis Patterns**
   ```bash
   # Find best performers for each topology
   ./build_and_run.sh search --topology intranode --size 10
   ./build_and_run.sh search --topology internode --size 10

   # Compare protocols
   ./build_and_run.sh search --protocol tcp --test-type stream --size 5
   ./build_and_run.sh search --protocol udp --test-type stream --size 5

   # Thread scaling analysis
   ./build_and_run.sh search --threads 1 --test-type stream --size 5
   ./build_and_run.sh search --threads 32 --test-type stream --size 5
   ./build_and_run.sh search --threads 64 --test-type stream --size 5
   ```

5. **Debugging Low Performance**
   ```bash
   # Find anomalies (very low throughput)
   ./build_and_run.sh search --max-throughput 1 --size 20

   # Specific configuration with issues
   ./build_and_run.sh search --model OVNK --max-throughput 10

   # Kernel-specific problems
   ./build_and_run.sh search --kernel 5.14.0-570.49.1.el9_6.x86_64 --max-throughput 10
   ```

## Current Data Summary (from your ES instance)

Run `./show_keywords.sh` to see:
- 475 total documents
- 3 batches
- 2 benchmarks (uperf: 410, iperf: 62)
- 2 models (DPU: 277, OVNK: 195)
- 3 NICs (BF3: 194, X550: 3, E810: 1)
- 2 topologies (internode: 249, intranode: 223)
- 2 protocols (tcp: 350, udp: 122)
- 3 test types (stream: 173, crr: 118, rr: 116)
- 3 thread counts (1: 209, 32: 112, 64: 89)
- 6 pods/worker values (1: 237, 13: 108, 6: 71, 7: 24, 4: 16, 8: 16)
- 2 performance profiles (single-numa-node: 232, None: 243)

## Getting Help

```bash
# Show all search options
./build_and_run.sh search --help

# Show valid values for all filters
./show_keywords.sh

# View comprehensive examples
cat SEARCH_EXAMPLES.md

# View this complete reference
cat COMPLETE_FILTER_REFERENCE.md
```
