#!/bin/sh
#
# Cleanup/remove/disable IPsec internal node-to-node traffic
#

echo oc patch networks.operator.openshift.io cluster --type=merge \
    -p '{"spec":{"defaultNetwork":{"ovnKubernetesConfig":{"ipsecConfig":null}}}}'

# EOF
