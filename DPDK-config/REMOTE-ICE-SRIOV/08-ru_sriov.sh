#!/bin/sh
#
# New since 22.03.
#   Init: during testbed prep
#       08-ru_siov_.sh setup  (Manual by CLI)
#   Each run:
#       08-ru_siov_.sh config (Auto my flexran-server-start scrip)
#
# This script creates RU VFs and fixes up config files to run the below XRAN test.
# ORU_DIR=${FLEXRAN_ROOT}/bin/nr5g/gnb/l1/orancfg/sub3_mu0_20mhz_4x4/oru
#

set -euo pipefail

DEBUG=1
source ./functions.sh
source ./setting.env

SINGLE_STEP=${SINGLE_STEP:-true}

print_usage() {
    declare -A arr
    arr+=( ["setup"]="setup SRIOV on RU"
           ["clean"]="cleanup SRIOV on RU"
         )
    echo "Usage:"
    echo ""
    for key in ${!arr[@]}; do
        printf '%-15s: %s\n' "$key" "${arr[$key]}"
    done
    exit 1
}

setup() {
    DPRINT $LINENO "Enter=setup" 
    echo "Setting up SRIOV on RU ..."

    #echo "creating VFs on ${RU_SRIOV_INTERFACE_1}"
    #echo 1 > /sys/class/net/${RU_SRIOV_INTERFACE_1}/device/sriov_numvfs    
    #ip link set dev ${RU_SRIOV_INTERFACE_1} vf 0 mac 00:11:22:33:00:10 spoofchk off
    #ip link set dev ${RU_SRIOV_INTERFACE_1} vf 1 mac 00:11:22:33:00:11 spoofchk off

    #echo "creating VFs on  ${RU_SRIOV_INTERFACE_2}"
    #echo 1 > /sys/class/net/${RU_SRIOV_INTERFACE_2}/device/sriov_numvfs    
    #ip link set dev ${RU_SRIOV_INTERFACE_2} vf 0  mac 00:11:22:33:00:20 spoofchk off
    #ip link set dev ${RU_SRIOV_INTERFACE_2} vf 1  mac 00:11:22:33:00:21 spoofchk off
    prompt_continue 

    # Tip: ip link show dev ens8f1
    # sleep a little so dmesg of VFs and binds kept in sequences. Better debug
    sleep 10
    echo "bind VF to vfio-pci"
    modprobe vfio-pci
    vfs_str=""

    for v in 0 ; do
    	# vf_pci=$(realpath /sys/class/net/${RU_SRIOV_INTERFACE_1}/device/virtfn${v} | awk -F '/' '{print $NF}')
    	vf_pci=$(realpath /sys/class/net/${RU_SRIOV_INTERFACE_1}/device| awk -F '/' '{print $NF}')
    	echo CMD: bind_driver vfio-pci ${vf_pci}
    	bind_driver vfio-pci "${vf_pci}"
    done

    for v in 0 ; do
        #vf_pci=$(realpath /sys/class/net/${RU_SRIOV_INTERFACE_2}/device/virtfn${v} | awk -F '/' '{print $NF}')
        vf_pci=$(realpath /sys/class/net/${RU_SRIOV_INTERFACE_2}/device | awk -F '/' '{print $NF}')
        echo CMD: bind_driver vfio-pci ${vf_pci}
        bind_driver vfio-pci "${vf_pci}"
    done

    echo "SRIOV setup on RU: done"
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

clean() {
    echo "Cleaning up SRIOV on RU"
    find-vfio-pci
    #echo 0 > /sys/class/net/${RU_SRIOV_INTERFACE_1}/device/sriov_numvfs
    #echo 0 > /sys/class/net/${RU_SRIOV_INTERFACE_2}/device/sriov_numvfs

    for pci in "${vfio_devices[@]}" ; do
    	echo CMD: bind_driver ice ${pci}
    	bind_driver ice "${pci}"
    done

    # debug lspci -nnk | grep -A3 "98:00." should show ice
       
    echo "SRIOV cleanup on RU: done"
}

if (( $# != 1 )); then
    print_usage
else
    ACTION=$1
fi


case "${ACTION}" in
    setup)
        DPRINT $LINENO "action=setup" prompt_continue
        # set mtu before bind them to vfio-mtu
        ip link set dev ${RU_SRIOV_INTERFACE_1} mtu ${SRIOV_MTU}
        ip link set dev ${RU_SRIOV_INTERFACE_2} mtu ${SRIOV_MTU}
        setup 
    ;;
    clean)
        DPRINT $LINENO "action=cleanup" 
        prompt_continue
        clean 
    ;;
    *)
        print_usage
esac

