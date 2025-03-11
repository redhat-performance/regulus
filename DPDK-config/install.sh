source ${REG_ROOT}/lab.config

pushd ICE-SRIOV/EAST && bash install.sh
popd
pushd ICE-SRIOV/WEST && bash install.sh
popd
