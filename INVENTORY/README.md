# Lab Configuration and Testbed Inventory Extractor

A comprehensive toolkit for extracting and correlating information from OpenShift lab environment configuration files (`env.json`) and hardware inventory files (`testbed.json`).

## Overview

This toolkit provides three main extraction tools:

1. **`lab_extractor.py`** - Python-based, feature-rich extractor with correlation capabilities
2. **`json_extractor.py`** - Standalone JSON extraction tool with nested path support  
3. **`extract_json.sh`** - Bash-based extractor using `jq` (lightweight)

## Files

### Configuration Files

- **`env.json`** - Environment configuration with hostnames, network settings, kubeconfig path
- **`testbed.json`** - Hardware inventory created by `create_testbed_section.py`
- **`lab.config`** - Bash-style configuration (optional, can be converted from env.json)

### Scripts

- **`lab_extractor.py`** - Main extraction tool (recommended)
- **`json_extractor.py`** - Generic JSON extractor
- **`extract_json.sh`** - Bash/jq-based extractor
- **`example_usage.sh`** - Usage examples and demonstrations

## Installation

### Prerequisites

**For Python scripts:**
```bash
python3 --version  # Should be Python 3.6+
```

**For bash script:**
```bash
# Install jq if not already installed
sudo dnf install jq    # RHEL/Fedora
sudo apt install jq    # Ubuntu/Debian
```

### Setup

```bash
# Make scripts executable
chmod +x lab_extractor.py json_extractor.py extract_json.sh example_usage.sh
```

## Usage

### Lab Extractor (lab_extractor.py) - Recommended

The `lab_extractor.py` is the most powerful tool, combining environment configuration with hardware inventory data.

#### Basic Operations

**1. Display Complete Summary**
```bash
./lab_extractor.py --env env.json --testbed testbed.json --summary
```

**2. Get Specific Environment Value**
```bash
./lab_extractor.py --env env.json --key KUBECONFIG
./lab_extractor.py --env env.json --key REG_SRIOV_NIC
```

**3. Search for Keys**
```bash
# Find all SR-IOV related configuration
./lab_extractor.py --env env.json --search SRIOV

# Find all DPDK configuration
./lab_extractor.py --env env.json --search DPDK

# Find all network interface configuration
./lab_extractor.py --env env.json --search NIC
```

**4. List All Hosts**
```bash
./lab_extractor.py --env env.json --list-hosts
```

**5. Get Host Details**
```bash
# Show complete configuration and hardware for a specific host
./lab_extractor.py --env env.json --testbed testbed.json \
    --host nvd-srv-24.nvidia.eng.rdu2.dc.redhat.com
```

**6. Show Network Configuration**
```bash
./lab_extractor.py --env env.json --network
```

**7. List All NICs with Models**
```bash
./lab_extractor.py --env env.json --testbed testbed.json --list-nics
```

**8. Export to Bash Variables**
```bash
./lab_extractor.py --env env.json --export-bash env_vars.sh

# Source it in your scripts
source env_vars.sh
echo $KUBECONFIG
```

#### JSON Output

Add `--json` flag to any command for JSON output:

```bash
# Get host details as JSON
./lab_extractor.py --env env.json --testbed testbed.json \
    --host nvd-srv-24.nvidia.eng.rdu2.dc.redhat.com --json

# Search and output as JSON
./lab_extractor.py --env env.json --search DPDK --json

# Network config as JSON
./lab_extractor.py --env env.json --network --json
```

#### Working Without Testbed File

If you haven't generated `testbed.json` yet:

```bash
# All commands work without --testbed flag
./lab_extractor.py --env env.json --summary
./lab_extractor.py --env env.json --list-hosts
./lab_extractor.py --env env.json --network
```

### Generic JSON Extractor (json_extractor.py)

For working with any JSON file with nested structures:

```bash
# Display summary
./json_extractor.py -e env.json --summary

# Get specific value
./json_extractor.py -e env.json -k KUBECONFIG

# Search for keys
./json_extractor.py -e env.json -s SRIOV

# List all hosts
./json_extractor.py -e env.json --hosts

# Show network configuration
./json_extractor.py -e env.json --network

# Export to bash
./json_extractor.py -e env.json --export-bash env_vars.sh
```

### Bash Extractor (extract_json.sh)

Lightweight alternative using `jq`:

```bash
# Show summary
./extract_json.sh -e env.json --summary

# Get specific value
./extract_json.sh -e env.json -k KUBECONFIG

# Search for keys
./extract_json.sh -e env.json -s SRIOV

# List all hosts
./extract_json.sh -e env.json -h

# Show network configuration
./extract_json.sh -e env.json -n

# Export to bash
./extract_json.sh -e env.json -b env_vars.sh
```

## Common Use Cases

### 1. Quick Environment Check

```bash
# What's my kubeconfig?
./lab_extractor.py --env env.json --key KUBECONFIG

# What workers do I have?
./lab_extractor.py --env env.json --list-hosts
```

### 2. SR-IOV Configuration Review

```bash
# Show all SR-IOV settings
./lab_extractor.py --env env.json --search SRIOV

# Or get as JSON for processing
./lab_extractor.py --env env.json --search SRIOV --json | jq '.'
```

### 3. Hardware Verification

