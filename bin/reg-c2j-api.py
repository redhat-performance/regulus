#!/usr/bin/env python3
"""
Convert Regulus crucible CLI arguments to the one-dot-json.

Description: Regulus originally uses run.sh to generate CLI arguments
    for e.g. "crucible run uperf --endpoint --mv-params ,,," aka old-style.
    With crucible moving to the new API style, "crucible run --from-file one.json" aka one-json,
    this script converts the old-style arguments to the new one.json.

    It supports both Regulus exsiting monobench and multi-bench run.sh.

Usage:

Arguments:

Example:

"""
import argparse
import json
import os
import re
import sys

import inspect
DEBUG_MODE = False
def HN_debug(msg):
    if DEBUG_MODE:
        frame = inspect.currentframe().f_back  # Get caller's frame
        print(f"Debug ({frame.f_code.co_filename}:{frame.f_lineno} in {frame.f_code.co_name}): {msg}")

# Example usage HN_debug(f"x = {x}")

def simplify_id_range(value):
    """ Change the idiosyncracy ranges in the form of 1-1 to just 1
    """
    match = re.fullmatch(r"(\d+)-(\d+)", value)
    if match:
        start, end = match.groups()
        return start if start == end else value
    return value

def format_combined_ids(id_list):
    """ Change ranges in the form of a-b,c-d to to a-b+c-d
    """
    return "+".join(id_list)

def load_json_from_file(filepath):
    """
        Load and parse a JSON file, handling both standard JSON and files with key prefixes
        Support 2 types of json stanza
            "nodeSelector": {
                "kubernetes.io/hostname": "52-54-00-19-43-83"
        
            }
        or
            {
                "key": "value"
            }  
    """
    try:
        with open(filepath, 'r') as f:
            content = f.read().strip()
        
        # First, try to parse as standard JSON
        try:
            return json.loads(content)
        except json.JSONDecodeError:
            # If that fails, check if it has a key prefix like "nodeSelector": {...}
            if content.startswith('"'):
                colon_idx = content.find(':')
                if colon_idx != -1:
                    # Skip past the key and colon to get just the JSON value
                    content = content[colon_idx + 1:].strip()
                    return json.loads(content)
            # If still can't parse, raise the error
            raise
            
    except json.JSONDecodeError as e:
        print(f"Error loading {filepath}: {e}", file=sys.stderr)
        return None
    except Exception as e:
        print(f"Error loading {filepath}: {e}", file=sys.stderr)
        return None

def transform_resources(resources):
    """
    Pass through resources as-is.
    The input resource stanza is used directly without any transformation.
    """
    return resources

def transform_securityContext(k8s_securityContext):
    """
    Transform k8s-style securityContext to kube-style securityContext
    
    k8s format (flat):
    {
        "privileged": true,
        "capabilities": {
            "add": ["SYS_ADMIN", "IPC_LOCK"]
        }
    }
    
    kube format (with container/pod level):
    {
        "container": {
            "privileged": true,
            "capabilities": {
                "add": ["SYS_ADMIN", "IPC_LOCK"]
            }
        }
    }
    """
    if not k8s_securityContext:
        return k8s_securityContext
    
    # Check if already has container or pod keys (already in kube format)
    if 'container' in k8s_securityContext or 'pod' in k8s_securityContext:
        # Already in kube format, return as-is
        return k8s_securityContext
    
    # These fields are container-level in K8s
    container_level_fields = [
        'privileged', 'capabilities', 'allowPrivilegeEscalation',
        'readOnlyRootFilesystem', 'runAsNonRoot', 'runAsUser',
        'runAsGroup', 'procMount', 'seccompProfile', 'seLinuxOptions',
        'windowsOptions'
    ]
    
    # These fields are pod-level in K8s
    pod_level_fields = [
        'fsGroup', 'fsGroupChangePolicy', 'supplementalGroups',
        'sysctls', 'seccompProfile', 'seLinuxOptions', 'windowsOptions'
    ]
    
    # Note: Some fields can appear at both levels (runAsUser, seLinuxOptions, etc.)
    # We'll default to container level if ambiguous
    
    container_ctx = {}
    pod_ctx = {}
    
    for key, value in k8s_securityContext.items():
        if key in ['fsGroup', 'fsGroupChangePolicy', 'supplementalGroups', 'sysctls']:
            # Definitely pod-level only
            pod_ctx[key] = value
        else:
            # Default to container level (includes privileged, capabilities, etc.)
            container_ctx[key] = value
    
    # Build the kube format
    kube_securityContext = {}
    if container_ctx:
        kube_securityContext['container'] = container_ctx
    if pod_ctx:
        kube_securityContext['pod'] = pod_ctx
    
    return kube_securityContext


