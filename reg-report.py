#!/usr/bin/env python3
import argparse
from build_report.factories import create_multi_format_orchestrator
import sys

# CLI parser for wrapper
parser = argparse.ArgumentParser(description="Wrapper for main.py to support multiple output formats")
parser.add_argument('--root', type=str, default='.', help='Root directory to scan for result-summary.txt')
parser.add_argument('--output', type=str, default='report', help='Base name for output files')
parser.add_argument('--formats', nargs='+', default=['json', 'html', 'csv'], help='Output formats')
args = parser.parse_args()

# Create orchestrator with requested formats
orchestrator = create_multi_format_orchestrator(args.formats)

# Call generate_report with the root path and output path
orchestrator.generate_report(
    root_path=args.root,
    output_path=args.output
)

print(f"Generated report in formats: {', '.join(args.formats)}")

