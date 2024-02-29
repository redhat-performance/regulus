This is the Regulus workspace, a repo that contains collections of crucible test configurations, performance-profile config utility, and SRIOV config utility.

Testing is to be invoked on a Crucible controller. PAO-config and SRIOV-config are to be launced on the bastion host.

# Intro
The primary goal of Regulus is to assit with building custom Crucible test suites and execute them easily.

Let's assume you would like to build a performance test suite for your target/product and run the suite reguarly to monitor performance trend.

The first complexity is the numerous test cases (INTER-NODE vs INTRA-NODE, UDP vs TCP, IPv4 vs. IPv6, block sizes, protocol stack i.e. OVN vs. Hostnetwork vs. SRIOV, performance profile etc.) that you may need - Each test case needs a set of recipe i.e run.sh, mv-params, annotations and resources specifications. It is easy to make typos when you tune the recepes. Regulus solves this problem by constructing the recepes programatically from templates, and hence eliminates typos.

The second complexity relates to the constructing and executing custom set of test cases. For example for weekly, you would like to run set A, and for montly you would like to run set B. Regulus "jobs" allows you to config two separate lists.

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

## Run a pilot test on a fresh Regulus workspace:
It recommends to run a pilot test to verify your Regulus set up.
 
1. > First, clone the repo
    <p>git clone https://github.com/HughNhan/regulus.git</p>
2. > Adapt the ./lab.config.template to match your lab>
    <p> cd ./regulus; cp lab.config.template lab.config; vi lab.config </p>

3. > set Regulus $REG_ROOT and a few other variables by sourcing the bootstrap file
    <p>source ./bootstrap.sh</p>
4. > set up a simple job with one simple test.
    <p> cp job.config.tempate job.config; vi job.config </p> Add a simple test case to ./jobs.config such as the "./1_GROUP/NO-PAO/4IP/INTER-NODE/TCP/2-POD" test. You may want to shorten the test duration to 10 seconds and reduce number of sample to 1 to speed up the pilot test.
5. > Initialize the testbed
    <p> make init-lab </p>
6. > Initialize the job
    <p> make init-jobs
7. > Run the job
    <p> make run-jobs </p>. If lab.config is OK, the job will run to completion.
5. > See examine result sections
5. > Clean the job
    <p>make clean-jobs </p>

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
export REG_KNI_USER=kni
export REG_OCPHOST=<your-bastion-fqdn>
export OCP_WORKER_0=worker000-r650
export OCP_WORKER_1=worker001-r650
export OCP_WORKER_2=worker002-r650
export REG_SRIOV_NIC=ens2f0np0
export REG_SRIOV_MTU=9000
export REG_SRIOV_NIC_MODEL=CX6
```
### ./jobs.config
You describe your job details in this file
```
export OCP_PROJECT=<your OCP/k8s project>    
export JOBS= ./1_GROUP/NO-PAO/4IP/INTER-NODE/TCP/2-POD 
export NUM_SAMPLES=3
export DURATION=120                                                  
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
