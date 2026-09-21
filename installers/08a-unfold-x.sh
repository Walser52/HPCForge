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
# unfold.x uses the QE build system directly through QE_ROOT. The QE module
# therefore supplies the compiler, MPI, libraries, include files, and
# make.inc required to build unfold.x.
#
# Features
#
# • Builds against an existing QE installation
# • CPU-only
# • Supports --force
# • Supports --module-only
# • Supports --version
# • Supports --jobs N
# • Generates an Lmod module
#
##############################################################################

set -euo pipefail

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
# Version of unfold-x itself.
#
# Set this in config.sh, for example:
#
#     UNFOLD_X_VERSION="..."
#
# The --version argument refers to the QE version against which unfold.x
# is compiled.
#


#
# Unfold-X tracks the current master branch.
#
UNFOLD_VERSION="master"

QE_VERSION_TARGET="${VERSION_OVERRIDE:-$QE_VERSION}"
##############################################################################
# CPU toolchain
##############################################################################

GPU=false
COMPILER="gcc"

select_toolchain    #GPU = False; COMPILER="gcc" => MPI="openmpi" (whichever version is set by config.sh)
load_toolchain      #Load the toolchain modules (gcc and openmpi)

##############################################################################
# Quantum ESPRESSO
##############################################################################
#
# unfold.x must be compiled against the CPU build of QE.
#
##############################################################################

echo
echo "Loading Quantum ESPRESSO $QE_VERSION_TARGET..."

module load "qe/$QE_VERSION_TARGET"

##############################################################################
# Locate QE
##############################################################################

PW_X="$(command -v pw.x || true)"

if [[ -z "$PW_X" ]]; then
    echo
    echo "ERROR: pw.x was not found after loading qe/$QE_VERSION_TARGET."
    echo
    exit 1
fi

QE_ROOT="$(cd -- "$(dirname -- "$(dirname -- "$PW_X")")" && pwd)"

if [[ ! -f "$QE_ROOT/make.inc" ]]; then
    echo
    echo "ERROR: QE make.inc was not found:"
    echo "    $QE_ROOT/make.inc"
    echo
    exit 1
fi

if [[ ! -f "$QE_ROOT/PW/src/libpw.a" ]]; then
    echo
    echo "ERROR: QE PW library was not found:"
    echo "    $QE_ROOT/PW/src/libpw.a"
    echo
    exit 1
fi

##############################################################################
# Source
##############################################################################

REPOSITORY="https://bitbucket.org/bonfus/unfold-x.git"

SOURCE_DIR="$SRC/unfold-x"

##############################################################################
# Installation
##############################################################################
#
# Keep the user-facing module name as:
#
#     unfold-x/<version>
#
# The module belongs to the CPU QE hierarchy and depends on the selected
# QE version.
#
# Physical installations are separated by QE version because unfold.x is
# compiled directly against QE's libraries.
#
##############################################################################

INSTALL="$(
    install_dir "$NAME" "$UNFOLD_VERSION"
)/$COMPILER/$COMPILER_VERSION/$MPI/$MPI_VERSION/qe/$QE_VERSION_TARGET"

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
echo "Quantum ESPRESSO:"
echo "    $QE_VERSION_TARGET"

echo
echo "QE root:"
echo "    $QE_ROOT"

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

    ##########################################################################
    # Existing installation
    ##########################################################################

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
        # Obtain source
        ######################################################################

        echo
        echo "Obtaining unfold-x source..."

        if [[ -d "$SOURCE_DIR/.git" ]]; then

            echo "Existing repository found:"
            echo "    $SOURCE_DIR"

            cd "$SOURCE_DIR"

            git fetch origin master
            git reset --hard origin/master
            git clean -fdx
        else

            rm -rf "$SOURCE_DIR"

            git clone --branch master "$REPOSITORY" "$SOURCE_DIR"

        fi

        ######################################################################
        # Build
        ######################################################################

        echo
        echo "Building unfold.x..."

        echo
        echo "Source:"
        echo "    $SOURCE_DIR"

        echo
        echo "QE_ROOT:"
        echo "    $QE_ROOT"

        cd "$SOURCE_DIR"

        make \
            QE_ROOT="$QE_ROOT" \
            -j"$JOBS"

        ######################################################################
        # Verify build
        ######################################################################

        if [[ ! -x "$SOURCE_DIR/bin/unfold.x" ]]; then

            echo
            echo "ERROR: unfold.x was not produced."
            echo
            echo "Expected:"
            echo "    $SOURCE_DIR/bin/unfold.x"
            echo

            exit 1

        fi

        ######################################################################
        # Install
        ######################################################################

        echo
        echo "Installing..."

        mkdir -p "$INSTALL/bin"

        cp -L \
            "$SOURCE_DIR/bin/unfold.x" \
            "$INSTALL/bin/unfold.x"

        #
        # Install unklist.x as well because the unfold-x build produces it.
        #

        if [[ -x "$SOURCE_DIR/bin/unklist.x" ]]; then

            cp -L \
                "$SOURCE_DIR/bin/unklist.x" \
                "$INSTALL/bin/unklist.x"

        fi

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
echo "QE root:"
echo "    $QE_ROOT"

echo
echo "Installation:"
echo "    $INSTALL"

echo
echo "Module:"
echo "    $MODULES/MPI/$COMPILER/$COMPILER_VERSION/$MPI/$MPI_VERSION/$NAME/$UNFOLD_VERSION.lua"

echo
echo "Executables:"
echo "    unfold.x"
echo "    unklist.x"

echo
echo "Done."
