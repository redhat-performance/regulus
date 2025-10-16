#!/usr/bin/env python3
"""
    Script to detect datapath model from all-in-one.json for hostNetwork, and
    annotation files for OVNK, MACVLAN.SRIOV,DPU.
    Bothe all-in-one.json and annotaitons file must be in current directory.

    Usage: DEBUG=1 reg-get-model.py all-in-one.py

"""
import glob
import re
import sys
import os
import json

def detect_datapath_model(file_path):
    """Detect datapath model from a single annotation file."""
    try:
        with open(file_path, 'r') as f:
            content = f.read()

        if re.search(r'"k8s\.v1\.cni\.cncf\.io/networks":\s*"regulus-macvlan-net"', content):
            return 'MACVLAN'
        if re.search(r'"k8s\.v1\.cni\.cncf\.io/networks":\s*"default/sriov', content):
            return 'SRIOV'
        if re.search(r'"v1\.multus-cni\.io/default-network":\s*"default/default"', content):
            return 'HWOL'
        if re.search(r'"v1\.multus-cni\.io/default-network":\s*"ovn-kubernetes/dpf-ovn-kubernetes"', content):
            return 'DPU'

        # None matched → OVNK
        return 'OVNK'

    except Exception as e:
        print(f"Warning reading {file_path}: {e}", file=sys.stderr)
        return 'OVNK'

def detect_model_iter():
    """Check all annotation files and return first detected model, or OVNK if none."""
    annotation_files = glob.glob('*annotation*')
    if not annotation_files:
        return 'OVNK'

    for file_path in annotation_files:
        model = detect_datapath_model(file_path)
        if model and model != 'OVNK':
            return model

    return 'OVNK'

def get_datapath_model(json_path):
    """Check hostNetwork first, then annotation files, default OVNK."""
    try:
        with open(json_path, "r") as f:
            data = json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        print(f"Warning reading {json_path}: {e}", file=sys.stderr)
        return detect_model_iter()

    endpoints = data.get("endpoints", [])
    for ep in endpoints:
        if ep.get("type") == "k8s" and ep.get("hostNetwork") == 1:
            return "hostNetwork"

    return detect_model_iter()

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <json_file>")
        sys.exit(1)

    json_file = sys.argv[1]
    result = get_datapath_model(json_file)
    print(result)

