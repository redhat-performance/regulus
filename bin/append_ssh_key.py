#!/usr/bin/env python3
"""
Simple script to append SSH key to authorized_keys via oc debug pod.
Idempotent - checks if key already exists before appending.
"""
import sys
import subprocess
import tempfile
import os

def run_cmd(cmd, check=True):
    """Run command and return output"""
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if check and result.returncode != 0:
        print(f"[ERROR] Command failed: {cmd}", file=sys.stderr)
        print(f"[ERROR] {result.stderr}", file=sys.stderr)
        sys.exit(1)
    return result.stdout.strip(), result.returncode

def main():
    if len(sys.argv) != 3:
        print("Usage: append_ssh_key.py <node-name> <local-key-file>")
        sys.exit(1)
    
    node_name = sys.argv[1]
    local_file = sys.argv[2]
    target_file = "/var/home/core/.ssh/authorized_keys.d/ignition"
    namespace = "default"
    
    if not os.path.exists(local_file):
        print(f"[ERROR] Local file '{local_file}' does not exist.")
        sys.exit(1)
    
    # Read the key content to check if already present
    with open(local_file, 'r') as f:
        key_content = f.read().strip()
    
    # Create debug pod
    print(f"[INFO] Launching debug pod on node {node_name}...")
    with tempfile.NamedTemporaryFile(mode='w', delete=False) as tmplog:
        log_file = tmplog.name
    
    subprocess.Popen(f"oc debug node/{node_name} -- bash -c 'sleep 300' > {log_file} 2>&1", shell=True)
    run_cmd("sleep 5", check=False)
    
    # Get debug pod name
    output, _ = run_cmd(f"grep -oE '^Starting pod/[a-z0-9-]+' {log_file} | cut -d/ -f2 | tail -1", check=False)
    debug_pod = output
    
    if not debug_pod:
        print("[ERROR] Could not determine debug pod name")
        with open(log_file) as f:
            print(f.read(), file=sys.stderr)
        os.unlink(log_file)
        sys.exit(1)
    
    # Wait for pod to be ready
    print(f"[INFO] Waiting for debug pod {debug_pod} to become ready...")
    _, rc = run_cmd(f"oc wait --for=condition=Ready pod/{debug_pod} --timeout=60s -n {namespace} > /dev/null", check=False)
    if rc != 0:
        print("[ERROR] Debug pod did not become ready in time.")
        run_cmd(f"oc delete pod/{debug_pod} -n {namespace} --ignore-not-found", check=False)
        os.unlink(log_file)
        sys.exit(1)
    
    # Check if key already exists
    print(f"[INFO] Checking if key already exists in {target_file}...")
    check_script = f"""#!/bin/bash
if [ -f "{target_file}" ] && grep -qF '{key_content}' "{target_file}"; then
    echo "KEY_EXISTS"
else
    echo "KEY_NOT_FOUND"
fi
"""
    
    output, _ = run_cmd(f"echo '{check_script}' | oc exec -i -n {namespace} {debug_pod} -- chroot /host /bin/bash", check=False)
    
    if "KEY_EXISTS" in output:
        print(f"[INFO] SSH key already present in {target_file} on node {node_name}")
        print("[INFO] Skipping append (idempotent)")
        run_cmd(f"oc delete pod/{debug_pod} -n {namespace} --ignore-not-found > /dev/null", check=False)
        os.unlink(log_file)
        print(f"[SUCCESS] SSH key verified in '{node_name}:{target_file}' (already present)")
        return
    
    print(f"[INFO] Key not found, will append...")
    
    # Copy key file to pod
    temp_remote = f"/tmp/{os.path.basename(local_file)}"
    print(f"[INFO] Copying local key file to {temp_remote} on node...")
    _, rc = run_cmd(f"oc cp {local_file} {namespace}/{debug_pod}:/host{temp_remote}", check=False)
    if rc != 0:
        print("[ERROR] Failed to copy key file into debug pod.")
        run_cmd(f"oc delete pod/{debug_pod} -n {namespace} --ignore-not-found", check=False)
        os.unlink(log_file)
        sys.exit(1)
    
    # Append key
    print(f"[INFO] Appending key file content to {target_file} on node...")
    append_script = f"""#!/bin/bash
mkdir -p "$(dirname "{target_file}")"
if [[ -f "{target_file}" && $(tail -c1 "{target_file}") != "" ]]; then
    printf "\\n" >> "{target_file}"
fi
cat "{temp_remote}" >> "{target_file}"
chmod 600 "{target_file}"
chown core:core "{target_file}"
rm "{temp_remote}"
"""
    
    _, rc = run_cmd(f"echo '{append_script}' | oc exec -i -n {namespace} {debug_pod} -- chroot /host /bin/bash", check=False)
    if rc != 0:
        print("[ERROR] Failed to append key file on node.")
        run_cmd(f"oc delete pod/{debug_pod} -n {namespace} --ignore-not-found", check=False)
        os.unlink(log_file)
        sys.exit(1)
    
    # Cleanup
    print(f"[INFO] Cleaning up debug pod {debug_pod}...")
    run_cmd(f"oc delete pod/{debug_pod} -n {namespace} --ignore-not-found > /dev/null", check=False)
    os.unlink(log_file)
    print(f"[SUCCESS] Appended '{local_file}' content to '{node_name}:{target_file}'")

if __name__ == "__main__":
    main()
