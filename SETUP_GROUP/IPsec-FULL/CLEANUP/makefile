#
# run: run oc/kubectl to cleanup IPsec-FULL on the testbed
#

ifndef REG_ROOT
$(error REG_ROOT is not set. Please 'source ./bootstrap.sh')
endif
include ${REG_ROOT}/jobs.config
include ${REG_ROOT}/lab.config

init:

run:
	@bash ./cleanup.sh