def transform_k8s_to_kube(k8s_endpoint):
    """
    Transform a k8s endpoint configuration to the new kube endpoint format
    
    Args:
        k8s_endpoint (dict): The k8s endpoint configuration (already parsed)
        
    Returns:
        dict: The transformed kube endpoint configuration
    """
    kube_endpoint = {
        "type": "kube",
        "host": k8s_endpoint["host"],
        "user": k8s_endpoint["user"],
        "engines": {}
    }
    
    # Transform engines - apply simplify_id_range to client/server IDs
    if "client" in k8s_endpoint:
        client_val = k8s_endpoint["client"]
        # If it's a list of ranges, format them with +, otherwise simplify
        if isinstance(client_val, list):
            simplified = [simplify_id_range(str(v)) for v in client_val]
            kube_endpoint["engines"]["client"] = format_combined_ids(simplified)
        else:
            kube_endpoint["engines"]["client"] = simplify_id_range(str(client_val))

    if "server" in k8s_endpoint:
        server_val = k8s_endpoint["server"]
        # If it's a list of ranges, format them with +, otherwise simplify
        if isinstance(server_val, list):
            simplified = [simplify_id_range(str(v)) for v in server_val]
            kube_endpoint["engines"]["server"] = format_combined_ids(simplified)
        else:
            kube_endpoint["engines"]["server"] = simplify_id_range(str(server_val))
    
    # Transform namespace
    if "unique-project" in k8s_endpoint:
        kube_endpoint["namespace"] = {
            "type": "unique",
            "prefix": k8s_endpoint["unique-project"]
        }
    elif "custom-project" in k8s_endpoint:
        kube_endpoint["namespace"] = {
            "type": "custom",
            "name": k8s_endpoint["custom-project"]
        }
    
    # Pass through direct properties
    passthrough_props = ["kubeconfig", "metallb-pool", "controller-ip-address"]
    for prop in passthrough_props:
        if prop in k8s_endpoint:
            kube_endpoint[prop] = k8s_endpoint[prop]
    
    # Pass through disable-tools if present
    if "disable-tools" in k8s_endpoint:
        kube_endpoint["disable-tools"] = k8s_endpoint["disable-tools"]
    
    # Pass through sysinfo if present
    if "sysinfo" in k8s_endpoint:
        kube_endpoint["sysinfo"] = k8s_endpoint["sysinfo"]
    
    # Build config array from settings
    config = []
    config_targets = {}  # target -> {settings}
    
    # Settings that can have target:filepath format
    setting_keys = {
        "nodeSelector": "nodeSelector",
        "resources": "resources", 
        "securityContext": "securityContext",
        "annotations": "annotations",
        "volumes": "volumes"
    }
    
    # Parse settings with target:filepath format
    for k8s_key, kube_key in setting_keys.items():
        if k8s_key in k8s_endpoint:
            value = k8s_endpoint[k8s_key]
            
            # Handle both list and string formats
            entries = value if isinstance(value, list) else [value]
            
            for entry in entries:
                # Parse target:filepath
                if ":" in str(entry) and "/" in str(entry):
                    # This is target:filepath format
                    parts = str(entry).split(":", 1)
                    target = parts[0]
                    filepath = parts[1]
                    
                    # Load the JSON file
                    content = load_json_from_file(filepath)
                    if content is None:
                        print(f"Warning: Failed to load {filepath} for {k8s_key}:{target}", file=sys.stderr)
                        continue
                    
                    # Transform resources if this is a resources file
                    if kube_key == "resources":
                        content = transform_resources(content)

                    # Transform securityContext if this is a securityContext file
                    if kube_key == "securityContext":
                        content = transform_securityContext(content)  # ← THIS LINE

                    if target not in config_targets:
                        config_targets[target] = {}
                    
                    config_targets[target][kube_key] = content
                else:
                    # Direct value (no file loading)
                    if "default" not in config_targets:
                        config_targets["default"] = {}
                    config_targets["default"][kube_key] = entry

    # Handle simple settings (no target:filepath format)
    simple_settings = ["userenv", "osruntime", "runtimeClassName", "hostNetwork", "cpu-partitioning"]
    default_settings = {}

    for setting in simple_settings:
        if setting in k8s_endpoint:
            val = k8s_endpoint[setting]
            # Special conversion: hostNetwork numeric 1 -> True, 0 -> False
            if setting == "hostNetwork":
                if val == 1:
                    val = True
                elif val == 0:
                    val = False
            # Keep all other settings as-is
            default_settings[setting] = val

    # Build config blocks
    for target, settings in config_targets.items():
        config_block = {
            "settings": settings
        }
        
        # Parse target
        if target == "default":
            config_block["targets"] = "default"
        else:
            # Parse target like "client-1" or "server-1"
            parts = target.split("-", 1)
            if len(parts) >= 2:
                role = parts[0]
                id_val = parts[1]
                config_block["targets"] = [{
                    "role": role,
                    "ids": id_val
                }]
            else:
                print(f"Warning: Could not parse target '{target}'", file=sys.stderr)
                continue
        
        config.append(config_block)
    
    # Add or merge default settings block
    if default_settings:
        # Check if there's already a default block
        default_block = None
        for block in config:
            if block.get("targets") == "default":
                default_block = block
                break
        
        if default_block:
            # Merge default_settings into existing default block
            default_block["settings"].update(default_settings)
        else:
            # Create new default block
            config.append({
                "targets": "default",
                "settings": default_settings
            })
    
    if config:
        kube_endpoint["config"] = config
    
    return kube_endpoint

