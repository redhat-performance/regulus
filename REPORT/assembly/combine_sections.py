#!/usr/bin/env python3
"""
Combine multiple JSON files into a single JSON object.
Supports multiple merge strategies and nested key namespacing.

	Usage:	python3 combine_sections.py -s custom lab-config.json testbed.json  result-summary.json -k lab testbed result -o output.json

The 5 Merge Strategies:

	Flat - All keys at root (simple, watch for conflicts)
		python3 combine_sections.py config.json inventory.json -o output.json
	Nested - Files become keys based on filename
		python3 combine_sections.py -s nested config.json inventory.json -o output.json
	Custom - You specify the keys (recommended!)
		python3 combine_sections.py -s custom config.json inventory.json -k environment hosts -o output.json
	Deep - Recursive merge (great for config overrides)
    	python3 combine_sections.py -s deep base.json override.json -o output.json
	Array - List of all files with metadata
		python3 combine_sections.py -s array file1.json file2.json file3.json -o output.json

"""

import json
import sys
import argparse
from pathlib import Path


def load_json_file(file_path):
    """Load and parse a JSON file."""
    try:
        with open(file_path, 'r') as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"Error: File '{file_path}' not found.", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in '{file_path}': {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error reading '{file_path}': {e}", file=sys.stderr)
        sys.exit(1)


def merge_flat(json_objects, file_names):
    """
    Merge strategy: Flat merge - all keys at root level.
    Later files override earlier ones on key conflicts.
    """
    result = {}
    for obj, file_name in zip(json_objects, file_names):
        if not isinstance(obj, dict):
            print(f"Warning: '{file_name}' is not a JSON object, skipping.", 
                  file=sys.stderr)
            continue
        result.update(obj)
    return result


def merge_nested(json_objects, file_names):
    """
    Merge strategy: Nested - each file gets its own key based on filename.
    """
    result = {}
    for obj, file_name in zip(json_objects, file_names):
        # Use filename without extension as key
        key = Path(file_name).stem
        result[key] = obj
    return result


def merge_deep(json_objects, file_names):
    """
    Merge strategy: Deep merge - recursively merge nested dictionaries.
    """
    def deep_merge_dict(base, update):
        """Recursively merge update into base."""
        for key, value in update.items():
            if key in base and isinstance(base[key], dict) and isinstance(value, dict):
                deep_merge_dict(base[key], value)
            else:
                base[key] = value
        return base
    
    result = {}
    for obj, file_name in zip(json_objects, file_names):
        if not isinstance(obj, dict):
            print(f"Warning: '{file_name}' is not a JSON object, skipping.", 
                  file=sys.stderr)
            continue
        deep_merge_dict(result, obj)
    return result


def merge_array(json_objects, file_names):
    """
    Merge strategy: Array - combine all objects into an array.
    """
    result = []
    for obj, file_name in zip(json_objects, file_names):
        result.append({
            "source": file_name,
            "data": obj
        })
    return result


def merge_custom_keys(json_objects, file_names, custom_keys):
    """
    Merge strategy: Custom keys - use user-provided keys for each file.
    """
    if len(custom_keys) != len(json_objects):
        print("Error: Number of custom keys must match number of input files.", 
              file=sys.stderr)
        sys.exit(1)
    
    result = {}
    for obj, key in zip(json_objects, custom_keys):
        result[key] = obj
    return result


def main():
    parser = argparse.ArgumentParser(
        description='Combine multiple JSON files into one',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Merge Strategies:
  flat      - Merge all keys at root level (later files override)
  nested    - Each file becomes a key (based on filename)
  deep      - Recursively merge nested dictionaries
  array     - Combine into array with source metadata
  custom    - Use custom keys for each file (requires --keys)

Examples:
  # Flat merge (default)
  %(prog)s config.json inventory.json -o combined.json
  
  # Nested merge (preserve file structure)
  %(prog)s -s nested config.json inventory.json -o combined.json
  
  # Custom keys
  %(prog)s -s custom config.json inventory.json -k environment inventory -o combined.json
  
  # Deep merge (recursive)
  %(prog)s -s deep base.json override.json -o merged.json
        """
    )
    
    parser.add_argument(
        'input_files',
        nargs='+',
        help='Input JSON files to combine'
    )
    parser.add_argument(
        '-o', '--output',
        help='Output JSON file (default: print to stdout)',
        default=None
    )
    parser.add_argument(
        '-s', '--strategy',
        choices=['flat', 'nested', 'deep', 'array', 'custom'],
        default='flat',
        help='Merge strategy (default: flat)'
    )
    parser.add_argument(
        '-k', '--keys',
        nargs='+',
        help='Custom keys for each input file (required for custom strategy)',
        default=None
    )
    parser.add_argument(
        '-i', '--indent',
        type=int,
        default=2,
        help='JSON indentation level (default: 2)'
    )
    parser.add_argument(
        '--compact',
        action='store_true',
        help='Compact output (no indentation)'
    )
    parser.add_argument(
        '-q', '--quiet',
        action='store_true',
        help='Suppress info messages'
    )
    
    args = parser.parse_args()
    
    # Validate custom strategy
    if args.strategy == 'custom' and not args.keys:
        print("Error: --keys is required when using 'custom' strategy.", 
              file=sys.stderr)
        sys.exit(1)
    
    # Load all JSON files
    json_objects = []
    for file_path in args.input_files:
        if not args.quiet:
            print(f"Loading {file_path}...", file=sys.stderr)
        json_objects.append(load_json_file(file_path))
    
    # Merge based on strategy
    if args.strategy == 'flat':
        result = merge_flat(json_objects, args.input_files)
    elif args.strategy == 'nested':
        result = merge_nested(json_objects, args.input_files)
    elif args.strategy == 'deep':
        result = merge_deep(json_objects, args.input_files)
    elif args.strategy == 'array':
        result = merge_array(json_objects, args.input_files)
    elif args.strategy == 'custom':
        result = merge_custom_keys(json_objects, args.input_files, args.keys)
    
    # Generate JSON output
    indent = None if args.compact else args.indent
    json_output = json.dumps(result, indent=indent)
    
    # Output to file or stdout
    if args.output:
        try:
            with open(args.output, 'w') as f:
                f.write(json_output)
            if not args.quiet:
                print(f"Successfully wrote combined JSON to {args.output}", 
                      file=sys.stderr)
        except Exception as e:
            print(f"Error writing output file: {e}", file=sys.stderr)
            sys.exit(1)
    else:
        print(json_output)


if __name__ == '__main__':
    main()
