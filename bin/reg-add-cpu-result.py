#!/usr/bin/env python3
"""
Script to add the Busy-CPU value to result-summary.txt.
It extract the Busy-CPU values from the horizontal.sh script output.
Matches TPUT and CPU values to specific metric types.

FIXED VERSION: Handles multibench output correctly by:
1. Identifying metric type in each result line
2. Mapping TPUT values to correct metrics
3. Properly replacing all sample values (not just the first one)
"""

import re
import sys

def parse_source_file(source_path):
    """Parse source file and extract TPUT and CPU values per metric type."""
    with open(source_path, 'r') as f:
        content = f.read()

    # Try to extract metric type labels if present (e.g., "uperf-Gbps", "iperf-rx-Gbps")
    # Otherwise assume single metric

    # Extract TPUT values
    tput_match = re.search(r'TPUT:\s+([\d.\s]+)', content)

    if not tput_match:
        print("Error: Could not find TPUT values in source file")
        sys.exit(1)

    tput_values = [float(x) for x in tput_match.group(1).split()]

    # Extract CPU values if present
    cpu_match = re.search(r'CPU:\s+([\d.\s]+)', content)
    cpu_values = [float(x) for x in cpu_match.group(1).split()] if cpu_match else []

    # Validate that TPUT and CPU have the same count if CPU exists
    if cpu_values and len(cpu_values) != len(tput_values):
        print(f"Warning: TPUT has {len(tput_values)} values but CPU has {len(cpu_values)} values")

    return {
        'tput': tput_values,
        'cpu': cpu_values
    }

def extract_metric_type(line):
    """Extract metric type from result line.

    Examples:
        result: (uperf::Gbps) ... -> 'uperf::Gbps'
        result: (uperf::connections-sec) ... -> 'uperf::connections-sec'
        result: (iperf::rx-Gbps) ... -> 'iperf::rx-Gbps'
    """
    match = re.search(r'result:\s*\(([^)]+)\)', line)
    if match:
        return match.group(1)
    return None

def update_result_line(line, tput_value, cpu_value=None):
    """Update a result line with new TPUT and CPU values.

    Properly handles multiple sample values by replacing all of them.
    """
    # Extract the existing samples to count them
    samples_match = re.search(r'samples:\s+([\d.\s]+?)(?:\s+mean:)', line)
    if not samples_match:
        print(f"Warning: Could not find samples in line: {line.strip()}")
        return line

    existing_samples = samples_match.group(1).split()
    num_samples = len(existing_samples)

    # Create new samples string (all same value)
    new_samples = ' '.join([str(tput_value)] * num_samples)

    # Replace samples
    updated_line = re.sub(
        r'samples:\s+[\d.\s]+?(?=\s+mean:)',
        f'samples: {new_samples}',
        line
    )

    # Replace mean, min, max
    updated_line = re.sub(r'mean:\s+[\d.]+', f'mean: {tput_value}', updated_line)
    updated_line = re.sub(r'min:\s+[\d.]+', f'min: {tput_value}', updated_line)
    updated_line = re.sub(r'max:\s+[\d.]+', f'max: {tput_value}', updated_line)

    # Add CPU value at the end of the line if available
    if cpu_value is not None:
        # Remove existing CPU value if present
        updated_line = re.sub(r'\s+CPU:\s+[\d.]+', '', updated_line)
        # Add new CPU value
        updated_line = updated_line.rstrip('\n') + f' CPU: {cpu_value}\n'

    return updated_line

def identify_target_metric(lines):
    """Identify which metric type should receive the TPUT updates.

    For multibench tests, we need to determine which metric corresponds
    to the TPUT values in horizontal.txt.

    Priority order:
    1. uperf::Gbps (most common for uperf throughput tests)
    2. iperf::rx-Gbps (for iperf throughput tests)
    3. First metric found
    """
    metrics = []
    for line in lines:
        if 'result:' in line:
            metric_type = extract_metric_type(line)
            if metric_type and metric_type not in metrics:
                metrics.append(metric_type)

    print(f"Found metrics in result file: {', '.join(metrics)}")

    # Priority-based selection
    if 'uperf::Gbps' in metrics:
        return 'uperf::Gbps'
    elif 'iperf::rx-Gbps' in metrics:
        return 'iperf::rx-Gbps'
    elif metrics:
        return metrics[0]

    return None

