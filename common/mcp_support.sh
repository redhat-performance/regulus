#!/bin/bash

# This modulde To Be sourced .
# Regulus uses the same MCP for more than one features. Thus the MCP needs a reference_couter.
#
# MCP Reference Counter Module
# Source this file and call functions directly:
#   source mcp-counter.sh
#   mcp_counter_add <mcp_name> <feature_name>
#   mcp_counter_del <mcp_name> <feature_name>
#   mcp_counter_get <mcp_name>

COUNTER_ANNOTATION="feature.openshift.io/reference-count"
REFERENCES_ANNOTATION="feature.openshift.io/references"

# Function to add a feature reference and increment counter
mcp_counter_add() {
    local mcp_name="$1"
    local feature_name="$2"
    
    if [[ -z "${mcp_name}" || -z "${feature_name}" ]]; then
        echo "Usage: mcp_counter_add <mcp_name> <feature_name>"
        return 1
    fi
    
    if ! oc get mcp "${mcp_name}" &>/dev/null; then
        echo "Error: MCP ${mcp_name} does not exist"
        return 1
    fi
    
    # Get current counter value
    current_count=$(oc get mcp "${mcp_name}" -o jsonpath="{.metadata.annotations['feature\.openshift\.io/reference-count']}" 2>/dev/null || echo "0")
    
    # Get current references
    current_refs=$(oc get mcp "${mcp_name}" -o jsonpath="{.metadata.annotations['feature\.openshift\.io/references']}" 2>/dev/null || echo "")
    
    # Check if feature already referenced (prevent double counting)
    if echo "${current_refs}" | grep -q "\b${feature_name}\b"; then
        echo "Warning: Feature ${feature_name} already referenced in MCP ${mcp_name}"
        return 0
    fi
    
    # Increment counter
    new_count=$((current_count + 1))
    
    # Update references list
    if [[ -z "${current_refs}" ]]; then
        new_refs="${feature_name}"
    else
        new_refs="${current_refs},${feature_name}"
    fi
    
    # Update MCP annotations
    oc annotate mcp "${mcp_name}" "${COUNTER_ANNOTATION}=${new_count}" --overwrite >/dev/null
    oc annotate mcp "${mcp_name}" "${REFERENCES_ANNOTATION}=${new_refs}" --overwrite >/dev/null
    
    #echo "Added feature ${feature_name} to MCP ${mcp_name}. Counter: ${current_count} -> ${new_count}"
}

# Function to remove a feature reference and decrement counter
mcp_counter_del() {
    local mcp_name="$1"
    local feature_name="$2"
    
    if [[ -z "${mcp_name}" || -z "${feature_name}" ]]; then
        echo "Usage: mcp_counter_del <mcp_name> <feature_name>"
        return 1
    fi
    
    if ! oc get mcp "${mcp_name}" &>/dev/null; then
        echo "Warning: MCP ${mcp_name} does not exist"
        return 0
    fi
    
    # Get current counter value
    current_count=$(oc get mcp "${mcp_name}" -o jsonpath="{.metadata.annotations['feature\.openshift\.io/reference-count']}" 2>/dev/null || echo "0")
    
    # Get current references
    current_refs=$(oc get mcp "${mcp_name}" -o jsonpath="{.metadata.annotations['feature\.openshift\.io/references']}" 2>/dev/null || echo "")
    
    # Check if feature is actually referenced
    if ! echo "${current_refs}" | grep -q "\b${feature_name}\b"; then
        echo "Warning: Feature ${feature_name} not found in MCP ${mcp_name} references"
        return 0
    fi
    
    # Decrement counter
    new_count=$((current_count - 1))
    
    # Ensure counter doesn't go below 0
    if [[ ${new_count} -lt 0 ]]; then
        new_count=0
    fi
    
    # Remove feature from references list
    new_refs=$(echo "${current_refs}" | sed "s/,${feature_name}//g" | sed "s/${feature_name},//g" | sed "s/^${feature_name}$//g")
    
    # Update annotations
    oc annotate mcp "${mcp_name}" "${COUNTER_ANNOTATION}=${new_count}" --overwrite >/dev/null
    oc annotate mcp "${mcp_name}" "${REFERENCES_ANNOTATION}=${new_refs}" --overwrite >/dev/null
    
    #echo "Removed feature ${feature_name} from MCP ${mcp_name}. Counter: ${current_count} -> ${new_count}"
    
}

# Function to get reference counter value
mcp_counter_get() {
    local mcp_name="$1"
    
    if [[ -z "${mcp_name}" ]]; then
        echo "Usage: mcp_counter_get <mcp_name>"
        return 1
    fi
    
    if ! oc get mcp "${mcp_name}" &>/dev/null; then
        echo "0"
        return 0
    fi
    
    # Use bracket notation for annotation keys with dots
    counter=$(oc get mcp "${mcp_name}" -o jsonpath="{.metadata.annotations['feature\.openshift\.io/reference-count']}" 2>/dev/null || echo "0")
    echo "${counter}"
}
#EOF
