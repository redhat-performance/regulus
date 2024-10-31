#
# init:     init this dir one-time
# install:  install IPsec
# cleanup:  remove IPsec
#

ifndef REG_ROOT
$(error REG_ROOT is not set. Please 'source ./bootstrap.sh')
endif
include ${REG_ROOT}/jobs.config
include ${REG_ROOT}/lab.config

confirm_bastion: 
	@if [ "$$(hostname)" != "$(REG_OCPHOST)" ] &&  [ "$$(hostname -i)" != "$(REG_OCPHOST)" ]; then \
		echo "Aborting. On $$(hostname). Please run this command on the bastion, $${REG_OCPHOST}."; \
		exit 1; \
	fi

init: confirm_bastion
	@bash ./expand.sh
install: confirm_bastion
	@bash ./install.sh
cleanup: confirm_bastion
	@bash ./cleanup.sh