def parse_endpoint(endpoint_str):
    """ parse endpoints. k8s will be transformed to kube. remotehost to remotehosts
    """
    tokens = endpoint_str.split(",")
    if not tokens:
        print("Error: --endpoint is empty.")
        return {}
    endpoint_type = tokens[0].strip()

    # Handle remotehosts
    if endpoint_type == "remotehosts":
        return parse_remotehosts(endpoint_str)

    # Parse k8s (and other types) as key:value pairs
    endpoint_data = {"type": endpoint_type}
    for pair in tokens[1:]:
        if ":" not in pair:
            continue
        key, value = pair.split(":", 1)
        key, value = key.strip(), value.strip()

        # Handle sysinfo boolean shorthand
        if key == "sysinfo":
            if value.lower() in ["true", "false"]:
                endpoint_data[key] = {"collect-must-gather": value.lower() == "true"}
                continue

        if value.isdigit():
            value = int(value)
        if key in endpoint_data:
            if isinstance(endpoint_data[key], list):
                endpoint_data[key].append(value)
            else:
                endpoint_data[key] = [endpoint_data[key], value]
        else:
            endpoint_data[key] = value

    # Transform k8s to kube format
    if endpoint_type == "k8s":
        HN_debug(f"Transforming k8s endpoint to kube format for host: {endpoint_data.get('host')}")
        endpoint_data = transform_k8s_to_kube(endpoint_data)

    return endpoint_data

def parse_remotehosts(endpoint_str):
    """ remotehosts transformation
    """
    endpoint_data = {"type": "remotehosts", "remotes": []}
    config = {"settings": {"osruntime": "chroot"}}
    remotes_entry = {"engines": [], "config": config}
    tokens = endpoint_str.split(",")
    for pair in tokens[1:]:
        if ":" not in pair:
            continue
        key, value = pair.split(":", 1)
        key, value = key.strip(), value.strip()
        if key in ["host"]:
            config[key] = value
        elif key in ["user"]:
            config["settings"]["user"] = value
        elif key in ["userenv"]:
            config["settings"]["userenv"] = value
        elif key in ["cpu-partitioning"]:
            config["settings"]["cpu-partitioning"] = value.lower() == "true"
        elif key == "client":
            remotes_entry["engines"].append({"role": "client", "ids": simplify_id_range(value)})
        elif key == "server":
            remotes_entry["engines"].append({"role": "server", "ids": simplify_id_range(value)})
        elif key == "profiler":
            remotes_entry["engines"].append({"role": "profiler"})
        elif key == "osruntime":
            config["settings"]["osruntime"] = value
        else:
            config[key] = value
    if "host" in config:
        endpoint_data["remotes"].append(remotes_entry)
    return endpoint_data

