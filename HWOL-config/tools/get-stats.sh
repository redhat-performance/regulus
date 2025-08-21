#!/bin/bash
#
# Get TC Offload Stats 
# Usage: ./get-stats.sh <worker-node> <interface>
# Example:
#        ./get-stats.sh d29-h13-000-r750  rickshaw-client-1
#        ./get-stats.sh d29-h13-000-r750  ens6f0np0_12  <-- representor

set -euo pipefail

# Check arguments
if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <worker-node> <pod-name|interface>"
    echo "Examples:"
    echo "  $0 worker-1 my-dpdk-pod-12345"
    echo "  $0 worker-1 eth0"
    exit 1
fi

WORKER_NODE="$1"
POD_OR_INTERFACE="$2"

echo "=== TC Offload Stats Check ==="
echo "Node: $WORKER_NODE"
echo "Target: $POD_OR_INTERFACE"
echo "Time: $(date)"
echo ""

# Function to run commands on the worker node
run_on_node() {
    oc debug node/"$WORKER_NODE" -- chroot /host bash -c "$1" 2>/dev/null
}

# Function to check if a command exists on the node
check_command_on_node() {
    local cmd="$1"
    run_on_node "command -v $cmd >/dev/null 2>&1 && echo 'yes' || echo 'no'"
}

