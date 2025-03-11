#!/bin/bash
# There different platforms that we run on. On NCP and RDS, day-1 is ready. While on a 
#   freshly created cluster, we are responsible for day-1.
# Hence, we have two SRIOV config scenarios.
#	1. Partial-installation (SriovNetworkNodePolicy and networkAttachementDefinition)
# 	2. Full-installation (SRIOV operator + partial installation)
# Therefore we have 2 reciprocol cleanup functions.

source ${REG_ROOT}/lab.config
source ${REG_ROOT}/SRIOV-config/config.env
source ${REG_ROOT}/DPDK-config/config.env

if [ "${DPDK_NAD_ONLY}"  ==  "true" ]; then
	echo DPDK-config: NAD only
        bash ./node-nad-cleanup.sh
else
	echo DPDK-config: SRIOV Operator and NAD 
        bash ./node-nad-cleanup.sh
        bash ./operator-cleanup.sh
fi
