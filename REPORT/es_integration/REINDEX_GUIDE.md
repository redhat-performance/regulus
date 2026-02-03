# Reindex Guide: Migrate to Rollover-Enabled Index

## Overview

This guide walks you through migrating your existing `regulus-results` index to a rollover-enabled setup with **no data deletion** (preparing for CCR).

## What You'll Get

**Before Migration:**
```
regulus-results (single index, grows forever)
└── 475 documents, no lifecycle management
```

**After Migration:**
```
regulus-results-000001 (rollover index)
├── 475 documents migrated
├── Rollover at 50GB/30d/1M docs → creates -000002
├── Hot phase (0-7d): Active indexing
├── Warm phase (7-30d): Read-only, optimized
├── Cold phase (30d+): Reduced replicas
└── NO DELETION (data kept permanently for CCR)

regulus-results (write alias → -000001)
└── Future uploads automatically go to current rollover index
```

## Prerequisites

1. **Backup your data** (optional but recommended):
   ```bash
   # Take snapshot or export current data
   curl -s "$ES_URL/regulus-results/_search?size=10000" > backup.json
   ```

2. **Verify current index**:
   ```bash
   cd $REG_ROOT/REPORT
   make es-index-stats
   ```

3. **Set ES_URL** in `lab.config`:
   ```bash
   export ES_URL='https://username:password@your-es-host.com'
   ```

## Migration Options

### Option 1: Automated Script (Recommended)

Run the automated reindex script:

```bash
cd $REG_ROOT/REPORT/es_integration
./reindex_to_rollover.sh
```

**What it does:**
1. ✓ Applies ILM policy (no deletion)
2. ✓ Applies index template
3. ✓ Creates `regulus-results-000001`
4. ✓ Reindexes all data from `regulus-results`
5. ✓ Verifies document count
6. ✓ Deletes old index (with confirmation)
7. ✓ Sets up write alias

**Time:** ~1-2 minutes for 475 documents

### Option 2: Manual Steps

If you prefer manual control:

#### Step 1: Apply ILM Policy (No Deletion)

```bash
cd $REG_ROOT/REPORT
make es-ilm-policy-no-delete
```

**Verify:**
```bash
make es-ilm-info
```

#### Step 2: Apply Index Template

```bash
make es-template
```

**Verify:**
```bash
make es-template-info
```

#### Step 3: Create Rollover Index

```bash
# Create regulus-results-000001 with write alias
curl -X PUT "$ES_URL/regulus-results-000001" \
    -H 'Content-Type: application/json' \
    -d '{"aliases": {"regulus-results": {"is_write_index": true}}}'
```

**Verify:**
```bash
curl -s "$ES_URL/_cat/aliases/regulus-results?v"
```

Should show:
```
alias            index                  is_write_index
regulus-results  regulus-results-000001 true
```

#### Step 4: Reindex Data

```bash
# Reindex from old to new
curl -X POST "$ES_URL/_reindex?wait_for_completion=true" \
    -H 'Content-Type: application/json' \
    -d '{
      "source": {"index": "regulus-results"},
      "dest": {"index": "regulus-results-000001"}
    }'
```

**Verify document count:**
```bash
# Old index count
curl -s "$ES_URL/regulus-results/_count"

# New index count
curl -s "$ES_URL/regulus-results-000001/_count"

# Should match!
```

#### Step 5: Delete Old Index

⚠️ **WARNING: Destructive operation! Verify counts match first!**

```bash
# Delete old index (cannot undo!)
curl -X DELETE "$ES_URL/regulus-results"
```

#### Step 6: Verify Setup

```bash
cd $REG_ROOT/REPORT

# Check index stats
make es-index-stats

# Check lifecycle phase
make es-ilm-explain

# List indices
curl -s "$ES_URL/_cat/indices/regulus-*?v"
```

## Post-Migration

### Upload New Data

Future uploads automatically use the rollover index:

```bash
cd $REG_ROOT/REPORT
make es-upload
```

Data goes to `regulus-results` alias → which points to `regulus-results-000001`

### Monitor Rollover

Check when next rollover will happen:

```bash
make es-ilm-explain
```

Index will rollover when it hits:
- 50 GB primary shard size, OR
- 30 days old, OR
- 1 million documents

### When Rollover Happens

Automatically:
```
regulus-results-000001 (full, moves to warm phase)
regulus-results-000002 (created, becomes write index)
regulus-results (alias → now points to -000002)
```

## Future: Enable Data Deletion (for CCR)

When you're ready to enable CCR and want to delete old data:

### Option A: Update Existing Policy

```bash
cd $REG_ROOT/REPORT
make es-ilm-policy  # Applies policy with 90-day deletion
```

This updates `regulus-ism-policy` to include delete phase.

### Option B: Manual Policy Update

Edit the policy via API:

```bash
# Add delete state to existing policy
curl -X PUT "$ES_URL/_plugins/_ism/policies/regulus-ism-policy" \
    -H 'Content-Type: application/json' \
    -d @REPORT/es_integration/opensearch_ism_policy.json
```

## Troubleshooting

### Reindex Failed

**Problem:** Document count doesn't match after reindex

**Solution:**
```bash
# Check for errors in reindex response
curl -X POST "$ES_URL/_reindex" \
    -H 'Content-Type: application/json' \
    -d '{
      "source": {"index": "regulus-results"},
      "dest": {"index": "regulus-results-000001"}
    }' | python3 -m json.tool

# Look for "failures" field
```

### Old Index Still Exists

**Problem:** Hesitant to delete old index

**Solution:** Keep both temporarily:
- Old index: `regulus-results` (static snapshot)
- New index: `regulus-results-000001` (active)
- Write alias points to new index
- Delete old when comfortable (days or weeks later)

### Rollover Not Working

**Problem:** Index not rolling over at expected size

**Solution:** Check ISM policy is attached:
```bash
make es-ilm-explain
```

Should show:
```json
{
  "regulus-results-000001": {
    "index.plugins.index_state_management.policy_id": "regulus-ism-policy"
  }
}
```

If null, manually attach:
```bash
curl -X POST "$ES_URL/_plugins/_ism/add/regulus-results-000001" \
    -H 'Content-Type: application/json' \
    -d '{"policy_id": "regulus-ism-policy"}'
```

## Rollback Plan

If something goes wrong during migration:

1. **Before deleting old index:**
   - Keep `regulus-results` (old index)
   - Delete `regulus-results-000001` (new index)
   - Remove alias if created

2. **After deleting old index:**
   - Restore from backup snapshot
   - Or accept data loss and start fresh

## Summary

**Safe Migration Path:**
1. Run `./reindex_to_rollover.sh`
2. Verify counts match
3. Test upload with `make es-upload`
4. Monitor with `make es-index-stats`
5. Later enable deletion when CCR is ready

**Benefits:**
- ✅ Automatic rollover at 50GB/30d/1M docs
- ✅ Data optimization (warm/cold phases)
- ✅ No data deletion (ready for CCR)
- ✅ Future-proof for scaling
