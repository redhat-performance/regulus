#!/usr/bin/env python3
"""
Convert environment configuration file to JSON format.
Parses export statements from bash-style config files.
    Usage: python3 create_env_section.py config.txt -o output.json
"""

import json
import sys
import argparse


def convert_env_to_json(file_path):
    """
    Parse environment configuration file and convert to dictionary.
    
    Args:
        file_path: Path to the configuration file
        
    Returns:
        Dictionary with parsed key-value pairs
    """
    config = {}
    
    try:
        with open(file_path, 'r') as f:
            for line_num, line in enumerate(f, 1):
                line = line.strip()
                
                # Skip empty lines and comments
                if not line or line.startswith('#'):
                    continue
                
                # Parse export statements
                if line.startswith('export '):
                    # Remove 'export ' prefix
                    line = line[7:]
                    
                    # Split on first '=' only
                    if '=' in line:
                        key, value = line.split('=', 1)
                        key = key.strip()
                        # Remove quotes from value
                        value = value.strip('"').strip("'")
                        config[key] = value
                    else:
                        print(f"Warning: Line {line_num} has no '=' sign: {line}", 
                              file=sys.stderr)
                else:
                    # Optionally warn about non-export lines
                    if line:
                        print(f"Info: Skipping non-export line {line_num}: {line}", 
                              file=sys.stderr)
    
    except FileNotFoundError:
        print(f"Error: File '{file_path}' not found.", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error reading file: {e}", file=sys.stderr)
        sys.exit(1)
    
    return config


def main():
    parser = argparse.ArgumentParser(
        description='Convert bash environment config file to JSON format'
    )
    parser.add_argument(
        'input_file',
        help='Input configuration file (e.g., config.txt)'
    )
    parser.add_argument(
        '-o', '--output',
        help='Output JSON file (default: print to stdout)',
        default=None
    )
    parser.add_argument(
        '-i', '--indent',
        type=int,
        default=2,
        help='JSON indentation level (default: 2)'
    )
    parser.add_argument(
        '-q', '--quiet',
        action='store_true',
        help='Suppress info messages'
    )
    
    args = parser.parse_args()
    
    # Suppress info messages if quiet mode
    if args.quiet:
        sys.stderr = open('/dev/null', 'w')
    
    # Convert to JSON
    config = convert_env_to_json(args.input_file)
    
    if not config:
        print("Warning: No configuration values found.", file=sys.stderr)
    
    # Generate JSON string
    json_output = json.dumps(config, indent=args.indent)
    
    # Output to file or stdout
    if args.output:
        try:
            with open(args.output, 'w') as f:
                f.write(json_output)
            print(f"Successfully wrote JSON to {args.output}", file=sys.stderr)
        except Exception as e:
            print(f"Error writing output file: {e}", file=sys.stderr)
            sys.exit(1)
    else:
        print(json_output)


if __name__ == '__main__':
    main()
