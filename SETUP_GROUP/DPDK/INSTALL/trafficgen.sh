# bash support functions. For sourcing ONLY

# Get the directory of the sourced script. Niffy bash feature to get this directory path, when this module is sourced.
FUNC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

query_pci_by_interface() {
    local json_file="${FUNC_DIR}/trex-device-info.json"
    local interface_name=$1

    [[ -z "$json_file" || -z "$interface_name" ]] && { echo "Usage: query_pci_by_interface <json_file> <interface_name>"; return 1; }

    local pci_addr
    pci_addr=$(jq -r --arg iface "$interface_name" '.[] | select(.interface_name == $iface) | .pci_addr' "$json_file")

    if [[ -n "$pci_addr" && "$pci_addr" != "null" ]]; then
        echo "$pci_addr"
    else
        echo "Error: Interface $interface_name not found in $json_file" >&2
        return 1
    fi
}

