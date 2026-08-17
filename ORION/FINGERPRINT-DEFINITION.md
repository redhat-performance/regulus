# Regulus Test Fingerprint Definition

**Version:** 2.0
**Date:** 2026-07-21
**Purpose:** Define all fields that constitute a unique test fingerprint for regression detection

## Overview

A **fingerprint** uniquely identifies a specific type of performance test. For Orion's changepoint detection to work correctly, tests must match **ALL** fingerprint fields exactly to be compared against the same historical baseline.

**Rule:** If even ONE field differs, it's a completely different test requiring its own baseline.

## Fingerprint Fields

Fingerprint fields are defined in the static template (`configs/template.yaml`). Each `{{ field }}` placeholder in the template's metadata section is a fingerprint field. At startup, the analyzer validates that the template covers all fields in the ES index mapping (minus `NON_FINGERPRINT_FIELDS`). If a mapping field is missing from the template, the analyzer exits with an error.

All fields below must match exactly for tests to be considered the same type:

### 1. Test Framework

| Field | Description | Example Values |
|-------|-------------|----------------|
| `benchmark` | Test tool/benchmark name | `uperf`, `fio`, `netperf` |

### 2. Network Configuration

| Field | Description | Example Values |
|-------|-------------|----------------|
| `model` | Network model/configuration type | `OVNK`, `MACVLAN`, `SRIOV`, `hostnetwork`, `hardware offload`, `dpf-ovnk` |
| `topology` | Network topology configuration | `internode`, `pod-to-pod`, `intranode` |
| `protocol` | Network protocol | `tcp`, `udp` |
| `nic` | Network interface card type | `mlx5_0`, `mlx5_1`, `X550`, `bond0`, `ens1f0` |
| `ipv` | IP version | `4`, `6` |
| `offload` | NIC offload settings | `None`, `enabled` |

### 3. Test Parameters

| Field | Description | Example Values |
|-------|-------------|----------------|
| `test_type` | Type of test workload | `stream`, `rr` (request-response) |
| `threads` | Number of threads in the test | `1`, `2`, `4`, `8`, `64` |
| `wsize` | Write size / payload size (bytes) | `64`, `256`, `1024`, `4096`, `32768` |
| `rsize` | Read size / receive buffer size (bytes) | `64`, `256`, `1024`, `4096`, `32768` |
| `performance_profile` | Performance profile setting | `None`, `low-latency`, `high-throughput` |

### 4. System Configuration

| Field | Description | Example Values |
|-------|-------------|----------------|
| `kernel` | Kernel version | `5.14.0-503.11.1.el9_5.x86_64` |
| `rcos` | RCOS/OS version | `9.6.20260615-0` |
| `arch` | CPU architecture/model | `Intel(R)_Xeon(R)_Gold_6130_CPU_@_2.10GHz` |

### 5. Pod/Container Configuration

| Field | Description | Example Values |
|-------|-------------|----------------|
| `cpu` | Number of CPUs allocated per pod | `2`, `4`, `8`, `16`, `50` |
| `pods_per_worker` | Number of pods per worker node | `1`, `2`, `4`, `10` |
| `scale_out_factor` | Scale-out factor for distributed tests | `1`, `2`, `4` |

## Non-Fingerprint Fields (Excluded)

These fields vary between test executions but do NOT affect the fingerprint:

| Field | Purpose | Why Excluded |
|-------|---------|--------------|
| `iteration_id` | Unique identifier per execution | Changes every run, even for same test |
| `run_id` | Crucible run identifier | Internal to Crucible for artifact investigation |
| `batch_id` | Batch identifier | **Special purpose:** Identifies which tests to analyze (input selector), not part of fingerprint matching |
| `@timestamp` | When test was executed | Time doesn't define test type |
| `regulus_git_branch` | Git branch | Metadata only |
| `execution_label` | Execution label | Metadata only |
| `regulus_data` | Path to test artifacts | Metadata only |
| `mean`, `min`, `max`, `stddev`, `samples` | Measured metric values | These are the RESULTS we're analyzing |
| `busy_cpu` | CPU utilization during test | Measured metric, not test configuration |
| `unit` | Metric unit of measurement (`Gbps`, `transactions-sec`, etc.) | Redundant — determined by `test_type` (stream→Gbps, rr→transactions-sec, crr→connections-sec) |
| `uploaded_at` | When data was uploaded to ES | Upload timestamp, not test configuration |
| `mock_data` | Flag for test data | Metadata flag |

