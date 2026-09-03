#!/usr/bin/env python3
"""
Estimate the wall-clock run time of a regulus 'make jobs' run, per job folder and in total,
directly from jobs.config and each job's mv-params.json — without running anything.

COST MODEL
==========
Image sourcing (~55s) is one-time per run. Each job folder then pays its own overhead.

    T_total = FIXED_RUN + Σ_jobs(FIXED_PER_JOB + N_iterations × N_samples × PER_SAMPLE)

Where:
  - FIXED_RUN:    One-time cost for image sourcing at start of run (~55 seconds)
  - FIXED_PER_JOB: Per-job overhead for setup roadblocks, shutdown, post-processing,
                   and crucible wrapper (~300 seconds per job)
  - N_iterations:  Cross-product of all parameter combinations in mv-params.json
  - N_samples:     NUM_SAMPLES from jobs.config (number of times each iteration runs)
  - PER_SAMPLE:    Overhead per sample (~68.5s) + DURATION (actual measurement time)

For setup/teardown jobs (SETUP_GROUP, INSTALL, CLEANUP) without mv-params.json:
  - Cost estimated by keyword matching (PAO/SRIOV → 300s, others → 60s)
  - These trigger MachineConfig node reboots which dominate their cost

AUTO-EXPANSION OF JOB TEMPLATES
================================
The script automatically finds mv-params.json in two ways:

  1. Direct file: If make init-jobs has been run, uses the expanded mv-params.json
  2. Template resolution: If mv-params.json doesn't exist, parses reg_expand.sh to locate
     the template file (e.g., templates/uperf/tcp-mv-params.json.template) and reads that.

This means you get accurate estimates even without running make init-jobs first!

CALIBRATION
===========
The FIXED_PER_JOB and PER_SAMPLE_OVERHEAD constants are calibrated from empirical measurement.
To recalibrate as infrastructure changes:

  1. Run a sample calibration job with 2 iterations × 3 samples:
     - This provides enough data to estimate both constants reliably
     - Use a short DURATION (10-20s) to keep calibration runtime under 30 minutes
     - Run during a quiet cluster period to avoid load skewing measurements
     - Set NUM_SAMPLES=3 and adjust one of your job configs for quick testing

  2. Capture the crucible run log with timestamps enabled and roadblock markers:
     $ cd bin/
     $ crucible run --log-level verbose <config_file> 2>&1 | tee calibration.log

     Or via make:
     $ make run JOBS=./calibration-job DRY_RUN=false LOG_LEVEL=verbose 2>&1 | tee calibration.log

  3. Run the calibrator from the repo root:
     $ ./bin/runtime-estimator.py --calibrate calibration.log

  4. Review the suggested updates and commit the new ./bin/runtime-estimator.json

Note: The calibrator parses [timestamp] roadblock-begin/end and measurement-begin/end markers
from the log. These appear automatically with --log-level verbose.

Usage:
  runtime-estimator.py [regulus_root_dir]           # Estimate all jobs
  runtime-estimator.py --calibrate <crucible_log>  # Recalibrate constants
"""
import json
import re
import os
import sys
import glob
import argparse
from pathlib import Path
from datetime import datetime

# ---- DEFAULT CONSTANTS (read from runtime-estimator.json at runtime) ----
DEFAULT_FIXED_RUN = 55.0
# One-time cost at start of entire run:
#   - image-source: pull/extract container images (cached), one-time for run
# Total: ~55s per run, regardless of job count

DEFAULT_FIXED_PER_JOB = 300.0
# Breakdown of per-job fixed cost (paid once per job folder):
#   - setup roadblocks       ~140s (16 roadblock barriers waiting for cluster readiness)
#   - shutdown               ~51s  (cleanup and tear down test pods)
#   - post-process/index     ~59s  (collect results, build indexes)
#   - crucible wrapper       ~51s  (orchestration overhead)
# Total: ~300s per job, regardless of iteration count

DEFAULT_PER_SAMPLE_OVERHEAD = 68.5
# Cost per sample (besides DURATION):
#   - 16 roadblock barriers × 3.45s each  ~55s (synchronization points in test)
#   - pod start/stop                      ~13s (lifecycle management)
# Total overhead: ~68.5s
# Actual sample time = PER_SAMPLE_OVERHEAD + DURATION (from jobs.config)

