#!/bin/sh
#
# Overall error handling policy: require operator intervention upon error
# Scenarios: 
#    1. install after install:   ERROR
#    2. cleanup before install:  OK
#    2. cleanup after cleanup:   OK
#
source ./setting.env

DEBUG=1
DPRINT() {
  if [ "$DEBUG" == 1 ]; then
     printf "($1): $2\n" 
  fi
}

print_usage() {
    declare -A arr
    arr+=( ["install"]="install vfio-pci devices on remotehost"
           ["cleanup"]="cleanup vfio-pci devices on remotehost"
         )
    echo "Usage:"
    echo ""
    for key in ${!arr[@]}; do
        printf '%-15s: %s\n' "$key" "${arr[$key]}"
    done
    exit 1
}

rebind_kernel_auto() {
    # Assuming the interface is bound to vfio-pci. Rebind to its kernel driver.
    # Example usage:
    #   rebind_kernel_auto 0000:98:00.0 

    local pci=$1
    DPRINT $LINENO "Attempting to unbind ${pci} from vfio-pci and rebind to kernel driver automatically"

    # Unbind from vfio-pci if already bound
    local vfio_driver_path="/sys/bus/pci/devices/${pci}/driver"
    if [[ -e ${vfio_driver_path} ]] && [[ "$(basename "$(realpath ${vfio_driver_path})")" == "vfio-pci" ]]; then
        echo "${pci}" > "/sys/bus/pci/drivers/vfio-pci/unbind" || {
            echo "Failed to unbind ${pci} from vfio-pci"
            exit 1
        }
        DPRINT $LINENO "Successfully unbound ${pci} from vfio-pci"
    else
        DPRINT $LINENO "${pci} is not bound to vfio-pci, skipping unbind"
    fi

    # Clear the driver_override to allow automatic kernel driver binding
    if [[ -w "/sys/bus/pci/devices/${pci}/driver_override" ]]; then
        echo "" > "/sys/bus/pci/devices/${pci}/driver_override" || {
            echo "Failed to clear driver_override for ${pci}"
            exit 1
        }
        DPRINT $LINENO "Cleared driver_override for ${pci}"
    else
        DPRINT $LINENO "No driver_override set for ${pci}, skipping"
    fi

    # Trigger PCI rescan to allow kernel to find and bind the appropriate driver
    echo 1 > /sys/bus/pci/rescan || {
        echo "Failed to trigger PCI rescan"
        exit 1
    }

    # Wait a moment for the kernel to detect and bind the correct driver
    sleep 2

    # Check if the device is bound to a kernel driver
    local driver_path="/sys/bus/pci/devices/${pci}/driver"
    if [[ -e ${driver_path} ]]; then
        local kernel_driver=$(basename "$(realpath ${driver_path})")
        DPRINT $LINENO "${pci} is now bound to ${kernel_driver}"
    else
        echo "WARN: rescan failed to bind ${pci} to a kernel driver. Attempting to find the driver manually."

        # Use `lspci -k` to find which driver is responsible for the PCI device
        local driver_name
        driver_name=$(lspci -k -s ${pci} | grep -A 2 "Kernel modules" | grep -oP "(?<=Kernel modules: )\S+")

        if [[ -n "$driver_name" ]]; then
            # Now bind the device to the correct driver
            echo "${pci}" > "/sys/bus/pci/drivers/${driver_name}/bind" || {
                echo "Failed to manually bind ${pci} to driver ${driver_name}"
                exit 1
            }
            DPRINT $LINENO "${pci} successfully bound to ${driver_name}"
        else
            echo "Could not determine the appropriate kernel driver for ${pci}. Manual bind failed."
            exit 1
        fi
    fi
}

is_device_bound_to_vfio() {
    local pci=$1
    local driver_path="/sys/bus/pci/devices/${pci}/driver"

    if [[ -e ${driver_path} ]]; then
        local current_driver=$(basename "$(realpath ${driver_path})")
        if [[ "${current_driver}" == "vfio-pci" ]]; then
            echo "${pci} is currently bound to the vfio-pci driver."
            return 0  # Success
        else
            echo "${pci} is bound to ${current_driver}, not vfio-pci."
            return 1  # Failure
        fi
    else
        echo "${pci} is not bound to any driver."
        return 2  # No driver bound
    fi
}

