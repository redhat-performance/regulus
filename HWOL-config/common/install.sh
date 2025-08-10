#!/bin/bash

PAUSE=${PAUSE:-false}
SINGLE_STEP=${SINGLE_STEP:-true}

if [ $PAUSE == true ]; then
  echo true PAUSE=$PAUSE
fi

#set -euo pipefail
source ./setting.env
source ../common/functions.sh


parse_args $@

MANIFEST_DIR=../generated_manifests

mkdir -p ${MANIFEST_DIR}/


if [ -z "${WORKER_LIST}"  ]; then
    echo no WORKER_LIST
    exit
else
    echo WORKER_LIST=$WORKER_LIST
fi
#echo INTERFACE=$INTERFACE; exit
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
        envsubst < templates/sub-sriov.yaml.template > ${MANIFEST_DIR}/sub-sriov.yaml
        RUN_CMD oc create -f ${MANIFEST_DIR}/sub-sriov.yaml
        echo "install SRIOV Operator: done"
        RUN_CMD wait_pod_in_namespace openshift-sriov-network-operator
        # give it a little delay. W/o delay we could encounter error on the next command.
        sleep 10
    fi

    ### install HWOL SRIOV Operator Config. 
    envsubst  < templates/sriov-operator-config.yaml.template > ${MANIFEST_DIR}/sriov-operator-config.yaml
    resource_count=$(oc get sriovoperatorconfig -n openshift-sriov-network-operator --no-headers 2>/dev/null | wc -l)
    if [ "$resource_count" -gt 0 ]; then
        echo $LINEO "INFO: a SRIOV Operator Config exists. Overwrite it"
        RUN_CMD oc apply -f ${MANIFEST_DIR}/sriov-operator-config.yaml
    else
        echo "Installing SRIOV Operator Config ..."
        RUN_CMD oc create -f ${MANIFEST_DIR}/sriov-operator-config.yaml
    fi 
    echo "install SRIOV Operator: done"
    # Nodes need a reboot for this /sriov-operator-config
    RUN_CMD wait_mcp
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
        envsubst < templates/mcp-hwol.yaml.template > ${MANIFEST_DIR}/mcp-hwol.yaml
        RUN_CMD oc create -f ${MANIFEST_DIR}/mcp-hwol.yaml
        echo "create mcp for $MCP: done"
    fi
}

# Create a new MCP, but if cluster is SNO or compact we only have masters, and hence use master MCP.
if [ ! -z "${WORKER_LIST}" ]; then
    configure_mcp     # SRIOV selects by node label and not MCP
    :
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

if [[ "${REG_DPDK_NIC_MODEL}" == CX* ]]; then
   DPRINT $LINDO "next, add add_mc_realloc"
   prompt_continue
   add_mc_realloc
fi

DPRINT $LINENO "next is config_SriovNetworkPoolConfig"
prompt_continue

# step 4 - create SriovNetworkPoolConfig CR. Purpose: add the mcp-offload MCP to SriovNetworkPoolConfig
#           !!! Node reboot !!!!
function add_SriovNetworkPoolConfig {
    if oc get SriovNetworkPoolConfig/sriovnetworkpoolconfig-offload -n openshift-sriov-network-operator &>/dev/null; then
        echo SriovNetworkPoolConfig exists. No need to create SriovNetworkPoolConfig
    else
        echo "create SriovNetworkPoolConfig  ..."
        # create sriov-pool-config.yaml from template
        envsubst < templates/sriov-pool-config.yaml.template > ${MANIFEST_DIR}/sriov-pool-config.yaml
        RUN_CMD oc create -f ${MANIFEST_DIR}/sriov-pool-config.yaml
        echo "create SriovNetworkPoolConfig: done"
        # !!!!! node should reboot but caller has initiated a pause !!!!
        #RUN_CMD wait_mcp
    fi
}
# Next 2 operations each will cause reboot. So we pause and resume,
pause_mcp   # wait_mcp will resume and then poll for completion
add_SriovNetworkPoolConfig

DPRINT $LINENO "next is config_SriovNetworkNodePolicy"
prompt_continue

# step 5  - SiovNetworkNodePolicy. Tell it what SRIOV devices (mlx, 710 etc) to be activated.

function config_SriovNetworkNodePolicy {
    ##### Configuring the SR-IOV network node policy
    echo "Acquiring SRIOV interface PCI info from worker node ${WORKER_LIST} ..."
    WORKER_ARR=(${WORKER_LIST})
    # assuming all worker NICs are in same PCI slot
    export INTERFACE_PCI=$(exec_over_ssh ${WORKER_ARR[0]} "ethtool -i ${REG_HWOL_NIC}" | awk '/bus-info:/{print $NF;}')
    echo "Acquiring SRIOV interface [$REG_HWOL_NIC] PCI info [$INTERFACE_PCI] from worker node ${WORKER_ARR[0]}: done"

    # step 1 - create sriov-node-policy.yaml from template
    # 
    export INTERFACE
    envsubst < templates_local/sriov-node-policy.yaml.template > ${MANIFEST_DIR}/sriov-node-policy.yaml
    echo "generating ${MANIFEST_DIR}/sriov-node-policy.yaml: done"
    # step 2 - apply

    for NODE in ${WORKER_LIST}; do
        RUN_CMD oc label --overwrite node $NODE feature.node.kubernetes.io/network-sriov.capable=true
    done

    if oc get SriovNetworkNodePolicy hwol-sriov-node-policy -n openshift-sriov-network-operator  2>/dev/null; then
        echo "SriovNetworkNodePolicy exists. Skip creation"
    else
        echo "create SriovNetworkNodePolicy ..."
        RUN_CMD oc create -f ${MANIFEST_DIR}/sriov-node-policy.yaml
        echo "create SriovNetworkNodePolicy: done"
    fi
}
config_SriovNetworkNodePolicy
# !!! reboot
RUN_CMD wait_mcp

function create_network_attachment {
    # debug:  oc get networkattachmentdefinition.k8s.cni.cncf.io/$NAD_NAME
    envsubst < templates/net-attach-def.yaml.template > ${MANIFEST_DIR}/net-attach-def.yaml
    echo "generating ${MANIFEST_DIR}/net-attach-def.yaml: done"
    if oc get networkattachmentdefinition.k8s.cni.cncf.io/$NET_ATTACH_NAME  &>/dev/null; then
        echo "NetworkAttachmentDefinition exists. Skip creation"
    else
        echo "create NetworkAttachmentDefinition ..."
        RUN_CMD oc create -f ${MANIFEST_DIR}/net-attach-def.yaml
        echo "create SriovNetwork net-attach-def: done"
    fi
}

DPRINT $LINENO "next create NAD"
prompt_continue
create_network_attachment

# Done