# setup/teardown job cost estimation by keyword matching
# These jobs have no mv-params.json and their cost is dominated by node reboots
DEFAULT_SETUP_COSTS = [("PAO", 300), ("SRIOV", 300)]  # keyword (case-insensitive) -> seconds
DEFAULT_SETUP_DEFAULT = 60  # for MACVLAN and other setup jobs

# Default calibration note for new config files
DEFAULT_CALIBRATION_NOTE = "uperf, kube endpoint, 1 client + 1 server pod, intranode, fedora-latest userenv, images cached"


class Config:
    """Manages the estimator configuration (constants and metadata)."""

    def __init__(self, config_path=None):
        """
        Load configuration from file or use defaults.

        Args:
            config_path: Path to runtime-estimator.json. If None, uses defaults.
        """
        self.path = config_path
        self.fixed_run = DEFAULT_FIXED_RUN
        self.fixed_per_job = DEFAULT_FIXED_PER_JOB
        self.per_sample_overhead = DEFAULT_PER_SAMPLE_OVERHEAD
        self.setup_costs = dict(DEFAULT_SETUP_COSTS)
        self.setup_default = DEFAULT_SETUP_DEFAULT
        self.calibration_date = None
        self.calibration_note = None

        if config_path and os.path.isfile(config_path):
            self.load(config_path)

    def load(self, config_path):
        """Load configuration from JSON file."""
        with open(config_path) as f:
            data = json.load(f)
            self.fixed_run = data.get("fixed_run", DEFAULT_FIXED_RUN)
            self.fixed_per_job = data.get("fixed_per_job", DEFAULT_FIXED_PER_JOB)
            self.per_sample_overhead = data.get(
                "per_sample_overhead", DEFAULT_PER_SAMPLE_OVERHEAD
            )
            setup_costs_dict = data.get("setup_costs", {})
            self.setup_costs = {
                k: v for k, v in setup_costs_dict.items() if k != "default"
            }
            self.setup_default = setup_costs_dict.get(
                "default", DEFAULT_SETUP_DEFAULT
            )
            self.calibration_date = data.get("calibration_date")
            self.calibration_note = data.get("calibration_note")

    def save(self, config_path):
        """Save configuration to JSON file."""
        os.makedirs(os.path.dirname(config_path), exist_ok=True)
        data = {
            "fixed_run": self.fixed_run,
            "fixed_per_job": self.fixed_per_job,
            "per_sample_overhead": self.per_sample_overhead,
            "setup_costs": {**self.setup_costs, "default": self.setup_default},
            "calibration_date": datetime.now().isoformat(),
            "calibration_note": self.calibration_note,
        }
        with open(config_path, "w") as f:
            json.dump(data, f, indent=2)

    def to_dict(self):
        """Convert to dictionary for display."""
        return {
            "fixed_run": self.fixed_run,
            "fixed_per_job": self.fixed_per_job,
            "per_sample_overhead": self.per_sample_overhead,
            "setup_costs": self.setup_costs,
            "setup_default": self.setup_default,
        }


def setup_cost(job, config):
    """
    Estimate cost of a setup/teardown job by matching keywords in the path.

    Setup jobs don't have mv-params.json and are dominated by node reboots triggered
    by MachineConfig changes (Performance Addon Operator, SR-IOV, MACVLAN).

    Args:
        job: Job path from JOBS list (e.g., "./SETUP_GROUP/PAO/INSTALL")
        config: Config object with setup cost mappings

    Returns:
        Estimated seconds for the job based on keyword matching (case-insensitive).
    """
    u = job.upper()
    for kw, c in config.setup_costs.items():
        if kw in u:
            return c
    return config.setup_default


def is_setup_job(job):
    """
    Identify setup/teardown jobs that manage node configuration and don't have mv-params.json.

    These are node-config orchestration steps (PAO/SR-IOV/MACVLAN installation/cleanup)
    that don't measure application performance. They're distinguished from benchmark jobs
    by path keywords.

    Args:
        job: Job path from JOBS list

    Returns:
        True if this is a setup/teardown job, False if it's a benchmark job.
    """
    u = job.upper()
    return ("SETUP" in u) or ("INSTALL" in u) or ("CLEANUP" in u)


