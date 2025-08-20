#!/bin/bash

SINGLE_STEP=${SINGLE_STEP:-false}

#set -euo pipefail
source ./setting.env
source ../common/functions.sh

MANIFEST_DIR=../generated_manifests

parse_args $@

if [ -z "${WORKER_LIST}" ]; then
    export MCP=master   
fi


echo "Next remove NAD ..."
prompt_continue

if oc get networkattachmentdefinition.k8s.cni.cncf.io/$NAD_NS &>/dev/null; then
    echo "remove NetworkAttachmentDefinition ..."
    RUN_CMD oc delete -f ${MANIFEST_DIR}/net-attach-def.yaml
    echo "remove NetworkAttachmentDefinition: done"
else
    echo "No NetworkAttachmentDefinition to remove"

fi

echo "Next remove SriovNetworkNodePolicy ..."
prompt_continue

pause_mcp

if oc get SriovNetworkNodePolicy hwol-sriov-node-policy -n openshift-sriov-network-operator  &>/dev/null; then
    echo "remove SriovNetworkNodePolicy ..."
    RUN_CMD oc delete  SriovNetworkNodePolicy hwol-sriov-node-policy -n openshift-sriov-network-operator
    echo "remove SriovNetworkNodePolicy: done"
    # !!!! reboot if we did not pause!!!!
    #RUN_CMD wait_mcp

else
    echo "No SriovNetworkNodePolicy to remove"
fi

echo "Next remove SriovNetworkPoolConfig, and reboot if continue"
prompt_continue

function rm_SriovNetworkPoolConfig {

 if oc get SriovNetworkPoolConfig -n openshift-sriov-network-operator &>/dev/null; then
    echo "remove SriovNetworkPoolConfig ..."
    RUN_CMD oc delete -f ${MANIFEST_DIR}/sriov-pool-config.yaml
    rm ${MANIFEST_DIR}/sriov-pool-config.yaml
    echo "remove SriovNetworkPoolConfig: done"
 else
    echo "No SriovNetworkPoolConfig to remove"
 fi

}
rm_SriovNetworkPoolConfig
# !!!! reboot as wait_mcp will initiate a resume !!!!
RUN_CMD wait_mcp

# remove label from nodes
if [ ! -z "${WORKER_LIST}" ]; then
    echo "removing worker node labels"
    for NODE in $WORKER_LIST; do
        RUN_CMD oc label --overwrite node ${NODE} node-role.kubernetes.io/${MCP}-
    done
else
    echo "removing master node labels"
    for NODE in $MASTER_LIST; do
        RUN_CMD oc label --overwrite node ${NODE} node-role.kubernetes.io/${MCP}-
    done
fi

#echo "short remove the mcp $MCP ..."
#exit

echo "Continue if you want to also remove the $MCP mcp  ..."
prompt_continue

# step 2 - remove label from nodes
if [ ! -z "${WORKER_LIST}" ]; then
    echo "removing worker node labels"
    for NODE in $WORKER_LIST; do
        oc label node ${NODE} node-role.kubernetes.io/${MCP}-
    done
else
    echo "removing master node labels"
    for NODE in $MASTER_LIST; do
        oc label node ${NODE} node-role.kubernetes.io/${MCP}-
    done
fi

if oc get mcp $MCP -n openshift-sriov-network-operator &>/dev/null; then
    echo "remove mcp  ..."
    oc delete -f ${MANIFEST_DIR}/mcp-hwol.yaml
    rm  -f ${MANIFEST_DIR}/mcp-hwol.yaml
    echo "delete mcp for $MCP done"
else
    echo "No mcp $MCP to remove."
fi

echo "($LINENO) short, Skip removing SRIOV Operator ..."
exit

echo "Continue if you want to also remove the SRIOV Operator ..."
prompt_continue

if oc get sriovoperatorconfig -n openshift-sriov-network-operator &>/dev/null; then 
    echo "Remove SRIOV Operator config ..."
    oc delete sriovoperatorconfig openshift-sriov-network-operator -n openshift-sriov-network-operator
    rm ${MANIFEST_DIR}/sriov-operator-config.yaml
fi

if oc get Subscription sriov-network-operator-subscription -n openshift-sriov-network-operator &>/dev/null; then
    echo "Remove  SRIOV Operator ..."
    oc delete -f ${MANIFEST_DIR}/sub-sriov.yaml
    rm ${MANIFEST_DIR}/sub-sriov.yaml
fi

#done

