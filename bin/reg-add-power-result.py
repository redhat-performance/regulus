#!/usr/bin/env python3
"""
Script to add redfish-bmc and mlxreg power values to result-summary.txt.
Extracts power metrics from Crucible HTTP API and appends them as separate lines.

For redfish-bmc: Shows consumed power (mean across samples) for each csid
For mlxreg: Shows vr0, vr1, and total-power (mean across samples) for each hostname
  - If total-power (sensor 127) is available, uses that value
  - If not available (old runs), computes total as vr0 + vr1

Usage: reg-add-power-result.py [result-summary.txt] [output_file]
"""

import re
import sys
import os
import json
from collections import defaultdict
try:
    # Python 3
    from urllib.request import Request, urlopen
    from urllib.error import URLError
except ImportError:
    # Python 2 (fallback)
    from urllib2 import Request, urlopen, URLError

def parse_available_sources(summary_path):
    """Parse result-summary.txt to check which metric sources are available.

    Returns: dict with keys 'redfish-bmc' and 'mlxreg' set to True/False
    """
    with open(summary_path, 'r') as f:
        content = f.read()

    available = {
        'redfish-bmc': False,
        'mlxreg': False
    }

    # Look for source declarations in the metrics section
    if re.search(r'source:\s+redfish-bmc', content, re.IGNORECASE):
        available['redfish-bmc'] = True
    if re.search(r'source:\s+mlxreg', content, re.IGNORECASE):
        available['mlxreg'] = True

    return available

def parse_result_summary_structure(summary_path):
    """Parse result-summary.txt to extract iterations with their period IDs.

    Returns: List of dicts with structure:
    [
        {
            'iteration_id': '...',
            'period_ids': ['id1', 'id2', 'id3'],
            'result_line_number': 45  # Line number of last result in this iteration
        },
        ...
    ]
    """
    with open(summary_path, 'r') as f:
        lines = f.readlines()

    iterations = []
    current_iteration = None

    for line_num, line in enumerate(lines):
        # Find iteration start
        if 'iteration-id:' in line:
            if current_iteration:
                iterations.append(current_iteration)

            match = re.search(r'iteration-id:\s+([A-F0-9-]+)', line, re.IGNORECASE)
            if match:
                current_iteration = {
                    'iteration_id': match.group(1),
                    'period_ids': [],
                    'result_line_number': None
                }

        # Collect period IDs within iteration
        elif current_iteration and 'primary period-id:' in line:
            match = re.search(r'primary period-id:\s+([A-F0-9-]+)', line, re.IGNORECASE)
            if match:
                current_iteration['period_ids'].append(match.group(1))

        # Track last result line in iteration
        elif current_iteration and 'result:' in line:
            current_iteration['result_line_number'] = line_num

    # Add last iteration
    if current_iteration:
        iterations.append(current_iteration)

    return iterations

def query_crucible_api(period_id, source, metric_type, breakout=None):
    """Query Crucible HTTP API for metrics.

    Args:
        period_id: The period UUID
        source: Metric source (e.g., 'redfish-bmc', 'mlxreg')
        metric_type: Metric type (e.g., 'power', 'power-watts')
        breakout: Optional breakout string (e.g., 'csid,metric', 'hostname,metric')

    Returns:
        Parsed JSON dict from API or None on error
    """
    # Get API URL from environment or use default
    api_url = os.environ.get('CRUCIBLE_API_URL', 'http://localhost:3000')

    # Build JSON payload
    payload = {
        'period': period_id,
        'source': source,
        'type': metric_type
    }

    if breakout:
        payload['breakout'] = breakout

    # Prepare request
    url = f"{api_url}/api/v1/metric-data"
    data = json.dumps(payload).encode('utf-8')
    headers = {'Content-Type': 'application/json'}

    try:
        req = Request(url, data=data, headers=headers)
        response = urlopen(req, timeout=30)
        result = response.read().decode('utf-8')
        return json.loads(result)
    except URLError as e:
        print(f"  Warning: HTTP API query failed: {e}", file=sys.stderr)
        return None
    except Exception as e:
        print(f"  Warning: Unexpected error: {e}", file=sys.stderr)
        return None

def parse_redfish_metrics(api_response):
    """Parse redfish-bmc JSON API response and extract consumed power per csid.

    Returns dict: {csid: value, ...}
    """
    if not api_response or 'values' not in api_response:
        return {}

    metrics = {}
    values = api_response['values']

    for key, data_points in values.items():
        # Key format: "<csid>-<metric>"
        # Example: "<remotehosts-1-power-srv-22-1>-<consumed>"
        if '-<consumed>' in key and data_points:
            # Extract csid: remove angle brackets, then split on -consumed
            clean_key = key.replace('<', '').replace('>', '')
            csid = clean_key.split('-consumed')[0]
            # Get the value from first data point
            value = data_points[0]['value']
            metrics[csid] = value

    return metrics

