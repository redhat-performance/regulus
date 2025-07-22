#!/bin/bash
# Flow:
#          STANDARD                                                             SNO
# 3. label to worker node, node-role.kubernetes.io/${MCP}="     3. none
# 4. config SriovNetworkNodePolicy (applied to node-role $MCP"  4. config SriovNetworkNodePolicy  (applied to node-role:master)
#

source ${REG_ROOT}/lab.config
source ${REG_ROOT}/SRIOV-config/config.env

SINGLE_STEP=${SINGLE_STEP:-false}
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
echo Use label $MCP 
prompt_continue

export OCP_CHANNEL=$(oc get packagemanifest sriov-network-operator -n openshift-marketplace -o json | jq -r '.status.channels[0].name')

# step 3 - label nodes that needs SRIOV

function add_label {
    for NODE in $WORKER_LIST; do
        echo label $NODE with $MCP
        oc label --overwrite node ${NODE} node-role.kubernetes.io/${MCP}=""
    done
}
add_label

# add this if necessary
function add_mc_realloc {
    if  oc get mc 99-pci-realloc-$MCP &>/dev/null ; then
        echo mc pci-realloc exists. No need to create this mc
    else
        echo "create mc mc-realloc.yaml ..."
        envsubst < templates/mc-realloc.yaml.template > ${MANIFEST_DIR}/mc-realloc.yaml
        oc create -f ${MANIFEST_DIR}/mc-realloc.yaml
        echo "create mc-realloc.yaml: done"
        wait_mcp
    fi
}

if [[ ${NIC_MODEL} == CX* ]]; then
   echo "next, add add_mc_realloc"
   prompt_continue
   add_mc_realloc
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

    if oc get SriovNetworkNodePolicy regulus-sriov-node-policy -n openshift-sriov-network-operator  2>/dev/null; then
        echo "SriovNetworkNodePolicy exists. Skip creation"
    else
        echo "create SriovNetworkNodePolicy ..."
        oc create -f ${MANIFEST_DIR}/sriov-node-policy.yaml
        echo "create SriovNetworkNodePolicy: done"
        # !!!!! node reboot !!!! ?
    fi
}

echo "next is config_SriovNetworkNodePolicy"
prompt_continue

config_SriovNetworkNodePolicy

# !!! reboot ?

function create_network {
    # debug:  oc get SriovNetwork/sriov-node-policy.yaml.template
    envsubst < templates/net-attach-def.yaml.template > ${MANIFEST_DIR}/net-attach-def.yaml
    return # lately we create NAD per test. So no need to create now

    if oc get network-attachment-definition/regulus-sriov-net -n ${MCP}  &>/dev/null; then
        echo "NAD exists. Skip creation"
    else
        echo "create network-attachment-definition/ ..."
        # we always recreate NAD in a test for the tester NS. Here we create one for the MCP as a test.
        oc new-project ${MCP}  &> /dev/null
        oc create -f ${MANIFEST_DIR}/net-attach-def.yaml
        echo "create NAD /net-attach-def.yaml  done"
    fi
}

# create network-attachment-definition/
echo create NAD
prompt_continue
create_network

# Done
