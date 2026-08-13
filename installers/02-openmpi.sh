#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

parse_build_args "$@"
if $GPU; then
    echo "OpenMPI is only built for the GCC toolchain."
    exit 1
fi

select_toolchain
load_toolchain
##############################################################################
# OpenMPI Installation
##############################################################################
# Use --version to override the default version of OpenMPI to install.

NAME="openmpi"

if [[ -n "$VERSION_OVERRIDE" ]]; then
    VERSION="$VERSION_OVERRIDE"
else
    VERSION="$MPI_VERSION"
fi

INSTALL="$(install_dir "$NAME" "$VERSION")"


##############################################################################
# Prerequisites
##############################################################################

require "$CC"
require "$CXX"
require "$FC"

require "$MPICC"
require "$MPICXX"
require "$MPIFC"

require make

##############################################################################
# Build and install
##############################################################################

if ! $MODULE_ONLY; then

    if installed "$INSTALL/bin/mpicc" && ! $FORCE; then
        echo "OpenMPI $VERSION already installed."

    else

        if $FORCE; then
            rm -rf "$INSTALL"
        fi

        ARCHIVE="openmpi-$VERSION.tar.gz"
        MPI_RELEASE="${VERSION%.*}"
        URL="https://download.open-mpi.org/release/open-mpi/v${MPI_RELEASE}/$ARCHIVE"

        echo "Downloading OpenMPI..."
        download "$URL" "$ARCHIVE"

        echo
        echo "Extracting..."
        extract "$ARCHIVE" "openmpi-$VERSION"

        echo
        echo "Preparing build directory..."

        rm -rf "$BUILD/openmpi-$VERSION"
        mkdir -p "$BUILD/openmpi-$VERSION"

        cd "$BUILD/openmpi-$VERSION"

        echo
        echo "Configuring..."

        CC="$CC" \
        CXX="$CXX" \
        FC="$FC" \
        "$SRC/openmpi-$VERSION/configure" \
            --prefix="$INSTALL"

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

if ! installed "$INSTALL/bin/mpicc"; then
    echo
    echo "ERROR: OpenMPI installation failed."
    exit 1
fi

##############################################################################
# Write module
##############################################################################

write_module compiler "$NAME" "$VERSION" "$INSTALL" '
family("mpi")
'

##############################################################################
# Summary
##############################################################################

echo
echo "=============================================================="
echo " OpenMPI $VERSION"
echo "=============================================================="
echo
echo "Installation:"
echo "  $INSTALL"
echo
echo "Module:"
echo "  $MODULES/Compiler/$COMPILER/$COMPILER_VERSION/$NAME/$VERSION.lua"
echo
echo "Done."