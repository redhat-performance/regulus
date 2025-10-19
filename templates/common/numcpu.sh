#!/bin/bash

# Enable debug mode
DEBUG=true
DEBUG=${DEBUG:-false}

debug() {
    if [[ "$DEBUG" == "true" ]]; then
        echo "[DEBUG] $*" >&2
    fi
}

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

compute_cpus_per_pod() {
    local num_cpus="$1"
    local CORE_PERSOCKET="$2"
    local CPUS_PER_CORE="$3"
    local topo="$4"
    local scale_up_factor="$5"
    local pod_qos="$6"
    local numa_mode="$7"
    local TPL_NUMCPUS="$8"

debug "HN num_cpus=$num_cpus CORE_PERSOCKET=$CORE_PERSOCKET CPUS_PER_CORE=$CPUS_PER_CORE topo=$topo scale_up_factor=$scale_up_factor pod_qos=$pod_qos numa_mode=$numa_mode TPL_NUMCPUS=$TPL_NUMCPUS"
    
    local cpus_per_pod=0
    local num_pods=0
    local cpus_per_numa_node=$((CORE_PERSOCKET * CPUS_PER_CORE))
    
    # Determine number of pods based on topology
    if [[ "$topo" == "intranode" ]]; then
        num_pods=$((scale_up_factor * 2))
    else
        num_pods=$scale_up_factor
    fi
    
    # If user provided TPL_NUMCPUS, validate and use it
    if [[ -n "$TPL_NUMCPUS" && "$TPL_NUMCPUS" -gt 0 ]]; then
        cpus_per_pod=$TPL_NUMCPUS
        
        # Validate against available CPUs
        local total_required=$((cpus_per_pod * num_pods))
        
        # Check if NUMA constraints apply
        if [[ -n "$pod_qos" ]]; then
            # NUMA considerations apply
            if [[ "$numa_mode" == "single-numa-node" ]]; then
                # ALL pods must fit in one NUMA node (they share a NIC on that NUMA)
                if [[ $total_required -gt $cpus_per_numa_node ]]; then
                    echo "Error: Total CPUs required ($total_required) for all $num_pods pods exceeds single NUMA node capacity ($cpus_per_numa_node)" >&2
                    return 1
                fi
                
                # For guaranteed QoS with single-numa-node, must use full cores
                if [[ $((cpus_per_pod % CPUS_PER_CORE)) -ne 0 ]]; then
                    echo "Error: CPUs per pod ($cpus_per_pod) must be a multiple of CPUS_PER_CORE ($CPUS_PER_CORE) for guaranteed QoS with single-numa-node policy" >&2
                    return 1
                fi
            else
                # NUMA aware but not single-numa-node policy
                if [[ $total_required -gt $num_cpus ]]; then
                    echo "Error: Total CPUs required ($total_required) exceeds available CPUs ($num_cpus)" >&2
                    return 1
                fi
            fi
        else
            # No NUMA considerations
            if [[ $total_required -gt $num_cpus ]]; then
                echo "Error: Total CPUs required ($total_required) exceeds available CPUs ($num_cpus)" >&2
                return 1
            fi
        fi
        
        echo "$cpus_per_pod"
        return 0
    fi
    
    # Compute cpus_per_pod when not provided by user
    if [[ -n "$pod_qos" ]]; then
        # NUMA considerations apply
        if [[ "$numa_mode" == "single-numa-node" ]]; then
            # ALL pods must fit in single NUMA node
            # For guaranteed QoS, must use full cores
            local cores_per_pod=$((cpus_per_numa_node / CPUS_PER_CORE / num_pods))
            
            if [[ $cores_per_pod -lt 1 ]]; then
                echo "Error: Cannot fit $num_pods pods in single NUMA node with full core allocation" >&2
                return 1
            fi
            
            cpus_per_pod=$((cores_per_pod * CPUS_PER_CORE))
            
            # Verify all pods fit in one NUMA node
            local total_required=$((cpus_per_pod * num_pods))
            if [[ $total_required -gt $cpus_per_numa_node ]]; then
                echo "Error: Total CPUs required ($total_required) for all $num_pods pods exceeds single NUMA node capacity ($cpus_per_numa_node)" >&2
                return 1
            fi
        else
            # NUMA aware but can span nodes
            cpus_per_pod=$((num_cpus / num_pods))
        fi
    else
        # No NUMA considerations - simple division
        cpus_per_pod=$((num_cpus / num_pods))
    fi
    
    # Ensure at least 1 CPU per pod
    if [[ $cpus_per_pod -lt 1 ]]; then
        echo "Error: Cannot allocate at least 1 CPU per pod with $num_pods pods" >&2
        return 1
    fi
    
    echo "$cpus_per_pod"
    return 0
}

