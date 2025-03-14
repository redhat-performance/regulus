get_ocp_channel () {
    local channel=$(oc get clusterversion -o json | jq -r '.items[0].spec.channel' | sed -r -n 's/.*-(.*)/\1/p')
    echo ${channel}
}

pause_mcp () {
    ECHO skip oc patch --type=merge --patch='{"spec":{"paused":true}}' machineconfigpool/${MCP}
}

resume_mcp () {
    ECHO resume_mcp skip: oc patch --type=merge --patch='{"spec":{"paused":false}}' machineconfigpool/${MCP}
}

# return True if either worker or my mcp is still updating.
get_mcp_progress_status () {
    local my_mcp_status=True
    local worker_status=$(oc get mcp worker -o json | jq -r '.status.conditions[] | select(.type == "Updated") | .status')
    if oc get mcp ${MCP} &> /dev/null ; then
        # my mcp exists.
        my_mcp_status=$(oc get mcp ${MCP} -o json | jq -r '.status.conditions[] | select(.type == "Updated") | .status')
    fi
    if [ "$worker_status" == "False" ]  || [ "$my_mcp_status" == "False" ]; then
        echo "True"
        # still updating
    else
        # All done updating
        echo "False"
    fi
}

wait_mcp () {
    resume_mcp
    printf "waiting 30 secs before checking mcp status "
    local count=30
    while [[ $count -gt 0  ]]; do
        sleep 10
        printf "."
        count=$((count-10))
    done

    local status=$(get_mcp_progress_status)
    count=300
    printf "\npolling 3000 sec for mcp complete"
    while [[ $status != "False" ]]; do
        if ((count == 0)); then
            printf "\ntimeout waiting for mcp complete on the baremetal host!\n"
            exit 1
        fi
        count=$((count-1))
        printf "."
        sleep 10
        status=$(get_mcp_progress_status)
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

    MCP=${MCP:-"worker-nas"}
    WAIT_MCP=${WAIT_MCP:-"true"}
    WORKERS=${WORKERS:-"none"}
    if [ ${WORKERS} == "none" ]; then 
        WORKERS=$(oc get node | grep worker | awk '{print $1}')
    fi
}


add_label_workers () {
    for worker in $WORKERS; do
        oc label --overwrite node ${worker} node-role.kubernetes.io/${MCP}=""
    done
}

remove_label_workers () {
    for worker in $WORKERS; do
        oc label --overwrite node ${worker} node-role.kubernetes.io/${MCP}-
    done
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

function prompt_continue {
    printf 'Continue next step (y/n)? '
    if [ "${SINGLE_STEP}" != "true" ]; then
        return
    fi
    read answer
    if [ "$answer" != "${answer#[Yy]}" ] ;then 
        echo Yes
    else
        echo No
        exit 1
    fi

}

function ECHO {
	echo ECHO: $@
}
