#!/bin/sh

# Install PAO and performanceprofile for SNO or regular cluster
#
# Note::
#    - for non-SNO: hardcode 2 CPUs for housekeeping workloads.

source ./setting.env
source ./functions.sh
export WORKER_LIST=${WORKER_LIST:-}
SINGLE_STEP=${SINGLE_STEP:-true}
export OCP_PROJECT=${OCP_PROJECT:-crucible-hnhan}

parse_args $@

# step 1 - keep only the GW node that we want to handle EIP
echo "Next, exclude unintended GW nodes from egressIP"
EGRESS_NODES=$(kubectl get nodes --selector=k8s.ovn.org/egress-assignable --no-headers | awk '{ print $1 }')
# Convert the list into an array
IFS=' ' read -r -a GW_ARRAY <<< "$GW_LIST"
for node in $EGRESS_NODES; do
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
    echo "create egressIP egress-$OCP_PROJECT  ..."
    mkdir -p ${MANIFEST_DIR}
    envsubst < templates/egress-crucible.yaml.template > ${MANIFEST_DIR}/egress-crucible.yaml
    oc create -f ${MANIFEST_DIR}/egress-crucible.yaml
    echo "create egressIP egress-$OCP_PROJECT  done"
else
    echo "egressIP egress-$OCP_PROJECT exists"
fi

prompt_continue
exit

# make sure MCP is labeled
if oc get mcp ${MCP} &> /dev/null ; then
   oc label --overwrite mcp ${MCP} machineconfiguration.openshift.io/role=${MCP}
fi

mkdir -p ${MANIFEST_DIR}/

# Step 3 - generate performance profile and install it 
echo "Acquiring cpu info from first worker node in ${WORKER_LIST} ..."
FIRST_WORKER=$(echo ${WORKER_LIST} * | head -n1 | awk '{print $1;}')
all_cpus=$(exec_over_ssh ${FIRST_WORKER} lscpu | awk '/On-line CPU/{print $NF;}')
export RESERVED_CPUS=
for N in {0..1}; do
    #add sibbling pair and a comma ','
    if [ $N -gt 0 ]; then
        RESERVED_CPUS+=","
    fi
    RESERVED_CPUS+=$(exec_over_ssh ${FIRST_WORKER} "cat /sys/bus/cpu/devices/cpu$N/topology/thread_siblings_list")
done
echo RESERVED_CPUS=$RESERVED_CPUS

PYTHON=$(get_python_exec)
export ISOLATED_CPUS=$(${PYTHON} cpu_cmd.py cpuset-substract ${all_cpus} ${RESERVED_CPUS})
echo "Acquiring cpu info from worker node ${FIRST_WORKER}: done"

echo "generating ${MANIFEST_DIR}/performance_profile.yaml ..."
envsubst < templates/performance_profile.yaml.template > ${MANIFEST_DIR}/performance_profile.yaml
echo "generating ${MANIFEST_DIR}/performance_profile.yaml: done"

if oc get mcp PerformanceProfile &>/dev/null; then
    echo "Skip. A performanceprofile exists"
    exit
fi
echo "next is is applying performance_profile"
prompt_continue 

echo "apply ${MANIFEST_DIR}/performance_profile.yaml ..."
oc apply -f ${MANIFEST_DIR}/performance_profile.yaml

if [[ "${WAIT_MCP}" == "true" ]]; then
    wait_mcp ${MCP}
fi

echo "apply ${MANIFEST_DIR}/performance_profile.yaml: done"
#EOF
