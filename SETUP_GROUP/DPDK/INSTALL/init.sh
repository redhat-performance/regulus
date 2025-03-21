#!/bin/bash
source ${REG_ROOT}/lab.config

if ! ssh $REG_KNI_USER@$REG_OCPHOST "kubectl get node &>/dev/null"; then
    echo "ERROR: check testbed"
    exit 1
fi

ssh $REG_KNI_USER@$REG_OCPHOST "cd $REG_DIR && source bootstrap.sh && cd DPDK-config && make init "  

if [[ -n "$REM_DPDK_CONFIG" && "$REM_DPDK_CONFIG" == "true" ]]; then
   echo CMD: ssh root@$TREX_HOSTS "cd $REG_DIR && source bootstrap.sh && cd DPDK-config/common && bash device-info.sh out.json"  
   ssh root@$TREX_HOSTS "cd $REG_DIR && source bootstrap.sh && cd DPDK-config/common && bash device-info.sh out.json"  
   scp root@$TREX_HOSTS:~/$REG_DIR/DPDK-config/common/out.json  trex-device-info.json

fi

# Done
