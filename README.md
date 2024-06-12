This is the Regulus workspace, a repo that contains collections of Crucible test configurations, performance-profile config utility, and SRIOV config utility.

Testing is to be invoked on a Crucible controller ([info](https://docs.google.com/presentation/d/1--L-kxt4QTW78a1Foz6FpKThsvSx-GUZwha4FzwRwsE/edit#slide=id.g158c5ca952e_3_0)). PAO-config and SRIOV-config are to be launched on the bastion host.

# Intro
The primary goal of Regulus is to assit with building custom Crucible test suites and execute them easily.

Let's assume you would like to build a performance test suite for your target/product and run the suite reguarly to monitor performance trend.

The first complexity is the numerous test cases (INTER-NODE vs INTRA-NODE, UDP vs TCP, IPv4 vs. IPv6, block sizes, protocol stack i.e. OVN vs. Hostnetwork vs. SRIOV, performance profile etc.) that you may need - Each test case needs a set of recipe i.e run.sh, mv-params, annotation and resource files. It is easy to make typos when you tune the recipes. Regulus solves this problem by constructing the recipes programatically from templates, and hence eliminates typos.

The second complexity relates to the constructing and executing custom sets of test case. For example, for weekly, you would like to run set A, and for monthly you would like to run set B. Regulus "jobs" allows you to config two separate jobs.

With Regulus, the workflow is as follows
### One time activities (per target/product)
1. Build your test suite by choosing the existing and/or create new custom test cases.
2. State your custom test params IF you need to customize them.
3. State all your test cases in the test suite job list.
4. Let Regulus automatically construct the final recipes i.e  "make init"
### Periodic activity
5. Launch the job i.e "make run"

# Using Regulus Step-by-step

## Prerequisite
Your Crucible controller has been setup and is working with your testbed in the standard way.

## Set up Regulus on the bastion
 
1. First, clone the repo
```
    git clone https://github.com/HughNhan/regulus.git
```
2. Adapt the ./lab.config.template to match your lab>
```
cd ./regulus; cp lab.config.template lab.config; vi lab.config
```
This creates ~/regulus. Note. it is important that this path matches the Crucible controller setup.
3. set Regulus $REG_ROOT and a few other variables by sourcing the bootstrap file
```
source ./bootstrap.sh
```
3. Init lab params
```
make init-lab
```
3. Init SRIOV-config
```
cd $REG_ROOT/SRIOV-config/UNIV && make init
```
3. Init PAO-config
```
cd $REG_ROOT/PAO-config && make init
```
## Set up Regulus on the crucible controller
 
1. First, clone the repo
```
    git clone https://github.com/HughNhan/regulus.git
```
This creates ~/regulus and it must match the bastion side.
2. Adapt the ./lab.config.template to match your lab. This implies it is the exact copy of bastion's lab.config.
```
cd ./regulus; cp lab.config.template lab.config; vi lab.config
```

3. set Regulus $REG_ROOT and a few other variables by sourcing the bootstrap file
```
source ./bootstrap.sh
```
3. Init lab params
```
make init-lab
```

## Run a pilot test on a fresh Regulus workspace:
It recommends to run a pilot test to verify your Regulus set up. On the Cricible controller
 
1. Add a simple test case to ./jobs.config such as the ./1_GROUP/NO-PAO/4IP/INTER-NODE/TCP/2-POD test. You may want to shorten the test duration to 10 seconds and reduce number of sample to 1 to speed up the pilot test.
6. Initialize the job
```
make init-jobs
```
7. Run the job
```
make run-jobs
```
If everything is OK, the job will run to completion

8. See examine result sections
9. Clean the job
```
make clean-jobs
```

## Considerations
### Time. 
Most test cases take a few minutes, but an iperf3 drop-hunter run can take several hours to finish its binary search. So you should consider the values for test duration and number of samples set in the "jobs.config" file. For trial runs, pick low values for a quicker completion. For real runs, a longer duration and more samples will produce better average.


### A few testing scenarios
1. Run a job of one or more test cases e.g ./1_GROUP/NO-PAO/4IP/INTER-NODE/TCP/16-POD + ../2-POD etc.
Add test cases to your job.
    ```
    cd $REG_ROOT
    vi jobs.config
	make init-jobs
	make run-jobs
	make clean-jobs
    ``````

2. To run all test cases under Regulus. Warning it can take multi hours if not day.
	```
    cd $REG_ROOT
    make init-all
	make run-all
	make clean-all
    ```
3. Run a test case directly at its directory e.g ./1_GROUP/NO-PAO/4IP/INTER-NODE/TCP/16-POD. 
Sometime you may have a reason to run a test locally at its directory instead of setting up $REG_ROOT/jobs.config and run a job of one test. Regulus supports this usage.
	```
    cd ./1_GROUP/NO-PAO/4IP/INTER-NODE/TCP/16-POD
	make init
	make run 
	make clean
    ```

# Examine results
In each test dir e.g ./1_GROUP/NO-PAO/4IP/INTER-NODE/TCP/16-POD. you should find the results and all run artifects in latest dir.
	
# Configure PAO and SRIOV

Assuming you have pulled this repo on your bastion. You should config PAO and SRIOV at the appropriate time. See README in SRIOV-config and PAO-config for details

# Customizations
### ./lab.config
You describe your lab details in this file.
```
export REG_KNI_USER=hnhan
export REG_OCPHOST="192.168.94.11"
export OCP_WORKER_0=appworker-0.blueprint-cwl.<>.lab
export OCP_WORKER_1=appworker-1.blueprint-cwl.<>.lab
export OCP_WORKER_2=appworker-2.blueprint-cwl.<>.lab
export BMLHOSTA=
export BMLHOSTB=
export REG_DP=415
export REG_SRIOV_NIC=ens1f0np0
export REG_SRIOV_MTU=9000
export REG_SRIOV_NIC_MODEL=CX6
```
### ./jobs.config
You describe your job details in this file
```
export OCP_PROJECT=crucible-hnhan
export NODE_IP=
export IPSEC_EP=
export REMOTE_HOST_INTF=
export JOBS= ./1_GROUP/NO-PAO/4IP/INTER-NODE/TCP/2-POD 
export DRY_RUN=false
export TAG=NOK
export NUM_SAMPLES=1
export DURATION=10                                                                    
```
### ./reg_expand.sh 
You customize a test recepes in its reg_expand.sh file. For example, /home/kni/regulus/1_GROUP/NO-PAO/4IP/INTER-NODE/TCP/2-POD.reg_expand.h

```
export TPL_SCALE_UP_FACTOR=1
export TPL_TOPO=internode
export TPL_INTF=eth0
```
### templates
The reg_expand.sh files use templates to expand. If you need to add more templates they are found at:

```
cd  $REG_ROOT/regulus/templates
```


--- done ---
