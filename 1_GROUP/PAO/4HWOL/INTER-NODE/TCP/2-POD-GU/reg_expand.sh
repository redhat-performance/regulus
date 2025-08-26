#!/bin/bash
# uperf PAO,HWOL,IPv4,INTER_NODE,2 GU Pods,

REG_ROOT=${REG_ROOT:-/root/REGULUS}
REG_TEMPLATES=${REG_ROOT}/templates/uperf
REG_COMMON=${REG_ROOT}/templates/common
MANIFEST_DIR=./

export TPL_SCALE_UP_FACTOR=1
export TPL_TOPO=internode
export TPL_HWOL=1
export TPL_PAO=1
export TPL_EXTRA_RESOURCES=./resource-hwol-be.json

export TPL_INTF=eth0
export TPL_IPV=4
envsubst '$TPL_INTF,$TPL_IPV' <  ${REG_TEMPLATES}/tcp-mv-params.json.template >  ${MANIFEST_DIR}/mv-params.json

cp ${REG_COMMON}/tool-params.json.template  ${MANIFEST_DIR}/tool-params.json
cp ${REG_COMMON}/securityContext.json.template  ${MANIFEST_DIR}/securityContext.json
cp ${REG_COMMON}/annotations-hwol-pao.json.template  ${MANIFEST_DIR}/annotations.json
cp ${REG_COMMON}/resource-hwol-be.json.template ${MANIFEST_DIR}/resource-hwol-be.json
export TPL_NUMCPUS=4
envsubst '$TPL_NUMCPUS' < ${REG_COMMON}/resource-static-Ncpu.json.template > ${MANIFEST_DIR}/resource-static-Ncpu.json
export TPL_RESOURCES=resource-static-Ncpu.json
envsubst '$TPL_EXTRA_RESOURCES,$TPL_RESOURCES,$TPL_PAO,$TPL_HWOL,$TPL_SCALE_UP_FACTOR,$TPL_TOPO' < ${REG_TEMPLATES}/run.sh.template > ${MANIFEST_DIR}/run.sh

