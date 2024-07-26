#!/bin/sh
# Cleanup EIP 
# 	 1- oc delete the EIP object.
# 	 2- Re-enable "egress-asignable" annotation to all nodes  with "gateway" in their name.
# 	    (At the moment our test only test 1 GW node)
#

set -euo pipefail

source ./setting.env
source ./functions.sh
SINGLE_STEP=${SINGLE_STEP:-false}
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

# EOF
