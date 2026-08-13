#!/usr/bin/env bash

##############################################################################
# USAGE:
#
# ./08-qe.sh
#     Build the default CPU version.
#
# ./08-qe.sh --gpu
#     Build the GPU version.
#
# ./08-qe.sh --version 7.4
#     Build QE 7.4 (CPU).
#
# ./08-qe.sh --version 7.4 --gpu
#     Build QE 7.4 (GPU).
#
##############################################################################
#
# Quantum ESPRESSO Installer
#
# Builds Quantum ESPRESSO using the common HPC build framework.
#
# Features
#
# • Out-of-source build
# • Supports --force
# • Supports --module-only
# • Supports --gpu
# • Supports --cpu
# • Supports --version
# • Supports --jobs N
# • Generates an Lmod module
#
##############################################################################

# set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

parse_build_args "$@"

##############################################################################
# Toolchain
##############################################################################

if $GPU; then
    COMPILER="nvhpc"
else
    COMPILER="gcc"
fi

select_toolchain
load_toolchain
load_dependencies openblas fftw scalapack libxc hdf5

if $GPU; then
    validate_gpu_configuration
fi

##############################################################################
# Package information
##############################################################################

NAME="qe"

VERSION="${VERSION_OVERRIDE:-$QE_VERSION}"

##############################################################################
# Installation
##############################################################################
#
# The module name is always:
#
#     qe/$VERSION
#
# The module hierarchy distinguishes the toolchain:
#
#     .../gcc/.../qe/$VERSION
#     .../nvhpc/.../qe/$VERSION
#
# The physical installation follows the same hierarchy so that CPU and
# GPU builds of the same QE version do not overwrite one another.
#
##############################################################################

BASE_INSTALL="$(install_dir "$NAME" "$VERSION")"

INSTALL="$BASE_INSTALL/$COMPILER/$COMPILER_VERSION/$MPI/$MPI_VERSION"

BUILD_DIR="$BUILD/qe-$VERSION-$COMPILER-$COMPILER_VERSION-$MPI-$MPI_VERSION"

##############################################################################
# Prerequisites
##############################################################################

require "$MPICC"
require "$MPIFC"
require cmake
require make

echo "Checking dependencies..."

find_package_library "$OPENBLAS_ROOT" libopenblas.so >/dev/null \
    || {
        echo "OpenBLAS not found."
        exit 1
    }

find_package_library "$SCALAPACK_ROOT" libscalapack.so >/dev/null \
    || {
        echo "ScaLAPACK not found."
        exit 1
    }

find_package_library "$FFTW_ROOT" libfftw3.so >/dev/null \
    || {
        echo "FFTW not found."
        exit 1
    }

echo "Finding LibXC"

find_package_library "$LIBXC_ROOT" libxc.so >/dev/null \
    || find_package_library "$LIBXC_ROOT" libxc.a >/dev/null \
    || {
        echo "LibXC not found."
        exit 1
    }

find_package_library "$LIBXC_ROOT" libxcf03.so >/dev/null \
    || find_package_library "$LIBXC_ROOT" libxcf03.a >/dev/null \
    || {
        echo "LibXC Fortran interface not found."
        exit 1
    }

echo "Finding HDF5"

find_package_library "$HDF5_ROOT" libhdf5.so >/dev/null \
    || {
        echo "HDF5 not found."
        exit 1
    }

##############################################################################
# Build / Install
##############################################################################

echo
echo "============================================================="
echo " Quantum ESPRESSO $VERSION"
echo "============================================================="
echo

echo "Build configuration:"
if $GPU; then
    echo "    Accelerator : CUDA"
    echo "    Compiler    : $COMPILER/$COMPILER_VERSION"
else
    echo "    Accelerator : CPU"
    echo "    Compiler    : $COMPILER/$COMPILER_VERSION"
fi

echo "    MPI         : $MPI/$MPI_VERSION"
echo "    Build type  : $BUILD_TYPE"
echo "    Jobs        : $JOBS"
echo

echo "Installation:"
echo "    $INSTALL"
echo

echo "Module:"
echo "    $MODULES/MPI/$COMPILER/$COMPILER_VERSION/$MPI/$MPI_VERSION/$NAME/$VERSION.lua"
echo

echo "Module-only:"
echo "    $MODULE_ONLY"
echo

