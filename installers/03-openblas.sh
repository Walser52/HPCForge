#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

parse_build_args "$@"
select_toolchain
load_toolchain

##############################################################################
# OpenBLAS Installation
##############################################################################

NAME="openblas"
VERSION="$OPENBLAS_VERSION"
INSTALL="$(install_dir "$NAME" "$VERSION")"

##############################################################################
# Prerequisites
##############################################################################

require "$CC"
require "$CXX"
require "$FC"
require make

##############################################################################
# Build and install
##############################################################################

if ! $MODULE_ONLY; then

    if already_installed libopenblas.so || already_installed libopenblas.a; then
        echo "OpenBLAS $VERSION already installed."

    else

        if $FORCE; then
            rm -rf "$INSTALL"
        fi

        ARCHIVE="OpenBLAS-$VERSION.tar.gz"
        URL="https://github.com/OpenMathLib/OpenBLAS/releases/download/v$VERSION/$ARCHIVE"

        echo "Downloading OpenBLAS..."
        download "$URL" "$ARCHIVE"

        echo
        echo "Extracting..."
        extract "$ARCHIVE" "OpenBLAS-$VERSION"

        cd "$SRC/OpenBLAS-$VERSION"

        echo
        echo "Building..."

        # make -j"$(nproc)"
        make -j"$JOBS"

        echo
        echo "Installing..."

        make PREFIX="$INSTALL" install

    fi

fi

##############################################################################
# Verify installation
##############################################################################

if ! library_exists "libopenblas.so" && ! library_exists "libopenblas.a"; then
    echo
    echo "ERROR: OpenBLAS installation failed."
    exit 1
fi

##############################################################################
# Module
##############################################################################
echo "COMPILER=$COMPILER"
echo "COMPILER_VERSION=$COMPILER_VERSION"
echo "INSTALL=$INSTALL"
echo "MODULE PATH=$MODULES/Compiler/$COMPILER/$COMPILER_VERSION/$NAME/$VERSION.lua"

# write_module compiler "$NAME" "$VERSION" "$INSTALL"
write_module compiler "$NAME" "$VERSION" "$INSTALL" ""

##############################################################################
# Summary
##############################################################################

echo
echo "=============================================================="
echo " OpenBLAS $VERSION"
echo "=============================================================="

echo
echo "Installation:"
echo "  $INSTALL"

echo
echo "Module:"
echo "  $MODULES/Compiler/$COMPILER/$COMPILER_VERSION/$NAME/$VERSION.lua"

echo
echo "Done."