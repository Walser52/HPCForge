#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

parse_build_args "$@"
select_toolchain
load_toolchain

##############################################################################
# ScaLAPACK Installation
##############################################################################

NAME="scalapack"
VERSION="$SCALAPACK_VERSION"
INSTALL="$(install_dir "$NAME" "$VERSION")"

##############################################################################
# Prerequisites
##############################################################################

require "$MPICC"
require "$MPIFC"
require cmake
require make

if ! installed "$(find_package_library "$OPENBLAS_ROOT" libopenblas.so)" &&
   ! installed "$(find_package_library "$OPENBLAS_ROOT" libopenblas.a)"
then
    echo "ERROR: OpenBLAS must be installed before ScaLAPACK."
    exit 1
fi

##############################################################################
# Build and install
##############################################################################

if ! $MODULE_ONLY; then

    if library_exists "libscalapack.so"; then
        echo "ScaLAPACK $VERSION already installed."

    else

        if $FORCE; then
            rm -rf "$INSTALL"
        fi

        ARCHIVE="scalapack-$VERSION.tar.gz"
        URL="https://github.com/Reference-ScaLAPACK/scalapack/archive/refs/tags/v$VERSION.tar.gz"

        echo "Downloading ScaLAPACK..."
        download "$URL" "$ARCHIVE"

        echo
        echo "Extracting..."
        extract "$ARCHIVE" "scalapack-$VERSION"

        rm -rf "$BUILD/scalapack-$VERSION"
        mkdir -p "$BUILD/scalapack-$VERSION"

        cd "$BUILD/scalapack-$VERSION"

        echo
        echo "Configuring..."

        CMAKE_ARGS=(
            -DCMAKE_BUILD_TYPE=Release
            -DCMAKE_INSTALL_PREFIX="$INSTALL"
            -DCMAKE_C_COMPILER="$MPICC"
            -DCMAKE_Fortran_COMPILER="$MPIFC"
            -DBUILD_SHARED_LIBS=ON
            -DBLAS_LIBRARIES="$(find_package_library "$OPENBLAS_ROOT" libopenblas.so)"
            -DLAPACK_LIBRARIES="$(find_package_library "$OPENBLAS_ROOT" libopenblas.so)"
        )

        if [ "$COMPILER" = "gcc" ]; then
            CMAKE_ARGS+=(
                -DCMAKE_Fortran_FLAGS="-fallow-argument-mismatch"
            )
        fi

        cmake "${CMAKE_ARGS[@]}" "$SRC/scalapack-$VERSION"


        echo
        echo "Building..."

        # make -j"$(nproc)"
        make -j"$JOBS"
        echo
        echo "Installing..."

        make install

    fi

fi

##############################################################################
# Verify installation
##############################################################################

if ! library_exists "libscalapack.so"; then
    echo
    echo "ERROR: ScaLAPACK installation failed."
    exit 1
fi

##############################################################################
# Module
##############################################################################

write_module mpi "$NAME" "$VERSION" "$INSTALL" ""

##############################################################################
# Summary
##############################################################################

echo
echo "=============================================================="
echo " ScaLAPACK $VERSION"
echo "=============================================================="

echo
echo "Installation:"
echo "  $INSTALL"

echo
echo "Module:"
echo "  $MODULES/MPI/$COMPILER/$COMPILER_VERSION/$MPI/$MPI_VERSION/$NAME/$VERSION.lua"

echo
echo "Done."


##############################################################################
# Notes
##############################################################################


# Compatibility & Fixes by GCC VersionGCC 9 and older: 
# Fully compatible out of the box with all classic ScaLAPACK versions (including v2.0.2 and v2.1.0).

# GCC 10 through GCC 14: 
# Requires ScaLAPACK v2.2.0 or newer, which includes native code fixes for compiler argument mismatches.Workaround for older ScaLAPACK:
# If you must compile an older ScaLAPACK version with GCC 10+, 
# you have to append the -fallow-argument-mismatch flag to your gfortran compilation flags (FCFLAGS).

# GCC 15 and newer: 
# Requires ScaLAPACK v2.2.2 or newer. GCC 15 enforces strict C standard conformity, 
# causing older ScaLAPACK releases to throw implicit function declaration errors.
# Workaround: If using older ScaLAPACK code, you must pas