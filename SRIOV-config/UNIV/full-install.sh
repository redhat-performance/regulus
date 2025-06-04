#!/bin/bash


# FLow:
#          STANDARD                                                             SNO
# 1. install SRIOV operator                                     1. install SRIOV operator
# 2. create a new MCP                                           2. (reuse) MCP=master, label mcp master, machineconfiguration.openshift.io/role=master
# 3. label to worker node, node-role.kubernetes.io/${MCP}="     3. none
# 4. config SriovNetworkNodePolicy (applied to node-role $MCP"  4. config SriovNetworkNodePolicy  (applied to node-role:master)
#

# do not create new MCP if available
# do not remove Operator
# allow no confirm mode

source ${REG_ROOT}/lab.config
source ${REG_ROOT}/SRIOV-config/config.env

SINGLE_STEP=${SINGLE_STEP:-true}
PAUSE=${PAUSE:-false}

if [ $PAUSE == true ]; then
  # Do not update mcp yet.
  echo true PAUSE=$PAUSE
fi

#set -euo pipefail
source ../setting.env
source ./functions.sh

parse_args $@

mkdir -p ${MANIFEST_DIR}/

if [ -z "$WORKER_LIST"  ]; then
    echo no WORRKER_LIST
    exit
fi
echo Use mcp $MCP 

export OCP_CHANNEL=$(oc get packagemanifest sriov-network-operator -n openshift-marketplace -o json | jq -r '.status.channels[0].name')

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
        envsubst '$OCP_CHANNEL' < templates/sub-sriov.yaml.template > ${MANIFEST_DIR}/sub-sriov.yaml
        ECHO oc create -f ${MANIFEST_DIR}/sub-sriov.yaml
        echo "install SRIOV Operator: done"
        ECHO wait_pod_in_namespace openshift-sriov-network-operator
        # give it a little delay. W/o delay we could encounter error on the next command.
        ECHO sleep 10
    fi

    ### install SRIOV operator config. Required since 4.18
    if oc get sriovoperatorconfig  -n openshift-sriov-network-operator &>/dev/null; then 
        echo "SRIOV Operator config already installed: done"
    else
        echo "Installing SRIOV Operator config ..."
        envsubst  < templates/sriov-operator-config.yaml.template > ${MANIFEST_DIR}/sriov-operator-config.yaml
        ECHO oc create -f ${MANIFEST_DIR}//sriov-operator-config.yaml
        echo "install SRIOV Operator: done"
        ECHO sleep 10
    fi

}

install_sriov_operator

# step 2 -Create mcp-regulus-vf mcp for STANDARD cluster
#         For SNO and 3-node compact, setting.env has MCP=master, hence we do not skip creation.

function configure_mcp {
    if oc get mcp ${MCP}  &>/dev/null; then
        echo "mcp ${MCP} exists. No need to create new"
    else
        echo "create mcp for ${MCP}  ..."
        mkdir -p ${MANIFEST_DIR}
        envsubst < templates/mcp-regulus-vf.yaml.template > ${MANIFEST_DIR}/mcp-regulus-vf.yaml
        ECHO oc create -f ${MANIFEST_DIR}/mcp-regulus-vf.yaml
        echo "create mcp for ${MCP} done"
    fi
}

echo "next is creating ${MCP} mcp"
prompt_continue

# Create a new MCP, but if cluster is SNO or 3-node compact, only mcp master has nodes, and we must use mcp master.
#                   Higher level should have set setting.env with "MCP=master" to indicate.
if [ "${MCP}" != "master" ]; then
    ECHO configure_mcp
else
    echo "Will use master mcp"
    # Put a label on master mcp so that new MCs can select.
    ECHO oc label --overwrite mcp master machineconfiguration.openshift.io/role=master
fi

# step 3 - label nodes that needs SRIOV

function add_label {
    if [ "$MCP}" != "master" ]; then
        for NODE in $WORKER_LIST; do
            echo label $NODE with $MCP
            ECHO oc label --overwrite node ${NODE} node-role.kubernetes.io/${MCP}=""
        done
    else
        echo "Cluster has no workers. No need to label master nodes"
    fi
}
add_label

# MCP goes to UPDATING after add label
wait_mcp

