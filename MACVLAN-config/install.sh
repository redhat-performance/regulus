#!/bin/bash
source ${REG_ROOT}/lab.config
source ${REG_ROOT}/MACVLAN-config/config.env

export MANIFEST_DIR="generated_manifests"

SINGLE_STEP=${SINGLE_STEP:-false}
PAUSE=${PAUSE:-false}

#set -euo pipefail
source ./functions.sh

parse_args $@

mkdir -p ${MANIFEST_DIR}/

if oc get network.config.openshift.io cluster -o jsonpath='{.spec.clusterNetwork[*].cidr}' | grep -q ":"; then
    export REG_IPV6_RANGE=',{"range_v6": "2001::00/64"}'
else
    export REG_IPV6_RANGE=""
fi

function create_nad {
    envsubst  < templates/net-attach-def.yaml.template > ${MANIFEST_DIR}/net-attach-def.yaml

    echo "Defer NAD creation to run.sh"
    return # lately we create NAD per test. So no need to create now

    if oc get network-attachment-definition/regulus-macvlan-net &>/dev/null; then
        echo "NAD exists. Skip creation"
    else
        echo "creating NAD ..."
        # we always recreate a NAD for test .
        oc create -f ${MANIFEST_DIR}/net-attach-def.yaml
        echo "created NAD, done"
    fi
}
# create network-attachment-definition/
echo "create NAD"
prompt_continue
create_nad

# Done
