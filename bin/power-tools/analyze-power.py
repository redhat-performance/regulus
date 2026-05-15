#!/usr/bin/env python3
"""
Analyze power consumption from regulus test results.
Parses report-power.txt files to extract and analyze BMC and BF3 NIC power metrics.

Common commands:
  python3 bin/analyze-power.py summary                      # Overall stats
  python3 bin/analyze-power.py count --group-by test-type   # Count iterations
  python3 bin/analyze-power.py by-server                    # Compare servers
  python3 bin/analyze-power.py nic-breakdown                # VR0 vs VR1
  python3 bin/analyze-power.py by-profile                   # By workload
  python3 bin/analyze-power.py find-high --limit 5          # Top 5 power consumers
  python3 bin/analyze-power.py find-low --metric nic        # Lowest NIC power

Usage: run at REG_ROOT

"""

import argparse
import re
import sys
from pathlib import Path
from collections import defaultdict
from dataclasses import dataclass
from typing import Dict, List, Optional
import statistics


@dataclass
class PowerMetrics:
    """Power metrics for a single iteration"""
    iteration_id: str
    run_path: str
    benchmark: str
    test_type: str
    protocol: str
    topology: str
    bmc_power: Dict[str, float]  # server -> watts
    nic_vr0: Dict[str, float]    # server -> watts
    nic_vr1: Dict[str, float]    # server -> watts
    nic_total: Dict[str, float]  # server -> watts


