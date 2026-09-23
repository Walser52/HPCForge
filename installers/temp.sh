#!/usr/bin/env bash

GPU=true   

set_COMPILER_nvhpc_gcc(){

local gpu_flag="$1"

if $gpu_flag; then

    COMPILER="nvhpc"

else

    COMPILER="gcc"

fi
}

set_COMPILER_nvhpc_gcc $GPU

echo $COMPILER