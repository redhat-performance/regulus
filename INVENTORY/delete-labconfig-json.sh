#!/bin/bash
# 
# Delete lab.config in json
#
set -e  # Exit on error
source ${REG_ROOT}/lab.config
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source $DIR/common

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
echo "($LINENO) delete-labconfig-json.py  done"

