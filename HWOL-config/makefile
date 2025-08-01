#
# init:     init this dir one-time
# install:  install SRIOV for HWOL
# cleanup:  remove SRIOV for HWOL
#

ifndef REG_ROOT
$(error REG_ROOT is not set. Please 'source ./bootstrap.sh')
endif
include ${REG_ROOT}/jobs.config
include ${REG_ROOT}/lab.config

confirm_bastion:
	@REG_OCPHOST=$$(echo "$$REG_OCPHOST" | sed 's/^[" ]*//; s/[" ]*$$//'); \
	host_name="$$(hostname)"; \
	host_ip="$$(hostname -i | awk '{print $$1}')"; \
	if [ "$$host_name" != "$$REG_OCPHOST" ] && ! hostname -I | grep -qw "$$REG_OCPHOST"; then \
		echo "Detected host_ip: $$host_ip"; \
		echo "Detected host_name: $$host_name"; \
		echo "Aborting. Please run this command on the configured bastion, $$REG_OCPHOST."; \
		exit 1; \
	fi

init: confirm_bastion
	@bash ./expand.sh

install: confirm_bastion
	@bash ./install.sh

cleanup: confirm_bastion
	@bash ./cleanup.sh
