#!/bin/bash

REG_ROOT=${REG_ROOT:-/root/REGULUS}
REG_TEMPLATES=${REG_ROOT}/templates/uperf
MANIFEST_DIR=./

export TPL_SCALE_UP_FACTOR=1
export TPL_TOPO=internode

envsubst '$TPL_SCALE_UP_FACTOR,$TPL_TOPO' < ${REG_TEMPLATES}/run.sh.template > ${MANIFEST_DIR}/run.sh
cp ${REG_TEMPLATES}/tcp-mv-params.json.template  ${MANIFEST_DIR}/mv-params.json
cp ${REG_TEMPLATES}/tool-params.json.template  ${MANIFEST_DIR}/tool-params.json


