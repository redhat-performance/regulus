#!/bin/bash
#
# SR-IOV Health Monitor - There were times when HWOF-config/make install got stuck. One or more nodes
#   did not reboot to flip mode from legacy->switchdev.  If confirm, they need manual rebootd.
#
# Usage: bash offload_progress.sh
# Env: run from the bastion
#
# Dependencies: MCP worker and reghwol are hardcoded.
#

echo " SR-IOV Health Check - $(date)"
echo "=================================="

# Check overall states
echo " Node States:"
oc get sriovnetworknodestates -n openshift-sriov-network-operator

# Check for problematic patterns
STUCK_NODES=$(oc get sriovnetworknodestates -n openshift-sriov-network-operator --no-headers | \
              awk '$2=="InProgress" && $3=="Idle" && $4=="Idle" {print $1}')

if [ -n "$STUCK_NODES" ]; then
    echo " REBOOT LIKELY NEEDED for: $STUCK_NODES"
    
    for node in $STUCK_NODES; do
        echo "   Checking $node logs..."
        POD=$(oc get pods -n openshift-sriov-network-operator -l app=sriov-network-config-daemon \
              --field-selector spec.nodeName=$node --no-headers | awk '{print $1}')
        
        if [ -n "$POD" ]; then
            MSTCONFIG_COUNT=$(oc logs -n openshift-sriov-network-operator $POD --since=5m | \
                             grep "mstconfig.*-d.*q" | wc -l)
            if [ "$MSTCONFIG_COUNT" -gt 5 ]; then
                echo "   🔄 $node: $MSTCONFIG_COUNT mstconfig queries in 5min - FIRMWARE LOOP!"
            fi
        fi
    done
fi

echo " MCP Status:"
oc get mcp | grep -E "(reghwol|worker)"

