#!/bin/sh
#
# Remove IPsec for local traffic ONLY.
#

source ./functions.sh

channel="$(get_ocp_channel)"
if [ "$channel" == "4.14"  ] ; then
    oc patch networks.operator.openshift.io/cluster --type=json -p='[{"op":"remove", "path":"/spec/defaultNetwork/ovnKubernetesConfig/ipsecConfig"}]'
else
    # 4.15 and later
    oc patch networks.operator.openshift.io cluster --type=merge -p '{ "spec":{ "defaultNetwork":{ "ovnKubernetesConfig":{ "ipsecConfig":{ "mode":"Disabled" }}}}}'
fi

# debug: oc get networks.operator.openshift.io cluster -o yaml


