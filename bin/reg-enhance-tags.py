#!/usr/bin/env python3
import json
import sys
import subprocess
import os

"""
 Reject duplicate key:value
"""

def get_value_from_script(script_path, json_file):
    """
    Run external script and return its stdout value.
    Raises ValueError if no output is returned.
    """
    try:
        result = subprocess.run(
            [script_path, json_file],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
        value = result.stdout.decode().strip()
        if not value:
            raise ValueError(f"No value returned from {script_path}")
        return value
    except Exception as e:
        print(f"Error running script {script_path}: {e}", file=sys.stderr)
        return None

def insert_tag(json_file, key, value):
    """
    Insert or update a key:value pair in the "tags" object of the JSON file.
    """
    try:
        with open(json_file, 'r') as f:
            data = json.load(f)

        if "tags" not in data:
            data["tags"] = {}

        if key in data["tags"]:
            print(f"Warning: key '{key}' already exists in tags. Overwriting.", file=sys.stderr)

        data["tags"][key] = value

        with open(json_file, 'w') as f:
            json.dump(data, f, indent=4)

        print(f"Inserted '{key}: {value}' into {json_file}")

    except Exception as e:
        print(f"Error updating {json_file}: {e}", file=sys.stderr)

def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <json_file> <key:script[,key:script,...]>", file=sys.stderr)
        sys.exit(1)

    json_file = sys.argv[1]
    key_script_str = sys.argv[2]

    if not os.path.isfile(json_file):
        print(f"JSON file does not exist: {json_file}", file=sys.stderr)
        sys.exit(1)

    # Parse key:script pairs
    pairs = key_script_str.split(',')
    seen_keys = set()

    for pair in pairs:
        if ':' not in pair:
            print(f"Invalid key:script pair: '{pair}'", file=sys.stderr)
            continue

        key, script_path = pair.split(':', 1)
        key = key.strip()
        script_path = script_path.strip()

        if key in seen_keys:
            print(f"Warning: duplicate key '{key}' in input. Skipping.", file=sys.stderr)
            continue
        seen_keys.add(key)

        if not os.path.isfile(script_path):
            print(f"Helper script does not exist: {script_path}", file=sys.stderr)
            continue

        value = get_value_from_script(script_path, json_file)
        if value is not None:
            insert_tag(json_file, key, value)

if __name__ == "__main__":
    main()

