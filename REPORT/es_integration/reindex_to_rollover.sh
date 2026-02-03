#!/bin/bash
# Script to migrate existing regulus-results index to rollover-enabled index
# This enables automatic index rollover without data deletion (for CCR setup)
#
# PREREQUISITE: Run from regulus root after sourcing bootstrap.sh
#   cd $REGULUS_CHECKOUT
#   source ./bootstrap.sh
#   REPORT/es_integration/reindex_to_rollover.sh

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check REG_ROOT is set
if [ -z "${REG_ROOT:-}" ]; then
    echo -e "${RED}ERROR: REG_ROOT is not set${NC}"
    echo ""
    echo "You must run this script from regulus root after sourcing bootstrap.sh:"
    echo ""
    echo "  cd \$REGULUS_CHECKOUT"
    echo "  source ./bootstrap.sh"
    echo "  REPORT/es_integration/reindex_to_rollover.sh"
    echo ""
    exit 1
fi

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# ES_URL should be set from lab.config via bootstrap.sh
if [ -z "${ES_URL:-}" ]; then
    echo -e "${RED}ERROR: ES_URL not set${NC}"
    echo ""
    echo "Ensure ES_URL is defined in lab.config, then re-run:"
    echo "  source ./bootstrap.sh"
    echo ""
    exit 1
fi

ES_INDEX="${ES_INDEX:-regulus-results}"
OLD_INDEX="$ES_INDEX"
NEW_INDEX="${ES_INDEX}-000001"
WRITE_ALIAS="$ES_INDEX"

echo "=========================================="
echo "  Regulus Index Migration to Rollover"
echo "=========================================="
echo ""
echo "This script will:"
echo "  1. Apply ILM policy (no deletion)"
echo "  2. Apply index template"
echo "  3. Create new rollover index: $NEW_INDEX"
echo "  4. Reindex data from: $OLD_INDEX"
echo "  5. Delete old index: $OLD_INDEX"
echo "  6. Set up write alias: $WRITE_ALIAS -> $NEW_INDEX"
echo ""
echo -e "${YELLOW}WARNING: This is a destructive operation!${NC}"
echo ""
read -p "Do you want to continue? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Step 1: Check current index exists
echo ""
echo "Step 1: Checking current index..."
COUNT=$(curl -s "$ES_URL/$OLD_INDEX/_count" | python3 -c "import sys, json; print(json.load(sys.stdin).get('count', 0))")
echo -e "${GREEN}✓ Current index has $COUNT documents${NC}"

# Step 2: Apply ILM policy (no deletion)
echo ""
echo "Step 2: Applying ILM policy (no deletion)..."
cd "$REPORT_DIR"
make es-ilm-policy-no-delete
echo -e "${GREEN}✓ ILM policy applied${NC}"

# Step 3: Apply index template
echo ""
echo "Step 3: Applying index template..."
make es-template
echo -e "${GREEN}✓ Index template applied${NC}"

# Step 4: Create new rollover index
echo ""
echo "Step 4: Creating rollover index: $NEW_INDEX..."
curl -X PUT "$ES_URL/$NEW_INDEX" \
    -H 'Content-Type: application/json' \
    -d "{\"aliases\": {\"$WRITE_ALIAS\": {\"is_write_index\": true}}}" | python3 -m json.tool
echo -e "${GREEN}✓ Rollover index created${NC}"

# Step 5: Reindex data
echo ""
echo "Step 5: Reindexing $COUNT documents from $OLD_INDEX to $NEW_INDEX..."
echo "This may take a while..."
curl -X POST "$ES_URL/_reindex?wait_for_completion=true" \
    -H 'Content-Type: application/json' \
    -d "{
      \"source\": {\"index\": \"$OLD_INDEX\"},
      \"dest\": {\"index\": \"$NEW_INDEX\"}
    }" | python3 -m json.tool

# Refresh the new index to ensure all documents are searchable
echo "Refreshing index..."
curl -s -X POST "$ES_URL/$NEW_INDEX/_refresh" > /dev/null

# Wait a moment for refresh to complete
sleep 2

# Verify count
NEW_COUNT=$(curl -s "$ES_URL/$NEW_INDEX/_count" | python3 -c "import sys, json; print(json.load(sys.stdin).get('count', 0))")
if [ "$COUNT" -eq "$NEW_COUNT" ]; then
    echo -e "${GREEN}✓ Reindex successful: $NEW_COUNT documents${NC}"
else
    echo -e "${RED}✗ ERROR: Document count mismatch!${NC}"
    echo "  Old index: $COUNT documents"
    echo "  New index: $NEW_COUNT documents"
    echo ""
    echo "Reindex response showed 'created': 475, so data may be there."
    echo "Trying one more refresh and count..."
    curl -s -X POST "$ES_URL/$NEW_INDEX/_refresh" > /dev/null
    sleep 3
    NEW_COUNT=$(curl -s "$ES_URL/$NEW_INDEX/_count" | python3 -c "import sys, json; print(json.load(sys.stdin).get('count', 0))")
    if [ "$COUNT" -eq "$NEW_COUNT" ]; then
        echo -e "${GREEN}✓ Reindex successful after retry: $NEW_COUNT documents${NC}"
    else
        echo -e "${RED}Still showing: $NEW_COUNT documents${NC}"
        echo "Aborting - please investigate manually"
        exit 1
    fi
fi

# Step 6: Delete old index
echo ""
echo "Step 6: Deleting old index: $OLD_INDEX..."
echo -e "${YELLOW}WARNING: About to delete $OLD_INDEX${NC}"
read -p "Confirm deletion? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted. Old index NOT deleted."
    echo "You now have both indexes. Delete $OLD_INDEX manually when ready."
    exit 0
fi

curl -X DELETE "$ES_URL/$OLD_INDEX"
echo -e "${GREEN}✓ Old index deleted${NC}"

# Step 7: Verify setup
echo ""
echo "=========================================="
echo "  Migration Complete!"
echo "=========================================="
echo ""
echo "Index setup:"
echo "  Write index: $NEW_INDEX"
echo "  Write alias: $WRITE_ALIAS -> $NEW_INDEX"
echo "  Documents: $NEW_COUNT"
echo ""
echo "Lifecycle phases:"
echo "  Hot (0-7d): Active indexing, rollover at 50GB/30d/1M docs"
echo "  Warm (7-30d): Read-only, optimized"
echo "  Cold (30d+): Reduced replicas"
echo "  Delete: NONE (data retained permanently for CCR)"
echo ""
echo -e "${GREEN}Future uploads will automatically use the rollover index!${NC}"
echo ""
echo "Verify with:"
echo "  make es-index-stats"
echo "  make es-ilm-explain"