# add this if necessary
function add_mc_realloc {
    if  oc get mc 99-pci-realloc-$MCP &>/dev/null ; then
        echo mc pci-realloc exists. No need to create this mc
    else
        echo "create mc mc-realloc.yaml ..."
        envsubst < templates/mc-realloc.yaml.template > ${MANIFEST_DIR}/mc-realloc.yaml
        ECHO oc create -f ${MANIFEST_DIR}/mc-realloc.yaml
        echo "create mc-realloc.yaml: done"
    fi
}

if [ ${NIC_MODEL} == "CX6" ]; then
   echo "next, add add_mc_realloc"
   prompt_continue
   add_mc_realloc
fi


if [ $PAUSE == true ]; then
  ECHO pause_mcp
fi

# step 5  - SriovNetworkNodePolicy. Tell it what SRIOV devices (mlx, 710 etc) to be activated.

function config_SriovNetworkNodePolicy {
    ##### Configuring the SR-IOV network node policy
    echo "Acquiring SRIOV interface PCI info from worker node ${WORKER_LIST} ..."
    WORKER_ARR=(${WORKER_LIST})
    # assuming all worker NICs are in same PCI slot
    export REGULUS_INTERFACE_PCI=$(exec_over_ssh ${WORKER_ARR[0]} "ethtool -i ${REGULUS_INTERFACE}" | awk '/bus-info:/{print $NF;}')
    echo "Acquiring SRIOV interface PCI_add= $REGULUS_INTERFACE_PCI from worker node ${WORKER_LIST}: done"

    # step 1 - create sriov-node-policy.yaml from template
    # 
    if [ ! -f ./templates/${NIC_MODEL}/sriov-node-policy.yaml.template ]; then
        echo "./templates/${NIC_MODEL}/sriov-node-policy.yaml.template not exist"
        echo "Please check for valid NIC_MODEL in setting.env"
        exit
    fi
 
    envsubst '$MCP,$REGULUS_INTERFACE_PCI,$REGULUS_INTERFACE,$SRIOV_MTU' < templates/${NIC_MODEL}/sriov-node-policy.yaml.template > ${MANIFEST_DIR}/sriov-node-policy.yaml
    echo "generating ${MANIFEST_DIR}/sriov-node-policy.yaml: done"
    # step 2 - apply

    for NODE in ${WORKER_LIST}; do
        ECHO oc label --overwrite node $NODE feature.node.kubernetes.io/network-sriov.capable=true
    done

    if oc get SriovNetworkNodePolicy regulus-sriov-node-policy -n openshift-sriov-network-operator  2>/dev/null; then
        echo "SriovNetworkNodePolicy exists. Skip creation"
    else
        echo "create SriovNetworkNodePolicy ..."
        ECHO oc create -f ${MANIFEST_DIR}/sriov-node-policy.yaml
        echo "create SriovNetworkNodePolicy: done"
        if [ $PAUSE == false ]; then
           # MCP may not go to UPDATING after apply SriovNetworkNodePolicy
           ECHO wait_mcp
        fi
        # !!!!! node reboot !!!!
    fi
}

echo "next is config_SriovNetworkNodePolicy"
prompt_continue

config_SriovNetworkNodePolicy

# !!! reboot

function create_network {
    # debug:  oc get SriovNetwork/sriov-node-policy.yaml.template
    if [ "${OCP_CHANNEL}" == "4.14" ] ||  [ "${OCP_CHANNEL}" == "4.15" ] ; then
    	envsubst < templates/net-attach-def.yaml.415.template > ${MANIFEST_DIR}/net-attach-def.yaml
    else
    	envsubst < templates/net-attach-def.yaml.template > ${MANIFEST_DIR}/net-attach-def.yaml
    fi
    if oc get network-attachment-definition/regulus-sriov-net -n ${MCP}  &>/dev/null; then
        echo "SriovNetworkexists. Skip creation"
    else
        echo "create network-attachment-definition/ ..."
        ECHO oc new-project ${MCP}  &> /dev/null
        ECHO oc create -f ${MANIFEST_DIR}/net-attach-def.yaml
        echo "create NAD /net-attach-def.yaml  done"
    fi
}

# create network-attachment-definition/
echo create SriovNetwork
prompt_continue
create_network

# Done
