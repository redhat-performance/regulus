#!/bin/bash
# A convenient script to rearrange the job list for all test cases in an
# order that minimize the numberof SRIOV and PAO install/cleanup ops.
# The order is as follows:
#    1. NO-PAO_no_SRIOV, 
#    2. NO-PAO_with_SRIOV, 
#    3. PAO_no_SRIOV, 
#    4. PAO_with_SRIOV

# Function to filter and sort tokens
filter_and_sort() {
    # filter token with "keyword"
    keyword="$1"
    token_list="$2"
    filtered=$(printf "%s\n" "${token_list[@]}" | grep "$keyword" | sort)
    echo "$filtered"
    echo
}

filter_not_and_sort() {
    # filter token without "keyword"
    keyword="$1"
    token_list="$2"
    filtered=$(printf "%s\n" "${token_list[@]}" | grep -v "$keyword" | sort)
    echo "$filtered"
    echo
}

format_print() {
    # add tab in front and line continuation "\" at the end of each token.
    local orig="$1"
    local formatted_string=$(printf "%s\n" "$orig" | sed 's/\([^ ]*\)/\t\1\\/')
    printf "%s\n" "$formatted_string"
}

basenames=$(find . -name reg_expand.sh -exec dirname {} \;)

# Filter and sort for each keyword
no_pao_list=$(filter_and_sort "/NO-PAO" "$basenames")
no_pao_with_sriov_list=$(filter_and_sort "SRIOV" "$no_pao_list")
no_pao_no_sriov_list=$(filter_not_and_sort "SRIOV" "$no_pao_list")
#
pao_list=$(filter_and_sort "/PAO" "$basenames")
pao_with_sriov_list=$(filter_and_sort "SRIOV" "$pao_list")
pao_no_sriov_list=$(filter_not_and_sort "SRIOV" "$pao_list")

# Create a list contains:  NO-PAO_no_SRIOV, SRIOV_install_op, NO-PAO_with_SRIOV, SRIOV_cleanup_op, 
#                          PAO_install_op,  PAO_no_SRIOV, SRIOV_install_op, PAO_with_SRIOV
format_print "$no_pao_no_sriov_list"
format_print ""
format_print "./SETUP_GROUP/SRIOV/INSTALL"
format_print ""
format_print "$no_pao_with_sriov_list"
format_print ""
format_print  "./SETUP_GROUP/SRIOV/CLEANUP"
format_print  "./SETUP_GROUP/PAO/INSTALL"
format_print ""
format_print "$pao_no_sriov_list"
format_print ""
format_print "./SETUP_GROUP/SRIOV/INSTALL"
format_print "$pao_with_sriov_list"
format_print ""
format_print  "./SETUP_GROUP/SRIOV/CLEANUP"
format_print  "./SETUP_GROUP/PAO/CLEANUP"

# You should capture the output of this script and paste to jobs.config "JOBS=" variable
# EOF