if ! $MODULE_ONLY; then

    ##########################################################################
    # Existing installation
    ##########################################################################

    if installed "$INSTALL/bin/pw.x" && ! $FORCE; then

        echo "Quantum ESPRESSO $VERSION is already installed."
        echo "Use --force to rebuild."

    else

        ######################################################################
        # Force rebuild
        ######################################################################

        if $FORCE; then
            echo "Force enabled."
            echo "Removing existing installation:"
            echo "    $INSTALL"
            rm -rf "$INSTALL"
        fi

        ######################################################################
        # Download
        ######################################################################

        ARCHIVE="qe-$VERSION-ReleasePack.tar.gz"

        URL="https://gitlab.com/QEF/q-e/-/archive/qe-$VERSION/$ARCHIVE"

        echo
        echo "Downloading Quantum ESPRESSO..."
        echo "    $URL"

        download "$URL" "$ARCHIVE"

        ######################################################################
        # Extract
        ######################################################################

        echo
        echo "Extracting..."

        extract "$ARCHIVE" "q-e-qe-$VERSION"

        QE_SRC="$(
            find "$SRC" \
                -maxdepth 1 \
                -type d \
                -name "q-e-qe-$VERSION*" \
                | head -n1
        )"

        if [[ -z "$QE_SRC" ]]; then
            echo
            echo "ERROR: Could not locate the extracted Quantum ESPRESSO"
            echo "source directory."
            exit 1
        fi

        echo "Using source directory:"
        echo "    $QE_SRC"

        ######################################################################
        # Build directory
        ######################################################################

        echo
        echo "Preparing build directory..."

        rm -rf "$BUILD_DIR"
        mkdir -p "$BUILD_DIR"

        cd "$BUILD_DIR"

        ######################################################################
        # Configure
        ######################################################################

        echo
        echo "Configuring..."

        CMAKE_ARGS=(
            -DCMAKE_INSTALL_PREFIX="$INSTALL"
            -DCMAKE_BUILD_TYPE="$BUILD_TYPE"

            -DCMAKE_C_COMPILER="$MPICC"
            -DCMAKE_Fortran_COMPILER="$MPIFC"

            -DCMAKE_PREFIX_PATH="$OPENBLAS_ROOT;$FFTW_ROOT;$SCALAPACK_ROOT"

            -DLIBXC_ROOT="$LIBXC_ROOT"
            -DHDF5_ROOT="$HDF5_ROOT"

            ##################################################################
            # QE features
            ##################################################################

            -DQE_ENABLE_MPI=ON
            -DQE_ENABLE_OPENMP=ON

            -DQE_ENABLE_SCALAPACK=ON
            -DQE_ENABLE_HDF5=ON
            -DQE_ENABLE_LIBXC=ON
        )

        ######################################################################
        # GPU build additional arguments
        ######################################################################

        if $GPU; then

            echo
            echo "GPU build enabled."

            CMAKE_ARGS+=(
                -DQE_ENABLE_CUDA=ON
                -DCMAKE_CUDA_ARCHITECTURES="$CUDA_ARCHITECTURES"
                -DCMAKE_CUDA_COMPILER="$(command -v nvcc)"
            )

        fi

        ######################################################################
        # Run CMake
        ######################################################################

        echo
        echo "PKG_CONFIG_PATH=$PKG_CONFIG_PATH"

        pkg-config --modversion libxc
        pkg-config --libs libxc
        pkg-config --cflags libxc

        echo
        echo "Running CMake..."

        cmake "${CMAKE_ARGS[@]}" \
            "$QE_SRC"

        ######################################################################
        # Build
        ######################################################################

        echo
        echo "Building..."

        cmake --build . -j"$JOBS"

        ######################################################################
        # Install
        ######################################################################

        echo
        echo "Installing..."

        cmake --install .

    fi

fi

##############################################################################
# Verify installation
##############################################################################

if ! installed "$INSTALL/bin/pw.x"; then

    echo
    echo "ERROR: Quantum ESPRESSO installation failed."
    echo
    echo "Expected executable:"
    echo "    $INSTALL/bin/pw.x"
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
    "$VERSION" \
    "$INSTALL" \
    "" \
    "$COMPILER/$COMPILER_VERSION" \
    "$MPI/$MPI_VERSION" \
    "openblas/$OPENBLAS_VERSION" \
    "fftw/$FFTW_VERSION" \
    "libxc/$LIBXC_VERSION" \
    "scalapack/$SCALAPACK_VERSION" \
    "hdf5/$HDF5_VERSION"

##############################################################################
# Summary
##############################################################################

echo
echo "============================================================="
echo " Quantum ESPRESSO $VERSION"
echo "============================================================="
echo

if $GPU; then
    echo "Build:"
    echo "    GPU / CUDA"
else
    echo "Build:"
    echo "    CPU"
fi

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
echo "    $MODULES/MPI/$COMPILER/$COMPILER_VERSION/$MPI/$MPI_VERSION/$NAME/$VERSION.lua"

echo
echo "Executables:"
echo "    pw.x"
echo "    ph.x"
echo "    bands.x"
echo "    dos.x"
echo "    projwfc.x"
echo "    pp.x"

echo
echo "Done."