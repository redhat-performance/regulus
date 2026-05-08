#!/usr/bin/env bash
#
# DPU and OVN Configuration Detection
#
# Detects if OVN-Kubernetes is running in DPU mode and extracts
# the OVN NIC interface name, model, and MTU settings
#
# Usage:
#   Source this file and call detect_dpu_ovn:
#     source bin/detect-dpu-ovn.sh
#     detect_dpu_ovn
#
#   Or run standalone:
#     bash bin/detect-dpu-ovn.sh
#
# Returns (via stdout in shell variable format):
#   DPU_MODE=true|false
#   REG_OVN_NIC=<interface_name>
#   REG_OVN_NIC_MODEL=<model_name>
#   REG_OVN_NIC_MTU=<mtu_value>
#
# Exit codes:
#   0 - Success (DPU mode detected or not)
#   1 - Error (missing dependencies, cannot connect, etc.)
#

# SSH options for nested SSH
SSH_OPTS="${SSH_OPTS:--o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=ERROR -o ConnectTimeout=20}"

# Helper function for SSH via bastion
do_ssh() {
    local user_host=$1; shift
    ssh $SSH_OPTS $user_host bash << EOFCMD
${KUBECONFIG:+export KUBECONFIG='${KUBECONFIG}'}
$*
EOFCMD
}

