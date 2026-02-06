#!/bin/bash
# Script to migrate existing regulus-results index to rollover-enabled index
# This enables automatic index rollover without data deletion (for CCR setup)
#
# PREREQUISITE: Run from regulus root after sourcing bootstrap.sh
#   cd $REGULUS_CHECKOUT
#   source ./bootstrap.sh
#   REPORT/es_integration/reindex_to_rollover_fixed.sh

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
    echo "  REPORT/es_integration/reindex_to_rollover_fixed.sh"
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

# Detect if we're migrating from a rollover index (e.g., regulus-results-000001)
# or from the original non-rollover index (e.g., regulus-results)
if [[ "$ES_INDEX" =~ -[0-9]{6}$ ]]; then
    # Already a rollover index, increment to next number
    BASE_NAME=$(echo "$ES_INDEX" | sed 's/-[0-9]\{6\}$//')
    CURRENT_NUM=$(echo "$ES_INDEX" | grep -o '[0-9]\{6\}$')
    NEXT_NUM=$(printf "%06d" $((10#$CURRENT_NUM + 1)))
    OLD_INDEX="$ES_INDEX"
    NEW_INDEX="${BASE_NAME}-${NEXT_NUM}"
    WRITE_ALIAS="${BASE_NAME}-write"
else
    # Original non-rollover index
    OLD_INDEX="$ES_INDEX"
    NEW_INDEX="${ES_INDEX}-000001"
    WRITE_ALIAS="${ES_INDEX}-write"
fi

TEMP_BACKUP="${OLD_INDEX}-backup-$(date +%s)"

echo "=========================================="
echo "  Regulus Index Migration to Rollover"
echo "=========================================="
echo ""
echo "This script will:"
echo "  1. Backup old index to: $TEMP_BACKUP"
echo "  2. Apply ISM policy (no deletion)"
echo "  3. Apply index template"
echo "  4. Delete old index: $OLD_INDEX"
echo "  5. Create new rollover index: $NEW_INDEX"
echo "  6. Set up write alias: $WRITE_ALIAS -> $NEW_INDEX"
echo "  7. Reindex data from backup"
echo "  8. Verify and cleanup"
echo ""
echo -e "${YELLOW}WARNING: This is a destructive operation!${NC}"
echo ""
read -p "Do you want to continue? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Step 1: Check current index exists and get count
echo ""
echo "Step 1: Checking current index..."
if ! curl -sf "$ES_URL/$OLD_INDEX/_count" > /dev/null 2>&1; then
    echo -e "${RED}✗ ERROR: Index $OLD_INDEX does not exist${NC}"
    exit 1
fi

COUNT=$(curl -s "$ES_URL/$OLD_INDEX/_count" | python3 -c "import sys, json; print(json.load(sys.stdin).get('count', 0))")
echo -e "${GREEN}✓ Current index has $COUNT documents${NC}"

# Step 2: Create backup of old index (reindex to temp name)
echo ""
echo "Step 2: Creating backup: $OLD_INDEX -> $TEMP_BACKUP..."
echo "This may take a while for large indices..."

curl -X POST "$ES_URL/_reindex?wait_for_completion=true" \
    -H 'Content-Type: application/json' \
    -d "{
      \"source\": {\"index\": \"$OLD_INDEX\"},
      \"dest\": {\"index\": \"$TEMP_BACKUP\"}
    }" | python3 -m json.tool

# Refresh backup index to make documents searchable
echo "Refreshing backup index..."
curl -s -X POST "$ES_URL/$TEMP_BACKUP/_refresh" > /dev/null
sleep 2

# Verify backup
BACKUP_COUNT=$(curl -s "$ES_URL/$TEMP_BACKUP/_count" | python3 -c "import sys, json; print(json.load(sys.stdin).get('count', 0))")
if [ "$COUNT" -eq "$BACKUP_COUNT" ]; then
    echo -e "${GREEN}✓ Backup created: $BACKUP_COUNT documents${NC}"
else
    echo -e "${RED}✗ ERROR: Backup count mismatch!${NC}"
    echo "  Original: $COUNT documents"
    echo "  Backup: $BACKUP_COUNT documents"
    exit 1
fi

# Step 3: Apply ISM policy (no deletion)
echo ""
echo "Step 3: Applying ISM policy (no deletion)..."
cd "$REPORT_DIR"
make es-ilm-policy-no-delete
echo -e "${GREEN}✓ ISM policy applied${NC}"

# Step 4: Apply index template
echo ""
echo "Step 4: Applying index template..."
make es-template
echo -e "${GREEN}✓ Index template applied${NC}"

# Step 5: Delete old index (CRITICAL: Must happen BEFORE creating alias)
echo ""
echo "Step 5: Deleting old index: $OLD_INDEX..."
echo -e "${YELLOW}WARNING: About to delete $OLD_INDEX (backup exists at $TEMP_BACKUP)${NC}"
read -p "Confirm deletion? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted. Cleaning up backup..."
    curl -X DELETE "$ES_URL/$TEMP_BACKUP"
    exit 1
fi

curl -s -X DELETE "$ES_URL/$OLD_INDEX" > /dev/null
echo -e "${GREEN}✓ Old index deleted${NC}"

# Wait for deletion to propagate
sleep 2

# Step 6: Create new rollover index with alias and rollover_alias setting
echo ""
echo "Step 6: Creating rollover index: $NEW_INDEX with alias $WRITE_ALIAS..."

# FIXED: Create index with both alias AND rollover_alias setting
curl -X PUT "$ES_URL/$NEW_INDEX" \
    -H 'Content-Type: application/json' \
    -d "{
      \"settings\": {
        \"index\": {
          \"plugins.index_state_management.rollover_alias\": \"$WRITE_ALIAS\"
        }
      },
      \"aliases\": {
        \"$WRITE_ALIAS\": {
          \"is_write_index\": true
        }
      }
    }" | python3 -m json.tool

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ ERROR: Failed to create rollover index${NC}"
    echo "Restoring from backup..."
    curl -X POST "$ES_URL/_reindex?wait_for_completion=true" \
        -H 'Content-Type: application/json' \
        -d "{
          \"source\": {\"index\": \"$TEMP_BACKUP\"},
          \"dest\": {\"index\": \"$OLD_INDEX\"}
        }"
    exit 1
