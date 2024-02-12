#!/bin/bash

#set -euo pipefail
source ./setting.env
source ./functions.sh

parse_args $@

if [ -z "${WORKER_LIST}" ]; then
    export MCP=master   
fi

if oc get networkattachmentdefinition.k8s.cni.cncf.io/$VENDOR-$DIR-testpmd-net-attach-def &>/dev/null; then
    echo "remove NetworkAttachmentDefinition ..."
    oc delete -f ${MANIFEST_DIR}/net-attach-def.yaml
    echo "remove NetworkAttachmentDefinition: done"
else
    echo "No NetworkAttachmentDefinition to remove"

fi
prompt_continue


# step 2 - apply
#set -uo pipefail

if oc get SriovNetworkNodePolicy sriov-node-policy -n openshift-sriov-network-operator  &>/dev/null; then
    echo "remove SriovNetworkNodePolicy ..."
    oc delete -f ${MANIFEST_DIR}/sriov-node-policy.yaml
    echo "remove SriovNetworkNodePolicy: done"
    wait_mcp
    # !!!! reboot !!!!

else
    echo "No SriovNetworkNodePolicy to remove"
fi

echo "short circuit removing SriovNetworkPoolConfig  ..."
exit


echo "Will remove SriovNetworkPoolConfig, and reboot if continue"
prompt_continue

# step 3 - delete
function rm_SriovNetworkPoolConfig {

 if oc get SriovNetworkPoolConfig -n openshift-sriov-network-operator &>/dev/null; then
    echo "remove SriovNetworkPoolConfig ..."
    oc delete -f ${MANIFEST_DIR}/sriov-pool-config.yaml
    wait_mcp

    # !!!! reboot !!!!
    rm ${MANIFEST_DIR}/sriov-pool-config.yaml 
    echo "remove SriovNetworkPoolConfig: done"
 else
    echo "No SriovNetworkPoolConfig to remove"
 fi

}

rm_SriovNetworkPoolConfig
#!!!! reboot !!!!

echo "Continue if you want to also remove the mcp-offload mcp  ..."
prompt_continue

#echo "short circuit mcp mcp-offloading removal  ..."
#exit

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

if oc get mcp mcp-offloading -n openshift-sriov-network-operator &>/dev/null; then
    echo "remove mcp for mcp-offloading  ..."
    oc delete -f ${MANIFEST_DIR}/mcp-offloading.yaml
    rm  -f ${MANIFEST_DIR}/mcp-offloading.yaml
    echo "delete mcp for mcp-offloading: done"
else
    echo "No mcp mcp-offloading to remove."
fi

echo "Continue if you want to also remove the SRIOV Operator ..."
prompt_continue

if oc get Subscription sriov-network-operator-subsription -n openshift-sriov-network-operator &>/dev/null; then
    echo "Remove  SRIOV Operator ..."
    oc delete -f ${MANIFEST_DIR}/sub-sriov.yaml
    rm ${MANIFEST_DIR}/sub-sriov.yaml
fi


