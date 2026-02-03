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
1. Your Crucible controller has been setup and is working with your testbed in the standard way.
2. Passwordless ssh from crucible controller to the bastion host MUST be setup. Please verify "ssh kni-username@bastion-host" works.
3. Passworless on the bastion to itsself MUST be settup i.e ssh kni-username@bastion-host
4. For Regulus to initialize the testbed, among other things, it needs to learn the first worker node CPU topology. So, passwordless ssh from the bastion to the first worker node MUST be setup i.e from the bastion "ssh core@your-workernode-0" works.

## Set up Regulus on the crucible controller

### Step 1: Clone the repository

```bash
git clone https://github.com/HughNhan/regulus.git
cd regulus
```

This creates `~/regulus`.

### Step 2: Configure your lab (Easy Mode)

Regulus provides a **smart configuration tool** that automatically detects most of your lab settings. You only need to provide 3 basic values:

```bash
# Copy the template
cp lab.config.template lab.config

# Edit ONLY these 3 required values:
vi lab.config
```

**Minimum required configuration:**
```bash
export REG_KNI_USER=your-username      # Your username on the bastion host
export REG_OCPHOST="192.168.x.x"       # Bastion host IP address
export KUBECONFIG=/path/to/kubeconfig  # Path to your kubeconfig file
```

**That's it!** You can leave all the NIC and topology settings blank - the smart config tool will figure them out.

### Step 3: Bootstrap Regulus

```bash
# Set up environment variables
source ./bootstrap.sh
```

### Step 4: Initialize lab and auto-detect configuration

```bash
# Initialize lab infrastructure
make init-lab

# Auto-detect NICs and network topology
bash bin/reg-smart-config
```

The `reg-smart-config` tool will automatically:
- ✅ Detect worker nodes (OCP_WORKER_0, OCP_WORKER_1, OCP_WORKER_2)
- ✅ Identify available NICs and their models (CX6, CX7, E810, etc.)
- ✅ Find suitable NICs for SRIOV testing (REG_SRIOV_NIC, REG_SRIOV_NIC_MODEL)
- ✅ Find suitable NICs for MACVLAN testing (REG_MACVLAN_NIC)
- ✅ Find suitable NICs for DPDK testing (REG_DPDK_NIC)
- ✅ Determine MTU settings
- ✅ Identify the OVN-Kubernetes primary interface (to avoid conflicts)
- ✅ Detect bare-metal hosts if available (BMLHOSTA, BMLHOSTB)

**What the smart config looks for:**
- NICs that are **UP** (cable connected)
- NICs that have **no IP address** (not in use)
- NICs that are **not used by OVN-K** (avoids conflicts)
- NICs with **recognized models**: XXV710, X710, E810, CX5, CX6, CX7, BF3

After running `reg-smart-config`, check your `lab.config` - it should now be populated with all the discovered values.

### Step 5: Verify configuration

```bash
# Review the auto-detected configuration
cat lab.config | grep -E "WORKER|SRIOV|MACVLAN|DPDK|NIC_MODEL"
```

You should see something like:
```bash
export OCP_WORKER_0=worker-0.example.com
export OCP_WORKER_1=worker-1.example.com
export OCP_WORKER_2=worker-2.example.com
export REG_SRIOV_NIC=ens1f0np0
export REG_SRIOV_NIC_MODEL=CX6
export REG_MACVLAN_NIC=ens2f0
export REG_DPDK_NIC=ens3f0
export REG_SRIOV_MTU=9000
```

---

### Alternative: Manual Configuration (Advanced Users)

If you prefer to configure everything manually, or if the smart config doesn't detect your setup correctly, you can manually edit `lab.config`:

<details>
<summary>Click to expand manual configuration guide</summary>

#### Understanding Your Network Topology

Before manually configuring, you need to understand:

1. **OVN-K Primary Interface**: Which NIC is used by OpenShift's primary network
   ```bash
   # On a worker node
   oc debug node/worker-0
   chroot /host
   ip addr show | grep -A 5 br-ex
   ```

2. **Available NICs**: List all network interfaces
   ```bash
   # On a worker node
   oc debug node/worker-0
   chroot /host
   lspci | grep -i ethernet
   ip link show
   ```

3. **NIC Models**: Identify your hardware
   ```bash
   # Common models
   # Intel: XXV710, X710, E810
   # Mellanox/NVIDIA: CX5, CX6, CX7, BF3
   ethtool -i ens1f0 | grep driver
   ```

#### Manual lab.config Parameters

