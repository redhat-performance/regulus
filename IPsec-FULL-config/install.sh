#!/bin/sh
#
# Install IPsec for local traffic ONLY. i.e mode=Full, and without additional config for External traffic
#

echo oc patch networks.operator.openshift.io cluster --type=merge \
    -p '{"spec":{"defaultNetwork":{"ovnKubernetesConfig":{"ipsecConfig":{"mode": "Full"}}}}}'

#
# debug: oc -n openshift-ovn-kubernetes rsh ovnkube-node-<XXXXX> ovn-nbctl --no-leader-only get nb_global . ipsec
#
