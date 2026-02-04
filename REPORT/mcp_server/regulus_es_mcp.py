#!/usr/bin/env python3
"""
Regulus ElasticSearch MCP Server

Model Context Protocol server for interacting with Regulus benchmark data in ElasticSearch.
Provides tools for querying, analyzing, and managing benchmark results.

Usage:
    python regulus_es_mcp.py

Configuration:
    Set ES_URL environment variable or configure in claude_desktop_config.json
"""

import os
import json
import logging
import sys
from typing import Any, Optional
from urllib.parse import urlparse
from mcp.server.fastmcp import FastMCP
import httpx

# Disable httpx logging to prevent credential leakage in URLs
logging.getLogger("httpx").setLevel(logging.WARNING)

# Initialize FastMCP server
mcp = FastMCP("regulus-elasticsearch")

# Configuration
ES_URL = os.getenv("ES_URL", "http://localhost:9200")
ES_INDEX = os.getenv("ES_INDEX", "regulus-results")
DEFAULT_SIZE = 10


def sanitize_url(url: str) -> str:
    """Remove credentials from URL for safe logging."""
    try:
        parsed = urlparse(url)
        if parsed.username or parsed.password:
            # Replace credentials with ***
            netloc = f"***:***@{parsed.hostname}"
            if parsed.port:
                netloc += f":{parsed.port}"
            return f"{parsed.scheme}://{netloc}{parsed.path}"
        return url
    except Exception:
        return "***"


def log_es_request(method: str, endpoint: str, status: str):
    """Log ES request with sanitized URL."""
    safe_url = sanitize_url(f"{ES_URL}/{endpoint}")
    print(f"[ES] {method} {safe_url} - {status}", file=sys.stderr)


async def es_request(
    method: str,
    endpoint: str,
    body: Optional[dict] = None
) -> dict[str, Any] | None:
    """Make a request to ElasticSearch."""
    url = f"{ES_URL}/{endpoint}"

    async with httpx.AsyncClient() as client:
        try:
            if method == "GET":
                response = await client.get(url, timeout=30.0)
            elif method == "POST":
                response = await client.post(
                    url,
                    json=body,
                    headers={"Content-Type": "application/json"},
                    timeout=30.0
                )
            elif method == "DELETE":
                response = await client.delete(url, timeout=30.0)
            else:
                return {"error": f"Unsupported HTTP method: {method}"}

            response.raise_for_status()

            # Log with sanitized URL
            log_es_request(method, endpoint, f"{response.status_code} {response.reason_phrase}")

            return response.json()
        except httpx.HTTPError as e:
            log_es_request(method, endpoint, f"ERROR: {type(e).__name__}")
            return {"error": str(e)}
        except Exception as e:
            log_es_request(method, endpoint, f"ERROR: {str(e)}")
            return {"error": f"Request failed: {str(e)}"}


@mcp.tool()
async def list_batches() -> str:
    """
    List all upload batches in the Regulus ElasticSearch index.
    Returns batch IDs with document counts.
    """
    query = {
        "size": 0,
        "aggs": {
            "batches": {
                "terms": {
                    "field": "batch_id.keyword",
                    "size": 100,
                    "order": {"_key": "desc"}
                }
            }
        }
    }

    result = await es_request("POST", f"{ES_INDEX}/_search", query)

    if not result or "error" in result:
        return f"Error: {result.get('error', 'Unknown error')}"

    buckets = result.get("aggregations", {}).get("batches", {}).get("buckets", [])

    if not buckets:
        return "No batches found in the index."

    output = [f"Found {len(buckets)} batch(es):\n"]
    for bucket in buckets:
        batch_id = bucket["key"]
        count = bucket["doc_count"]
        output.append(f"  • {batch_id}: {count} documents")

    return "\n".join(output)