def read_jobs_config(root):
    """
    Parse jobs.config to extract configuration and job list.

    jobs.config defines:
      - NUM_SAMPLES: How many times each iteration is measured (replicates for variance)
      - DURATION: Seconds per sample during actual measurement
      - DRY_RUN: Whether this is a dry run (affects time estimates)
      - JOBS: List of job directories to run as separate crucible runs

    Args:
        root: Path to regulus repo (directory containing jobs.config)

    Returns:
        Tuple of (num_samples, duration, dry_run_flag, jobs_list)
    """
    txt = open(os.path.join(root, "jobs.config")).read()

    def val(name, default):
        """Extract a shell export variable from jobs.config."""
        m = re.search(r"^\s*export\s+%s=(\S+)" % name, txt, re.M)
        return m.group(1).strip().strip('"') if m else default

    # NUM_SAMPLES: Number of measurement replicates per iteration
    # If not specified, defaults to 1 (single measurement, no variance statistics)
    num_samples = int(val("NUM_SAMPLES", "1"))

    # DURATION: Seconds per sample that the actual measurement runs
    # This is the "real work" time in each sample; overhead is separate
    # If not specified, defaults to 0 (shouldn't happen in practice)
    duration = int(val("DURATION", "0"))

    # DRY_RUN: Flag to indicate a dry run (fast path, no real execution)
    # Estimates here assume real execution; dry runs are much faster
    dry = val("DRY_RUN", "false").lower()

    # JOBS: Multi-line list of job directories, each a separate crucible run
    # Entries may span multiple lines with backslash continuation
    # We extract all lines starting with ./ or / and treat them as job paths
    m = re.search(
        r"^\s*export\s+JOBS=(.*?)(?=^\s*export\s+\w+=|\Z)", txt, re.S | re.M
    )
    jobs = []
    if m:
        for line in m.group(1).splitlines():
            line = line.strip().rstrip("\\").strip().strip('"')
            if line.startswith("./") or line.startswith("/"):
                jobs.append(line)
    return num_samples, duration, dry, jobs


def find_template_mvparams(root, job):
    """
    Find the template mv-params.json file by parsing reg_expand.sh.

    Each job folder contains a reg_expand.sh script that specifies which template
    to expand. This function parses that script to locate the source template
    for the mv-params.json, allowing estimation even if make init-jobs hasn't run.

    Example from reg_expand.sh:
      REG_TEMPLATES=${REG_ROOT}/templates/uperf
      envsubst '...' < ${REG_TEMPLATES}/tcp-mv-params.json.template > ./mv-params.json

    Args:
        root: Regulus repo root
        job: Job directory path

    Returns:
        Path to template mv-params.json.template if found, None otherwise.
    """
    jd = os.path.join(root, job)
    expand_script = os.path.join(jd, "reg_expand.sh")

    if not os.path.isfile(expand_script):
        return None

    try:
        with open(expand_script) as f:
            content = f.read()

        # Extract REG_TEMPLATES variable (may be relative to REG_ROOT or absolute)
        reg_templates_match = re.search(
            r'REG_TEMPLATES=(\$\{REG_ROOT\})?([^\n\r]+)', content
        )
        if not reg_templates_match:
            return None

        reg_templates = reg_templates_match.group(2).strip()

        # Find the line that redirects a template to mv-params.json
        # Pattern: envsubst '...' < ${REG_TEMPLATES}/TEMPLATE.json.template > ./mv-params.json
        mv_match = re.search(
            r'\$\{REG_TEMPLATES\}([^\s>]+\.json\.template)',
            content,
        )
        if not mv_match:
            return None

        template_rel = mv_match.group(1)

        # Resolve the full path: REG_TEMPLATES + template relative path
        # REG_TEMPLATES is relative to repo root (e.g., templates/uperf)
        template_path = os.path.join(root, reg_templates.lstrip("/"), template_rel.lstrip("/"))

        if os.path.isfile(template_path):
            return template_path

    except Exception:
        pass

    return None


