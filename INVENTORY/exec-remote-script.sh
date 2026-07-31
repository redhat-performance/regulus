#!/bin/bash
# exec-remote-script - Execute commands on remote hos  - For sourcing into main script
# Usage: exec-remote-script "cmd1 && cmd2 ...."

exec-remote-script() {
    source $REG_ROOT/lab.config

    #DEST="$REG_KNI_USER@$REG_OCPHOST"
    #scp -r $REG_ROOT/INVENTORY       $DEST:$REG_ROOT/  > /dev/null
    #scp -r $REG_ROOT/REPORT/upload   $DEST:$REG_ROOT/REPORT  > /dev/null

    # Configuration - adjust these or set via environment
    local REMOTE_HOST="${REG_OCPHOST}"
    local REMOTE_USER="${REG_KNI_USER}"
    local LOCAL_ROOT="${LOCAL_ROOT:-$REG_ROOT}"
    local _sub_path=${REG_ROOT#$HOME/}
    local _remote_root
    if [[ "$_sub_path" != "$REG_ROOT" ]]; then
        local _kni_home
        _kni_home=$(ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR "${REMOTE_USER}@${REMOTE_HOST}" "pwd")
        _remote_root=${_kni_home}/${_sub_path}
    else
        _remote_root=$REG_ROOT
    fi
    local REMOTE_ROOT="${REMOTE_ROOT:-${_remote_root}}"

    # Get the script path or command
    local INPUT="$1"
    shift  # Remaining args are passed to the script

    if [[ -z "$INPUT" ]]; then
        echo "Usage: exec-remote-script <script-path|command> [args...]" >&2
        echo "Examples:" >&2
        echo "  exec-remote-script ./script.sh arg1 arg2" >&2
        echo "  exec-remote-script 'source bootstrap.sh && ./script.sh'" >&2
        return 1
    fi

    # Check if it's a command string (contains &&, ||, ;, or |)
    if [[ "$INPUT" =~ (&&|\|\||;|\|) ]]; then
        # It's a command string - do path translation and execute
        local REMOTE_COMMAND
        if [[ -n "$LOCAL_ROOT" ]] && [[ -n "$REMOTE_ROOT" ]] && [[ "$LOCAL_ROOT" != "$REMOTE_ROOT" ]]; then
            REMOTE_COMMAND="${INPUT//$LOCAL_ROOT/$REMOTE_ROOT}"
        else
            REMOTE_COMMAND="$INPUT"
        fi
        
        echo "Local:  $INPUT" >&2
        echo "Remote: cd $REMOTE_ROOT && $REMOTE_COMMAND on $REMOTE_USER@$REMOTE_HOST" >&2
        
        ssh -o UserKnownHostsFile=/dev/null \
            -o StrictHostKeyChecking=no \
            -o LogLevel=ERROR \
            -o ConnectTimeout=20 \
            "${REMOTE_USER}@${REMOTE_HOST}" \
            "bash -c 'cd $REMOTE_ROOT && $REMOTE_COMMAND'"
    else
        # It's a single script - convert to absolute path
        local SCRIPT_PATH="$INPUT"
        
        if [[ "$SCRIPT_PATH" != /* ]]; then
            # Get absolute path
            SCRIPT_PATH="$(realpath "$SCRIPT_PATH" 2>/dev/null || readlink -f "$SCRIPT_PATH")"
        fi
        
        # Determine remote path
        local REMOTE_PATH
        if [[ -n "$LOCAL_ROOT" ]] && [[ -n "$REMOTE_ROOT" ]]; then
            REMOTE_PATH="${SCRIPT_PATH/$LOCAL_ROOT/$REMOTE_ROOT}"
        else
            REMOTE_PATH="$SCRIPT_PATH"
        fi
        
        echo "Local:  $SCRIPT_PATH" >&2
        echo "Remote: $REMOTE_PATH on $REMOTE_USER@$REMOTE_HOST" >&2
        
        ssh -o UserKnownHostsFile=/dev/null \
            -o StrictHostKeyChecking=no \
            -o LogLevel=ERROR \
            -o ConnectTimeout=20 \
            "${REMOTE_USER}@${REMOTE_HOST}" \
            bash "$REMOTE_PATH" "$@"
    fi
}