```bash
# Required: Basic connection
export REG_KNI_USER=your-username
export REG_OCPHOST="192.168.x.x"
export KUBECONFIG=/path/to/kubeconfig

# Worker nodes (can use IP or FQDN)
export OCP_WORKER_0=worker-0.example.com
export OCP_WORKER_1=worker-1.example.com
export OCP_WORKER_2=worker-2.example.com

# SRIOV Testing NIC
# - Must NOT be the OVN-K primary interface
# - Must be UP (cable connected)
# - Must have no IP address assigned
export REG_SRIOV_NIC=ens1f0np0          # NIC device name
export REG_SRIOV_NIC_MODEL=CX6          # Model: CX6, CX7, E810, etc.
export REG_SRIOV_MTU=9000               # MTU setting

# MACVLAN Testing NIC (different from SRIOV)
export REG_MACVLAN_NIC=ens2f0

# DPDK Testing NIC (different from SRIOV and MACVLAN)
# - Cannot have existing SRIOV VFs
# - Must be recognized model
export REG_DPDK_NIC=ens3f0

# Bare-metal hosts (optional, for certain tests)
export BMLHOSTA=bare-metal-1.example.com
export BMLHOSTB=bare-metal-2.example.com

# Other optional settings
export REG_DP=415                       # Deployment identifier
```

#### Rules for NIC Selection

**SRIOV NIC Requirements:**
- ✅ Different from OVN-K primary interface
- ✅ Interface is UP (link detected)
- ✅ No IP address assigned
- ✅ Supported model (CX6, CX7, E810, etc.)

**MACVLAN NIC Requirements:**
- ✅ Different from SRIOV NIC
- ✅ Interface is UP
- ✅ No IP address assigned

**DPDK NIC Requirements:**
- ✅ Different from SRIOV and MACVLAN NICs
- ✅ Interface is UP
- ✅ No IP address assigned
- ✅ No existing SRIOV VFs configured
- ✅ Recognized model

</details>

---

## Run a pilot test on a fresh Regulus workspace:
It recommends to run a pilot test to verify your Regulus set up. On the Crucible controller
 
1. Add a simple test case to ./jobs.config such as the ./1_GROUP/NO-PAO/4IP/INTER-NODE/TCP/2-POD test. You may want to shorten the test duration to 10 seconds and reduce number of sample to 1 to speed up the pilot test.
2. Initialize the job
```
make init-jobs
```
3. Run the job
```
make run-jobs
```
If everything is OK, the job will run to completion

4. See examine result sections
5. Clean the job
```
make clean-jobs
```

## Considerations
### Time. 
Most test cases take a few minutes, but an iperf3 drop-hunter run can take several hours to finish its binary search. So you should consider the values for test duration and number of samples set in the "jobs.config" file. For trial runs, pick low values for a quicker completion. For real runs, a longer duration and more samples will produce better average.


### A few testing scenarios
1. Run a job of one or more test cases

Add test cases to the JOBS variable your jobs.config.

    ```
	cd $REG_ROOT
	vi jobs.config
	make init-jobs
	make run-jobs
	make clean-jobs
    ```

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
    cd $REG_ROOT/1_GROUP/NO-PAO/4IP/INTER-NODE/TCP/16-POD
	make init
	make run 
	make clean
    ```

# Examine and Analyze Results

## Quick Results Check

In each test directory (e.g., `./1_GROUP/NO-PAO/4IP/INTER-NODE/TCP/16-POD`), you'll find:
- **latest/** - All run artifacts and raw results
- Individual result files from uperf, iperf3, etc.

## Generate Comprehensive Reports

Regulus includes powerful report generation and analysis tools in the `REPORT/` directory:

```bash
cd $REG_ROOT

# Generate a comprehensive report (JSON, HTML, CSV)
make summary

# View results in an interactive web dashboard
make report-dashboard
# Opens at http://localhost:5001

# Upload to ElasticSearch for trend analysis
make es-upload

# Query results via command line
cd REPORT/mcp_server
./build_and_run.sh search --model OVNK --nic BF3
./build_and_run.sh stats
```

### Report Capabilities

The REPORT/ directory provides a complete analysis pipeline:

1. **Automated Report Generation** (`build_report/`)
   - Discovers all test runs automatically
   - Extracts metrics from multiple tools (uperf, iperf3, etc.)
   - Generates JSON, HTML, and CSV reports
   - Validates data against schemas

2. **Interactive Dashboard** (`dashboard/`)
   - Load and compare multiple reports side-by-side
   - Filter by benchmark, model, NIC, topology
   - Visual performance analysis
   - Export filtered results

3. **ElasticSearch Integration** (`es_integration/`)
   - Store results in ElasticSearch/OpenSearch
   - Track performance trends over time
   - Compare results across different runs
   - Advanced querying and aggregations

4. **AI-Powered Queries** (`mcp_server/`)
   - Query results using natural language (Claude Desktop, Cline, etc.)
   - Supports any MCP-compatible client
   - Standalone CLI for direct access (no AI required)
   - Containerized for easy deployment

**For detailed documentation, see:** [README-report.md](./README-report.md)
	
# Configure PAO and SRIOV

Assuming you have pulled this repo on your crucible controller and have invoked "make init-lab" with success, you should config PAO and SRIOV at the appropriate time. See README in SRIOV-config and PAO-config for details

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