def find_mvparams(root, job):
    """
    Locate the mv-params.json file for a job folder.

    Each benchmark job has a parameter definition file that specifies all parameter
    combinations to test. This function attempts to find it in this order:

    1. mv-params.json (already expanded by make init-jobs) ← fastest, preferred
    2. Template via reg_expand.sh (script indicates which template to use) ← works without init-jobs
    3. mv-params.json.template or other *mv-params*.json variants ← fallback

    This allows estimation even if make init-jobs hasn't been run yet, by reading
    the template that would be expanded.

    Args:
        root: Regulus repo root
        job: Job directory path (e.g., "./1_GROUP/NO-PAO/4IP/INTRA-NODE/TCP/2-POD")

    Returns:
        Path to mv-params.json (or template) if found, None otherwise.
    """
    jd = os.path.join(root, job)

    # Try expanded file first (fastest, no template substitution needed)
    if os.path.isfile(os.path.join(jd, "mv-params.json")):
        return os.path.join(jd, "mv-params.json")

    # Try to find template via reg_expand.sh
    # This allows iteration counting without requiring make init-jobs
    template_path = find_template_mvparams(root, job)
    if template_path:
        return template_path

    # Fallback: look for other mv-params variants
    for name in ("mv-params.json.template",):
        p = os.path.join(jd, name)
        if os.path.isfile(p):
            return p

    g = sorted(glob.glob(os.path.join(jd, "*mv-params*.json")))
    return g[0] if g else None


def count_iters(mvpath):
    """
    Count the total number of iterations from mv-params.json.

    An "iteration" is one complete run of the benchmark with a specific parameter
    combination. The total iteration count is the cross-product of all parameter values.

    The file can define parameters in two ways:
    1. global-options: Parameters that apply to all sets, multiplied across all sets
    2. sets: Named parameter groups with independent combinations

    For global-options: if set X defines params [a1, a2] and set Y defines [b1, b2],
    the cross-product is 2×2=4 iterations. Each global-option group is multiplied
    across all sets.

    For sets without global-options: each set defines its own parameters independently,
    and the total is the sum of cross-products across sets.

    Example from skill: calibration job with:
      - global nthreads:[1,64] (×2)
      - set stream/wsize:[512,32768] (×2), rr (×1), crr (×1)
      → (2+1+1) × 2 = 8 iterations total

    Args:
        mvpath: Path to mv-params.json

    Returns:
        Total number of iterations (distinct parameter combinations).
    """
    d = json.load(open(mvpath))

    # First, compute the multiplier from each global-option group
    # Global options apply to *all* sets, so we multiply their dimensions together
    gmult = {}
    for g in d.get("global-options", []):
        m = 1
        # For each param in the global-option, multiply by its value count
        # If a param has no values or is omitted, it contributes factor of 1
        for p in g.get("params", []):
            m *= max(1, len(p.get("vals", []) or [1]))
        gmult[g.get("name")] = m

    # Check if there are named parameter sets
    sets = d.get("sets", [])
    if not sets:
        # No sets: just multiply all global-option multipliers together
        total = 1
        for m in gmult.values():
            total *= m
        return total

    # With sets: each set is independent and adds to the total iteration count
    # Each set's contribution = (product of its param dimensions) × (global multiplier)
    total = 0
    for s in sets:
        sm = 1
        # Multiply dimensions of params *within* this set
        for p in s.get("params", []):
            sm *= max(1, len(p.get("vals", []) or [1]))
        # Include the global-option multiplier for this set (lookup by "include" field)
        # If a set doesn't reference a global-option, the multiplier defaults to 1
        total += sm * gmult.get(s.get("include"), 1)
    return total


def fmt(s):
    """
    Format seconds into human-readable time string (e.g., "1h23m45s" or "5m30s").

    Args:
        s: Time in seconds (float or int)

    Returns:
        Formatted string like "1h23m45s", "5m30s", or "45s"
    """
    s = int(round(s))
    h = s // 3600
    m = (s % 3600) // 60
    sec = s % 60
    return f"{h}h{m:02d}m{sec:02d}s" if h else f"{m}m{sec:02d}s"


