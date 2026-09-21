#!/usr/bin/env bash

##############################################################################
# ORCA Installer
#
# Installs the official ORCA binary distribution.
#
# Features
#
# • Uses the official precompiled ORCA binary
# • AVX2 build
# • OpenMPI 4.1.8
# • Supports --force
# • Supports --module-only
# • Supports --version
# • Supports --prefix
# • Generates an Lmod module
#
##############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

parse_build_args "$@"

##############################################################################
# Toolchain
##############################################################################

COMPILER="gcc"

select_toolchain
load_toolchain 4.1.8

##############################################################################
# Package information
##############################################################################

NAME="orca"
ORCA_VERSION="6.1.1"

VERSION="${VERSION_OVERRIDE:-$ORCA_VERSION}"
INSTALL="$(install_dir "$NAME" "$VERSION")"

ARCHIVE="orca_6_1_1_linux_x86-64_shared_openmpi418_avx2.run"
ARCHIVE_PATH="$DOWNLOAD/$ARCHIVE"

##############################################################################
# Prerequisites
##############################################################################

require "$MPIRUN"

if [[ ! -f "$ARCHIVE_PATH" ]]; then

    echo
    echo "ERROR: ORCA installer not found:"
    echo "    $ARCHIVE_PATH"
    echo
    echo "Download the official ORCA installer into:"
    echo "    $DOWNLOAD"
    exit 1

fi

##############################################################################
# Build / Install
##############################################################################

if ! $MODULE_ONLY; then

    if installed "$INSTALL/orca" && ! $FORCE; then

        echo "ORCA $VERSION already installed."

    else

        if $FORCE; then
            rm -rf "$INSTALL"
        fi

        echo
        echo "Installing ORCA $VERSION..."
        echo
        echo "Archive:"
        echo "    $ARCHIVE_PATH"
        echo
        echo "Installation:"
        echo "    $INSTALL"
        echo

        mkdir -p "$(dirname "$INSTALL")"

        ######################################################################
        # Prevent the ORCA installer from modifying the user's shell startup
        # files.
        ######################################################################

        TMP_HOME="$(mktemp -d)"

        trap 'rm -rf "$TMP_HOME"' EXIT

        ######################################################################
        # Run official ORCA installer
        ######################################################################

        HOME="$TMP_HOME" \
            "$ARCHIVE_PATH" \
            --accept \
            -- \
            -p "$INSTALL"

        ######################################################################
        # Cleanup
        ######################################################################

        rm -rf "$TMP_HOME"
        trap - EXIT

    fi

fi

##############################################################################
# Verify installation
##############################################################################

if ! installed "$INSTALL/orca"; then

    echo
    echo "ERROR: ORCA installation failed."
    exit 1

fi

##############################################################################
# Module
##############################################################################


write_module \
    mpi \
    "$NAME" \
    "$VERSION" \
    "$INSTALL" \
    'family("orca")' \
    "root_path" #special argument to prepend root to PATH instead of root/bin

##############################################################################
# Summary
##############################################################################

echo
echo "=============================================================="
echo " ORCA $VERSION"
echo "=============================================================="
echo

echo "Compiler:"
echo "    $COMPILER/$COMPILER_VERSION"
echo

echo "MPI:"
echo "    $MPI/$MPI_VERSION"
echo

echo "Installation:"
echo "    $INSTALL"
echo

echo "Module:"
echo "    $MODULES/Compiler/$COMPILER/$COMPILER_VERSION/$NAME/$VERSION.lua"
echo

echo "Executables:"
echo "    orca"
echo

echo "Done."