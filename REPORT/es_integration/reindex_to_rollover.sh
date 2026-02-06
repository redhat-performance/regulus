#!/bin/bash
# Script to migrate existing regulus-results index to rollover-enabled index
# This enables automatic index rollover without data deletion (for CCR setup)
#
# The script auto-detects the current write index from the write alias,
# so no manual configuration is needed.
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
    echo "  REPORT/es_integration/reindex_to_rollover_fixed.sh"
    echo ""
    exit 1
fi

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source lab.config to get ES_URL
if [ -f "$REG_ROOT/lab.config" ]; then
    source "$REG_ROOT/lab.config"
fi

# Verify ES_URL is set
if [ -z "${ES_URL:-}" ]; then
    echo -e "${RED}ERROR: ES_URL not set${NC}"
    echo ""
    echo "ES_URL must be defined in $REG_ROOT/lab.config"
    echo ""
    exit 1
fi

# Auto-detect current write index from write alias (consistent with es_config.py)
WRITE_ALIAS="regulus-results-write"
BASE_NAME="regulus-results"

# Try to find the current index from the write alias
echo "Detecting current write index from alias: $WRITE_ALIAS..."
ALIAS_RESULT=$(curl -s "$ES_URL/_cat/aliases/$WRITE_ALIAS?h=index")

