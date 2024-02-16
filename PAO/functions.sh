#!/bin/bash

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

exec_over_ssh () {
    local nodename=$1
    local cmd=$2
    local ssh_options="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
    local ip_addr=$(oc get node ${nodename} -o json | jq -r '.status.addresses[0] | select(.type=="InternalIP") | .address')
    local ssh_output=$(ssh ${ssh_options} core@${ip_addr} "$cmd")
    echo "${ssh_output}"
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

# return True if either worker or my mcp is still updating.
get_mcp_progress_status () {
    if [[ "${SNO}" == "true" ]]; then
       local status=$(oc get mcp master -o json | jq -r '.status.conditions[] | select(.type == "Updated") | .status')
       echo ${status}
    else
       local worker_status=$(oc get mcp worker -o json | jq -r '.status.conditions[] | select(.type == "Updated") | .status')
       if oc get mcp ${MCP} &> /dev/null ; then
          # my mcp exists.
          local my_mcp_status=$(oc get mcp ${MCP} -o json | jq -r '.status.conditions[] | select(.type == "Updated") | .status')
       fi
       if [ "$worker_status" == "False" ]  || [ "$my_mcp_status" == "False" ]; then
          # still updating
          echo "True"
       else
          # All done updating
          echo "False"
       fi
    fi
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
    read answer
    if [ "$answer" != "${answer#[Yy]}" ] ;then
        echo Yes
    else
        echo No
        exit 1 
    fi
}

