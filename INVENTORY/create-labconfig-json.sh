#!/bin/bash
# 
# Generate lab.config in json
#
set -e  # Exit on error
source ${REG_ROOT}/lab.config
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source $DIR/common

mkdir -p ${GEN_DIR}/ 
OUTPUT_FILE="$REG_ROOT/INVENTORY/$GEN_DIR/$LABJSON"

# Parse options
while getopts "f:o:" opt; do
    case "$opt" in
        f) FORCE=1 ;;
        o) OUTPUT_FILE="$OPTARG" ;;
        *) echo "Usage: $0 [-f] [-o output_file]"; exit 1 ;;
    esac
done

shift $((OPTIND -1))  # Shift past options

python3 $DIR/create-labconfig-json.py $REG_ROOT/lab.config -o $OUTPUT_FILE
echo "($LINENO) create-labconfig-json.py  done"

