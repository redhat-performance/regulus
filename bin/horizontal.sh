#!/bin/bash

# Script to convert new-summary* result lines that are vertical to horizontal lines.
# Usage:  horizontal.sh input_file
#    Or:  cat data.txt | ./horizontal.sh

input_file="${1:-/dev/stdin}"

# Process the input
awk '
BEGIN {
    section = ""
    values = ""
}

# Match section headers (lines starting with -- and ending with --)
/^--.*--$/ {
    # If we have a previous section, print it
    if (section != "") {
        print section ":" values
    }
    
    # Extract new section name (remove -- from both ends)
    section = $0
    gsub(/^--[ ]*/, "", section)
    gsub(/[ ]*--$/, "", section)
    values = ""
    next
}

# Skip empty lines
/^$/ {
    next
}

# Collect data values
{
    if (values == "") {
        values = " " $0
    } else {
        values = values " " $0
    }
}

# Print the last section
END {
    if (section != "") {
        print section ":" values
    }
}
' "$input_file"

