#!/bin/bash

#set -euo pipefail
source ./setting.env
source ./functions.sh

SINGLE_STEP=${SINGLE_STEP:-false}
PAUSE=${PAUSE:-false}

parse_args $@


if oc get svc uperf-lb-svc  &>/dev/null; then
    oc delete svc uperf-lb-svc
fi


if oc get L2Advertisement l2advertisement -n metallb-system  &>/dev/null; then
        echo "delete L2Advertisement  ..."
        oc delete -f ${MANIFEST_DIR}/l2-advertisement.yaml
        echo "delete L2Advertisement done"
else
        echo "L2Advertisement not exist. done"
fi


if oc get IPAddressPool $POOL_NAME  -n metallb-system &>/dev/null; then 
        echo "Deleting IPAddressPool..."
        oc delete -f  ${MANIFEST_DIR}/metalLB-address-pool-config.yaml
        echo "Delete IPAddressPool : done"
else
        echo "No IPaddress pool $POOL_NAME. done"
fi


