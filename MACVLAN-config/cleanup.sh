#!/bin/bash

#set -euo pipefail
source ./functions.sh

SINGLE_STEP=${SINGLE_STEP:-false}
PAUSE=${PAUSE:-false}

parse_args $@

if oc get network-attachment-definition/regulus-macvlan-net &>/dev/null; then
    echo "remove MACVLAN ..."
    oc delete network-attachment-definition/regulus-macvlan-net 
    echo "remove macvlan NAD: done"
else
    echo "No macvlan NAD to remove"
fi

#done

