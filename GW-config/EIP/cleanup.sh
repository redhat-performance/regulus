#!/bin/sh
#
# Cleanup performanceprofile while taking into consideration the SRIOV states.
# 	If SRIOV is still active, leave node labels and MCP alone.
#

set -euo pipefail

source ./setting.env
source ./functions.sh
SINGLE_STEP=${SINGLE_STEP:-true}
export OCP_PROJECT=${OCP_PROJECT:-crucible-hnhan}

parse_args $@


echo "Next, delete egressIP egress-$OCP_PROJECT  ..."
prompt_continue

# Cleanup step 2 - create a new EIP object
if oc get egressIP egress-$OCP_PROJECT &>/dev/null; then
    echo "delete egressIP egress-$OCP_PROJECT  ..."
    oc delete -f ${MANIFEST_DIR}/egress-crucible.yaml
    echo "delete egressIP egress-$OCP_PROJECT  done"
else
    echo "No egressIP egress-$OCP_PROJECT"
fi

echo "Next, return all GW nodes to participate in  egressIP ..."
prompt_continue

# Cleanup step 1 - enable EIP on all GW node
# Get all node names using kubectl and filter with grep
GW_NODES=$(kubectl get nodes -o=jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep '^gateway')
for node in $GW_NODES; do
    echo confirm CMD:  "kubectl label nodes $node k8s.ovn.org/egress-assignable= --overwrite"
	prompt_continue
    kubectl label nodes $node k8s.ovn.org/egress-assignable= --overwrite
done

exit




if oc get SriovNetworkNodePolicy &>/dev/null; then
    echo "SRIOV is still active. Skip the rest. Done"
    exit
fi


echo "Next, remove node labels and MCP ${MCP}"
prompt_continue 

echo "deleting label for $WORKER_LIST ..."
if [ "${MCP}" != "master" ]; then
    # this is STANDARD cluster. Do it.
    for worker in $WORKER_LIST; do
        oc label --overwrite node ${worker} node-role.kubernetes.io/${MCP}-
    done
fi

##### Remove MCP ######
if [ "${MCP}" != "master" ]; then
    # this is STANDARD cluster. Do it.
    if oc get mcp ${MCP} 2>/dev/null; then
        oc delete mcp ${MCP}
        echo "deleted mcp for ${MCP}: done"
    fi
else
    # this is non-standard cluster that uses mcp master. Just remove the label.
    oc label --overwrite mcp ${MCP} machineconfiguration.openshift.io/role-

fi


# EOF
