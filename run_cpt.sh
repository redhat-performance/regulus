#/bin/bash
#
# Main script to support Prow env, called by:  Prow -> bastion -> True bastion -> this-script
# after Crucible and Regulus have been installed.
#
# See release/ci-operator/step-registry/openshift-qe/installer/bm/day2/regulus
# for the description of bastion vs true bastion.
#
source bootstrap.sh
source lab.config

# If we run in the double/nested ssh scenario, the destination env context may not have 
# ssh-agent available and thus no key. In this case we must use explicit key. "ssh -i <key> ...."
if ssh-add -l >/dev/null 2>&1; then
    echo 'SSH agent available, using agent'
    export extra_SSH_OPTS=""
else
    echo 'No SSH agent, using private_key'
    if [ -e /tmp/private_key  ]; then
        export extra_SSH_OPTS=" -i /tmp/private_key"  
    fi
fi

function do_ssh_copy_id() {
    # Script to ssh-copy-id with password
    # Usage: do_ssh_copy_id <host_ip> <password> [username]

    if [ $# -lt 2 ] || [ $# -gt 3 ]; then
        echo "Usage: do_ssh_copy_id <host_ip> <password> [username]"
        echo "Example: do_ssh_copy_id 192.168.1.100 mypassword"
        echo "Example: do_ssh_copy_id 192.168.1.100 mypassword kni"
        return 1 
    fi

    HOST_IP="$1"
    PASSWORD="$2"
    USERNAME="${3:-root}"  # Default to root if username not provided

    # Check if expect is installed
    if ! command -v expect &> /dev/null; then
        echo "Warning: 'expect' is not installed. Install it"
        yum install expect -y
    fi

    echo "Copying SSH key to ${USERNAME}@${HOST_IP}..."

    # Use expect to automate password entry
    expect << EOF
spawn ssh-copy-id ${USERNAME}@${HOST_IP}
expect "*'s password:"
send "${PASSWORD}\r"
expect eof
EOF

    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        echo "✓ SSH key copy completed for ${USERNAME}@${HOST_IP}"
        return 0
    else
        echo "✗ SSH key copy failed for ${USERNAME}@${HOST_IP}"
        return 1
    fi
}

# We are on the true bastion, Set it up so that it can ssh to itself.
if ! ssh -o ConnectTimeout=5 -o BatchMode=yes $REG_KNI_USER@$REG_OCPHOST "pwd" 2>/dev/null; then
    echo "SSH key authentication failed, copying SSH key..."
    echo CMD: do_ssh_copy_id "$REG_OCPHOST" "100yard-" "$REG_KNI_USER"
    do_ssh_copy_id "$REG_OCPHOST" "100yard-" "$REG_KNI_USER"
fi

#### Now do the Regulus work.
./bin/reg-smart-config || { echo "reg-smart-config failed"; exit 1; }
source bootstrap.sh || { echo "bootstrap.sh failed"; exit 1; }
source lab.config || { echo "lab.config failed"; exit 1; }
make init-lab || { echo "make init-lab failed"; exit 1; }
pushd templates/uperf/TEST || { echo "pushd failed"; exit 1; }
bash setmode one || { echo "setmode failed"; exit 1; }
popd || { echo "popd failed"; exit 1; }
make init-jobs || { echo "make init-jobs failed"; exit 1; }
make jobs || { echo "make jobs failed"; exit 1; }
make summary || { echo "make summary failed"; exit 1; }

#EOF
