#!/bin/bash

REG_ROOT=${REG_ROOT:-/root/REGULUS}
REG_TEMPLATES=./templates
MANIFEST_DIR=./
source ${REG_ROOT}/lab.config
source ${REG_ROOT}/SRIOV-config/config.env

echo OCP_WORKER_1=$OCP_WORKER_0

envsubst '$MCP,$REG_SRIOV_MTU,$REG_SRIOV_NIC,$REG_SRIOV_NIC_MODEL,$OCP_WORKER_0,$OCP_WORKER_1,$OCP_WORKER_2' < ${REG_TEMPLATES}/setting.env.template > ${MANIFEST_DIR}/setting.env

