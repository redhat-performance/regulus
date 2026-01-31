# ElasticSearch/OpenSearch Integration Guide

This guide covers how to upload benchmark results to ElasticSearch or OpenSearch and manage the data.

**Platform Auto-Detection**: All targets automatically detect whether you're using ElasticSearch or OpenSearch and use the appropriate APIs. No manual configuration needed!

## Quick Start

### Complete Workflow (Recommended)

The simplest way to generate reports and upload to ElasticSearch:

```bash
cd $REG_ROOT i.e /home/<user>/regulus

# Delete existing index (if needed)
curl -X DELETE "http://localhost:9200/regulus-results"

# Run complete workflow: generate reports + upload to ES
make -C REPORT es-full ES_HOST=localhost:9200
```

This will:
1. Generate both unflatten (report.json) and flatten (reports.ndjson) outputs
2. Apply the ElasticSearch index template
3. Upload the data to ElasticSearch

## Step-by-Step Workflow

### 1. Generate Reports

```bash
cd $REG_ROOT i.e /home/user/regulus

# Generate both unflatten and flatten outputs
make report-summary
```

This creates:
- `report.json` - Unflatten format (nested JSON)
- `reports.ndjson` - Flatten format (NDJSON for ElasticSearch)
- `report.html` - HTML report
- `report.csv` - CSV report

### 2. Upload to ElasticSearch

```bash
# Apply index template (first time only)
make -C REPORT es-template ES_HOST=localhost:9200

# Upload data
make -C REPORT es-upload ES_HOST=localhost:9200
```

## Managing ElasticSearch Data

### Delete and Re-push (Clean Slate)

When you want to completely replace the data:

```bash
# Delete the entire index
curl -X DELETE "http://localhost:9200/regulus-results"

# Re-run the complete workflow
make -C REPORT es-full ES_HOST=localhost:9200
```

### Update Existing Data

To add new documents without deleting old ones:

```bash
# Generate new reports
make report-summary

# Upload (will add/update documents by ID)
make -C REPORT es-upload ES_HOST=localhost:9200
```

### Delete Specific Documents

Delete documents by query (e.g., specific run_id):

```bash
curl -X POST "http://localhost:9200/regulus-results/_delete_by_query" \
  -H 'Content-Type: application/json' \
  -d '{
    "query": {
      "match": {
        "run_id": "your-run-id-here"
      }
    }
  }'
```

## Verification

### Check Index Status

```bash
# Check if index exists
curl "http://localhost:9200/regulus-results"

# Get index mapping
curl "http://localhost:9200/regulus-results/_mapping?pretty"

# Get index settings
curl "http://localhost:9200/regulus-results/_settings?pretty"
```

### Count Documents

```bash
# Count all documents
curl "http://localhost:9200/regulus-results/_count?pretty"

# Count documents matching a query
curl -X POST "http://localhost:9200/regulus-results/_count?pretty" \
  -H 'Content-Type: application/json' \
  -d '{
    "query": {
      "match": {
        "model": "OVNK"
      }
    }
  }'
```

### View Documents

```bash
# View first 5 documents
curl "http://localhost:9200/regulus-results/_search?size=5&pretty"

# Search with filters
curl -X POST "http://localhost:9200/regulus-results/_search?pretty" \
  -H 'Content-Type: application/json' \
  -d '{
    "query": {
      "bool": {
        "must": [
          { "match": { "model": "OVNK" } },
          { "match": { "unit": "Gbps" } }
        ]
      }
    },
    "size": 10
  }'
```

### View Specific Document

```bash
# Get document by ID
curl "http://localhost:9200/regulus-results/_doc/YOUR_DOCUMENT_ID?pretty"
```

## Index Lifecycle Management (ILM/ISM)

Automatically manage index rollover and retention with lifecycle policies. Both ElasticSearch and OpenSearch are supported with automatic platform detection.

### Lifecycle Phases

1. **Hot Phase (0-30 days)** - Active data receiving writes
   - Rollover triggers: 50GB size OR 30 days age OR 1M documents
   - Highest priority for search

2. **Warm Phase (7-30 days)** - Read-only optimization
   - Force merge to 1 segment for better performance
   - Medium priority

3. **Cold Phase (30-90 days)** - Long-term storage
   - ElasticSearch: Searchable snapshots
   - OpenSearch: Replica reduction
   - Lowest priority

4. **Delete Phase (90+ days)** - Automatic deletion

### Setup Lifecycle Policy

```bash
# Apply lifecycle policy (auto-detects ES/OpenSearch)
make -C REPORT/build_report es-ilm-policy ES_HOST=localhost:9200

# View applied policy
make -C REPORT/build_report es-ilm-info ES_HOST=localhost:9200

# Check lifecycle status for an index
make -C REPORT/build_report es-ilm-explain ES_HOST=localhost:9200 ES_INDEX=regulus-results
```

### Bootstrap Rollover Index

Before uploading data with lifecycle management:

```bash
# Create rollover-enabled index with write alias
make -C REPORT/build_report es-bootstrap-index ES_HOST=localhost:9200
```

This creates:
- Index: `regulus-results-000001`
- Write alias: `regulus-results`

New indices are automatically created when rollover conditions are met (e.g., `regulus-results-000002`, `regulus-results-000003`, etc.).

### Files

- **detect_platform.sh** - Auto-detection script for ES/OpenSearch
- **es_ilm_policy.json** - ElasticSearch ILM policy
- **opensearch_ism_policy.json** - OpenSearch ISM policy
- **es_mapping_template.json** - Index template with lifecycle settings

