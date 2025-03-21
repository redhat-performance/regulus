#
# run: use oc/kubectl to install IPsec on the testbed
#

ifndef REG_ROOT
$(error REG_ROOT is not set. Please 'source ./bootstrap.sh')
endif
include ${REG_ROOT}/jobs.config
include ${REG_ROOT}/lab.config

confirm_controller:
	@if [ "$$(hostname)" == "$(REG_OCPHOST_NAME)" ]; then \
		echo "Aborting. Please run this command on the controller."; \
		exit 1; \
	fi

init:

run: confirm_controller
	@bash ./install.sh

