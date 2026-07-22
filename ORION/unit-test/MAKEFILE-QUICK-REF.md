# Makefile Quick Reference

Quick reference for all `make` targets in the unit-test directory.

## Quick Start

```bash
cd unit-test

# See all available targets
make help

# Complete workflow in one command
make full-cycle

# Practice cycle (generate → index → pull)
make practice-cycle

# Clean everything and start fresh
make reset
```

## Common Commands

### Basic Workflow

```bash
make generate      # Generate mock data (240 docs)
make convert       # Convert to NDJSON bulk format
make index         # Index to OpenSearch
make pull          # Pull from OpenSearch
make test          # Run Orion regression test
```

### Complete Workflows

```bash
make full-cycle    # generate → convert → index → verify
make practice-cycle # full-cycle + pull
make round-trip    # full-cycle + pull + reindex
```

### Exercises (Learn Step-by-Step)

```bash
make exercise1     # Generate and inspect
make exercise2     # Generate → Convert → Index
make exercise3     # Full cycle with pull
```

### Cleanup

```bash
make clean         # Clean local files
make clean-index   # Delete OpenSearch index
make clean-all     # Clean files + indices
make reset         # Complete reset
```

## All Targets by Category

### Step 1: Generate

| Target | Description |
|--------|-------------|
| `make generate` | Generate all scenarios (240 docs) |
| `make generate-regression` | Generate only regression (30 docs) |
| `make generate-gradual` | Generate only gradual degradation (40 docs) |
| `make generate-all-separate` | Generate each scenario to separate files |

### Step 2: Convert

| Target | Description |
|--------|-------------|
| `make convert` | Convert to NDJSON bulk format |
| `make convert-all` | Convert all separate scenarios |

### Step 3: Index

| Target | Description |
|--------|-------------|
| `make index` | Index to OpenSearch |
| `make index-direct` | Generate and index directly (no files) |
| `make verify-index` | Verify document count in OpenSearch |

### Step 4: Pull

| Target | Description |
|--------|-------------|
| `make pull` | Pull all data from OpenSearch |
| `make pull-regression` | Pull only regression test data |
| `make pull-with-auth` | Pull with authentication |

### Step 5: Re-Index

| Target | Description |
|--------|-------------|
| `make reindex` | Re-index pulled data to practice index |

### Step 6: Test

| Target | Description |
|--------|-------------|
| `make test` | Run Orion regression test |
| `make test-all` | Run all Orion test scenarios |
| `make test-gradual` | Run gradual degradation test |
| `make test-intermittent` | Run intermittent outliers test |

### Inspection

| Target | Description |
|--------|-------------|
| `make view` | View first generated document |
| `make view-pulled` | View first pulled document |
| `make stats` | Show statistics (min, max, avg) |
| `make count` | Count documents in all files |
| `make list-indices` | List OpenSearch indices |
| `make show-files` | Show all generated files |

### Cleanup

| Target | Description |
|--------|-------------|
| `make clean` | Clean generated files |
| `make clean-index` | Delete OpenSearch index |
| `make clean-all-indices` | Delete all mock indices |
| `make clean-all` | Clean files + indices |
| `make reset` | Complete reset |

### Utility

| Target | Description |
|--------|-------------|
| `make help` | Show all targets with descriptions |
| `make check-env` | Check environment variables |

## Environment Variables

Override defaults with environment variables:

```bash
# Set OpenSearch server
make index ES_SERVER=http://your-server:9200

# Set Orion directory
make test ORION_DIR=/path/to/orion

# Set index name
make index ES_INDEX=my-custom-index

# Set authentication
make pull-with-auth ES_USER=admin ES_PASSWORD=secret
```

### Persistent Configuration

Set in your shell:

```bash
export ES_SERVER=http://localhost:9200
export ORION_DIR=/path/to/orion
export ES_INDEX=regulus-results-mock

# Now just use: make index, make test, etc.
```

## Example Workflows

### First Time Setup

```bash
# Set environment
export ES_SERVER=http://localhost:9200
export ORION_DIR=/path/to/orion

# Check environment
make check-env

# Run exercise 1
make exercise1
```

### Daily Practice

```bash
# Clean start
make reset

# Full cycle
make full-cycle

# Test with Orion
make test
```

### Complete Round Trip

```bash
# Clean everything
make clean-all

# Generate → Index → Pull → Re-Index
make round-trip

# Verify both indices
curl "http://localhost:9200/regulus-results-mock/_count"
curl "http://localhost:9200/regulus-results-mock-practice/_count"
```

### Test Individual Scenarios

```bash
# Generate specific scenario
make generate-regression

# Convert it
./json-to-bulk.py generated/regression.json generated/regression.ndjson

# Index it
curl -X POST 'http://localhost:9200/_bulk' \
  -H 'Content-Type: application/x-ndjson' \
  --data-binary '@generated/regression.ndjson'

# Test it
make test
```

### Pull and Analyze

```bash
# Make sure data is indexed
make verify-index

# Pull it back
make pull

# View statistics
make stats

# Inspect the data
make view-pulled
```

## Chaining Commands

```bash
# Multiple commands in sequence
make clean && make full-cycle && make test

# With different parameters
make clean-all ES_INDEX=test1 && \
make full-cycle ES_INDEX=test1 && \
make test ES_INDEX=test1
```

## Tips

1. **Always check help**: `make help` shows all targets
2. **Use tab completion**: Makefile supports bash tab completion
3. **Check environment**: `make check-env` before testing
4. **Clean between runs**: `make clean-all` for fresh start
5. **Use exercises**: Great for learning step-by-step
6. **Override variables**: Pass ES_SERVER, ORION_DIR as needed
7. **View before index**: `make view` to inspect data first
8. **Verify after index**: Automatic with `make index`

## Common Patterns

### Morning Practice Routine

```bash
make reset              # Clean slate
make practice-cycle     # Generate, index, pull
make stats             # Check data
make test              # Run Orion test
```

### Testing New Scenarios

```bash
make clean
make generate-regression
make convert
make index
make test
```

### Debugging

```bash
make check-env         # Verify configuration
make show-files        # See what files exist
make view              # Inspect data
make verify-index      # Check OpenSearch
make list-indices      # See all indices
```

### Cleanup After Work

```bash
make clean-all         # Remove files and indices
```

## Makefile Features

- ✅ **Color output** - Green for success, yellow for warnings, red for errors
- ✅ **Dependency tracking** - Automatically runs prerequisites
- ✅ **Error handling** - Stops on errors unless explicitly allowed
- ✅ **Environment variable support** - Override defaults easily
- ✅ **Help system** - Organized by category with descriptions
- ✅ **Progress indicators** - Shows what's happening
- ✅ **Verification** - Automatic checks after operations
- ✅ **Phony targets** - Never confused with files

## Getting Help

```bash
# Show all targets organized by category
make help

# Show what a target does
grep "target-name:" Makefile

# Dry run (see what would execute)
make -n target-name
```

## Advanced Usage

### Custom Index Names

```bash
# Use different index for testing
make full-cycle ES_INDEX=my-test-index
make test ES_INDEX=my-test-index
```

### Multiple Environments

```bash
# Development
make full-cycle ES_SERVER=http://dev-server:9200 ES_INDEX=dev-index

# Staging
make full-cycle ES_SERVER=http://staging-server:9200 ES_INDEX=staging-index
```

### Parallel Operations

```bash
# Generate multiple scenarios in parallel
make generate-regression &
make generate-gradual &
wait
```

---

**Start with:** `make help` to see all available targets!
