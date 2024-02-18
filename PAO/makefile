#
# init:     init this dir one-time
# install:  install performanceprofile
# cleanup:  remove performanceprofile
#

ifndef REG_ROOT
$(error REG_ROOT is not set. Please 'source ./bootstrap.sh')
endif
include ${REG_ROOT}/jobs.config

#@echo "VARIABLE_NAME is $${REG_OCPHOST}"

include_env_vars:

confirm_bastion: 
	source ${REG_ROOT}/lab.config && export REG_OCPHOST=$${REG_OCPHOST} 
	@if [ $$(hostname) != "$${REG_OCPHOST}" ]; then \
		 . ${REG_ROOT}/lab.config && echo "ABorting. Please run this command on the bastion, $${REG_OCPHOST}."; \
		exit 1; \
	fi

init: confirm_bastion
	. ${REG_ROOT}/lab.config && ./expand.sh
install: confirm_bastion
	. ${REG_ROOT}/lab.config && bash install.sh
cleanup: confirm_bastion
	. ${REG_ROOT}/lab.config && bash cleanup.sh 
