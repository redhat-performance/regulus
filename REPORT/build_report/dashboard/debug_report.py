#!/usr/bin/env python3
"""
Debug script to inspect JSON report structure.

Helps identify issues in report files that fail to load.
"""

import json
import sys
from pathlib import Path


def debug_report(report_path):
    """Analyze a JSON report and show its structure."""

    print(f"Analyzing: {report_path}")
    print("=" * 70)

    try:
        with open(report_path, 'r') as f:
            data = json.load(f)

        print(f"✓ JSON is valid")
        print(f"✓ Top-level type: {type(data).__name__}")
        print()

        if isinstance(data, dict):
            print("Top-level keys:")
            for key in data.keys():
                value = data[key]
                print(f"  - {key}: {type(value).__name__}", end="")
                if isinstance(value, (list, dict)):
                    print(f" (length: {len(value)})")
                else:
                    print()
            print()

            # Check generation_info
            if 'generation_info' in data:
                gen_info = data['generation_info']
                print(f"generation_info type: {type(gen_info).__name__}")
                if isinstance(gen_info, dict):
                    print(f"  Keys: {list(gen_info.keys())}")
                elif isinstance(gen_info, str):
                    print(f"  ⚠️  WARNING: generation_info is a string: {gen_info[:100]}")
                print()

            # Check results
            if 'results' in data:
                results = data['results']
                print(f"results type: {type(results).__name__}")
                if isinstance(results, list):
                    print(f"  Total results: {len(results)}")

                    # Check first result
                    if len(results) > 0:
                        first_result = results[0]
                        print(f"  First result type: {type(first_result).__name__}")

                        if isinstance(first_result, dict):
                            print(f"  First result keys: {list(first_result.keys())}")

                            # Check nested structures
                            for key in ['common_params', 'key_tags', 'iterations']:
                                if key in first_result:
                                    value = first_result[key]
                                    print(f"    - {key}: {type(value).__name__}", end="")
                                    if isinstance(value, (list, dict)):
                                        print(f" (length: {len(value)})")
                                    elif isinstance(value, str):
                                        print(f" = '{value[:50]}...'")
                                    else:
                                        print()

                            # Check iterations structure
                            if 'iterations' in first_result:
                                iterations = first_result['iterations']
                                if isinstance(iterations, list) and len(iterations) > 0:
                                    first_iter = iterations[0]
                                    print(f"    First iteration type: {type(first_iter).__name__}")
                                    if isinstance(first_iter, dict):
                                        print(f"    First iteration keys: {list(first_iter.keys())}")

                                        for key in ['unique_params', 'results']:
                                            if key in first_iter:
                                                value = first_iter[key]
                                                print(f"      - {key}: {type(value).__name__}", end="")
                                                if isinstance(value, (list, dict)):
                                                    print(f" (length: {len(value)})")
                                                elif isinstance(value, str):
                                                    print(f" = '{value[:50]}...'")
                                                else:
                                                    print()

                        elif isinstance(first_result, str):
                            print(f"  ⚠️  WARNING: First result is a string: {first_result[:100]}")

                elif isinstance(results, str):
                    print(f"  ⚠️  WARNING: results is a string: {results[:100]}")
                print()

            # Check for inventory section (if it exists)
            if 'inventory' in data:
                inventory = data['inventory']
                print(f"inventory type: {type(inventory).__name__}")
                if isinstance(inventory, dict):
                    print(f"  Keys: {list(inventory.keys())}")
                elif isinstance(inventory, list):
                    print(f"  Length: {len(inventory)}")
                print()

        else:
            print(f"⚠️  ERROR: Expected dictionary at top level, got {type(data).__name__}")

        print("=" * 70)
        print("Analysis complete!")

    except json.JSONDecodeError as e:
        print(f"✗ JSON parse error: {e}")
    except Exception as e:
        import traceback
        print(f"✗ Error: {e}")
        print(traceback.format_exc())


if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: python3 debug_report.py <path-to-json-report>")
        print()
        print("Example:")
        print("  python3 debug_report.py /tmp/reports/report-all-output.json")
        sys.exit(1)

    report_path = sys.argv[1]
    if not Path(report_path).exists():
        print(f"Error: File not found: {report_path}")
        sys.exit(1)

    debug_report(report_path)