if [ -n "$ALIAS_RESULT" ] && [ "$ALIAS_RESULT" != "404" ]; then
    # Alias exists, get the current index
    OLD_INDEX="$ALIAS_RESULT"
    echo "Found current write index: $OLD_INDEX"

    # Extract index number and calculate next
    if [[ "$OLD_INDEX" =~ -([0-9]{6})$ ]]; then
        CURRENT_NUM="${BASH_REMATCH[1]}"
        NEXT_NUM=$(printf "%06d" $((10#$CURRENT_NUM + 1)))
        NEW_INDEX="${BASE_NAME}-${NEXT_NUM}"
    else
        echo -e "${RED}ERROR: Current index '$OLD_INDEX' doesn't match rollover pattern${NC}"
        exit 1
    fi
else
    # Alias doesn't exist, check for non-rollover index
    echo "Write alias not found, checking for legacy index: $BASE_NAME..."
    INDEX_CHECK=$(curl -s "$ES_URL/_cat/indices/$BASE_NAME?h=index")

    if [ -n "$INDEX_CHECK" ] && [ "$INDEX_CHECK" != "404" ]; then
        # Legacy non-rollover index exists
        OLD_INDEX="$BASE_NAME"
        NEW_INDEX="${BASE_NAME}-000001"
        echo "Found legacy index: $OLD_INDEX"
    else
        echo -e "${RED}ERROR: No index found to migrate${NC}"
        echo "Expected either:"
        echo "  - Write alias: $WRITE_ALIAS"
        echo "  - Legacy index: $BASE_NAME"
        exit 1
    fi
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
echo "  7. Attach ISM policy to new index"
echo "  8. Reindex data from backup"
echo "  9. Verify and cleanup"
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

# Step 7: Attach ISM policy to new index
echo ""
echo "Step 7: Attaching ISM policy to new index..."
POLICY_ATTACH_RESULT=$(curl -s -X POST "$ES_URL/_plugins/_ism/add/$NEW_INDEX" \
    -H 'Content-Type: application/json' \
    -d "{\"policy_id\": \"regulus-ism-policy\"}")

POLICY_ATTACH_SUCCESS=$(echo "$POLICY_ATTACH_RESULT" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('updated_indices', 0))")

if [ "$POLICY_ATTACH_SUCCESS" -eq 1 ]; then
    echo -e "${GREEN}✓ ISM policy attached to new index${NC}"
else
    echo -e "${YELLOW}⚠ WARNING: Failed to attach ISM policy${NC}"
    echo "$POLICY_ATTACH_RESULT"
    echo "You may need to attach it manually after migration"
fi

# Step 8: Reindex data from backup to new index
echo ""
echo "Step 8: Reindexing $COUNT documents from $TEMP_BACKUP to $NEW_INDEX..."
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

# Step 9: Verify ISM policy and alias setup
echo ""
echo "Step 9: Verifying rollover configuration..."

# Check alias
ALIAS_CHECK=$(curl -s "$ES_URL/$NEW_INDEX/_alias" | python3 -c "import sys, json; d=json.load(sys.stdin); print(len(d.get('$NEW_INDEX', {}).get('aliases', {})))")
if [ "$ALIAS_CHECK" -gt 0 ]; then
    echo -e "${GREEN}✓ Alias configured${NC}"
else
    echo -e "${RED}✗ WARNING: No alias found!${NC}"
fi

# Check ISM policy status
echo "Checking ISM policy attachment..."
ISM_EXPLAIN=$(curl -s "$ES_URL/_plugins/_ism/explain/$NEW_INDEX")
ISM_POLICY_ID=$(echo "$ISM_EXPLAIN" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('$NEW_INDEX', {}).get('policy_id', 'null'))")
ISM_ENABLED=$(echo "$ISM_EXPLAIN" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('$NEW_INDEX', {}).get('enabled', 'null'))")

if [ "$ISM_POLICY_ID" != "null" ] && [ "$ISM_POLICY_ID" != "None" ]; then
    echo -e "${GREEN}✓ ISM policy attached: $ISM_POLICY_ID${NC}"

    # Check if state is initialized (may take a few minutes)
    ISM_STATE=$(echo "$ISM_EXPLAIN" | python3 -c "import sys, json; d=json.load(sys.stdin); state=d.get('$NEW_INDEX', {}).get('state'); print(state.get('name') if state else 'initializing')")
    if [ "$ISM_STATE" != "initializing" ]; then
        echo -e "${GREEN}✓ ISM state initialized: $ISM_STATE${NC}"
    else
        echo -e "${YELLOW}⚠ ISM state initializing (will be ready in ~5 minutes)${NC}"
    fi
else
    echo -e "${RED}✗ ERROR: ISM policy NOT attached!${NC}"
    echo "  You'll need to attach it manually"
fi

# Step 10: Cleanup backup
echo ""
echo "Step 10: Cleanup backup index..."
read -p "Delete backup index $TEMP_BACKUP? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    curl -s -X DELETE "$ES_URL/$TEMP_BACKUP" > /dev/null
    echo -e "${GREEN}✓ Backup deleted${NC}"
else
    echo -e "${YELLOW}⚠ Backup preserved at $TEMP_BACKUP${NC}"
    echo "Delete it manually when ready: curl -X DELETE '$ES_URL/$TEMP_BACKUP'"
fi

# Step 11: Final verification and summary
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
echo "  Hot: Active indexing, rollover at 500MB/30d/5k docs"
echo "  Warm (1h after rollover): Read-only, force-merged, optimized"
echo "  Replicated (7d): Reduced replicas to 0"
echo "  Delete: NONE (data retained permanently)"
echo ""
echo -e "${GREEN}✓ Future uploads should use: $WRITE_ALIAS${NC}"
echo ""
# Calculate next rollover index number
NEXT_ROLLOVER_NUM=$(printf "%06d" $((10#$NEXT_NUM + 1)))
echo "Next rollover will create: ${BASE_NAME}-${NEXT_ROLLOVER_NUM}"
echo ""
echo "ISM Policy Status:"
echo "  Policy: regulus-ism-policy (attached)"
if [ "$ISM_STATE" != "initializing" ]; then
    echo "  State: $ISM_STATE (active)"
else
    echo "  State: Initializing (~5 min wait)"
    echo "  NOTE: ISM will activate on next manager cycle"
fi
echo ""
echo "Verify with:"
echo "  curl '$ES_URL/_cat/indices/regulus*?v'"
echo "  curl '$ES_URL/_cat/aliases/$WRITE_ALIAS?v'"
echo "  curl '$ES_URL/_plugins/_ism/explain/$NEW_INDEX' | python3 -m json.tool"
echo ""
