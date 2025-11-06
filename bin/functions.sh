#!/bin/sh

# combine 2 crucible annotation json files  (w/o outer pair of {})
function combine_2_files {
    json1={$(cat $1)}
    json2={$(cat $2)}
    combined_json=$(echo "$json1 $json2" | jq -s '.[0] * .[1]')
    echo $combined_json  |  sed 's/^{\(.*\)}$/\1/'
}
function combine_3_files {
    json1={$(cat $1)}
    json2={$(cat $2)}
    json3={$(cat $3)}
    combined_json=$(echo "$json1 $json2 $json3" | jq -s '.[0] * .[1] * .[2]')
    echo $combined_json  |  sed 's/^{\(.*\)}$/\1/'
}


DBG=false
PRINT_DEBUG() {
    if $DBG; then
        local line=$1
        shift
        echo "($line): DEBUG $*"  >&2
    fi
}

PRINT_INFO() {
	local line=$1
    shift
    echo "($line) INFO: $*"  >&2
}

# In double/netsted usage, we need extra_SSH_OPTS
SSH_OPTS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=ERROR -o ConnectTimeout=20"
SSH_OPTS+="${extra_SSH_OPTS:-}"


function exit_err() {
    local msg
    msg="$1"
    echo "[ERROR] ${msg}" 1>&2
    exit 1
}

function exec_ssh() {
    local user_host user host
    user_host=$1; shift
    user=`echo $user_host | awk -F@ '{print $1}'`
    host=`echo $user_host | awk -F@ '{print $2}'`

    if [ -z "$user" ]; then
        exit_err "exec_ssh: user was blank: $user_host"
    fi
    if [ -z "$host" ]; then
        exit_err "exec_ssh: host was blank: $user_host"
    fi

    # Use here-document to send the script
    ssh $SSH_OPTS $user_host bash << EOFCMD
export KUBECONFIG='${KUBECONFIG}'
$*
EOFCMD
    return $?
}

