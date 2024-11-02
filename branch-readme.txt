For RDS,
Precondition:
    1. Control plan reserveds a number of workers with label: worker-dpdk, worker-metalln
    2. Most worker nodes have 2 dual-port XXV710. Some worker nodes have and addition Cx-5
    3. ens2f1 (XXV710) is br-ex, 
    4. SRIOV has been installed by RDS
    5. performanceprofile named customcnf
    6. The worker nodes each havs 64 CPUs (32 core HT)
Adaptations
   1. Stay away form control plane workers. Use MATCH, MATCH_NOT to select different workers.
	In ./templates/common/worker_labels.config:
		MATCH, MATCH_NOT

   2. use the Cx-5 for DPDK
   3. Use ens2f0 (the XXV710 second port) for SRIOV multus net1
   4. Use SRIOV-config partial-config mode
	In ./SRIOV-config/config.env
 		SRIOV_NAD_ONLY=true
	In SRIOV-config/UNIV/templates/setting.env.template: export WOKER_LIST="${OCP_WORKER_0} ${OCP_WORKER_1} ${OCP_WORKER_2}"
	In lab.config  export OCP_WORKER_0=e23-h12-b03-fc640.rdu2.scalelab.redhat.com 

   5. Match MCP to performanceprofile name
	In ./SRIOV-config/config.env
		MCP=customcnf
   6. Multibench has to be reduced to 26 pairs instead of standard 32 pairs

Explanations:
1, WORKER_0,1,2 are defined in lab.config
2. WORKER_LIST={WORKER_0,WORKER_1,WORKER_2} is used to label nodes that will be SRIOV enabled. We manually pick this
   list b/c it has NIC type that matches SriovNetworkNodePolicy, and their ports are on the same subnets
3. MATCH and MATCH_NOT is used to filter workers that will be used for client/server pods
