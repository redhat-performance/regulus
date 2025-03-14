#!/usr/bin/env python3
"""
Convert Regulus crucible CLI arguments to the one-dot-json.

Description: Regulus originally uses run.sh to generate CLI arguments
    for e.g. "crucibbe run uperf --endpoint --mv-params ,,," aka old-style.
    With crucible moving to the new API style, "crucible run --from-file one.json" aka one-json,
    this script converts the old-style arguments to a new one.json.

    It supports both Regulus exsiting monobench and multi-bench run.sh.

Usage:

Arguments:

Example:

"""
import argparse
import json
import os
import re

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

def parse_endpoint(endpoint_str):
    """ parse endpoints. k8s is still simple for now. remotehosts has its fancier schema.
    """
    tokens = endpoint_str.split(",")
    if not tokens:
        print("Error: --endpoint is empty.")
        return {}
    endpoint_type = tokens[0].strip()
    if endpoint_type == "remotehosts":
        return parse_remotehosts(endpoint_str)
    endpoint_data = {"type": endpoint_type}
    for pair in tokens[1:]:
        if ":" not in pair:
            continue
        key, value = pair.split(":", 1)
        key, value = key.strip(), value.strip()
        if value.isdigit():
            value = int(value)
        if key in endpoint_data:
            if isinstance(endpoint_data[key], list):
                endpoint_data[key].append(value)
            else:
                endpoint_data[key] = [endpoint_data[key], value]
        else:
            endpoint_data[key] = value
    return endpoint_data

def parse_remotehosts(endpoint_str):
    """ remotehosts is defined by its fancy schema
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

