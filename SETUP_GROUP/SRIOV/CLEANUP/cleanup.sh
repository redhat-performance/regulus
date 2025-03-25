#!/bin/bash

source ${REG_ROOT}/lab.config

if ! ssh $REG_KNI_USER@$REG_OCPHOST "kubectl get node  &>/dev/null"; then
    echo "ERROR: check testbed"
    exit 1
fi

ssh $REG_KNI_USER@$REG_OCPHOST "cd $REG_DIR && source bootstrap.sh && cd SRIOV-config/UNIV && make cleanup "  

# Done
