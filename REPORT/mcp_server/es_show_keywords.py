#!/usr/bin/env python3
"""
Show all valid keyword values for search filters from ElasticSearch.

Usage:
    ./es_show_keywords.py
"""

import os
import sys
import asyncio
import httpx


ES_URL = os.getenv("ES_URL", "http://localhost:9200")
ES_INDEX = os.getenv("ES_INDEX", "regulus-results")


async def get_field_values(field_name: str, size: int = 50):
    """Get unique values for a field."""
    query = {
        "size": 0,
        "aggs": {
            "unique_values": {
                "terms": {
                    "field": field_name,
                    "size": size,
                    "order": {"_count": "desc"}
                }
            }
        }
    }

    url = f"{ES_URL}/{ES_INDEX}/_search"

    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(
                url,
                json=query,
                headers={"Content-Type": "application/json"},
                timeout=30.0
            )
            response.raise_for_status()
            data = response.json()

            buckets = data.get("aggregations", {}).get("unique_values", {}).get("buckets", [])
            return [(b["key"], b["doc_count"]) for b in buckets]

        except Exception as e:
            return []


async def main():
    print("=" * 70)
    print("  Valid Search Keywords from Regulus ElasticSearch")
    print("=" * 70)
    print()

    # Check connection
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(f"{ES_URL}/{ES_INDEX}/_count", timeout=10.0)
            response.raise_for_status()
            total = response.json().get("count", 0)
            print(f"Connected to: {ES_INDEX}")
            print(f"Total Documents: {total}")
            print()
    except Exception as e:
        print(f"Error: Cannot connect to ElasticSearch: {e}", file=sys.stderr)
        sys.exit(1)

    # Get values for each field
    fields = {
        "benchmark": "Benchmark Types (--benchmark)",
        "model": "Datapath Models (--model)",
        "nic": "NIC Types (--nic)",
        "topology": "Topologies (--topology)",
        "protocol": "Protocols (--protocol)",
        "test_type": "Test Types (--test-type)",
        "kernel": "Kernel Versions (--kernel)",
        "rcos": "RCOS/OpenShift Versions (--rcos)",
        "arch": "Architectures (--arch)",
        "cpu": "CPU Counts (--cpu)",
        "performance_profile": "Performance Profiles (--performance-profile)",
        "offload": "Offload Settings (--offload)",
        "threads": "Thread Counts (--threads)",
        "wsize": "Write Sizes (--wsize)",
        "rsize": "Read Sizes (--rsize)",
        "pods_per_worker": "Pods Per Worker (--pods-per-worker)",
        "scale_out_factor": "Scale Out Factors (--scale-out-factor)"
    }

    for field, label in fields.items():
        values = await get_field_values(field)

        if values:
            print(f"{label}:")
            print("-" * 70)
            for value, count in values:
                if value is not None:  # Skip None but allow 0
                    # Format value as string (handles both strings and integers)
                    value_str = str(value)
                    print(f"  {value_str:30s} ({count:4d} documents)")
            print()

    # Show throughput range
    print("Throughput Range (--min-throughput):")
    print("-" * 70)

    query = {
        "size": 0,
        "aggs": {
            "stats": {
                "stats": {"field": "mean"}
            },
            "unit": {
                "terms": {"field": "unit", "size": 10}
            }
        }
    }

    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{ES_URL}/{ES_INDEX}/_search",
                json=query,
                headers={"Content-Type": "application/json"},
                timeout=30.0
            )
            data = response.json()

            stats = data.get("aggregations", {}).get("stats", {})
            units = data.get("aggregations", {}).get("unit", {}).get("buckets", [])

            print(f"  Min:  {stats.get('min', 'N/A')}")
            print(f"  Max:  {stats.get('max', 'N/A')}")
            print(f"  Avg:  {stats.get('avg', 'N/A')}")
            print()
            print("  Units used:")
            for u in units:
                print(f"    - {u['key']} ({u['doc_count']} documents)")
            print()

    except Exception as e:
        print(f"  Error fetching stats: {e}")
        print()

    print("=" * 70)
    print("Example Queries:")
    print("=" * 70)

    # Get one example value from each field for examples
    benchmarks = await get_field_values("benchmark", size=2)
    models = await get_field_values("model", size=2)
    nics = await get_field_values("nic", size=2)

    if benchmarks and benchmarks[0][0]:
        print(f"./build_and_run.sh search --benchmark {benchmarks[0][0]}")

    if models and models[0][0]:
        print(f"./build_and_run.sh search --model {models[0][0]}")

    if nics and nics[0][0]:
        print(f"./build_and_run.sh search --nic {nics[0][0]}")

    if benchmarks and models and benchmarks[0][0] and models[0][0]:
        print(f"./build_and_run.sh search --benchmark {benchmarks[0][0]} --model {models[0][0]}")

    print("./build_and_run.sh search --min-throughput 90 --size 20")
    print()


if __name__ == '__main__':
    asyncio.run(main())
