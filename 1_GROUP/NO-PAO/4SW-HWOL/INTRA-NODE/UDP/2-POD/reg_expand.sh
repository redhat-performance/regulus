#!/bin/bash
# uperf NO-PAO, IPv4 UDP, INTRA-NODE,  Pods

REG_ROOT=${REG_ROOT:-/root/REGULUS}
REG_TEMPLATES=${REG_ROOT}/templates/uperf
REG_COMMON=${REG_ROOT}/templates/common
MANIFEST_DIR=./

export TPL_SCALE_UP_FACTOR=1
export TPL_TOPO=intranode

envsubst '$TPL_SCALE_UP_FACTOR,$TPL_TOPO' < ${REG_TEMPLATES}/run.sh.template > ${MANIFEST_DIR}/run.sh
export TPL_INTF=eth0
envsubst '$TPL_INTF' <  ${REG_TEMPLATES}/udp-mv-params.json.template >  ${MANIFEST_DIR}/mv-params.json
cp ${REG_COMMON}/tool-params.json.template  ${MANIFEST_DIR}/tool-params.json

