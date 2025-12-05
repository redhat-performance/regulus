#!/bin/bash

# Enable debug mode
DEBUG=false
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
    local NUM_NUMAS="$2"
    local CPUS_PER_CORE="$3"
    local topo="$4"
    local scale_up_factor="$5"
    local pod_qos="$6"
    local numa_mode="$7"
    local TPL_NUMCPUS="$8"

debug "HN num_cpus=$num_cpus NUM_NUMAS=$NUM_NUMAS CPUS_PER_CORE=$CPUS_PER_CORE topo=$topo scale_up_factor=$scale_up_factor pod_qos=$pod_qos numa_mode=$numa_mode TPL_NUMCPUS=$TPL_NUMCPUS"

    local cpus_per_pod=0
    local num_pods=0
    local cpus_per_numa_node=$((num_cpus / NUM_NUMAS))

    # Determine number of pods based on topology
    if [[ "$topo" == "intranode" ]]; then
        num_pods=$((scale_up_factor * 2))
    else
        num_pods=$scale_up_factor
    fi

    # If user provided TPL_NUMCPUS, validate and use it
    if [[ -n "$TPL_NUMCPUS" && "$TPL_NUMCPUS" -gt 0 ]]; then
        cpus_per_pod=$TPL_NUMCPUS

        # For guaranteed QoS, must use full cores
        if [[ "$pod_qos" == "guaranteed" ]]; then
            if [[ $((cpus_per_pod % CPUS_PER_CORE)) -ne 0 ]]; then
                echo "Error: CPUs per pod ($cpus_per_pod) must be a multiple of CPUS_PER_CORE ($CPUS_PER_CORE) for guaranteed QoS" >&2
                return 1
            fi
        fi

        # Validate against available CPUs
        local total_required=$((cpus_per_pod * num_pods))

        # Check if single-numa-node constraint applies
        if [[ "$numa_mode" == "single-numa-node" && "$pod_qos" == "guaranteed" ]]; then
            # ALL pods must fit in one NUMA node
            if [[ $total_required -gt $cpus_per_numa_node ]]; then
                echo "Error: Total CPUs required ($total_required) for all $num_pods pods exceeds single NUMA node capacity ($cpus_per_numa_node)" >&2
                return 1
            fi
        else
            # Pods can span NUMA nodes
            if [[ $total_required -gt $num_cpus ]]; then
                echo "Error: Total CPUs required ($total_required) exceeds available CPUs ($num_cpus)" >&2
                return 1
            fi
        fi

        echo "$cpus_per_pod"
        return 0
    fi

    # Compute cpus_per_pod when not provided by user
    if [[ "$numa_mode" == "single-numa-node" && "$pod_qos" == "guaranteed" ]]; then
        # ALL pods must fit in single NUMA node
        # For guaranteed QoS, must use full cores
        local cores_per_pod=$((cpus_per_numa_node / CPUS_PER_CORE / num_pods))

        if [[ $cores_per_pod -lt 1 ]]; then
            echo "Error: Cannot fit $num_pods pods in single NUMA node with full core allocation" >&2
            return 1
        fi

        cpus_per_pod=$((cores_per_pod * CPUS_PER_CORE))
    elif [[ "$pod_qos" == "guaranteed" ]]; then
        # Guaranteed QoS but can span NUMA nodes - still enforce full cores
        local cores_per_pod=$((num_cpus / CPUS_PER_CORE / num_pods))

        if [[ $cores_per_pod -lt 1 ]]; then
            echo "Error: Cannot allocate at least 1 full core per pod with $num_pods pods" >&2
            return 1
        fi

        cpus_per_pod=$((cores_per_pod * CPUS_PER_CORE))
    else
        # Non-guaranteed QoS - simple division, no full core requirement
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
    local num_numas="$3"
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
    echo "  Params: num_cpus=$num_cpus, num_numas=$num_numas, cpus_per_core=$cpus_per_core"
    echo "          topo=$topo, scale_up=$scale_up_factor, qos='$pod_qos', numa='$numa_mode', tpl='$tpl_numcpus'"

    # Calculate expected pod count and NUMA capacity for clarity
    local num_pods=$scale_up_factor
    if [[ "$topo" == "intranode" ]]; then
        num_pods=$((scale_up_factor * 2))
    fi
    local numa_capacity=$((num_cpus / num_numas))
    echo "          -> $num_pods pods total, NUMA capacity=$numa_capacity CPUs per node"

    local result
    result=$(compute_cpus_per_pod "$num_cpus" "$num_numas" "$cpus_per_core" "$topo" "$scale_up_factor" "$pod_qos" "$numa_mode" "$tpl_numcpus" 2>&1)
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
                    echo "  Total allocation: $total CPUs for $num_pods pods"
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
    # CATEGORY 1: No QoS or Non-Guaranteed QoS (Pods can span NUMA nodes)
    # ==========================================
    echo ""
    echo -e "${YELLOW}=== CATEGORY 1: No QoS or Non-Guaranteed QoS ===${NC}"

    # Test 1: No QoS, internode, 2 NUMA nodes, SMT on
    run_test "No QoS, internode, 4 pods, 2 NUMAs, SMT on" \
        96 2 2 "internode" 4 "" "" "" 24 false

    # Test 2: No QoS, intranode (doubles pods), SMT on
    run_test "No QoS, intranode, 8 pods (4*2), 2 NUMAs, SMT on" \
        96 2 2 "intranode" 4 "" "" "" 12 false

    # Test 3: Burstable QoS with single-numa-node (doesn't apply constraint)
    run_test "Burstable QoS, single-numa-node (ignored), 4 pods" \
        96 2 2 "internode" 4 "burstable" "single-numa-node" "" 24 false

    # Test 4: Empty QoS with single-numa-node (doesn't apply constraint)
    run_test "Empty QoS, single-numa-node (ignored), 4 pods" \
        96 2 2 "internode" 4 "" "single-numa-node" "" 24 false

    # Test 5: User-provided CPUs, no constraints (odd number OK for non-guaranteed)
    run_test "No QoS, user wants 21 CPUs/pod, 4 pods" \
        96 2 2 "internode" 4 "" "" 21 21 false

    # Test 6: User-provided CPUs exceeds total
    run_test "No QoS, user wants 30 CPUs/pod, 4 pods (exceeds)" \
        96 2 2 "internode" 4 "" "" 30 0 true

    # ==========================================
    # CATEGORY 2: Guaranteed QoS with Single-NUMA-Node (Full Cores Required)
    # ==========================================
    echo ""
    echo -e "${YELLOW}=== CATEGORY 2: Guaranteed QoS + Single-NUMA-Node ===${NC}"

    # Test 7: Guaranteed + single-numa-node, 4 pods, 2 NUMAs, SMT on
    # 96 CPUs / 2 NUMAs = 48 CPUs per NUMA, 48 CPUs / 2 CPUs_per_core = 24 cores
    # 24 cores / 4 pods = 6 cores = 12 CPUs/pod
    run_test "Guaranteed + single-numa-node, 4 pods, 2 NUMAs, SMT on" \
        96 2 2 "internode" 4 "guaranteed" "single-numa-node" "" 12 false

    # Test 8: Guaranteed + single-numa-node, intranode, 8 pods, SMT on
    # 24 cores / 8 pods = 3 cores = 6 CPUs/pod
    run_test "Guaranteed + single-numa-node, intranode, 8 pods, SMT on" \
        96 2 2 "intranode" 4 "guaranteed" "single-numa-node" "" 6 false

    # Test 9: User's original case - 18 CPUs, 2 NUMAs, intranode, 2 pods, SMT on
    # 18 / 2 = 9 CPUs per NUMA, 9 / 2 = 4.5 cores (rounds to 4 cores)
    # 1 scale_up * 2 (intranode) = 2 pods
    # 4 cores / 2 pods = 2 cores = 4 CPUs/pod
    run_test "User case: 18 CPUs, 2 NUMAs, intranode, 2 pods, SMT on" \
        18 2 2 "intranode" 1 "guaranteed" "single-numa-node" "" 4 false

    # Test 10: Guaranteed + single-numa-node, user specifies valid full cores
    run_test "Guaranteed + single-numa, user wants 10 CPUs/pod (5 cores), 4 pods" \
        96 2 2 "internode" 4 "guaranteed" "single-numa-node" 10 10 false

    # Test 11: Guaranteed + single-numa-node, user specifies odd CPUs (not full cores)
    run_test "Guaranteed + single-numa, user wants 11 CPUs/pod (not full cores)" \
        96 2 2 "internode" 4 "guaranteed" "single-numa-node" 11 0 true

    # Test 12: Guaranteed + single-numa-node, user exceeds NUMA capacity
    # 4 pods * 16 CPUs = 64 > 48 (one NUMA)
    run_test "Guaranteed + single-numa, user wants 16 CPUs/pod (exceeds NUMA)" \
        96 2 2 "internode" 4 "guaranteed" "single-numa-node" 16 0 true

    # Test 13: Guaranteed + single-numa-node, too many pods
    run_test "Guaranteed + single-numa, 50 pods (too many)" \
        96 2 2 "internode" 50 "guaranteed" "single-numa-node" "" 0 true

    # ==========================================
    # CATEGORY 3: Guaranteed QoS without Single-NUMA (Full Cores Required)
    # ==========================================
    echo ""
    echo -e "${YELLOW}=== CATEGORY 3: Guaranteed QoS (No Single-NUMA) ===${NC}"

    # Test 14: Guaranteed QoS, can span NUMAs, but still needs full cores
    # 96 / 2 = 48 cores, 48 / 4 = 12 cores = 24 CPUs/pod
    run_test "Guaranteed (no single-numa), 4 pods, SMT on" \
        96 2 2 "internode" 4 "guaranteed" "" "" 24 false

    # Test 15: Guaranteed QoS, user wants odd CPUs (not full cores) - should fail
    run_test "Guaranteed (no single-numa), user wants 11 CPUs (not full cores)" \
        96 2 2 "internode" 4 "guaranteed" "" 11 0 true

    # Test 16: Guaranteed QoS, SMT off
    # 48 CPUs / 1 per core = 48 cores, 48 / 4 = 12 cores = 12 CPUs/pod
    run_test "Guaranteed (no single-numa), 4 pods, SMT off" \
        48 2 1 "internode" 4 "guaranteed" "" "" 12 false

    # ==========================================
    # CATEGORY 4: Edge Cases
    # ==========================================
    echo ""
    echo -e "${YELLOW}=== CATEGORY 4: Edge Cases ===${NC}"

    # Test 17: Single pod, no constraints
    run_test "Single pod, no constraints" \
        96 2 2 "internode" 1 "" "" "" 96 false

    # Test 18: Single pod, guaranteed + single-numa (full cores)
    # 48 CPUs per NUMA / 2 = 24 cores, 24 cores * 2 = 48 CPUs
    run_test "Single pod, guaranteed + single-numa, SMT on" \
        96 2 2 "internode" 1 "guaranteed" "single-numa-node" "" 48 false

    # Test 19: User wants 0 CPUs (auto-compute)
    run_test "User wants 0 CPUs (auto-compute)" \
        96 2 2 "internode" 4 "" "" 0 24 false

    # Test 20: More pods than CPUs
    run_test "100 pods, more than available CPUs" \
        96 2 2 "internode" 100 "" "" "" 0 true

    # ==========================================
    # CATEGORY 5: Odd Numbers & Reserved CPUs with Full Cores
    # ==========================================
    echo ""
    echo -e "${YELLOW}=== CATEGORY 5: Odd Numbers & Reserved CPUs ===${NC}"

    # Test 21: 18 CPUs (reserved some), 2 NUMAs, guaranteed + single-numa
    # 18 / 2 = 9 CPUs per NUMA, 9 / 2 = 4 cores (integer), 4 cores / 4 pods = 1 core = 2 CPUs/pod
    run_test "18 CPUs (9 per NUMA), 4 pods, guaranteed + single-numa, SMT on" \
        18 2 2 "internode" 4 "guaranteed" "single-numa-node" "" 2 false

    # Test 22: 21 CPUs, 2 NUMAs, 5 pods
    # 21 / 2 = 10 CPUs per NUMA, 10 / 2 = 5 cores, 5 cores / 5 pods = 1 core = 2 CPUs/pod
    run_test "21 CPUs (10 per NUMA), 5 pods, guaranteed + single-numa" \
        21 2 2 "internode" 5 "guaranteed" "single-numa-node" "" 2 false

    # Test 23: 50 CPUs, 3 NUMAs, 6 pods
    # 50 / 3 = 16 CPUs per NUMA, 16 / 2 = 8 cores, 8 cores / 6 pods = 1 core = 2 CPUs/pod
    run_test "50 CPUs, 3 NUMAs (16 per NUMA), 6 pods" \
        50 3 2 "internode" 6 "guaranteed" "single-numa-node" "" 2 false

    # Test 24: User specifies exact fit with full cores
    run_test "18 CPUs, 2 NUMAs, user wants 4 CPUs/pod (2 cores), 2 pods (intranode)" \
        18 2 2 "intranode" 1 "guaranteed" "single-numa-node" 4 4 false

    # Test 25: User specifies odd CPUs with guaranteed QoS (should fail)
    run_test "18 CPUs, user wants 5 CPUs/pod (not full cores)" \
        18 2 2 "intranode" 1 "guaranteed" "single-numa-node" 5 0 true

    # Test 26: User specifies full cores but exceeds NUMA capacity
    # 18 / 2 = 9 CPUs per NUMA, user wants 6 * 2 = 12 > 9
    run_test "18 CPUs, user wants 6 CPUs/pod (3 cores), 2 pods (exceeds)" \
        18 2 2 "intranode" 1 "guaranteed" "single-numa-node" 6 0 true

    # ==========================================
    # CATEGORY 6: Multiple NUMA Configurations
    # ==========================================
    echo ""
    echo -e "${YELLOW}=== CATEGORY 6: Multiple NUMA Configurations ===${NC}"

    # Test 27: 4 NUMA nodes, guaranteed + single-numa
    # 256 / 4 = 64 CPUs per NUMA, 64 / 2 = 32 cores, 32 / 8 = 4 cores = 8 CPUs/pod
    run_test "256 CPUs, 4 NUMAs, 8 pods, guaranteed + single-numa" \
        256 4 2 "internode" 8 "guaranteed" "single-numa-node" "" 8 false

    # Test 28: Single NUMA node
    # 64 / 1 = 64 CPUs per NUMA, 64 / 2 = 32 cores, 32 / 4 = 8 cores = 16 CPUs/pod
    run_test "64 CPUs, 1 NUMA, 4 pods, guaranteed + single-numa" \
        64 1 2 "internode" 4 "guaranteed" "single-numa-node" "" 16 false

    # Test 29: 8 NUMA nodes
    # 512 / 8 = 64 CPUs per NUMA, 64 / 2 = 32 cores, 32 / 16 = 2 cores = 4 CPUs/pod
    run_test "512 CPUs, 8 NUMAs, 16 pods, guaranteed + single-numa" \
        512 8 2 "internode" 16 "guaranteed" "single-numa-node" "" 4 false

    # ==========================================
    # CATEGORY 7: Intranode Topology Variations
    # ==========================================
    echo ""
    echo -e "${YELLOW}=== CATEGORY 7: Intranode Topology ===${NC}"

    # Test 30: Intranode with odd scale factor
    # 96 / 2 = 48 per NUMA, 48 / 2 = 24 cores, 3 * 2 = 6 pods, 24 / 6 = 4 cores = 8 CPUs/pod
    run_test "Intranode, scale=3 (6 pods), guaranteed + single-numa" \
        96 2 2 "intranode" 3 "guaranteed" "single-numa-node" "" 8 false

    # Test 31: Intranode with many pods
    # 24 cores, 10 * 2 = 20 pods, 24 / 20 = 1 core = 2 CPUs/pod
    run_test "Intranode, scale=10 (20 pods), guaranteed + single-numa" \
        96 2 2 "intranode" 10 "guaranteed" "single-numa-node" "" 2 false

    # Test 32: Intranode, too many pods for one NUMA
    # 24 cores, 30 * 2 = 60 pods, 24 / 60 = 0 cores (fails)
    run_test "Intranode, scale=30 (60 pods), too many" \
        96 2 2 "intranode" 30 "guaranteed" "single-numa-node" "" 0 true

    # ==========================================
    # CATEGORY 8: QoS Comparison
    # ==========================================
    echo ""
    echo -e "${YELLOW}=== CATEGORY 8: QoS Comparison ===${NC}"

    # Test 33: Same config, burstable uses all CPUs (no full core requirement)
    run_test "Burstable + single-numa (uses all 96), 4 pods" \
        96 2 2 "internode" 4 "burstable" "single-numa-node" "" 24 false

    # Test 34: Same config, guaranteed restricted to one NUMA with full cores
    # 48 CPUs / 2 = 24 cores, 24 / 4 = 6 cores = 12 CPUs/pod
    run_test "Guaranteed + single-numa (restricted to 48, full cores), 4 pods" \
        96 2 2 "internode" 4 "guaranteed" "single-numa-node" "" 12 false

    # Test 35: Besteffort QoS (no constraints)
    run_test "Besteffort QoS, 4 pods" \
        96 2 2 "internode" 4 "besteffort" "" "" 24 false

    # Test 36: SMT off with guaranteed QoS
    # 48 CPUs / 1 = 48 cores, 48 / 4 = 12 cores = 12 CPUs/pod
    run_test "Guaranteed, SMT off, 4 pods" \
        48 2 1 "internode" 4 "guaranteed" "" "" 12 false

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
        echo "  - No QoS / Non-Guaranteed: 6 tests"
        echo "  - Guaranteed + Single-NUMA (full cores): 7 tests"
        echo "  - Guaranteed without Single-NUMA (full cores): 3 tests"
        echo "  - Edge cases: 4 tests"
        echo "  - Odd numbers & reserved CPUs: 6 tests"
        echo "  - Multiple NUMA configs: 3 tests"
        echo "  - Intranode topology: 3 tests"
        echo "  - QoS comparisons: 4 tests"
        echo "  ----------------------------------------"
        echo "  Total: 36 comprehensive tests"
        exit 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        exit 1
    fi
else
    # script being sourced
    :
fi
