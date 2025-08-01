source ${REG_ROOT}/lab.config

nic_type=$REG_HWOL_NIC_MODEL

case "${nic_type}" in
    CX5|CX6)
        echo "config $REG_HWOL_NIC_MODEL"
        ;;
    *)
        echo "Unsupport NIC $REG_HWOL_NIC_MODEL"
        exit 1
        ;;
esac

pushd $nic_type > /dev/null && bash cleanup.sh && popd >/dev/null
#pushd $nic_type/WEST && bash cleanup.sh && popd