class PowerAnalyzer:
    def __init__(self, reg_root: Path):
        self.reg_root = reg_root
        self.metrics: List[PowerMetrics] = []
        self._load_data()

    def _load_data(self):
        """Load all power metrics from report-power.txt files"""
        for report_file in self.reg_root.rglob("report-power.txt"):
            # Skip nested copies in blob subdirectories (only process run-level artifacts)
            # If report-power.txt is in a subdirectory with a UUID-like name or /run subdirectory, skip it
            parent_path = str(report_file.parent.relative_to(self.reg_root))

            # Skip if this is in a nested blob directory (contains UUID pattern or /run subdir)
            # Example to skip: run-xxx/iperf-and-uperf--2026-05-13_22:14:44_UTC--9c107e5b.../run/report-power.txt
            # Example to keep: run-xxx/report-power.txt
            if '/run/' in parent_path or parent_path.endswith('/run'):
                continue

            # Skip if path contains a crucible run UUID pattern (timestamp + UUID)
            import re
            if re.search(r'/\w+-\d{4}-\d{2}-\d{2}_\d{2}:\d{2}:\d{2}_[A-Z]+-[-0-9a-f]{36}/', parent_path):
                continue

            self._parse_report(report_file)

    def _parse_report(self, report_file: Path):
        """Parse a single report-power.txt file"""
        with open(report_file, 'r') as f:
            content = f.read()

        # Extract global parameters
        protocol_match = re.search(r'protocol=(\w+)', content)
        protocol = protocol_match.group(1) if protocol_match else "unknown"

        topo_match = re.search(r'topo=(\w+)', content)
        topology = topo_match.group(1) if topo_match else "unknown"

        # Check if this is a multibench run (benchmark field contains comma-separated values)
        bench_match = re.search(r'benchmark:\s+(.+)', content)
        if bench_match:
            bench_value = bench_match.group(1).strip()
            # If benchmark contains comma or multiple benchmark types, it's multibench
            if ',' in bench_value or ('iperf' in bench_value and 'uperf' in bench_value):
                benchmark = "multibench"
            else:
                benchmark = bench_value
        else:
            benchmark = "unknown"

        run_path = str(report_file.parent.relative_to(self.reg_root))

        # Process each iteration
        for iteration_block in re.finditer(r'iteration-id:.*?(?=iteration-id:|$)', content, re.DOTALL):
            block_text = iteration_block.group(0)

            # Extract iteration ID
            iter_id_match = re.search(r'iteration-id:\s+([A-F0-9-]+)', block_text)
            iter_id = iter_id_match.group(1) if iter_id_match else "unknown"

            # Extract test-type
            test_type_match = re.search(r'test-type=(\w+)', block_text)
            test_type = test_type_match.group(1) if test_type_match else "unknown"

            # iperf only does stream traffic, so if benchmark is iperf (not multibench) and test-type is unknown, set to stream
            if benchmark == "iperf" and test_type == "unknown":
                test_type = "stream"

            # Extract power metrics
            bmc_power = {}
            nic_vr0 = {}
            nic_vr1 = {}
            nic_total = {}

            # Parse redfish-bmc
            for bmc_match in re.finditer(
                r'redfish-bmc \(remotehosts-1-power-srv-(\d+)-1\): mean consumed: ([\d.]+) W',
                block_text
            ):
                server = f"srv-{bmc_match.group(1)}"
                power = float(bmc_match.group(2))
                bmc_power[server] = power

            # Parse mlxreg
            for mlx_match in re.finditer(
                r'mlxreg \(nvd-srv-(\d+)\.nvidia\.eng\.rdu2\.dc\.redhat\.com\): mean \(vr0/vr1/Total\): ([\d.]+) ([\d.]+) ([\d.]+) W',
                block_text
            ):
                server = f"srv-{mlx_match.group(1)}"
                vr0 = float(mlx_match.group(2))
                vr1 = float(mlx_match.group(3))
                total = float(mlx_match.group(4))
                nic_vr0[server] = vr0
                nic_vr1[server] = vr1
                nic_total[server] = total

            # Only create metrics if we have power data
            if bmc_power or nic_total:
                metrics = PowerMetrics(
                    iteration_id=iter_id,
                    run_path=run_path,
                    benchmark=benchmark,
                    test_type=test_type,
                    protocol=protocol,
                    topology=topology,
                    bmc_power=bmc_power,
                    nic_vr0=nic_vr0,
                    nic_vr1=nic_vr1,
                    nic_total=nic_total
                )
                self.metrics.append(metrics)

    def summary(self):
        """Print overall power consumption summary"""
        # Collect data by server
        data = {
            'srv-22': {'bmc': [], 'nic': [], 'vr0': [], 'vr1': []},
            'srv-23': {'bmc': [], 'nic': [], 'vr0': [], 'vr1': []}
        }

        for m in self.metrics:
            for server in ['srv-22', 'srv-23']:
                if server in m.bmc_power:
                    data[server]['bmc'].append(m.bmc_power[server])
                if server in m.nic_total:
                    data[server]['nic'].append(m.nic_total[server])
                if server in m.nic_vr0:
                    data[server]['vr0'].append(m.nic_vr0[server])
                if server in m.nic_vr1:
                    data[server]['vr1'].append(m.nic_vr1[server])

        print(f"\nOVERALL POWER CONSUMPTION ({len(self.metrics)} iterations)")
        print("=" * 90)
        print(f"{'Server/NIC':<10} {'Metric':<20} {'Samples':<10} {'Mean':<10} {'Min':<10} {'Max':<10} {'StdDev':<10}")
        print("-" * 90)

        for server in ['srv-22', 'srv-23']:
            if data[server]['bmc']:
                vals = data[server]['bmc']
                print(f"{server:<10} {'BMC Consumed (W)':<20} {len(vals):<10} {statistics.mean(vals):<10.2f} "
                      f"{min(vals):<10.2f} {max(vals):<10.2f} {statistics.stdev(vals) if len(vals) > 1 else 0:<10.2f}")

            if data[server]['nic']:
                vals = data[server]['nic']
                nic_name = f"BF3-{server.split('-')[1]}"
                print(f"{nic_name:<10} {'BF3 NIC Total (W)':<20} {len(vals):<10} {statistics.mean(vals):<10.2f} "
                      f"{min(vals):<10.2f} {max(vals):<10.2f} {statistics.stdev(vals) if len(vals) > 1 else 0:<10.2f}")

        print()

    def by_profile(self, test_type: Optional[str] = None, protocol: Optional[str] = None,
                   topology: Optional[str] = None):
        """Analyze power by workload profile"""
        # Group by profile
        profiles = defaultdict(lambda: {
            'srv-22': {'bmc': [], 'vr0': [], 'vr1': [], 'total': []},
            'srv-23': {'bmc': [], 'vr0': [], 'vr1': [], 'total': []}
        })

        for m in self.metrics:
            # Apply filters
            if test_type and m.test_type != test_type:
                continue
            if protocol and m.protocol != protocol:
                continue
            if topology and m.topology != topology:
                continue

            # If test-type is unknown and benchmark is known, use benchmark name
            if m.test_type == "unknown" and m.benchmark != "unknown":
                profile = f"{m.benchmark}/{m.protocol}/{m.topology}"
            else:
                profile = f"{m.test_type}/{m.protocol}/{m.topology}"

            for server in ['srv-22', 'srv-23']:
                if server in m.bmc_power:
                    profiles[profile][server]['bmc'].append(m.bmc_power[server])
                if server in m.nic_total:
                    profiles[profile][server]['total'].append(m.nic_total[server])
                if server in m.nic_vr0:
                    profiles[profile][server]['vr0'].append(m.nic_vr0[server])
                if server in m.nic_vr1:
                    profiles[profile][server]['vr1'].append(m.nic_vr1[server])

        print("\nPOWER BY WORKLOAD PROFILE")
        print("=" * 95)
        print(f"{'Server':<10} {'Profile':<35} {'BMC (W)':<12} {'BF3 Total (W)':<15} {'VR0 (W)':<10} {'VR1 (W)':<10}")
        print("-" * 95)

        for profile in sorted(profiles.keys()):
            for server in ['srv-22', 'srv-23']:
                d = profiles[profile][server]
                if d['bmc'] or d['total']:
                    bmc = f"{statistics.mean(d['bmc']):.2f}" if d['bmc'] else "N/A"
                    total = f"{statistics.mean(d['total']):.2f}" if d['total'] else "N/A"
                    vr0 = f"{statistics.mean(d['vr0']):.2f}" if d['vr0'] else "N/A"
                    vr1 = f"{statistics.mean(d['vr1']):.2f}" if d['vr1'] else "N/A"
                    print(f"{server:<10} {profile:<35} {bmc:<12} {total:<15} {vr0:<10} {vr1:<10}")
            print()

    def by_server(self):
        """Compare srv-22 vs srv-23"""
        self.summary()
        print("\nSERVER COMPARISON")
        print("=" * 70)

        srv22_bmc = [m.bmc_power.get('srv-22', 0) for m in self.metrics if 'srv-22' in m.bmc_power]
        srv23_bmc = [m.bmc_power.get('srv-23', 0) for m in self.metrics if 'srv-23' in m.bmc_power]
        srv22_nic = [m.nic_total.get('srv-22', 0) for m in self.metrics if 'srv-22' in m.nic_total]
        srv23_nic = [m.nic_total.get('srv-23', 0) for m in self.metrics if 'srv-23' in m.nic_total]

        if srv22_bmc and srv23_bmc:
            diff_bmc = statistics.mean(srv22_bmc) - statistics.mean(srv23_bmc)
            print(f"BMC Power Difference (srv-22 - srv-23): {diff_bmc:+.2f} W")

        if srv22_nic and srv23_nic:
            diff_nic = statistics.mean(srv22_nic) - statistics.mean(srv23_nic)
            print(f"BF3 NIC Power Difference (srv-22 - srv-23): {diff_nic:+.2f} W")

        print()

    def nic_breakdown(self):
        """Analyze BF3 NIC VR0/VR1 breakdown"""
        data = {
            'srv-22': {'vr0': [], 'vr1': []},
            'srv-23': {'vr0': [], 'vr1': []}
        }

        for m in self.metrics:
            for server in ['srv-22', 'srv-23']:
                if server in m.nic_vr0:
                    data[server]['vr0'].append(m.nic_vr0[server])
                if server in m.nic_vr1:
                    data[server]['vr1'].append(m.nic_vr1[server])

        print("\nBF3 NIC POWER BREAKDOWN (VR0 vs VR1)")
        print("=" * 90)
        print(f"{'NIC':<10} {'Component':<15} {'Samples':<10} {'Mean (W)':<12} {'Min (W)':<10} {'Max (W)':<10} {'% of Total':<12}")
        print("-" * 90)

        for server in ['srv-22', 'srv-23']:
            if data[server]['vr0'] and data[server]['vr1']:
                nic_name = f"BF3-{server.split('-')[1]}"
                total_mean = statistics.mean(data[server]['vr0']) + statistics.mean(data[server]['vr1'])

                # VR0
                vals = data[server]['vr0']
                mean_val = statistics.mean(vals)
                pct = (mean_val / total_mean * 100) if total_mean > 0 else 0
                print(f"{nic_name:<10} {'VR0':<15} {len(vals):<10} {mean_val:<12.2f} "
                      f"{min(vals):<10.2f} {max(vals):<10.2f} {pct:<12.1f}")

                # VR1
                vals = data[server]['vr1']
                mean_val = statistics.mean(vals)
                pct = (mean_val / total_mean * 100) if total_mean > 0 else 0
                print(f"{nic_name:<10} {'VR1':<15} {len(vals):<10} {mean_val:<12.2f} "
                      f"{min(vals):<10.2f} {max(vals):<10.2f} {pct:<12.1f}")
                print()

    def find_high(self, limit: int = 10, metric: str = 'bmc'):
        """Find highest power consuming iterations"""
        if metric == 'bmc':
            # Combine both servers
            items = []
            for m in self.metrics:
                for server, power in m.bmc_power.items():
                    items.append((power, server, m))
        else:  # nic
            items = []
            for m in self.metrics:
                for server, power in m.nic_total.items():
                    items.append((power, server, m))

        items.sort(key=lambda x: x[0], reverse=True)

        metric_name = "BMC Consumed" if metric == 'bmc' else "BF3 NIC Total"
        print(f"\nHIGHEST {metric_name.upper()} POWER (Top {limit})")
        print("=" * 140)
        print(f"{'Rank':<6} {'Power (W)':<12} {'Server':<10} {'Profile':<35} {'Run Path'}")
        print("-" * 140)

        for rank, (power, server, m) in enumerate(items[:limit], 1):
            # If test-type is unknown and benchmark is known, use benchmark name
            if m.test_type == "unknown" and m.benchmark != "unknown":
                profile = f"{m.benchmark}/{m.protocol}/{m.topology}"
            else:
                profile = f"{m.test_type}/{m.protocol}/{m.topology}"
            print(f"{rank:<6} {power:<12.2f} {server:<10} {profile:<35} {m.run_path}")
        print()

    def find_low(self, limit: int = 10, metric: str = 'bmc'):
        """Find lowest power consuming iterations"""
        if metric == 'bmc':
            items = []
            for m in self.metrics:
                for server, power in m.bmc_power.items():
                    items.append((power, server, m))
        else:  # nic
            items = []
            for m in self.metrics:
                for server, power in m.nic_total.items():
                    items.append((power, server, m))

        items.sort(key=lambda x: x[0])

        metric_name = "BMC Consumed" if metric == 'bmc' else "BF3 NIC Total"
        print(f"\nLOWEST {metric_name.upper()} POWER (Bottom {limit})")
        print("=" * 140)
        print(f"{'Rank':<6} {'Power (W)':<12} {'Server':<10} {'Profile':<35} {'Run Path'}")
        print("-" * 140)

        for rank, (power, server, m) in enumerate(items[:limit], 1):
            # If test-type is unknown and benchmark is known, use benchmark name
            if m.test_type == "unknown" and m.benchmark != "unknown":
                profile = f"{m.benchmark}/{m.protocol}/{m.topology}"
            else:
                profile = f"{m.test_type}/{m.protocol}/{m.topology}"
            print(f"{rank:<6} {power:<12.2f} {server:<10} {profile:<35} {m.run_path}")
        print()

    def count(self, group_by: str = 'test-type'):
        """Count iterations by grouping"""
        counts = defaultdict(int)

        for m in self.metrics:
            if group_by == 'test-type':
                key = m.test_type
            elif group_by == 'protocol':
                key = m.protocol
            elif group_by == 'topology':
                key = m.topology
            elif group_by == 'benchmark':
                key = m.benchmark
            else:
                # If test-type is unknown and benchmark is known, use benchmark name
                if m.test_type == "unknown" and m.benchmark != "unknown":
                    key = f"{m.benchmark}/{m.protocol}/{m.topology}"
                else:
                    key = f"{m.test_type}/{m.protocol}/{m.topology}"
            counts[key] += 1

        print(f"\nITERATION COUNT BY {group_by.upper()}")
        print("=" * 50)
        print(f"{'Category':<40} {'Count':<10}")
        print("-" * 50)

        for key in sorted(counts.keys()):
            print(f"{key:<40} {counts[key]:<10}")

        print("-" * 50)
        print(f"{'TOTAL':<40} {len(self.metrics):<10}")
        print()


