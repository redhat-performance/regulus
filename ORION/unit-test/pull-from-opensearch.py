#!/usr/bin/env python3
"""
Pull mock data from OpenSearch to local JSON files.

This allows you to:
- Verify what's indexed in OpenSearch
- Extract data for re-use or inspection
- Practice the workflow by pulling, then re-indexing

Usage:
    ./pull-from-opensearch.py --es-server http://localhost:9200
    ./pull-from-opensearch.py --es-server http://localhost:9200 --query '{"term": {"nic": "mlx5_0"}}'
"""

import argparse
import json
import sys
import os


def pull_from_opensearch(es_server, index_pattern, query=None, output_dir="generated/pulled",
                        es_user=None, es_password=None, size=1000):
    """Pull documents from OpenSearch."""
    try:
        import requests
        from requests.auth import HTTPBasicAuth
    except ImportError:
        print("Error: 'requests' module required. Install with: pip3 install requests")
        sys.exit(1)

    # Ensure output directory exists
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
        print(f"Created directory: {output_dir}")

    # Build search URL
    url = f"{es_server}/{index_pattern}/_search"

    # Build query
    search_body = {
        "size": size,
        "query": query if query else {"match_all": {}},
        "sort": [{"@timestamp": "asc"}]
    }

    # Authentication
    auth = None
    if es_user and es_password:
        auth = HTTPBasicAuth(es_user, es_password)

    print(f"Pulling from: {url}")
    print(f"Query: {json.dumps(search_body['query'], indent=2)}")
    print(f"Max documents: {size}")
    print()

    # Execute search
    response = requests.post(url, json=search_body, auth=auth)

    if response.status_code != 200:
        print(f"Error: HTTP {response.status_code}")
        print(response.text)
        sys.exit(1)

    result = response.json()
    hits = result.get('hits', {}).get('hits', [])
    total = result.get('hits', {}).get('total', {})

    if isinstance(total, dict):
        total_count = total.get('value', 0)
    else:
        total_count = total

    print(f"Found {total_count} total documents")
    print(f"Retrieved {len(hits)} documents")
    print()

    if len(hits) == 0:
        print("No documents found!")
        return

    # Extract source documents
    documents = [hit['_source'] for hit in hits]

    # Group by metadata characteristics
    groups = {}

    for doc in documents:
        # Create a key based on test characteristics
        key_parts = []
        key_parts.append(doc.get('unit', 'unknown'))

        if 'topology' in doc:
            key_parts.append(doc['topology'])
        if 'protocol' in doc:
            key_parts.append(doc['protocol'])
        if 'nic' in doc:
            key_parts.append(doc['nic'])

        key = '-'.join(key_parts)

        if key not in groups:
            groups[key] = []
        groups[key].append(doc)

    print(f"Organized into {len(groups)} groups:")
    print()

    # Save each group
    for group_name, group_docs in groups.items():
        filename = f"{output_dir}/{group_name}.json"

        with open(filename, 'w') as f:
            json.dump(group_docs, f, indent=2)

        print(f"  ✓ {group_name}: {len(group_docs)} docs → {filename}")

    # Also save all documents together
    all_filename = f"{output_dir}/all-pulled-data.json"
    with open(all_filename, 'w') as f:
        json.dump(documents, f, indent=2)

    print()
    print(f"  ✓ All documents: {len(documents)} docs → {all_filename}")
    print()

    # Show statistics
    print("=" * 80)
    print("STATISTICS")
    print("=" * 80)

    units = {}
    topologies = {}
    protocols = {}
    nics = {}

    for doc in documents:
        unit = doc.get('unit', 'unknown')
        units[unit] = units.get(unit, 0) + 1

        if 'topology' in doc:
            topo = doc['topology']
            topologies[topo] = topologies.get(topo, 0) + 1

        if 'protocol' in doc:
            proto = doc['protocol']
            protocols[proto] = protocols.get(proto, 0) + 1

        if 'nic' in doc:
            nic = doc['nic']
            nics[nic] = nics.get(nic, 0) + 1

    print(f"\nUnits: {units}")
    print(f"Topologies: {topologies}")
    print(f"Protocols: {protocols}")
    print(f"NICs: {nics}")
    print()

    print("=" * 80)
    print("NEXT STEPS")
    print("=" * 80)
    print()
    print("1. Inspect the data:")
    print(f"   jq '.[0]' {all_filename}")
    print()
    print("2. Convert to bulk format:")
    print(f"   ./json-to-bulk.py {all_filename} {output_dir}/bulk-all.ndjson")
    print()
    print("3. Re-index to OpenSearch:")
    print(f"   curl -X POST '{es_server}/_bulk' \\")
    print(f"     -H 'Content-Type: application/x-ndjson' \\")
    print(f"     --data-binary '@{output_dir}/bulk-all.ndjson'")
    print()


def main():
    parser = argparse.ArgumentParser(
        description='Pull mock data from OpenSearch to local files',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Pull all mock data
  ./pull-from-opensearch.py --es-server http://localhost:9200

  # Pull specific test type
  ./pull-from-opensearch.py --es-server http://localhost:9200 \\
    --query '{"term": {"nic": "mlx5_0"}}'

  # Pull with authentication
  ./pull-from-opensearch.py --es-server https://your-server:9200 \\
    --es-user admin --es-password secret

  # Pull to custom directory
  ./pull-from-opensearch.py --es-server http://localhost:9200 \\
    --output generated/backup

  # Pull only 100 documents
  ./pull-from-opensearch.py --es-server http://localhost:9200 --size 100
        """
    )

    parser.add_argument('--es-server', required=True,
                       help='OpenSearch server URL')

    parser.add_argument('--index', default='regulus-results-mock*',
                       help='Index pattern to search (default: regulus-results-mock*)')

    parser.add_argument('--query', type=json.loads,
                       help='Query JSON (default: match_all)')

    parser.add_argument('--output', default='generated/pulled',
                       help='Output directory (default: generated/pulled)')

    parser.add_argument('--es-user', help='OpenSearch username')
    parser.add_argument('--es-password', help='OpenSearch password')

    parser.add_argument('--size', type=int, default=1000,
                       help='Maximum documents to retrieve (default: 1000)')

    args = parser.parse_args()

    print()
    print("=" * 80)
    print("PULL DATA FROM OPENSEARCH")
    print("=" * 80)
    print()

    pull_from_opensearch(
        es_server=args.es_server,
        index_pattern=args.index,
        query=args.query,
        output_dir=args.output,
        es_user=args.es_user,
        es_password=args.es_password,
        size=args.size
    )


if __name__ == '__main__':
    main()