## Tracked Metrics

Orion tracks two metrics per fingerprint for regression detection:

| Metric Name | ES Field | Aggregation | Direction | Threshold | What it detects |
|-------------|----------|-------------|-----------|-----------|-----------------|
| `throughput` | `mean` | `avg` | `0` (both directions) | 5% | Throughput changes |
| `cpu_cost` | `busy_cpu` | `avg` | `0` (both directions) | 10% | CPU usage changes |

A fingerprint is flagged as regressed if **either** metric triggers a changepoint.

## Examples

### Example 1: Same Fingerprint (Should Compare)

**Test A:**
```yaml
benchmark: uperf
model: OVNK
topology: internode
protocol: tcp
ipv: 4
nic: mlx5_0
test_type: stream
threads: 8
wsize: 1024
performance_profile: None
kernel: 5.14.0-503.11.1.el9_5.x86_64
rcos: 9.6.20260615-0
arch: Intel(R)_Xeon(R)_Gold_6130_CPU_@_2.10GHz
cpu: 4
pods_per_worker: 1
scale_out_factor: 1

# Execution-specific (not part of fingerprint)
iteration_id: aaa-111-bbb-222
@timestamp: 2026-07-01T10:00:00
mean: 8.5
```

**Test B:**
```yaml
# ... ALL fingerprint fields identical to Test A ...

# Different execution-specific values (OK!)
iteration_id: ccc-333-ddd-444
@timestamp: 2026-07-02T14:30:00
mean: 7.2  # ← Lower performance! Potential regression!
```

**Result:** ✅ SAME fingerprint → Should be compared for regression detection

### Example 2: Different Fingerprint (Should NOT Compare)

**Test A:** (as above)

**Test C:**
```yaml
benchmark: uperf
model: OVNK
topology: internode
protocol: tcp
ipv: 4
nic: mlx5_0
test_type: stream
threads: 16          # ← DIFFERENT! (was 8)
wsize: 1024
performance_profile: None
kernel: 5.14.0-503.11.1.el9_5.x86_64
rcos: 9.6.20260615-0
arch: Intel(R)_Xeon(R)_Gold_6130_CPU_@_2.10GHz
cpu: 4
pods_per_worker: 1
scale_out_factor: 1

iteration_id: eee-555-fff-666
@timestamp: 2026-07-02T14:45:00
mean: 15.3
```

**Result:** ❌ DIFFERENT fingerprint (threads: 8 vs 16) → Should NOT be compared. These are different test types requiring separate baselines.

### Example 3: Critical Field Difference

**Test A:** `model: OVNK`, `arch: Intel Xeon Gold 6130`

**Test D:** `model: OVN`, `arch: Intel Xeon Gold 6130`

**Result:** ❌ DIFFERENT fingerprint (different network model) → Completely different networking stack, requires separate baseline.

**Test E:** `model: OVNK`, `arch: AMD EPYC 7763`

**Result:** ❌ DIFFERENT fingerprint (different CPU architecture) → Different CPU has different performance characteristics, requires separate baseline.

## Understanding batch_id vs Fingerprint

### The Role of batch_id

The `batch_id` field has a special purpose that's different from fingerprint fields:

**Purpose:** Tells Orion "these are the new tests I want analyzed"

**How it works:**
1. You submit a batch of tests (Test A, Test B, Test C...)
2. All tests in the batch share the same `batch_id` (e.g., "2026-07-06-batch-001")
3. You run Orion with: `--batch-id "2026-07-06-batch-001"`
4. Orion queries ES for all tests with that batch_id
5. Orion discovers the unique fingerprints in the batch
6. For each fingerprint, Orion:
   - Queries ALL historical data with that fingerprint (ignoring batch_id)
   - Includes the new test(s) from the batch
   - Runs changepoint detection
   - Reports regressions

**Key Distinction:**
- `batch_id` = **Input selector** (which tests to analyze)
- `fingerprint` = **Baseline selector** (which historical data to compare against)

**Example:**

Batch "2026-07-06-001" contains:
- Test A: `benchmark=uperf, unit=Gbps, threads=16, ...` (fingerprint A)
- Test B: `benchmark=uperf, unit=Gbps, threads=32, ...` (fingerprint B)

```bash
./scripts/analyze-batch.py --batch-id "2026-07-06-001"
```

