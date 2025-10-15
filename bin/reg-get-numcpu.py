#!/usr/bin/env python3
"""
    Script to detect CPU resources and QoS class from resource files.
    Searches all *resource* files in current directory.

    Usage: DEBUG=1 reg-get-nimcpu.py
    Return: even number of CPU
"""
import glob
import re
import sys
import os

def parse_cpu_value(cpu_str):
    """
    Parse CPU value from various formats:
    - "33000m" -> 33.0
    - "2" -> 2.0
    - 1 -> 1.0
    """
    if isinstance(cpu_str, (int, float)):
        return float(cpu_str)
    
    cpu_str = str(cpu_str).strip().strip('"')
    
    # Handle millicores (e.g., "33000m")
    if cpu_str.endswith('m'):
        return float(cpu_str[:-1]) / 1000.0
    
    # Handle regular CPU count
    return float(cpu_str)

def extract_cpu_resources(file_path):
    """
    Extract CPU request and limit from a resource file.
    Returns tuple: (cpu_request, cpu_limit, qos_class)
    """
    try:
        with open(file_path, 'r') as f:
            content = f.read()
        
        cpu_request = None
        cpu_limit = None
        
        # Extract CPU request
        request_match = re.search(r'"requests":\s*{[^}]*"cpu":\s*"?([^",\s]+)"?', content, re.DOTALL)
        if request_match:
            cpu_request = parse_cpu_value(request_match.group(1))
        
        # Extract CPU limit
        limit_match = re.search(r'"limits":\s*{[^}]*"cpu":\s*"?([^",\s]+)"?', content, re.DOTALL)
        if limit_match:
            cpu_limit = parse_cpu_value(limit_match.group(1))
        
        # Determine QoS class
        if cpu_request is not None and cpu_limit is not None:
            if cpu_request == cpu_limit:
                qos_class = "Guaranteed"
            else:
                qos_class = "Burstable"
        elif cpu_request is not None:
            qos_class = "Burstable"
        else:
            qos_class = "BestEffort"
        
        return cpu_request, cpu_limit, qos_class
        
    except Exception as e:
        if os.environ.get('DEBUG', '').lower() in ('1', 'true', 'yes'):
            print(f"Error reading {file_path}: {e}", file=sys.stderr)
        return None, None, None

def main():
    # Check if debug mode is enabled
    debug = os.environ.get('DEBUG', '').lower() in ('1', 'true', 'yes')
    
    # Find all files matching *resource* pattern in current directory
    resource_files = glob.glob('*resource*')
    
    if not resource_files:
        if debug:
            print("No resource files found in current directory")
        sys.exit(1)
    
    if debug:
        print(f"Found {len(resource_files)} resource file(s)\n")
    
    # Process each file
    for file_path in resource_files:
        cpu_request, cpu_limit, qos_class = extract_cpu_resources(file_path)
        
        if debug:
            print(f"File: {file_path}")
            if cpu_request is not None:
                print(f"  CPU Request: {cpu_request}")
            if cpu_limit is not None:
                print(f"  CPU Limit: {cpu_limit}")
            print(f"  QoS Class: {qos_class}")
            print()
        
        # In non-debug mode, output CPU request value with QoS indicator
        if not debug and cpu_request is not None:
            # Format the output to remove unnecessary decimal places
            if cpu_request == int(cpu_request):
                cpu_str = str(int(cpu_request))
            else:
                cpu_str = str(cpu_request)
            
            # Add (Gu) suffix for Guaranteed QoS
            if qos_class == "Guaranteed":
                print(f"{cpu_str}(Gu)", end='')
            else:
                print(cpu_str, end='')
            return cpu_request
    
    # If no CPU found in any file
    if not debug:
        print('0', end='')
    
    return 0

if __name__ == "__main__":
    result = main()
    sys.exit(0)