fi

echo -e "${GREEN}✓ Rollover index created with alias${NC}"

# Step 7: Reindex data from backup to new index
echo ""
echo "Step 7: Reindexing $COUNT documents from $TEMP_BACKUP to $NEW_INDEX..."
echo "This may take a while..."

curl -X POST "$ES_URL/_reindex?wait_for_completion=true" \
    -H 'Content-Type: application/json' \
    -d "{
      \"source\": {\"index\": \"$TEMP_BACKUP\"},
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
    echo -e "${YELLOW}⚠ Document count mismatch - trying one more refresh...${NC}"
    echo "  Expected: $COUNT documents"
    echo "  Found: $NEW_COUNT documents"

    curl -s -X POST "$ES_URL/$NEW_INDEX/_refresh" > /dev/null
    sleep 3
    NEW_COUNT=$(curl -s "$ES_URL/$NEW_INDEX/_count" | python3 -c "import sys, json; print(json.load(sys.stdin).get('count', 0))")

    if [ "$COUNT" -eq "$NEW_COUNT" ]; then
        echo -e "${GREEN}✓ Reindex successful after retry: $NEW_COUNT documents${NC}"
    else
        echo -e "${RED}✗ ERROR: Still showing $NEW_COUNT documents${NC}"
        echo "Backup is preserved at $TEMP_BACKUP - please investigate manually"
        exit 1
    fi
fi

# Step 8: Verify ISM policy and alias setup
echo ""
echo "Step 8: Verifying rollover configuration..."

# Check alias
ALIAS_CHECK=$(curl -s "$ES_URL/$NEW_INDEX/_alias" | python3 -c "import sys, json; d=json.load(sys.stdin); print(len(d.get('$NEW_INDEX', {}).get('aliases', {})))")
if [ "$ALIAS_CHECK" -gt 0 ]; then
    echo -e "${GREEN}✓ Alias configured${NC}"
else
    echo -e "${RED}✗ WARNING: No alias found!${NC}"
fi

# Check ISM policy status
ISM_STATUS=$(curl -s "$ES_URL/_plugins/_ism/explain/$NEW_INDEX" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('$NEW_INDEX', {}).get('info', {}).get('message', 'OK'))")
if [ "$ISM_STATUS" == "OK" ]; then
    echo -e "${GREEN}✓ ISM policy working correctly${NC}"
else
    echo -e "${YELLOW}⚠ ISM status: $ISM_STATUS${NC}"
fi

# Step 9: Cleanup backup
echo ""
echo "Step 9: Cleanup backup index..."
read -p "Delete backup index $TEMP_BACKUP? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    curl -s -X DELETE "$ES_URL/$TEMP_BACKUP" > /dev/null
    echo -e "${GREEN}✓ Backup deleted${NC}"
else
    echo -e "${YELLOW}⚠ Backup preserved at $TEMP_BACKUP${NC}"
    echo "Delete it manually when ready: curl -X DELETE '$ES_URL/$TEMP_BACKUP'"
fi

# Step 10: Final verification and summary
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
echo "  Warm (7-30d): Read-only, force-merged, optimized"
echo "  Cold (30d+): Reduced replicas to 0"
echo "  Delete: NONE (data retained permanently for CCR)"
echo ""
echo -e "${GREEN}✓ Future uploads should use: $WRITE_ALIAS${NC}"
echo ""
echo "Next rollover will create: ${ES_INDEX}-000002"
echo ""
echo "Verify with:"
echo "  curl '$ES_URL/_cat/indices/regulus*?v'"
echo "  curl '$ES_URL/_cat/aliases/$WRITE_ALIAS?v'"
echo "  curl '$ES_URL/_plugins/_ism/explain/$NEW_INDEX' | python3 -m json.tool"
echo ""