# Function to find the busiest VF representor
find_busiest_vf() {
    # Use ip -s -j link with jq to find the interface with highest RX bytes
    local busiest_vf
    busiest_vf=$(run_on_node "
        # Check if jq is available
        if command -v jq >/dev/null 2>&1; then
            # Method 1: Use jq to find busiest VF representor
            ip -s -j link 2>/dev/null | jq -r '
                map(select(.ifname | test(\"(pf[0-9]+vf[0-9]+|ens[0-9]+f[0-9]+np[0-9]+_[0-9]+|eth[0-9]+_[0-9]+|rep[0-9]+|vf-[0-9]+|enp[0-9]+s[0-9]+f[0-9]+_[0-9]+)\"))) |
                max_by(.stats64.rx.bytes) |
                .ifname
            ' 2>/dev/null || echo ''
        else
            # Method 2: Fallback without jq - find busiest manually
            max_bytes=0
            max_iface=''
            for iface in /sys/class/net/*; do
                iface_name=\$(basename \"\$iface\")
                if [[ \"\$iface_name\" =~ (pf[0-9]+vf[0-9]+|ens[0-9]+f[0-9]+np[0-9]+_[0-9]+|eth[0-9]+_[0-9]+|rep[0-9]+|vf-[0-9]+|enp[0-9]+s[0-9]+f[0-9]+_[0-9]+) ]]; then
                    rx_bytes=\$(cat \"\$iface/statistics/rx_bytes\" 2>/dev/null || echo '0')
                    if [[ \$rx_bytes -gt \$max_bytes ]]; then
                        max_bytes=\$rx_bytes
                        max_iface=\$iface_name
                    fi
                fi
            done
            echo \"\$max_iface\"
        fi
    " 2>/dev/null || echo "")
    
    if [[ -n "$busiest_vf" ]]; then
        echo "Found busiest VF representor: $busiest_vf" >&2
        
        # Get detailed stats for the busiest interface
        local vf_stats
        vf_stats=$(run_on_node "
            if command -v jq >/dev/null 2>&1; then
                # Get detailed stats using jq
                ip -s -j link show dev $busiest_vf 2>/dev/null | jq -r '
                    .[0] | 
                    \"  RX: \" + (.stats64.rx.bytes | tostring) + \" bytes (\" + (.stats64.rx.packets | tostring) + \" packets)\" +
                    \"\\n  TX: \" + (.stats64.tx.bytes | tostring) + \" bytes (\" + (.stats64.tx.packets | tostring) + \" packets)\"
                ' 2>/dev/null || echo ''
            else
                # Fallback method
                rx_bytes=\$(cat /sys/class/net/$busiest_vf/statistics/rx_bytes 2>/dev/null || echo '0')
                tx_bytes=\$(cat /sys/class/net/$busiest_vf/statistics/tx_bytes 2>/dev/null || echo '0')
                rx_packets=\$(cat /sys/class/net/$busiest_vf/statistics/rx_packets 2>/dev/null || echo '0')
                tx_packets=\$(cat /sys/class/net/$busiest_vf/statistics/tx_packets 2>/dev/null || echo '0')
                printf '  RX: %s bytes (%s packets)\\n  TX: %s bytes (%s packets)' \"\$rx_bytes\" \"\$rx_packets\" \"\$tx_bytes\" \"\$tx_packets\"
            fi
        " 2>/dev/null || echo "")
        
        echo "$vf_stats" >&2
        echo "$busiest_vf"
        return 0
    else
        echo "No VF representor interfaces found" >&2
        return 1
    fi
}

# Determine what interfaces to check
interfaces_to_check=()

# Check if the input looks like a pod name (contains hyphens and alphanumeric)
if [[ "$POD_OR_INTERFACE" =~ ^[a-zA-Z0-9-]+$ ]] && [[ "$POD_OR_INTERFACE" == *-* ]]; then
    echo "Input appears to be a pod name, finding busiest VF representor..."
    vf_interface=$(find_busiest_vf)
    if [[ -n "$vf_interface" ]]; then
        interfaces_to_check=("$vf_interface")
        echo "Will check VF representor: $vf_interface"
    else
        echo "Failed to find VF representor, will check if input is a regular interface"
        interfaces_to_check=("$POD_OR_INTERFACE")
    fi
else
    echo "Input appears to be an interface name"
    interfaces_to_check=("$POD_OR_INTERFACE")
fi

echo ""

# Check each interface
for current_interface in "${interfaces_to_check[@]}"; do
    echo "=== Checking Interface: $current_interface ==="
    
    # Check if interface exists
    interface_exists=$(run_on_node "test -d /sys/class/net/$current_interface && echo 'yes' || echo 'no'")
    if [[ "$interface_exists" != "yes" ]]; then
        echo "Interface $current_interface does not exist on node $WORKER_NODE"
        continue
    fi
    

    
    # Check for OVS hardware offload instead of TC
    echo "OVS Hardware Offload Statistics ($current_interface):"
    
    # Check if interface is part of OVS
    ovs_info=$(run_on_node "ovs-vsctl list interface $current_interface 2>/dev/null || echo ''")
    if [[ -n "$ovs_info" ]]; then
        # Extract key info from ovs-vsctl output
        ovs_name=$(echo "$ovs_info" | grep -E "^name" | cut -d'"' -f2 2>/dev/null || echo "$current_interface")
        ovs_type=$(echo "$ovs_info" | grep -E "^type" | cut -d'"' -f2 2>/dev/null || echo "system")
        ofport=$(echo "$ovs_info" | grep -E "^ofport" | sed 's/ofport[[:space:]]*:[[:space:]]*//' | xargs 2>/dev/null || echo "")
        
        echo "  Interface: $ovs_name (type: $ovs_type, ofport: $ofport)"
        
        # Get all OVS flows and check for hardware offload
        echo "  Checking OVS datapath flows..."
        ovs_flows=$(run_on_node "ovs-appctl dpctl/dump-flows 2>/dev/null || echo ''")
        if [[ -n "$ovs_flows" ]]; then
            total_flows=$(echo "$ovs_flows" | wc -l)
            hw_offloaded=$(echo "$ovs_flows" | grep -c "offloaded:yes" || true)
            
            echo "  Total datapath flows: $total_flows"
            echo "  Hardware offloaded flows: $hw_offloaded"
            
            if [[ "$hw_offloaded" -gt 0 ]]; then
                echo "  Status: ✓ OVS Hardware offload ACTIVE"
                
                # Show some example offloaded flows
                echo "  Sample offloaded flows:"
                echo "$ovs_flows" | grep "offloaded:yes" | head -3 | while IFS= read -r flow; do
                    # Extract key parts of the flow
                    flow_match=$(echo "$flow" | cut -d',' -f1-4)
                    echo "    $flow_match..."
                done
            else
                echo "  Status: ✗ OVS Hardware offload NOT ACTIVE"
            fi
            
            # Check for flows that might be related to this VF (by looking for the ofport)
            if [[ -n "$ofport" ]] && [[ "$ofport" != "-1" ]] && [[ "$ofport" =~ ^[0-9]+$ ]]; then
                vf_flows=$(echo "$ovs_flows" | grep -E "(in_port\($ofport\)|actions:.*$ofport)" | wc -l || true)
                vf_hw_flows=$(echo "$ovs_flows" | grep -E "(in_port\($ofport\)|actions:.*$ofport)" | grep -c "offloaded:yes" || true)
                echo "  Flows involving this VF (port $ofport): $vf_flows (HW offloaded: $vf_hw_flows)"
            else
                echo "  Could not determine ofport number for VF-specific flow analysis"
            fi
            
        else
            echo "  No datapath flows found or dpctl command failed"
        fi
        
        # Also check OpenFlow flows
        echo ""
        echo "  OpenFlow table statistics:"
        of_stats=$(run_on_node "ovs-ofctl dump-flows br-int 2>/dev/null | grep -E '(n_packets|n_bytes)' | wc -l || true")
        echo "  Active OpenFlow rules: $of_stats"
        
    else
        echo "  Interface is not an OVS port"
        
        # Fall back to TC check
        echo ""
        echo "TC Filter Statistics ($current_interface):"
        tc_stats=$(run_on_node "tc -s filter show dev $current_interface 2>/dev/null || echo ''")
        if [[ -n "$tc_stats" ]]; then
            echo "Raw TC filters:"
            echo "$tc_stats"
            echo ""
            
            # Simple check for hardware offload
            if echo "$tc_stats" | grep -q "in_hw"; then
                echo "  Status: ✓ Hardware offload ACTIVE"
                hw_filters=$(echo "$tc_stats" | grep -c "in_hw" || true)
                echo "  Hardware offloaded filters: $hw_filters"
            else
                echo "  Status: ✗ Hardware offload NOT ACTIVE"
            fi
            
            if echo "$tc_stats" | grep -q "not_in_hw"; then
                sw_filters=$(echo "$tc_stats" | grep -c "not_in_hw" || true)
                echo "  Software only filters: $sw_filters"
            fi
        else
            echo "  No TC filters configured"
        fi
    fi
    echo ""
    
    # Get interface counters
    echo "Interface Statistics ($current_interface):"
    run_on_node "
        rx_packets=\$(cat /sys/class/net/$current_interface/statistics/rx_packets 2>/dev/null || echo '0')
        tx_packets=\$(cat /sys/class/net/$current_interface/statistics/tx_packets 2>/dev/null || echo '0')
        rx_bytes=\$(cat /sys/class/net/$current_interface/statistics/rx_bytes 2>/dev/null || echo '0')
        tx_bytes=\$(cat /sys/class/net/$current_interface/statistics/tx_bytes 2>/dev/null || echo '0')
        rx_dropped=\$(cat /sys/class/net/$current_interface/statistics/rx_dropped 2>/dev/null || echo '0')
        tx_dropped=\$(cat /sys/class/net/$current_interface/statistics/tx_dropped 2>/dev/null || echo '0')
        
        printf \"  RX: %'d packets (%'d bytes)\\n\" \"\$rx_packets\" \"\$rx_bytes\"
        printf \"  TX: %'d packets (%'d bytes)\\n\" \"\$tx_packets\" \"\$tx_bytes\"
        printf \"  Dropped: RX %'d, TX %'d\\n\" \"\$rx_dropped\" \"\$tx_dropped\"
    " 2>/dev/null || echo "  Stats unavailable"
    echo ""
    
    # Get key hardware stats for OVS offload
    echo "Hardware Statistics ($current_interface):"
    hw_stats=$(run_on_node "ethtool -S $current_interface 2>/dev/null || echo ''")
    if [[ -n "$hw_stats" ]]; then
        # Look for OVS/hardware offload specific counters
        echo "  Hardware Offload Counters:"
        echo "$hw_stats" | grep -iE "(rx_packets_phy|tx_packets_phy|rx_vport|tx_vport|vf_rx|vf_tx)" | head -8 | \
        while IFS=':' read -r name value; do
            value=$(echo "$value" | xargs)
            if [[ "$value" =~ ^[0-9]+$ ]] && [[ "$value" -gt 0 ]]; then
                printf "    %-25s: %'d\n" "$name" "$value"
            fi
        done
        
        echo "  Flow Steering Counters:"
        echo "$hw_stats" | grep -iE "(fs_|flow_steering|steering)" | head -5 | \
        while IFS=':' read -r name value; do
            value=$(echo "$value" | xargs)
            if [[ "$value" =~ ^[0-9]+$ ]] && [[ "$value" -gt 0 ]]; then
                printf "    %-25s: %'d\n" "$name" "$value"
            fi
        done
    else
        echo "  No hardware stats available"
    fi
    echo ""
done

echo "=== Check Complete ==="
