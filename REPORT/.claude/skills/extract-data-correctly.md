# Extract Data Correctly from Reports

**CRITICAL**: Properly extract fields from report.json files by checking both `common_params` and `unique_params`.

## The Problem We've Encountered Multiple Times

When processing report.json files, fields can be located in TWO places:
1. **`common_params`** - Parameters that apply to all iterations in a test run
2. **`unique_params`** - Parameters specific to each iteration

**If you only check one location, you'll miss data!** This has caused errors multiple times.

## Source Code Reference

See `dashboard/data_loader.py` lines 344-352:

```python
# test-type (traffic profile: stream, rr, crr, rtpe) can be in either unique_params or common_params
test_type=unique_params.get('test-type') or common_params.get('test-type'),

# protocol can be in either common_params or unique_params
protocol=common_params.get('protocol') or unique_params.get('protocol'),

# nthreads can be in either unique_params or common_params
threads=self._parse_int(unique_params.get('nthreads') or common_params.get('nthreads')),

# wsize and rsize can be in either unique_params or common_params
wsize=self._parse_int(unique_params.get('wsize') or common_params.get('wsize')),
rsize=self._parse_int(unique_params.get('rsize') or common_params.get('rsize')),
```

## Report.json Structure

```json
{
  "runs": [
    {
      "common_params": {
        "protocol": "tcp",
        "test-type": "stream",
        "topology": "internode"
      },
      "iterations": [
        {
          "iteration_id": "...",
          "unique_params": {
            "nthreads": 32,
            "wsize": 134144
          },
          "results": {
            "mean": 314.08,
            "busy_cpu": 25.99
          }
        }
      ]
    }
  ]
}
```

## Fields That Can Be in EITHER Location

Always check **BOTH** `unique_params` and `common_params` for:

### Test Configuration
- `test-type` (stream, rr, crr)
- `protocol` (tcp, udp)
- `nthreads` (number of threads)
- `wsize` (write/window size)
- `rsize` (read size)
- `topology` (internode, intranode)

### Infrastructure Parameters
Some fields might also appear in either location depending on how the test was configured.

## Correct Extraction Pattern

**ALWAYS use this pattern when extracting data:**

```python
# Extract common_params and unique_params first
common_params = file_result.get('common_params', {})
if not isinstance(common_params, dict):
    common_params = {}

unique_params = iteration.get('unique_params', {})
if not isinstance(unique_params, dict):
    unique_params = {}

# Then extract fields checking BOTH locations (unique first, then common)
test_type = unique_params.get('test-type') or common_params.get('test-type')
protocol = common_params.get('protocol') or unique_params.get('protocol')
threads = unique_params.get('nthreads') or common_params.get('nthreads')
wsize = unique_params.get('wsize') or common_params.get('wsize')
```

## Why This Order?

The pattern is:
```python
unique_params.get('field') or common_params.get('field')
```

OR

```python
common_params.get('field') or unique_params.get('field')
```

**Strategy**: Try the more specific location first (unique_params for iteration-specific values, common_params for run-wide values), then fall back to the other.

## Fields ONLY in Results

These fields are NOT in params, they're in the `results` section of each iteration:

- `mean` - Throughput value
- `min` - Minimum value
- `max` - Maximum value
- `stddev` - Standard deviation
- `stddevpct` - Standard deviation percentage
- `unit` - Units (Gbps, transactions-sec, etc.)
- `busy_cpu` - CPU consumption metric
- `samples_count` - Number of samples

## After Flattening to OpenSearch

Once data is flattened and uploaded to OpenSearch (via `flatten_to_es.py`), ALL fields are at the top level of `_source`:

```json
{
  "_source": {
    "test_type": "stream",
    "protocol": "tcp",
    "threads": 32,
    "wsize": 134144,
    "mean": 314.08,
    "busy_cpu": 25.99,
    ...
  }
}
```

**No nested structures in OpenSearch** - everything is flattened.

## Common Mistakes to Avoid

1. ❌ Only checking `unique_params`
2. ❌ Only checking `common_params`
3. ❌ Assuming field location is consistent across all reports
4. ❌ Not validating that extracted value is not None

## Best Practice

When writing code to process reports:

1. **Load both dictionaries first**
2. **Use the fallback pattern** for every field that could be in either location
3. **Validate extracted values** before using them
4. **Document which fields you're extracting** and from where

## Real Example That Caused Issues

We had cases where:
- Some reports had `protocol` in `common_params` (applies to all iterations)
- Other reports had `protocol` in `unique_params` (varies per iteration)

If we only checked one location, we'd get `None` and miss the data entirely, causing incomplete comparisons.

## Summary

**Golden Rule**: Always check BOTH `common_params` AND `unique_params` when extracting test configuration fields from report.json files. Use the pattern:

```python
value = unique_params.get('field') or common_params.get('field')
```

This prevents data loss and ensures complete extraction.
