#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

parse_build_args "$@"

select_toolchain
load_toolchain

##############################################################################
# HDF5 Installation
##############################################################################

NAME="hdf5"
VERSION="$HDF5_VERSION"
INSTALL="$(install_dir "$NAME" "$VERSION")"

##############################################################################
# Prerequisites
##############################################################################

require "$MPICC"
require "$MPIFC"
require make

##############################################################################
# Build and install
##############################################################################

if ! $MODULE_ONLY; then

    if already_installed "lib/libhdf5.so"; then
        echo "HDF5 $VERSION already installed."
    
    else

        if $FORCE; then
            rm -rf "$BUILD/hdf5-$VERSION"
            rm -rf "$INSTALL"
        fi

        ARCHIVE="hdf5-$VERSION.tar.gz"
        URL="https://github.com/HDFGroup/hdf5/releases/download/hdf5_$VERSION/$ARCHIVE"

        echo $URL
        echo "Downloading HDF5..."
        download "$URL" "$ARCHIVE"

        echo
        echo "Extracting..."
        extract "$ARCHIVE" "hdf5-$VERSION"

        rm -rf "$BUILD/hdf5-$VERSION"
        mkdir -p "$BUILD/hdf5-$VERSION"

        cd "$BUILD/hdf5-$VERSION"

        echo
        echo "Configuring..."

        CC="$MPICC" \
        FC="$MPIFC" \
        "$SRC/hdf5-$VERSION/configure" \
            --prefix="$INSTALL" \
            --enable-shared \
            --enable-static \
            --enable-parallel \
            --enable-fortran \
            --enable-hl

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

if ! library_exists "libhdf5.so"; then
    echo
    echo "ERROR: HDF5 installation failed."
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
echo " HDF5 $VERSION"
echo "=============================================================="

echo
echo "Installation:"
echo "  $INSTALL"

echo
echo "Module:"
echo "  $MODULES/MPI/$COMPILER/$COMPILER_VERSION/$MPI/$MPI_VERSION/$NAME/$VERSION.lua"

echo
echo "Done."