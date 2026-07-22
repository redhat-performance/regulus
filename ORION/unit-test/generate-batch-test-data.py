#!/usr/bin/env python3
"""
Generate test data for batch analyzer validation.

Creates a single batch with multiple unique fingerprints plus historical data
for each fingerprint to test the analyze-batch.py tool.

Usage:
    ./generate-batch-test-data.py --batch-id "test-batch-001"
    ./generate-batch-test-data.py --batch-id "test-batch-001" --index-to-es
"""

import argparse
import json
import sys
import uuid
from datetime import datetime, timedelta
from typing import List, Dict, Any
import random

# Reuse the mock data generator
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Import using importlib since filename has hyphens
import importlib.util
spec = importlib.util.spec_from_file_location(
    "generate_mock_data",
    os.path.join(os.path.dirname(__file__), "generate-mock-data.py")
)
generate_mock_data = importlib.util.module_from_spec(spec)
spec.loader.exec_module(generate_mock_data)
RegulusMockDataGenerator = generate_mock_data.RegulusMockDataGenerator


def generate_batch_with_multiple_fingerprints(
    batch_id: str,
    base_timestamp: datetime,
    num_historical_per_fingerprint: int = 20
) -> List[Dict[str, Any]]:
    """
    Generate test data with:
    - Historical data for 3 different fingerprints (20 samples each, spanning 30 days ago to 1 day ago)
    - New batch with 1 test per fingerprint (today)

    Fingerprints differ by threads parameter:
    - Fingerprint A: threads=16 (stable performance)
    - Fingerprint B: threads=32 (regressed in new batch)
    - Fingerprint C: threads=64 (improved in new batch)
    """

    all_documents = []

    # Common fingerprint fields (ALL fingerprints share these exact values)
    common_config = {
        'topology': 'internode',
        'protocol': 'tcp',
        'nic': 'mlx5_0',
        'ipv': '4',
        'model': 'OVNK',
        'test_type': 'stream',
        'performance_profile': 'None',
        'kernel': '5.14.0-503.11.1.el9_5.x86_64',  # FIXED
        'rcos': '9.6.20260615-0',  # FIXED
        'arch': 'Intel(R)_Xeon(R)_Gold_6130_CPU_@_2.10GHz',  # FIXED
        'cpu': '4',  # FIXED
        'pods_per_worker': '1',  # FIXED
        'scale_out_factor': '1',  # FIXED
        'wsize': 32768,  # FIXED
    }

    print("=" * 80)
    print(f"Generating Batch Analyzer Test Data")
    print(f"Batch ID: {batch_id}")
    print("=" * 80)

    # =========================================================================
    # Fingerprint A: threads=16, stable performance
    # =========================================================================
    print("\n📊 Fingerprint A (threads=16) - Stable Performance")
    print(f"  Historical: {num_historical_per_fingerprint} samples (30 days ago to 1 day ago)")
    print(f"  New batch: 1 sample (today)")

    # Historical data for Fingerprint A (stable, 30-1 days ago)
    gen_a_historical = RegulusMockDataGenerator(
        base_timestamp=base_timestamp - timedelta(days=30),
        batch_id=f"historical-a-{uuid.uuid4()}"  # Different batch_id for historical
    )

    config_a = {**common_config, 'threads': 16}
    docs_a_hist = gen_a_historical.generate_stable_baseline(
        metric_type='throughput',
        num_samples=num_historical_per_fingerprint,
        test_config=config_a
    )
    all_documents.extend(docs_a_hist)
    print(f"  ✓ Generated {len(docs_a_hist)} historical documents")

    # New batch data for Fingerprint A (stable performance continues)
    gen_a_new = RegulusMockDataGenerator(
        base_timestamp=datetime.utcnow(),
        batch_id=batch_id  # Same batch_id for new tests
    )
    docs_a_new = gen_a_new.generate_stable_baseline(
        metric_type='throughput',
        num_samples=1,
        test_config=config_a
    )
    all_documents.extend(docs_a_new)
    print(f"  ✓ Generated {len(docs_a_new)} NEW batch documents (stable)")
    print(f"     Mean: {docs_a_new[0]['mean']:.2f} Gbps")

    # =========================================================================
    # Fingerprint B: threads=32, REGRESSION in new batch
    # =========================================================================
    print("\n📊 Fingerprint B (threads=32) - REGRESSION Detected")
    print(f"  Historical: {num_historical_per_fingerprint} samples (stable)")
    print(f"  New batch: 1 sample (25% drop!)")

    # Historical data for Fingerprint B (stable baseline)
    gen_b_historical = RegulusMockDataGenerator(
        base_timestamp=base_timestamp - timedelta(days=30),
        batch_id=f"historical-b-{uuid.uuid4()}"
    )

    config_b = {**common_config, 'threads': 32}
    docs_b_hist = gen_b_historical.generate_stable_baseline(
        metric_type='throughput',
        num_samples=num_historical_per_fingerprint,
        test_config=config_b
    )
    all_documents.extend(docs_b_hist)
    print(f"  ✓ Generated {len(docs_b_hist)} historical documents")

    # New batch data for Fingerprint B (REGRESSION - 25% drop)
    gen_b_new = RegulusMockDataGenerator(
        base_timestamp=datetime.utcnow(),
        batch_id=batch_id
    )

    # Generate one regressed sample
    baseline_b = gen_b_new.baselines['throughput']
    regressed_value = baseline_b['mean'] * 0.75  # 25% drop

    doc_b_new = gen_b_new._generate_base_document(
        metric_type='throughput',
        timestamp=datetime.utcnow(),
        test_config=config_b
    )
    doc_b_new['mean'] = regressed_value
    doc_b_new['min'] = regressed_value * 0.95
    doc_b_new['max'] = regressed_value * 1.05
    doc_b_new['stddev'] = baseline_b['stddev']
    doc_b_new['sample_count'] = 150

    all_documents.append(doc_b_new)
    print(f"  ✓ Generated 1 NEW batch document (REGRESSED)")
    print(f"     Mean: {doc_b_new['mean']:.2f} Gbps (25% drop from ~{baseline_b['mean']:.2f})")

    # =========================================================================
    # Fingerprint C: threads=64, IMPROVEMENT in new batch
    # =========================================================================
    print("\n📊 Fingerprint C (threads=64) - Performance IMPROVEMENT")
    print(f"  Historical: {num_historical_per_fingerprint} samples (stable)")
    print(f"  New batch: 1 sample (20% improvement!)")

    # Historical data for Fingerprint C (stable baseline)
    gen_c_historical = RegulusMockDataGenerator(
        base_timestamp=base_timestamp - timedelta(days=30),
        batch_id=f"historical-c-{uuid.uuid4()}"
    )

    config_c = {**common_config, 'threads': 64}
    docs_c_hist = gen_c_historical.generate_stable_baseline(
        metric_type='throughput',
        num_samples=num_historical_per_fingerprint,
        test_config=config_c
    )
    all_documents.extend(docs_c_hist)
    print(f"  ✓ Generated {len(docs_c_hist)} historical documents")

    # New batch data for Fingerprint C (IMPROVEMENT - 20% increase)
    gen_c_new = RegulusMockDataGenerator(
        base_timestamp=datetime.utcnow(),
        batch_id=batch_id
    )

    baseline_c = gen_c_new.baselines['throughput']
    improved_value = baseline_c['mean'] * 1.20  # 20% improvement

    doc_c_new = gen_c_new._generate_base_document(
        metric_type='throughput',
        timestamp=datetime.utcnow(),
        test_config=config_c
    )
    doc_c_new['mean'] = improved_value
    doc_c_new['min'] = improved_value * 0.95
    doc_c_new['max'] = improved_value * 1.05
    doc_c_new['stddev'] = baseline_c['stddev']
    doc_c_new['sample_count'] = 150

    all_documents.append(doc_c_new)
    print(f"  ✓ Generated 1 NEW batch document (IMPROVED)")
    print(f"     Mean: {doc_c_new['mean']:.2f} Gbps (20% improvement from ~{baseline_c['mean']:.2f})")

    # =========================================================================
    # Fingerprint D: threads=128, demonstrates rcos field importance
    # =========================================================================
    print("\n📊 Fingerprint D (threads=128) - RCOS Change Demonstrates Field Importance")
    print(f"  Historical: {num_historical_per_fingerprint} samples with rcos=9.5.20260515-0")
    print(f"  New batch: 1 sample with rcos=9.6.20260615-0 (DIFFERENT RCOS!)")
    print(f"  Performance: 30% REGRESSION in new batch")
    print(f"  Expected behavior:")
    print(f"    - WITH rcos in fingerprint: No changepoint (different fingerprints)")
    print(f"    - WITHOUT rcos: Changepoint detected (30% regression)")

    # Historical data for Fingerprint D (old rcos, good performance)
    gen_d_historical = RegulusMockDataGenerator(
        base_timestamp=base_timestamp - timedelta(days=30),
        batch_id=f"historical-d-{uuid.uuid4()}"
    )

    # Override rcos for historical data
    config_d_hist = {**common_config, 'threads': 128}
    docs_d_hist = gen_d_historical.generate_stable_baseline(
        metric_type='throughput',
        num_samples=num_historical_per_fingerprint,
        test_config=config_d_hist
    )

    # Change rcos in historical data to OLD version
    old_rcos = '9.5.20260515-0'
    for doc in docs_d_hist:
        doc['rcos'] = old_rcos

    all_documents.extend(docs_d_hist)
    print(f"  ✓ Generated {len(docs_d_hist)} historical documents (rcos={old_rcos})")

    # New batch data for Fingerprint D (NEW rcos, REGRESSION - 30% drop)
    gen_d_new = RegulusMockDataGenerator(
        base_timestamp=datetime.utcnow(),
        batch_id=batch_id
    )

    baseline_d = gen_d_new.baselines['throughput']
    regressed_value_d = baseline_d['mean'] * 0.70  # 30% regression

    # Use NEW rcos for new batch (different from historical)
    config_d_new = {**common_config, 'threads': 128, 'rcos': '9.6.20260615-0'}

    doc_d_new = gen_d_new._generate_base_document(
        metric_type='throughput',
        timestamp=datetime.utcnow(),
        test_config=config_d_new
    )
    doc_d_new['mean'] = regressed_value_d
    doc_d_new['min'] = regressed_value_d * 0.95
    doc_d_new['max'] = regressed_value_d * 1.05
    doc_d_new['stddev'] = baseline_d['stddev']
    doc_d_new['sample_count'] = 150

    all_documents.append(doc_d_new)
    print(f"  ✓ Generated 1 NEW batch document (REGRESSED, rcos={config_d_new['rcos']})")
    print(f"     Mean: {doc_d_new['mean']:.2f} Gbps (30% drop from ~{baseline_d['mean']:.2f})")
    print(f"  ⚠️  IMPORTANT: Historical has rcos={old_rcos}, new batch has rcos={config_d_new['rcos']}")
    print(f"     This creates DIFFERENT fingerprints if rcos is included!")

    # =========================================================================
    # Fingerprint E: threads=256, stable throughput but CPU REGRESSION
    # =========================================================================
    print("\n📊 Fingerprint E (threads=256) - CPU Regression (throughput stable)")
    print(f"  Historical: {num_historical_per_fingerprint} samples (busy_cpu ~25%)")
    print(f"  New batch: 1 sample (busy_cpu ~50%, throughput unchanged)")

    # Historical data for Fingerprint E (stable throughput and CPU)
    gen_e_historical = RegulusMockDataGenerator(
        base_timestamp=base_timestamp - timedelta(days=30),
        batch_id=f"historical-e-{uuid.uuid4()}"
    )

    config_e = {**common_config, 'threads': 256}
    docs_e_hist = gen_e_historical.generate_stable_baseline(
        metric_type='throughput',
        num_samples=num_historical_per_fingerprint,
        test_config=config_e
    )
    # Ensure historical busy_cpu is stable around 25%
    for doc in docs_e_hist:
        doc['busy_cpu'] = round(random.gauss(25.0, 2.0), 2)
    all_documents.extend(docs_e_hist)
    print(f"  ✓ Generated {len(docs_e_hist)} historical documents")

    # New batch data for Fingerprint E (CPU REGRESSION - busy_cpu doubles)
    gen_e_new = RegulusMockDataGenerator(
        base_timestamp=datetime.utcnow(),
        batch_id=batch_id
    )

    baseline_e = gen_e_new.baselines['throughput']
    doc_e_new = gen_e_new._generate_base_document(
        metric_type='throughput',
        timestamp=datetime.utcnow(),
        test_config=config_e
    )
    # Throughput stays normal
    doc_e_new['mean'] = baseline_e['mean']
    doc_e_new['min'] = baseline_e['mean'] * 0.95
    doc_e_new['max'] = baseline_e['mean'] * 1.05
    doc_e_new['stddev'] = baseline_e['stddev']
    doc_e_new['sample_count'] = 150
    # CPU doubles (regression)
    doc_e_new['busy_cpu'] = 50.0

    all_documents.append(doc_e_new)
    print(f"  ✓ Generated 1 NEW batch document (CPU REGRESSED)")
    print(f"     Mean: {doc_e_new['mean']:.2f} Gbps (stable)")
    print(f"     busy_cpu: {doc_e_new['busy_cpu']}% (doubled from ~25%)")

    # Summary
    print("\n" + "=" * 80)
    print(f"Total documents generated: {len(all_documents)}")
    print(f"  - Historical data: {num_historical_per_fingerprint * 5} documents (5 fingerprints × {num_historical_per_fingerprint})")
    print(f"  - New batch '{batch_id}': 5 documents")
    print(f"\nExpected analyze-batch.py results:")
    print(f"  ✓ Fingerprint A (threads=16): STABLE")
    print(f"  ⚠️  Fingerprint B (threads=32): REGRESSION (throughput -25%)")
    print(f"  ⚠️  Fingerprint C (threads=64): CHANGEPOINT (throughput +20%)")
    print(f"  🔍 Fingerprint D (threads=128): Depends on rcos handling")
    print(f"     - WITH rcos field: STABLE (no historical match, treated as new)")
    print(f"     - WITHOUT rcos field: REGRESSION (30% drop detected)")
    print(f"  ⚠️  Fingerprint E (threads=256): REGRESSION (busy_cpu doubled)")
    print("=" * 80)

    return all_documents


