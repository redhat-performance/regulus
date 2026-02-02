#!/usr/bin/env python3
"""
ElasticSearch Report Flattener

Converts nested report.json files into flat NDJSON format for ElasticSearch ingestion.
Reuses the dashboard/data_loader.py for consistent data parsing.

Usage:
    # Convert report.json to NDJSON
    python3 flatten_to_es.py report.json -o report.ndjson

    # Process all reports in a directory
    python3 flatten_to_es.py dashboard/test_data/ -o output.ndjson

    # Upload directly to ElasticSearch
    python3 flatten_to_es.py report.json --es-host localhost:9200 --es-index benchmark-results
"""

import sys
import json
import argparse
import uuid
from pathlib import Path
from typing import List, Dict, Any, Optional
from datetime import datetime

# Import from dashboard data_loader
sys.path.insert(0, str(Path(__file__).parent.parent))
try:
    from dashboard.data_loader import ReportLoader, BenchmarkResult
except ImportError:
    print("Error: Could not import dashboard.data_loader", file=sys.stderr)
    print("Make sure you're running from the build_report directory", file=sys.stderr)
    sys.exit(1)


class ESDocumentFlattener:
    """Convert BenchmarkResult objects to flat ElasticSearch documents."""

    def __init__(self, index_name: str = "regulus-results"):
        self.index_name = index_name
        self.regulus_git_branch = None
        self.execution_label = None
        self.batch_id = str(uuid.uuid4())  # UUID to group documents from the same upload batch

    def flatten_result(self, result: BenchmarkResult) -> Dict[str, Any]:
        """
        Convert a BenchmarkResult to a flat ElasticSearch document.

        All nested structures are flattened into a single-level dictionary.
        Field names use ElasticSearch conventions (lowercase, underscores).
        """
        doc = {
            # Document metadata
            "@timestamp": result.timestamp or datetime.utcnow().isoformat(),

            # Upload batch tracking
            "batch_id": self.batch_id,

            # Execution context metadata
            "regulus_git_branch": self.regulus_git_branch,
            "execution_label": self.execution_label,

            "regulus_data": result.regulus_data,
            "run_id": result.run_id,
            "iteration_id": result.iteration_id,

            # Test identification
            "benchmark": result.benchmark,
            "test_type": result.test_type,
            "protocol": result.protocol,

            # Infrastructure tags
            "model": result.model,          # Datapath model (OVNK, DPU, SRIOV, etc.)
            "nic": result.nic,              # NIC vendor (e810, cx7, etc.)
            "arch": result.arch,            # CPU architecture
            "cpu": result.cpu,              # CPU model
            "kernel": result.kernel,        # Kernel version
            "rcos": result.rcos,            # RCOS version

            # Configuration
            "topology": result.topo,
            "performance_profile": result.perf,
            "offload": result.offload,
            "threads": result.threads,
            "wsize": result.wsize,
            "rsize": result.rsize,

            # Scale parameters
            "pods_per_worker": result.pods_per_worker,
            "scale_out_factor": result.scale_out_factor,

            # Performance metrics
            "mean": result.mean,
            "min": result.min,
            "max": result.max,
            "stddev": result.stddev,
            "stddev_pct": result.stddevpct,
            "unit": result.unit,
            "busy_cpu": result.busy_cpu,
            "samples_count": result.samples_count
        }

        # Remove null values and convert string "None" to null for numeric fields only
        # This handles cases where upstream data has "None" as a string instead of null
        # Define fields that should be numeric (ES expects integers/floats for these)
        numeric_fields = {
            'threads', 'wsize', 'rsize', 'cpu',
            'pods_per_worker', 'scale_out_factor',
            'mean', 'min', 'max', 'stddev', 'stddev_pct', 'busy_cpu', 'samples_count'
        }

        def sanitize_value(key, value):
            """Convert string 'None' to None for numeric fields only"""
            if key in numeric_fields and (value == "None" or value == ""):
                return None
            return value

        sanitized_doc = {k: sanitize_value(k, v) for k, v in doc.items()}

        # Remove null values to save space
        return {k: v for k, v in sanitized_doc.items() if v is not None}

    def create_bulk_action(self, doc: Dict[str, Any], doc_id: Optional[str] = None) -> Dict[str, Any]:
        """
        Create ElasticSearch bulk API action metadata.

        Returns the "index" action with optional document ID.
        """
        action = {
            "index": {
                "_index": self.index_name
            }
        }

        if doc_id:
            action["index"]["_id"] = doc_id

        return action

    def to_ndjson_line(self, result: BenchmarkResult, include_action: bool = True) -> str:
        """
        Convert a BenchmarkResult to NDJSON format line(s).

        If include_action is True, returns bulk API format (2 lines):
        - Line 1: {"index": {...}}
        - Line 2: {document}

        Otherwise returns single line with just the document.
        """
        doc = self.flatten_result(result)

        if include_action:
            # Generate document ID from run_id, iteration_id, and unit (to handle multiple metrics per iteration)
            if result.run_id and result.iteration_id and result.unit:
                # Sanitize unit for use in ID (replace special chars with underscore)
                safe_unit = result.unit.replace('/', '-').replace(' ', '_')
                doc_id = f"{result.run_id}_{result.iteration_id}_{safe_unit}"
            else:
                doc_id = None
            action = self.create_bulk_action(doc, doc_id)
            return json.dumps(action) + '\n' + json.dumps(doc) + '\n'
        else:
            return json.dumps(doc) + '\n'


