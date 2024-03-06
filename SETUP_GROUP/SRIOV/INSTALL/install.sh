#!/bin/bash
source ${REG_ROOT}/lab.config

if ! ssh $REG_KNI_USER@$REG_OCPHOST "kubectl get node &>/dev/null"; then
    echo "ERROR: check testbed"
    exit 1
fi

# remote REG_ROOT can be different i.e root vs kni. Extract the regulus dir part
reg_dir=$(basename "$REG_ROOT")

ssh $REG_KNI_USER@$REG_OCPHOST "cd $reg_dir && source bootstrap.sh && cd SRIOV-config/UNIV && make install "  

# Done
