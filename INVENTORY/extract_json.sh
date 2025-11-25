#!/bin/bash
# Simple JSON extractor using jq

set -e

ENV_FILE=""
INVENTORY_FILE=""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Extract values from JSON configuration files

OPTIONS:
    -e, --env FILE          Environment JSON file (required)
    -i, --inventory FILE    Inventory JSON file (optional)
    -k, --key KEY          Get specific key value
    -s, --search PATTERN   Search for keys matching pattern
    -a, --all              Display all key-value pairs
    -h, --hosts            List all hosts
    -n, --network          Show network configuration
    -b, --bash FILE        Export as bash variables
    --summary              Show configuration summary
    --help                 Show this help message

EXAMPLES:
    # Get specific value
    $0 -e env.json -k KUBECONFIG

    # Search for SRIOV-related keys
    $0 -e env.json -s SRIOV

    # Show all hosts
    $0 -e env.json -h

    # Export to bash
    $0 -e env.json -b env_vars.sh
EOF
}

check_jq() {
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq is not installed${NC}"
        echo "Install with: sudo dnf install jq"
        exit 1
    fi
}

get_value() {
    local file=$1
    local key=$2
    
    if [ ! -f "$file" ]; then
        echo -e "${RED}Error: File $file not found${NC}"
        exit 1
    fi
    
    value=$(jq -r ".${key} // empty" "$file")
    if [ -z "$value" ]; then
        echo -e "${YELLOW}Key '$key' not found${NC}"
        return 1
    fi
    echo "$value"
}

search_keys() {
    local file=$1
    local pattern=$2
    
    echo -e "${BLUE}Keys matching '$pattern':${NC}"
    jq -r "to_entries[] | select(.key | test(\"$pattern\"; \"i\")) | \"\(.key): \(.value)\"" "$file"
}

list_all() {
    local file=$1
    
    echo -e "${BLUE}All configuration values:${NC}"
    jq -r 'to_entries[] | "\(.key): \(.value)"' "$file"
}

list_hosts() {
    local file=$1
    
    echo -e "${BLUE}Hosts:${NC}"
    jq -r 'to_entries[] | select(.key | test("HOST"; "i")) | .value' "$file" | sort -u
}

show_network() {
    local file=$1
    
    echo -e "${BLUE}Network Configuration:${NC}"
    jq -r 'to_entries[] | select(.key | test("NIC|MTU|INTERFACE|MACVLAN|SRIOV|DPDK|OVN"; "i")) | "\(.key): \(.value)"' "$file"
}

export_bash() {
    local file=$1
    local output=$2
    
    echo "#!/bin/bash" > "$output"
    echo "# Exported from $file" >> "$output"
    echo "" >> "$output"
    
    jq -r 'to_entries[] | "export \(.key)=\"\(.value)\""' "$file" >> "$output"
    
    chmod +x "$output"
    echo -e "${GREEN}Exported to $output${NC}"
}

show_summary() {
    local file=$1
    
    echo -e "${GREEN}=================================${NC}"
    echo -e "${GREEN}CONFIGURATION SUMMARY${NC}"
    echo -e "${GREEN}=================================${NC}"
    
    echo -e "\n${BLUE}Kubeconfig:${NC}"
    get_value "$file" "KUBECONFIG" || echo "Not set"
    
    echo -e "\n${BLUE}OCP Cluster Host:${NC}"
    get_value "$file" "REG_OCPHOST" || echo "Not set"
    
    echo -e "\n${BLUE}Worker Nodes:${NC}"
    for i in 0 1 2; do
        worker=$(get_value "$file" "OCP_WORKER_$i" 2>/dev/null)
        [ -n "$worker" ] && echo "  Worker $i: $worker"
    done
    
    echo -e "\n${BLUE}SR-IOV Configuration:${NC}"
    echo "  NIC: $(get_value "$file" "REG_SRIOV_NIC" 2>/dev/null || echo 'N/A')"
    echo "  MTU: $(get_value "$file" "REG_SRIOV_MTU" 2>/dev/null || echo 'N/A')"
    echo "  Model: $(get_value "$file" "REG_SRIOV_NIC_MODEL" 2>/dev/null || echo 'N/A')"
    
    echo -e "\n${BLUE}MACVLAN Configuration:${NC}"
    echo "  NIC: $(get_value "$file" "REG_MACVLAN_NIC" 2>/dev/null || echo 'N/A')"
    echo "  MTU: $(get_value "$file" "REG_MACVLAN_MTU" 2>/dev/null || echo 'N/A')"
    echo "  Model: $(get_value "$file" "REG_MACVLAN_NIC_MODEL" 2>/dev/null || echo 'N/A')"
    
    echo -e "\n${BLUE}DPDK Configuration:${NC}"
    echo "  NIC 1: $(get_value "$file" "REG_DPDK_NIC_1" 2>/dev/null || echo 'N/A')"
    echo "  NIC 2: $(get_value "$file" "REG_DPDK_NIC_2" 2>/dev/null || echo 'N/A')"
    echo "  Model: $(get_value "$file" "REG_DPDK_NIC_MODEL" 2>/dev/null || echo 'N/A')"
    
    echo -e "\n${BLUE}TRex Configuration:${NC}"
    echo "  Host: $(get_value "$file" "TREX_HOSTS" 2>/dev/null || echo 'N/A')"
    echo "  Interface 1: $(get_value "$file" "TREX_SRIOV_INTERFACE_1" 2>/dev/null || echo 'N/A')"
    echo "  Interface 2: $(get_value "$file" "TREX_SRIOV_INTERFACE_2" 2>/dev/null || echo 'N/A')"
    
    echo -e "\n${GREEN}=================================${NC}"
}

# Check for jq
check_jq

# Parse arguments
if [ $# -eq 0 ]; then
    usage
    exit 0
fi

while [ $# -gt 0 ]; do
    case $1 in
        -e|--env)
            ENV_FILE="$2"
            shift 2
            ;;
        -i|--inventory)
            INVENTORY_FILE="$2"
            shift 2
            ;;
        -k|--key)
            KEY="$2"
            shift 2
            ;;
        -s|--search)
            SEARCH="$2"
            shift 2
            ;;
        -a|--all)
            SHOW_ALL=1
            shift
            ;;
        -h|--hosts)
            SHOW_HOSTS=1
            shift
            ;;
        -n|--network)
            SHOW_NETWORK=1
            shift
            ;;
        -b|--bash)
            BASH_OUTPUT="$2"
            shift 2
            ;;
        --summary)
            SHOW_SUMMARY=1
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            exit 1
            ;;
    esac
done

# Validate required arguments
if [ -z "$ENV_FILE" ]; then
    echo -e "${RED}Error: Environment file is required${NC}"
    usage
    exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}Error: File $ENV_FILE not found${NC}"
    exit 1
fi

# Execute requested operation
if [ -n "$KEY" ]; then
    get_value "$ENV_FILE" "$KEY"
elif [ -n "$SEARCH" ]; then
    search_keys "$ENV_FILE" "$SEARCH"
elif [ -n "$SHOW_ALL" ]; then
    list_all "$ENV_FILE"
elif [ -n "$SHOW_HOSTS" ]; then
    list_hosts "$ENV_FILE"
elif [ -n "$SHOW_NETWORK" ]; then
    show_network "$ENV_FILE"
elif [ -n "$BASH_OUTPUT" ]; then
    export_bash "$ENV_FILE" "$BASH_OUTPUT"
elif [ -n "$SHOW_SUMMARY" ]; then
    show_summary "$ENV_FILE"
else
    usage
fi