# ================================================================================
# Main DPU Detection Function
# ================================================================================
# Detects if OVN-Kubernetes is running in DPU mode and extracts OVN NIC config.
#
# DETECTION FLOW:
#   1. Select worker node (prioritize DPU-enabled nodes for mixed clusters)
#   2. Check bridge-id: "br-dpu" = DPU mode, "br-ex" = standard mode
#   3. Identify OVN NIC (MAC matching for DPU, nmcli for standard)
#   4. Detect NIC model via lspci
#   5. Get MTU (cluster config for DPU, cluster or physical for standard)
#
# OUTPUT (shell variables suitable for eval):
#   DPU_MODE="true|false"          # DPU mode enabled
#   REG_OVN_NIC="ens7f0np0"        # OVN interface name
#   REG_OVN_NIC_MODEL="BF3"        # NIC model (BF3, BF2, CX7, CX6, E810, XXV710)
#   REG_OVN_NIC_MTU="1400"         # MTU (what pods see)
#
# USAGE:
#   eval "$(detect_dpu_ovn)"
#   [[ "$DPU_MODE" == "true" ]] && echo "DPU: $REG_OVN_NIC_MODEL on $REG_OVN_NIC"
#
# EXIT CODES: 0=success, 1=error (missing env vars, cannot connect, etc.)
# ================================================================================
detect_dpu_ovn() {
    # Check required environment variables
    if [[ -z "$KUBECONFIG" ]]; then
        echo "ERROR: KUBECONFIG not set" >&2
        return 1
    fi

    if [[ -z "$REG_OCPHOST" ]]; then
        echo "ERROR: REG_OCPHOST not set" >&2
        return 1
    fi

    if [[ -z "$REG_KNI_USER" ]]; then
        echo "ERROR: REG_KNI_USER not set" >&2
        return 1
    fi

    # Source worker_labels.config if it exists (for MATCH variables)
    # Try multiple locations: current dir, REG_ROOT, or relative to script
    local worker_labels_config=""
    if [[ -f "templates/common/worker_labels.config" ]]; then
        worker_labels_config="templates/common/worker_labels.config"
    elif [[ -n "$REG_ROOT" ]] && [[ -f "$REG_ROOT/templates/common/worker_labels.config" ]]; then
        worker_labels_config="$REG_ROOT/templates/common/worker_labels.config"
    fi

    if [[ -n "$worker_labels_config" ]]; then
        source "$worker_labels_config"
    fi

    local dest="$REG_KNI_USER@$REG_OCPHOST"

    # ============================================================================
    # WORKER NODE SELECTION
    # ============================================================================
    # Mixed cluster support: Prioritize DPU-enabled nodes (br-dpu) to detect
    # cluster DPU capability. Falls back to first worker if no DPU nodes found.
    # Valid scenarios: Pure DPU, Pure non-DPU, or Mixed (DPU + non-DPU workers)
    #
    # Uses MATCH, MATCH_NOT_1, MATCH_NOT_2, MATCH_NOT_3, MATCH_NOT_4 variables
    # for worker node selection (from template/common/worker_labels.config or environment)
    # ============================================================================

    # Build jq selector from MATCH, MATCH_NOT_* variables
    local jq_select=""
    if [[ -z "$MATCH" ]]; then
        jq_select=".\"node-role.kubernetes.io/worker\" != null"
    else
        jq_select=".\"node-role.kubernetes.io/$MATCH\" != null"
    fi
    if [[ -n "$MATCH_NOT_1" ]]; then
        jq_select+=" and .\"node-role.kubernetes.io/$MATCH_NOT_1\" == null"
    fi
    if [[ -n "$MATCH_NOT_2" ]]; then
        jq_select+=" and .\"node-role.kubernetes.io/$MATCH_NOT_2\" == null"
    fi
    if [[ -n "$MATCH_NOT_3" ]]; then
        jq_select+=" and .\"node-role.kubernetes.io/$MATCH_NOT_3\" == null"
    fi
    if [[ -n "$MATCH_NOT_4" ]]; then
        jq_select+=" and .\"node-role.kubernetes.io/$MATCH_NOT_4\" == null"
    fi

    # Get all nodes as JSON and filter with jq
    # First, try to find a DPU-enabled node (has br-dpu in l3-gateway-config)
    local worker_node=$(do_ssh $dest "oc get nodes -o json | jq -r '.items[] | select(.metadata.labels | $jq_select) | select(.metadata.annotations[\"k8s.ovn.org/l3-gateway-config\"] | contains(\"br-dpu\")) | .metadata.name' | head -1")

    # If no DPU nodes found, fall back to first worker node matching the selector
    # Sort by name to ensure deterministic selection
    if [[ -z "$worker_node" ]]; then
        worker_node=$(do_ssh $dest "oc get nodes -o json | jq -r '.items[] | select(.metadata.labels | $jq_select) | .metadata.name' | sort | head -1")
    fi

    if [[ -z "$worker_node" ]]; then
        echo "ERROR: No worker nodes found" >&2
        return 1
    fi

    echo "DEBUG: Selected node for OVN/bond detection: $worker_node (using MATCH=$MATCH, MATCH_NOT_1=$MATCH_NOT_1, MATCH_NOT_2=$MATCH_NOT_2)" >&2

    # Get worker node IP
    local jq_cmd='.status.addresses[] | select(.type=="InternalIP") | .address | select(contains("."))'
    local worker_ip=$(do_ssh $dest "oc get node $worker_node -o json | jq -r '$jq_cmd'")

    if [[ -z "$worker_ip" ]]; then
        echo "ERROR: Could not get worker node IP for $worker_node" >&2
        return 1
    fi

    # ============================================================================
    # DPU MODE DETECTION
    # ============================================================================
    # Source: Node annotation k8s.ovn.org/l3-gateway-config → .default.bridge-id
    # DPU mode:      bridge-id = "br-dpu"
    # Standard mode: bridge-id = "br-ex"
    #
    # Why bridge-id is definitive:
    # - Set by OVN-Kubernetes operator (stable, reliable)
    # - Directly reflects OVN configuration (not just hardware detection)
    # - Works even if NFD is not deployed
    #
    # Example annotations:
    #   DPU:      {"default": {"bridge-id": "br-dpu", "next-hops": ["10.6.156.211"]}}
    #   Standard: {"default": {"bridge-id": "br-ex", "next-hops": ["10.6.135.254"]}}
    # ============================================================================

    # Get L3 gateway configuration annotation
    local l3_gateway_config=$(do_ssh $dest "oc get node $worker_node -o jsonpath='{.metadata.annotations.k8s\.ovn\.org/l3-gateway-config}'")

    # Extract bridge-id from L3 gateway config
    local bridge_id=$(echo "$l3_gateway_config" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('default', {}).get('bridge-id', ''))" 2>/dev/null || echo "")

    # Determine if DPU mode is enabled (simple, robust check)
    local dpu_mode="false"
    if [[ "$bridge_id" == "br-dpu" ]]; then
        dpu_mode="true"
    fi

    # ============================================================================
    # OVN NIC IDENTIFICATION
    # ============================================================================
    # DPU mode: Match MAC from l3-gateway-config annotation → interface name
    #   - OVS runs on DPU (not host), so nmcli doesn't show ovs-port-phys0
    #   - Example: MAC c4:70:bd:c2:c1:68 → ens7f0np0 (BF3 DPU port)
    #
    # Standard mode: nmcli finds interface assigned to ovs-port-phys0
    #   - OVS runs on host, nmcli shows bridge mapping
    #   - Example: nmcli → enp1s0: ovs-port-phys0
    #
    # Both modes: Determine NIC model via lspci (ethtool bus-info → lspci -s)
    # ============================================================================

    local ovn_nic=""
    local ovn_nic_model=""  # Will be detected via lspci
    local ovn_nic_mtu=""

    if [[ "$dpu_mode" == "true" ]]; then
        # DPU MODE: Extract interface from l3-gateway-config via MAC address
        local mac_address=$(echo "$l3_gateway_config" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('default', {}).get('mac-address', ''))" 2>/dev/null || echo "")

        if [[ -n "$mac_address" ]]; then
            # Find interface name by MAC address on the worker node
            ovn_nic=$(do_ssh $dest "ssh $SSH_OPTS core@$worker_ip \"ip -o link | grep -i '$mac_address' | awk '{print \\\$2}' | tr -d ':' | head -1\"")
        fi

        # If we found the NIC, determine its model
        if [[ -n "$ovn_nic" ]]; then
            # NIC model detection: ethtool -i (bus-info) → lspci -s → pattern match
            # Supported: BF3, BF2, CX7, CX6, E810, XXV710 (priority order)

            local lspci_output=$(do_ssh $dest "ssh $SSH_OPTS core@$worker_ip \"sudo ethtool -i $ovn_nic 2>/dev/null | grep 'bus-info' | awk '{print \\\$2}'\"" || echo "")

            if [[ -n "$lspci_output" ]]; then
                local pci_addr=$(echo "$lspci_output" | sed 's/0000://')
                local lspci_info=$(do_ssh $dest "ssh $SSH_OPTS core@$worker_ip \"lspci -s $pci_addr -v 2>/dev/null\"" || echo "")

                # Determine model from lspci output (priority order matters!)
                if echo "$lspci_info" | grep -q -i "BlueField-3"; then
                    ovn_nic_model="BF3"
                elif echo "$lspci_info" | grep -q -i "BlueField-2"; then
                    ovn_nic_model="BF2"
                elif echo "$lspci_info" | grep -q -i "ConnectX-7"; then
                    ovn_nic_model="CX7"
                elif echo "$lspci_info" | grep -q -i "ConnectX-6"; then
                    ovn_nic_model="CX6"
                elif echo "$lspci_info" | grep -q -i "E810"; then
                    ovn_nic_model="E810"
                elif echo "$lspci_info" | grep -q -i "XXV710"; then
                    ovn_nic_model="XXV710"
                elif echo "$lspci_info" | grep -q -i "X550"; then
                    ovn_nic_model="X550"
                else
                    echo "DEBUG: unknown DPU NIC model" >&2
                    ovn_nic_model="UNKNOWN"
                fi
            fi
        fi
    else
        # Standard mode: nmcli finds ovs-port-phys0 bridge connection
        ovn_nic=$(do_ssh $dest "ssh $SSH_OPTS core@$worker_ip \"nmcli | grep ovs-port-phys0 | awk '{print \\\$1}' | tr -d ':'\"" || echo "")

        if [[ -n "$ovn_nic" ]]; then
            # Get model for non-DPU OVN interface (same lspci logic)
            local lspci_output=$(do_ssh $dest "ssh $SSH_OPTS core@$worker_ip \"sudo ethtool -i $ovn_nic 2>/dev/null | grep 'bus-info' | awk '{print \\\$2}'\"" || echo "")

            # If no bus-info (e.g., bond interface), try to get the first slave interface
            if [[ -z "$lspci_output" ]]; then
                local slave_nic=$(do_ssh $dest "ssh $SSH_OPTS core@$worker_ip \"ls /sys/class/net/$ovn_nic/lower_* 2>/dev/null | head -1 | xargs -r basename\"" || echo "")
                if [[ -n "$slave_nic" ]]; then
                    slave_nic=$(echo "$slave_nic" | sed 's/lower_//')
                    lspci_output=$(do_ssh $dest "ssh $SSH_OPTS core@$worker_ip \"sudo ethtool -i $slave_nic 2>/dev/null | grep 'bus-info' | awk '{print \\\$2}'\"" || echo "")
                fi
            fi

            if [[ -n "$lspci_output" ]]; then
                local pci_addr=$(echo "$lspci_output" | sed 's/0000://')
                local lspci_info=$(do_ssh $dest "ssh $SSH_OPTS core@$worker_ip \"lspci -s $pci_addr -v 2>/dev/null\"" || echo "")

                # Determine model (same pattern matching as DPU mode)
                if echo "$lspci_info" | grep -q -i "BlueField-3"; then
                    ovn_nic_model="BF3"
                elif echo "$lspci_info" | grep -q -i "BlueField-2"; then
                    ovn_nic_model="BF2"
                elif echo "$lspci_info" | grep -q -i "XXV710"; then
                    ovn_nic_model="XXV710"
                elif echo "$lspci_info" | grep -q -i "X710"; then
                    ovn_nic_model="X710"
                elif echo "$lspci_info" | grep -q -i "E810"; then
                    ovn_nic_model="E810"
                elif echo "$lspci_info" | grep -q -i "E820"; then
                    ovn_nic_model="E820"
                elif echo "$lspci_info" | grep -q -i "ConnectX-8"; then
                    ovn_nic_model="CX8"
                elif echo "$lspci_info" | grep -q -i "ConnectX-7"; then
                    ovn_nic_model="CX7"
                elif echo "$lspci_info" | grep -q -i "ConnectX-6"; then
                    ovn_nic_model="CX6"
                elif echo "$lspci_info" | grep -q -i "ConnectX-5"; then
                    ovn_nic_model="CX5"
                elif echo "$lspci_info" | grep -q -i "X550"; then
                    ovn_nic_model="X550"
                elif echo "$lspci_info" | grep -q -i "Mellanox.*Connect"; then
                    if [ "$driver" == "mlx5_core" ]; then
                        ovn_nic_model="CX5"  # Default to CX5 for Mellanox with mlx5_core
                    fi
                else
                    echo "DEBUG: unknown OVNK NIC model" >&2
                    ovn_nic_model="UNKNOWN"
                fi
            fi
        fi
    fi

    # ============================================================================
    # MTU DETECTION - Multiple MTU Layers in DPU Mode
    # ============================================================================
    # DPU mode has 4 different MTU values for example:
    #   1. Pod eth0 MTU:    1400  (what iperf/uperf see) ← WE RETURN THIS
    #   2. VF MTU (host):   1500  (pods don't see this)
    #   3. PF MTU:          1460  (1400 + 60 Geneve overhead)
    #   4. Hardware max:    9978  (BF3 capability)
    #
    # Traffic flow (openshift.io/bf3-p0-vfs resource):
    #   App -> TCP (MSS 1360) -> pod eth0 (1400) -> VF host (1500) ->
    #   BF-3 ARM (+60 Geneve) -> PF (1460) -> Physical network
    #
    # KEY: Pod eth0 IS the VF, but OVN-K enforces MTU 1400 inside pod namespace
    #   - With bf3-p0-vfs resource, pod gets VF as PRIMARY interface (eth0)
    #   - VF at host level shows MTU 1500, but pod sees 1400
    #   - Verify: oc exec <pod> -- ip link show eth0 → mtu 1400
    #   - Why: OVN-K sets clusterNetworkMTU=1400 for Geneve overhead
    #
    # DECISION: Return cluster network MTU (1400) for DPU mode
    #   ✓ What pods see on eth0 (verified)
    #   ✓ What determines TCP MSS (1400 - 40 = 1360)
    #   ✓ What iperf/uperf tests use
    #   ✗ NOT VF MTU (1500) - invisible to pod
    #   ✗ NOT PF MTU (1460) - only for br-dpu bridge
    #
    # Source: network.config.openshift.io/cluster .status.clusterNetworkMTU
    # Fallback: PF MTU - 60 (remove Geneve overhead)
    #
    # Standard mode: cluster MTU = physical MTU (no VF layer, values match)
    # ============================================================================

    if [[ "$dpu_mode" == "true" ]]; then
        # DPU mode: Get cluster network MTU (what pods actually see)
        # This is the authoritative source for pod eth0 MTU in DPU mode
        ovn_nic_mtu=$(do_ssh $dest "oc get network.config.openshift.io cluster -o jsonpath='{.status.clusterNetworkMTU}'" || echo "")

        # Fallback to PF MTU - 60 if cluster config unavailable
        # (PF MTU includes Geneve overhead, so subtract 60 to get pod MTU)
        if [[ -z "$ovn_nic_mtu" ]] && [[ -n "$ovn_nic" ]]; then
            local pf_mtu=$(do_ssh $dest "ssh $SSH_OPTS core@$worker_ip \"cat /sys/class/net/$ovn_nic/mtu 2>/dev/null\"" || echo "")
            if [[ -n "$pf_mtu" ]] && [[ "$pf_mtu" -gt 60 ]]; then
                ovn_nic_mtu=$((pf_mtu - 60))  # Remove Geneve overhead
            fi
        fi
    else
        # Standard mode: Get MTU from cluster config (overlay MTU = physical MTU)
        ovn_nic_mtu=$(do_ssh $dest "oc get network.config.openshift.io cluster -o jsonpath='{.status.clusterNetworkMTU}'" || echo "")

        # Fallback to physical interface if cluster config unavailable
        if [[ -z "$ovn_nic_mtu" ]] && [[ -n "$ovn_nic" ]]; then
            ovn_nic_mtu=$(do_ssh $dest "ssh $SSH_OPTS core@$worker_ip \"cat /sys/class/net/$ovn_nic/mtu 2>/dev/null\"" || echo "")
        fi
    fi

    # ============================================================================
    # OUTPUT RESULTS
    # ============================================================================
    # Format: Shell variable assignments suitable for eval
    #
    # Example output for DPU cluster:
    #   DPU_MODE="true"
    #   REG_OVN_NIC="ens7f0np0"
    #   REG_OVN_NIC_MODEL="BF3"
    #   REG_OVN_NIC_MTU="1400"
    #
    # Example output for standard OVN cluster:
    #   DPU_MODE="false"
    #   REG_OVN_NIC="enp1s0"
    #   REG_OVN_NIC_MODEL="E810"
    #   REG_OVN_NIC_MTU="9000"
    # ============================================================================
    echo "DPU_MODE=\"$dpu_mode\""
    echo "REG_OVN_NIC=\"$ovn_nic\""
    echo "REG_OVN_NIC_MODEL=\"$ovn_nic_model\""
    echo "REG_OVN_NIC_MTU=\"$ovn_nic_mtu\""

    return 0
}

# If script is run directly (not sourced), execute the detection
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being executed directly
    detect_dpu_ovn
fi
