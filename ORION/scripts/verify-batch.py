#!/usr/bin/env python3
"""Verify batch data quality - check if documents have all required fields."""
import sys
import json

# Non-fingerprint fields — everything else is a fingerprint field.
NON_FINGERPRINT_FIELDS = {
    '@timestamp',
    'mean', 'min', 'max', 'stddev', 'stddev_pct',
    'busy_cpu', 'samples_count', 'sample_count',
    'run_id', 'batch_id', 'iteration_id',
    'regulus_data', 'regulus_git_branch', 'execution_label',
    'mock_data',
}

# Orion required fields
ORION_FIELDS = ["@timestamp", "iteration_id", "batch_id"]

# Required metric fields (Orion needs these)
METRIC_FIELDS = ["mean", "min", "max", "stddev", "sample_count"]

try:
    data = json.load(sys.stdin)

    hits = data.get('hits', {}).get('hits', [])
    total = data.get('hits', {}).get('total', {})

    if isinstance(total, dict):
        total_count = total.get('value', 0)
    else:
        total_count = total

    if total_count == 0:
        print("❌ Batch not found or has no documents")
        sys.exit(1)

    print(f"Found {total_count} document(s) in batch")
    print("")

    # Discover fingerprint fields from first document's keys
    first_doc = hits[0].get('_source', {}) if hits else {}
    FINGERPRINT_FIELDS = sorted(k for k in first_doc if k not in NON_FINGERPRINT_FIELDS)
    print(f"Discovered {len(FINGERPRINT_FIELDS)} fingerprint fields from document keys")
    print("")

    # Analyze documents
    missing_fields = {}
    missing_metrics = {}
    bad_docs = []

    for i, hit in enumerate(hits, 1):
        doc = hit.get('_source', {})
        doc_id = hit.get('_id', f'doc-{i}')
        doc_missing = []

        # Check Orion required fields
        for field in ORION_FIELDS:
            if field not in doc or doc[field] is None or doc[field] == "":
                doc_missing.append(field)
                missing_fields[field] = missing_fields.get(field, 0) + 1

        # Check fingerprint fields
        for field in FINGERPRINT_FIELDS:
            if field not in doc or doc[field] is None:
                doc_missing.append(field)
                missing_fields[field] = missing_fields.get(field, 0) + 1

        # Check metric fields
        for field in METRIC_FIELDS:
            if field not in doc or doc[field] is None:
                missing_metrics[field] = missing_metrics.get(field, 0) + 1

        if doc_missing:
            bad_docs.append((doc_id, doc_missing))

    # Report findings
    print("=" * 80)
    print("Batch Data Quality Report")
    print("=" * 80)
    print("")

    if missing_fields:
        print("❌ CRITICAL: Missing required fields detected")
        print("")
        print("Field                          Missing in N documents")
        print("-" * 80)
        for field, count in sorted(missing_fields.items(), key=lambda x: x[1], reverse=True):
            print(f"{field:<30} {count:>10}/{total_count}")
        print("")
        print("This will cause dynamic config builder to fail!")
        print("")

    if missing_metrics:
        print("⚠️  WARNING: Missing metric fields")
        print("")
        print("Field                          Missing in N documents")
        print("-" * 80)
        for field, count in sorted(missing_metrics.items(), key=lambda x: x[1], reverse=True):
            print(f"{field:<30} {count:>10}/{total_count}")
        print("")
        print("Orion analysis may fail if metrics are missing.")
        print("")

    if bad_docs:
        print(f"Documents with issues: {len(bad_docs)}/{total_count}")
        if len(bad_docs) <= 5:
            print("")
            for doc_id, fields in bad_docs[:5]:
                print(f"  {doc_id}: missing {', '.join(fields)}")
        print("")

    if not missing_fields and not missing_metrics:
        print("✅ All documents have required fields")
        print("✅ Batch data quality is good")
        sys.exit(0)
    elif missing_fields:
        print("=" * 80)
        print("❌ Batch has critical data quality issues")
        print("=" * 80)
        sys.exit(1)
    else:
        print("=" * 80)
        print("⚠️  Batch has warnings but may still work")
        print("=" * 80)
        sys.exit(0)

except Exception as e:
    print(f"❌ Error verifying batch: {e}", file=sys.stderr)
    sys.exit(1)
