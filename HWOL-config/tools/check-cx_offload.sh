#!/bin/bash

# ConnectX Offload Checker 
# This script checks if ConnectX hardware offload features are active in OpenShift
# Supports ConnectX-5, ConnectX-6, ConnectX-7, and ConnectX-8 series
# Usage: ./check_cx_offload.sh [OPTIONS] <interface_name>
# 
# OPTIONS:
#   -s, --status-only    Show only offload status (on/off) - concise output
#   -a, --all           Show detailed analysis (default)
#   -h, --help          Show this help message
#
# Examples:
#   ./check_cx_offload.sh -s ens8f0          # Status only
#   ./check_cx_offload.sh -a ens8f0          # Full analysis
#   ./check_cx_offload.sh ens8f0             # Status only (default)
#
# Env: run this script from the bastion.

set -e

# Default values
STATUS_ONLY=true
INTERFACE_NAME=""

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--status-only)
                STATUS_ONLY=true
                shift
                ;;
            -a|--all)
                STATUS_ONLY=false
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                echo "Unknown option $1"
                show_help
                exit 1
                ;;
            *)
                if [ -z "$INTERFACE_NAME" ]; then
                    INTERFACE_NAME="$1"
                else
                    echo "Too many arguments"
                    show_help
                    exit 1
                fi
                shift
                ;;
        esac
    done
}

# Show help message
show_help() {
    echo "Usage: $0 [OPTIONS] <interface_name>"
    echo ""
    echo "OPTIONS:"
    echo "  -s, --status-only    Show only offload status (on/off) - concise output"
    echo "  -a, --all           Show detailed analysis (default)"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -s ens8f0          # Status only"
    echo "  $0 -a ens8f0          # Full analysis"
    echo "  $0 ens8f0             # Full analysis (default)"
}

# Parse arguments
parse_args "$@"

# Function to print status output
print_status() {
    local status=$1
    local message=$2
    
    if [ "$STATUS_ONLY" = true ]; then
        # Only print ERROR messages in status-only mode
        case $status in
            "ERROR")
                echo "[ERROR] $message"
                ;;
        esac
    else
        # Print all messages in full mode
        case $status in
            "SUCCESS")
                echo "[SUCCESS] $message"
                ;;
            "WARNING")
                echo "[WARNING] $message"
                ;;
            "ERROR")
                echo "[ERROR] $message"
                ;;
            "INFO")
                echo "[INFO] $message"
                ;;
        esac
    fi
}

# Function to print status-only output
print_status_only() {
    local feature=$1
    local status=$2
    local details=$3
    
    if [ -n "$details" ]; then
        printf "%-20s: %-8s (%s)\n" "$feature" "$status" "$details"
    else
        printf "%-20s: %s\n" "$feature" "$status"
    fi
}

# Function to validate interface name
validate_interface() {
    if [ -z "$INTERFACE_NAME" ]; then
        print_status "ERROR" "Please specify an interface name"
        echo "Usage: $0 <interface_name>"
        echo "Example: $0 ens8f0"
        exit 1
    fi
    print_status "INFO" "Checking interface: $INTERFACE_NAME"
}

# Function to check if running in OpenShift environment
check_openshift_env() {
    print_status "INFO" "Checking OpenShift environment..."
    
    if ! command -v oc &> /dev/null; then
        print_status "ERROR" "OpenShift CLI (oc) not found. Please install oc client."
        exit 1
    fi
    
    if ! oc whoami &> /dev/null; then
        print_status "ERROR" "Not logged into OpenShift cluster. Please run 'oc login'."
        exit 1
    fi
    
    print_status "SUCCESS" "Connected to OpenShift cluster: $(oc whoami --show-server)"
}

