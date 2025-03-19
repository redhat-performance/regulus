source ${REG_ROOT}/lab.config

nic_type=$REG_DPDK_NIC_MODEL

case "${nic_type}" in
    X710|XXV710|E810|MLX6)
        echo "config $REG_DPDK_NIC_MODEL"
        ;;
    *)
        echo "Unsupport NIC $REG_DPDK_NIC_MODEL"
        exit 1
        ;;
esac

pushd $nic_type/EAST && bash cleanup.sh && popd
pushd $nic_type/WEST && bash cleanup.sh && popd

