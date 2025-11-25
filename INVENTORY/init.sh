#!/bin/bash
# Main function to collect the testbed inventory
#
set -e  # Exit on error
source ${REG_ROOT}/lab.config

./create-tb-json.sh
./create-labconfig-json.sh  
