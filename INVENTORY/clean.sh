#!/bin/bash
# Main function to clear the testbed inventory
#
set -e  # Exit on error
source ${REG_ROOT}/lab.config

./delete-tb-json.sh
./delete-labconfig-json.sh  