def load_json_file(file_path):
    try:
        with open(file_path, "r") as file:
            return json.load(file)
    except FileNotFoundError:
        print(f"Error: {file_path} not found.")
        return {}
    except json.JSONDecodeError:
        print(f"Error: Invalid JSON in {file_path}.")
        return {}

def parse_tags(tag_str):
    tags = {}
    for pair in tag_str.split(","):
        if ":" not in pair:
            continue
        key, value = pair.split(":", 1)
        tags[key.strip()] = value.strip()
    return tags

def main():
    parser = argparse.ArgumentParser(description="Parse multiple --endpoint values into JSON")
    parser.add_argument("--name", type=str, required=True, help="Comma-separated list of benchmark names i.e uperf,iperf")
    parser.add_argument('--mv-params', help='Comma-separated list of mv params files', type=str, required=True)
    parser.add_argument("--bench-ids", type=str, help="Comma-separated list of benchmark IDs in format name:ids")
    parser.add_argument("--endpoint", action="append", required=True, help="Comma-separated key-value pairs (multiple allowed)")
    parser.add_argument("--num-samples", type=int, default=1, help="Number of samples for run-params")
    parser.add_argument("--tags", default="", help="Comma-separated key-value pairs for tags")
    parser.add_argument("--tool-params", help="JSON file for tool-params")
    parser.add_argument("--max-sample-failures", type=int, help="Maximum number of sample failures")
    parser.add_argument("--max-rb-attempts", type=int, help="Maximum number of rollback attempts")
    parser.add_argument("--output", default="endpoints.json", help="Output JSON file")

    args = parser.parse_args()

    args.name = args.name.split(",")
    mv_params_list = args.mv_params.split(",") if args.mv_params else []

    # each benchmark must have its mv-params
    if len(mv_params_list) != len(args.name):
        print("Error: Number of mv-params files does not match the number of benchmark names")
        return

    loaded_mv_params = [load_json_file(param) if os.path.isfile(param) else {} for param in mv_params_list]

    bench_ids_map = {}

    # handle bench-ids with multiple key:value pairs of same key i.e uperf:1-2,uperf:21-26
    if args.bench_ids:
        for entry in args.bench_ids.split(","):
            name, ids = entry.split(":")
            if name in bench_ids_map:
                bench_ids_map[name].append(ids)
            else:
                bench_ids_map[name] = [ids]
    
    benchmarks = []
    for i, name in enumerate(args.name):
        benchmarks.append({
            "name": name,
            "ids": format_combined_ids(bench_ids_map.get(name, ["1-64"])),
            "mv-params": loaded_mv_params[i]
        })

    # Parse all endpoints - remotehosts logic unchanged, k8s gets transformed to kube
    endpoints = [parse_endpoint(ep) for ep in args.endpoint]
    
    tags = parse_tags(args.tags) if args.tags else {}
    tool_params = load_json_file(args.tool_params) if args.tool_params else {}

    run_params = {"num-samples": args.num_samples}
    if args.max_sample_failures is not None:
        run_params["max-sample-failures"] = args.max_sample_failures
    if args.max_rb_attempts is not None:
        run_params["max-rb-attempts"] = args.max_rb_attempts

    output_data = {
        "benchmarks": benchmarks,
        "endpoints": endpoints,
        "run-params": run_params,
        "tags": tags,
        "tool-params": tool_params
    }

    with open(args.output, "w") as f:
        json.dump(output_data, f, indent=4)

    print(f"JSON data saved to {args.output}")

if __name__ == "__main__":
    main()

