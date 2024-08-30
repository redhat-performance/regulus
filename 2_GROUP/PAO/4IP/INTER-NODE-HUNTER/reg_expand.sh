#!/bin/bash
# iperf PAO, IPv4 UDP, INTER-NODE-HUMTER

REG_ROOT=${REG_ROOT:-/root/REGULUS}
REG_TEMPLATES=${REG_ROOT}/templates/iperf
REG_COMMON=${REG_ROOT}/templates/common
MANIFEST_DIR=./


export TPL_SCALE_UP_FACTOR=1
export TPL_TOPO=intranode
export TPL_PAO=1
envsubst '$TPL_SCALE_UP_FACTOR,$TPL_TOPO,$TPL_PAO' < ${REG_TEMPLATES}/run.sh.template > ${MANIFEST_DIR}/run.sh

export TPL_INTF=eth0
export TPL_IPV=4
envsubst '$TPL_INTF,$TPL_IPV' < ${REG_TEMPLATES}/udp-drop-mv-params.json.template >  ${MANIFEST_DIR}/mv-params.json

envsubst < ${REG_COMMON}/tool-params.json.template > ${MANIFEST_DIR}/tool-params.json
# PAO needs
envsubst < ${REG_COMMON}/securityContext.json.template > ${MANIFEST_DIR}/securityContext.json
envsubst < ${REG_COMMON}/annotations-pao.json.template > ${MANIFEST_DIR}/annotations.json
