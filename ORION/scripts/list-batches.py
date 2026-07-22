#!/usr/bin/env python3
"""List recent batch IDs from Elasticsearch."""
import sys
import json

try:
    data = json.load(sys.stdin)

    if "aggregations" not in data or "batches" not in data.get("aggregations", {}):
        print("\n⚠️  No batch_id field found in index or no data available")
        sys.exit(0)

    batches = data["aggregations"]["batches"]["buckets"]

    if not batches:
        print("\n⚠️  No batches found")
        sys.exit(0)

    print("\n{:<40} {:>10} {}".format("Batch ID", "Tests", "Latest Timestamp"))
    print("="*80)

    for b in batches:
        timestamp = b["latest"].get("value_as_string", "N/A")
        print("{:<40} {:>10} {}".format(b["key"], b["count"]["value"], timestamp))

except Exception as e:
    print(f"\n❌ Error parsing ES response: {e}")
    sys.exit(1)
