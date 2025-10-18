#!/bin/bash
# uperf PAO,DPU,IPv4,UDP,INTER_NODE, N Pods 

REG_ROOT=${REG_ROOT:-/root/REGULUS}
REG_TEMPLATES=${REG_ROOT}/templates/uperf
REG_COMMON=${REG_ROOT}/templates/common
MANIFEST_DIR=./

export TPL_SCALE_UP_FACTOR=13
export TPL_QOS=burstable
export TPL_TOPO=internode
export TPL_PAO=0
export TPL_DPF=1

envsubst '$TPL_QOS,$TPL_PAO,$TPL_DPF,$TPL_SCALE_UP_FACTOR,$TPL_TOPO' < ${REG_TEMPLATES}/run.sh.template > ${MANIFEST_DIR}/run.sh
export TPL_INTF=eth0
export TPL_IPV=4
envsubst '$TPL_INTF,$TPL_IPV' <  ${REG_TEMPLATES}/udp-mv-params.json.template >  ${MANIFEST_DIR}/mv-params.json

cp ${REG_COMMON}/tool-params.json.template  ${MANIFEST_DIR}/tool-params.json
cp ${REG_COMMON}/securityContext.json.template  ${MANIFEST_DIR}/securityContext.json
cp ${REG_COMMON}/annotations-pao-qos.json.template  ${MANIFEST_DIR}/annotations-pao-qos.json
cp ${REG_COMMON}/annotations-dpf.json.template  ${MANIFEST_DIR}/annotations.json
cp ${REG_COMMON}/resource-dpf.json.template ${MANIFEST_DIR}/resource-dpf.json

