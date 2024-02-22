#!/bin/bash

REG_ROOT=${REG_ROOT:-/root/regulus}
REG_TEMPLATES=./templates
MANIFEST_DIR=./

envsubst '$MCP,$OCP_WORKER_0,$OCP_WORKER_1,$OCP_WORKER_2' < ${REG_TEMPLATES}/setting.env.template > ${MANIFEST_DIR}/setting.env

