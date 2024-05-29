#!/bin/bash
# iperf IPv4, INGRESS,2 Pods

REG_ROOT=${REG_ROOT:-/root/REGULUS}
REG_TEMPLATES=${REG_ROOT}/templates/iperf
REG_COMMON=${REG_ROOT}/templates/common
MANIFEST_DIR=./

export TPL_SCALE_UP_FACTOR=8
export TPL_TOPO=ingress
export TPL_PAO=1

envsubst '$MCP,$TPL_PAO,$TPL_SCALE_UP_FACTOR,$TPL_TOPO' < ${REG_TEMPLATES}/run.sh.template > ${MANIFEST_DIR}/run.sh
export TPL_INTF=eth0
export TPL_EP=$IPSEC_EP     # define IPSEC_EP in jobs.config
export TPL_IPV=4
export TPL_DIR=
envsubst '$TPL_INTF,$IPSEC_EP,$TPL_IPV,$TPL_DIR' <  ${REG_TEMPLATES}/tcp-ingress-ipsec-mv-params.json.template >  ${MANIFEST_DIR}/mv-params.json

cp ${REG_COMMON}/tool-params.json.template  ${MANIFEST_DIR}/tool-params.json
cp ${REG_COMMON}/annotations-pao.json.template  ${MANIFEST_DIR}/annotations.json
