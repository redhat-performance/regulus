#!/usr/bin/env python3
"""
Parse ElasticSearch bulk upload response and show meaningful error information
"""
import sys
import json

def main():
    try:
        response = json.load(sys.stdin)
        items = response.get('items', [])
        has_errors = response.get('errors', False)

        print(f'✓ Uploaded: {len(items)} documents')

        if has_errors:
            # Count error types
            error_types = {}
            for item in items:
                if 'index' in item and 'error' in item['index']:
                    err_type = item['index']['error'].get('type', 'unknown')
                    error_types[err_type] = error_types.get(err_type, 0) + 1

            if error_types:
                error_summary = ', '.join([f'{k}({v})' for k, v in error_types.items()])
                print(f'  Warnings: {error_summary}')
        else:
            print('  No errors')
    except Exception as e:
        print(f'ERROR parsing ES response: {e}', file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
