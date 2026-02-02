# Sample Data

Place sample JSON report files in this directory to include them in the Docker image.

## What to Put Here

Copy your sample/demo JSON report files here:

```bash
# From test data
cp ../build_report/dashboard/test_data/*.json .

# Or from actual test results
cp ~/my-performance-tests/sample-report.json .
```

## File Format

JSON files should follow the regulus report schema. Example structure:

```json
{
  "schema_info": {
    "version": "2.0",
    "description": "..."
  },
  "generation_info": {
    "total_results": 2,
    "benchmarks": ["uperf"],
    ...
  },
  "results": [
    {
      "benchmark": "uperf",
      "key_tags": {...},
      "iterations": [...],
      ...
    }
  ]
}
```

## How It Works

1. Files in this directory are **copied into the Docker image** at build time
2. They are stored in `/app/initial_data/` inside the container
3. On first run (when `/app/data` is empty), they're copied to `/app/data/`
4. Users see these as initial demo data when they first run the dashboard

## Best Practices

- Include 2-5 representative sample files (not too many)
- Use descriptive filenames: `mock-ovnk-cx7-test.json`, `sample-sriov-results.json`
- Keep files reasonably sized (< 1MB each)
- Include variety: different benchmarks, configurations, etc.

## Building Without Sample Data

If this directory is empty, the Docker image will build without initial data.
Users will need to add their own JSON files to get started.

## File Naming Conventions

Consider using prefixes to identify sample data:
- `mock-*.json` - Mock/demo data
- `sample-*.json` - Sample real data
- `demo-*.json` - Demonstration data

This makes it easy for users to identify and remove sample files:
```bash
rm /tmp/regulus-data/mock-*.json
```
