#!/bin/bash

#set -euo pipefail
source ./setting.env
source ./functions.sh

PAUSE=${PAUSE:-false}

if [ $PAUSE == true ]; then
  echo mc will NOT apply now due to PAUSE=$PAUSE
  prompt_continue
else
  echo mc will apply due to PAUSE=$PAUSE
fi

parse_args $@

if [ -z "${WORKER_LIST}" ]; then
    export MCP=master   
fi

if oc get network-attachment-definition/$DIR-sriov-net -n openshift-sriov-network-operator &>/dev/null; then
    echo "remove networkAttachment ..."
    oc delete -f ${MANIFEST_DIR}/net-attach-def.yaml
    echo "remove networkAttachment: done"
else
    echo "No networkAttachment to remove"

fi

echo "Next remove SriovNetworkNodePolicy ..."
prompt_continue


# step 2 - apply
#set -uo pipefail

if oc get SriovNetworkNodePolicy $VENDOR-$DIR-sriov-node-policy -n openshift-sriov-network-operator  &>/dev/null; then
    echo "remove SriovNetworkNodePolicy ..."
    oc delete -f ${MANIFEST_DIR}/sriov-node-policy.yaml
    echo "remove SriovNetworkNodePolicy: done"
    wait_mcp
    # !!!! reboot !!!!

else
    echo "No SriovNetworkNodePolicy to remove"
fi

#echo "short  remove the mcp-$VENDOR-vf mcp  ..."
#exit

echo "Continue if you want to also remove the mcp-*-vf mcp  ..."
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

if oc get mcp mcp-$VENDOR-vf -n openshift-sriov-network-operator &>/dev/null; then
    echo "remove mcp for mcp-offloading  ..."
    oc delete -f ${MANIFEST_DIR}/mcp-$VENDOR-vf.yaml
    rm  -f ${MANIFEST_DIR}/mcp-intel-vf.yaml
    echo "delete mcp for mcp-$VENDOR-vf: done"
else
    echo "No mcp mcp-$VENDOR-vf to remove."
fi

echo "short remoing SRIOV Operator ..."
exit

echo "Continue if you want to also remove the SRIOV Operator ..."
prompt_continue

if oc get Subscription sriov-network-operator-subsription -n openshift-sriov-network-operator &>/dev/null; then
    echo "Remove  SRIOV Operator ..."
    oc delete -f ${MANIFEST_DIR}/sub-sriov.yaml
    rm ${MANIFEST_DIR}/sub-sriov.yaml
fi

#done

