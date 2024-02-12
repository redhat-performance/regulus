#!/bin/sh
#

set -euo pipefail

source ./setting.env
source ./functions.sh

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

echo HN short; exit

echo "deleting label for $WORKER_LIST ..."
for worker in $WORKER_LIST; do
   oc label --overwrite node ${worker} node-role.kubernetes.io/${MCP}-
done

# wait for nodes to move back to mcp worker
if [[ "${WAIT_MCP}" == "true" ]]; then
    wait_mcp worker
fi

##### Remove MCP ######
if oc get mcp $MCP 2>/dev/null; then
    oc delete -f ${MANIFEST_DIR}/mcp-${MCP}.yaml
    echo "deleted mcp for ${MCP}: done"
fi

# EOF
