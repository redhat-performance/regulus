#!/usr/bin/env python3
"""
Regulus batch analyzer with auto-discovery and flexible filtering.

WHY THIS EXISTS:
Unlike other Orion clients that use static YAML configs (see Orion/examples/),
Regulus has hundreds of dynamic test variations. This tool automates:
1. Query ES by batch_id to get relevant tests
2. Extract unique fingerprints dynamically (16-field test identification)
3. Generate temporary Orion configs automatically per fingerprint
4. Invoke Orion for each unique test type
5. Interpret results and produce aggregated report

Instead of maintaining hundreds of static configs, run ONE command.

BATCH CONCEPT:
All analysis operates on a batch (1+ documents). A batch is identified either by:
- Explicit BATCH_ID parameter, or
- Auto-discovery (finds latest batch by timestamp)

OPTIONAL FILTERING:
- MATCH: Select specific tests within batch (e.g., "threads=128")
- IGNORE: Exclude fields from fingerprint for grouping (e.g., "rcos" for cross-version analysis)

WORKFLOW:
1. Determine batch (specified or auto-discover latest)
2. Query ES for all documents in that batch
3. Apply MATCH filter to select specific tests
4. Extract fingerprints (using active fields: 16 fields - IGNORE fields)
5. Group documents by fingerprint
6. Generate Orion config for each unique fingerprint
7. Run Orion analyses and report results

Usage:
    # Analyze latest batch (auto-discover)
    ./analyze-batch.py

    # Analyze specific batch
    ./analyze-batch.py --batch-id "test-batch-2026-07-08"

    # Cross-version analysis (ignore rcos field from fingerprint)
    ./analyze-batch.py --batch-id "test-batch-2026-07-08" --ignore "rcos"

    # Filter to specific tests within batch
    ./analyze-batch.py --batch-id "test-batch-2026-07-08" --match "threads=128"

    # Combine MATCH and IGNORE
    ./analyze-batch.py --batch-id "test-batch-2026-07-08" --match "threads=128" --ignore "kernel rcos"
"""

import argparse
import json
import re
import sys
import os
import subprocess
import tempfile
from typing import List, Dict, Any, Tuple
from collections import defaultdict
import yaml

# Non-fingerprint fields — everything else in the ES mapping is a fingerprint field.
NON_FINGERPRINT_FIELDS = {
    '@timestamp',
    'mean', 'min', 'max', 'stddev', 'stddev_pct',
    'busy_cpu', 'samples_count', 'sample_count',
    'run_id', 'batch_id', 'iteration_id',
    'regulus_data', 'regulus_git_branch', 'execution_label',
    'mock_data',
}


