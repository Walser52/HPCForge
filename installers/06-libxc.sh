#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

parse_build_args "$@"
select_toolchain
load_toolchain

##############################################################################
# LibXC Installation
##############################################################################

NAME="libxc"
VERSION="$LIBXC_VERSION"
INSTALL="$(install_dir "$NAME" "$VERSION")"

##############################################################################
# Prerequisites
##############################################################################

require "$CC"
require "$FC"
require cmake
require make

##############################################################################
# Build and install
##############################################################################

if ! $MODULE_ONLY; then

    if already_installed "lib/libxc.a" || already_installed "lib/libxc.so"; then
        echo "LibXC $VERSION already installed."

    else

        if $FORCE; then
            rm -rf "$BUILD/qe-$VERSION"
            rm -rf "$INSTALL"
        fi

        ARCHIVE="libxc-$VERSION.tar.gz"
        URL="https://gitlab.com/libxc/libxc/-/archive/$VERSION/$ARCHIVE"

        echo "Downloading LibXC..."
        download "$URL" "$ARCHIVE"

        echo
        echo "Extracting..."
        extract "$ARCHIVE" "libxc-$VERSION"

        rm -rf "$BUILD/libxc-$VERSION"
        mkdir -p "$BUILD/libxc-$VERSION"

        cd "$BUILD/libxc-$VERSION"

        echo
        echo "Configuring..."

        cmake \
            -DCMAKE_INSTALL_PREFIX="$INSTALL" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_C_COMPILER="$CC" \
            -DCMAKE_Fortran_COMPILER="$FC" \
            -DBUILD_SHARED_LIBS=OFF \
            -DENABLE_FORTRAN=ON \
            "$SRC/libxc-$VERSION"
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

if ! library_exists "libxc.a" && ! library_exists "libxc.so"; then
    echo "ERROR: LibXC installation failed."
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
echo " LibXC $VERSION"
echo "=============================================================="

echo
echo "Installation:"
echo "  $INSTALL"

echo
echo "Module:"
echo "  $MODULES/Compiler/$COMPILER/$COMPILER_VERSION/$NAME/$VERSION.lua"

echo
echo "Done."