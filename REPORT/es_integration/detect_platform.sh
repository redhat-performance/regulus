#!/bin/bash
# Auto-detection script for ElasticSearch vs OpenSearch
# Returns platform type and appropriate API endpoints
#
# REQUIRED environment variables (must be set by caller):
#   ES_URL - Complete ElasticSearch/OpenSearch URL with embedded credentials
#            Format: protocol://[user:password@]host:port
#            Examples:
#              https://admin:secret@search-example.us-west-2.es.amazonaws.com
#              http://localhost:9200
#
# All ES_URL value must be determined completely outside REPORT/ and passed in.

# Validate that ES_URL is set
if [ -z "$ES_URL" ]; then
    echo "ERROR: ES_URL environment variable must be set" >&2
    exit 1
fi

# Query the root endpoint to get version info
RESPONSE=$(curl -s "$ES_URL/" 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$RESPONSE" ]; then
    echo "ERROR: Cannot connect to ElasticSearch/OpenSearch using ES_URL" >&2
    exit 1
fi

# Detect platform based on response
# OpenSearch can be detected by either: distribution field OR "The OpenSearch Project" in tagline
if echo "$RESPONSE" | grep -q '"distribution".*:.*"opensearch"'; then
    PLATFORM="opensearch"
    VERSION=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('version', {}).get('number', 'unknown'))" 2>/dev/null)
elif echo "$RESPONSE" | grep -q "The OpenSearch Project"; then
    PLATFORM="opensearch"
    VERSION=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('version', {}).get('number', 'unknown'))" 2>/dev/null)
elif echo "$RESPONSE" | grep -q '"tagline".*:.*"You Know, for Search"'; then
    PLATFORM="elasticsearch"
    VERSION=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('version', {}).get('number', 'unknown'))" 2>/dev/null)
else
    echo "ERROR: Unknown platform" >&2
    exit 1
fi

# Set platform-specific paths
case $PLATFORM in
    elasticsearch)
        POLICY_ENDPOINT="/_ilm/policy"
        POLICY_FILE="es_ilm_policy.json"
        POLICY_NAME="regulus-ilm-policy"
        POLICY_EXPLAIN_PREFIX=""
        POLICY_EXPLAIN_SUFFIX="/_ilm/explain"
        TEMPLATE_FILE="es_mapping_template.json"
        ;;
    opensearch)
        POLICY_ENDPOINT="/_plugins/_ism/policies"
        POLICY_FILE="opensearch_ism_policy.json"
        POLICY_NAME="regulus-ism-policy"
        POLICY_EXPLAIN_PREFIX="/_plugins/_ism/explain/"
        POLICY_EXPLAIN_SUFFIX=""
        TEMPLATE_FILE="opensearch_mapping_template.json"
        ;;
esac

# Export variables for use in calling scripts
cat <<EOF
PLATFORM=$PLATFORM
VERSION=$VERSION
POLICY_ENDPOINT=$POLICY_ENDPOINT
POLICY_FILE=$POLICY_FILE
POLICY_NAME=$POLICY_NAME
POLICY_EXPLAIN_PREFIX=$POLICY_EXPLAIN_PREFIX
POLICY_EXPLAIN_SUFFIX=$POLICY_EXPLAIN_SUFFIX
TEMPLATE_FILE=$TEMPLATE_FILE
EOF