class BatchAnalyzer:
    """Batch analyzer with auto-discovery and flexible filtering."""

    def __init__(self, es_server: str, es_index: str, batch_id: str = None,
                 match: Dict[str, str] = None, ignore: set = None,
                 lookback: str = "90d", debug: bool = False):
        self.es_server = es_server
        self.es_index = es_index
        self.batch_id = batch_id
        self.match = match or {}
        self.ignore = ignore or set()
        self.lookback = lookback
        self.debug = debug
        self.es_server_display = re.sub(r'https?://[^@]*@', lambda m: m.group(0).split('//')[0] + '//***:***@', es_server)
        self.script_dir = os.path.dirname(os.path.abspath(__file__))
        self.repo_root = os.path.dirname(self.script_dir)

        # Separate directories for generated files
        self.config_dir = os.path.join(self.repo_root, 'generated-configs')
        self.output_dir = os.path.join(self.repo_root, 'generated-orion')

        # Create directories if they don't exist
        os.makedirs(self.config_dir, exist_ok=True)
        os.makedirs(self.output_dir, exist_ok=True)

        # Discover fingerprint fields from ES mapping
        discovered = self._discover_fingerprint_fields()

        # Validate match fields
        invalid_match = set(self.match.keys()) - set(discovered)
        if invalid_match:
            print(f"⚠️  Warning: Invalid MATCH fields (will be ignored): {invalid_match}")
            for field in invalid_match:
                del self.match[field]

        # Validate ignore fields
        invalid_ignore = self.ignore - set(discovered)
        if invalid_ignore:
            print(f"⚠️  Warning: Invalid IGNORE fields: {invalid_ignore}")
            self.ignore -= invalid_ignore

        # Calculate active fingerprint fields (all fields minus ignored ones)
        self.fingerprint_fields = [
            f for f in discovered
            if f not in self.ignore
        ]

        # Ensure required fields are always included
        required = {'benchmark', 'unit'}
        missing_required = required - set(self.fingerprint_fields)
        if missing_required:
            print(f"❌ Error: Cannot ignore required fields: {missing_required}")
            sys.exit(1)

    def _discover_fingerprint_fields(self) -> List[str]:
        """Discover fingerprint fields from ES index mapping.

        Queries the mapping, subtracts NON_FINGERPRINT_FIELDS, returns sorted list.
        Hard fails if ES is unreachable — no fallback.
        """
        import requests

        url = f"{self.es_server}/{self.es_index}/_mapping"
        try:
            response = requests.get(url, timeout=30)
            response.raise_for_status()
        except Exception as e:
            print(f"❌ FATAL: Cannot retrieve ES mapping: {e}")
            sys.exit(1)

        mapping_data = response.json()
        first_index = list(mapping_data.keys())[0]
        properties = mapping_data[first_index].get('mappings', {}).get('properties', {})

        fields = sorted(f for f in properties if f not in NON_FINGERPRINT_FIELDS)

        if not fields:
            print(f"❌ FATAL: No fingerprint fields discovered from mapping")
            sys.exit(1)

        print(f"\n📋 Discovered {len(fields)} fingerprint fields from ES mapping")
        if self.debug:
            for f in fields:
                print(f"   - {f}")

        return fields

    def discover_latest_batch(self) -> str:
        """Auto-discover the latest batch_id from Elasticsearch."""
        print(f"\n🔍 Auto-discovering latest batch...")
        print(f"   Server: {self.es_server_display}")
        print(f"   Index: {self.es_index}")

        query = {
            "size": 0,
            "aggs": {
                "batches": {
                    "terms": {
                        "field": "batch_id.keyword",
                        "size": 1,
                        "order": {"latest_timestamp": "desc"}
                    },
                    "aggs": {
                        "latest_timestamp": {"max": {"field": "@timestamp"}}
                    }
                }
            }
        }

        import requests
        url = f"{self.es_server}/{self.es_index}/_search"

        try:
            response = requests.post(url, json=query, headers={'Content-Type': 'application/json'}, timeout=30)
            response.raise_for_status()
            result = response.json()

            buckets = result.get('aggregations', {}).get('batches', {}).get('buckets', [])
            if not buckets:
                print(f"   ✗ No batches found in {self.es_index}")
                sys.exit(1)

            latest_batch = buckets[0]['key']
            latest_ts = buckets[0]['latest_timestamp']['value']
            doc_count = buckets[0]['doc_count']

            print(f"   ✓ Found latest batch: {latest_batch}")
            print(f"   ✓ Timestamp: {latest_ts}")
            print(f"   ✓ Documents: {doc_count}")

            return latest_batch

        except requests.exceptions.RequestException as e:
            print(f"   ✗ Error querying ES: {e}")
            sys.exit(1)

    def query_tests(self) -> List[Dict[str, Any]]:
        """Query Elasticsearch for tests (batch-based or match-based)."""
        print(f"\n📥 Querying ES for matching tests")
        print(f"   Server: {self.es_server_display}")
        print(f"   Index: {self.es_index}")

        # Build query based on batch_id and/or match criteria
        must_clauses = []

        if self.batch_id:
            must_clauses.append({"term": {"batch_id.keyword": self.batch_id}})
            print(f"   Batch ID: {self.batch_id}")

        if self.match:
            for field, value in self.match.items():
                must_clauses.append({"match": {field: value}})
            print(f"   Match: {self.match}")

        if self.ignore:
            print(f"   Ignore: {self.ignore}")
            print(f"   Active fingerprint fields: {len(self.fingerprint_fields)}")

        query = {
            "query": {
                "bool": {
                    "must": must_clauses
                }
            } if must_clauses else {"match_all": {}},
            "size": 10000
        }

        import requests
        url = f"{self.es_server}/{self.es_index}/_search"

        try:
            response = requests.post(url, json=query, headers={'Content-Type': 'application/json'}, timeout=30)
            response.raise_for_status()
            result = response.json()

            hits = result.get('hits', {}).get('hits', [])
            documents = [hit['_source'] for hit in hits]

            print(f"   ✓ Found {len(documents)} matching documents")
            return documents

        except requests.exceptions.RequestException as e:
            print(f"   ✗ Error querying ES: {e}")
            sys.exit(1)

    def extract_fingerprint(self, doc: Dict[str, Any]) -> Tuple[str, Dict[str, Any]]:
        """Extract fingerprint from a document using active fingerprint fields.

        Returns:
            (fingerprint_hash, fingerprint_dict)
        """
        fingerprint = {}

        for field in self.fingerprint_fields:
            value = doc.get(field)
            if value is not None:
                # Convert to string for consistent hashing
                fingerprint[field] = str(value)
            else:
                # Missing field - use placeholder
                fingerprint[field] = "MISSING"

        # Create a hash for grouping
        fp_hash = "_".join([f"{k}={v}" for k, v in sorted(fingerprint.items())])

        return fp_hash, fingerprint

    def group_by_fingerprint(self, documents: List[Dict[str, Any]]) -> Dict[str, List[Dict[str, Any]]]:
        """Group documents by their fingerprint.

        Returns:
            {fingerprint_hash: [doc1, doc2, ...]}
        """
        print(f"\n🔍 Extracting fingerprints...")

        groups = defaultdict(list)

        for doc in documents:
            fp_hash, _ = self.extract_fingerprint(doc)
            groups[fp_hash].append(doc)

        print(f"   ✓ Discovered {len(groups)} unique fingerprint(s)")
        return groups

    def generate_orion_config(self, fingerprint: Dict[str, Any],
                             config_name: str) -> str:
        """Generate a temporary Orion YAML config for a fingerprint.

        Returns:
            Path to the generated config file
        """
        # Create temp config
        # NOTE: version_field allows cross-version comparison (ignores that field for filtering)
        # By NOT setting version_field, rcos will be used as a regular metadata filter
        config = {
            'tests': [{
                'name': config_name,
                'timestamp': '@timestamp',
                'uuid_field': 'iteration_id',
                # version_field NOT set - this makes rcos act as a regular filter field
                'metadata': {},
                'metrics': [
                    {
                        'name': 'throughput',
                        'metric_of_interest': 'mean',
                        'agg': {'agg_type': 'avg'},
                        'direction': 0,
                        'threshold': 5,
                        'labels': [f'[Batch: {self.batch_id}]']
                    },
                    {
                        'name': 'cpu_cost',
                        'metric_of_interest': 'busy_cpu',
                        'agg': {'agg_type': 'avg'},
                        'direction': 0,
                        'threshold': 10,
                        'labels': [f'[Batch: {self.batch_id}]']
                    }
                ]
            }]
        }

        # Add fingerprint fields to metadata (exclude MISSING values)
        for field, value in fingerprint.items():
            if value != "MISSING":
                # Convert numeric strings back to appropriate types
                if field in ['threads', 'wsize']:
                    try:
                        config['tests'][0]['metadata'][field] = int(value)
                    except ValueError:
                        config['tests'][0]['metadata'][field] = value
                else:
                    config['tests'][0]['metadata'][field] = value

        # Write to config directory (accessible to container via /orion mount)
        fd, config_path = tempfile.mkstemp(
            suffix='.yaml',
            prefix='orion-config-',
            dir=self.config_dir
        )
        with os.fdopen(fd, 'w') as f:
            yaml.dump(config, f, default_flow_style=False)

        if self.debug:
            print(f"\n   📄 Generated config: {config_path}")
            with open(config_path, 'r') as f:
                print(f"   {f.read()}")

        return config_path

    def _build_orion_cmd(self, config_path: str, fp_index: int):
        """Build Orion command for either pip-installed CLI or podman container."""
        output_filename = f'orion-output-fp{fp_index}.json'
        data_filename = f'data-fp{fp_index}.csv'

        import shutil
        if shutil.which('orion'):
            cmd = [
                'orion',
                '--es-server', self.es_server,
                '--config', config_path,
                '--hunter-analyze',
                '--benchmark-index', self.es_index,
                '--metadata-index', self.es_index,
                '--lookback', self.lookback,
                '--output-format', 'json',
                '--save-output-path', os.path.join(self.output_dir, output_filename),
                '--save-data-path', os.path.join(self.output_dir, data_filename)
            ]
        else:
            run_it_script = os.path.join(self.script_dir, 'run-it')
            container_config_path = config_path.replace(self.repo_root, '/orion')
            container_output_dir = self.output_dir.replace(self.repo_root, '/orion')
            cmd = [
                run_it_script,
                '--config', container_config_path,
                '--hunter-analyze',
                '--benchmark-index', self.es_index,
                '--metadata-index', self.es_index,
                '--lookback', self.lookback,
                '--output-format', 'json',
                '--save-output-path', f'{container_output_dir}/{output_filename}',
                '--save-data-path', f'{container_output_dir}/{data_filename}'
            ]
        return cmd, output_filename

    def run_orion_analysis(self, config_path: str, fingerprint_name: str, fp_index: int) -> Dict[str, Any]:
        """Run Orion Hunter analysis with the given config.

        Returns:
            Analysis results dict
        """
        print(f"\n   🏹 Running Orion for: {fingerprint_name}")

        cmd, output_filename = self._build_orion_cmd(config_path, fp_index)

        if self.debug:
            print(f"      Command: {' '.join(cmd)}")

        try:
            # Run Orion (Python 3.6 compatible)
            result = subprocess.run(
                cmd,
                cwd=self.repo_root,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                universal_newlines=True,
                timeout=300  # 5 minute timeout
            )

            if self.debug:
                print(f"      STDOUT: {result.stdout}")
                if result.stderr:
                    print(f"      STDERR: {result.stderr}")

            # Parse output
            # Check if output file exists in generated-orion directory
            # Orion may append _fingerprint-{N} to the filename when regressions are detected
            # NOTE: Orion returns non-zero exit code when regression is detected, so check file first
            output_file = os.path.join(self.output_dir, output_filename)

            # Try exact filename first, then look for Orion-appended variations
            if not os.path.exists(output_file):
                # Look for files with pattern: orion-output-fpN_fingerprint-*.json
                base_name = output_filename.replace('.json', '')
                for fname in os.listdir(self.output_dir):
                    if fname.startswith(base_name + '_fingerprint-') and fname.endswith('.json'):
                        output_file = os.path.join(self.output_dir, fname)
                        break

            if os.path.exists(output_file):
                # Output file exists, parse it regardless of return code
                with open(output_file, 'r') as f:
                    output_data = json.load(f)
                # Check which metrics have changepoints
                regressed_metrics = set()
                for doc in output_data:
                    if doc.get('is_changepoint', False):
                        for mkey, mval in doc.get('metrics', {}).items():
                            if mval.get('percentage_change', 0) != 0:
                                regressed_metrics.add(mkey)
                return {
                    'status': 'success',
                    'regression_detected': len(regressed_metrics) > 0,
                    'regressed_metrics': sorted(regressed_metrics),
                    'details': output_data,
                    'stdout': result.stdout
                }
            else:
                # No output file - this is an error
                return {
                    'status': 'error',
                    'error': result.stderr or f"Orion failed with return code {result.returncode}",
                    'stdout': result.stdout
                }

        except subprocess.TimeoutExpired:
            return {
                'status': 'error',
                'error': 'Orion analysis timed out (>5 minutes)'
            }
        except Exception as e:
            return {
                'status': 'error',
                'error': str(e)
            }

    def analyze(self) -> Dict[str, Any]:
        """Main analysis workflow with auto-discovery support."""
        print("=" * 80)
        print("🔬 Orion Regulus Batch Analyzer")
        print("=" * 80)

        # Auto-discover latest batch if not specified
        if not self.batch_id:
            self.batch_id = self.discover_latest_batch()

        print(f"Batch ID: {self.batch_id}")

        if self.match:
            print(f"Match criteria: {self.match}")
        if self.ignore:
            print(f"Ignored fields: {self.ignore}")
            print(f"Active fingerprint fields: {len(self.fingerprint_fields)}")

        print(f"Lookback: {self.lookback}")
        print("=" * 80)

        # Step 1: Query tests
        documents = self.query_tests()

        if not documents:
            print("\n⚠️  No documents found matching criteria!")
            return {'status': 'error', 'message': 'No matching documents'}

        # Step 2: Group by fingerprint
        fingerprint_groups = self.group_by_fingerprint(documents)

        # Step 3: Analyze each fingerprint
        print(f"\n🔬 Analyzing {len(fingerprint_groups)} fingerprint(s)...\n")

        results = []

        for idx, (fp_hash, docs) in enumerate(fingerprint_groups.items(), 1):
            # Extract fingerprint
            _, fingerprint = self.extract_fingerprint(docs[0])

            # Create full fingerprint display (all active fields)
            full_fp_parts = []
            for field in self.fingerprint_fields:
                if field in fingerprint and fingerprint[field] != "MISSING":
                    full_fp_parts.append(f"{field}={fingerprint[field]}")
            full_fp_name = ", ".join(full_fp_parts)

            print(f"─" * 80)
            print(f"Fingerprint #{idx}: {full_fp_name}")
            print(f"   Documents in batch: {len(docs)}")

            # Generate config
            config_path = self.generate_orion_config(
                fingerprint,
                f"fingerprint-{idx}"
            )

            # Run Orion
            analysis_result = self.run_orion_analysis(config_path, full_fp_name, idx)

            results.append({
                'fingerprint_name': full_fp_name,
                'fingerprint': fingerprint,
                'docs_in_batch': len(docs),
                'analysis': analysis_result
            })

            # Print result
            if analysis_result['status'] == 'success':
                if analysis_result['regression_detected']:
                    metrics = ', '.join(analysis_result.get('regressed_metrics', []))
                    print(f"   ⚠️  REGRESSION DETECTED ({metrics})")
                else:
                    print(f"   ✅ STABLE (no regression)")
            else:
                print(f"   ❌ ERROR: {analysis_result.get('error', 'Unknown error')}")

            # Note: Config files are kept in generated-configs/ for reference
            # Orion output files are kept in generated-orion/ for detailed analysis

        print("\n" + "=" * 80)
        print("📊 Analysis Summary")
        print("=" * 80)

        total = len(results)
        regressions = sum(1 for r in results if r['analysis'].get('regression_detected'))
        stable = sum(1 for r in results if r['analysis']['status'] == 'success' and not r['analysis'].get('regression_detected'))
        errors = sum(1 for r in results if r['analysis']['status'] == 'error')

        print(f"Total fingerprints analyzed: {total}")
        print(f"  ✅ Stable: {stable}")
        print(f"  ⚠️  Regressions: {regressions}")
        print(f"  ❌ Errors: {errors}")
        print("=" * 80)

        return {
            'status': 'success',
            'batch_id': self.batch_id,
            'total_fingerprints': total,
            'stable': stable,
            'regressions': regressions,
            'errors': errors,
            'results': results
        }


