#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/config.sh"

parse_build_args "$@"
select_toolchain
load_toolchain

##############################################################################
# FFTW Installation
##############################################################################

NAME="fftw"
VERSION="$FFTW_VERSION"
INSTALL="$(install_dir "$NAME" "$VERSION")"

##############################################################################
# Prerequisites
##############################################################################

require "$CC"
require "$FC"
require make

##############################################################################
# Build and install
##############################################################################

if ! $MODULE_ONLY; then

    if already_installed "lib/libfftw3.so"; then
        echo "FFTW $VERSION already installed."

    else

        if $FORCE; then
            rm -rf "$INSTALL"
        fi

        ARCHIVE="fftw-$VERSION.tar.gz"
        URL="https://www.fftw.org/$ARCHIVE"

        echo "Downloading FFTW..."
        download "$URL" "$ARCHIVE"

        echo
        echo "Extracting..."
        extract "$ARCHIVE" "fftw-$VERSION"

        rm -rf "$BUILD/fftw-$VERSION"
        mkdir -p "$BUILD/fftw-$VERSION"

        cd "$BUILD/fftw-$VERSION"

        echo
        echo "Configuring..."

        "$SRC/fftw-$VERSION/configure" \
            --prefix="$INSTALL" \
            --enable-shared \
            --enable-static \
            --enable-openmp \
            CC="$CC" \
            FC="$FC"

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

if ! installed "$INSTALL/lib/libfftw3.so"; then
    echo
    echo "ERROR: FFTW installation failed."
    exit 1
fi

##############################################################################
# Module
##############################################################################

write_module compiler "$NAME" "$VERSION" "$INSTALL" ""

##############################################################################
# Summary
##############################################################################

echo
echo "=============================================================="
echo " FFTW $VERSION"
echo "=============================================================="

echo
echo "Installation:"
echo "  $INSTALL"

echo
echo "Module:"
echo "  $MODULES/Compiler/$COMPILER/$COMPILER_VERSION/$NAME/$VERSION.lua"

echo
echo "Done."

# Remarks
# =========================================
# FFTW actually comes in several variants:

# double precision (libfftw3)
# single precision (libfftw3f)
# long double (libfftw3l)
# MPI (libfftw3_mpi)
# OpenMP (libfftw3_omp)

# The script above builds the standard double-precision library with OpenMP support, which is sufficient for Quantum ESPRESSO.

# A couple of choices I'd make:

    # Build shared libraries (--enable-shared).
    # Also build static libraries (--enable-static).
    # Enable OpenMP support (--enable-openmp) so QE can take advantage of threaded FFTs.
    # Install into your toolchain directory.
    # Keep it as a compiler-level module.