def estimate_jobs(root, config):
    """
    Estimate runtime for all jobs in jobs.config.

    Reads jobs.config and estimates per-job and total runtime based on iteration
    counts from mv-params.json and the calibrated cost constants.

    Args:
        root: Path to regulus repo root
        config: Config object with calibrated constants
    """
    # ---- READ CONFIGURATION ----
    num_samples, duration, dry, jobs = read_jobs_config(root)

    # Calculate the per-sample time: overhead + actual measurement duration
    # This is what each iteration × sample takes (excludes job fixed cost)
    per_sample = config.per_sample_overhead + duration

    # Print configuration header
    print(f"Regulus root : {root}")
    print(f"NUM_SAMPLES={num_samples}  DURATION={duration}s  DRY_RUN={dry}")
    print(
        f"per-sample   = {per_sample:.1f}s (overhead {config.per_sample_overhead} + duration {duration})"
    )
    print(f"fixed/run    = {config.fixed_run:.0f}s")
    print(f"fixed/job    = {config.fixed_per_job:.0f}s")
    if dry == "true":
        print("\n** DRY_RUN=true: crucible does a dry run; these real-execution")
        print("   estimates do NOT apply (a dry run is far faster). **")
    print()

    # Print table header: iteration count, samples, execution time, fixed cost, total
    hdr = f"{'#':>2} {'iters':>5} {'samp':>4} {'exec':>10} {'+fixed':>8} {'=total':>10}  job"
    print(hdr)
    print("-" * len(hdr))

    # Accumulate totals for summary
    grand = config.fixed_run  # Start with one-time run cost
    bench_total = 0.0  # Total for benchmark jobs only
    setup_total = 0.0  # Total for setup jobs only
    n_bench = n_setup = missing = 0

    # ---- PROCESS EACH JOB ----
    for i, job in enumerate(jobs, 1):
        mv = find_mvparams(root, job)
        if not mv:
            # No mv-params.json found
            if is_setup_job(job):
                # It's a setup/teardown job: estimate by keyword matching
                c = setup_cost(job, config)
                setup_total += c
                n_setup += 1
                grand += c
                print(
                    f"{i:2d} {'-':>5} {'-':>4} {'-':>10} {'-':>8} {fmt(c):>10}  {job}  (setup)"
                )
            else:
                # It's a benchmark job but mv-params.json/template is missing
                # This means reg_expand.sh is also missing (folder not from template)
                missing += 1
                print(
                    f"{i:2d} {'?':>5} {num_samples:4d} {'?':>10} {'?':>8} {'?':>10}  {job}  (no mv-params.json/template)"
                )
            continue

        # ---- BENCHMARK JOB CALCULATION ----
        # Count iterations: number of distinct parameter combinations
        iters = count_iters(mv)

        # Calculate execution time: iterations × samples × per-sample time
        # This is the pure measurement time (does NOT include per-job overhead)
        execs = iters * num_samples * per_sample

        # Total job time: per-job fixed overhead + execution time
        # Formula: T_job = FIXED_PER_JOB + (iters × samples × per_sample)
        tot = config.fixed_per_job + execs

        # Accumulate totals (grand total already includes FIXED_RUN at the start)
        grand += tot
        bench_total += tot
        n_bench += 1

        # Print row: job number, iterations, samples per iteration, exec time, fixed cost, total
        print(
            f"{i:2d} {iters:5d} {num_samples:4d} {fmt(execs):>10} {fmt(config.fixed_per_job):>8} {fmt(tot):>10}  {job}"
        )

    # ---- PRINT SUMMARY ----
    print("-" * len(hdr))
    print(f"benchmark jobs : {n_bench:2d}  {fmt(bench_total)}")
    print(f"setup jobs     : {n_setup:2d}  {fmt(setup_total)}")
    print(f"GRAND TOTAL    : {fmt(grand)}  ({grand:.0f}s)")

    # Alert if there are jobs with no mv-params or templates
    if missing:
        print(f"\n** {missing} job(s) have no mv-params.json/template and are NOT setup steps —")
        print("   folders not created from templates. Check job paths. **")


