#!/bin/bash

if [ -z "$REG_ROOT" ]; then
	export REG_ROOT=$(pwd)
	export PATH=$PATH:/$REG_ROOT/bin
fi
