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

.PHONY: clean

trex-device-info.json: init.sh
	@echo "Running trex-device-info target"
	@bash ./init.sh
	@touch trex-device-info.json

init:
	@bash ./init.sh

clean:
	@rm -f trex-device-info.json

run: trex-device-info.json
	@bash ./install.sh

