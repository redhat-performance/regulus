#!/bin/bash
# allow no confirm mode
# do not unlabel nodes and remove MCP if PAO exist
# do not remove Operator

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

# step 2 - apply
#set -uo pipefail

if oc get SriovNetworkNodePolicy regulus-sriov-node-policy -n openshift-sriov-network-operator  &>/dev/null; then
    echo "remove SriovNetworkNodePolicy ..."
    oc delete SriovNetworkNodePolicy regulus-sriov-node-policy -n openshift-sriov-network-operator
    echo "remove SriovNetworkNodePolicy: done"
    # !!!! reboot !!!! if not paused

else
    echo "No SriovNetworkNodePolicy to remove"
    exit 0
fi

### We are on delete path. Always resume and wait before mucking the node label, and deleting mcp.
### A messed up mcp is harder to fix. Just pay some wait time here is cheaper.
resume_mcp

# MCP may not go to UPDATING after removing SriovNetworkNodePolicy
wait_mcp

echo "Next remove node labels ..."
prompt_continue

if oc get PerformanceProfile ${MCP} &>/dev/null; then
    echo "Performance profile is still active. Skip the rest. Done"
    exit 0
fi

# step 2 - remove label from nodes
if [ "${MCP}" != "master" ]; then
    echo "removing worker node labels"
    for NODE in $WORKER_LIST; do
        oc label --overwrite node ${NODE} node-role.kubernetes.io/${MCP}-
    done
fi

# MCP does go to UPDATING after clear label.
wait_mcp

echo "Next delete the ${MCP} mcp  ..."
prompt_continue

if [ "${MCP}" != "master" ]; then
    if oc get mcp ${MCP} -n openshift-sriov-network-operator &>/dev/null; then
      echo "remove mcp ${MCP}  ..."
      oc delete mcp ${MCP} -n openshift-sriov-network-operator
      rm  -f ${MANIFEST_DIR}/mcp-regulus-vf.yaml
      echo "delete mcp for mcp-regulus-vf: done"
    else
      echo "No mcp ${MCP} to remove."
    fi
else
    oc label --overwrite mcp master machineconfiguration.openshift.io/role-
fi

echo "You don't want to remove SRIOV Operator (esp. web console installed)"
exit

echo "Continue if you want to remove the SRIOV Operator ..."
prompt_continue

if oc get Subscription sriov-network-operator-subscription -n openshift-sriov-network-operator &>/dev/null; then
    echo "Remove  SRIOV Operator ..."
    oc delete Subscription sriov-network-operator-subsription -n openshift-sriov-network-operator
    rm ${MANIFEST_DIR}/sub-sriov.yaml
fi

#done

