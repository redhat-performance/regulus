#!/bin/sh

# This script is invoked by the flexran server. It launches the XRAN RU.
#   cd /opt/flexran && source sdk.env 
#   cd bin/nr5g/gnb/l1/orancfg/sub3_mu0_20mhz_4x4/oru
#   ./run_o_ru.sh
#
# Prerequisite:
#   1. Create 2 VFs 
#         echo 2 > /sys/class/net/${RU_ETH}/device/sriov_numvfs
#         ip link set dev ${RU_ETH} vf 0 vlan 10 mac 00:11:22:33:00:01 spoofchk off
#         ip link set dev ${RU_ETH} vf 1 vlan 20 mac 00:11:22:33:00:11 spoofchk off
#      This was done by 08-ru_sriov.sh
#   2. In /opt/flexran/bin/nr5g/gnb/l1/orancfg/sub3_mu0_20mhz_4x4/oru/run_o_ru.sh,
#         update PCI address of above VFs e.g  "--vf_addr_o_xu_a "0000:d8:0a.0,0000:d8:0a.1"
#      This was done by 08-ru_sriov.sh update_run_o_ru_file()
#
#   3. In /opt/flexran/bin/nr5g/gnb/l1/orancfg/sub3_mu0_20mhz_4x4/oru/usecase_ru.cfg,
#         update:
#            - ioCore       <=== alloc 1 core, value is coreID
#            - ioWorker     <=== alloc 2 cores, value is core_mask
#            - oXuRem0Mac0, oXuRem0Mac1: DU's VF mac address 
#      The first two are done in this module. For DU's VF MACs, we keep the canned addresses when we config the DU. 
#      Hence no fixes.
#   4. In /opt/flexran/bin/nr5g/gnb/l1/orancfg/sub3_mu0_20mhz_4x4/oru/config_file_o_ru.dat
#      update:
#           - duMac0, duMac1: DU's VF mac address
#      We use canned MAC adresses. No fixes.     
#

set -eu

source ./setting.env
source ./functions.sh

if [ -z "$1" ]; then
  FLEXRAN_RU_LOG=flexran_ru.log
else
  FLEXRAN_RU_LOG=$1
fi

if [[ ! -f ${ORU_DIR}/usecase_ru.cfg.orig ]]; then
    # Save orig file
    cp ${ORU_DIR}/usecase_ru.cfg  ${ORU_DIR}/usecase_ru.cfg.orig
fi

echo "updating cpu setting in ${ORU_DIR}/usecase_ru.cfg"

cpu_cache_dir=$(mktemp -d)

isolated_cpus=$(cat /proc/cmdline | sed -n -r 's/.* isolcpus=([0-9,\,\-]+).*/\1/p')
if [[ -z "${isolated_cpus}" ]]; then
    echo "no isolated_cpus on kernel cmdline, use default Cpus_allowed_list"
    egrep 'Cpus_allowed_list:' /proc/self/status > ${cpu_cache_dir}/procstatus
else
    echo "found isolated_cpus on kernel cmdline"
    echo "Cpus_allowed_list: ${isolated_cpus}" > ${cpu_cache_dir}/procstatus 
fi

# Alloc 1 core for ioCore 
PYTHON=$(get_python_exec)
core=$(${PYTHON} cpu_cmd.py --proc=${cpu_cache_dir}/procstatus --dir ${cpu_cache_dir} allocate-core)
sed -i -r "s/^(ioCore)=.*/\1=${core}/" ${ORU_DIR}/usecase_ru.cfg

# Alloc 2 cores for ioWorker 
cpumask=$(${PYTHON} cpu_cmd.py --proc=${cpu_cache_dir}/procstatus --dir ${cpu_cache_dir} allocate-cpu-mask 2)
sed -i -r "s/^(ioWorker)=.*/\1=${cpumask}/" ${ORU_DIR}/usecase_ru.cfg

echo "cpu setting updated"

/bin/rm -rf ${cpu_cache_dir}

echo "starting ru"

ls -lt ${ORU_DIR}
env
echo -e "$(pwd) run: cd ${FLEXRAN_ROOT}; source sdk.env; cd ${ORU_DIR}; bash ./run_o_ru.sh"
ru_cmd="cd ${FLEXRAN_ROOT}; source sdk.env; cd ${ORU_DIR}; bash ./run_o_ru.sh"

tmux kill-session -t ru 2>/dev/null || true
sleep 1
tmux new-session -s ru -d "${ru_cmd} 2>&1 | tee -a ${FLEXRAN_RU_LOG}"
sleep 1
if ! tmux ls | grep ru; then
    echo "failed to start ru"
    exit 1
else
    echo "ru started"
fi