def parse_calibration_log(logpath):
    """
    Parse a crucible run log to extract roadblock, measurement, and job timings.

    Expected log format from crucible with timestamps:
      [2026-09-03 01:20:38,555][INFO] Roadblock: ... endpoint-deploy-begin ...
      [2026-09-03 01:21:12,501][INFO] Roadblock 'endpoint-deploy-begin' completed ...
      [2026-09-03 01:22:50,581][INFO] Starting iteration 1 sample 1 ...
      [2026-09-03 01:24:08,726][INFO] Completed iteration 1 sample 1 ...

    Extracts durations for roadblocks, samples, and overall job time.

    Args:
        logpath: Path to crucible run log with [timestamp] markers

    Returns:
        Tuple of (roadblock_times, sample_times, first_ts, last_ts)
        - roadblock_times: list of durations in seconds
        - sample_times: list of durations in seconds
        - first_ts: earliest timestamp in log (job start)
        - last_ts: latest timestamp in log (job end)
    """
    roadblock_times = []
    sample_times = []
    pending_roadblocks = {}
    pending_samples = {}
    first_ts = None
    last_ts = None

    try:
        with open(logpath) as f:
            for line in f:
                # Extract timestamp and message
                m = re.match(r"\[([^\]]+)\]\s*(?:\[[^\]]+\])?\s*(.*)", line)
                if not m:
                    continue
                ts_str = m.group(1)
                msg = m.group(2) if m.lastindex >= 2 else ""

                # Parse timestamp
                try:
                    if "," in ts_str:
                        ts = datetime.strptime(ts_str, "%Y-%m-%d %H:%M:%S,%f")
                    elif "T" in ts_str:
                        ts = datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
                    else:
                        ts = datetime.fromisoformat(ts_str)
                except (ValueError, AttributeError):
                    continue

                # Track first and last timestamp for job duration
                if first_ts is None:
                    first_ts = ts
                last_ts = ts

                # Roadblock begin markers
                if "Roadblock:" in msg and "begin" in msg.lower():
                    rb_match = re.search(r":(\w+-begin)\s", msg)
                    if rb_match:
                        roadblock_name = rb_match.group(1)
                        pending_roadblocks[roadblock_name] = ts

                # Roadblock end markers
                if "Roadblock" in msg and "completed" in msg.lower():
                    rb_match = re.search(r"'(\w+-begin)'", msg)
                    if rb_match:
                        roadblock_name = rb_match.group(1)
                        if roadblock_name in pending_roadblocks:
                            duration = (ts - pending_roadblocks[roadblock_name]).total_seconds()
                            if duration > 0:
                                roadblock_times.append(duration)
                            del pending_roadblocks[roadblock_name]

                # Sample start
                if "Starting iteration" in msg and "sample" in msg:
                    m_iter = re.search(r"iteration (\d+) sample (\d+)", msg)
                    if m_iter:
                        iter_num = m_iter.group(1)
                        sample_num = m_iter.group(2)
                        sample_key = f"iter{iter_num}_sample{sample_num}"
                        pending_samples[sample_key] = ts

                # Sample completion
                if "Completed iteration" in msg and "sample" in msg:
                    m_iter = re.search(r"iteration (\d+) sample (\d+)", msg)
                    if m_iter:
                        iter_num = m_iter.group(1)
                        sample_num = m_iter.group(2)
                        sample_key = f"iter{iter_num}_sample{sample_num}"
                        if sample_key in pending_samples:
                            duration = (ts - pending_samples[sample_key]).total_seconds()
                            if duration > 0:
                                sample_times.append(duration)
                            del pending_samples[sample_key]

    except Exception as e:
        print(f"Warning: Error parsing log file: {e}", file=sys.stderr)

    return roadblock_times, sample_times, first_ts, last_ts


