#!/bin/sh

# Install PAO and performanceprofile for SNO or regular cluster
#
# Note::
#    - for non-SNO: hardcode 2 CPUs for housekeeping workloads.

set -euo pipefail
source ./setting.env
source ./functions.sh
export WORKER_LIST=${WORKER_LIST:-}

parse_args $@

# step 1 - label workers
for worker in $WORKER_LIST; do
   oc label --overwrite node ${worker} node-role.kubernetes.io/${MCP}=""
done

# step 2 - create a new MCP
if ! oc get mcp $MCP 2>/dev/null; then
    echo "create mcp for $MCP ..."
    mkdir -p ${MANIFEST_DIR}
    envsubst < templates/mcp-worker-cnf.yaml.template > ${MANIFEST_DIR}/mcp-${MCP}.yaml
    oc create -f ${MANIFEST_DIR}/mcp-${MCP}.yaml
    echo "create mcp for ${MCP}: done"
fi

# make sure MCP is labeled
if oc get mcp ${MCP} ; then
   oc label --overwrite mcp ${MCP} machineconfiguration.openshift.io/role=${MCP}
fi

mkdir -p ${MANIFEST_DIR}/

##### Step 3 - SKIP install PAO since version > 4.10 

###### Step 4 - generate performance profile and install ######
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

echo "apply ${MANIFEST_DIR}/performance_profile.yaml ..."
oc apply -f ${MANIFEST_DIR}/performance_profile.yaml

sleep 10

if [[ "${WAIT_MCP}" == "true" ]]; then
    wait_mcp ${MCP}
fi

echo "apply ${MANIFEST_DIR}/performance_profile.yaml: done"
#EOF
