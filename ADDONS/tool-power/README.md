# Tool-power Helper for Regulus Runs

## Purpose

Enable BMC-based power telemetry collection for Regulus benchmark runs using `tool-power`.

## Problem

To run `tool-power` in a Regulus benchmark, you need:
1. A **remotehost endpoint** with `tool-opt-in-tags:[power-monitoring]` in `run.sh`
2. A **tool-power configuration** merged into `tool-params.json`

By design, we don't want to fully integrate tool-power into core Regulus infrastructure. This helper tool provides a simple way to add these requirements to specific run directories.

## Solution

Add 3 lines to your run directory's `reg_expand.sh` to automatically configure power collection:

```bash
cp ${REG_COMMON}/tool-power.json.template  ${MANIFEST_DIR}/tool-power.json
cp ${REG_COMMON}/hostmount.json.template  ${MANIFEST_DIR}/hostmount.json
$REG_ROOT/ADDONS/tool-power/enable.sh  ./ tool-power.json
```

When you run `make init`, these lines will:
- Insert the POWER snippet into `run.sh` (creates the remotehost endpoint)
- Merge `tool-power.json` into `tool-params.json` (adds tool-power configuration)

## Quick Start

### 1. Configure Master Template (One-Time Setup)

Edit `$REG_ROOT/templates/common/tool-power.json.template`:

```bash
vi $REG_ROOT/templates/common/tool-power.json.template
```

Set your BMC endpoints and interval:

```json
{
  "tool": "power",
  "deployment": "opt-in",
  "opt-tag": "power-monitoring",
  "params": [
    {  "arg": "interval", "val": "2" },
    {  "arg": "plugin", "val": "bf3-sensor" },
    {  "arg": "endpoints", "val": "bmc1.example.com,bmc2.example.com" }
  ]
}
```

**Authentication:** Configure `.netrc` on remotehost OR add `user`/`password` parameters. See `/opt/crucible/repos/.../tool-power/README.md` for details.

### 2. Enable Power Collection for a Run Directory

```bash
# Go to your run directory, for example
cd $REG_ROOT/1_GROUP/NO-PAO/4IP/INTRA-NODE/TCP/2-POD

# Edit reg_expand.sh
vi reg_expand.sh
```

Add these 3 lines after the `tool-params.json` copy:

```bash
cp ${REG_COMMON}/tool-power.json.template  ${MANIFEST_DIR}/tool-power.json
cp ${REG_COMMON}/hostmount.json.template  ${MANIFEST_DIR}/hostmount.json
$REG_ROOT/ADDONS/tool-power/enable.sh  ./ tool-power.json
```

### 3. Run Your Benchmark

```bash
make init
make run
```

Done! Power collection will run automatically.

## What Gets Modified

The `enable.sh` script makes two changes:

**1. Inserts POWER snippet into `run.sh`:**
```bash
POWER=1
    if [ "${POWER:-0}" = "1" ]; then
        endpoint_opt+=" --endpoint remotehosts,user:root,host:$bmlhosta,profiler:1-$num_servers,userenv:$userenv,tool-opt-in-tags:[power-monitoring],host-mounts:`pwd`/hostmount.json"
    fi
```

**2. Merges tool-power into `tool-params.json`:**
```json
[
  {"tool": "sysstat"},
  {"tool": "power",
    "deployment": "opt-in",
    "opt-tag": "power-monitoring",
    "params": [...]
  }
]
```

## Disabling Power Collection

Remove or comment out the 3 lines in `reg_expand.sh`, then run `make init` again.

## Examples and Templates

- **`example-run-dir/`** - Working example run directory with `reg_expand.sh` that uses the 3 lines to enable power collection
- **`example=templates/`** - Example tool-power.json templates for reference (with and without .netrc)

**Note:** `reg_expand.sh` uses master templates from `$REG_ROOT/templates/common/`:
- `tool-power.json.template` - Customize this with your BMC endpoints
- `hostmount.json.template` - For .netrc mounting

## Documentation

- **tool-power details:** `/opt/crucible/repos/.../tool-power/README.md`
  - Authentication setup (.netrc or user/password)
  - Output formats and metrics
  - Troubleshooting
