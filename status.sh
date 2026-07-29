#!/usr/bin/env bash

##############################################################################
#
# status.sh
#
# Display the currently loaded HPC software stack.
#
##############################################################################

set -euo pipefail

##############################################################################
# Ensure Lmod is available
##############################################################################

source /usr/share/lmod/lmod/init/bash >/dev/null 2>&1 || true

##############################################################################
# Header
##############################################################################

echo
echo "=============================================================="
echo "                HPC Software Stack Status"
echo "=============================================================="
echo

##############################################################################
# Loaded modules
##############################################################################

echo "Loaded Modules"
echo "--------------"

if module -t list 2>/dev/null | grep -q .; then
    module -t list 2>&1 | sed 's/^/  /'
else
    echo "  None"
fi

echo

##############################################################################
# Toolchain
##############################################################################

printf "%-15s %s\n" "Compiler:" "${CC:-Not set}"
printf "%-15s %s\n" "C++:"      "${CXX:-Not set}"
printf "%-15s %s\n" "Fortran:"  "${FC:-Not set}"
printf "%-15s %s\n" "MPI C:"    "${MPICC:-Not set}"
printf "%-15s %s\n" "MPI F:"    "${MPIFC:-Not set}"

echo

##############################################################################
# Executables
##############################################################################

echo "Executables"
echo "-----------"

for exe in \
    gcc g++ gfortran \
    mpicc mpicxx mpifort mpirun \
    pw.x ph.x bands.x dos.x projwfc.x pp.x
do

    if command -v "$exe" >/dev/null 2>&1; then
        printf "%-12s %s\n" "$exe" "$(command -v "$exe")"
    fi

done

echo

##############################################################################
# Library paths
##############################################################################

echo "Library Search Paths"
echo "--------------------"

echo "LD_LIBRARY_PATH"

if [ -n "${LD_LIBRARY_PATH:-}" ]; then
    echo "$LD_LIBRARY_PATH" | tr ':' '\n' | sed 's/^/  /'
else
    echo "  Not set"
fi

echo

echo "CPATH"

if [ -n "${CPATH:-}" ]; then
    echo "$CPATH" | tr ':' '\n' | sed 's/^/  /'
else
    echo "  Not set"
fi

echo

##############################################################################
# Module path
##############################################################################

echo "MODULEPATH"
echo "----------"

echo "$MODULEPATH" | tr ':' '\n' | sed 's/^/  /'

echo