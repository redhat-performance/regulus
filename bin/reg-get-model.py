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
import sys

def detect_datapath_model(file_path):
    """
    Detect datapath model from a single annotation file.
    Returns the model name if found, otherwise None.
    """
    try:
        with open(file_path, 'r') as f:
            content = f.read()
        
        # Check for MACVLAN
        if re.search(r'"k8s\.v1\.cni\.cncf\.io/networks":\s*"regulus-macvlan-net"', content):
            return 'MACVLAN'
        
        # Check for SRIOV
        if re.search(r'"k8s\.v1\.cni\.cncf\.io/networks":\s*"default/sriov', content):
            return 'SRIOV'
        
        # Check for HWOL
        if re.search(r'"v1\.multus-cni\.io/default-network":\s*"default/default"', content):
            return 'HWOL'
        
        # Check for DPU
        if re.search(r'"v1\.multus-cni\.io/default-network":\s*"ovn-kubernetes/dpf-ovn-kubernetes"', content):
            return 'DPU'
        
        # If none of the above patterns match, it's OVNK
        return 'OVNK'
        
    except Exception as e:
        print(f"Error reading {file_path}: {e}", file=sys.stderr)
        return None

def detect_model_iter():
    # Check if debug mode is enabled
    debug = os.environ.get('DEBUG', '').lower() in ('1', 'true', 'yes')
    
    # Find all files matching *annotation* pattern in current directory
    annotation_files = glob.glob('*annotation*')
    
    if not annotation_files:
        if debug:
            print("No annotation files found in current directory")
        sys.exit(1)
    
    if debug:
        print(f"Found {len(annotation_files)} annotation file(s)")
    
    # Check each file and return the first match
    for file_path in annotation_files:
        if debug:
            print(f"Checking: {file_path}")
        model = detect_datapath_model(file_path)
        
        if model and model != 'OVNK':
            if debug:
                print(f"\nDatapath Model: {model}")
                print(f"Detected in: {file_path}")
            return model
    
    # If no specific model found in any file, default to OVNK
    if debug:
        print(f"\nDatapath Model: OVNK")
        print("(No specific datapath patterns detected)")
    return 'OVNK'

def get_datapath_model(json_path):
    """
    Detect hostNetwork first from all-in-one.json file.
    If any endpoint of type 'k8s' has hostNetwork == 1,
    return 'hostNetwork'. Otherwise, return output of detect_datapath_model().
    """
    try:
        with open(json_path, "r") as f:
            data = json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        print(f"Error reading {json_path}: {e}", file=sys.stderr)
        return detect_datapath_model()

    endpoints = data.get("endpoints", [])
    for ep in endpoints:
        if ep.get("type") == "k8s" and ep.get("hostNetwork") == 1:
            return "hostNetwork"

    # If not hostNetwork, detect model usine annotation files, 
    return detect_model_iter()

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <json_file>")
        sys.exit(1)

    json_file = sys.argv[1]
    result = get_datapath_model(json_file)
    print(result)



"""
1. add model
    MACVLAN:  "k8s.v1.cni.cncf.io/networks": "regulus-macvlan-net"
    SRIOV:  "k8s.v1.cni.cncf.io/networks": "default/sriov
    HWOL:  "v1.multus-cni.io/default-network": "default/default" 
    DPU: "v1.multus-cni.io/default-network": "ovn-kubernetes/dpf-ovn-kubernetes"
    OVNK: none of the above key
2. add qos
    static
    single-numa-policy
    none
3. add cpu
    burstable
    N-CPU
"""
