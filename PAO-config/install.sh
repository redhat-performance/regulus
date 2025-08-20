#!/bin/sh

# Install PAO and performanceprofile for SNO or regular cluster
#
# Note::
#    - for non-SNO: hardcode 2 CPUs for housekeeping workloads.

source ${REG_ROOT}/lab.config
source ./setting.env
source ./functions.sh
export WORKER_LIST=${WORKER_LIST:-}
SINGLE_STEP=${SINGLE_STEP:-true}

parse_args $@

# Step 0 - If there is a mcp that is not mcp-regulus-vf, the cluster is not in a known state
function f_ensure_no_other_mcps {
  OTHER_MCPS=$(oc get mcp  --no-headers | awk '{print $1}' | grep -v "worker\|master")
  if [ ! -z "$OTHER_MCPS" ] && [ "${OTHER_MCPS}" != "${MCP}" ];  then
    echo "Other mcp(s) $OTHER_MCPS exist(s)."
    echo "Fix it before continue installing ${MCP}"
    exit
  fi
}

if [ "${MCP}" != "master" ]; then
    # It is  a STANDARD cluster
    RUN_CMD f_ensure_no_other_mcps
fi

# step 1 - label workers unless mcp is "master" implying SNO or 3-node compact.
if [ "${MCP}" != "master" ]; then
    for worker in $WORKER_LIST; do
        RUN_CMD oc label --overwrite node ${worker} node-role.kubernetes.io/${MCP}=""
    done
fi

# step 2 - create a new MCP. For SNO and 3-node compact, we will skip this step since mcp master exists
if ! oc get mcp $MCP &>/dev/null; then
    echo "create mcp for $MCP ..."
    mkdir -p ${MANIFEST_DIR}
    envsubst < templates/mcp-worker-cnf.yaml.template > ${MANIFEST_DIR}/mcp-${MCP}.yaml
    RUN_CMD oc create -f ${MANIFEST_DIR}/mcp-${MCP}.yaml
    echo "create mcp for ${MCP}: done"
fi

echo "Next is label node role ${MCP}"; prompt_continue 

# make sure MCP is labeled
if oc get mcp ${MCP} &> /dev/null ; then
   RUN_CMD oc label --overwrite mcp ${MCP} machineconfiguration.openshift.io/role=${MCP}
fi

mkdir -p ${MANIFEST_DIR}/

echo "Next is getting cpuinfo from 1st of role ${WORKER_LIST}"; prompt_continue 

# Step 3 - generate performance profile and install it 
echo "Acquiring reserved cpu info from first worker node in ${WORKER_LIST} ..."
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
echo "Next is getting isolated cpuinfo from 1st of role ${FIRST_WORKER}"
prompt_continue 

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
RUN_CMD oc apply -f ${MANIFEST_DIR}/performance_profile.yaml

if [[ "${WAIT_MCP}" == "true" ]]; then
    RUN_CMD wait_mcp ${MCP}
fi

echo "apply ${MANIFEST_DIR}/performance_profile.yaml: done"
#EOF
