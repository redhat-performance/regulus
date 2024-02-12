#!/bin/bash

#set -euo pipefail
source ./setting.env
source ./functions.sh

parse_args $@


mkdir -p ${MANIFEST_DIR}/

# if no worker i.e SNO, compact cluster, use master mcp
if [ -z "$WORKER_LIST"  ]; then
    export MCP=master   
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
    if oc get Subscription sriov-network-operator-subsription -n openshift-sriov-network-operator &>/dev/null; then 
        echo "SRIOV Operator already installed: done"
    else
        #// Installing SR-IOV Network Operator done
        echo "Installing SRIOV Operator ..."
        export OCP_CHANNEL=$(get_ocp_channel)
        envsubst < templates/sub-sriov.yaml.template > ${MANIFEST_DIR}/sub-sriov.yaml
        oc create -f ${MANIFEST_DIR}/sub-sriov.yaml
        echo "install SRIOV Operator: done"
        wait_pod_in_namespace openshift-sriov-network-operator
        # give it a little delay. W/o delay we could encounter error on the next command.
        sleep 10
    fi
}

install_sriov_operator
echo "next is creating $MCP mcp"
prompt_continue

# step 2 - Create mcp-offloading mcp

function configure_mcp {
    if oc get mcp $MCP  &>/dev/null; then
        echo "mcp $MCP exists. No need to create new"
    else
        echo "create mcp for $MCP  ..."
        mkdir -p ${MANIFEST_DIR}
        envsubst < templates/$MCP.yaml.template > ${MANIFEST_DIR}/$MCP.yaml
        oc create -f ${MANIFEST_DIR}/$MCP.yaml
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
            oc label --overwrite node ${NODE} node-role.kubernetes.io/${MCP}=""
        done
    else
        echo "Cluster has no workers. No need to label master nodes"
    fi
}
add_label
echo "next is add_mc_realloc"
prompt_continue

# add this if necessary
function add_mc_realloc {
    if  oc get mc 99-pci-realloc-workers &>/dev/null ; then
        echo mc pci-realloc exists. No need to create this mc
    else
        echo "create mc mc-realloc.yaml ..."
        envsubst < templates/mc-realloc.yaml.template > ${MANIFEST_DIR}/mc-realloc.yaml
        oc create -f ${MANIFEST_DIR}/mc-realloc.yaml
        echo "create mc-realloc.yaml: done"
    fi
}

add_mc_realloc
echo "next is add_SriovNetworkPoolConfig"
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
        oc create -f ${MANIFEST_DIR}/sriov-pool-config.yaml
        echo "create SriovNetworkPoolConfig: done"
        wait_mcp
        # !!!!! node reboot !!!!
    fi
}
add_SriovNetworkPoolConfig
echo "next is config_SriovNetworkNodePolicy"
prompt_continue

# step 5  - SiovNetworkNodePolicy. Tell it what SRIOV devices (mlx, 710 etc) to be activated.

function config_SriovNetworkNodePolicy {
    ##### Configuring the SR-IOV network node policy
    echo "Acquiring SRIOV interface PCI info from worker node ${WORKER_LIST} ..."
    WORKER_ARR=(${WORKER_LIST})
    # assuming all worker NICs are in same PCI slot
    export HWOL_INTERFACE_PCI=$(exec_over_ssh ${WORKER_ARR[0]} "ethtool -i ${HWOL_INTERFACE}" | awk '/bus-info:/{print $NF;}')
    echo "Acquiring SRIOV interface PCI info from worker node ${WORKER_LIST}: done"

    # step 1 - create sriov-node-policy.yaml from template
    # 
    envsubst < templates/sriov-node-policy.yaml.template > ${MANIFEST_DIR}/sriov-node-policy.yaml
    echo "generating ${MANIFEST_DIR}/sriov-node-policy.yaml: done"
    # step 2 - apply

    for NODE in ${WORKER_LIST}; do
        oc label --overwrite node $NODE feature.node.kubernetes.io/network-sriov.capable=true
    done

    if oc get SriovNetworkNodePolicy sriov-node-policy -n openshift-sriov-network-operator  2>/dev/null; then
        echo "SriovNetworkNodePolicy exists. Skip creation"
    else
        echo "create SriovNetworkNodePolicy ..."
        oc create -f ${MANIFEST_DIR}/sriov-node-policy.yaml
        echo "create SriovNetworkNodePolicy: done"
        wait_mcp
        # !!!!! node reboot !!!!
    fi
}
config_SriovNetworkNodePolicy
# !!! reboot
echo "next is create_network_attachment"
prompt_continue


#### Creating a network attachment definition

function create_network_attachment {
    # debug:  oc get networkattachmentdefinition.k8s.cni.cncf.io/$NET_ATTACH_NAME
    envsubst < templates//net-attach-def.yaml.template > ${MANIFEST_DIR}/net-attach-def.yaml
    echo "generating ${MANIFEST_DIR}/net-attach-def.yaml: done"
    if oc get networkattachmentdefinition.k8s.cni.cncf.io/$NET_ATTACH_NAME  &>/dev/null; then
        echo "NetworkAttachmentDefinition exists. Skip creation"
    else
        echo "create NetworkAttachmentDefinition ..."
        oc create -f ${MANIFEST_DIR}/net-attach-def.yaml
        echo "create SriovNetwork net-attach-def: done"
    fi
}

create_network_attachment


#
#  to annotate pod
# ....
# metadata:
#   annotations:
#    v1.multus-cni.io/default-network: net-attach-def/net-attach-def 
