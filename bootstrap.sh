#!/bin/bash

#if [ -z "$REG_ROOT" ]; then
    export REG_ROOT=$(pwd)
    export REG_DIR="${PWD#"$HOME"/}" 
    unset PATH
    # Set the PATH variable to the default value
    export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    source ~/.bashrc
    export PATH=$PATH:$REG_ROOT/bin
    source ${REG_ROOT}/system.config
#fi

if [ !  -x "$(command -v reg-run)" ]; then
    echo please unset REG_ROOT and source bootstrap.sh again.
fi