def parse_mlxreg_metrics(api_response):
    """Parse mlxreg JSON API response and extract vr0-power, vr1-power, and total-power per hostname.

    Returns dict: {hostname: {'vr0': value, 'vr1': value, 'total': value}, ...}
    """
    if not api_response or 'values' not in api_response:
        return {}

    # Dictionary to store vr0, vr1, and total power per hostname
    hostname_power = {}

    values = api_response['values']

    for key, data_points in values.items():
        # Key format: "<hostname>-<metric>"
        # Example: "<nvd-srv-22.nvidia.eng.rdu2.dc.redhat.com>-<vr0-power>"
        if data_points and ('-<vr0-power>' in key or '-<vr1-power>' in key or '-<total-power>' in key):
            # Extract hostname: remove angle brackets, then split on metric
            clean_key = key.replace('<', '').replace('>', '')
            # Split on metric name (without angle brackets)
            if '-vr0-power' in clean_key:
                hostname = clean_key.split('-vr0-power')[0]
                metric_type = 'vr0'
            elif '-vr1-power' in clean_key:
                hostname = clean_key.split('-vr1-power')[0]
                metric_type = 'vr1'
            elif '-total-power' in clean_key:
                hostname = clean_key.split('-total-power')[0]
                metric_type = 'total'
            else:
                continue

            # Get the value from first data point
            value = data_points[0]['value']

            # Store vr0, vr1, and total separately for each hostname
            if hostname not in hostname_power:
                hostname_power[hostname] = {'vr0': 0.0, 'vr1': 0.0, 'total': 0.0}
            hostname_power[hostname][metric_type] = value

    return hostname_power

def get_mean_power_metrics(period_ids, available_sources):
    """Query power metrics for multiple periods and calculate mean.

    Args:
        period_ids: List of period UUIDs to query
        available_sources: Dict with 'redfish-bmc' and 'mlxreg' availability

    Returns:
        {
            'redfish': {csid: mean_value, ...},
            'mlxreg': {hostname: {'vr0': mean_vr0, 'vr1': mean_vr1, 'total': mean_total}, ...}
        }
    """
    # Collect metrics from all periods
    redfish_by_period = []  # List of {csid: value} dicts
    mlxreg_by_period = []   # List of {hostname: {'vr0': value, 'vr1': value, 'total': value}} dicts

    for period_id in period_ids:
        # Get redfish-bmc power metric only if available
        if available_sources['redfish-bmc']:
            response = query_crucible_api(period_id, 'redfish-bmc', 'power', 'csid,metric')
            if response:
                redfish_by_period.append(parse_redfish_metrics(response))

        # Get mlxreg power-watts metric only if available
        if available_sources['mlxreg']:
            response = query_crucible_api(period_id, 'mlxreg', 'power-watts', 'hostname,metric')
            if response:
                mlxreg_by_period.append(parse_mlxreg_metrics(response))

    # Calculate mean for redfish metrics
    redfish_mean = {}
    if redfish_by_period:
        # Get all unique csids
        all_csids = set()
        for period_data in redfish_by_period:
            all_csids.update(period_data.keys())

        # Calculate mean for each csid
        for csid in all_csids:
            values = [period_data.get(csid, 0) for period_data in redfish_by_period if csid in period_data]
            if values:
                redfish_mean[csid] = sum(values) / len(values)

    # Calculate mean for mlxreg metrics (vr0, vr1, and total separately)
    mlxreg_mean = {}
    if mlxreg_by_period:
        # Get all unique hostnames
        all_hostnames = set()
        for period_data in mlxreg_by_period:
            all_hostnames.update(period_data.keys())

        # Calculate mean for each hostname's vr0, vr1, and total
        for hostname in all_hostnames:
            vr0_values = [period_data[hostname]['vr0'] for period_data in mlxreg_by_period if hostname in period_data]
            vr1_values = [period_data[hostname]['vr1'] for period_data in mlxreg_by_period if hostname in period_data]
            total_values = [period_data[hostname]['total'] for period_data in mlxreg_by_period if hostname in period_data]

            if vr0_values and vr1_values:
                mean_vr0 = sum(vr0_values) / len(vr0_values)
                mean_vr1 = sum(vr1_values) / len(vr1_values)
                mean_total = sum(total_values) / len(total_values) if total_values else 0.0

                # If total-power (sensor 127) is not available, compute from vr0+vr1
                if mean_total == 0.0:
                    mean_total = mean_vr0 + mean_vr1

                mlxreg_mean[hostname] = {
                    'vr0': mean_vr0,
                    'vr1': mean_vr1,
                    'total': mean_total
                }

    return {
        'redfish': redfish_mean,
        'mlxreg': mlxreg_mean
    }

