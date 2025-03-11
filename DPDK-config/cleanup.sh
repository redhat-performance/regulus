source ${REG_ROOT}/lab.config

pushd ICE-SRIOV/EAST && bash cleanup.sh
popd
pushd ICE-SRIOV/WEST && bash cleanup.sh
popd
