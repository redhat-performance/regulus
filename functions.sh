#!/bin/sh

# combine 2 crucible annotation json files  (w/o outer pair of {})
function combine_2_files {
    json1={$(cat $1)}
    json2={$(cat $2)}
    combined_json=$(echo "$json1 $json2" | jq -s '.[0] * .[1]')
    echo $combined_json  |  sed 's/^{\(.*\)}$/\1/'
}
function combine_3_files {
    json1={$(cat $1)}
    json2={$(cat $2)}
    json3={$(cat $3)}
    combined_json=$(echo "$json1 $json2 $json3" | jq -s '.[0] * .[1] * .[2]')
    echo $combined_json  |  sed 's/^{\(.*\)}$/\1/'
}

