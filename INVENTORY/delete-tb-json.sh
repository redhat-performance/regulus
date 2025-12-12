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

REMOTE_OUTPUT_DIR="$REG_ROOT/INVENTORY/$GEN_DIR"
OUTPUT_DIR="$REG_ROOT/INVENTORY/$GEN_DIR"


# Parse options
while getopts "f:o:" opt; do
    case "$opt" in
        f) FORCE=1 ;;
        o) OUTPUT_FILE="$OPTARG" ;;
        *) echo "Usage: $0 [-f] [-o output_file]"; exit 1 ;;
    esac
done

shift $((OPTIND -1))  # Shift past options

rm -fr $OUTPUT_DIR

# Get testbed info from the bastion
echo "exec-remote-script source lab.config && cd INVENTORY && rm -fr $REMOTE_OUTPUT_DIR"
if ! exec-remote-script "cd INVENTORY && pwd &&  rm -fr $REMOTE_OUTPUT_DIR"; then
    echo "exec_ssh failed"
    exit 1
fi

