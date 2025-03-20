#!/bin/bash

REG_ROOT=${REG_ROOT:-/root/regulus}
REG_TEMPLATES=./templates
MANIFEST_DIR=../
source ${REG_ROOT}/lab.config
source ${REG_ROOT}/system.config
source ${REG_ROOT}/SRIOV-config/config.env

if [ -z "${CLUSTER_TYPE}" ]; then
    echo "Please prepare lab by \"make init-lab\" at top level prior to coming here"
    exit 1
fi

if [ "${CLUSTER_TYPE}" != "STANDARD" ]; then
    # these cluster types (SNO and 3-node compact) only have MCP master
    MCP="master" 
fi
export MCP
envsubst '$MCP,$REG_SRIOV_MTU,$REG_SRIOV_NIC,$REG_SRIOV_NIC_MODEL,$OCP_WORKER_0,$OCP_WORKER_1,$OCP_WORKER_2' < ${REG_TEMPLATES}/setting.env.template > ${MANIFEST_DIR}/setting.env

