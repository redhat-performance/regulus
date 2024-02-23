#!/bin/bash

if [ -z "$REG_ROOT" ]; then
	export REG_ROOT=$(pwd)
	export PATH=$PATH:/$REG_ROOT/bin
	source ${REG_ROOT}/system.config
fi

if [ !  -x "$(command -v reg-run)" ]; then
	echo please unset REG_ROOT and source bootstrap.sh again.
fi
