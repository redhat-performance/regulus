#!/bin/bash
# There different platforms that we run on. On NCP and RDS, day-1 is ready. While on a
#   freshly created cluster, we are responsible for day-1.
# Hence, we have two SRIOV config scenarios.
# 	1. SRIOV operator only
#	1. Partial-installation (SriovNetworkNodePolicy and networkAttachementDefinition)
#

source ${REG_ROOT}/lab.config
source ${REG_ROOT}/SRIOV-config/config.env

if [ "${SRIOV_NAD_ONLY}"  ==  "true" ]; then
	echo SRIOV-config: NAD only
        bash ./partial-install.sh
else
	echo SRIOV-config: Operator only
        bash ./operator-only-sh
fi
