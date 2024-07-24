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
source ./setting.env
source ./functions.sh

parse_args $@

mkdir -p ${MANIFEST_DIR}/

export OCP_CHANNEL=$(get_ocp_channel)

# lately 4.14 onward sriov  operator want channel="stable" and not the actual version number.
OCP_CHANNEL=stable

# step1 - install sriov Operator
function install_IPAddressPool {

    # install IPaddress pool operator
    if oc get IPAddressPool $POOL_NAME  -n metallb-system &>/dev/null; then 
        echo "IPaddress pool $POOL_NAME already installed: done"
    else
        echo "Installing IPAddressPool..."
        envsubst '$POOL_NAME, $ADDR_RANGE' < templates/metalLB-address-pool-config.yaml.template > ${MANIFEST_DIR}/metalLB-address-pool-config.yaml
        oc apply -f  ${MANIFEST_DIR}/metalLB-address-pool-config.yaml
        echo "install IPAddressPool : done"
    fi
}

install_IPAddressPool


# step 2 -  Install  l2-advertisement.yaml

function install_L2Advertisement {
    if oc get L2Advertisement l2advertisement  &>/dev/null; then
        echo "L2Advertisement exists. No need to create new"
    else
        echo "create L2Advertisement  ..."
        envsubst '$POOL_NAME' < templates/l2-advertisement.yaml.template > ${MANIFEST_DIR}/l2-advertisement.yaml
        oc create -f ${MANIFEST_DIR}/l2-advertisement.yaml
        echo "create L2Advertisement done"
    fi
}

install_L2Advertisement

function install_LBsvc {
    if oc get svc uperf-lb-svc  &>/dev/null; then
        oc delete svc uperf-lb-svc
    fi
    echo "Create new LB svc"
    oc create -f multiproto-lbsvc.yaml
}

install_LBsvc

# Done
