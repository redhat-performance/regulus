#!/usr/bin/env python3
"""Verify Elasticsearch index mapping compatibility with Orion batch analyzer."""
import sys
import json

# Required fields for Orion
orion_required = ["@timestamp", "iteration_id"]
orion_keyword = ["iteration_id"]

# Required fields for batch analysis
batch_required = ["batch_id"]
batch_keyword = ["batch_id"]

# Non-fingerprint fields — everything else in the mapping is a fingerprint field.
NON_FINGERPRINT_FIELDS = {
    '@timestamp',
    'mean', 'min', 'max', 'stddev', 'stddev_pct',
    'busy_cpu', 'samples_count', 'sample_count',
    'run_id', 'batch_id', 'iteration_id',
    'regulus_data', 'regulus_git_branch', 'execution_label',
    'mock_data',
}

try:
    data = json.load(sys.stdin)

    errors = []
    warnings = []

    for idx_name, idx_data in data.items():
        props = idx_data.get("mappings", {}).get("properties", {})
        print(f"Index: {idx_name}")
        print("")

        # Check Orion required fields
        print("Orion Requirements:")
        for field in orion_required:
            if field in props:
                print(f"  ✅ {field} exists")
            else:
                errors.append(f"{field} MISSING (required by Orion)")
                print(f"  ❌ {field} MISSING (required by Orion)")

        for field in orion_keyword:
            if field in props and "fields" in props[field] and "keyword" in props[field]["fields"]:
                print(f"  ✅ {field}.keyword exists")
            else:
                errors.append(f"{field}.keyword MISSING (required by Orion)")
                print(f"  ❌ {field}.keyword MISSING (required by Orion)")

        print("")

        # Check batch analysis fields
        print("Batch Analysis Requirements:")
        for field in batch_required:
            if field in props:
                print(f"  ✅ {field} exists")
            else:
                errors.append(f"{field} MISSING (batch analysis will fail)")
                print(f"  ❌ {field} MISSING (batch analysis will fail)")

        for field in batch_keyword:
            if field in props and "fields" in props[field] and "keyword" in props[field]["fields"]:
                print(f"  ✅ {field}.keyword exists")
            else:
                errors.append(f"{field}.keyword MISSING (batch analysis will fail)")
                print(f"  ❌ {field}.keyword MISSING (batch analysis will fail)")

        print("")

        # Discover fingerprint fields (all properties minus exclusion set)
        fingerprint_fields = sorted(f for f in props if f not in NON_FINGERPRINT_FIELDS)
        print(f"Fingerprint Fields (discovered {len(fingerprint_fields)} from mapping):")
        if fingerprint_fields:
            for f in fingerprint_fields:
                print(f"  ✅ {f}")
        else:
            print(f"  ⚠️  No fingerprint fields found (all fields are in exclusion set)")
            warnings.append("no_fingerprint_fields")

        print("")

    # Summary
    print("=" * 80)
    print("Summary:")
    print("=" * 80)
    if errors:
        print(f"❌ {len(errors)} critical error(s) found - analysis will FAIL:")
        for err in errors:
            print(f"   - {err}")
        sys.exit(1)
    elif warnings:
        print(f"⚠️  {len(warnings)} warning(s) - analysis may be incomplete:")
        for warn in warnings:
            print(f"   - {warn}")
        sys.exit(0)
    else:
        print("✅ Index mapping is fully compatible")
        sys.exit(0)

except Exception as e:
    print(f"❌ Error verifying mapping: {e}", file=sys.stderr)
    sys.exit(1)