@mcp.tool()
async def get_batch_info(batch_id: str) -> str:
    """
    Get detailed information about a specific batch.

    Args:
        batch_id: The UUID of the batch to inspect
    """
    query = {
        "size": 0,
        "query": {
            "term": {"batch_id.keyword": batch_id}
        },
        "aggs": {
            "benchmarks": {
                "terms": {"field": "benchmark", "size": 20}
            },
            "models": {
                "terms": {"field": "model", "size": 20}
            },
            "nics": {
                "terms": {"field": "nic", "size": 20}
            },
            "timestamp_stats": {
                "stats": {"field": "@timestamp"}
            }
        }
    }

    result = await es_request("POST", f"{ES_INDEX}/_search", query)

    if not result or "error" in result:
        return f"Error: {result.get('error', 'Unknown error')}"

    total = result.get("hits", {}).get("total", {}).get("value", 0)

    if total == 0:
        return f"No documents found with batch_id: {batch_id}"

    aggs = result.get("aggregations", {})
    benchmarks = aggs.get("benchmarks", {}).get("buckets", [])
    models = aggs.get("models", {}).get("buckets", [])
    nics = aggs.get("nics", {}).get("buckets", [])

    output = [
        f"Batch ID: {batch_id}",
        f"Total Documents: {total}",
        "",
        "Benchmarks:"
    ]
    for b in benchmarks:
        output.append(f"  • {b['key']}: {b['doc_count']} docs")

    output.append("\nModels:")
    for m in models:
        output.append(f"  • {m['key']}: {m['doc_count']} docs")

    output.append("\nNICs:")
    for n in nics:
        output.append(f"  • {n['key']}: {n['doc_count']} docs")

    return "\n".join(output)


