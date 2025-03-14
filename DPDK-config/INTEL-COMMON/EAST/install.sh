#!/bin/bash

PAUSE=${PAUSE:-false}
SINGLE_STEP=${SINGLE_STEP:-false}

if [ $PAUSE == true ]; then
  echo true PAUSE=$PAUSE
fi

#set -euo pipefail
source ./setting.env
source ../../common/functions.sh

parse_args $@


mkdir -p ${MANIFEST_DIR}/

if [ -z "${WORKER_LIST}"  ]; then
    echo no WORKER_LIST
    exit
else
    echo WORRER_LIST=$WORKER_LIST
fi
echo Use mcp $MCP 

export OCP_CHANNEL=$(get_ocp_channel)

# step1 - install sriov Operator
function install_sriov_operator {
    # Debug: oc get csv -n openshift-sriov-network-operator -o custom-columns=Name:.metadata.name,Phase:.status.phase
    #        oc get network.operator -o yaml | grep routing
    #        ( look for =>  routingViaHost: false )
    # oc get csv -n openshift-sriov-network-operator
    # oc get SriovNetworkNodeState -n openshift-sriov-network-operator worker-0


    # install SRIOV operator
    # skip if sriov operator subscription already exists 
    if oc get Subscription sriov-network-operator-subscription -n openshift-sriov-network-operator &>/dev/null; then 
        echo "SRIOV Operator already installed: done"
    else
        #// Installing SR-IOV Network Operator done
        echo "Installing SRIOV Operator ..."
        export OCP_CHANNEL=$(get_ocp_channel)
        envsubst < templates/sub-sriov.yaml.template > ${MANIFEST_DIR}/sub-sriov.yaml
        RUN_CMD oc create -f ${MANIFEST_DIR}/sub-sriov.yaml
        echo "install SRIOV Operator: done"
        RUN_CMD wait_pod_in_namespace openshift-sriov-network-operator
        # give it a little delay. W/o delay we could encounter error on the next command.
        sleep 10
    fi
}

install_sriov_operator
DPRINT $LINENO "next is creating $MCP mcp"
prompt_continue

# step 2 - Create $MCP mcp

function configure_mcp {
    if oc get mcp $MCP  &>/dev/null; then
        echo "mcp $MCP exists. No need to create new"
    else
        echo "create mcp for $MCP ..."
        mkdir -p ${MANIFEST_DIR}
        envsubst < templates/mcp-intel-vf.yaml.template > ${MANIFEST_DIR}/mcp-intel-vf.yaml
        RUN_CMD oc create -f ${MANIFEST_DIR}/mcp-intel-vf.yaml
        echo "create mcp for $MCP: done"
    fi
}

# Create a new MCP, but if cluster is SNO or compact we only have masters, and hence use master MCP.
if [ ! -z "${WORKER_LIST}" ]; then
    configure_mcp
else
    echo "Cluster has no workers. Will use master mcp"
fi

# step 3 - label nodes that needs SRIOV

function add_label {
    if [ ! -z $WORKER_LIS} ]; then
        for NODE in $WORKER_LIST; do
            echo label $NODE with $MCP
            RUN_CMD oc label --overwrite node ${NODE} node-role.kubernetes.io/${MCP}=""
        done
    else
        echo "Cluster has no workers. No need to label master nodes"
    fi
}
DPRINT $LINENO "next is add node-role label"
add_label

# add this if necessary
function add_mc_realloc {
    if  oc get mc 99-pci-realloc-$MCP &>/dev/null ; then
        echo mc pci-realloc exists. No need to create this mc
    else
        echo "create mc mc-realloc.yaml ..."
        envsubst < templates/mc-realloc.yaml.template > ${MANIFEST_DIR}/mc-realloc.yaml
        RUN_CMD oc create -f ${MANIFEST_DIR}/mc-realloc.yaml
        echo "create mc-realloc.yaml: done"
    fi
}

if [ ${NIC_MODEL} == "CX6" ]; then
   DPRINT $LINDO "next, add add_mc_realloc"
   prompt_continue
   add_mc_realloc
fi

DPRINT $LINENO "next is config_SriovNetworkNodePolicy"
prompt_continue

if [ $PAUSE == true ]; then
  RUN_CMD pause_mcp
fi

# step 5  - SiovNetworkNodePolicy. Tell it what SRIOV devices (mlx, 710 etc) to be activated.

function config_SriovNetworkNodePolicy {
    ##### Configuring the SR-IOV network node policy
    echo "Acquiring SRIOV interface PCI info from worker node ${WORKER_LIST} ..."
    WORKER_ARR=(${WORKER_LIST})
    # assuming all worker NICs are in same PCI slot
    export INTEL_INTERFACE_PCI=$(exec_over_ssh ${WORKER_ARR[0]} "ethtool -i ${INTEL_INTERFACE}" | awk '/bus-info:/{print $NF;}')
    echo "Acquiring SRIOV interface PCI info from worker node ${WORKER_LIST}: done"

    # step 1 - create sriov-node-policy.yaml from template
    # 
    envsubst < templates/sriov-node-policy.yaml.template > ${MANIFEST_DIR}/sriov-node-policy.yaml
    echo "generating ${MANIFEST_DIR}/sriov-node-policy.yaml: done"
    # step 2 - apply

    for NODE in ${WORKER_LIST}; do
        RUN_CMD oc label --overwrite node $NODE feature.node.kubernetes.io/network-sriov.capable=true
    done

    if oc get SriovNetworkNodePolicy $DIR-sriov-node-policy -n openshift-sriov-network-operator  2>/dev/null; then
        echo "SriovNetworkNodePolicy exists. Skip creation"
    else
        echo "create SriovNetworkNodePolicy ..."
        RUN_CMD oc create -f ${MANIFEST_DIR}/sriov-node-policy.yaml
        echo "create SriovNetworkNodePolicy: done"
        if [ $PAUSE == true ]; then
           RUN_CMD wait_mcp
        fi
        # !!!!! node reboot !!!!
    fi
}
config_SriovNetworkNodePolicy
# !!! reboot

function create_network {
    # debug:  oc get SriovNetwork/sriov-node-policy.yaml.template
    envsubst < templates/testpmd-sriov-network.yaml.template > ${MANIFEST_DIR}/testpmd-sriov-network.yaml
    if oc get SriovNetwork/$DIR-testpmd-sriov-network -n openshift-sriov-network-operator  &>/dev/null; then
        echo "SriovNetworkexists. Skip creation"
    else
        echo "create SriovNetwork ..."
        RUN_CMD oc create -f ${MANIFEST_DIR}/testpmd-sriov-network.yaml
        echo "create SriovNetwork testpmd-sriov-network.yaml  done"
    fi
}

# create SriovNetwork
DPRINT $LINENO "next is create SriovNetwork"
prompt_continue
create_network

# Done
