#
# Usage: "make run" to install OCP  and TREX_HOST vfio-pci devices
# Dependecies: 
#    export TREX_HOSTS="hostname"
#    export REM_DPDK_CONFIG=true
#

ifndef REG_ROOT
$(error REG_ROOT is not set. Please 'source ./bootstrap.sh')
endif
include ${REG_ROOT}/jobs.config
include ${REG_ROOT}/lab.config

.PHONY: confirm_controller clean

confirm_controller:
	@if [ "$$(hostname)" != "$(REG_OCPHOST_NAME)" ]; then \
		echo "Aborting. Please run this command on the controller."; \
		exit 1; \
	fi

trex-device-info.json: init.sh
	@echo "Running trex-device-info target"
	@bash ./init.sh
	@touch trex-device-info.json

init: confirm_controller
	@bash ./init.sh

clean:
	@rm -f trex-device-info.json

run: confirm_controller trex-device-info.json
	@bash ./install.sh

