#!/bin/bash
source ${REG_ROOT}/lab.config

if ! ssh $REG_KNI_USER@$REG_OCPHOST "kubectl get node &>/dev/null"; then
    echo "ERROR: check testbed"
    exit 1
fi

echo CMD: ssh $REG_KNI_USER@$REG_OCPHOST "cd $REG_DIR && source bootstrap.sh && cd DPDK-config && bash install.sh "  
ssh $REG_KNI_USER@$REG_OCPHOST "cd $REG_DIR && source bootstrap.sh && cd DPDK-config && bash install.sh "  

if [[ -n "$REM_DPDK_CONFIG" && "$REM_DPDK_CONFIG" == "true" ]]; then
   echo CMD: ssh root@$TREX_HOSTS "cd $REG_DIR && source bootstrap.sh && cd DPDK-config/REMOTE-ICE-SRIOV && bash sriov-setup.sh install"  
   ssh root@$TREX_HOSTS "cd $REG_DIR && source bootstrap.sh && cd DPDK-config/REMOTE-ICE-SRIOV && bash sriov-setup.sh install"  
fi

# Done
