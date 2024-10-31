#!/bin/sh
#
# Remove IPsec for local traffic ONLY.
#

source ./functions.sh

if [[ "$(wait_mcp_state_ready 0)" == "False" ]]; then
    printf "\nMCP is not in ready state. Try again later\n"
    exit 1
fi

if [[ "$(ipsec_is_enable)" == "False" ]]; then
    printf "\nIPsec is not enabled. Nothing to disable.\n"
    exit 0
fi

channel="$(get_ocp_channel)"

if [[ "$channel" == "4.14" ]]; then
    # For OCP 4.14, remove the IPsec config entirely
    if ! oc patch networks.operator.openshift.io/cluster --type=json -p='[{"op":"remove", "path":"/spec/defaultNetwork/ovnKubernetesConfig/ipsecConfig"}]'; then
        echo "Error: Failed to remove IPsec config for 4.14." >&2
        exit 1
    fi
else
    # For OCP 4.15 and later, disable IPsec by setting mode to "Disabled"
    if ! oc patch networks.operator.openshift.io cluster --type=merge -p '{ "spec":{ "defaultNetwork":{ "ovnKubernetesConfig":{ "ipsecConfig":{ "mode":"Disabled" }}}}}'; then
        echo "Error: Failed to patch IPsec config for 4.15 and later." >&2
        exit 1
    fi
fi

# Wait for MCP to start updating
if [[ "$(wait_mcp_state_not_ready 600)" == "False" ]]; then
    printf "\nTimeout waiting for MCP to start updating after 600 sec. Further debug is needed.\n"
    exit 1
fi

# Wait for MCP to return to ready state
if [[ "$(wait_mcp_state_ready 3000)" == "False" ]]; then
    printf "\nTimeout waiting for MCP to return to ready after 3000 sec. Further debug is needed.\n"
    exit 1
fi

# debug: oc get networks.operator.openshift.io cluster -o yaml

