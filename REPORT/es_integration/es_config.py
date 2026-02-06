"""
ElasticSearch Configuration for Regulus

This module provides centralized configuration for all ES-related tools.
All Python scripts that interact with ElasticSearch should import from here.

Configuration priority:
  1. Environment variables (set in lab.config via bootstrap.sh)
  2. Defaults defined here

Usage:
    from es_integration.es_config import ES_URL, ES_INDEX, ES_WRITE_ALIAS
"""

import os

# ElasticSearch server URL
# Set in lab.config or via environment
ES_URL = os.getenv("ES_URL", "http://localhost:9200")

# ES_INDEX: Pattern for querying data across all rollover indices
# Regulus uses rollover indices with ISM (Index State Management):
#   regulus-results-000001, regulus-results-000002, etc.
# The wildcard pattern ensures queries span all indices.
# DO NOT CHANGE unless you understand rollover index architecture.
ES_INDEX = os.getenv("ES_INDEX", "regulus-results-*")

# ES_WRITE_ALIAS: Alias for uploading new data
# Always points to the current "hot" index for writes.
# Upload tools should use this, not the direct index name.
ES_WRITE_ALIAS = os.getenv("ES_WRITE_ALIAS", "regulus-results-write")

# Display configuration (for debugging)
def print_config():
    """Print current ES configuration"""
    print(f"ES Configuration:")
    print(f"  ES_URL:         {ES_URL}")
    print(f"  ES_INDEX:       {ES_INDEX} (query pattern)")
    print(f"  ES_WRITE_ALIAS: {ES_WRITE_ALIAS} (upload target)")

if __name__ == "__main__":
    print_config()