```bash
# Check specific worker hardware
./lab_extractor.py --env env.json --testbed testbed.json \
    --host nvd-srv-24.nvidia.eng.rdu2.dc.redhat.com

# List all NICs across all hosts
./lab_extractor.py --env env.json --testbed testbed.json --list-nics
```

### 4. Script Integration

```bash
#!/bin/bash

# Load environment variables
./lab_extractor.py --env env.json --export-bash /tmp/env.sh
source /tmp/env.sh

# Now use them in your script
echo "Testing on worker: $OCP_WORKER_0"
ssh core@$OCP_WORKER_0 "hostname"

# Get worker list as JSON for iteration
WORKERS=$(./lab_extractor.py --env env.json --list-hosts --json | jq -r '.hosts[]')

for worker in $WORKERS; do
    echo "Configuring $worker..."
    # Your configuration commands here
done
```

### 5. Network Configuration Extraction

```bash
# Get SR-IOV NIC for automation
SRIOV_NIC=$(./lab_extractor.py --env env.json --key REG_SRIOV_NIC)
echo "Configuring SR-IOV on: $SRIOV_NIC"

# Get all network config as JSON
./lab_extractor.py --env env.json --network --json > network_config.json
```

### 6. Report Generation

```bash
# Generate comprehensive lab report
./lab_extractor.py --env env.json --testbed testbed.json --summary > lab_report.txt

# Generate JSON report for processing
./lab_extractor.py --env env.json --testbed testbed.json --summary --json > lab_report.json
```

## Environment JSON Structure

Your `env.json` should contain:

```json
{
  "KUBECONFIG": "/path/to/kubeconfig",
  "REG_OCPHOST": "registry.example.com",
  "OCP_WORKER_0": "worker1.example.com",
  "OCP_WORKER_1": "worker2.example.com",
  "BM_HOSTS": "bmhost1.example.com bmhost2.example.com",
  "TREX_HOSTS": "trex.example.com",
  "REG_SRIOV_NIC": "ens1f0",
  "REG_SRIOV_MTU": "9000",
  "REG_SRIOV_NIC_MODEL": "CX6",
  ...
}
```

## Testbed JSON Structure

Generated by `create_testbed_section.py`:

```json
{
  "collection_time": "2024-01-15T10:30:00",
  "ocp_worker_count": 3,
  "ocp_workers": ["worker1.example.com", "worker2.example.com"],
  "ocp_workers_details": {
    "worker1.example.com": {
      "cpu": {
        "Model name": "Intel(R) Xeon(R) Gold 6348 CPU @ 2.60GHz",
        "CPU(s)": "112"
      },
      "network": {
        "pci_devices": [...],
        "lshw": [...]
      }
    }
  },
  ...
}
```

## Generating Testbed Inventory

To create the `testbed.json` file:

```bash
# Using lab.config file
python3 create_testbed_section.py \
    --lab-config lab.config \
    --lshw /usr/sbin/lshw \
    --json \
    --output testbed.json

# Or using kubeconfig directly
python3 create_testbed_section.py \
    --kubeconfig $KUBECONFIG \
    --lshw /usr/sbin/lshw \
    --json \
    --output testbed.json
```

## Converting lab.config to env.json

If you have a `lab.config` bash file:

```bash
# Create env.json from lab.config
python3 << 'EOF'
import json
import re

env = {}
with open('lab.config', 'r') as f:
    for line in f:
        match = re.match(r'export\s+(\w+)\s*=\s*"([^"]*)"', line.strip())
        if match:
            env[match.group(1)] = match.group(2)

with open('env.json', 'w') as f:
    json.dump(env, f, indent=2)
print("Created env.json from lab.config")
EOF
```

## Help

All tools support `--help`:

```bash
./lab_extractor.py --help
./json_extractor.py --help
./extract_json.sh --help
```

## Tips and Tricks

1. **Use JSON output for automation:**
   ```bash
   ./lab_extractor.py --env env.json --list-hosts --json | jq -r '.hosts[]'
   ```

2. **Combine with jq for filtering:**
   ```bash
   ./lab_extractor.py --env env.json --network --json | jq '.sriov'
   ```

3. **Export once, use everywhere:**
   ```bash
   ./lab_extractor.py --env env.json --export-bash ~/.lab_env.sh
   echo "source ~/.lab_env.sh" >> ~/.bashrc
   ```

4. **Quick host lookup:**
   ```bash
   # Create an alias
   alias labhost='./lab_extractor.py --env env.json --testbed testbed.json --host'
   
   # Use it
   labhost nvd-srv-24.nvidia.eng.rdu2.dc.redhat.com
   ```

## Troubleshooting

**Problem:** Script not executable
```bash
chmod +x lab_extractor.py
```

**Problem:** Python not found
```bash
python3 --version  # Check Python 3 is installed
```

**Problem:** jq not found (for extract_json.sh)
```bash
sudo dnf install jq  # RHEL/Fedora
```

**Problem:** File not found
```bash
# Check files exist
ls -l env.json testbed.json

# Use absolute paths
./lab_extractor.py --env /full/path/to/env.json --summary
```

## Examples

See `example_usage.sh` for comprehensive examples:

```bash
./example_usage.sh
```

## License

Internal Red Hat tool for lab management and testing automation.
