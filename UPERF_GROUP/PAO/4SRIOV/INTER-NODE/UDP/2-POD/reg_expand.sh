#!/bin/bash
# uperf NO-PAO, SRIOV, IPv4 UDP, INTER_NODE, 2 Pods

REG_ROOT=${REG_ROOT:-/root/REGULUS}
REG_TEMPLATES=${REG_ROOT}/templates/uperf
REG_COMMON=${REG_ROOT}/templates/common
MANIFEST_DIR=./
source ${REG_ROOT}/system.config

export TPL_SCALE_UP_FACTOR=1
export TPL_TOPO=internode
export TPL_SRIOV=1
export TPL_PAO=1
envsubst '$MCP,$TPL_PAO,$TPL_SRIOV,$TPL_SCALE_UP_FACTOR,$TPL_TOPO' < ${REG_TEMPLATES}/run.sh.template > ${MANIFEST_DIR}/run.sh

export TPL_INTF=net1
export TPL_IPV=4
envsubst '$TPL_INTF,$TPL_IPV' <  ${REG_TEMPLATES}/udp-mv-params.json.template >  ${MANIFEST_DIR}/mv-params.json

cp ${REG_COMMON}/tool-params.json.template  ${MANIFEST_DIR}/tool-params.json
cp ${REG_COMMON}/securityContext.json.template  ${MANIFEST_DIR}/securityContext.json
cp ${REG_COMMON}/annotations-sriov-pao-be.json.template  ${MANIFEST_DIR}/annotations.json

