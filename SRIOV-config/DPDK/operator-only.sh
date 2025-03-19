#!/bin/bash

source ${REG_ROOT}/lab.config
source ${REG_ROOT}/SRIOV-config/config.env
source ./setting.env
source ./functions.sh

SINGLE_STEP=${SINGLE_STEP:-true}

#set -euo pipefail

parse_args $@

mkdir -p ${MANIFEST_DIR}/

if [ -z "$WORKER_LIST"  ]; then
    echo no WORRKER_LIST
    exit
fi
echo Use mcp $MCP 

export OCP_CHANNEL=$(get_ocp_channel)

# lately 4.14 onward sriov  operator want channel="stable" and not the actual version number.
OCP_CHANNEL=stable

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
        ECHO CMD: oc create -f ${MANIFEST_DIR}/sub-sriov.yaml && \
                  oc create -f ${MANIFEST_DIR}/sub-sriov.yaml
        echo "install SRIOV Operator: done"
        ECHO CMD: wait_pod_in_namespace openshift-sriov-network-operator &&\
                  wait_pod_in_namespace openshift-sriov-network-operator
        # give it a little delay. W/o delay we could encounter error on the next command.
        ECHO sleep 10
    fi
}

install_sriov_operator

# MCP goes to UPDATING after add label
wait_mcp

# Done
