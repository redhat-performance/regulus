#!/bin/bash

REG_ROOT=${REG_ROOT:-/root/regulus}
REG_TEMPLATES=./templates
MANIFEST_DIR=./
source ${REG_ROOT}/lab.config
source ${REG_ROOT}/system.config
source ${REG_ROOT}/MACVLAN-config/config.env

if [ -z "${CLUSTER_TYPE}" ]; then
    echo "Please prepare lab by \"make init-lab\" at top level prior to coming here"
    exit 1
fi

if [ "${CLUSTER_TYPE}" != "STANDARD" ]; then
    # these cluster types (SNO and 3-node compact) only have MCP master
    MCP="master" 
fi

# MACVLAN does not need setting.env ?
echo "MACVLAN does not setting.env"
#export MCP
#envsubst '$MCP,$REG_MACVLAN_MTU,$REG_MACVLAN_NIC' < ${REG_TEMPLATES}/setting.env.template > ${MANIFEST_DIR}/setting.env

