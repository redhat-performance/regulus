#!/bin/bash
# 
# Usage : full_report.sh [-f]
#   -f : force to acquire testbed details again. Otherwise, reuse the exist info
#

pushd $REG_ROOT > /dev/null
set -e  # Exit on error
source ${REG_ROOT}/lab.config
source $REG_ROOT/bin/functions.sh

FORCE=0

while getopts "f" opt; do
    case "$opt" in
        f) FORCE=1 ;;
        *) echo "Usage: $0 [-f]"; exit 1 ;;
    esac
done

shift $((OPTIND -1))  # Shift past options

reg_dir="${PWD#"$HOME"/}"
DEST="$REG_KNI_USER@$REG_OCPHOST"
THISROOT=REPORT/upload

if [ "$FORCE" -eq 1 ] || [ ! -e "$THISROOT/tmp/testbed_section.json" ]; then
    if ! exec_ssh $DEST "cd $reg_dir && source lab.config && python3 $THISROOT/create_testbed_section.py  --lab-config $REG_ROOT/lab.config --ssh-key ~/.ssh/id_rsa  --lshw /usr/sbin/lshw  --json --output $THISROOT/testbed_section.json" ; then
        echo "exec_ssh failed" 
    fi

    mkdir -p $THISROOT/tmp >/dev/null 2>&1

    if ! scp $DEST:/$reg_dir/$THISROOT/testbed_section.json $THISROOT/tmp/; then
        echo "scp failed" 
    fi
fi

python3 $THISROOT/create_env_section.py $REG_ROOT/lab.config -o $THISROOT/tmp/lab_config.json
python3 $THISROOT/combine_sections.py -s custom $THISROOT/tmp/lab_config.json $THISROOT/tmp/testbed_section.json $REG_ROOT/report.json -k lab_info testbed_info results -o $THISROOT/tmp/all-output.json

popd > /dev/null

