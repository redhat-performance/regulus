#!/usr/bin/env python3
"""
    Script to add the Busy-CPU value to result-summary.txt.
    It extract the Busy-CPU values from the horizontal.sh script output.
    Also adds num CPU and datapath model to the tags line.
    Matches TPUT and CPU values order of appearance.

    Usage: reg-enhance-results.py horizontal.txt result-summary.tx <outfile>
"""
import re
import sys
import subprocess
import os

def get_cpu_resources():
    """Get CPU resources by invoking the reg-get-numcpu.py script."""
    try:
        reg_root = os.environ.get('REG_ROOT', '')
        script_path = os.path.join(reg_root, 'bin', 'reg-get-numcpu.py') if reg_root else 'reg-get-numcpu.py'
        
        result = subprocess.run(
            ['python3', script_path],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True,
            check=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        return None
    except FileNotFoundError:
        print(f"Warning: reg-get-numcpu.py not found at {script_path}", file=sys.stderr)
        return None

def get_datapath_model():
    """Get datapath model by invoking the reg-get-model.py script."""
    try:
        reg_root = os.environ.get('REG_ROOT', '')
        script_path = os.path.join(reg_root, 'bin', 'reg-get-model.py') if reg_root else 'reg-get-model.py'
        
        result = subprocess.run(
            ['python3', script_path],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True,
            check=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        return None
    except FileNotFoundError:
        print(f"Warning: reg-get-model.py not found at {script_path}", file=sys.stderr)
        return None

def parse_source_file(source_path):
    """Parse source file and extract TPUT and CPU values."""
    with open(source_path, 'r') as f:
        content = f.read()
    
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

def update_destination_file(dest_path, values, cpu_resource, datapath_model, output_path=None):
    """Update destination file with extracted values and metadata."""
    with open(dest_path, 'r') as f:
        lines = f.readlines()
    
    updated_lines = []
    iteration_count = 0
    tags_updated = False
    
    for i, line in enumerate(lines):
        # Update tags line with CPU resource and datapath model
        if line.strip().startswith('tags:') and not tags_updated:
            updated_line = line.rstrip('\n')
            
            # Add datapath model if available
            if datapath_model:
                updated_line += f' model={datapath_model}'
            
            # Add CPU resource if available
            if cpu_resource:
                updated_line += f' cpu={cpu_resource}'
            
            updated_line += '\n'
            updated_lines.append(updated_line)
            tags_updated = True
            continue
        
        # Check for result line with result:
        if 'result:' in line:
            # Make sure we have values for this iteration
            if iteration_count < len(values['tput']):
                new_tput_value = values['tput'][iteration_count]
                
                # Replace all occurrences of the old value with the new value
                updated_line = re.sub(
                    r'samples: [\d.]+',
                    f'samples: {new_tput_value}',
                    line
                )
                updated_line = re.sub(
                    r'mean: [\d.]+',
                    f'mean: {new_tput_value}',
                    updated_line
                )
                updated_line = re.sub(
                    r'min: [\d.]+',
                    f'min: {new_tput_value}',
                    updated_line
                )
                updated_line = re.sub(
                    r'max: [\d.]+',
                    f'max: {new_tput_value}',
                    updated_line
                )
                
                # Add CPU value at the end of the line if available
                if values['cpu'] and iteration_count < len(values['cpu']):
                    cpu_value = values['cpu'][iteration_count]
                    # Remove newline, add CPU value, then add newline back
                    updated_line = updated_line.rstrip('\n') + f' CPU: {cpu_value}\n'
                
                updated_lines.append(updated_line)
                iteration_count += 1
            else:
                print(f"Warning: More iterations in destination than values in source (skipping iteration {iteration_count + 1})")
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
    if cpu_resource:
        print(f"Added CPU resource: {cpu_resource}")
    if datapath_model:
        print(f"Added datapath model: {datapath_model}")
    print(f"Updated {iteration_count} iterations")
    print(f"TPUT values applied: {', '.join(str(v) for v in values['tput'][:iteration_count])}")
    if values['cpu']:
        print(f"CPU values applied: {', '.join(str(v) for v in values['cpu'][:iteration_count])}")

def main():
    if len(sys.argv) < 3:
        print("Usage: python script.py <source_file> <destination_file> [output_file]")
        print("  If output_file is not specified, destination_file will be updated in place")
        sys.exit(1)
    
    source_file = sys.argv[1]
    dest_file = sys.argv[2]
    output_file = sys.argv[3] if len(sys.argv) > 3 else None
    
    # Get CPU resources and datapath model
    cpu_resource = get_cpu_resources()
    datapath_model = get_datapath_model()
    
    # Parse source file
    values = parse_source_file(source_file)
    print(f"Found {len(values['tput'])} TPUT values in source file")
    if values['cpu']:
        print(f"Found {len(values['cpu'])} CPU values in source file")
    
    # Update destination file
    update_destination_file(dest_file, values, cpu_resource, datapath_model, output_file)

if __name__ == "__main__":
    main()

