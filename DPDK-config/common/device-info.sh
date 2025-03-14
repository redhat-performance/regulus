#!/bin/bash

device_info_create() {
    local output_file=$1
    local first_entry=true

    echo "[" > "${output_file}"

    for pci_addr in /sys/bus/pci/devices/*; do
        [[ -d "$pci_addr" ]] || continue  # Skip non-directory entries

        local interface_name driver_name pci_id
        pci_id=$(basename "$pci_addr")

        # Extract driver name
        if [[ -L "$pci_addr/driver" ]]; then
            driver_name=$(basename "$(realpath "$pci_addr/driver")")
        else
            driver_name="unbound"
        fi

        # Get interface name from sysfs
        if_name_path=$(ls "$pci_addr/net/" 2>/dev/null)
        interface_name=${if_name_path:-"N/A"}  # Use "N/A" if no interface

        # Skip entries without a valid interface name
        [[ "$interface_name" == "N/A" ]] && continue

        # Add comma if not the first entry
        if [[ "$first_entry" == false ]]; then
            echo "," >> "${output_file}"
        fi
        first_entry=false

        # Write JSON object
        cat <<EOF >> "${output_file}"
    {
        "interface_name": "$interface_name",
        "pci_addr": "$pci_id",
        "driver_name": "$driver_name"
    }
EOF
    done

    echo "]" >> "${output_file}"
    echo "JSON file written to ${output_file}"
}

device_info_create "$1"

#EOF
