#!/usr/bin/env python3
"""
Convert JSON array files to NDJSON bulk index format for OpenSearch.

Usage:
    ./json-to-bulk.py input.json output.ndjson [--index regulus-results-mock]
"""

import json
import sys
import argparse


def json_to_bulk(input_file, output_file, index_name="regulus-results-mock"):
    """Convert JSON array to NDJSON bulk format."""

    # Read JSON array
    with open(input_file, 'r') as f:
        documents = json.load(f)

    # Write NDJSON bulk format
    with open(output_file, 'w') as f:
        for doc in documents:
            # Index action
            action = {"index": {"_index": index_name}}
            f.write(json.dumps(action) + '\n')
            # Document
            f.write(json.dumps(doc) + '\n')

    return len(documents)


def main():
    parser = argparse.ArgumentParser(description='Convert JSON array to NDJSON bulk format')
    parser.add_argument('input', help='Input JSON file')
    parser.add_argument('output', help='Output NDJSON file')
    parser.add_argument('--index', default='regulus-results-mock',
                       help='Index name (default: regulus-results-mock)')

    args = parser.parse_args()

    try:
        count = json_to_bulk(args.input, args.output, args.index)
        print(f"✓ Converted {count} documents from {args.input} to {args.output}")
        print(f"  Index: {args.index}")
        print(f"\nTo index to OpenSearch:")
        print(f"  curl -X POST 'http://localhost:9200/_bulk' \\")
        print(f"    -H 'Content-Type: application/x-ndjson' \\")
        print(f"    --data-binary '@{args.output}'")
    except Exception as e:
        print(f"✗ Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
