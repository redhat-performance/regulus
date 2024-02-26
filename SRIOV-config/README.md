The SRIOV-config/UNIV and PAO-config directories contain scripts and config templates to install SRIOV and PerformanceProfile.

# Install SRIOV
1. > Clone this repo on your cluster
    <p>git clone https://github.com/HughNhan/regulus.git</p>
2. > Change to ./regulus
    <p> cd regulus </p>
3. > edit/vi to adapt lab.config accordingly. To set "REG_SRIOV_NIC=<you-nic>", you ought to know your testbed to select this NIC.
4. > set the ROOT VAR of regulus
    <p> source  bootstrap.sh</p>
5. > learn the cluster i.e cluster type, worker node num_cpus
    <p> make init-lab</p> 
6. > initialize install params
    <p>cd SRIOV-config/UNIV
    <p> make init </p> 
8. Install SRIOV. The install process may take 15 minutes+
    <p> make install </p>

If the installation fails because the variables in lab.config are  incorrect, you need to repeat steps 3-8.

# Remove SRIOV
> Remove SRIOV
1. <p>make cleanup</p> 

# Install PAO
If you have installed SRIOV on this shell, you can keep step 1-4. Otherwise.
1. > Clone this repo on your cluster
    <p>git clone https://github.com/HughNhan/regulus.git</p>
2. > Change to ./regulus
    <p> cd regulus </p>
3. > edit/vi to adapt lab.config accordingly. To set "REG_SRIOV_NIC=<you-nic>", you ought to know your testbed to select this NIC.
4. > set the ROOT VAR of regulus
    <p> source  bootstrap.sh</p>
5. > learn the cluster i.e cluster type, worker node num_cpus
    <p> make init-lab</p> 
6. > initialize install params
    <p>cd PAO-config
    <p> make init </p> 
8. Install PAO. The install process may take a few minutes+
    <p> make install </p>

# Remove PAO
<p>make cleanup</p>



# Considerations:
The SRIOV-config and PAO-config are OCP configuration tools. They must be invoked on the bastion when applicable.

Most likely you only want to intall SRIOV for the SRIOV test cases, and similarly to install PAO for the PAO-enabled test cases.

Note the top level of Regulus workspace can invoke "run-job" or "run-all". Therefore you want to craft several jobs.
1. A job contains all testcases that are not SRIOV nor PAO.
1. A job contains all SRIOV test cases
1. A job contains all PAO-enable test cases
1. A job contain all SRIOV with PAO-enabled test cases.

Then you run job number #1. Install SRIOV. Run job #2. Remove SRIOV,and install PAO. Run job #3. Install SRIOV. Run job #4.

Note that you could install both SRIOV and PAO then run-all. However  you need to confirm if the results are what you want since all tests run in the present of SRIOV and PAO-enabled.

Note a SRIOV install or remove operation can take more than 15 minutes. It is that reason that we decide to leave them outside the tests, and let the user organizes the jobs as mentioned above.

