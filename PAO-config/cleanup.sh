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
  oc delete -f ${MANIFEST_DIR}/performance_profile.yaml 
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
for worker in $WORKER_LIST; do
    oc label --overwrite node ${worker} node-role.kubernetes.io/${MCP}-
done

##### Remove MCP ######
if oc get mcp $MCP 2>/dev/null; then
    oc delete -f ${MANIFEST_DIR}/mcp-${MCP}.yaml
    echo "deleted mcp for ${MCP}: done"
fi


# EOF