# Test helper function
run_test() {
    local test_name="$1"
    local num_cpus="$2"
    local core_persocket="$3"
    local cpus_per_core="$4"
    local topo="$5"
    local scale_up_factor="$6"
    local pod_qos="$7"
    local numa_mode="$8"
    local tpl_numcpus="$9"
    local expected_result="${10}"
    local should_fail="${11:-false}"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo ""
    echo "Test #$TOTAL_TESTS: $test_name"
    echo "  Params: num_cpus=$num_cpus, cores_per_socket=$core_persocket, cpus_per_core=$cpus_per_core"
    echo "          topo=$topo, scale_up=$scale_up_factor, qos='$pod_qos', numa='$numa_mode', tpl='$tpl_numcpus'"
    
    # Calculate expected pod count and NUMA capacity for clarity
    local num_pods=$scale_up_factor
    if [[ "$topo" == "intranode" ]]; then
        num_pods=$((scale_up_factor * 2))
    fi
    local numa_capacity=$((core_persocket * cpus_per_core))
    echo "          -> $num_pods pods total, NUMA capacity=$numa_capacity CPUs ($core_persocket cores)"
    
    local result
    result=$(compute_cpus_per_pod "$num_cpus" "$core_persocket" "$cpus_per_core" "$topo" "$scale_up_factor" "$pod_qos" "$numa_mode" "$tpl_numcpus" 2>&1)
    local exit_code=$?
    
    if [[ "$should_fail" == "true" ]]; then
        if [[ $exit_code -ne 0 ]]; then
            echo -e "  ${GREEN}✓ PASSED${NC} - Failed as expected"
            echo "  Error message: $result"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            echo -e "  ${RED}✗ FAILED${NC} - Should have failed but got: $result"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    else
        if [[ $exit_code -eq 0 ]]; then
            if [[ "$result" == "$expected_result" ]]; then
                echo -e "  ${GREEN}✓ PASSED${NC} - Got expected result: $result CPUs/pod"
                if [[ -n "$expected_result" ]]; then
                    local total=$((result * num_pods))
                    local cores_used=$((result * num_pods / cpus_per_core))
                    echo "  Total allocation: $total CPUs ($cores_used cores) for $num_pods pods"
                fi
                PASSED_TESTS=$((PASSED_TESTS + 1))
            else
                echo -e "  ${RED}✗ FAILED${NC} - Expected: $expected_result, Got: $result"
                FAILED_TESTS=$((FAILED_TESTS + 1))
            fi
        else
            echo -e "  ${RED}✗ FAILED${NC} - Unexpected failure: $result"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    fi
}
   
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # script being execute directly.
    
    echo "=========================================="
    echo "CPU Per Pod Computation - Test Suite"
    echo "=========================================="
    
    # ==========================================
    # CATEGORY 1: No NUMA Constraints (pod_qos="")
    # ==========================================
    echo ""
    echo -e "${YELLOW}=== CATEGORY 1: No NUMA Constraints ===${NC}"
    
    # Test 1: Simple case - no NUMA, internode
    run_test "No NUMA, internode, 4 pods" \
        96 24 2 "internode" 4 "" "" "" 24 false
    
    # Test 2: No NUMA, intranode (double the pods)
    run_test "No NUMA, intranode, 8 pods (4*2)" \
        96 24 2 "intranode" 4 "" "" "" 12 false
    
    # Test 3: No NUMA, SMT off (1 cpu per core)
    run_test "No NUMA, SMT off, 4 pods" \
        48 24 1 "internode" 4 "" "" "" 12 false
    
    # Test 4: No NUMA with user-provided TPL_NUMCPUS (valid)
    run_test "No NUMA, user wants 20 CPUs per pod" \
        96 24 2 "internode" 4 "" "" 20 20 false
    
    # Test 5: No NUMA with user-provided TPL_NUMCPUS (exceeds capacity)
    run_test "No NUMA, user wants 30 CPUs per pod (too many)" \
        96 24 2 "internode" 4 "" "" 30 0 true
    
    # ==========================================
    # CATEGORY 2: NUMA Aware, Not Single-NUMA-Node
    # ==========================================
    echo ""
    echo -e "${YELLOW}=== CATEGORY 2: NUMA Aware (Not Single-Node) ===${NC}"
    
    # Test 6: NUMA aware, can span nodes
    run_test "NUMA aware, internode, 4 pods" \
        96 24 2 "internode" 4 "guaranteed" "multi-numa" "" 24 false
    
    # Test 7: NUMA aware, intranode
    run_test "NUMA aware, intranode, 8 pods" \
        96 24 2 "intranode" 4 "guaranteed" "multi-numa" "" 12 false
    
    # Test 8: NUMA aware with user-provided CPUs (valid)
    run_test "NUMA aware, user wants 20 CPUs" \
        96 24 2 "internode" 4 "guaranteed" "multi-numa" 20 20 false
    
    # Test 9: NUMA aware with user-provided CPUs (exceeds total)
    run_test "NUMA aware, user wants 30 CPUs (exceeds)" \
        96 24 2 "internode" 4 "guaranteed" "multi-numa" 30 0 true
    
    # ==========================================
    # CATEGORY 3: Single-NUMA-Node Policy
    # ==========================================
    echo ""
    echo -e "${YELLOW}=== CATEGORY 3: Single-NUMA-Node Policy ===${NC}"
    echo "NOTE: All pods share a NIC and MUST fit on ONE NUMA node"
    
    # Test 10: Single NUMA, auto-compute, internode, 4 pods
    run_test "Single NUMA, internode, 4 pods, SMT on" \
        96 24 2 "internode" 4 "guaranteed" "single-numa-node" "" 12 false
    
    # Test 11: Single NUMA, auto-compute, intranode, 8 pods
    run_test "Single NUMA, intranode, 8 pods (4*2), SMT on" \
        96 24 2 "intranode" 4 "guaranteed" "single-numa-node" "" 6 false
    
    # Test 12: Single NUMA, SMT off
    run_test "Single NUMA, internode, 4 pods, SMT off" \
        48 24 1 "internode" 4 "guaranteed" "single-numa-node" "" 6 false
    
    # Test 13: Single NUMA with user-provided CPUs (valid, full cores, all fit)
    run_test "Single NUMA, user wants 12 CPUs/pod (6 cores), 4 pods" \
        96 24 2 "internode" 4 "guaranteed" "single-numa-node" 12 12 false
    
    # Test 14: Single NUMA with user-provided CPUs (not full cores)
    run_test "Single NUMA, user wants 11 CPUs (not full cores)" \
        96 24 2 "internode" 4 "guaranteed" "single-numa-node" 11 0 true
    
    # Test 15: Single NUMA with user-provided CPUs (exceeds NUMA capacity for all pods)
    run_test "Single NUMA, user wants 16 CPUs/pod, 4 pods (64 > 48)" \
        96 24 2 "internode" 4 "guaranteed" "single-numa-node" 16 0 true
    
    # Test 16: Single NUMA, too many pods for one NUMA node
    run_test "Single NUMA, 10 pods (can fit)" \
        96 24 2 "internode" 10 "guaranteed" "single-numa-node" "" 4 false
    
    # Test 17: Single NUMA, way too many pods
    run_test "Single NUMA, 30 pods (too many for one NUMA)" \
        96 24 2 "internode" 30 "guaranteed" "single-numa-node" "" 0 true
    
    # Test 18: Single NUMA, intranode with many pods
    run_test "Single NUMA, intranode, 6 scale (12 pods)" \
        96 24 2 "intranode" 6 "guaranteed" "single-numa-node" "" 4 false
    
    # Test 19: Single NUMA, user request that fits exactly
    run_test "Single NUMA, user wants 8 CPUs/pod, 6 pods (exact fit)" \
        96 24 2 "internode" 6 "guaranteed" "single-numa-node" 8 8 false
    
    # Test 20: Single NUMA, user request just over capacity
    run_test "Single NUMA, user wants 10 CPUs/pod, 6 pods (60 > 48)" \
        96 24 2 "internode" 6 "guaranteed" "single-numa-node" 10 0 true
    
    # ==========================================
    # CATEGORY 4: Edge Cases
    # ==========================================
    echo ""
    echo -e "${YELLOW}=== CATEGORY 4: Edge Cases ===${NC}"
    
    # Test 21: Single pod, no NUMA
    run_test "Single pod, no NUMA" \
        96 24 2 "internode" 1 "" "" "" 96 false
    
    # Test 22: Single pod, single NUMA
    run_test "Single pod, single NUMA" \
        96 24 2 "internode" 1 "guaranteed" "single-numa-node" "" 48 false
    
    # Test 23: Maximum pods that fit (no NUMA)
    run_test "48 pods, no NUMA" \
        96 24 2 "internode" 48 "" "" "" 2 false
    
    # Test 24: More pods than CPUs (should fail)
    run_test "100 pods (more than CPUs)" \
        96 24 2 "internode" 100 "" "" "" 0 true
    
    # Test 25: User wants 0 CPUs (treated as empty, auto-compute)
    run_test "User wants 0 CPUs (auto-compute)" \
        96 24 2 "internode" 4 "" "" 0 24 false
    
    # Test 26: Very small system
    run_test "Small system: 8 CPUs, 2 pods" \
        8 4 2 "internode" 2 "" "" "" 4 false
    
    # Test 27: Single NUMA, intranode with odd scale factor
    run_test "Single NUMA, intranode, 3 scale (6 pods)" \
        96 24 2 "intranode" 3 "guaranteed" "single-numa-node" "" 8 false
    
    # ==========================================
    # CATEGORY 5: Different Hardware Configurations
    # ==========================================
    echo ""
    echo -e "${YELLOW}=== CATEGORY 5: Different Hardware Configs ===${NC}"
    
    # Test 28: Large system (256 CPUs, 64 cores/socket)
    run_test "Large system: 256 CPUs, 8 pods, no NUMA" \
        256 64 2 "internode" 8 "" "" "" 32 false
    
    # Test 29: Large system with single NUMA
    run_test "Large system: 256 CPUs, 8 pods, single NUMA" \
        256 64 2 "internode" 8 "guaranteed" "single-numa-node" "" 16 false
    
    # Test 30: 4-way SMT (hypothetical)
    run_test "4-way SMT, 16 cores/socket, 4 pods" \
        128 16 4 "internode" 4 "guaranteed" "single-numa-node" "" 16 false
    
    # Test 31: User wants odd number of CPUs (no NUMA)
    run_test "User wants 7 CPUs (odd number, no NUMA)" \
        96 24 2 "internode" 4 "" "" 7 7 false
    
    # Test 32: Single NUMA, SMT off, user wants 2 CPUs
    run_test "SMT off, user wants 2 CPUs/pod, single NUMA" \
        48 24 1 "internode" 4 "guaranteed" "single-numa-node" 2 2 false
    
    # Test 33: Single NUMA, SMT off, auto-compute 6 pods
    run_test "SMT off, single NUMA, 6 pods" \
        48 24 1 "internode" 6 "guaranteed" "single-numa-node" "" 4 false
    
    # ==========================================
    # CATEGORY 6: Different QoS without single-numa-node
    # ==========================================
    echo ""
    echo -e "${YELLOW}=== CATEGORY 6: QoS Variations ===${NC}"
    
    # Test 34: Burstable QoS
    run_test "Burstable QoS with NUMA aware" \
        96 24 2 "internode" 4 "burstable" "prefer-numa" "" 24 false
    
    # Test 35: BestEffort QoS
    run_test "BestEffort QoS with NUMA" \
        96 24 2 "internode" 4 "besteffort" "" "" 24 false
    
    # ==========================================
    # CATEGORY 7: Boundary Conditions
    # ==========================================
    echo ""
    echo -e "${YELLOW}=== CATEGORY 7: Boundary Conditions ===${NC}"
    
    # Test 36: Exact fit - user request exactly fills NUMA node
    run_test "Exact fit: 4 pods * 12 CPUs = 48 (one NUMA)" \
        96 24 2 "internode" 4 "guaranteed" "single-numa-node" 12 12 false
    
    # Test 37: Just over NUMA capacity
    run_test "Just over NUMA: 4 pods * 14 CPUs = 56 > 48" \
        96 24 2 "internode" 4 "guaranteed" "single-numa-node" 14 0 true
    
    # Test 38: Minimum allocation (1 CPU per pod, no NUMA)
    run_test "Minimum: 1 CPU per pod" \
        4 2 2 "internode" 4 "" "" 1 1 false
    
    # Test 39: Intranode with single-numa, tight fit
    run_test "Intranode, single NUMA, 3 scale (6 pods) * 8 CPUs = 48" \
        96 24 2 "intranode" 3 "guaranteed" "single-numa-node" 8 8 false
    
    # Test 40: Empty topology string (should behave as internode)
    run_test "Empty topology string" \
        96 24 2 "" 4 "" "" "" 24 false
    
    # ==========================================
    # CATEGORY 8: Critical Single-NUMA Scenarios
    # ==========================================
    echo ""
    echo -e "${YELLOW}=== CATEGORY 8: Critical Single-NUMA Scenarios ===${NC}"
    
    # Test 41: Small NUMA node with many pods
    run_test "Small NUMA (16 CPUs), 6 pods" \
        32 8 2 "internode" 6 "guaranteed" "single-numa-node" "" 2 false
    
    # Test 42: Small NUMA node with too many pods
    run_test "Small NUMA (16 CPUs), 10 pods (too many)" \
        32 8 2 "internode" 10 "guaranteed" "single-numa-node" "" 0 true
    
    # Test 43: Intranode doubles pods - ensure total still fits one NUMA
    run_test "Intranode, 8 scale (16 pods), must fit one NUMA" \
        96 24 2 "intranode" 8 "guaranteed" "single-numa-node" "" 2 false
    
    # Test 44: Intranode with too many pods for one NUMA
    run_test "Intranode, 15 scale (30 pods), too many for one NUMA" \
        96 24 2 "intranode" 15 "guaranteed" "single-numa-node" "" 0 true
    
    # Test 45: User specifies CPUs that would span multiple NUMAs
    run_test "8 pods * 8 CPUs = 64 > 48 NUMA capacity" \
        96 24 2 "internode" 8 "guaranteed" "single-numa-node" 8 0 true
    
    # ==========================================
    # CATEGORY 9: ODD CORES - Reserved CPUs Scenarios
    # ==========================================
    echo ""
    echo -e "${BLUE}=== CATEGORY 9: ODD CORES (Reserved CPUs) ===${NC}"
    echo "NOTE: When cores are reserved, we get odd numbers like 21, 22, 23 cores"
    
    # Test 46: 21 cores (42 CPUs), SMT on, 4 pods, single NUMA
    # 42 / 2 / 4 = 5.25 cores, rounds down to 5 cores = 10 CPUs/pod
    # Total: 4 * 10 = 40 CPUs (fits in 42)
    run_test "21 cores (42 CPUs), SMT on, 4 pods, single NUMA" \
        84 21 2 "internode" 4 "guaranteed" "single-numa-node" "" 10 false
    
    # Test 47: 21 cores, 5 pods - should still work
    # 42 / 2 / 5 = 4.2 cores, rounds down to 4 cores = 8 CPUs/pod
    # Total: 5 * 8 = 40 CPUs (fits in 42)
    run_test "21 cores (42 CPUs), 5 pods, single NUMA" \
        84 21 2 "internode" 5 "guaranteed" "single-numa-node" "" 8 false
    
    # Test 48: 21 cores, 6 pods
    # 42 / 2 / 6 = 3.5 cores, rounds down to 3 cores = 6 CPUs/pod
    # Total: 6 * 6 = 36 CPUs (fits in 42)
    run_test "21 cores (42 CPUs), 6 pods, single NUMA" \
        84 21 2 "internode" 6 "guaranteed" "single-numa-node" "" 6 false
    
    # Test 49: 21 cores, 8 pods
    # 42 / 2 / 8 = 2.625 cores, rounds down to 2 cores = 4 CPUs/pod
    # Total: 8 * 4 = 32 CPUs (fits in 42)
    run_test "21 cores (42 CPUs), 8 pods, single NUMA" \
        84 21 2 "internode" 8 "guaranteed" "single-numa-node" "" 4 false
    
    # Test 50: 21 cores, 11 pods (should work)
    # 42 / 2 / 11 = 1.909 cores, rounds down to 1 core = 2 CPUs/pod
    # Total: 11 * 2 = 22 CPUs (fits in 42)
    run_test "21 cores (42 CPUs), 11 pods, single NUMA" \
        84 21 2 "internode" 11 "guaranteed" "single-numa-node" "" 2 false
    
    # Test 51: 21 cores, 22 pods (should fail)
    # 42 / 2 / 22 = 0.954 cores (< 1, should fail)
    run_test "21 cores (42 CPUs), 22 pods (too many)" \
        84 21 2 "internode" 22 "guaranteed" "single-numa-node" "" 0 true
    
    # Test 52: 21 cores, user wants 11 CPUs (not full cores, should fail)
    run_test "21 cores, user wants 11 CPUs (not full cores)" \
        84 21 2 "internode" 4 "guaranteed" "single-numa-node" 11 0 true
    
    # Test 53: 21 cores, user wants 10 CPUs (5 full cores, should work)
    # 4 pods * 10 = 40 < 42
    run_test "21 cores, user wants 10 CPUs (5 cores), 4 pods" \
        84 21 2 "internode" 4 "guaranteed" "single-numa-node" 10 10 false
    
    # Test 54: 21 cores, user wants 12 CPUs, but total exceeds
    # 4 pods * 12 = 48 > 42 (should fail)
    run_test "21 cores, user wants 12 CPUs, 4 pods (48 > 42)" \
        84 21 2 "internode" 4 "guaranteed" "single-numa-node" 12 0 true
    
    # Test 55: 23 cores (46 CPUs), SMT on, 5 pods
    # 46 / 2 / 5 = 4.6 cores, rounds down to 4 cores = 8 CPUs/pod
    # Total: 5 * 8 = 40 CPUs (fits in 46)
    run_test "23 cores (46 CPUs), SMT on, 5 pods" \
        92 23 2 "internode" 5 "guaranteed" "single-numa-node" "" 8 false
    
    # Test 56: 23 cores, 6 pods
    # 46 / 2 / 6 = 3.833 cores, rounds down to 3 cores = 6 CPUs/pod
    # Total: 6 * 6 = 36 CPUs (fits in 46)
    run_test "23 cores (46 CPUs), 6 pods" \
        92 23 2 "internode" 6 "guaranteed" "single-numa-node" "" 6 false
    
    # Test 57: 23 cores, 12 pods
    # 46 / 2 / 12 = 1.916 cores, rounds down to 1 core = 2 CPUs/pod
    # Total: 12 * 2 = 24 CPUs (fits in 46)
    run_test "23 cores (46 CPUs), 12 pods" \
        92 23 2 "internode" 12 "guaranteed" "single-numa-node" "" 2 false
    
    # Test 58: 23 cores, 24 pods (should fail)
    # 46 / 2 / 24 = 0.958 cores (< 1, should fail)
    run_test "23 cores (46 CPUs), 24 pods (too many)" \
        92 23 2 "internode" 24 "guaranteed" "single-numa-node" "" 0 true
    
    # Test 59: 22 cores (44 CPUs), intranode topology
    # scale=5, intranode = 10 pods
    # 44 / 2 / 10 = 2.2 cores, rounds down to 2 cores = 4 CPUs/pod
    # Total: 10 * 4 = 40 CPUs (fits in 44)
    run_test "22 cores (44 CPUs), intranode, 5 scale (10 pods)" \
        88 22 2 "intranode" 5 "guaranteed" "single-numa-node" "" 4 false
    
    # Test 60: 22 cores, intranode with tight fit
    # scale=6, intranode = 12 pods
    # 44 / 2 / 12 = 1.833 cores, rounds down to 1 core = 2 CPUs/pod
    # Total: 12 * 2 = 24 CPUs (fits in 44)
    run_test "22 cores (44 CPUs), intranode, 6 scale (12 pods)" \
        88 22 2 "intranode" 6 "guaranteed" "single-numa-node" "" 2 false
    
    # Test 61: 22 cores, intranode with too many pods
    # scale=12, intranode = 24 pods
    # 44 / 2 / 24 = 0.916 cores (< 1, should fail)
    run_test "22 cores (44 CPUs), intranode, 12 scale (24 pods)" \
        88 22 2 "intranode" 12 "guaranteed" "single-numa-node" "" 0 true
    
    # Test 62: 21 cores, SMT off (21 CPUs), 5 pods
    # 21 / 1 / 5 = 4.2 cores, rounds down to 4 cores = 4 CPUs/pod
    # Total: 5 * 4 = 20 CPUs (fits in 21)
    run_test "21 cores, SMT off, 5 pods" \
        42 21 1 "internode" 5 "guaranteed" "single-numa-node" "" 4 false
    
    # Test 63: 21 cores, SMT off, 6 pods
    # 21 / 1 / 6 = 3.5 cores, rounds down to 3 cores = 3 CPUs/pod
    # Total: 6 * 3 = 18 CPUs (fits in 21)
    run_test "21 cores, SMT off, 6 pods" \
        42 21 1 "internode" 6 "guaranteed" "single-numa-node" "" 3 false
    
    # Test 64: 21 cores, SMT off, 22 pods (should fail)
    # 21 / 1 / 22 = 0.954 cores (< 1, should fail)
    run_test "21 cores, SMT off, 22 pods (too many)" \
        42 21 1 "internode" 22 "guaranteed" "single-numa-node" "" 0 true
    
    # Test 65: 19 cores (38 CPUs), very tight odd number
    # 38 / 2 / 5 = 3.8 cores, rounds down to 3 cores = 6 CPUs/pod
    # Total: 5 * 6 = 30 CPUs (fits in 38)
    run_test "19 cores (38 CPUs), 5 pods" \
        76 19 2 "internode" 5 "guaranteed" "single-numa-node" "" 6 false
    
    # Test 66: 19 cores, 10 pods
    # 38 / 2 / 10 = 1.9 cores, rounds down to 1 core = 2 CPUs/pod
    # Total: 10 * 2 = 20 CPUs (fits in 38)
    run_test "19 cores (38 CPUs), 10 pods" \
        76 19 2 "internode" 10 "guaranteed" "single-numa-node" "" 2 false
    
    # Test 67: 19 cores, 20 pods (should fail)
    # 38 / 2 / 20 = 0.95 cores (< 1, should fail)
    run_test "19 cores (38 CPUs), 20 pods (too many)" \
        76 19 2 "internode" 20 "guaranteed" "single-numa-node" "" 0 true
    
    # Test 68: 25 cores (50 CPUs), 7 pods
    # 50 / 2 / 7 = 3.571 cores, rounds down to 3 cores = 6 CPUs/pod
    # Total: 7 * 6 = 42 CPUs (fits in 50)
    run_test "25 cores (50 CPUs), 7 pods" \
        100 25 2 "internode" 7 "guaranteed" "single-numa-node" "" 6 false
    
    # Test 69: 25 cores, 9 pods
    # 50 / 2 / 9 = 2.777 cores, rounds down to 2 cores = 4 CPUs/pod
    # Total: 9 * 4 = 36 CPUs (fits in 50)
    run_test "25 cores (50 CPUs), 9 pods" \
        100 25 2 "internode" 9 "guaranteed" "single-numa-node" "" 4 false
    
    # Test 70: 25 cores, 26 pods (should fail)
    # 50 / 2 / 26 = 0.961 cores (< 1, should fail)
    run_test "25 cores (50 CPUs), 26 pods (too many)" \
        100 25 2 "internode" 26 "guaranteed" "single-numa-node" "" 0 true
    
    # Test 71: 21 cores, user wants exact fit with waste
    # User wants 6 CPUs/pod, 7 pods = 42 CPUs (exact fit!)
    run_test "21 cores, user wants 6 CPUs/pod, 7 pods (exact fit)" \
        84 21 2 "internode" 7 "guaranteed" "single-numa-node" 6 6 false
    
    # Test 72: 21 cores, user wants 8 CPUs/pod, 6 pods
    # 6 * 8 = 48 > 42 (should fail)
    run_test "21 cores, user wants 8 CPUs/pod, 6 pods (exceeds)" \
        84 21 2 "internode" 6 "guaranteed" "single-numa-node" 8 0 true
    
    # Test 73: 23 cores, user wants 4 CPUs/pod, 11 pods
    # 11 * 4 = 44 < 46 (fits)
    run_test "23 cores, user wants 4 CPUs/pod, 11 pods" \
        92 23 2 "internode" 11 "guaranteed" "single-numa-node" 4 4 false
    
    # Test 74: 23 cores, user wants 4 CPUs/pod, 12 pods
    # 12 * 4 = 48 > 46 (should fail)
    run_test "23 cores, user wants 4 CPUs/pod, 12 pods (exceeds)" \
        92 23 2 "internode" 12 "guaranteed" "single-numa-node" 4 0 true
    
    # Test 75: 17 cores (34 CPUs), very small odd NUMA
    # 34 / 2 / 4 = 4.25 cores, rounds down to 4 cores = 8 CPUs/pod
    # Total: 4 * 8 = 32 CPUs (fits in 34)
    run_test "17 cores (34 CPUs), 4 pods" \
        68 17 2 "internode" 4 "guaranteed" "single-numa-node" "" 8 false
    
    # Test 76: 17 cores, 9 pods
    # 34 / 2 / 9 = 1.888 cores, rounds down to 1 core = 2 CPUs/pod
    # Total: 9 * 2 = 18 CPUs (fits in 34)
    run_test "17 cores (34 CPUs), 9 pods" \
        68 17 2 "internode" 9 "guaranteed" "single-numa-node" "" 2 false
    
    # Test 77: 17 cores, 18 pods (should fail)
    # 34 / 2 / 18 = 0.944 cores (< 1, should fail)
    run_test "17 cores (34 CPUs), 18 pods (too many)" \
        68 17 2 "internode" 18 "guaranteed" "single-numa-node" "" 0 true
    
    # Test 78: 15 cores (30 CPUs), borderline case
    # 30 / 2 / 8 = 1.875 cores, rounds down to 1 core = 2 CPUs/pod
    # Total: 8 * 2 = 16 CPUs (fits in 30)
    run_test "15 cores (30 CPUs), 8 pods" \
        60 15 2 "internode" 8 "guaranteed" "single-numa-node" "" 2 false
    
    # Test 79: 15 cores, 16 pods (should fail)
    # 30 / 2 / 16 = 0.9375 cores (< 1, should fail)
    run_test "15 cores (30 CPUs), 16 pods (too many)" \
        60 15 2 "internode" 16 "guaranteed" "single-numa-node" "" 0 true
    
    # Test 80: 27 cores (54 CPUs), larger odd number
    # 54 / 2 / 10 = 2.7 cores, rounds down to 2 cores = 4 CPUs/pod
    # Total: 10 * 4 = 40 CPUs (fits in 54)
    run_test "27 cores (54 CPUs), 10 pods" \
        108 27 2 "internode" 10 "guaranteed" "single-numa-node" "" 4 false
    
    # Test 81: 27 cores, 14 pods
    # 54 / 2 / 14 = 1.928 cores, rounds down to 1 core = 2 CPUs/pod
    # Total: 14 * 2 = 28 CPUs (fits in 54)
    run_test "27 cores (54 CPUs), 14 pods" \
        108 27 2 "internode" 14 "guaranteed" "single-numa-node" "" 2 false
    
    # Test 82: 27 cores, 28 pods (should fail)
    # 54 / 2 / 28 = 0.964 cores (< 1, should fail)
    run_test "27 cores (54 CPUs), 28 pods (too many)" \
        108 27 2 "internode" 28 "guaranteed" "single-numa-node" "" 0 true
    
    # ==========================================
    # CATEGORY 10: ODD CORES with Intranode Topology
    # ==========================================
    echo ""
    echo -e "${BLUE}=== CATEGORY 10: ODD CORES + Intranode (Stress Test) ===${NC}"
    
    # Test 83: 21 cores, intranode, scale=4 (8 pods)
    # 42 / 2 / 8 = 2.625 cores, rounds down to 2 cores = 4 CPUs/pod
    # Total: 8 * 4 = 32 CPUs (fits in 42)
    run_test "21 cores, intranode, scale=4 (8 pods)" \
        84 21 2 "intranode" 4 "guaranteed" "single-numa-node" "" 4 false
    
    # Test 84: 21 cores, intranode, scale=6 (12 pods)
    # 42 / 2 / 12 = 1.75 cores, rounds down to 1 core = 2 CPUs/pod
    # Total: 12 * 2 = 24 CPUs (fits in 42)
    run_test "21 cores, intranode, scale=6 (12 pods)" \
        84 21 2 "intranode" 6 "guaranteed" "single-numa-node" "" 2 false
    
    # Test 85: 21 cores, intranode, scale=11 (22 pods)
    # 42 / 2 / 22 = 0.954 cores (< 1, should fail)
    run_test "21 cores, intranode, scale=11 (22 pods - too many)" \
        84 21 2 "intranode" 11 "guaranteed" "single-numa-node" "" 0 true
    
    # Test 86: 19 cores, intranode, scale=5 (10 pods)
    # 38 / 2 / 10 = 1.9 cores, rounds down to 1 core = 2 CPUs/pod
    # Total: 10 * 2 = 20 CPUs (fits in 38)
    run_test "19 cores, intranode, scale=5 (10 pods)" \
        76 19 2 "intranode" 5 "guaranteed" "single-numa-node" "" 2 false
    
    # Test 87: 19 cores, intranode, scale=10 (20 pods)
    # 38 / 2 / 20 = 0.95 cores (< 1, should fail)
    run_test "19 cores, intranode, scale=10 (20 pods - too many)" \
        76 19 2 "intranode" 10 "guaranteed" "single-numa-node" "" 0 true
    
    # Test 88: 23 cores, intranode, scale=3 (6 pods)
    # 46 / 2 / 6 = 3.833 cores, rounds down to 3 cores = 6 CPUs/pod
    # Total: 6 * 6 = 36 CPUs (fits in 46)
    run_test "23 cores, intranode, scale=3 (6 pods)" \
        92 23 2 "intranode" 3 "guaranteed" "single-numa-node" "" 6 false
    
    # Test 89: 23 cores, intranode, scale=7 (14 pods)
    # 46 / 2 / 14 = 1.642 cores, rounds down to 1 core = 2 CPUs/pod
    # Total: 14 * 2 = 28 CPUs (fits in 46)
    run_test "23 cores, intranode, scale=7 (14 pods)" \
        92 23 2 "intranode" 7 "guaranteed" "single-numa-node" "" 2 false
    
    # Test 90: 23 cores, intranode, scale=12 (24 pods)
    # 46 / 2 / 24 = 0.958 cores (< 1, should fail)
    run_test "23 cores, intranode, scale=12 (24 pods - too many)" \
        92 23 2 "intranode" 12 "guaranteed" "single-numa-node" "" 0 true
    
    # ==========================================
    # CATEGORY 11: ODD CORES with User-Specified CPUs
    # ==========================================
    echo ""
    echo -e "${BLUE}=== CATEGORY 11: ODD CORES + User TPL_NUMCPUS ===${NC}"
    
    # Test 91: 21 cores, user wants 10 CPUs (valid), 4 pods
    # 4 * 10 = 40 < 42 (fits)
    run_test "21 cores, user specifies 10 CPUs/pod, 4 pods" \
        84 21 2 "internode" 4 "guaranteed" "single-numa-node" 10 10 false
    
    # Test 92: 21 cores, user wants 11 CPUs (not full cores)
    run_test "21 cores, user specifies 11 CPUs (not full cores)" \
        84 21 2 "internode" 4 "guaranteed" "single-numa-node" 11 0 true
    
    # Test 93: 21 cores, user wants 8 CPUs, 5 pods
    # 5 * 8 = 40 < 42 (fits)
    run_test "21 cores, user specifies 8 CPUs/pod, 5 pods" \
        84 21 2 "internode" 5 "guaranteed" "single-numa-node" 8 8 false
    
    # Test 94: 21 cores, user wants 8 CPUs, 6 pods
    # 6 * 8 = 48 > 42 (exceeds)
    run_test "21 cores, user specifies 8 CPUs/pod, 6 pods (exceeds)" \
        84 21 2 "internode" 6 "guaranteed" "single-numa-node" 8 0 true
    
    # Test 95: 19 cores, user wants 6 CPUs, 6 pods
    # 6 * 6 = 36 < 38 (fits)
    run_test "19 cores, user specifies 6 CPUs/pod, 6 pods" \
        76 19 2 "internode" 6 "guaranteed" "single-numa-node" 6 6 false
    
    # Test 96: 19 cores, user wants 6 CPUs, 7 pods
    # 7 * 6 = 42 > 38 (exceeds)
    run_test "19 cores, user specifies 6 CPUs/pod, 7 pods (exceeds)" \
        76 19 2 "internode" 7 "guaranteed" "single-numa-node" 6 0 true
    
    # Test 97: 23 cores, user wants 14 CPUs, 3 pods
    # 3 * 14 = 42 < 46 (fits)
    run_test "23 cores, user specifies 14 CPUs/pod, 3 pods" \
        92 23 2 "internode" 3 "guaranteed" "single-numa-node" 14 14 false
    
    # Test 98: 23 cores, user wants 16 CPUs, 3 pods
    # 3 * 16 = 48 > 46 (exceeds)
    run_test "23 cores, user specifies 16 CPUs/pod, 3 pods (exceeds)" \
        92 23 2 "internode" 3 "guaranteed" "single-numa-node" 16 0 true
    
    # Test 99: 25 cores, user wants 2 CPUs (minimum full core), 20 pods
    # 20 * 2 = 40 < 50 (fits)
    run_test "25 cores, user specifies 2 CPUs/pod, 20 pods" \
        100 25 2 "internode" 20 "guaranteed" "single-numa-node" 2 2 false
    
    # Test 100: 25 cores, user wants 2 CPUs, 26 pods
    # 26 * 2 = 52 > 50 (exceeds)
    run_test "25 cores, user specifies 2 CPUs/pod, 26 pods (exceeds)" \
        100 25 2 "internode" 26 "guaranteed" "single-numa-node" 2 0 true
    
    # ==========================================
    # CATEGORY 12: ODD CORES with SMT Off
    # ==========================================
    echo ""
    echo -e "${BLUE}=== CATEGORY 12: ODD CORES + SMT Off ===${NC}"
    
    # Test 101: 21 cores, SMT off, 7 pods
    # 21 / 1 / 7 = 3 cores = 3 CPUs/pod
    # Total: 7 * 3 = 21 CPUs (exact fit!)
    run_test "21 cores, SMT off, 7 pods (exact fit)" \
        42 21 1 "internode" 7 "guaranteed" "single-numa-node" "" 3 false
    
    # Test 102: 19 cores, SMT off, 6 pods
    # 19 / 1 / 6 = 3.166 cores, rounds down to 3 cores = 3 CPUs/pod
    # Total: 6 * 3 = 18 CPUs (fits in 19)
    run_test "19 cores, SMT off, 6 pods" \
        38 19 1 "internode" 6 "guaranteed" "single-numa-node" "" 3 false
    
    # Test 103: 19 cores, SMT off, 20 pods (should fail)
    # 19 / 1 / 20 = 0.95 cores (< 1, should fail)
    run_test "19 cores, SMT off, 20 pods (too many)" \
        38 19 1 "internode" 20 "guaranteed" "single-numa-node" "" 0 true
    
    # Test 104: 23 cores, SMT off, 11 pods
    # 23 / 1 / 11 = 2.09 cores, rounds down to 2 cores = 2 CPUs/pod
    # Total: 11 * 2 = 22 CPUs (fits in 23)
    run_test "23 cores, SMT off, 11 pods" \
        46 23 1 "internode" 11 "guaranteed" "single-numa-node" "" 2 false
    
    # Test 105: 23 cores, SMT off, 24 pods (should fail)
    # 23 / 1 / 24 = 0.958 cores (< 1, should fail)
    run_test "23 cores, SMT off, 24 pods (too many)" \
        46 23 1 "internode" 24 "guaranteed" "single-numa-node" "" 0 true
    
    # Test 106: 17 cores, SMT off, 8 pods
    # 17 / 1 / 8 = 2.125 cores, rounds down to 2 cores = 2 CPUs/pod
    # Total: 8 * 2 = 16 CPUs (fits in 17)
    run_test "17 cores, SMT off, 8 pods" \
        34 17 1 "internode" 8 "guaranteed" "single-numa-node" "" 2 false
    
    # Test 107: 17 cores, SMT off, user wants 3 CPUs, 5 pods
    # 5 * 3 = 15 < 17 (fits)
    run_test "17 cores, SMT off, user wants 3 CPUs/pod, 5 pods" \
        34 17 1 "internode" 5 "guaranteed" "single-numa-node" 3 3 false
    
    # Test 108: 17 cores, SMT off, user wants 3 CPUs, 6 pods
    # 6 * 3 = 18 > 17 (exceeds)
    run_test "17 cores, SMT off, user wants 3 CPUs/pod, 6 pods (exceeds)" \
        34 17 1 "internode" 6 "guaranteed" "single-numa-node" 3 0 true
    
    # ==========================================
    # CATEGORY 13: Extreme ODD CORES Cases
    # ==========================================
    echo ""
    echo -e "${BLUE}=== CATEGORY 13: Extreme ODD CORES Cases ===${NC}"
    
    # Test 109: 31 cores (62 CPUs), larger odd prime number
    # 62 / 2 / 10 = 3.1 cores, rounds down to 3 cores = 6 CPUs/pod
    # Total: 10 * 6 = 60 CPUs (fits in 62)
    run_test "31 cores (62 CPUs), 10 pods" \
        124 31 2 "internode" 10 "guaranteed" "single-numa-node" "" 6 false
    
    # Test 110: 31 cores, 11 pods
    # 62 / 2 / 11 = 2.818 cores, rounds down to 2 cores = 4 CPUs/pod
    # Total: 11 * 4 = 44 CPUs (fits in 62)
    run_test "31 cores (62 CPUs), 11 pods" \
        124 31 2 "internode" 11 "guaranteed" "single-numa-node" "" 4 false
    
    # Test 111: 31 cores, 32 pods (should fail)
    # 62 / 2 / 32 = 0.96875 cores (< 1, should fail)
    run_test "31 cores (62 CPUs), 32 pods (too many)" \
        124 31 2 "internode" 32 "guaranteed" "single-numa-node" "" 0 true
    
    # Test 112: 13 cores (26 CPUs), small odd prime
    # 26 / 2 / 6 = 2.166 cores, rounds down to 2 cores = 4 CPUs/pod
    # Total: 6 * 4 = 24 CPUs (fits in 26)
    run_test "13 cores (26 CPUs), 6 pods" \
        52 13 2 "internode" 6 "guaranteed" "single-numa-node" "" 4 false
    
    # Test 113: 13 cores, 7 pods
    # 26 / 2 / 7 = 1.857 cores, rounds down to 1 core = 2 CPUs/pod
    # Total: 7 * 2 = 14 CPUs (fits in 26)
    run_test "13 cores (26 CPUs), 7 pods" \
        52 13 2 "internode" 7 "guaranteed" "single-numa-node" "" 2 false
    
    # Test 114: 13 cores, 14 pods (should fail)
    # 26 / 2 / 14 = 0.928 cores (< 1, should fail)
    run_test "13 cores (26 CPUs), 14 pods (too many)" \
        52 13 2 "internode" 14 "guaranteed" "single-numa-node" "" 0 true
    
    # Test 115: 11 cores (22 CPUs), very small odd
    # 22 / 2 / 5 = 2.2 cores, rounds down to 2 cores = 4 CPUs/pod
    # Total: 5 * 4 = 20 CPUs (fits in 22)
    run_test "11 cores (22 CPUs), 5 pods" \
        44 11 2 "internode" 5 "guaranteed" "single-numa-node" "" 4 false
    
    # Test 116: 11 cores, 11 pods
    # 22 / 2 / 11 = 1 core = 2 CPUs/pod
    # Total: 11 * 2 = 22 CPUs (exact fit!)
    run_test "11 cores (22 CPUs), 11 pods (exact fit)" \
        44 11 2 "internode" 11 "guaranteed" "single-numa-node" "" 2 false
    
    # Test 117: 11 cores, 12 pods (should fail)
    # 22 / 2 / 12 = 0.916 cores (< 1, should fail)
    run_test "11 cores (22 CPUs), 12 pods (too many)" \
        44 11 2 "internode" 12 "guaranteed" "single-numa-node" "" 0 true
    
    # Test 118: 29 cores (58 CPUs), odd number close to 30
    # 58 / 2 / 14 = 2.071 cores, rounds down to 2 cores = 4 CPUs/pod
    # Total: 14 * 4 = 56 CPUs (fits in 58)
    run_test "29 cores (58 CPUs), 14 pods" \
        116 29 2 "internode" 14 "guaranteed" "single-numa-node" "" 4 false
    
    # Test 119: 29 cores, 15 pods
    # 58 / 2 / 15 = 1.933 cores, rounds down to 1 core = 2 CPUs/pod
    # Total: 15 * 2 = 30 CPUs (fits in 58)
    run_test "29 cores (58 CPUs), 15 pods" \
        116 29 2 "internode" 15 "guaranteed" "single-numa-node" "" 2 false
    
    # Test 120: 29 cores, 30 pods (should fail)
    # 58 / 2 / 30 = 0.966 cores (< 1, should fail)
    run_test "29 cores (58 CPUs), 30 pods (too many)" \
        116 29 2 "internode" 30 "guaranteed" "single-numa-node" "" 0 true
    
    # ==========================================
    # Summary
    # ==========================================
    echo ""
    echo "=========================================="
    echo "Test Summary"
    echo "=========================================="
    echo -e "Total Tests:  $TOTAL_TESTS"
    echo -e "${GREEN}Passed:       $PASSED_TESTS${NC}"
    echo -e "${RED}Failed:       $FAILED_TESTS${NC}"
    echo ""
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        echo ""
        echo "Test Coverage Summary:"
        echo "  - No NUMA constraints: 5 tests"
        echo "  - NUMA aware (multi-node): 4 tests"
        echo "  - Single-NUMA-node policy: 10 tests"
        echo "  - Edge cases: 7 tests"
        echo "  - Different hardware configs: 6 tests"
        echo "  - QoS variations: 2 tests"
        echo "  - Boundary conditions: 5 tests"
        echo "  - Critical single-NUMA scenarios: 5 tests"
        echo "  - ODD cores (reserved CPUs): 30 tests"
        echo "  - ODD cores + intranode: 8 tests"
        echo "  - ODD cores + user-specified: 10 tests"
        echo "  - ODD cores + SMT off: 8 tests"
        echo "  - Extreme ODD cores: 12 tests"
        echo "  ----------------------------------------"
        echo "  Total: 120 comprehensive tests"
        exit 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        exit 1
    fi
else
    # script being sourced
    :
fi

