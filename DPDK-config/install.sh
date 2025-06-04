source ${REG_ROOT}/lab.config

nic_type=$REG_DPDK_NIC_MODEL

case "${nic_type}" in
    X710|XXV710|E810|CX6)
        echo "config $REG_DPDK_NIC_MODEL"
        ;;
    *)
        echo "Unsupport NIC $REG_DPDK_NIC_MODEL"
        exit 1
        ;;
esac

pushd $nic_type/EAST && bash install.sh && popd
pushd $nic_type/WEST && bash install.sh && popd

