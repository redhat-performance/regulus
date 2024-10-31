#!/bin/bash

#set -euo pipefail
source ./setting.env
source ./functions.sh

SINGLE_STEP=${SINGLE_STEP:-false}
PAUSE=${PAUSE:-false}

parse_args $@

if oc get network-attachment-definition/regulus-sriov-net -n ${MCP} &>/dev/null; then
    echo "remove SriovNetwork ..."
    oc delete  network-attachment-definition/regulus-sriov-net -n  ${MCP}
    echo "remove NetworkAttachmentDefinition: done"
else
    echo "No NetworkAttachmentDefinition to remove"
fi

echo "Next remove SriovNetworkNodePolicy ..."
prompt_continue


if oc get SriovNetworkNodePolicy regulus-sriov-node-policy -n openshift-sriov-network-operator  &>/dev/null; then
    echo "remove SriovNetworkNodePolicy ..."
    oc delete SriovNetworkNodePolicy regulus-sriov-node-policy -n openshift-sriov-network-operator
    echo "remove SriovNetworkNodePolicy: done"
    # !!!! reboot !!!! if not paused

else
    echo "No SriovNetworkNodePolicy to remove"
fi

# MCP may not go to UPDATING after removing SriovNetworkNodePolicy
wait_mcp

echo "Next remove node labels ..."
prompt_continue

# step 2 - remove label from nodes
if [ "${MCP}" != "master" ]; then
    echo "removing worker node labels"
    for NODE in $WORKER_LIST; do
        oc label --overwrite node ${NODE} node-role.kubernetes.io/${MCP}-
    done
fi

# MCP does go to UPDATING after clear label.
wait_mcp

#done

