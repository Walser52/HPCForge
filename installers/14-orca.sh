#!/usr/bin/env bash

##############################################################################
#
# USAGE:
#
# ./14-orca.sh
#
# Installs ORCA.
#
# ./14-orca.sh --force
#
# Reinstalls ORCA even if already installed.
#
# ./14-orca.sh --module-only
#
# Creates the module without reinstalling ORCA.
#
##############################################################################
#
# ORCA Installer
#
# Installs the precompiled ORCA package using the common HPC build framework.
#
# Unlike source-built packages, ORCA is distributed as a licensed binary
# archive and therefore must be downloaded manually.
#
##############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"
source "$SCRIPT_DIR/../reports.sh"

# source "$(dirname "$0")/config.sh"
# source "$(dirname "$0")/reports.sh"

parse_build_args "$@"


##############################################################################
# Package information
##############################################################################

NAME="orca"
VERSION="$ORCA_VERSION"

INSTALL="$(install_dir "$NAME" "$VERSION")"

ARCHIVE="orca_6_1_1_linux_x86-64_shared_openmpi418_avx2.tar.xz"

ARCHIVE_PATH="$DOWNLOADS/orca/$ARCHIVE"

MPI_VERSION="4.1.8"


##############################################################################
# Prerequisites
##############################################################################

echo "Checking dependencies..."

require tar

if [[ ! -f "$ARCHIVE_PATH" ]]; then

    echo
    echo "ERROR: ORCA archive not found:"
    echo
    echo "    $ARCHIVE_PATH"
    echo
    echo "ORCA must be downloaded manually from the ORCA Forum."
    echo

    exit 1

fi


##############################################################################
# Build / Install
##############################################################################

if ! $MODULE_ONLY; then

    if already_installed "$INSTALL/bin/orca"; then

        echo "ORCA $VERSION already installed."

        if $FORCE; then
            rm -rf "$INSTALL"
        else
            echo "Use --force to reinstall."
        fi

    fi

    if ! already_installed "$INSTALL/bin/orca"; then

        ######################################################################
        # Extract
        ######################################################################

        echo
        echo "Extracting ORCA..."

        extract "$ARCHIVE" "orca"

        ######################################################################
        # Locate extracted package
        ######################################################################

        ORCA_SRC=$(find "$SRC" \
            -maxdepth 1 \
            -type d \
            -name "orca*" \
            | head -n1)

        if [[ -z "$ORCA_SRC" ]]; then
            echo "Error: Could not locate extracted ORCA directory."
            exit 1
        fi

        ######################################################################
        # Install
        ######################################################################

        echo
        echo "Installing ORCA..."

        mkdir -p "$(dirname "$INSTALL")"

        mv "$ORCA_SRC" "$INSTALL"

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
    "" \
    "$MPI/$MPI_VERSION"


##############################################################################
# Summary
##############################################################################

summary \
    "ORCA $VERSION" \
    "Installation:" "$INSTALL" \
    "Module:" "$MODULES/MPI/$MPI/$MPI_VERSION/$NAME/$VERSION.lua" \
    "Executable:" "orca"

echo "Done."