def calibrate(logpath, config_path):
    """
    Recalibrate constants from a crucible run log.

    Parses the log to extract roadblock and measurement timings, then computes
    suggested values for FIXED_PER_JOB and PER_SAMPLE_OVERHEAD.

    For best results, the log should come from a calibration run with:
      - 2 iterations × 3 samples (provides 6 data points for averaging)
      - DURATION 10-20s (short, to keep calibration fast)
      - Quiet cluster (to avoid load noise)
      - --log-level verbose to get [timestamp] markers

    Args:
        logpath: Path to crucible run log with [timestamp] markers
        config_path: Path to save updated estimator config
    """
    print(f"Parsing calibration log: {logpath}")
    roadblock_times, sample_times, first_ts, last_ts = parse_calibration_log(logpath)

    if not sample_times:
        print("Error: Could not extract sample timing data from log.", file=sys.stderr)
        print(
            "Expected log with 'Starting iteration X sample Y' and 'Completed iteration X sample Y' markers.",
            file=sys.stderr,
        )
        print(
            "Make sure the run completed successfully with actual measurements.",
            file=sys.stderr,
        )
        sys.exit(1)

    print(f"\nCalibration data extracted:")

    avg_sample = sum(sample_times) / len(sample_times) if sample_times else 0
    total_sample_time = sum(sample_times) if sample_times else 0

    print(f"  Measurement samples: {len(sample_times)}")
    if sample_times:
        print(f"    Average per sample: {avg_sample:.1f}s")
        print(f"    Total measurement time: {total_sample_time:.1f}s")
        print(f"    Range: {min(sample_times):.1f}s - {max(sample_times):.1f}s")

    if roadblock_times:
        avg_roadblock = sum(roadblock_times) / len(roadblock_times)
        print(f"  Roadblock events: {len(roadblock_times)}")
        print(f"    Average duration: {avg_roadblock:.1f}s")
        print(f"    Range: {min(roadblock_times):.1f}s - {max(roadblock_times):.1f}s")
    else:
        print(f"  Roadblock events: 0")

    # Calculate FIXED_RUN and FIXED_PER_JOB from job duration
    # Image sourcing is ~55s (one-time), rest is per-job
    # FIXED_PER_JOB = (total_job_time - total_sample_time) - FIXED_RUN
    new_fixed_run = None
    new_fixed_per_job = None
    if first_ts and last_ts:
        total_job_time = (last_ts - first_ts).total_seconds()
        overhead_total = total_job_time - total_sample_time

        # Estimate FIXED_RUN as image sourcing time (~55s typical)
        # Could also use: FIXED_RUN = default if we want to keep it constant
        # For now, assume image sourcing is reasonably consistent
        new_fixed_run = config.fixed_run  # Keep default for FIXED_RUN (image sourcing)
        new_fixed_per_job = overhead_total - new_fixed_run

        print(f"\n  Job duration: {total_job_time:.1f}s")
        print(f"    = {total_sample_time:.1f}s (samples) + {overhead_total:.1f}s (fixed overhead)")
        print(f"    = {new_fixed_run:.1f}s (run overhead) + {new_fixed_per_job:.1f}s (per-job)")

    # Use full sample time as PER_SAMPLE_OVERHEAD (includes DURATION)
    new_per_sample_overhead = avg_sample

    print(f"\nSuggested updates:")
    if new_fixed_per_job is not None:
        print(
            f"  FIXED_PER_JOB: {config.fixed_per_job:.1f}s → {new_fixed_per_job:.1f}s"
        )
        print(
            f"    (drift: {((new_fixed_per_job - config.fixed_per_job) / config.fixed_per_job * 100):+.1f}%)"
        )
    print(
        f"  PER_SAMPLE_OVERHEAD: {config.per_sample_overhead:.1f}s → {new_per_sample_overhead:.1f}s"
    )
    print(
        f"    (drift: {((new_per_sample_overhead - config.per_sample_overhead) / config.per_sample_overhead * 100):+.1f}%)"
    )
    print(
        f"\nNote: PER_SAMPLE_OVERHEAD is the total per-sample time (DURATION + overhead)."
    )
    print(
        f"To extract the pure overhead constant, subtract your DURATION from this value."
    )
    print(
        f"  Example: If DURATION=60s and average=78.6s, then overhead ≈ 18.6s"
    )

    # Update and save config
    if new_fixed_per_job is not None:
        config.fixed_per_job = new_fixed_per_job
    config.per_sample_overhead = new_per_sample_overhead
    config.calibration_note = DEFAULT_CALIBRATION_NOTE
    config.save(config_path)

    print(f"\nConfiguration saved to: {config_path}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Estimate regulus job runtime or recalibrate timing constants."
    )
    parser.add_argument(
        "root", nargs="?", help="Regulus repo root (default: current directory)"
    )
    parser.add_argument(
        "--calibrate",
        metavar="LOG",
        help="Recalibrate constants from a crucible run log (2 iter × 3 samples recommended)",
    )

    args = parser.parse_args()

    # Determine regulus root and config path
    # Config lives next to the script in bin/ directory for self-contained organization
    # Named to match the script: runtime-estimator.py → runtime-estimator.json
    regulus_root = args.root or os.getcwd()
    script_dir = os.path.dirname(os.path.abspath(__file__))
    config_path = os.path.join(script_dir, "runtime-estimator.json")

    # Load existing config or use defaults
    config = Config(config_path)

    if args.calibrate:
        # ---- CALIBRATION MODE ----
        calibrate(args.calibrate, config_path)
    else:
        # ---- ESTIMATION MODE ----
        if not os.path.isdir(regulus_root):
            print(f"Error: {regulus_root} is not a directory", file=sys.stderr)
            sys.exit(1)
        if not os.path.isfile(os.path.join(regulus_root, "jobs.config")):
            print(
                f"Error: {regulus_root} does not contain jobs.config",
                file=sys.stderr,
            )
            sys.exit(1)

        estimate_jobs(regulus_root, config)
