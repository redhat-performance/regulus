#!/bin/bash

REG_ROOT=${REG_ROOT:-/root/regulus}
REG_TEMPLATES=./templates
MANIFEST_DIR=./
source ${REG_ROOT}/lab.config
source ${REG_ROOT}/system.config
source ${REG_ROOT}/SRIOV-config/config.env
source ${REG_ROOT}/templates/common/worker_labels.config

if [ -z "${CLUSTER_TYPE}" ]; then
    echo "Please prepare lab by \"make init-lab\" at top level prior to coming here"
    exit 1
fi

if [ "${CLUSTER_TYPE}" != "STANDARD" ]; then
    # these cluster types (SNO and 3-node compact) only have MCP master
    MCP="master" 
fi


# MCP's single source of truth is at SRIOV-config/config.env
export MCP

# Function to get worker nodes based on match criteria
get_worker_nodes() {
    # Build the jq selector based on MATCH and MATCH_NOT variables
    local my_select_var
    # Support one MATCH label and 4 MATCH_NOT labels for worker selection
    if [[ -z "$MATCH" ]]; then
        my_select_var=".metadata.labels.\"node-role.kubernetes.io/worker\" != null"
    else
        my_select_var=".metadata.labels.\"node-role.kubernetes.io/$MATCH\" != null"
    fi
    if [[ -n "$MATCH_NOT_1" ]]; then
        my_select_var+=" and .metadata.labels.\"node-role.kubernetes.io/$MATCH_NOT_1\" == null"
    fi
    if [[ -n "$MATCH_NOT_2" ]]; then
        my_select_var+=" and .metadata.labels.\"node-role.kubernetes.io/$MATCH_NOT_2\" == null"
    fi
    if [[ -n "$MATCH_NOT_3" ]]; then
        my_select_var+=" and .metadata.labels.\"node-role.kubernetes.io/$MATCH_NOT_3\" == null"
    fi
    if [[ -n "$MATCH_NOT_4" ]]; then
        my_select_var+=" and .metadata.labels.\"node-role.kubernetes.io/$MATCH_NOT_4\" == null"
    fi
    echo "Using node selector: $my_select_var" >&2
    # Get nodes using the constructed selector - return space-separated list
    kubectl get nodes -o json | jq -r ".items[] | select($my_select_var) | .metadata.name" | tr '\n' ' ' | sed 's/ $//'
}

# Get all worker nodes using match criteria and assign to WORKER_0

if [[ -z "$RE_HWOL_WORKER_LIST" ]]; then
   OCP_WORKER_LIST=$(get_worker_nodes)
fi
if [[ -z "$OCP_WORKER_LIST" ]]; then
   echo "Error: No worker nodes found matching the specified criteria" >&2
   echo "Match criteria used:" >&2
   echo "  MATCH: ${MATCH:-worker (default)}" >&2
   echo "  MATCH_NOT_1: ${MATCH_NOT_1:-<not set>}" >&2
   echo "  MATCH_NOT_2: ${MATCH_NOT_2:-<not set>}" >&2
   echo "  MATCH_NOT_3: ${MATCH_NOT_3:-<not set>}" >&2
   echo "  MATCH_NOT_4: ${MATCH_NOT_4:-<not set>}" >&2
   exit 1
fi

echo "Found worker nodes: $OCP_WORKER_LIST"

export OCP_WORKER_LIST 

envsubst '$MCP,$OCP_WORKER_LIST' < ${REG_TEMPLATES}/setting.env.template > ${MANIFEST_DIR}/setting.env