def update_destination_file(dest_path, values, output_path=None, target_metric=None):
    """Update destination file with extracted values.

    Args:
        dest_path: Path to result-summary.txt
        values: Dictionary with 'tput' and 'cpu' lists
        output_path: Optional output path (if None, updates in place)
        target_metric: Specific metric type to update (e.g., 'uperf::Gbps')
                      If None, auto-detect
    """
    with open(dest_path, 'r') as f:
        lines = f.readlines()

    # Auto-detect target metric if not specified
    if target_metric is None:
        target_metric = identify_target_metric(lines)
        if target_metric:
            print(f"Auto-detected target metric: {target_metric}")
        else:
            print("Error: Could not detect target metric")
            sys.exit(1)

    updated_lines = []
    iteration_count = 0

    for i, line in enumerate(lines):
        # Check for result line
        if 'result:' in line:
            metric_type = extract_metric_type(line)

            # Only update lines matching the target metric
            if metric_type == target_metric:
                # Make sure we have values for this iteration
                if iteration_count < len(values['tput']):
                    tput_value = values['tput'][iteration_count]
                    cpu_value = values['cpu'][iteration_count] if values['cpu'] and iteration_count < len(values['cpu']) else None

                    updated_line = update_result_line(line, tput_value, cpu_value)
                    updated_lines.append(updated_line)

                    print(f"Updated iteration {iteration_count + 1} ({metric_type}): TPUT={tput_value}" +
                          (f", CPU={cpu_value}" if cpu_value else ""))

                    iteration_count += 1
                else:
                    print(f"Warning: More iterations in destination than values in source (skipping iteration {iteration_count + 1})")
                    updated_lines.append(line)
            else:
                # Different metric type, leave unchanged
                updated_lines.append(line)
        else:
            updated_lines.append(line)

    # Check if we used all values
    if iteration_count < len(values['tput']):
        print(f"Warning: Source has {len(values['tput'])} values but only {iteration_count} iterations were updated")

    # Write to output file
    output_file = output_path if output_path else dest_path
    with open(output_file, 'w') as f:
        f.writelines(updated_lines)

    print(f"\nSuccessfully updated {output_file}")
    print(f"Updated {iteration_count} iterations for metric: {target_metric}")
    print(f"TPUT values applied: {', '.join(str(v) for v in values['tput'][:iteration_count])}")
    if values['cpu']:
        print(f"CPU values applied: {', '.join(str(v) for v in values['cpu'][:iteration_count])}")

def main():
    if len(sys.argv) < 3:
        print("Usage: python script.py <source_file> <destination_file> [output_file] [metric_type]")
        print("  source_file: horizontal.txt with TPUT and CPU values")
        print("  destination_file: result-summary.txt to update")
        print("  output_file: (optional) if not specified, destination_file will be updated in place")
        print("  metric_type: (optional) specific metric to update (e.g., 'uperf::Gbps', 'iperf::rx-Gbps')")
        print("               if not specified, will auto-detect based on priority")
        sys.exit(1)

    source_file = sys.argv[1]
    dest_file = sys.argv[2]
    output_file = sys.argv[3] if len(sys.argv) > 3 else None
    target_metric = sys.argv[4] if len(sys.argv) > 4 else None

    # Parse source file
    values = parse_source_file(source_file)
    print(f"Found {len(values['tput'])} TPUT values in source file: {values['tput']}")
    if values['cpu']:
        print(f"Found {len(values['cpu'])} CPU values in source file: {values['cpu']}")

    # Update destination file
    update_destination_file(dest_file, values, output_file, target_metric)

if __name__ == "__main__":
    main()
