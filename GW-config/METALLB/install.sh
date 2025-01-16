#!/bin/bash


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

OCP_CHANNEL=stable

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

# step1 - install IPAddressPool
install_IPAddressPool


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

# step 2 -  Install  l2-advertisement.yaml
install_L2Advertisement


# Done
