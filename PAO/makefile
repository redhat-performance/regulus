#
# init:     init this dir one-time
# install:  install performanceprofile
# cleanup:  remove performanceprofile
#

ifndef REG_ROOT
$(error REG_ROOT is not set. Please 'source ./bootstrap.sh')
endif
include ${REG_ROOT}/jobs.config

init:
	. ${REG_ROOT}/lab.config && ./reg_expand.sh
install:
	. ${REG_ROOT}/lab.config && bash install.sh
clean:
	. ${REG_ROOT}/lab.config && bash cleanup.sh 
