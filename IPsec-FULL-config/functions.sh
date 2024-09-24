#!/bin/bash

get_ocp_channel () {
    local channel=$(oc get clusterversion -o json | jq -r '.items[0].spec.channel' | sed -r -n 's/.*-(.*)/\1/p')
    echo "${channel}"
}

ipsec_is_enable () {
    local channel="$(get_ocp_channel)"
    
    if [[ "$channel" == "4.14" ]]; then
        # Handle for 4.14 channel
        output=$(oc get networks.operator.openshift.io cluster -o json | jq '.spec.defaultNetwork.ovnKubernetesConfig.ipsecConfig')
        if [[ "$output" == "null" || -z "$output" ]]; then
            echo "False"
        else
            echo "True"
        fi
    else
        # Handle for 4.15 and later
        output=$(oc get networks.operator.openshift.io cluster -o json | jq -r '.spec.defaultNetwork.ovnKubernetesConfig.ipsecConfig.mode')
        if [[ "$output" == "Disabled" || -z "$output" ]]; then
            echo "False"
        else
            echo "True"
        fi
    fi
}

upd_machcount=0

# Function to return "True" if any MCP is not ready (UPDATED!=True or UPDATING!=False)
mcp_not_ready() {
    local output=$(oc get mcp -o json 2>&1)
    local return_code=$?
    local not_ready=""
    if [ $return_code -ne 0 ]; then
        echo "Command failed with exit code $return_code, $output. Retry"
        not_ready="True"
    elif echo "$output" | grep -i "error"; then
        echo "Command succeeded but found error message in the output. Retry"
        not_ready="True"
    else
        # Command succeeded without errors.
        not_ready=$(echo "$output" | jq -r '.items[] | select((.status.conditions[] | select(.type == "Updated").status != "True") or (.status.conditions[] | select(.type == "Updating").status != "False")) | .metadata.name' 2>&1)
        # also note the UPDATEDMACHINECOUNT value
        upd_machcount=$(echo "$output" | jq -r '.items[] | {name: .metadata.name, updatedMachineCount: .status.updatedMachineCount}')
    fi

    # If there are any MCPs that are not ready, echo "True" and return success status
    if [[ -n "$not_ready" ]]; then
        echo "True"
        return 0  # Exit successfully but indicates some MCPs are not ready
    else
        echo "False"
        return 1  # No MCPs are in a not ready state
    fi
}

# Retry to confirm the statement of "mcp not ready is <IN>"
# IN: True/False
# IN: max - timeout value if not making progress. We monitor the mcp UPDATEDMACHINECOUNT value. 
# OUT:True  - statement is true
#     False - statement is false 
#
wait_mcp_state_not_ready_core () {
    local last_upd_machcount=0
    local state=$1
    local max=$2
    local timeout=$max
    local count=0
    local status=$(mcp_not_ready)
    printf "\npolling $max sec for mcp 'not_ready'==$state. May lose API connection if SNO, during node reboot" >&2
    while [[ "$status" != "$state" ]]; do
        if ((count >= timeout)); then
            printf "\nTimeout waiting for mcp 'not_ready'=$state, status=$status after $count sec.!\n" >&2
            echo "False"
            return
        fi
        count=$((count + 10))
        printf "." >&2
        sleep 10
        status=$(mcp_not_ready)
        if [[ "$upd_machcount" -ne "$last_upd_machcount" ]]; then
           # extend expiration time since we are making progress
           last_upd_machcount=$upd_machcount
           timeout=$((count + max))
        fi
    done
    printf "\nFound mcp 'not_ready'==$state in %d sec\n" $count >&2
    echo "True"
}

# return True if the mcp is ready, False otherwise
wait_mcp_state_ready () {
    local max=$1
    wait_mcp_state_not_ready_core "False" $max
}

# return True if mcp is NOT ready, False otherwise
wait_mcp_state_not_ready () {
    local max=$1
    wait_mcp_state_not_ready_core "True" $max
}

