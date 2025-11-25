#!/bin/bash
#
# Support functions to get common tags for run.sh
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source $SCRIPT_DIR/common

tb-get-cpu-model() {
    local host=$1
    local cpu

    cpu=$(
        "$SCRIPT_DIR/lab_extractor.py" \
            --env "$SCRIPT_DIR/$GEN_DIR/$LABJSON" \
            --testbed "$SCRIPT_DIR/$GEN_DIR/$TBJSON" \
            --host "$host" \
            --json \
        | jq -r '.hardware.cpu["Model name"]'
    ) || return 1

    # If jq extracted nothing or null → treat as error
    [[ -z "$cpu" || "$cpu" == "null" ]] && return 1

    cpu="${cpu// /_}"
    echo "$cpu"
}


tb-get-nic-model() {
    local model
    model=$("$SCRIPT_DIR/lab_extractor.py" --env "$SCRIPT_DIR/$GEN_DIR/$LABJSON" --key "$1") || return 1
    # Replace spaces with underscores
    model="${model// /_}"
    echo "$model"
}


