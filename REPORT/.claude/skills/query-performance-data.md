# Query Performance Data

Query performance benchmark data from OpenSearch for network performance analysis.

## When to Use
- User asks to search for specific test results
- User wants to find top performers by throughput
- User needs to filter by test parameters (topology, protocol, threads, etc.)
- User wants to analyze specific batches

## What This Skill Does

1. **Connect to OpenSearch**
   - Use curl to query http://localhost:9200
   - Search regulus-results-* indices
   - Use ES_WRITE_ALIAS=regulus-results-write for current data

2. **Common Query Patterns**
   - Search by batch_id to analyze specific test runs
   - Filter by topology (internode/intranode)
   - Filter by protocol (tcp/udp)
   - Filter by test_type (stream/rr/crr)
   - Filter by cpu allocation, threads, wsize, performance_profile
   - Sort by mean (throughput) to find top performers

3. **Data Fields**
   - `mean`: Throughput value (Gbps for stream, trans/sec for rr)
   - `cpu`: CPU allocation (e.g., "2", "29", "58(Gu)")
   - `busy_cpu`: Number of busy CPUs during test
   - `topology`: internode or intranode
   - `protocol`: tcp or udp
   - `test_type`: stream, rr, or crr
   - `threads`: Number of threads
   - `wsize`: Packet/window size in bytes
   - `performance_profile`: single-numa-node or None
   - `batch_id`: UUID identifying the test run

4. **Output Format**
   - Return JSON results with relevant fields
   - Include throughput (mean) and CPU metrics (busy_cpu)
   - Show test parameters for context

## Example Queries

**Find highest throughput for internode TCP stream:**
```bash
curl -X GET "http://localhost:9200/regulus-results-*/_search" -H 'Content-Type: application/json' -d'
{
  "query": {
    "bool": {
      "must": [
        {"term": {"topology": "internode"}},
        {"term": {"protocol": "tcp"}},
        {"term": {"test_type": "stream"}}
      ]
    }
  },
  "sort": [{"mean": {"order": "desc"}}],
  "size": 10
}'
```

**Find all tests for a specific batch:**
```bash
curl -X GET "http://localhost:9200/regulus-results-*/_search" -H 'Content-Type: application/json' -d'
{
  "query": {
    "term": {"batch_id": "BATCH_UUID_HERE"}
  },
  "size": 100
}'
```
