#!/bin/bash
# iperf PAO, IPv4 TCP, INTRANODE, 4 Pods (2 clients and 2 servers) each 2 Engines

REG_ROOT=${REG_ROOT:-/root/REGULUS}
REG_TEMPLATES=${REG_ROOT}/templates/iperf
REG_COMMON=${REG_ROOT}/templates/common
MANIFEST_DIR=./

export TPL_SCALE_UP_FACTOR=4
export TPL_TOPO=intranode
export TPL_PAO=1
export TPL_MULTI_ENGINE_POD=2
envsubst '$TPL_MULTI_ENGINE_POD,$TPL_PAO,$TPL_SCALE_UP_FACTOR,$TPL_TOPO' < ${REG_TEMPLATES}/run.sh.template > ${MANIFEST_DIR}/run.sh
export TPL_INTF=eth0
export TPL_IPV=4
envsubst '$TPL_IPV, $TPL_INTF' <  ${REG_TEMPLATES}/tcp-mv-params.json.template >  ${MANIFEST_DIR}/mv-params.json
cp ${REG_COMMON}/tool-params.json.template  ${MANIFEST_DIR}/tool-params.json
cp ${REG_COMMON}/securityContext.json.template  ${MANIFEST_DIR}/securityContext.json
cp ${REG_COMMON}/annotations-pao-qos.json.template  ${MANIFEST_DIR}/annotations-pao-qos.json

