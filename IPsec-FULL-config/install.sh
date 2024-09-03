#!/bin/sh
#
# Install IPsec for local traffic ONLY. i.e mode=Full, and without additional config for External traffic
#

source ./functions.sh

channel="$(get_ocp_channel)"
if [ "$channel" == "4.14"  ] ; then
    oc patch networks.operator.openshift.io cluster --type=merge -p '{"spec":{"defaultNetwork":{"ovnKubernetesConfig":{"ipsecConfig":{ }}}}}'
else
    # 4.15 and later on
    oc patch networks.operator.openshift.io cluster --type=merge -p '{ "spec":{ "defaultNetwork":{ "ovnKubernetesConfig":{ "ipsecConfig":{ "mode":"full" }}}}}'
fi

# debug: oc get networks.operator.openshift.io cluster -o yaml


