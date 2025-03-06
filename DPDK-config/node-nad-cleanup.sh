#!/bin/bash

#set -euo pipefail
source ./setting.env
source ./functions.sh

SINGLE_STEP=${SINGLE_STEP:-false}
PAUSE=${PAUSE:-false}

parse_args $@

if oc get network-attachment-definition/sriov-dpdk-net -n ${MCP} &>/dev/null; then
    echo "remove SriovNetwork ..."
    oc delete  network-attachment-definition/sriov-dpdk-net -n  ${MCP}
    echo "remove NetworkAttachmentDefinition: done"
else
    echo "No NetworkAttachmentDefinition to remove"
fi

echo "Next remove SriovNetworkNodePolicy ..."
prompt_continue


if oc get SriovNetworkNodePolicy sriov-dpdk-net -n openshift-sriov-network-operator  &>/dev/null; then
    echo "remove SriovNetworkNodePolicy ..."
    oc delete SriovNetworkNodePolicy sriov-dpdk-net -n openshift-sriov-network-operator
    echo "remove SriovNetworkNodePolicy: done"
    # !!!! reboot !!!! if not paused

else
    echo "No SriovNetworkNodePolicy to remove"
fi

# MCP may not go to UPDATING after removing SriovNetworkNodePolicy
wait_mcp

#done

