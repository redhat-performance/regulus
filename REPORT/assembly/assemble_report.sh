#!/bin/bash
# 
# Usage : assemble_report.sh [-f]
#   -f : force to acquire testbed details again. Otherwise, reuse the exist info
#

set -e  # Exit on error
source ${REG_ROOT}/lab.config
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#reg_dir="${PWD#"$HOME"/}"
#scp -r $REG_ROOT/INVENTORY        root@$REG_OCPHOST:/$reg_dir         > /dev/null
#scp -r $REG_ROOT/REPORT/upload    root@$REG_OCPHOST:/$reg_dir/REPORT  > /dev/null
#scp -r $REG_ROOT/makefile          root@$REG_OCPHOST:/$reg_dir/makefile  > /dev/null

FORCE=0

while getopts "f" opt; do
    case "$opt" in
        f) FORCE=1 ;;
        *) echo "Usage: $0 [-f]"; exit 1 ;;
    esac
done

shift $((OPTIND -1))  # Shift past options

INVENTORY=$REG_ROOT/INVENTORY
TBJSON=$INVENTORY/generated/gen-tb-config.json
LABJSON=$INVENTORY/generated/gen-lab-config.json

if [ "$FORCE" -eq 1 ] || [ ! -e "$TBJSON" ]; then
    bash $INVENTORY/create-tb-json.sh -o $TBJSON
fi


if [ "$FORCE" -eq 1 ] || [ ! -e "$LABJSON" ]; then
    bash  $INVENTORY/create-labconfig-json.sh $LABJSON
fi

REPORT_JSON=$REG_ROOT/REPORT/generated/report.json
TESTBED_REPORT_JSON=$REG_ROOT/REPORT/generated/report-with-testbed-info.json

# Combine report.json with testbed/lab info
python3 $DIR/combine_sections.py -s custom $TBJSON $LABJSON $REPORT_JSON -k lab_info testbed_info results -o $TESTBED_REPORT_JSON

# Backup report.json to avoid duplicate loading in dashboard
# The testbed-info version is newer and contains all the same data plus additional metadata
if [ -f "$REPORT_JSON" ]; then
    echo "Backing up $REPORT_JSON to $REPORT_JSON.bak"
    mv -f "$REPORT_JSON" "$REPORT_JSON.bak"
fi