def main():
    parser = argparse.ArgumentParser(
        description='Generate batch analyzer test data with multiple fingerprints'
    )
    parser.add_argument('--batch-id', required=True,
                        help='Batch ID for the new test batch')
    parser.add_argument('--output', default='generated/batch-test-data.json',
                        help='Output JSON file (default: generated/batch-test-data.json)')
    parser.add_argument('--historical-samples', type=int, default=20,
                        help='Number of historical samples per fingerprint (default: 20)')
    parser.add_argument('--index-to-es', action='store_true',
                        help='Index data to Elasticsearch after generation')
    parser.add_argument('--es-server', default='http://localhost:9200',
                        help='Elasticsearch server URL')
    parser.add_argument('--es-index', default='regulus-results-mock',
                        help='Elasticsearch index name')

    args = parser.parse_args()

    # Generate data
    base_timestamp = datetime.utcnow()
    documents = generate_batch_with_multiple_fingerprints(
        batch_id=args.batch_id,
        base_timestamp=base_timestamp,
        num_historical_per_fingerprint=args.historical_samples
    )

    # Write to JSON file
    import os
    os.makedirs(os.path.dirname(args.output), exist_ok=True)

    print(f"\n💾 Writing {len(documents)} documents to {args.output}...")
    with open(args.output, 'w') as f:
        json.dump(documents, f, indent=2)
    print(f"  ✓ Wrote {args.output}")

    # Optionally index to ES
    if args.index_to_es:
        try:
            import requests
        except ImportError:
            print("\n⚠️  Error: 'requests' module not found. Install with: pip install requests")
            sys.exit(1)

        print(f"\n📤 Indexing to Elasticsearch ({args.es_server}/{args.es_index})...")

        # Prepare bulk request
        bulk_data = []
        for doc in documents:
            bulk_data.append(json.dumps({"index": {"_index": args.es_index}}))
            bulk_data.append(json.dumps(doc))

        bulk_body = '\n'.join(bulk_data) + '\n'

        # Send bulk request
        url = f"{args.es_server}/_bulk"
        headers = {'Content-Type': 'application/x-ndjson'}

        response = requests.post(url, data=bulk_body, headers=headers, timeout=60)

        if response.status_code == 200:
            result = response.json()
            if result.get('errors'):
                print(f"  ⚠️  Some documents failed to index")
                for item in result.get('items', [])[:5]:
                    if 'error' in item.get('index', {}):
                        print(f"    Error: {item['index']['error']}")
            else:
                print(f"  ✓ Successfully indexed {len(documents)} documents")
                print(f"  ✓ Index: {args.es_index}")
                print(f"\n🎯 Ready to test with:")
                print(f"     ./scripts/analyze-batch.py --batch-id '{args.batch_id}'")
        else:
            print(f"  ✗ Failed to index: {response.status_code} {response.text}")
            sys.exit(1)

    print("\n✅ Done!")


if __name__ == '__main__':
    main()
