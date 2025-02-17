#!/usr/bin/python3
"""
Utility to convert an old CLI style of "crucible run" to the new, one-json style
Usage:
    OLD: crucible run uperf --tags $tags --mv-params $mv_params_file --num-samples=$NUM_SAMPLES --max-sample-failures=$max_failures $endpoint_opt  --max-rb-attempts=3 
    NEW:
        c2j.py --name uperf --output all-in-one.json \
            --tags $tags \
            --mv-params $mv_params_file \
            --num-samples $NUM_SAMPLES \
            --max-sample-failures $max_failures \
            $endpoint_opt \
            --tool-params tool-params.json \
            --max-rb-attempts=3 
        crucible run --from-file all-in-one.json

Required: python 3.10
"""
import argparse
import json

import inspect
DEBUG_MODE = False 
def HN_debug(msg):
    if DEBUG_MODE:
        frame = inspect.currentframe().f_back  # Get caller's frame
        print(f"Debug ({frame.f_code.co_filename}:{frame.f_lineno} in {frame.f_code.co_name}): {msg}")

# Example usage HN_debug(f"x = {x}")

import re
def simplify_id_range(value):
    """
    Converts '1-1' to '1', but keeps valid ranges like '1-3' unchanged.
    This idiosyncrasy was in the old style artifacts
    """
    match = re.fullmatch(r"(\d+)-(\d+)", value)
    if match:
        start, end = match.groups()
        return start if start == end else value
    return value

def parse_endpoint(endpoint_str):
    """ 
        Parses an endpoint string into a structured dictionary.
        See 
    """
    tokens = endpoint_str.split(",")
    HN_debug(f"enter");

    if not tokens:
        print("Error: --endpoint is empty.")
        return {}

    endpoint_type = tokens[0].strip()

    if endpoint_type == "remotehosts":
        return parse_remotehosts(endpoint_str)

    # Default parsing for other endpoint types
    endpoint_data = {"type": endpoint_type}
    for pair in tokens[1:]:
        if ":" not in pair:
            print(f"Skipping invalid pair (missing ':'): {pair}")
            continue
        key, value = pair.split(":", 1)
        key, value = key.strip(), value.strip()

        # Convert to int if applicable
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
    """ Parses an endpoint string of type 'remotehosts' into structured data.
        See https://github.com/perftool-incubator/rickshaw/blob/master/schema/remotehosts.json
    """

    endpoint_data = {
        "type": "remotehosts",
        "remotes": []
    }

    config = {"settings": {"osruntime": "chroot"}}  # Default osruntime to "chroot"
    remotes_entry = {"engines": [], "config": config}

    tokens = endpoint_str.split(",")

    for pair in tokens[1:]:  # Skip "remotehosts"
        if ":" not in pair:
            continue
        key, value = pair.split(":", 1)
        key, value = key.strip(), value.strip()

        #if key in ["host", "user", "userenv"]:  
        if key in ["host"]:  
            config[key] = value  # Place in the config section
        elif key in [ "user", "userenv"]:  
            # eat them HN
            HN_debug(f"eat {key}");
        elif key == "client":
            remotes_entry["engines"].append({"role": "client", "ids": simplify_id_range(value)})
        elif key == "server":
            remotes_entry["engines"].append({"role": "server", "ids": simplify_id_range(value)})
        elif key == "profiler":
            remotes_entry["engines"].append({"role": "profiler"})
        elif key == "osruntime":
            config["settings"]["osruntime"] = value  # Place under settings
        else:
            config[key] = value  # Any additional settings go under config

    # Ensure "host" is required before adding to remotes
    if "host" in config:
        endpoint_data["remotes"].append(remotes_entry)

    return endpoint_data


def load_json_file(file_path):
    """Loads JSON content from a file."""
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
    """Parses a comma-separated string into a dictionary."""
    tags = {}
    for pair in tag_str.split(","):
        if ":" not in pair:
            print(f"Skipping invalid tag pair (missing ':'): {pair}")
            continue
        key, value = pair.split(":", 1)
        tags[key.strip()] = value.strip()
    return tags

def main():
    """
        See https://github.com/perftool-incubator/rickshaw/blob/master/util/JSON/schema.json
    """
    parser = argparse.ArgumentParser(description="Parse multiple --endpoint values into JSON")
    parser.add_argument("--endpoint", action="append", required=True, help="Comma-separated key-value pairs (multiple allowed)")
    parser.add_argument("--mv-params", help="JSON file for mv-params to insert into the output")
    parser.add_argument("--num-samples", type=int, default=1, help="Number of samples for run-params")
    parser.add_argument("--tags", default="", help="Comma-separated key-value pairs for tags")
    parser.add_argument("--tool-params", help="JSON file for tool-params")
    parser.add_argument("--name", required=True, help="Name of the benchmark")
    parser.add_argument("--output", default="endpoints.json", help="Output JSON file")
    parser.add_argument("--max-sample-failures", type=int, help="Maximum number of sample failures")
    parser.add_argument("--max-rb-attempts", type=int, help="Maximum number of rollback attempts")

    args = parser.parse_args()

    # Parse endpoints
    endpoints = [parse_endpoint(ep) for ep in args.endpoint]

    # Parse optional parameters
    mv_params = load_json_file(args.mv_params) if args.mv_params else {}
    tool_params = load_json_file(args.tool_params) if args.tool_params else []
    tags = parse_tags(args.tags) if args.tags else {}

    # Construct run-params dynamically
    run_params = {"num-samples": args.num_samples}
    if args.max_sample_failures is not None:
        run_params["max-sample-failures"] = args.max_sample_failures
    if args.max_rb_attempts is not None:
        run_params["max-rb-attempts"] = args.max_rb_attempts

    # Construct the JSON output
    output_data = {
        "benchmarks": [
            {
                "name": args.name,
                "ids": "1-64",          # HN: simplification for mono-bench
                "mv-params": mv_params
            }
        ],
        "endpoints": endpoints,
        "run-params": run_params,
        "tags": tags,
        "tool-params": tool_params
    }

    # Save to file
    with open(args.output, "w") as f:
        json.dump(output_data, f, indent=4)

    print(f"JSON data saved to {args.output}")

if __name__ == "__main__":
    main()

