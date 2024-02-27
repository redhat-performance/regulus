This is the Regulus workspace, a repo that contains collections of crucible test configurations (./1_GROUP, ./2_GROUP and ./3_GROUP), performance-profile config util (./PAO-config), and SRIOV config util (./SRIOV-config)

The tests are to be invoked on a Crucible controller. Meanwhile, the PAO-config and SRIOV-config are to be launced on the bastion.

# Assumption 

Your Crucible controller has been setup and is working with your testbed in the standard way.


# Run a pilot test on a fresh Regulus workspace:
It recommends to run a pilot test to verify your Regulus set up.
 
1. > First, clone the repo
    <p>git clone https://github.com/HughNhan/regulus.git</p>
2. > Adapt the ./lab.config to match your lab
    <p> cd ./regulus && vi lab.config </p>

3. > set REGULUS ROOT variables by sourcing the bootstrap file
    <p>source ./bootstrap.sh</p>
4. > set up a simple job.
    <p> vi job.config </p> Add a simple test case to ./jobs.config such as the "./1_GROUP/NO-PAO/4IP/INTER-NODE/TCP/2-POD" test. You may want to shorten the test duration to 10 seconds and reduce number of sample to 1 to speed up the pilot test.
5. > Initialize the testbed
    <p> make init-lab </p>
6. > Initialize the job
    <p> make init-jobs
7. > Run the job
    <p> make run-jobs </p>. If lab.config is OK, the job will run to completion.
5. > See examine result sections
5. > Clean the job
    <p>make clean-jobs </p>

# Considerations
	1. Time. Most test case take a few minutes, but an iperf3 drop-hunter job can take several hours to finish its binary search. So you need consider the test duration and number of sample variables in the jobs.config.


# A few testing scenarios
1. Run one test case job e.g ./1_GROUP/NO-PAO/4IP/INTER-NODE/TCP/16-POD in debug mode
	```
    cd ./1_GROUP/NO-PAO/4IP/INTER-NODE/TCP/16-POD
	make init
	make run 
	make clean
    ```

2. Run several test cases job e.g ./1_GROUP/NO-PAO/4IP/INTER-NODE/TCP/16-POD+2-POD ...  etc in job mode.
    ```
    vi jobs.config # add test cases to your job
	make init-jobs
	make run-jobs
	make clean-jobs
    ``````

2. To run all test cases under Regulus. Warning it can take multi hours if not day.
	```
    make init-all
	make run-all
	make clean-all
    ```

# Examine results

	In each test dir e.g ./1_GROUP/NO-PAO/4IP/INTER-NODE/TCP/16-POD.
	you should find the results and all run artifects in latest dir.
	
# Configure PAO and SRIOV

Assuming you have pulled this repo on your bastion. You should config PAO and SRIOV at the appropriate time. See README in SRIOV-config and PAO-config for details


# Customization:
You can changes many things in. See
./lab.config
./jobs.config
./templates/...

-- done ---
