#!/usr/bin/env python3
"""
Debug script to find and display detailed ElasticSearch upload errors
"""
import sys
import json
import os

def main():
    # Read the ES bulk response from stdin
    try:
        response = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        print(f"ERROR: Failed to parse JSON response: {e}", file=sys.stderr)
        sys.exit(1)

    items = response.get('items', [])
    has_errors = response.get('errors', False)

    print(f"\n{'='*70}")
    print(f"ElasticSearch Bulk Upload Response Analysis")
    print(f"{'='*70}\n")
    print(f"Total documents: {len(items)}")
    print(f"Has errors: {has_errors}\n")

    if not has_errors:
        print("✓ No errors found!")
        return

    # Collect all errors with details
    errors = []
    for idx, item in enumerate(items):
        if 'index' in item and 'error' in item['index']:
            error_info = item['index']['error']
            errors.append({
                'doc_number': idx + 1,
                'doc_id': item['index'].get('_id', 'N/A'),
                'error_type': error_info.get('type', 'unknown'),
                'error_reason': error_info.get('reason', 'No reason provided'),
                'caused_by': error_info.get('caused_by', {}),
                'full_error': error_info
            })

    print(f"Found {len(errors)} documents with errors:\n")
    print(f"{'-'*70}\n")

    # Group errors by type
    error_by_type = {}
    for err in errors:
        err_type = err['error_type']
        if err_type not in error_by_type:
            error_by_type[err_type] = []
        error_by_type[err_type].append(err)

    # Display grouped errors
    for err_type, err_list in error_by_type.items():
        print(f"\n{err_type} ({len(err_list)} occurrences):")
        print(f"{'-'*70}")

        for err in err_list:
            print(f"\nDocument #{err['doc_number']} (ID: {err['doc_id']})")
            print(f"  Reason: {err['error_reason']}")

            if err['caused_by']:
                print(f"  Caused by: {err['caused_by'].get('type', 'N/A')}")
                print(f"             {err['caused_by'].get('reason', 'N/A')}")

            # Show full error details for mapper_parsing_exception
            if err_type == 'mapper_parsing_exception':
                print(f"\n  Full error details:")
                print(f"  {json.dumps(err['full_error'], indent=4)}")

            print()

    print(f"\n{'='*70}")
    print(f"Summary: {len(errors)} errors across {len(error_by_type)} error types")
    print(f"{'='*70}\n")

if __name__ == '__main__':
    main()
