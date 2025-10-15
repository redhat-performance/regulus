#!/bin/bash
# uperf PAO,IPv4,INTRA_NODE,2 Pods, GU

REG_ROOT=${REG_ROOT:-/root/REGULUS}
REG_TEMPLATES=${REG_ROOT}/templates/uperf
REG_COMMON=${REG_ROOT}/templates/common
MANIFEST_DIR=./

export TPL_SCALE_UP_FACTOR=4
export TPL_TOPO=intranode
export TPL_PAO=1
export TPL_QOS=guaranteed
export TPL_NUMCPUS=4
envsubst '$TPL_NUMCPUS,$TPL_QOS,$MCP,$TPL_PAO,$TPL_SCALE_UP_FACTOR,$TPL_TOPO' < ${REG_TEMPLATES}/run.sh.template > ${MANIFEST_DIR}/run.sh

export TPL_INTF=eth0
envsubst '$TPL_INTF' <  ${REG_TEMPLATES}/tcp-mv-params.json.template >  ${MANIFEST_DIR}/mv-params.json

cp ${REG_COMMON}/tool-params.json.template  ${MANIFEST_DIR}/tool-params.json
cp ${REG_COMMON}/annotations-pao.json.template  ${MANIFEST_DIR}/annotations.json
export TPL_NUMCPUS=4
envsubst '$TPL_NUMCPUS' < ${REG_COMMON}/resource-static-Ncpu.json.template > ${MANIFEST_DIR}/resource-static-Ncpu.json

