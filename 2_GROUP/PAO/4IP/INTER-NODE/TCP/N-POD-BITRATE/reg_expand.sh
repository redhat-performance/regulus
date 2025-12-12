#!/bin/bash
# iperf IPv4,internode, 16 4-CPU Pods. bitrate: 8 pods transmit each direction, step up bitrate

REG_ROOT=${REG_ROOT:-/root/REGULUS}
REG_TEMPLATES=${REG_ROOT}/templates/iperf
REG_COMMON=${REG_ROOT}/templates/common
MANIFEST_DIR=./

export TPL_SCALE_UP_FACTOR=13
export TPL_TOPO=internode
export TPL_PAO=1

envsubst '$MCP,$TPL_PAO,$TPL_SCALE_UP_FACTOR,$TPL_TOPO,$TPL_RESOURCES' < ${REG_TEMPLATES}/run.sh.template > ${MANIFEST_DIR}/run.sh
export TPL_INTF=eth0
export TPL_IPV=4
envsubst '$TPL_INTF,$TPL_IPV' <  ${REG_TEMPLATES}/tcp-bitrate-mv-params.json.template >  ${MANIFEST_DIR}/mv-params.json

cp ${REG_COMMON}/tool-params.json.template  ${MANIFEST_DIR}/tool-params.json
cp ${REG_COMMON}/annotations-pao.json.template  ${MANIFEST_DIR}/annotations.json

