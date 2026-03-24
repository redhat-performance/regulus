# Manage OpenSearch Batches

List, inspect, and manage performance test batches stored in OpenSearch.

## When to Use
- User asks "how many batches are there"
- User wants to see available test runs
- User needs batch metadata or statistics

## What This Skill Does

1. **List All Batches**
   ```bash
   curl -X GET "http://localhost:9200/regulus-results-*/_search" -H 'Content-Type: application/json' -d'
   {
     "size": 0,
     "aggs": {
       "batches": {
         "terms": {
           "field": "batch_id.keyword",
           "size": 100
         },
         "aggs": {
           "doc_count": {"value_count": {"field": "_id"}},
           "first_upload": {"min": {"field": "@timestamp"}},
           "last_upload": {"max": {"field": "@timestamp"}}
         }
       }
     }
   }'
   ```

2. **Get Batch Metadata**
   - Batch ID (UUID)
   - Document count
   - Upload timestamp
   - Test configuration summary
   - Datapath type (DPU, NIC-mode, etc.)

3. **Batch Statistics**
   - Total number of tests
   - Topology breakdown (internode/intranode)
   - Protocol breakdown (tcp/udp)
   - Test type breakdown (stream/rr/crr)
   - CPU configurations used
   - Performance profile types

4. **Identify Batch Details**
   - Get one sample document to see batch metadata:
   ```bash
   curl -X GET "http://localhost:9200/regulus-results-*/_search" -H 'Content-Type: application/json' -d'
   {
     "query": {"term": {"batch_id.keyword": "BATCH_UUID"}},
     "size": 1
   }'
   ```

## Common Operations

**Count documents per batch:**
- Use aggregations on batch_id.keyword field

**Find latest batch:**
- Sort by @timestamp, get most recent

**Get batch by name pattern:**
- Search execution_label or regulus_data fields for identifying information

## Index Information

- **Index pattern**: regulus-results-*
- **Write alias**: regulus-results-write
- **Rollover**: Automatic at 5000 docs, 500MB, or 30 days
- **Current index**: regulus-results-000001
