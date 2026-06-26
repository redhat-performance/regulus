#
# Install auth key onto a node in order to shupport ssh core@<node_ip>
#
# Limitation: Can be invoked from jumphost/bastion only
#
# Usage:  core-auth-key.sh <node-name> [public.key]
#         core-auth-key.sh <worker-0>  /root/.ssh/id_rsa.pub
#

#!/bin/bash

SSH_OPTS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=ERROR -o ConnectTimeout=20"

oc_append_key_to_node() {
  local NODE_NAME="$1"
  local LOCAL_FILE="$2"
  local TARGET_FILE="/var/home/core/.ssh/authorized_keys.d/ignition"

  if [[ -z "$NODE_NAME" || -z "$LOCAL_FILE" ]]; then
    echo "Usage: $0 <node-name> <local-key-file>"
    return 1
  fi

  if [[ ! -f "$LOCAL_FILE" ]]; then
    echo "[ERROR] Local file '$LOCAL_FILE' does not exist."
    return 1
  fi

  local TMP_LOG
  TMP_LOG=$(mktemp)

  echo "[INFO] Launching debug pod on node $NODE_NAME (logs: $TMP_LOG)..."

  oc debug node/"$NODE_NAME" -- bash -c "sleep 300" > "$TMP_LOG" 2>&1 &

  sleep 5

  # Extract namespace from log output
  local NAMESPACE
  NAMESPACE=$(grep -oE 'Temporary namespace openshift-debug-[a-z0-9]+' "$TMP_LOG" | head -1 | awk '{print $3}')
  
  if [[ -z "$NAMESPACE" ]]; then
    echo "[ERROR] Could not determine debug namespace from output:"
    cat "$TMP_LOG"
    rm -f "$TMP_LOG"
    return 1
  fi

  echo "[INFO] Using namespace: $NAMESPACE"

  local DEBUG_POD
  DEBUG_POD=$(grep -oE 'Starting pod/[a-z0-9-]+' "$TMP_LOG" | cut -d/ -f2 | tail -1)

  if [[ -z "$DEBUG_POD" ]]; then
    echo "[ERROR] Could not determine debug pod name from output:"
    cat "$TMP_LOG"
    rm -f "$TMP_LOG"
    return 1
  fi

  echo "[INFO] Waiting for debug pod $DEBUG_POD to become ready..."
  
  # Poll every 3 seconds for up to 120 seconds
  local TIMEOUT=120
  local ELAPSED=0
  local POLL_INTERVAL=3
  
  while [ $ELAPSED -lt $TIMEOUT ]; do
    if oc get pod/"$DEBUG_POD" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q "True"; then
      echo "[INFO] Debug pod is ready"
      break
    fi
    sleep $POLL_INTERVAL
    ELAPSED=$((ELAPSED + POLL_INTERVAL))
  done
  
  # Final check
  if ! oc get pod/"$DEBUG_POD" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q "True"; then
    echo "[ERROR] Debug pod did not become ready in time."
    oc delete pod/"$DEBUG_POD" -n "$NAMESPACE" --ignore-not-found > /dev/null 2>&1
    rm -f "$TMP_LOG"
    return 1
  fi

  local TEMP_REMOTE_FILE="/tmp/$(basename "$LOCAL_FILE")"
  echo "[INFO] Copying local key file to $TEMP_REMOTE_FILE on node..."
  if ! oc cp "$LOCAL_FILE" "$NAMESPACE/$DEBUG_POD:/host$TEMP_REMOTE_FILE"; then
    echo "[ERROR] Failed to copy key file into debug pod."
    oc delete pod/"$DEBUG_POD" -n "$NAMESPACE" --ignore-not-found > /dev/null 2>&1
    rm -f "$TMP_LOG"
    return 1
  fi

  echo "[INFO] Appending key file content to $TARGET_FILE on node (newline if needed)..."
  if ! oc exec -n "$NAMESPACE" "$DEBUG_POD" -- chroot /host /bin/bash -c '
    mkdir -p "$(dirname "'"$TARGET_FILE"'")"
    if [[ -f "'"$TARGET_FILE"'" && $(tail -c1 "'"$TARGET_FILE"'") != "" ]]; then
      printf "\n" >> "'"$TARGET_FILE"'"
    fi
    cat "'"$TEMP_REMOTE_FILE"'" >> "'"$TARGET_FILE"'"
    chmod 600 "'"$TARGET_FILE"'"
    chown core:core "'"$TARGET_FILE"'"
    rm "'"$TEMP_REMOTE_FILE"'"
  '; then
    echo "[ERROR] Failed to append key file on node."
    oc delete pod/"$DEBUG_POD" -n "$NAMESPACE" --ignore-not-found > /dev/null 2>&1
    rm -f "$TMP_LOG"
    return 1
  fi

  echo "[INFO] Cleaning up debug pod $DEBUG_POD..."
  oc delete pod/"$DEBUG_POD" -n "$NAMESPACE" --ignore-not-found > /dev/null 2>&1

  rm -f "$TMP_LOG"
  echo "[SUCCESS] Appended '$LOCAL_FILE' content to '$NODE_NAME:$TARGET_FILE'"
}

node_ip=$(kubectl get node $1 -o json | jq -r '.status.addresses[] | select(.type=="InternalIP") | .address | select(contains("."))')
if [ -z "$node_ip" ]; then
    echo "Error: Could not get IP for node $1" >&2
    exit 1
fi

if ssh $SSH_OPTS core@$node_ip "pwd" ; then
    # ssh core@<node_ip> is ready
    exit 0
fi

# If script is called directly, run the function with arguments
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  oc_append_key_to_node "$@" || exit 1
  exit 0
fi


echo oc_append_key_to_node  "$1"   "$2"
#oc_append_key_to_node  "$1"   "$2"

#example: oc_append_key_to_node worker-0  /root/.ssh/id_rsa.pub
