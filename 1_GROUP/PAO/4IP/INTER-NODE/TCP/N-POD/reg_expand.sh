#!/bin/bash
# uperf PAO,IPv4,INTER_NODE,N Pods

REG_ROOT=${REG_ROOT:-/root/REGULUS}
# SUBSET_TESTS=NIC-MODE selects reduced test params (NIC-BOND-TEST folders only)
if [ "${SUBSET_TESTS}" = "NIC-MODE" ]; then
    REG_TEMPLATES=${REG_ROOT}/templates/uperf/NIC-BOND-TEST
    export TPL_MVPARAMS=${TPL_MVPARAMS:-r11-tcp-mv-params.json.template}
else
    REG_TEMPLATES=${REG_ROOT}/templates/uperf
    export TPL_MVPARAMS=${TPL_MVPARAMS:-tcp-mv-params.json.template}
fi
REG_COMMON=${REG_ROOT}/templates/common
MANIFEST_DIR=./

export TPL_SCALE_UP_FACTOR=13
export TPL_QOS=burstable
export TPL_TOPO=internode
export TPL_PAO=1

# Adapt DPU old logic
export TPL_NUMCPUS=2
envsubst '$TPL_NUMCPUS,$TPL_QOS,$MCP,$TPL_PAO,$TPL_SCALE_UP_FACTOR,$TPL_TOPO' < ${REG_TEMPLATES}/run.sh.template > ${MANIFEST_DIR}/run.sh
export TPL_INTF=eth0
export TPL_IPV=4 
envsubst '$TPL_INTF,$TPL_IPV' <  ${REG_TEMPLATES}/${TPL_MVPARAMS} >  ${MANIFEST_DIR}/mv-params.json

cp ${REG_COMMON}/tool-params.json.template  ${MANIFEST_DIR}/tool-params.json
cp ${REG_COMMON}/securityContext.json.template  ${MANIFEST_DIR}/securityContext.json 
cp ${REG_COMMON}/annotations-pao.json.template  ${MANIFEST_DIR}/annotations.json

