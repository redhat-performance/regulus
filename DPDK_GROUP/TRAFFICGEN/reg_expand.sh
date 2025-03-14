#!/bin/bash
# trafficgen 4CPUs, "mac" forwarding mode.

REG_ROOT=${REG_ROOT:-/root/REGULUS}
REG_TEMPLATES=${REG_ROOT}/templates/trafficgen
REG_COMMON=${REG_ROOT}/templates/common
MANIFEST_DIR=./

export TPL_FWD_MODE=mac
export TPL_NUMCPUS=4
envsubst '$MCP' < ${REG_TEMPLATES}/run.sh.template > ${MANIFEST_DIR}/run.sh
envsubst '$TPL_FWD_MODE' <  ${REG_TEMPLATES}/mv-params.json.template >  ${MANIFEST_DIR}/mv-params.json
envsubst '$TPL_NUMCPUS' <  ${REG_TEMPLATES}/resources.json.template >  ${MANIFEST_DIR}/resources.json
envsubst '' <  ${REG_TEMPLATES}/annotations.json.template  > ${MANIFEST_DIR}/annotations.json

cp ${REG_COMMON}/tool-params.json.template  ${MANIFEST_DIR}/tool-params.json
cp ${REG_COMMON}/securityContext.json.template  ${MANIFEST_DIR}/securityContext.json