@mcp.tool()
async def search_benchmarks(
    benchmark: Optional[str] = None,
    model: Optional[str] = None,
    nic: Optional[str] = None,
    topology: Optional[str] = None,
    protocol: Optional[str] = None,
    test_type: Optional[str] = None,
    kernel: Optional[str] = None,
    rcos: Optional[str] = None,
    arch: Optional[str] = None,
    cpu: Optional[str] = None,
    performance_profile: Optional[str] = None,
    offload: Optional[str] = None,
    threads: Optional[int] = None,
    wsize: Optional[int] = None,
    rsize: Optional[int] = None,
    pods_per_worker: Optional[int] = None,
    scale_out_factor: Optional[int] = None,
    min_throughput: Optional[float] = None,
    max_throughput: Optional[float] = None,
    execution_label: Optional[str] = None,
    run_id: Optional[str] = None,
    iteration_id: Optional[str] = None,
    size: int = 10
) -> str:
    """
    Search for benchmark results with optional filters.

    Args:
        benchmark: Filter by benchmark type (e.g., 'uperf', 'iperf')
        model: Filter by datapath model (e.g., 'OVNK', 'DPU', 'SRIOV')
        nic: Filter by NIC type (e.g., 'E810', 'CX6', 'CX7', 'BF3')
        topology: Filter by topology (e.g., 'intranode', 'internode')
        protocol: Filter by protocol (e.g., 'tcp', 'udp')
        test_type: Filter by test type (e.g., 'stream', 'rr', 'crr')
        kernel: Filter by kernel version (e.g., '5.14.0-570.49.1.el9_6.x86_64')
        rcos: Filter by RCOS/OpenShift version (e.g., '4.17')
        arch: Filter by architecture (e.g., 'INTEL(R)_XEON(R)_GOLD_6548Y+')
        cpu: Filter by CPU count (e.g., '4', '26', '52')
        performance_profile: Filter by performance profile (e.g., 'performance', 'latency-performance')
        offload: Filter by offload settings (e.g., 'on', 'off')
        threads: Filter by thread count (e.g., 1, 32, 64)
        wsize: Filter by write size (e.g., 64, 1024, 8192)
        rsize: Filter by read size (e.g., 64, 1024, 8192)
        pods_per_worker: Filter by pods per worker node
        scale_out_factor: Filter by scale out factor
        min_throughput: Minimum mean throughput value
        max_throughput: Maximum mean throughput value
        execution_label: Filter by execution label (e.g., 'baseline-q1', 'non-accelerated', 'weekly-run-2025-w01')
        run_id: Filter by run ID (exact match)
        iteration_id: Filter by iteration ID (exact match)
        size: Number of results to return (default: 10, max: 100)
    """
    # Build query
    must_clauses = []

    # String field filters
    if benchmark:
        must_clauses.append({"term": {"benchmark": benchmark}})
    if model:
        must_clauses.append({"term": {"model": model}})
    if nic:
        must_clauses.append({"term": {"nic": nic}})
    if topology:
        must_clauses.append({"term": {"topology": topology}})
    if protocol:
        must_clauses.append({"term": {"protocol": protocol}})
    if test_type:
        must_clauses.append({"term": {"test_type": test_type}})
    if kernel:
        must_clauses.append({"term": {"kernel": kernel}})
    if rcos:
        must_clauses.append({"term": {"rcos": rcos}})
    if arch:
        must_clauses.append({"term": {"arch": arch}})
    if cpu:
        must_clauses.append({"term": {"cpu": cpu}})
    if performance_profile:
        must_clauses.append({"term": {"performance_profile": performance_profile}})
    if offload:
        must_clauses.append({"term": {"offload": offload}})

    # Execution context filters
    # These are defined as 'keyword' type in the mapping template, so no .keyword suffix needed
    if execution_label:
        must_clauses.append({"term": {"execution_label": execution_label}})
    if run_id:
        must_clauses.append({"term": {"run_id": run_id}})
    if iteration_id:
        must_clauses.append({"term": {"iteration_id": iteration_id}})

    # Integer field filters
    if threads is not None:
        must_clauses.append({"term": {"threads": threads}})
    if wsize is not None:
        must_clauses.append({"term": {"wsize": wsize}})
    if rsize is not None:
        must_clauses.append({"term": {"rsize": rsize}})
    if pods_per_worker is not None:
        must_clauses.append({"term": {"pods_per_worker": pods_per_worker}})
    if scale_out_factor is not None:
        must_clauses.append({"term": {"scale_out_factor": scale_out_factor}})

    # Throughput range filters
    if min_throughput is not None or max_throughput is not None:
        range_filter = {}
        if min_throughput is not None:
            range_filter["gte"] = min_throughput
        if max_throughput is not None:
            range_filter["lte"] = max_throughput
        must_clauses.append({"range": {"mean": range_filter}})

    query = {
        "size": min(size, 100),
        "query": {
            "bool": {"must": must_clauses} if must_clauses else {"match_all": {}}
        },
        "sort": [{"mean": {"order": "desc"}}, {"@timestamp": {"order": "desc"}}],
        "_source": [
            "batch_id", "run_id", "benchmark", "model", "nic", "kernel", "rcos",
            "topology", "protocol", "test_type", "arch", "cpu",
            "performance_profile", "offload",
            "threads", "wsize", "rsize",
            "pods_per_worker", "scale_out_factor",
            "mean", "unit", "busy_cpu", "@timestamp"
        ]
    }

    result = await es_request("POST", f"{ES_INDEX}/_search", query)

    if not result or "error" in result:
        return f"Error: {result.get('error', 'Unknown error')}"

    hits = result.get("hits", {}).get("hits", [])
    total = result.get("hits", {}).get("total", {}).get("value", 0)

    if not hits:
        return "No matching benchmark results found."

    output = [f"Found {total} total results (showing {len(hits)}):\n"]

    for hit in hits:
        doc = hit["_source"]

        # Format throughput and CPU with reasonable precision
        mean_val = doc.get('mean')
        mean_str = f"{mean_val:.2f}" if mean_val is not None else 'N/A'

        cpu_val = doc.get('busy_cpu')
        cpu_str = f"{cpu_val:.1f}" if cpu_val is not None else 'N/A'

        # First line: benchmark, model, NIC, throughput, CPU
        output.append(
            f"• {doc.get('benchmark', 'N/A')} | {doc.get('model', 'N/A')} | "
            f"{doc.get('nic', 'N/A')} | Throughput: {mean_str} {doc.get('unit', '')}, "
            f"CPU: {cpu_str}"
        )

        # Second line: topology, protocol, test_type
        output.append(
            f"  Topology: {doc.get('topology', 'N/A')}, Protocol: {doc.get('protocol', 'N/A')}, "
            f"Test: {doc.get('test_type', 'N/A')}"
        )

        # Third line: arch, kernel, rcos
        output.append(
            f"  Arch: {doc.get('arch', 'N/A')}, Kernel: {doc.get('kernel', 'N/A')}, "
            f"RCOS: {doc.get('rcos', 'N/A')}"
        )

        # Fourth line: performance profile, offload, threads, sizes, CPU count
        size_info = []
        if doc.get('wsize'):
            size_info.append(f"wsize: {doc.get('wsize')}")
        if doc.get('rsize'):
            size_info.append(f"rsize: {doc.get('rsize')}")
        size_str = ", ".join(size_info) if size_info else "N/A"

        output.append(
            f"  Perf: {doc.get('performance_profile', 'N/A')}, Offload: {doc.get('offload', 'N/A')}, "
            f"Threads: {doc.get('threads', 'N/A')}, {size_str}, CPUs: {doc.get('cpu', 'N/A')}"
        )

        # Fifth line: scale parameters if present
        scale_info = []
        if doc.get('pods_per_worker'):
            scale_info.append(f"Pods/Worker: {doc.get('pods_per_worker')}")
        if doc.get('scale_out_factor'):
            scale_info.append(f"Scale: {doc.get('scale_out_factor')}")

        if scale_info:
            output.append(f"  {', '.join(scale_info)}")

        # Last line: batch and timestamp (shortened)
        timestamp = doc.get('@timestamp', 'N/A')
        if timestamp != 'N/A' and len(timestamp) > 19:
            timestamp = timestamp[:19]  # Keep YYYY-MM-DDTHH:MM:SS

        output.append(f"  Batch: {doc.get('batch_id', 'N/A')[:8]}..., Time: {timestamp}")
        output.append("")

    return "\n".join(output)


