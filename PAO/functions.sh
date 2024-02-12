
export SNO=${SNO:-false}
get_python_exec () {
    local py_exec
    if command -v python3 >/dev/null 2>&1; then
        py_exec=python3
    else
        for x in $(ls /usr/bin/python3); do
	    if command -v $x >/dev/null 2>&1; then
                py_exec=$x
                break
            else
               py_exec=""
            fi
        done
    fi
    if [[ -z "${py_exec}" ]]; then
        echo "command python and python3 not available!"
        exit 1
    fi
    echo ${py_exec}
}

bind_driver () {
    local driver=$1
    local pci=$2
    local original_path=$(realpath /sys/bus/pci/devices/${pci}/driver)
    local new_path=/sys/bus/pci/drivers/${driver}
    if [[ ! -e ${new_path}/${pci} ]]; then
        echo ${pci} > ${original_path}/unbind  || true
        echo ${driver} > /sys/bus/pci/devices/${pci}/driver_override  || true
        echo ${pci} > ${new_path}/bind  || true
        if [[ ! -e ${new_path}/${pci} ]]; then
            echo "failed to bind ${pci} to ${new_path}"
            exit 1 
        fi
    fi
}

get_ocp_channel () {
    local channel=$(oc get clusterversion -o json | jq -r '.items[0].spec.channel' | sed -r -n 's/.*-(.*)/\1/p')
    echo ${channel}
}

pause_mcp () {
    oc patch --type=merge --patch='{"spec":{"paused":true}}' machineconfigpool/${MCP}
}

resume_mcp () {
    oc patch --type=merge --patch='{"spec":{"paused":false}}' machineconfigpool/${MCP}
}

get_mcp_progress_status () {
    local this_mcp=$1
    if [[ "${SNO}" == "true" ]]; then
      local status=$(oc get mcp master -o json | jq -r '.status.conditions[] | select(.type == "Updating") | .status')
    else
      local status=$(oc get mcp $this_mcp -o json | jq -r '.status.conditions[] | select(.type == "Updating") | .status')
    fi
    echo ${status}
}

wait_mcp () {
    local this_mcp=$1
    resume_mcp
    printf "waiting 60 sec before checking mcp status "
    local count=60
    while [[ $count -gt 0  ]]; do
        sleep 10
        printf "."
        count=$((count-10))
    done

    local status=$(get_mcp_progress_status $this_mcp)
    count=300
    printf "\npolling 3000 sec for mcp complete, May lose API connection if SNO, during node reboot"
    while [[ $status != "False" ]]; do
        if ((count == 0)); then
            printf "\ntimeout waiting for mcp complete on the baremetal host!\n"
            exit 1
        fi
        count=$((count-1))
        printf "."
        sleep 10
        status=$(get_mcp_progress_status $this_mcp)
    done
    printf "\nmcp complete on the baremetal host in %d sec\n" $(( (300-count) * 10 ))
}

wait_pod_in_namespace () {
    local namespace=$1
    local count=100
    printf "waiting for pod in ${namespace}"
    while ! oc get pods -n ${namespace} 2>/dev/null | grep Running; do
        if ((count == 0)); then
            printf "\ntimeout waiting for pod in ${namespace}!\n" 
            exit 1
        fi
        count=$((count-1))
        printf "."
        sleep 5
    done
    printf "\npod in ${namespace}: up\n"
}

wait_named_pod_in_namespace () {
    local namespace=$1
    local podpattern=$2
    local count=100
    printf "waiting for pod ${podpattern} in ${namespace}"
    while ! oc get pods -n ${namespace} 2>/dev/null | grep ${podpattern} | grep Running; do
        if ((count == 0)); then
            printf "\ntimeout waiting for pod ${podpattern} in ${namespace}!\n"
            exit 1
        fi
        count=$((count-1))
        printf "."
        sleep 5
    done
    printf "\npod ${podpattern} in ${namespace}: up\n"
}

wait_named_deployement_in_namespace () {
    local namespace=$1
    local deployname=$2
    local count=100
    printf "waiting for deployment ${deployname} in ${namespace}"
    local status="False"
    while [[ "${status}" != "True" ]]; do
        if ((count == 0)); then
            printf "\ntimeout waiting for deployment ${deployname} in ${namespace}!\n"
            exit 1
        fi
        count=$((count-1))
        printf "."
        sleep 5
        status=$(oc get deploy ${deployname} -n ${namespace} -o json 2>/dev/null | jq -r '.status.conditions[] | select(.type=="Available") | .status' || echo "False")
    done
    printf "\ndeployment ${deployname} in ${namespace}: up\n"
}


exec_over_ssh () {
    local nodename=$1
    local cmd=$2
    local ssh_options="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
    local ip_addr=$(oc get node ${nodename} -o json | jq -r '.status.addresses[0] | select(.type=="InternalIP") | .address')
    local ssh_output=$(ssh ${ssh_options} core@${ip_addr} "$cmd")
    echo "${ssh_output}"
}

set_registry () {
    OPENSHIFT_SECRET_FILE=pull_secret.json
    oc get secret/pull-secret -n openshift-config --template='{{index .data ".dockerconfigjson" | base64decode}}' > ${OPENSHIFT_SECRET_FILE}
    oc registry login --skip-check --registry="${IMAGE_REPO}" --auth-basic="${REGISTRY_USER}:${REGISTRY_PASSWORD}" --to=${OPENSHIFT_SECRET_FILE}
    oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=${OPENSHIFT_SECRET_FILE}
    REGISTRY_CERT="domain.crt"
    if [[ ! -e ${REGISTRY_CERT} ]]; then
        echo "${REGISTRY_CERT} not present in current folder, downloading from REGISTRY_SSL_CERT_URL ..."
        curl -L -o ${REGISTRY_CERT} ${REGISTRY_SSL_CERT_URL}
    fi
    oc delete configmap registry-cas -n openshift-config 2>/dev/null || true
    oc create configmap registry-cas -n openshift-config --from-file=$(echo ${IMAGE_REPO} | sed s/:/../)=${REGISTRY_CERT}
    oc patch image.config.openshift.io/cluster --patch '{"spec":{"additionalTrustedCA":{"name":"registry-cas"}}}' --type=merge
}

parse_args() {
    USAGE="Usage: $0 [options]
Options:
    -n             Do not wait
    -h             This
"
    while getopts "hn" OPTION
    do
        case $OPTION in
            n) WAIT_MCP="false" ;;
            h) echo "$USAGE"; exit ;;
            *) echo "$USAGE"; exit 1;;
        esac
    done

    WAIT_MCP=${WAIT_MCP:-"true"}
}

another_get_mcp_progress_status () {
    if [[ "${SNO}" == "true" ]]; then
       status=$(oc get mcp | awk '/master-cnf/{if(match($2, /rendered-/)){print $4} else{print $3}}')
    else
       status=$(oc get mcp | awk '/${MCP}/{if(match($2, /rendered-/)){print $4} else{print $3}}')
    fi
    echo ${status}
}

function ver { 
   printf "%03d%03d%03d%03d" $(echo "$1" | tr '.' ' '); 
}

hn_echo() {
    echo $@
}
hn_exit() {
    echo "HN exit"
    exit
}

