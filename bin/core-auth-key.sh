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
  local NAMESPACE="default"

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

  local DEBUG_POD
  DEBUG_POD=$(grep -oE '^Starting pod/[a-z0-9-]+' "$TMP_LOG" | cut -d/ -f2 | tail -1)

  if [[ -z "$DEBUG_POD" ]]; then
    echo "[ERROR] Could not determine debug pod name from output:"
    cat "$TMP_LOG"
    rm -f "$TMP_LOG"
    return 1
  fi

  echo "[INFO] Waiting for debug pod $DEBUG_POD to become ready..."
  if ! oc wait --for=condition=Ready pod/"$DEBUG_POD" --timeout=60s -n "$NAMESPACE" > /dev/null; then
    echo "[ERROR] Debug pod did not become ready in time."
    oc delete pod/"$DEBUG_POD" -n "$NAMESPACE" --ignore-not-found
    rm -f "$TMP_LOG"
    return 1
  fi

  local TEMP_REMOTE_FILE="/tmp/$(basename "$LOCAL_FILE")"
  echo "[INFO] Copying local key file to $TEMP_REMOTE_FILE on node..."
  if ! oc cp "$LOCAL_FILE" "$NAMESPACE/$DEBUG_POD:/host$TEMP_REMOTE_FILE"; then
    echo "[ERROR] Failed to copy key file into debug pod."
    oc delete pod/"$DEBUG_POD" -n "$NAMESPACE" --ignore-not-found
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
    oc delete pod/"$DEBUG_POD" -n "$NAMESPACE" --ignore-not-found
    rm -f "$TMP_LOG"
    return 1
  fi

  echo "[INFO] Cleaning up debug pod $DEBUG_POD..."
  oc delete pod/"$DEBUG_POD" -n "$NAMESPACE" --ignore-not-found > /dev/null

  rm -f "$TMP_LOG"
  echo "[SUCCESS] Appended '$LOCAL_FILE' content to '$NODE_NAME:$TARGET_FILE'"
}

node_ip=$(kubectl get node $1 -o json | jq -r '.status.addresses[] | select(.type=="InternalIP") | .address | select(contains("."))')
if [ -z "$node_ip" ]; then
    echo "Error: Could not get IP for node $node" >&2
    exit 1
fi

if ssh $SSH_OPTS core@$node_ip "pwd" ; then
    # ssh core@<node_ip> is ready
    exit 0
fi

# If script is called directly, run the function with arguments
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  oc_append_key_to_node "$@"
  exit 0
fi


echo oc_append_key_to_node  "$1"   "$2"
#oc_append_key_to_node  "$1"   "$2"

#example: oc_append_key_to_node worker-0  /root/.ssh/id_rsa.pub

