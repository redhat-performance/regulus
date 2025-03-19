#!/bin/bash

SINGLE_STEP=${SINGLE_STEP:-false}

#set -euo pipefail
source ./setting.env
source ../../common/functions.sh


parse_args $@

if [ -z "${WORKER_LIST}" ]; then
    export MCP=master   
fi

if oc get SriovNetwork/$DIR-testpmd-sriov-network -n openshift-sriov-network-operator &>/dev/null; then
    echo "remove SriovNetwork ..."
    RUN_CMD oc delete SriovNetwork/$DIR-testpmd-sriov-network -n openshift-sriov-network-operator
    echo "remove SriovNetwork: done"
else
    echo "No SriovNetwork to remove"

fi

echo "Next remove SriovNetworkNodePolicy ..."
prompt_continue


# step 2 - apply
#set -uo pipefail

if oc get SriovNetworkNodePolicy $DIR-sriov-node-policy -n openshift-sriov-network-operator  &>/dev/null; then
    echo "remove SriovNetworkNodePolicy ..."
    RUN_CMD oc delete  SriovNetworkNodePolicy $DIR-sriov-node-policy -n openshift-sriov-network-operator
    echo "remove SriovNetworkNodePolicy: done"
    #wait_mcp
    # !!!! reboot !!!!

else
    echo "No SriovNetworkNodePolicy to remove"
fi

echo "short remove the mcp $MCP ..."
exit

echo "Continue if you want to also remove the $MCP mcp  ..."
prompt_continue

# step 2 - remove label from nodes
if [ ! -z "${WORKER_LIST}" ]; then
    echo "removing worker node labels"
    for NODE in $WORKER_LIST; do
        oc label --overwrite node ${NODE} node-role.kubernetes.io/${MCP}-
    done
else
    echo "removing master node labels"
    for NODE in $MASTER_LIST; do
        oc label --overwrite node ${NODE} node-role.kubernetes.io/${MCP}-
    done
fi

if oc get mcp $MCP -n openshift-sriov-network-operator &>/dev/null; then
    echo "remove mcp for mcp-offloading  ..."
    oc delete -f ${MANIFEST_DIR}/mcp-intel-vf.yaml
    rm  -f ${MANIFEST_DIR}/mcp-intel-vf.yaml
    echo "delete mcp for $MCP done"
else
    echo "No mcp $MCP to remove."
fi

echo "short remoing SRIOV Operator ..."
exit

echo "Continue if you want to also remove the SRIOV Operator ..."
prompt_continue

if oc get Subscription sriov-network-operator-subscription -n openshift-sriov-network-operator &>/dev/null; then
    echo "Remove  SRIOV Operator ..."
    oc delete -f ${MANIFEST_DIR}/sub-sriov.yaml
    rm ${MANIFEST_DIR}/sub-sriov.yaml
fi

#done

