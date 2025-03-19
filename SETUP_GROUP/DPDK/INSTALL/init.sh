#!/bin/bash
source ${REG_ROOT}/lab.config

if ! ssh $REG_KNI_USER@$REG_OCPHOST "kubectl get node &>/dev/null"; then
    echo "ERROR: check testbed"
    exit 1
fi
# remote REG_ROOT can be different i.e root vs kni. Extract the regulus dir part
reg_dir=$(basename "$REG_ROOT")

if [[ -n "$REM_DPDK_CONFIG" && "$REM_DPDK_CONFIG" == "true" ]]; then
   echo CMD: ssh root@$TREX_HOSTS "cd $reg_dir && source bootstrap.sh && cd DPDK-config/common && bash device-info.sh out.json"  
   ssh root@$TREX_HOSTS "cd $reg_dir && source bootstrap.sh && cd DPDK-config/common && bash device-info.sh out.json"  
   scp root@$TREX_HOSTS:~/$reg_dir/DPDK-config/common/out.json  trex-device-info.json
fi

# Done