The tool will:
1. Query ES for tests with batch_id="2026-07-06-001" → finds Test A and Test B
2. Extract fingerprint A (threads=16) and fingerprint B (threads=32)
3. Run Orion with template + `--input-vars` for fingerprint A (metadata filters WITHOUT batch_id)
4. Run Orion with template + `--input-vars` for fingerprint B
5. Aggregate and report results

**Note:** Orion doesn't have native `--batch-id` support, so the wrapper tool is needed to:
- Use batch_id to discover which tests to analyze
- Use fingerprint (without batch_id) to match historical baselines

## Design Philosophy

### Why All Fields Matter

Each fingerprint field represents a variable that can significantly impact performance:

- **Network fields** (model, topology, protocol, nic): Different network paths and processing
- **Test parameters** (test_type, threads, wsize): Different workload characteristics
- **System config** (kernel, rcos, arch): Different software/hardware stack
- **Resource allocation** (cpu, pods_per_worker, scale_out_factor): Different resource constraints

Mixing tests with different configurations would create "apples to oranges" comparisons and lead to:
- ❌ False positives: Flagging legitimate performance differences as regressions
- ❌ False negatives: Missing real regressions due to noisy baselines

### Extensibility

To add a new fingerprint field:

1. Add the field to the Regulus ES mapping template
2. Add `{{ new_field }}` to `configs/template.yaml` (with `{% if is defined %}` guard)
3. Document it in this file

At startup, `analyze-batch.py` compares the template's `{{ }}` placeholders against the ES mapping and exits with an error if any mapping field is missing from the template.

The tools use a `NON_FINGERPRINT_FIELDS` exclusion set (metrics, IDs, timestamps, metadata). Any field in the mapping NOT in that set is automatically a fingerprint field. The exclusion set is maintained in `analyze-batch.py`, `verify-batch.py`, and `verify-mapping.py`. The Prow CI step clones the Regulus repo and uses `analyze-batch.py` directly via `ORION/scripts/prow-entry.sh`.

## Tool Integration

The `analyze-batch.py` wrapper tool uses this definition to:

1. **Query ES** for all tests with the specified `batch_id`
2. **Extract fingerprints** from those tests (group by all discovered fingerprint fields)
3. **Run Orion** per fingerprint using the static template (`configs/template.yaml`) with `--input-vars` supplying the fingerprint values
4. **Aggregate results** into a unified report

Per-fingerprint outputs are written to `generated-orion/` with a manifest file (`manifest-fpN.json`) mapping each output to its full fingerprint fields.

**Why batch_id is excluded from Orion metadata:**
- Including batch_id in metadata would limit Orion to only that batch
- We want Orion to query ALL historical data for comparison (1 year, or whatever lookback)
- batch_id is only used to discover which NEW tests to analyze, not for historical matching

## Changelog

| Date | Change | Fields Added/Modified |
|------|--------|-----------------------|
| 2026-07-06 | Initial definition | All 16 fields: benchmark, unit, model, topology, protocol, nic, test_type, threads, wsize, performance_profile, kernel, rcos, arch, cpu, pods_per_worker, scale_out_factor |
| 2026-07-21 | Dynamic discovery + ipv | Replaced hardcoded field list with dynamic discovery from ES mapping using NON_FINGERPRINT_FIELDS exclusion set. Added `ipv` (IP version 4/6) to Network Configuration. |
| 2026-08-05 | Move unit to non-fingerprint | `unit` is redundant with `test_type` (stream→Gbps, rr→transactions-sec, crr→connections-sec). Added `unit` to NON_FINGERPRINT_FIELDS in all three scripts. Added `uploaded_at` to doc. Added `ipv` to examples. |
| 2026-08-17 | Restore offload as fingerprint | `offload` was accidentally added to NON_FINGERPRINT_FIELDS in the unit removal commit. Restored to fingerprint table under Network Configuration. |
| 2026-08-17 | Static template, add rsize | Default to static `configs/template.yaml` with `--input-vars` instead of generating per-fingerprint configs. Added `rsize` to Test Parameters. Added manifest files (`manifest-fpN.json`) to `generated-orion/`. Updated extensibility steps to include template. |

## See Also

- **CLAUDE.md** - Development session history and design decisions
- **README.md** - Project overview
- **analyze-batch.py** - Fingerprint analysis tool (uses this definition)
- **configs/template.yaml** - Static Orion config template with fingerprint placeholders
