#!/bin/bash
# iperf IPv4, INGRESS,2 Pods

REG_ROOT=${REG_ROOT:-/root/REGULUS}
REG_TEMPLATES=${REG_ROOT}/templates/iperf
REG_COMMON=${REG_ROOT}/templates/common
MANIFEST_DIR=./

export TPL_SCALE_UP_FACTOR=10
export TPL_TOPO=egress
export TPL_PAO=1
export TPL_RESOURCES='resource-static-Ncpu.json'

envsubst '$TPL_RESOURCES,$MCP,$TPL_PAO,$TPL_SCALE_UP_FACTOR,$TPL_TOPO' < ${REG_TEMPLATES}/run.sh.template > ${MANIFEST_DIR}/run.sh
export TPL_INTF=$REMOTE_HOST_INTF
#export TPL_EP=$IPSEC_EP     # define IPSEC_EP in jobs.config
#export TPL_DIR=",--bidir"
export TPL_IPV=4
#envsubst '$TPL_INTF,$TPL_IPV' <  ${REG_TEMPLATES}/tcp-mv-params.json.template >  ${MANIFEST_DIR}/mv-params.json

cp ${REG_COMMON}/tool-params.json.template  ${MANIFEST_DIR}/tool-params.json
cp ${REG_COMMON}/annotations-pao.json.template  ${MANIFEST_DIR}/annotations.json

# 
export TPL_NUMCPUS="4"
envsubst '$TPL_NUMCPUS' < ${REG_COMMON}/resource-static-Ncpu.json.template > ${MANIFEST_DIR}/resource-static-Ncpu.json 
