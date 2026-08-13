#!/usr/bin/env bash

set -euo pipefail

###############################################################################
# Configuration
###############################################################################

ROOT="$HOME"
PREFIX="$ROOT/apps"

GCC_VER="13.2.0"
MPI_VER="5.0.3"
FFTW_VER="3.3.10"
SCALAPACK_VER="2.2.0"
QE_VER="7.4"

###############################################################################
# Directory layout
###############################################################################

mkdir -p "$PREFIX"

cd "$PREFIX"

# Software installation directories
mkdir -p \
    gcc/$GCC_VER \
    openmpi/$MPI_VER \
    fftw/$FFTW_VER \
    scalapack/$SCALAPACK_VER \
    qe/$QE_VER

# Module directories
mkdir -p \
    modulefiles/gcc \
    modulefiles/openmpi \
    modulefiles/fftw \
    modulefiles/scalapack \
    modulefiles/qe

###############################################################################
# GCC module
###############################################################################

cat > modulefiles/gcc/$GCC_VER.lua <<EOF
help([[
GCC $GCC_VER
]])

whatis("GNU Compiler Collection $GCC_VER")

family("compiler")

local root="$PREFIX/gcc/$GCC_VER"

prepend_path("PATH", pathJoin(root,"bin"))
prepend_path("LD_LIBRARY_PATH", pathJoin(root,"lib64"))

setenv("CC","gcc")
setenv("CXX","g++")
setenv("FC","gfortran")
EOF

###############################################################################
# OpenMPI module
###############################################################################

cat > modulefiles/openmpi/$MPI_VER.lua <<EOF
help([[
OpenMPI $MPI_VER
]])

depends_on("gcc/$GCC_VER")

family("mpi")

local root="$PREFIX/openmpi/$MPI_VER"

prepend_path("PATH", pathJoin(root,"bin"))
prepend_path("LD_LIBRARY_PATH", pathJoin(root,"lib"))
EOF

###############################################################################
# FFTW module
###############################################################################

cat > modulefiles/fftw/$FFTW_VER.lua <<EOF
depends_on("gcc/$GCC_VER")

local root="$PREFIX/fftw/$FFTW_VER"

prepend_path("PATH", pathJoin(root,"bin"))
prepend_path("LD_LIBRARY_PATH", pathJoin(root,"lib"))
prepend_path("PKG_CONFIG_PATH", pathJoin(root,"lib/pkgconfig"))
EOF

###############################################################################
# ScaLAPACK module
###############################################################################

cat > modulefiles/scalapack/$SCALAPACK_VER.lua <<EOF
depends_on("openmpi/$MPI_VER")

local root="$PREFIX/scalapack/$SCALAPACK_VER"

prepend_path("LD_LIBRARY_PATH", pathJoin(root,"lib"))
EOF

###############################################################################
# Quantum ESPRESSO module
###############################################################################

cat > modulefiles/qe/$QE_VER.lua <<EOF
help([[
Quantum ESPRESSO $QE_VER
]])

depends_on("openmpi/$MPI_VER")
depends_on("fftw/$FFTW_VER")
depends_on("scalapack/$SCALAPACK_VER")

local root="$PREFIX/qe/$QE_VER"

prepend_path("PATH", pathJoin(root,"bin"))

setenv("ESPRESSO_ROOT",root)
EOF

###############################################################################
# Finished
###############################################################################

echo
echo "Directory tree created:"
echo "$PREFIX"
echo
echo "Module files:"
find "$PREFIX/modulefiles" -type f | sort