# Function to check offload status only (concise mode)
check_offload_status_only() {
    print_status "INFO" "Checking offload status for interface: $INTERFACE_NAME"
    
    for node in "${NODES_WITH_INTERFACE[@]}"; do
        echo
        echo "Node: $node"
        echo "Interface: $INTERFACE_NAME"
        echo "----------------------------------------"
        
        # Get all offload information in one debug session
        local offload_info=$(oc debug node/$node -- chroot /host bash -c "
            # Check if interface exists
            if [[ ! -d /sys/class/net/$INTERFACE_NAME ]]; then
                echo \"ERROR: Interface not found\"
                exit 1
            fi
            
            # Get driver info
            driver=\$(ethtool -i $INTERFACE_NAME 2>/dev/null | grep driver | awk '{print \$2}')
            echo \"DRIVER:\$driver\"
            
            # Get TC offload status
            tc_status=\$(ethtool -k $INTERFACE_NAME 2>/dev/null | grep -E 'hw-tc-offload' | awk '{print \$2}')
            echo \"TC_OFFLOAD:\$tc_status\"
            
            # Get other offload features
            rx_csum=\$(ethtool -k $INTERFACE_NAME 2>/dev/null | grep 'rx-checksumming' | awk '{print \$2}')
            tx_csum=\$(ethtool -k $INTERFACE_NAME 2>/dev/null | grep 'tx-checksumming' | awk '{print \$2}')
            tso=\$(ethtool -k $INTERFACE_NAME 2>/dev/null | grep 'tcp-segmentation-offload' | awk '{print \$2}')
            gro=\$(ethtool -k $INTERFACE_NAME 2>/dev/null | grep 'generic-receive-offload' | awk '{print \$2}')
            gso=\$(ethtool -k $INTERFACE_NAME 2>/dev/null | grep 'generic-segmentation-offload' | awk '{print \$2}')
            
            echo \"RX_CHECKSUM:\$rx_csum\"
            echo \"TX_CHECKSUM:\$tx_csum\"
            echo \"TSO:\$tso\"
            echo \"GRO:\$gro\"
            echo \"GSO:\$gso\"
            
            # Get switchdev mode if available
            if [[ -L /sys/class/net/$INTERFACE_NAME/device ]]; then
                pci_path=\$(readlink /sys/class/net/$INTERFACE_NAME/device)
                pci_id=\$(basename \$pci_path)
                switchdev_mode=\$(devlink dev eswitch show pci/\$pci_id 2>/dev/null | grep -o 'mode [a-z]*' | awk '{print \$2}' || echo 'unknown')
                echo \"SWITCHDEV_MODE:\$switchdev_mode\"
                
                # Get SR-IOV VF count
                if [[ -f /sys/class/net/$INTERFACE_NAME/device/sriov_numvfs ]]; then
                    numvfs=\$(cat /sys/class/net/$INTERFACE_NAME/device/sriov_numvfs)
                    echo \"SRIOV_VFS:\$numvfs\"
                else
                    echo \"SRIOV_VFS:N/A\"
                fi
            else
                echo \"SWITCHDEV_MODE:unknown\"
                echo \"SRIOV_VFS:N/A\"
            fi
        " 2>/dev/null)
        
        # Parse and display the results
        if echo "$offload_info" | grep -q "ERROR:"; then
            echo "$offload_info"
            continue
        fi
        
        # Extract values and display formatted output
        local driver=$(echo "$offload_info" | grep "DRIVER:" | cut -d: -f2)
        local tc_offload=$(echo "$offload_info" | grep "TC_OFFLOAD:" | cut -d: -f2)
        local rx_checksum=$(echo "$offload_info" | grep "RX_CHECKSUM:" | cut -d: -f2)
        local tx_checksum=$(echo "$offload_info" | grep "TX_CHECKSUM:" | cut -d: -f2)
        local tso=$(echo "$offload_info" | grep "TSO:" | cut -d: -f2)
        local gro=$(echo "$offload_info" | grep "GRO:" | cut -d: -f2)
        local gso=$(echo "$offload_info" | grep "GSO:" | cut -d: -f2)
        local switchdev_mode=$(echo "$offload_info" | grep "SWITCHDEV_MODE:" | cut -d: -f2)
        local sriov_vfs=$(echo "$offload_info" | grep "SRIOV_VFS:" | cut -d: -f2)
        
        # Determine ConnectX generation based on PCI info
        local connectx_gen="Unknown"
        local pci_info=$(oc debug node/$node -- chroot /host bash -c "
            if [[ -L /sys/class/net/$INTERFACE_NAME/device ]]; then
                pci_path=\$(readlink /sys/class/net/$INTERFACE_NAME/device)
                pci_id=\$(basename \$pci_path)
                lspci -s \$pci_id 2>/dev/null
            fi
        " 2>/dev/null)
        
        if echo "$pci_info" | grep -iq "connectx-8\|cx8"; then
            connectx_gen="ConnectX-8"
        elif echo "$pci_info" | grep -iq "connectx-7\|cx7"; then
            connectx_gen="ConnectX-7"
        elif echo "$pci_info" | grep -iq "connectx-6\|cx6"; then
            connectx_gen="ConnectX-6"
        elif echo "$pci_info" | grep -iq "connectx-5\|cx5"; then
            connectx_gen="ConnectX-5"
        elif echo "$pci_info" | grep -iq "connectx"; then
            connectx_gen="ConnectX"
        elif [[ "$driver" == "mlx5_core" ]]; then
            connectx_gen="ConnectX (mlx5)"
        fi
        
        print_status_only "Hardware" "$connectx_gen"
        print_status_only "Driver" "$driver"
        print_status_only "TC Hardware Offload" "$tc_offload"
        print_status_only "RX Checksum" "$rx_checksum"
        print_status_only "TX Checksum" "$tx_checksum"
        print_status_only "TSO" "$tso"
        print_status_only "GRO" "$gro"
        print_status_only "GSO" "$gso"
        print_status_only "Switchdev Mode" "$switchdev_mode"
        print_status_only "SR-IOV VFs" "$sriov_vfs"
        
        echo
        
        # Summary assessment
        echo "OFFLOAD READINESS SUMMARY:"
        if [[ "$tc_offload" == "on" && "$switchdev_mode" == "switchdev" ]]; then
            echo "✓ TC Hardware Offload: READY"
        elif [[ "$tc_offload" == "on" && "$switchdev_mode" != "switchdev" ]]; then
            echo "⚠ TC Hardware Offload: ENABLED but not in switchdev mode"
        else
            echo "✗ TC Hardware Offload: NOT READY"
        fi
        
        if [[ "$rx_checksum" == "on" && "$tx_checksum" == "on" && "$tso" == "on" ]]; then
            echo "✓ Basic Offloads: ENABLED"
        else
            echo "⚠ Basic Offloads: PARTIALLY ENABLED"
        fi
    done
}
find_nodes_with_interface() {
    print_status "INFO" "Finding nodes with interface $INTERFACE_NAME..."
    
    local nodes=$(oc get nodes --no-headers -l node-role.kubernetes.io/worker | awk '{print $1}')
    NODES_WITH_INTERFACE=()
    
    for node in $nodes; do
        print_status "INFO" "Checking node $node for interface $INTERFACE_NAME..."
        local has_interface=$(oc debug node/$node -- chroot /host bash -c "ls /sys/class/net/ | grep -x $INTERFACE_NAME" 2>/dev/null || true)
        
        if [ -n "$has_interface" ]; then
            NODES_WITH_INTERFACE+=("$node")
            print_status "SUCCESS" "Interface $INTERFACE_NAME found on node: $node"
        else
            print_status "INFO" "Interface $INTERFACE_NAME not found on node: $node"
        fi
    done
    
    if [ ${#NODES_WITH_INTERFACE[@]} -eq 0 ]; then
        print_status "ERROR" "Interface $INTERFACE_NAME not found on any worker nodes"
        exit 1
    fi
    
    print_status "INFO" "Found interface $INTERFACE_NAME on ${#NODES_WITH_INTERFACE[@]} node(s)"
}

# Function to check for SR-IOV Network Operator
check_sriov_operator() {
    print_status "INFO" "Checking SR-IOV Network Operator..."
    
    local sriov_operator=$(oc get pods -n openshift-sriov-network-operator --no-headers 2>/dev/null | wc -l)
    if [ "$sriov_operator" -gt 0 ]; then
        print_status "SUCCESS" "SR-IOV Network Operator is deployed"
        oc get pods -n openshift-sriov-network-operator
    else
        print_status "WARNING" "SR-IOV Network Operator not found"
    fi
}

# Function to check for ConnectX devices
check_cx_devices() {
    print_status "INFO" "Checking if $INTERFACE_NAME is a ConnectX device..."
    
    for node in "${NODES_WITH_INTERFACE[@]}"; do
        echo
        echo "Node: $node"
        
        # Check if the specific interface is ConnectX series
        local interface_info=$(oc debug node/$node -- chroot /host bash -c "
            # Get driver info
            echo \"Interface: $INTERFACE_NAME\"
            echo \"Driver Info:\"
            ethtool -i $INTERFACE_NAME 2>/dev/null || echo \"  Could not get driver info\"
            
            # Get PCI device info
            if [[ -L /sys/class/net/$INTERFACE_NAME/device ]]; then
                pci_path=\$(readlink /sys/class/net/$INTERFACE_NAME/device)
                pci_id=\$(basename \$pci_path)
                echo \"PCI Device: \$pci_id\"
                pci_info=\$(lspci -s \$pci_id -v 2>/dev/null | head -5)
                echo \"\$pci_info\"
                
                # Try to get more specific device info
                device_name=\$(lspci -s \$pci_id 2>/dev/null | cut -d: -f3- | sed 's/^ *//')
                echo \"Device: \$device_name\"
            fi
        " 2>/dev/null)
        
        echo "$interface_info"
        
        # Check if it's a ConnectX device and determine generation
        local connectx_gen=""
        if echo "$interface_info" | grep -iq "connectx-8\|cx8"; then
            connectx_gen="ConnectX-8"
        elif echo "$interface_info" | grep -iq "connectx-7\|cx7"; then
            connectx_gen="ConnectX-7"
        elif echo "$interface_info" | grep -iq "connectx-6\|cx6"; then
            connectx_gen="ConnectX-6"
        elif echo "$interface_info" | grep -iq "connectx-5\|cx5"; then
            connectx_gen="ConnectX-5"
        elif echo "$interface_info" | grep -iq "connectx"; then
            connectx_gen="ConnectX (generation unknown)"
        elif echo "$interface_info" | grep -iq "mlx5_core"; then
            connectx_gen="ConnectX series (mlx5_core driver)"
        fi
        
        if [ -n "$connectx_gen" ]; then
            print_status "SUCCESS" "Interface $INTERFACE_NAME is a $connectx_gen device"
        else
            print_status "WARNING" "Interface $INTERFACE_NAME may not be a ConnectX device"
        fi
    done
}

# Function to check SR-IOV Network Node Policies
check_sriov_policies() {
    print_status "INFO" "Checking SR-IOV Network Node Policies..."
    
    local policies=$(oc get sriovnetworknodepolicy -n openshift-sriov-network-operator --no-headers 2>/dev/null | wc -l)
    if [ "$policies" -gt 0 ]; then
        print_status "SUCCESS" "Found SR-IOV Network Node Policies:"
        oc get sriovnetworknodepolicy -n openshift-sriov-network-operator -o wide
    else
        print_status "WARNING" "No SR-IOV Network Node Policies found"
    fi
}

# Function to check SR-IOV Networks
check_sriov_networks() {
    print_status "INFO" "Checking SR-IOV Networks..."
    
    local networks=$(oc get sriovnetwork -A --no-headers 2>/dev/null | wc -l)
    if [ "$networks" -gt 0 ]; then
        print_status "SUCCESS" "Found SR-IOV Networks:"
        oc get sriovnetwork -A -o wide
    else
        print_status "WARNING" "No SR-IOV Networks found"
    fi
}

# Function to check for hardware offload features on the specific interface
check_hardware_offload() {
    print_status "INFO" "Checking hardware offload features for $INTERFACE_NAME..."
    
    for node in "${NODES_WITH_INTERFACE[@]}"; do
        echo
        echo "Node: $node"
        
        print_status "INFO" "Checking offload capabilities for interface $INTERFACE_NAME..."
        
        oc debug node/$node -- chroot /host bash -c "
            echo \"=== Interface: $INTERFACE_NAME ===\"
            
            # Check if interface exists and get basic info
            if [[ ! -d /sys/class/net/$INTERFACE_NAME ]]; then
                echo \"Interface $INTERFACE_NAME not found\"
                exit 1
            fi
            
            # Get interface status
            echo \"Interface Status:\"
            ip link show $INTERFACE_NAME 2>/dev/null | head -2
            
            echo
            echo \"Offload Features:\"
            ethtool -k $INTERFACE_NAME 2>/dev/null | grep -E '(rx-checksumming|tx-checksumming|tcp-segmentation-offload|receive-hashing|large-receive-offload|generic-receive-offload|generic-segmentation-offload)' || echo \"Could not get offload features\"
            
            echo
            echo \"Ring Parameters:\"
            ethtool -g $INTERFACE_NAME 2>/dev/null || echo \"Could not get ring parameters\"
            
            echo
            echo \"Coalesce Settings:\"
            ethtool -c $INTERFACE_NAME 2>/dev/null | head -5 || echo \"Could not get coalesce settings\"
        " 2>/dev/null || print_status "WARNING" "Could not check offload features for $INTERFACE_NAME on node $node"
    done
}

# Function to check TC (Traffic Control) offload capabilities
check_tc_offload() {
    print_status "INFO" "Checking TC (Traffic Control) offload capabilities for $INTERFACE_NAME..."
    
    for node in "${NODES_WITH_INTERFACE[@]}"; do
        echo
        echo "Node: $node"
        
        print_status "INFO" "Analyzing TC offload for interface $INTERFACE_NAME..."
        
        oc debug node/$node -- chroot /host bash -c "
            echo '=== TC Offload Status for $INTERFACE_NAME ==='
            
            # Check if interface exists
            if [[ ! -d /sys/class/net/$INTERFACE_NAME ]]; then
                echo \"Interface $INTERFACE_NAME not found\"
                exit 1
            fi
            
            # Get driver information
            driver=\$(ethtool -i $INTERFACE_NAME 2>/dev/null | grep driver | awk '{print \$2}')
            echo \"Interface: $INTERFACE_NAME (Driver: \$driver)\"
            
            # Check if TC offload is supported
            echo \"TC Offload Support:\"
            ethtool -k $INTERFACE_NAME 2>/dev/null | grep -E '(hw-tc-offload|tc-offload)' || echo \"  No TC offload capability found\"
            
            # Check current TC configuration
            echo
            echo \"Current TC Configuration:\"
            echo \"  Qdisc:\"
            tc qdisc show dev $INTERFACE_NAME 2>/dev/null || echo \"    No qdisc configured\"
            
            echo \"  Filters:\"
            tc filter show dev $INTERFACE_NAME 2>/dev/null || echo \"    No filters configured\"
            
            # Check switchdev mode (required for TC offload)
            echo
            echo \"Switchdev Mode Status:\"
            if [[ -L /sys/class/net/$INTERFACE_NAME/device ]]; then
                pci_path=\$(readlink /sys/class/net/$INTERFACE_NAME/device)
                pci_id=\$(basename \$pci_path)
                echo \"  PCI Device: \$pci_id\"
                
                # Try to get switchdev mode
                devlink dev eswitch show pci/\$pci_id 2>/dev/null || echo \"  Switchdev info not available (may not be in switchdev mode)\"
                
                # Check if SR-IOV is enabled
                if [[ -f /sys/class/net/$INTERFACE_NAME/device/sriov_numvfs ]]; then
                    numvfs=\$(cat /sys/class/net/$INTERFACE_NAME/device/sriov_numvfs)
                    echo \"  SR-IOV VFs: \$numvfs\"
                else
                    echo \"  SR-IOV: Not available\"
                fi
            else
                echo \"  Could not determine PCI device\"
            fi
            
            echo
            echo '=== Hardware Capabilities ==='
            # Check if hardware supports TC offload
            if [[ -L /sys/class/net/$INTERFACE_NAME/device ]]; then
                pci_path=\$(readlink /sys/class/net/$INTERFACE_NAME/device)
                pci_id=\$(basename \$pci_path)
                echo \"PCI Device: \$pci_id\"
                
                # Show device capabilities
                lspci -s \$pci_id -vv 2>/dev/null | grep -A5 -B5 -i capabilities || echo \"Could not get device capabilities\"
                
                # Check devlink info
                echo
                echo \"Devlink Device Info:\"
                devlink dev info pci/\$pci_id 2>/dev/null || echo \"Devlink info not available\"
            fi
            
            echo
            echo '=== Required Kernel Modules ==='
            echo \"TC-related modules loaded:\"
            lsmod | grep -E '(cls_flower|cls_u32|sch_ingress|act_mirred|act_vlan|act_tunnel_key)' || echo 'No specific TC modules found loaded'
            
            echo
            echo '=== TC Offload Statistics (if available) ==='
            if [[ -f /proc/net/tc_stats ]]; then
                cat /proc/net/tc_stats 2>/dev/null || echo \"TC stats not available\"
            else
                echo \"TC statistics not available in /proc/net/\"
            fi
        " 2>/dev/null || print_status "WARNING" "Could not check TC offload for $INTERFACE_NAME on node $node"
    done
}

# Function to check SR-IOV configuration for the specific interface
check_sriov_config() {
    print_status "INFO" "Checking SR-IOV configuration for $INTERFACE_NAME..."
    
    for node in "${NODES_WITH_INTERFACE[@]}"; do
        echo
        echo "Node: $node"
        
        oc debug node/$node -- chroot /host bash -c "
            echo '=== SR-IOV Configuration for $INTERFACE_NAME ==='
            
            if [[ -L /sys/class/net/$INTERFACE_NAME/device ]]; then
                pci_path=\$(readlink /sys/class/net/$INTERFACE_NAME/device)
                pci_id=\$(basename \$pci_path)
                echo \"PCI Device: \$pci_id\"
                
                # Check SR-IOV capabilities
                if [[ -f /sys/class/net/$INTERFACE_NAME/device/sriov_totalvfs ]]; then
                    total_vfs=\$(cat /sys/class/net/$INTERFACE_NAME/device/sriov_totalvfs)
                    current_vfs=\$(cat /sys/class/net/$INTERFACE_NAME/device/sriov_numvfs)
                    echo \"SR-IOV Total VFs: \$total_vfs\"
                    echo \"SR-IOV Current VFs: \$current_vfs\"
                    
                    if [[ \$current_vfs -gt 0 ]]; then
                        echo \"VF Interfaces:\"
                        ls /sys/class/net/$INTERFACE_NAME/device/virtfn*/net/ 2>/dev/null | head -5 || echo \"  Could not list VF interfaces\"
                    fi
                else
                    echo \"SR-IOV: Not supported on this interface\"
                fi
                
                # Check if interface is managed by SR-IOV operator
                echo
                echo \"SR-IOV Operator Management:\"
                # Look for SR-IOV node state
                if [[ -f /etc/sriov-operator/pci-addr-config ]]; then
                    grep -i \$pci_id /etc/sriov-operator/pci-addr-config 2>/dev/null || echo \"  Interface not managed by SR-IOV operator\"
                else
                    echo \"  SR-IOV operator config not found\"
                fi
            else
                echo \"Could not determine PCI device for $INTERFACE_NAME\"
            fi
        " 2>/dev/null || print_status "WARNING" "Could not check SR-IOV config for $INTERFACE_NAME on node $node"
    done
}

# Function to check node feature discovery for hardware capabilities
check_node_feature_discovery() {
    print_status "INFO" "Checking Node Feature Discovery for hardware capabilities..."
    
    # Check if NFD is deployed
    local nfd_pods=$(oc get pods -n openshift-nfd --no-headers 2>/dev/null | wc -l)
    if [ "$nfd_pods" -gt 0 ]; then
        print_status "SUCCESS" "Node Feature Discovery is deployed"
        
        # Check for hardware-related node labels
        print_status "INFO" "Checking nodes for hardware feature labels..."
        oc get nodes -o custom-columns="NAME:.metadata.name,LABELS:.metadata.labels" | grep -E "(sriov|rdma|dpdk|hardware)" || print_status "WARNING" "No specific hardware feature labels found"
    else
        print_status "WARNING" "Node Feature Discovery not found"
    fi
}

# Function to check for DPDK or other high-performance networking
check_dpdk_support() {
    print_status "INFO" "Checking for DPDK support..."
    
    # Check for DPDK-related pods or configurations
    local dpdk_pods=$(oc get pods -A --no-headers 2>/dev/null | grep -i dpdk | wc -l)
    if [ "$dpdk_pods" -gt 0 ]; then
        print_status "SUCCESS" "Found DPDK-related pods:"
        oc get pods -A --no-headers | grep -i dpdk
    else
        print_status "INFO" "No DPDK-related pods found"
    fi
}

# Function to check performance profiles (if using Performance Addon Operator)
check_performance_profiles() {
    print_status "INFO" "Checking Performance Profiles..."
    
    local perf_profiles=$(oc get performanceprofile --no-headers 2>/dev/null | wc -l)
    if [ "$perf_profiles" -gt 0 ]; then
        print_status "SUCCESS" "Found Performance Profiles:"
        oc get performanceprofile -o wide
    else
        print_status "INFO" "No Performance Profiles found (Performance Addon Operator may not be installed)"
    fi
}

# Main execution
main() {
    if [ "$STATUS_ONLY" = true ]; then
        echo "================================================"
        echo "  ConnectX Offload Status Report"
        echo "  Interface: $INTERFACE_NAME"
        echo "================================================"
    else
        echo "================================================"
        echo "  OpenShift ConnectX Offload Status Checker"
        echo "  Interface-Specific Analysis: $INTERFACE_NAME"
        echo "================================================"
        echo
    fi
    
    validate_interface
    if [ "$STATUS_ONLY" = false ]; then
        echo
    fi
    
    check_openshift_env
    if [ "$STATUS_ONLY" = false ]; then
        echo
    fi
    
    find_nodes_with_interface
    if [ "$STATUS_ONLY" = false ]; then
        echo
    fi
    
    if [ "$STATUS_ONLY" = true ]; then
        check_offload_status_only
    else
        check_cx_devices
        echo
        
        check_hardware_offload
        echo
        
        check_tc_offload
        echo
        
        check_sriov_config
        echo
        
        check_sriov_operator
        echo
        
        check_sriov_policies
        echo
        
        check_sriov_networks
        echo
        
        check_node_feature_discovery
        echo
        
        check_dpdk_support
        echo
        
        check_performance_profiles
        echo
        
        echo "================================================"
        echo "            Analysis Complete                   "
        echo "================================================"
        
        print_status "INFO" "Analysis completed for interface: $INTERFACE_NAME"
        echo "For detailed TC offload verification:"
        echo "  1. Ensure switchdev mode is enabled if SR-IOV is required"
        echo "  2. Configure TC ingress qdisc: tc qdisc add dev $INTERFACE_NAME ingress"
        echo "  3. Add TC flower rules and monitor with: tc -s filter show dev $INTERFACE_NAME"
        echo "  4. Check hardware counters for offload effectiveness"
    fi
}

# Run main function
main "$@"

# EOF
