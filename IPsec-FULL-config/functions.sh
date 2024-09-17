#!/bin/bash

get_ocp_channel () {
    local channel=$(oc get clusterversion -o json | jq -r '.items[0].spec.channel' | sed -r -n 's/.*-(.*)/\1/p')
    echo ${channel}
}

# Function to check if any MCP is not ready by parsing JSON output
mcp_not_ready() {
    # Get the JSON output from `oc get mcp`
    not_ready=$(oc get mcp -o json | jq -r '.items[] | select(.status.conditions[] | select(.type == "Updated").status != "True" or .type == "Updating" and .status != "False") | .metadata.name')

    # If there are any MCPs that are not ready, echo "True" and return success status
    if [[ -n $not_ready ]]; then
        echo "True"
        return 0  # Exit successfully but indicates some MCPs are not ready
    else
        echo "False"
        return 1  # No MCPs are in a not ready state
    fi
}

wait_mcp () {
    local this_mcp=$1
    printf "waiting 30 secs before checking mcp status "
    local count=30
    while [[ $count -gt 0  ]]; do
        sleep 10
        printf "."
        count=$((count-10))
    done

    local status=$(mcp_not_ready)
    count=300
    printf "\npolling 3000 sec for mcp complete, May lose API connection if SNO, during node reboot"
    while [[ $status != "True" ]]; do
        if ((count == 0)); then
            printf "\ntimeout waiting for mcp complete on the baremetal host!\n"
            exit 1
        fi
        count=$((count-1))
        printf "."
        sleep 10
        status=$(mcp_not_ready)
    done
    printf "\nmcp complete on the baremetal host in %d sec\n" $(( (300-count) * 10 ))
}

