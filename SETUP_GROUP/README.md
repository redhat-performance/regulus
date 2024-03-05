This group provides the "API" to remotely install and cleaup the testbed performanceProfile and SRIOV.
The main usage is to have them as a line-items in the job list. See jobs.config file.

```
export JOBS= \
    ./SETUP_GROUP/SRIOV/INSTALL \   <== install SRIOV
    ./3_GROUP/NO-PAO/SRIOV  \       <== run a SRIOV test
    ./SETUP_GROUP/PAO/INSTALL \
    ./3_GROUP/PAO/SRIOV  \          <== run a SRIOV+PAO test
```

##Prerequisite:
Regulus has been installed and configured (valid lab.config) on the bastion/jumphost.
Highly recommend to test the operation directly on the bastion/jumphost one-time to verify.