## Makefile Targets Reference

### From Root Directory

```bash
# Generate reports (unflatten + flatten)
make report-summary

# Complete ES workflow
make -C REPORT es-full ES_HOST=localhost:9200
```

### From REPORT Directory

```bash
cd REPORT

# Generate reports
make summary

# ElasticSearch operations
make es-check ES_HOST=localhost:9200        # Check ES connection
make es-template ES_HOST=localhost:9200     # Apply index template
make es-upload ES_HOST=localhost:9200       # Upload data
make es-full ES_HOST=localhost:9200         # Complete workflow

# Index Lifecycle Management (auto-detects ES/OpenSearch)
make es-ilm-policy ES_HOST=localhost:9200   # Apply ILM/ISM policy
make es-ilm-info ES_HOST=localhost:9200     # View policy details
make es-ilm-explain ES_HOST=localhost:9200  # Check index lifecycle status
make es-bootstrap-index ES_HOST=localhost:9200  # Create rollover index

# Debugging
make es-index-stats ES_HOST=localhost:9200  # Show index statistics
make es-index-mapping ES_HOST=localhost:9200 # Show index mapping
make es-template-info ES_HOST=localhost:9200 # Show template details
```

## Configuration

### Environment Variables

Set these in your makefile or environment:

```bash
ES_HOST=localhost:9200          # ElasticSearch host:port
ES_INDEX=regulus-results        # Index name
ES_USER=elastic                 # Username (if auth enabled)
ES_PASSWORD=changeme            # Password (if auth enabled)
```

### With Authentication

```bash
# Upload with authentication
make -C REPORT es-upload \
  ES_HOST=localhost:9200 \
  ES_USER=elastic \
  ES_PASSWORD=changeme
```

## Document Structure

Each document in the index contains:

```json
{
  "@timestamp": "2025-11-21T23:49:33.266144",
  "regulus_data": "path/to/result-summary.txt",
  "run_id": "957f87ae-7221-42fc-ae36-3ad65e7c1b5e",
  "iteration_id": "84C3D740-C75E-11F0-883A-A3313D4C31ED",
  "benchmark": "uperf",
  "protocol": "tcp",
  "model": "OVNK",
  "nic": "E810",
  "arch": "INTEL(R)_XEON(R)_GOLD_6548Y+",
  "cpu": "52",
  "kernel": "5.14.0-570.49.1.el9_6.x86_64",
  "rcos": "9.6.20250925-0",
  "topology": "internode",
  "performance_profile": "None",
  "offload": "None",
  "threads": 64,
  "pods_per_worker": "1",
  "scale_out_factor": "1",
  "mean": 9.431873,
  "min": 9.431873,
  "max": 9.431873,
  "unit": "Gbps",
  "busy_cpu": 10.8544
}
```

### Document ID Format

Documents are uniquely identified by:
```
{run_id}_{iteration_id}_{unit}
```

This ensures that multiple metrics from the same iteration (e.g., Gbps, connections/sec) are stored as separate documents.

## Troubleshooting

### Index Already Exists Error

If you get an error that the index already exists:

```bash
# Delete the index
curl -X DELETE "http://localhost:9200/regulus-results"

# Re-run the workflow
make -C REPORT es-full ES_HOST=localhost:9200
```

### Connection Refused

Check if ElasticSearch is running:

```bash
# Check ES status
curl "http://localhost:9200"

# Check if ES is listening
ss -lntp | grep 9200
```

### Document Count Mismatch

If the document count doesn't match expectations:

```bash
# Check for duplicate IDs
curl -X POST "http://localhost:9200/regulus-results/_search?pretty" \
  -H 'Content-Type: application/json' \
  -d '{
    "aggs": {
      "duplicate_ids": {
        "terms": {
          "field": "_id",
          "min_doc_count": 2
        }
      }
    }
  }'
```

### View Upload Errors

Check the bulk upload response for errors:

```bash
# The es-upload target will show errors in the output
make -C REPORT es-upload ES_HOST=localhost:9200
```

## Advanced Usage

### Custom Index Name

```bash
make -C REPORT es-upload \
  ES_HOST=localhost:9200 \
  ES_INDEX=my-custom-index
```

### Flatten Only (No Upload)

```bash
# Generate flatten output without uploading
make -C REPORT flatten
```

### Pretty Print NDJSON

For debugging, create a human-readable version:

```bash
make -C REPORT flatten-pretty
# Output: reports_pretty.json
```

### Direct Python Script Usage

```bash
cd REPORT/build_report

# Flatten report.json
python3 es_integration/flatten_to_es.py report.json -o output.ndjson

# Upload directly to ES
python3 es_integration/flatten_to_es.py report.json \
  --es-host localhost:9200 \
  --es-index regulus-results
```

## Best Practices

1. **Always delete the index before re-uploading** if you want a clean slate
2. **Use document IDs** to allow updates without duplicates
3. **Check the document count** after upload to verify success
4. **Apply the index template** before first upload to ensure proper field mappings
5. **Use the complete workflow** (`es-full`) for simplicity

## Data Flow

```
report.json (unflatten)
    ↓
flatten_to_es.py
    ↓
reports.ndjson (flatten)
    ↓
ElasticSearch Bulk API
    ↓
regulus-results index
```

The `make summary` target generates both unflatten and flatten outputs in one step, ensuring the flatten input is always the just-created report.json (safe and predictable).
