#
# This function to be sourced by run.sh after source lab.config
#
# To support running regulus on the remote VM versus on the bastion, we need to cop with REG_ROOT difference.
#    i.e /root/sub-dir/regulus vs /home/kni/sub-dir/regulus
# Figure out the remote REG_ROOT and export REM_REG_ROOT at run time.
#
is_local() {
    local input="$1"
    local ip_to_check

    # Check if input is an IP address (IPv4)
    if [[ "$input" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        ip_to_check="$input"
    else
        # Attempt to resolve FQDN to IP address
        ip_to_check=$(getent hosts "$input" | awk '{ print $1 }')
        if [[ -z "$ip_to_check" ]]; then
            echo "Error: Could not resolve hostname to IP address."
            return 1
        fi
    fi

    # Check if resolved IP is found among local IPs
    if ip addr show | grep -wq "$ip_to_check"; then
        return 0  # True: IP is local
    else
        return 1  # False: IP is not local
    fi
}

if is_local "$REG_OCPHOST"; then
	REM_REG_ROOT=${REG_ROOT}
	#echo run local REM_REG_PATH=$REM_REG_ROOT
else
    SUB_PATH=${REG_ROOT#$HOME/}
    if [[ "$SUB_PATH" != "$REG_ROOT" ]]; then
        KNI_HOME=$(ssh "${REG_KNI_USER}@${REG_OCPHOST}" "pwd")
        if [[ -z "$KNI_HOME" ]]; then
            echo "ERROR: Failed to determine remote home directory for '$REG_KNI_USER' on $REG_OCPHOST" >&2
            exit 1
        fi
        REM_REG_ROOT=$KNI_HOME/$SUB_PATH
        if ! ssh "${REG_KNI_USER}@${REG_OCPHOST}" "test -d $REM_REG_ROOT"; then
            echo "ERROR: Remote user '$REG_KNI_USER' cannot access $REM_REG_ROOT on $REG_OCPHOST" >&2
            exit 1
        fi
    else
        REM_REG_ROOT=$REG_ROOT
        if ! ssh "${REG_KNI_USER}@${REG_OCPHOST}" "test -d $REM_REG_ROOT"; then
            echo "ERROR: Remote user '$REG_KNI_USER' cannot access $REM_REG_ROOT on $REG_OCPHOST" >&2
            exit 1
        fi
    fi
fi

# env to support when running on the bastion vs crucible VM
export REM_REG_ROOT