@mcp.tool()
async def compare_batches(batch_id_1: str, batch_id_2: str) -> str:
    """
    Compare two upload batches to see performance differences.

    Args:
        batch_id_1: First batch UUID
        batch_id_2: Second batch UUID
    """
    async def get_batch_stats(batch_id: str) -> dict:
        query = {
            "size": 0,
            "query": {"term": {"batch_id.keyword": batch_id}},
            "aggs": {
                "avg_throughput": {"avg": {"field": "mean"}},
                "avg_cpu": {"avg": {"field": "busy_cpu"}},
                "count": {"value_count": {"field": "mean"}},
                "by_benchmark": {
                    "terms": {"field": "benchmark"},
                    "aggs": {"avg_throughput": {"avg": {"field": "mean"}}}
                }
            }
        }
        result = await es_request("POST", f"{ES_INDEX}/_search", query)
        return result.get("aggregations", {}) if result else {}

    stats1 = await get_batch_stats(batch_id_1)
    stats2 = await get_batch_stats(batch_id_2)

    if not stats1 or not stats2:
        return "Error: Could not fetch batch statistics"

    count1 = stats1.get("count", {}).get("value", 0)
    count2 = stats2.get("count", {}).get("value", 0)

    if count1 == 0 or count2 == 0:
        return "Error: One or both batches have no data"

    avg_tp1 = stats1.get("avg_throughput", {}).get("value", 0)
    avg_tp2 = stats2.get("avg_throughput", {}).get("value", 0)
    avg_cpu1 = stats1.get("avg_cpu", {}).get("value", 0)
    avg_cpu2 = stats2.get("avg_cpu", {}).get("value", 0)

    diff_pct = ((avg_tp2 - avg_tp1) / avg_tp1 * 100) if avg_tp1 > 0 else 0

    output = [
        f"Batch Comparison",
        f"================",
        f"",
        f"Batch 1 ({batch_id_1[:8]}...):",
        f"  Documents: {count1}",
        f"  Avg Throughput: {avg_tp1:.2f}",
        f"  Avg CPU: {avg_cpu1:.2f}%",
        f"",
        f"Batch 2 ({batch_id_2[:8]}...):",
        f"  Documents: {count2}",
        f"  Avg Throughput: {avg_tp2:.2f}",
        f"  Avg CPU: {avg_cpu2:.2f}%",
        f"",
        f"Performance Change: {diff_pct:+.2f}%",
    ]

    return "\n".join(output)