def parse_match_string(match_str: str) -> Dict[str, str]:
    """Parse 'key1=value1 key2=value2' into dict."""
    if not match_str:
        return {}

    match_dict = {}
    pairs = match_str.strip().split()
    for pair in pairs:
        if '=' not in pair:
            print(f"⚠️  Warning: Invalid MATCH format '{pair}' (expected key=value)")
            continue
        key, value = pair.split('=', 1)
        match_dict[key] = value

    return match_dict


def parse_ignore_string(ignore_str: str) -> set:
    """Parse 'field1 field2 field3' into set."""
    if not ignore_str:
        return set()
    return set(ignore_str.strip().split())


def main():
    parser = argparse.ArgumentParser(
        description='Regulus test analyzer with batch discovery and fingerprint filtering',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Auto-discover and analyze latest batch
  ./analyze-batch.py

  # Analyze specific batch
  ./analyze-batch.py --batch-id "test-batch-2026-07-06"

  # Analyze latest batch, ignore rcos for cross-version comparison
  ./analyze-batch.py --ignore "rcos"

  # Analyze specific batch with MATCH filter
  ./analyze-batch.py --batch-id "test-001" --match "threads=128"

  # Analyze with both MATCH and IGNORE
  ./analyze-batch.py --batch-id "test-001" --match "threads=128" --ignore "kernel rcos"
"""
    )

    parser.add_argument('--batch-id',
                        help='Batch ID to analyze (default: auto-discover latest)')
    parser.add_argument('--match',
                        help='Match specific fields (format: "field1=value1 field2=value2")')
    parser.add_argument('--ignore',
                        help='Ignore specific fields from fingerprint (format: "field1 field2 field3")')
    parser.add_argument('--es-server',
                        default=os.environ.get('ES_SERVER', 'http://localhost:9200'),
                        help='Elasticsearch server URL (default: $ES_SERVER or http://localhost:9200)')
    parser.add_argument('--es-index',
                        default='regulus-results-*',
                        help='Elasticsearch index pattern (default: regulus-results-*)')
    parser.add_argument('--lookback',
                        default='90d',
                        help='How far back to look for historical data (default: 90d)')
    parser.add_argument('--debug',
                        action='store_true',
                        help='Enable debug output')
    parser.add_argument('--output',
                        help='Save results to JSON file')

    args = parser.parse_args()

    # Check for required dependencies
    try:
        import requests
        import yaml
    except ImportError as e:
        print(f"❌ Missing required Python module: {e}")
        print("   Install with: pip3 install requests pyyaml")
        sys.exit(1)

    # Parse match and ignore strings
    match_dict = parse_match_string(args.match)
    ignore_set = parse_ignore_string(args.ignore)

    # Run analysis
    analyzer = BatchAnalyzer(
        es_server=args.es_server,
        es_index=args.es_index,
        batch_id=args.batch_id,
        match=match_dict,
        ignore=ignore_set,
        lookback=args.lookback,
        debug=args.debug
    )

    results = analyzer.analyze()

    # Save results if requested
    if args.output:
        with open(args.output, 'w') as f:
            json.dump(results, f, indent=2)
        print(f"\n💾 Results saved to: {args.output}")

    # Exit code based on results
    if results.get('regressions', 0) > 0:
        sys.exit(1)  # Regressions found
    elif results.get('errors', 0) > 0:
        sys.exit(2)  # Errors occurred
    else:
        sys.exit(0)  # All good


if __name__ == '__main__':
    main()
