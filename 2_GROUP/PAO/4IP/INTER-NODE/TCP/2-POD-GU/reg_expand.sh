#!/bin/bash
# iperf IPv4,internode, 2 Pods. 

REG_ROOT=${REG_ROOT:-/root/REGULUS}
REG_TEMPLATES=${REG_ROOT}/templates/iperf
REG_COMMON=${REG_ROOT}/templates/common
MANIFEST_DIR=./

export TPL_SCALE_UP_FACTOR=8
export TPL_TOPO=internode
export TPL_PAO=1
export TPL_QOS=guaranteed
export TPL_NUMCPUS=

envsubst '$TPL_NUMSPUS,$TPL_QOS,$MCP,$TPL_PAO,$TPL_SCALE_UP_FACTOR,$TPL_TOPO' < ${REG_TEMPLATES}/run.sh.template > ${MANIFEST_DIR}/run.sh
export TPL_INTF=eth0
export TPL_IPV=4
envsubst '$TPL_INTF,$TPL_IPV' <  ${REG_TEMPLATES}/tcp-mv-params.json.template >  ${MANIFEST_DIR}/mv-params.json

cp ${REG_COMMON}/tool-params.json.template  ${MANIFEST_DIR}/tool-params.json
cp ${REG_COMMON}/securityContext.json.template  ${MANIFEST_DIR}/securityContext.json
cp ${REG_COMMON}/annotations-pao-qos.json.template  ${MANIFEST_DIR}/annotations-pao-qos.json

