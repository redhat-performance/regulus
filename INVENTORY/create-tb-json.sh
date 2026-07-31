#!/bin/bash
# 
# Get testbed info in json
# Usage : create-tb-json.sh  -o <outfile>
#
set -e  # Exit on error
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source $DIR/common
source $DIR/exec-remote-script.sh

# Default values
FORCE=0

_sub_path=${REG_ROOT#$HOME/}
if [[ "$_sub_path" != "$REG_ROOT" ]]; then
    _kni_home=$(ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR "${REG_KNI_USER}@${REG_OCPHOST}" "pwd")
    _remote_root="${_kni_home}/${_sub_path}"
else
    _remote_root="$REG_ROOT"
fi
REMOTE_OUTPUT_FILE="$_remote_root/INVENTORY/$GEN_DIR/$TBJSON"
OUTPUT_FILE="$REG_ROOT/INVENTORY/$GEN_DIR/$TBJSON"


# Parse options
while getopts "f:o:" opt; do
    case "$opt" in
        f) FORCE=1 ;;
        o) OUTPUT_FILE="$OPTARG" ;;
        *) echo "Usage: $0 [-f] [-o output_file]"; exit 1 ;;
    esac
done

shift $((OPTIND -1))  # Shift past options

# Get testbed info from the bastion
if ! exec-remote-script "source lab.config && cd INVENTORY &&  python3 create-tb-json.py \
        --kubeconfig \$KUBECONFIG \
        --lab-config $REG_ROOT/lab.config \
        --ssh-key ~/.ssh/id_rsa \
        --lshw /usr/sbin/lshw \
        --json \
        --output $REMOTE_OUTPUT_FILE"; then
        echo "exec_ssh failed"
        exit 1
fi


# Ensure directory exists
OUTDIR="$(dirname "$OUTPUT_FILE")"
mkdir -p "$OUTDIR"

DEST="$REG_KNI_USER@$REG_OCPHOST"
if ! scp -o UserKnownHostsFile=/dev/null \
         -o StrictHostKeyChecking=no \
         -o LogLevel=ERROR \
         "$DEST:$REMOTE_OUTPUT_FILE" "$OUTPUT_FILE"; then
    echo "create-tb-json.sh: scp failed"
    exit 1
fi

