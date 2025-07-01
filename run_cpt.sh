#/bin/bash
#
# Main script called by Prow after Crucible and Regulus have been installed.
#
#

source bootstrap.sh
source lab.config

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

# This process needs ssh to the bastion (could be itself)
if ! ssh -o ConnectTimeout=5 -o BatchMode=yes $REG_KNI_USER@$REG_OCPHOST "pwd" 2>/dev/null; then
    echo "SSH key authentication failed, copying SSH key..."
    echo CMD: do_ssh_copy_id "$REG_OCPHOST" "100yard-" "$REG_KNI_USER"
    do_ssh_copy_id "$REG_OCPHOST" "100yard-" "$REG_KNI_USER"
fi

#### do some real work
./bin/reg-smart-config      # Fix lab.config. Prow unlikely to have created a perfect lab.config
source bootstrap.sh         # Pick up the updated lab.config
source lab.config
make init-lab
pushd templates/uperf/TEST
bash setmode one            # Make Prow Regulus job super short for now.
popd
make init-jobs
make jobs