@mcp.tool()
async def delete_batch(batch_id: str, confirm: str = "no") -> str:
    """
    Delete all documents in a batch. REQUIRES CONFIRMATION.

    Args:
        batch_id: The UUID of the batch to delete
        confirm: Must be exactly "yes" to proceed with deletion
    """
    if confirm != "yes":
        # First show what would be deleted
        count_query = {
            "query": {"term": {"batch_id.keyword": batch_id}}
        }
        result = await es_request("POST", f"{ES_INDEX}/_count", count_query)

        if not result or "error" in result:
            return f"Error: {result.get('error', 'Unknown error')}"

        count = result.get("count", 0)

        return (
            f"WARNING: This will delete {count} documents with batch_id={batch_id}\n"
            f"To confirm deletion, call again with confirm='yes'"
        )

    # Perform deletion
    delete_query = {
        "query": {"term": {"batch_id.keyword": batch_id}}
    }

    result = await es_request("POST", f"{ES_INDEX}/_delete_by_query", delete_query)

    if not result or "error" in result:
        return f"Error: {result.get('error', 'Unknown error')}"

    deleted = result.get("deleted", 0)
    return f"Successfully deleted {deleted} documents from batch {batch_id}"


@mcp.tool()
async def get_index_stats() -> str:
    """Get overall statistics about the Regulus ElasticSearch index."""
    # Get count
    count_result = await es_request("GET", f"{ES_INDEX}/_count")

    # Get aggregations
    agg_query = {
        "size": 0,
        "aggs": {
            "total_batches": {
                "cardinality": {"field": "batch_id.keyword"}
            },
            "benchmarks": {
                "terms": {"field": "benchmark", "size": 10}
            },
            "models": {
                "terms": {"field": "model", "size": 10}
            }
        }
    }

    agg_result = await es_request("POST", f"{ES_INDEX}/_search", agg_query)

    if not count_result or not agg_result:
        return "Error fetching index statistics"

    total_docs = count_result.get("count", 0)
    aggs = agg_result.get("aggregations", {})
    total_batches = aggs.get("total_batches", {}).get("value", 0)
    benchmarks = aggs.get("benchmarks", {}).get("buckets", [])
    models = aggs.get("models", {}).get("buckets", [])

    output = [
        f"Regulus Index Statistics",
        f"========================",
        f"Index: {ES_INDEX}",
        f"Total Documents: {total_docs}",
        f"Total Batches: {total_batches}",
        f"",
        f"Benchmarks:"
    ]

    for b in benchmarks:
        output.append(f"  • {b['key']}: {b['doc_count']} docs")

    output.append("\nModels:")
    for m in models:
        output.append(f"  • {m['key']}: {m['doc_count']} docs")

    return "\n".join(output)


def main():
    """Run the MCP server."""
    import sys

    # Validate configuration
    if not ES_URL:
        print("Error: ES_URL environment variable not set", file=sys.stderr)
        sys.exit(1)

    # Run server with stdio transport
    mcp.run(transport="stdio")


if __name__ == "__main__":
    main()
