#!/bin/bash
# 
# find all directories with result-summary.txt and execute reg-gen-pps 
#

ALL=$(find . -maxdepth 8 -name result-summary.txt)

# we have results-summary.txt both places. Besure to ignore the one under the blob ./run/result-summary.txt
# ../blob/run/result-summary.txt
# ../blob/result-summary.txt

for result_blob in $ALL; do
    dir=$(dirname $result_blob)     # dir is either ../blob/run/ or ../blob/
    base_dir=$(basename $dir)       # base_dir is either: run or blob
    if [[ "$base_dir" == "run" ]]; then
        continue
    fi
    pushd $dir  </dev/null

   if [ ! -e ./run.sh ]; then
        # Skp this trashy blob.
        continue
   fi

    # extract the keywork in topo=<keyword>.    /^topo=/ to say the line has no other char before topo=
    topo=$(awk -F'topo=' '/^topo=/ {print $2}' run.sh | awk '{print $1}')
    echo topo=$topo

    if [ "$topo" == "ingress" ]; then
        # The log file tells LB or NP
        if grep -q  "lbSvc" ../$base_dir.log; then
            echo LB
            cp $REG_ROOT/templates/common/ingress-lb-pps.template  ../spec-pps.desc
            reg-gen-pps
        else
            echo NP
            cp $REG_ROOT/templates/common/ingress-np-pps.template  ..//spec-pps.desc
            reg-gen-pps
        fi
    else
        echo egress
        # The mv-params file tells EIP or egress
        if grep -q  "vlan46" mv-params.json; then
            echo EGRESS
            cp $REG_ROOT/templates/common/egress-pps.template  ../spec-pps.desc
            reg-gen-pps
        else
            echo EIP
            cp $REG_ROOT/templates/common/egress-eip-pps.template  ..//spec-pps.desc
            reg-gen-pps
        fi

    fi
    popd >/dev/null
done