def main():
    parser = argparse.ArgumentParser(description='Analyze power consumption from regulus test results')
    parser.add_argument('command', choices=[
        'summary', 'by-profile', 'by-server', 'nic-breakdown',
        'find-high', 'find-low', 'count'
    ], help='Analysis command to run')

    # Options for by-profile
    parser.add_argument('--test-type', help='Filter by test type')
    parser.add_argument('--protocol', help='Filter by protocol')
    parser.add_argument('--topology', help='Filter by topology')

    # Options for find-high/find-low
    parser.add_argument('--limit', type=int, default=10, help='Number of results to show')
    parser.add_argument('--metric', choices=['bmc', 'nic'], default='bmc', help='Power metric to analyze')

    # Options for count
    parser.add_argument('--group-by', choices=['test-type', 'protocol', 'topology', 'benchmark', 'profile'],
                        default='test-type', help='How to group iterations')

    args = parser.parse_args()

    # Determine REG_ROOT
    reg_root = Path('/home/hnhan/NVD-DPU/nvd-44-test-power-regulus')
    if not reg_root.exists():
        print(f"ERROR: REG_ROOT not found: {reg_root}", file=sys.stderr)
        return 1

    # Load data
    analyzer = PowerAnalyzer(reg_root)

    # Execute command
    if args.command == 'summary':
        analyzer.summary()
    elif args.command == 'by-profile':
        analyzer.by_profile(args.test_type, args.protocol, args.topology)
    elif args.command == 'by-server':
        analyzer.by_server()
    elif args.command == 'nic-breakdown':
        analyzer.nic_breakdown()
    elif args.command == 'find-high':
        analyzer.find_high(args.limit, args.metric)
    elif args.command == 'find-low':
        analyzer.find_low(args.limit, args.metric)
    elif args.command == 'count':
        analyzer.count(args.group_by)

    return 0


if __name__ == '__main__':
    sys.exit(main())