def update_result_summary(summary_path, output_path=None):
    """Update result-summary.txt with mean power metrics."""
    # Check which metric sources are available
    available_sources = parse_available_sources(summary_path)

    print(f"Available power sources:", file=sys.stderr)
    print(f"  redfish-bmc: {available_sources['redfish-bmc']}", file=sys.stderr)
    print(f"  mlxreg: {available_sources['mlxreg']}", file=sys.stderr)

    # Skip processing if no power sources are available
    if not available_sources['redfish-bmc'] and not available_sources['mlxreg']:
        print("\nNo power sources (redfish-bmc or mlxreg) found in result-summary.txt", file=sys.stderr)
        print("Skipping power metric processing", file=sys.stderr)
        # Just copy the file as-is
        with open(summary_path, 'r') as f:
            content = f.read()
        output_file = output_path if output_path else summary_path
        with open(output_file, 'w') as f:
            f.write(content)
        return

    # Parse the structure to find iterations and their periods
    iterations = parse_result_summary_structure(summary_path)

    if not iterations:
        print("Error: Could not find any iterations in result-summary.txt", file=sys.stderr)
        sys.exit(1)

    print(f"\nFound {len(iterations)} iterations", file=sys.stderr)

    # Read all lines
    with open(summary_path, 'r') as f:
        lines = f.readlines()

    # Process each iteration and collect power metrics
    iteration_metrics = {}
    for idx, iteration in enumerate(iterations):
        print(f"\nProcessing iteration {idx + 1}: {iteration['iteration_id']}", file=sys.stderr)
        print(f"  Samples: {len(iteration['period_ids'])}", file=sys.stderr)

        if not iteration['period_ids']:
            print(f"  Warning: No period IDs found for this iteration", file=sys.stderr)
            continue

        # Get mean power metrics across all samples
        metrics = get_mean_power_metrics(iteration['period_ids'], available_sources)

        if metrics['redfish']:
            print(f"  Found {len(metrics['redfish'])} redfish-bmc consumed power metrics (mean)", file=sys.stderr)
            for csid, value in metrics['redfish'].items():
                print(f"    {csid}: {value:.2f} W", file=sys.stderr)

        if metrics['mlxreg']:
            print(f"  Found {len(metrics['mlxreg'])} mlxreg power metrics (mean)", file=sys.stderr)
            for hostname, values in metrics['mlxreg'].items():
                total = values['total']
                print(f"    {hostname}: vr0={values['vr0']:.2f} vr1={values['vr1']:.2f} total={total:.2f} W", file=sys.stderr)

        # Store metrics indexed by result line number
        if iteration['result_line_number'] is not None:
            iteration_metrics[iteration['result_line_number']] = metrics

    # Insert power metrics after the last result line of each iteration
    updated_lines = []
    for line_num, line in enumerate(lines):
        updated_lines.append(line)

        # Check if this is the last result line of an iteration
        if line_num in iteration_metrics:
            metrics = iteration_metrics[line_num]

            # Add redfish-bmc consumed power - one line per csid
            for csid, value in sorted(metrics['redfish'].items()):
                indent = ' ' * 12  # Match indentation of result line
                power_line = f"{indent}redfish-bmc ({csid}): mean consumed: {value:.2f} W\n"
                updated_lines.append(power_line)

            # Add mlxreg vr0, vr1, and total - one line per hostname
            for hostname, values in sorted(metrics['mlxreg'].items()):
                indent = ' ' * 12
                vr0 = values['vr0']
                vr1 = values['vr1']
                total = values['total']
                power_line = f"{indent}mlxreg ({hostname}): mean (vr0/vr1/Total): {vr0:.2f} {vr1:.2f} {total:.2f} W\n"
                updated_lines.append(power_line)

    # Write to output file
    output_file = output_path if output_path else summary_path
    with open(output_file, 'w') as f:
        f.writelines(updated_lines)

    print(f"\nSuccessfully updated {output_file}", file=sys.stderr)
    print(f"Updated {len(iteration_metrics)} iterations with mean power metrics", file=sys.stderr)

def main():
    if len(sys.argv) < 1:
        print("Usage: python reg-add-power-result.py [result-summary.txt] [output_file]", file=sys.stderr)
        print("  result-summary.txt: Optional input file (default: result-summary.txt)", file=sys.stderr)
        print("  output_file: Optional output file (default: report-power.txt)", file=sys.stderr)
        print("", file=sys.stderr)
        print("Examples:", file=sys.stderr)
        print("  reg-add-power-result.py", file=sys.stderr)
        print("  reg-add-power-result.py result-summary.txt", file=sys.stderr)
        print("  reg-add-power-result.py result-summary.txt custom-output.txt", file=sys.stderr)
        print("", file=sys.stderr)
        print("Environment Variables:", file=sys.stderr)
        print("  CRUCIBLE_API_URL: Crucible API endpoint (default: http://localhost:3000)", file=sys.stderr)
        sys.exit(1)

    summary_file = sys.argv[1] if len(sys.argv) > 1 else "result-summary.txt"
    output_file = sys.argv[2] if len(sys.argv) > 2 else "report-power.txt"

    if not os.path.isfile(summary_file):
        print(f"Error: Result summary file not found: {summary_file}", file=sys.stderr)
        sys.exit(1)

    # Update result summary with power metrics
    update_result_summary(summary_file, output_file)

    print(f"\nPower report created: {output_file}", file=sys.stderr)

if __name__ == "__main__":
    main()
