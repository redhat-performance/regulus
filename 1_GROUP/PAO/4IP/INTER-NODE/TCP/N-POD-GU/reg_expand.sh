#!/bin/bash
# uperf PAO,IPv4,INTER_NODE,2 Pods, GU

REG_ROOT=${REG_ROOT:-/root/REGULUS}
REG_TEMPLATES=${REG_ROOT}/templates/uperf
REG_COMMON=${REG_ROOT}/templates/common
MANIFEST_DIR=./

export TPL_SCALE_UP_FACTOR=8
export TPL_TOPO=internode
export TPL_PAO=1
export TPL_QOS=
export TPL_NUMCPUS=0

envsubst '$TPL_QOS,$TPL_NUMCPUS,$MCP,$TPL_PAO,$TPL_SCALE_UP_FACTOR,$TPL_TOPO' < ${REG_TEMPLATES}/run.sh.template > ${MANIFEST_DIR}/run.sh

export TPL_INTF=eth0
envsubst '$TPL_INTF' <  ${REG_TEMPLATES}/tcp-mv-params.json.template >  ${MANIFEST_DIR}/mv-params.json

cp ${REG_COMMON}/tool-params.json.template  ${MANIFEST_DIR}/tool-params.json
cp ${REG_COMMON}/annotations-pao.json.template  ${MANIFEST_DIR}/annotations.json

