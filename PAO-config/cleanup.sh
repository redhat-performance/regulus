#!/bin/sh
#
# Cleanup performanceprofile while taking into consideration the SRIOV states.
# 	If SRIOV is still active, leave node labels and MCP alone.
#

set -euo pipefail

source ./setting.env
source ./functions.sh
SINGLE_STEP=${SINGLE_STEP:-false}

parse_args $@

##### Remove performan-profile ######
echo "Removing performance profile ..."
if oc get PerformanceProfile ${MCP} &>/dev/null; then
  oc delete PerformanceProfile ${MCP}
  echo "deleted performance-profile: done"

  if [[ "${WAIT_MCP}" == "true" ]]; then
      wait_mcp ${MCP}
   fi
else
  echo "No performance profile: done"
fi

if oc get SriovNetworkNodePolicy &>/dev/null; then
    echo "SRIOV is still active. Skip the rest. Done"
    exit
fi


echo "Next, remove node labels and MCP ${MCP}"
prompt_continue 

echo "deleting label for $WORKER_LIST ..."
if [ "${MCP}" != "master" ]; then
    # this is STANDARD cluster. Do it.
    for worker in $WORKER_LIST; do
        oc label node ${worker} node-role.kubernetes.io/${MCP}-
    done
fi

##### Remove MCP ######
if [ "${MCP}" != "master" ]; then
    # this is STANDARD cluster. Do it.
    if oc get mcp ${MCP} 2>/dev/null; then
        oc delete mcp ${MCP}
        echo "deleted mcp for ${MCP}: done"
    fi
else
    # this is non-standard cluster that uses mcp master. Just remove the label.
    oc label mcp ${MCP} machineconfiguration.openshift.io/role-

fi


# EOF
