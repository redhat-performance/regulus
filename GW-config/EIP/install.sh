#!/bin/sh

#
# Install EIP.
#    Before multi GWs support, this script makes sure only one node function as GW.
#    Then create and apply an EIP object.
#

source ./setting.env
source ./functions.sh
export WORKER_LIST=${WORKER_LIST:-}
SINGLE_STEP=${SINGLE_STEP:-false}
export OCP_PROJECT=${OCP_PROJECT:-crucible-hnhan}

parse_args $@

# step 1 - Keep only the GW node that we want to handle EIP.
#       How? If there are more than 1 node with "k8s.ovn.org/egress-assignable="
#       we will prompt the user to confirm each of node found with "egress-assignable" annotation.
#          
echo "Next, exclude unintended GW nodes from egressIP"
EGRESS_NODES=$(kubectl get nodes --selector=k8s.ovn.org/egress-assignable --no-headers | awk '{ print $1 }')
# Convert the list into an array
IFS=' ' read -r -a GW_ARRAY <<< "$GW_LIST"
for node in $EGRESS_NODES; do
    echo node=$node
	found=0
    # If this node in NOT in GW_LIST, clear its EIP label
	for gw in "${GW_ARRAY[@]}"; do
    	if [[ "$gw" == "$node" ]]; then
        	found=1
        	break
    	fi
	done
	if [ $found != 1 ]; then
    	echo confirm CMD:  "kubectl label nodes $node k8s.ovn.org/egress-assignable- --overwrite"
		prompt_continue
    	echo SKIP kubectl label nodes $node k8s.ovn.org/egress-assignable- --overwrite
	fi
done

echo "Next, create egressIP  egress-$OCP_PROJECT  ..."
prompt_continue

# step 2 - create a new EIP object
if ! oc get egressIP egress-$OCP_PROJECT &>/dev/null; then
    echo "oc create egressIP egress-$OCP_PROJECT  ..."
    mkdir -p ${MANIFEST_DIR}
    envsubst < templates/egress-crucible.yaml.template > ${MANIFEST_DIR}/egress-crucible.yaml
    oc create -f ${MANIFEST_DIR}/egress-crucible.yaml
    echo "oc create egressIP egress-$OCP_PROJECT  done"
else
    echo "oc egressIP egress-$OCP_PROJECT exists"
fi

prompt_continue

