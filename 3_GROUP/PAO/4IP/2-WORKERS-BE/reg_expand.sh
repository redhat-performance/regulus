#!/bin/bash
# mbench PAO, IPv4, SRIOV, Best-effort - 2 WORKERS BALANCED CONFIGURATION
# 50% inter-node, 50% intra-node tests
# Covers TCP CRR, TCP Stream, UDP evenly across 2 workers
#
#          WORKER-0                                                        WORKER-1
#  ================================================================================================
#
#  [1]  ------------------- uperf CRR wsize=512,rsize=2048,1th -------------> [1]
#  [2]  ------------------- uperf CRR wsize=512,rsize=2048,1th -------------> [2]
#  [3]  ------------------- uperf CRR wsize=512,rsize=2048,1th -------------> [3]
#  [4]  ------------------- uperf CRR wsize=512,rsize=2048,1th -------------> [4]
#  [5]  ------------------- uperf CRR wsize=512,rsize=2048,1th -------------> [5]
#  [6]  <------------------ uperf CRR wsize=512,rsize=2048,1th -------------- [6]
#  [7]  <------------------ uperf CRR wsize=512,rsize=2048,1th -------------- [7]
#  [8]  <------------------ uperf CRR wsize=512,rsize=2048,1th -------------- [8]
#  [9]  <------------------ uperf CRR wsize=512,rsize=2048,1th -------------- [9]
#  [10] <------------------ uperf CRR wsize=512,rsize=2048,1th -------------- [10]
#  [11] -- uperf CRR wsize=512,rsize=2048,1th --> [11]
#  [12] -- uperf CRR wsize=512,rsize=2048,1th --> [12]
#  [13] -- uperf CRR wsize=512,rsize=2048,1th --> [13]
#  [14] -- uperf CRR wsize=512,rsize=2048,1th --> [14]
#  [15] -- uperf CRR wsize=512,rsize=2048,1th --> [15]
#                                                                              [16] -- uperf CRR wsize=512,rsize=2048,1th --> [16]
#                                                                              [17] -- uperf CRR wsize=512,rsize=2048,1th --> [17]
#                                                                              [18] -- uperf CRR wsize=512,rsize=2048,1th --> [18]
#                                                                              [19] -- uperf CRR wsize=512,rsize=2048,1th --> [19]
#                                                                              [20] -- uperf CRR wsize=512,rsize=2048,1th --> [20]
#  [21] ------------------ iperf UDP bitrate=200M,len=256 -------------------> [21]
#  [22] ------------------ iperf UDP bitrate=200M,len=256 -------------------> [22]
#  [23] <----------------- iperf UDP bitrate=200M,len=512 -------------------- [23]
#  [24] <----------------- iperf UDP bitrate=200M,len=512 -------------------- [24]
#  [25] -- iperf UDP bitrate=400M,len=1024 --> [25]
#                                                                              [26] -- iperf UDP bitrate=400M,len=1024 --> [26]
#  [27] ---------------- uperf Stream wsize=32768,1th -----------------------> [27]
#  [28] ---------------- uperf Stream wsize=512,16th ------------------------> [28]
#  [29] <--------------- uperf Stream wsize=32768,1th ------------------------ [29]
#  [30] <--------------- uperf Stream wsize=512,16th ------------------------- [30]
#  [31] -- uperf Stream wsize=32768,1th --> [31]
#                                                                              [32] -- uperf Stream wsize=512,16th --> [32]
#

REG_ROOT=${REG_ROOT:-/root/REGULUS}
REG_TEMPLATES=${REG_ROOT}/templates/mbench-small
REG_MVPARAMS_TEMPLATES=${REG_ROOT}/templates/mbench-official
REG_COMMON=${REG_ROOT}/templates/common
MANIFEST_DIR=./
source $REG_ROOT/lab.config    		# for worker node names
source ${REG_ROOT}/system.config	# for MCP

# generate run.sh with custom-param "node-config"
export TPL_NODE_CONF="node-config"
envsubst '$MCP,$TPL_NODE_CONF' < ${REG_TEMPLATES}/run.sh.template > ${MANIFEST_DIR}/run.sh

# generate run-3types.sh - USE 2-WORKER TEMPLATE
export TPL_SRIOV=0
envsubst '$TPL_SRIOV'  < ${REG_TEMPLATES}/run-3types-2worker.sh.template > ${MANIFEST_DIR}/run-3types.sh

export TPL_PAO=1

# generate node-config w/o custom resources - USE 2-WORKER TEMPLATE
envsubst '$TPL_PAO,$MCP,$TPL_RESOURCES,$TPL_SRIOV' < ${REG_TEMPLATES}/base-node-config-2worker.template > ${MANIFEST_DIR}/node-config

# generate annotation.
envsubst '' < ${REG_COMMON}/annotations-pao.json.template  > ${MANIFEST_DIR}/annotations.json

# generate placement - USE 2-WORKER TEMPLATE
envsubst '' < ${REG_TEMPLATES}/2worker-32pairs.placement.template  > ${MANIFEST_DIR}/pairs.placement

export TPL_INTF=eth0
export TPL_IPV=4
envsubst '$TPL_INTF,$TPL_IPV' < ${REG_MVPARAMS_TEMPLATES}/iperf-mv-params.json.template >  ${MANIFEST_DIR}/iperf-mv-params.json
# Use balanced 2-worker template (IDs 31-32 both use wsize=32768,16th)
envsubst '$TPL_INTF,$TPL_IPV' < ${REG_TEMPLATES}/uperf-mv-params-2worker-balanced.json.template >  ${MANIFEST_DIR}/uperf-mv-params.json

# generta tools params. No custom params
envsubst '' < ${REG_COMMON}/tool-params.json.template >  ${MANIFEST_DIR}/tool-params.json
cp ${REG_COMMON}/securityContext.json.template  ${MANIFEST_DIR}/securityContext.json

# generate worker node mapping - ONLY 2 WORKERS
export TPL_WORKER=$OCP_WORKER_0
envsubst '$TPL_WORKER' < ${REG_TEMPLATES}/nodeSelector-worker-n.json.template >  ${MANIFEST_DIR}/nodeSelector-worker-0.json

export TPL_WORKER=$OCP_WORKER_1
envsubst '$TPL_WORKER' < ${REG_TEMPLATES}/nodeSelector-worker-n.json.template >  ${MANIFEST_DIR}/nodeSelector-worker-1.json

# done