def process_report(report_path: str, flattener: ESDocumentFlattener, loader: ReportLoader) -> List[str]:
    """
    Process a single report file and return NDJSON lines.
    """
    print(f"Processing: {report_path}")

    # Load the JSON file to extract generation_info metadata
    try:
        with open(report_path, 'r') as f:
            report_data = json.load(f)

        # Extract metadata from generation_info
        generation_info = report_data.get('generation_info', {})
        flattener.regulus_git_branch = generation_info.get('regulus_git_branch')
        flattener.execution_label = generation_info.get('execution_label')
    except Exception as e:
        print(f"  Warning: Could not extract metadata from {report_path}: {e}")

    # Load and extract results
    loader.load_report(report_path)
    results = loader.extract_all_results()

    if not results:
        print(f"  Warning: No results found in {report_path}")
        return []

    print(f"  Found {len(results)} benchmark results")

    # Convert to NDJSON
    ndjson_lines = []
    for result in results:
        ndjson_lines.append(flattener.to_ndjson_line(result, include_action=True))

    return ndjson_lines


def process_directory(directory: str, flattener: ESDocumentFlattener, loader: ReportLoader) -> List[str]:
    """
    Process all JSON report files in a directory.
    """
    dir_path = Path(directory)
    if not dir_path.is_dir():
        print(f"Error: {directory} is not a directory", file=sys.stderr)
        return []

    # Find all JSON files
    json_files = list(dir_path.glob("*.json"))
    if not json_files:
        print(f"Warning: No JSON files found in {directory}")
        return []

    print(f"Found {len(json_files)} JSON files in {directory}")

    all_lines = []
    for json_file in sorted(json_files):
        lines = process_report(str(json_file), flattener, loader)
        all_lines.extend(lines)

    return all_lines


def write_ndjson(lines: List[str], output_path: str):
    """
    Write NDJSON lines to output file.
    """
    with open(output_path, 'w') as f:
        for line in lines:
            f.write(line)

    # Count documents (each bulk action is 2 lines)
    doc_count = sum(1 for line in lines if line.strip() and not line.strip().startswith('{"index"'))
    print(f"\nWrote {doc_count} documents to {output_path}")


def upload_to_elasticsearch(lines: List[str], es_host: str, index_name: str, es_user: Optional[str] = None, es_password: Optional[str] = None):
    """
    Upload NDJSON data directly to ElasticSearch using bulk API.

    Requires: pip install elasticsearch
    """
    try:
        from elasticsearch import Elasticsearch
    except ImportError:
        print("Error: elasticsearch package not installed", file=sys.stderr)
        print("Install with: pip install elasticsearch", file=sys.stderr)
        sys.exit(1)

    # Create ES client
    auth = (es_user, es_password) if es_user and es_password else None
    es = Elasticsearch([es_host], basic_auth=auth)

    # Check connection
    if not es.ping():
        print(f"Error: Could not connect to ElasticSearch at {es_host}", file=sys.stderr)
        sys.exit(1)

    print(f"Connected to ElasticSearch at {es_host}")

    # Prepare bulk data
    bulk_data = ''.join(lines)

    # Upload
    print(f"Uploading to index '{index_name}'...")
    response = es.bulk(body=bulk_data, index=index_name)

    if response.get('errors'):
        print("Warning: Some documents failed to index")
        for item in response['items']:
            if 'error' in item.get('index', {}):
                print(f"  Error: {item['index']['error']}")
    else:
        doc_count = len(response['items'])
        print(f"Successfully indexed {doc_count} documents")


def main():
    parser = argparse.ArgumentParser(
        description="Flatten report.json files for ElasticSearch ingestion",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Convert single report to NDJSON
  python3 flatten_to_es.py report.json -o report.ndjson

  # Process all reports in directory
  python3 flatten_to_es.py dashboard/test_data/ -o all_reports.ndjson

  # Upload directly to ElasticSearch
  python3 flatten_to_es.py report.json --es-host localhost:9200 --es-index benchmark-results

  # Upload with authentication
  python3 flatten_to_es.py report.json --es-host localhost:9200 --es-user elastic --es-password changeme
        """
    )

    parser.add_argument('input', help='Input report.json file or directory')
    parser.add_argument('-o', '--output', help='Output NDJSON file')
    parser.add_argument('--es-host', help='ElasticSearch host (e.g., localhost:9200)')
    parser.add_argument('--es-index', default='regulus-results', help='ElasticSearch index name (default: regulus-results)')
    parser.add_argument('--es-user', help='ElasticSearch username')
    parser.add_argument('--es-password', help='ElasticSearch password')

    args = parser.parse_args()

    # Validate arguments
    if not args.output and not args.es_host:
        parser.error("Must specify either --output or --es-host")

    # Initialize
    flattener = ESDocumentFlattener(index_name=args.es_index)
    loader = ReportLoader()

    # Process input
    input_path = Path(args.input)
    if input_path.is_file():
        ndjson_lines = process_report(args.input, flattener, loader)
    elif input_path.is_dir():
        ndjson_lines = process_directory(args.input, flattener, loader)
    else:
        print(f"Error: {args.input} does not exist", file=sys.stderr)
        sys.exit(1)

    if not ndjson_lines:
        print("No data to process")
        sys.exit(1)

    # Output
    if args.output:
        write_ndjson(ndjson_lines, args.output)

    if args.es_host:
        upload_to_elasticsearch(
            ndjson_lines,
            args.es_host,
            args.es_index,
            args.es_user,
            args.es_password
        )


if __name__ == '__main__':
    main()