bind_driver() {
    # Assuming the device is bound to a kernel driver i.e. ice
    # Example usage:
    #   bind_driver vfio-pci 0000:98:00.0 

    local driver=$1
    local pci=$2
    DPRINT $LINENO "Attempting to bind ${pci} to ${driver}"

    # Check if the device has a currently bound driver
    local driver_path="/sys/bus/pci/devices/${pci}/driver"
    if [[ -e ${driver_path} ]]; then
        local current_driver
        current_driver=$(basename "$(realpath "${driver_path}")")
        DPRINT $LINENO "Current driver for ${pci} is ${current_driver}, unbinding..."
        if ! echo "${pci}" > "/sys/bus/pci/drivers/${current_driver}/unbind"; then
            echo "Failed to unbind current driver from ${pci}"
            exit 1
        fi
        sleep 1  # Allow time for unbind to take effect
    else
        DPRINT $LINENO "No driver bound to ${pci}, skipping unbind"
    fi


    # Check if driver_override exists and is writable
    local driver_override_path="/sys/bus/pci/devices/${pci}/driver_override"
    if [[ ! -w "${driver_override_path}" ]]; then
        echo "Error: driver_override is not writable for ${pci}"
        exit 1
    fi

    # Override the driver
    if ! echo "${driver}" > "${driver_override_path}"; then
        echo "Failed to set driver_override for ${pci}"
        exit 1
    fi

    # Bind the device to the new driver
    if ! echo "${pci}" > "/sys/bus/pci/drivers/${driver}/bind"; then
        echo "Failed to bind ${pci} to ${driver}"
        exit 1
    fi

    # Verify successful binding
    if [[ -e ${driver_path} ]] && [[ "$(basename "$(realpath "${driver_path}")")" == "${driver}" ]]; then
        DPRINT $LINENO "Successfully bound ${pci} to ${driver}"
    else
        echo "Failed to bind ${pci} to ${driver}"
        exit 1
    fi
}


install() {
    DPRINT $LINENO "Enter=setup" 
    echo "Setting up vfio-pci on TREX host ..."

    echo "bind PF to vfio-pci"
    modprobe vfio-pci

   	pf_pci=$(realpath /sys/class/net/${TREX_SRIOV_INTERFACE_1}/device| awk -F '/' '{print $NF}')
    echo CMD: bind_driver vfio-pci ${pf_pci}
    bind_driver vfio-pci "${pf_pci}"

    pf_pci=$(realpath /sys/class/net/${TREX_SRIOV_INTERFACE_2}/device | awk -F '/' '{print $NF}')
    echo CMD: bind_driver vfio-pci ${pf_pci}
    bind_driver vfio-pci "${pf_pci}"

    echo "vfio-pci devices setup on TREX host: done"
}     

vfio_devices=()

find-vfio-pci() {
  # Find all PCI devices bound to vfio-pci
  for pci_device in /sys/bus/pci/drivers/vfio-pci/*; do
     # Ensure it's a symlink to a valid device directory
     target=$(readlink -f "$pci_device")
     if [[ -L "$pci_device" && -d "$target" && "$target" == /sys/devices/* ]]; then
        # Extract the PCI address from the symlink
        pci_address=$(basename "$pci_device")
        echo "Device bound to vfio-pci: $pci_address"
        vfio_devices+=("$pci_address")
     fi
  done
}

cleanup() {
    echo "Cleaning up vfio-pci devices on TREX host"
    find-vfio-pci

    for pci in "${vfio_devices[@]}" ; do
    	echo CMD: rebind_kernel_auto ${pci}
    	rebind_kernel_auto "${pci}" 
    done

    # debug lspci -nnk | grep -A3 "98:00." should show ice
       
    echo "vfio-pci cleanup on TREX host: done"
}

if (( $# != 1 )); then
    print_usage
else
    ACTION=$1
fi

case "${ACTION}" in
    install)
        DPRINT $LINENO "/sys/class/net/${TREX_SRIOV_INTERFACE_1}"
        if [[ ! -e /sys/class/net/${TREX_SRIOV_INTERFACE_1} ]]; then
            echo "device $TREX_SRIOV_INTERFACE_1 not bound to a kernel driver"
            exit 1
        fi
        if [[ ! -e /sys/class/net/${TREX_SRIOV_INTERFACE_2} ]]; then
            echo "device $TREX_SRIOV_INTERFACE_2 not bound to a kernel driver"
            exit 1
        fi
    
        DPRINT $LINENO "action=install" 
        # set mtu before bind them to vfio-mtu
        ip link set dev ${TREX_SRIOV_INTERFACE_1} mtu ${SRIOV_MTU}
        ip link set dev ${TREX_SRIOV_INTERFACE_2} mtu ${SRIOV_MTU}
        install 
    ;;
    cleanup)
        DPRINT $LINENO "action=cleanup" 
        cleanup
    ;;
    *)
        print_usage
esac

