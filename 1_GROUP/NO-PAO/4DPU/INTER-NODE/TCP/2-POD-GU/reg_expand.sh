#!/bin/bash
# uperf DPU,NO-PAO,IPv4,INTER_NODE,2 Pods, GU

REG_ROOT=${REG_ROOT:-/root/REGULUS}
# SUBSET_TESTS=NIC-MODE selects reduced test params (NIC-BOND-TEST folders only)
if [ "${SUBSET_TESTS}" = "NIC-MODE" ]; then
    REG_TEMPLATES=${REG_ROOT}/templates/uperf/NIC-BOND-TEST
    export TPL_MVPARAMS=${TPL_MVPARAMS:-r1-tcp-mv-params.json.template}
else
    REG_TEMPLATES=${REG_ROOT}/templates/uperf
    export TPL_MVPARAMS=${TPL_MVPARAMS:-tcp-mv-params.json.template}
fi
REG_COMMON=${REG_ROOT}/templates/common
MANIFEST_DIR=./

export TPL_SCALE_UP_FACTOR=1
export TPL_TOPO=internode
export TPL_QOS=guaranteed
export TPL_PAO=0

export TPL_QOS=guaranteed
export TPL_NUMCPUs=0
export TPL_DPF=1

envsubst '\$TPL_QOS,$TPL_PAO,$TPL_DPF,\$TPL_NUMCPUs,$TPL_QOS,$MCP,$TPL_PAO,$TPL_SCALE_UP_FACTOR,$TPL_TOPO' < ${REG_TEMPLATES}/run.sh.template > ${MANIFEST_DIR}/run.sh
export TPL_INTF=eth0
export TPL_IPV=4
envsubst '$TPL_IPV,$TPL_INTF' <  ${REG_TEMPLATES}/${TPL_MVPARAMS} >  ${MANIFEST_DIR}/mv-params.json

cp ${REG_COMMON}/tool-params.json.template  ${MANIFEST_DIR}/tool-params.json
cp ${REG_COMMON}/annotations-pao-qos.json.template  ${MANIFEST_DIR}/annotations-pao-qos.json
cp ${REG_COMMON}/annotations-dpf.json.template  ${MANIFEST_DIR}/annotations.json
cp ${REG_COMMON}/resource-dpf.json.template ${MANIFEST_DIR}/resource-dpf.json

