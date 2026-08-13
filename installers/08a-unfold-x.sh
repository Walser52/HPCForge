```bash
#!/usr/bin/env bash

##############################################################################
# USAGE:
#
# ./08a-unfold-x.sh
#     Build unfold.x against the default QE version.
#
# ./08a-unfold-x.sh --version 7.4
#     Build unfold.x against QE 7.4.
#
##############################################################################
#
# Unfold-X Installer
#
# Builds unfold.x against an existing CPU Quantum ESPRESSO installation.
#
# The required toolchain is inherited from the QE module hierarchy:
#
#     gcc/<version>
#         openmpi/<version>
#             qe/<QE_VERSION>
#                 unfold-x/<UNFOLD_VERSION>
#
# unfold.x is intentionally CPU-only.
#
# Features
#
# • Builds against an existing QE installation
# • Supports --force
# • Supports --module-only
# • Supports --version
# • Supports --jobs N
# • Generates an Lmod module
#
##############################################################################

# set -euo pipefail

##############################################################################
# Configuration
##############################################################################

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

parse_build_args "$@"

##############################################################################
# Package information
##############################################################################

NAME="unfold-x"

#
# IMPORTANT:
#
# UNFOLD_VERSION is the version of unfold-x itself.
#
# QE_VERSION_TARGET is the version of QE against which unfold.x is compiled.
#
# For now, unfold-x is treated as a single source version and the QE version
# is selected with --version.
#

UNFOLD_VERSION="${UNFOLD_X_VERSION:-master}"
QE_VERSION_TARGET="${VERSION_OVERRIDE:-$QE_VERSION}"

##############################################################################
# CPU toolchain
##############################################################################

COMPILER="gcc"

select_toolchain
load_toolchain

##############################################################################
# QE dependency
##############################################################################

load_dependencies openblas fftw scalapack libxc hdf5

##############################################################################
# Prerequisites
##############################################################################

require "$MPICC"
require "$MPIFC"
require make
require git

##############################################################################
# Locate the QE installation
##############################################################################
#
# We deliberately load QE through the module hierarchy rather than attempting
# to reconstruct its installation path ourselves.
#
##############################################################################

echo
echo "Loading Quantum ESPRESSO $QE_VERSION_TARGET..."

module load "qe/$QE_VERSION_TARGET"

QE_ROOT="$(dirname "$(dirname "$(command -v pw.x)")")"

if [[ ! -d "$QE_ROOT" ]]; then
    echo
    echo "ERROR: Could not determine QE installation."
    echo
    exit 1
fi

if [[ ! -x "$QE_ROOT/bin/pw.x" ]]; then
    echo
    echo "ERROR: QE installation does not contain pw.x:"
    echo "    $QE_ROOT"
    echo
    exit 1
fi

echo "QE installation:"
echo "    $QE_ROOT"

##############################################################################
# Package source
##############################################################################

REPOSITORY="https://bitbucket.org/bonfus/unfold-x.git"

SOURCE_DIR="$SRC/unfold-x"

BUILD_DIR="$BUILD/unfold-x"

#
# The installed module is tied to the QE version because unfold.x is compiled
# against that QE installation.
#
INSTALL="$(install_dir "$NAME" "$UNFOLD_VERSION")/$COMPILER/$COMPILER_VERSION/$MPI/$MPI_VERSION/qe/$QE_VERSION_TARGET"

##############################################################################
# Existing installation
##############################################################################

echo
echo "============================================================="
echo " Unfold-X"
echo "============================================================="
echo

echo "Unfold-X version:"
echo "    $UNFOLD_VERSION"

echo
echo "Quantum ESPRESSO:"
echo "    $QE_VERSION_TARGET"

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
echo "    $MODULES/MPI/$COMPILER/$COMPILER_VERSION/$MPI/$MPI_VERSION/$NAME/$UNFOLD_VERSION.lua"

##############################################################################
# Build / Install
##############################################################################

if ! $MODULE_ONLY; then

    if installed "$INSTALL/bin/unfold.x" && ! $FORCE; then

        echo
        echo "unfold.x is already installed."
        echo "Use --force to rebuild."

    else

        ######################################################################
        # Force rebuild
        ######################################################################

        if $FORCE; then
            echo
            echo "Force enabled."
            echo "Removing existing installation:"
            echo "    $INSTALL"

            rm -rf "$INSTALL"
        fi

        ######################################################################
        # Source
        ######################################################################

        echo
        echo "Obtaining unfold-x source..."

        if [[ -d "$SOURCE_DIR/.git" ]]; then

            echo "Existing repository found:"
            echo "    $SOURCE_DIR"

            cd "$SOURCE_DIR"

            git fetch --all
            git reset --hard origin/master

        else

            rm -rf "$SOURCE_DIR"

            git clone "$REPOSITORY" "$SOURCE_DIR"

        fi

        ######################################################################
        # Build directory
        ######################################################################

        echo
        echo "Preparing build directory..."

        rm -rf "$BUILD_DIR"
        mkdir -p "$BUILD_DIR"

        ######################################################################
        # Build
        ######################################################################

        echo
        echo "Building unfold.x against:"
        echo "    QE_ROOT=$QE_ROOT"

        cd "$SOURCE_DIR"

        make \
            QE_ROOT="$QE_ROOT" \
            -j"$JOBS"

        ######################################################################
        # Verify build
        ######################################################################

        if [[ ! -x "$SOURCE_DIR/src/unfold.x" ]]; then

            echo
            echo "ERROR: unfold.x was not produced."
            echo
            exit 1

        fi

        ######################################################################
        # Install
        ######################################################################

        echo
        echo "Installing..."

        mkdir -p "$INSTALL/bin"

        cp "$SOURCE_DIR/src/unfold.x" \
            "$INSTALL/bin/unfold.x"

    fi

fi

##############################################################################
# Verify installation
##############################################################################

if ! installed "$INSTALL/bin/unfold.x"; then

    echo
    echo "ERROR: unfold.x installation failed."
    echo
    echo "Expected executable:"
    echo "    $INSTALL/bin/unfold.x"
    echo

    exit 1

fi

##############################################################################
# Module
##############################################################################

echo
echo "Generating module..."

write_module \
    mpi \
    "$NAME" \
    "$UNFOLD_VERSION" \
    "$INSTALL" \
    "" \
    "$COMPILER/$COMPILER_VERSION" \
    "$MPI/$MPI_VERSION" \
    "qe/$QE_VERSION_TARGET"

##############################################################################
# Summary
##############################################################################

echo
echo "============================================================="
echo " Unfold-X"
echo "============================================================="
echo

echo "Unfold-X version:"
echo "    $UNFOLD_VERSION"

echo
echo "Compiled against QE:"
echo "    $QE_VERSION_TARGET"

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
echo "    $MODULES/MPI/$COMPILER/$COMPILER_VERSION/$MPI/$MPI_VERSION/$NAME/$UNFOLD_VERSION.lua"

echo
echo "Executable:"
echo "    unfold.x"

echo
echo "Done."
```
