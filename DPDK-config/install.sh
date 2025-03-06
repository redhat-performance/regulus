#!/bin/bash
# There different platforms that we run on. On NCP and RDS, day-1 is ready. While on a
#   freshly created cluster, we are responsible for day-1.
# Hence, we have two SRIOV config scenarios.
# 	1. SRIOV operator only
#	1. Partial-installation (SriovNetworkNodePolicy and networkAttachementDefinition)
#

source ${REG_ROOT}/lab.config
source ${REG_ROOT}/SRIOV-config/config.env
source ${REG_ROOT}/DPDK-config/config.env

if [ "${DPDK_NAD_ONLY}"  ==  "true" ]; then
	echo DPDK-config: NAD only
        echo CMD: bash ././node-nad-install.sh
        bash ./node-nad-install.sh
else
	echo DPDK-config: SRIOV Operator and NAD
        echo "CMD: bash ./operator-install.sh && bash ./node-nad-install.sh"
       	bash ./operator-install.sh
        bash ./node-nad-install.sh
fi
