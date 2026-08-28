#!/usr/bin/env bash

#Loader for orca on HPCForge

module load gcc/13.3.0
module load openmpi/4.1.8
module load orca/6.1.1

module list
which orca
which mpirun
orca
mpirun --version