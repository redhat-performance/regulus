#
# Usage: "make run" to clean up OCP and TREX_HOST vfio-pci devices
# Dependecies: 
#    export TREX_HOSTS="hostname"
#    export REM_DPDK_CONFIG=true
#
ifndef REG_ROOT
$(error REG_ROOT is not set. Please 'source ./bootstrap.sh')
endif
include ${REG_ROOT}/jobs.config
include ${REG_ROOT}/lab.config

confirm_bastion:
	@if [ "$$(hostname)" == "$(REG_OCPHOST)" ]; then \
		echo "Aborting. Please run this command on the controller."; \
		exit 1; \
	fi

init:

run: confirm_bastion
	@bash ./cleanup.sh

