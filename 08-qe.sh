#!/usr/bin/env bash

##############################################################################
# USAGE: 
#   ./08-qe.sh
# will build a CPU version.
# 
#   ./08-qe.sh --gpu
# will first check:
#   ✓ CUDA_HOME exists
#   ✓ nvcc exists
#   ✓ CUDA_ARCH is valid
# before CMake is invoked.
# To set the gpu version go to config.sh.

##############################################################################
#
# Quantum ESPRESSO Installer
#
# Builds Quantum ESPRESSO using the common HPC build framework.
#
# Features
#
#   • Out-of-source build
#   • Supports --force
#   • Supports --module-only
#   • Supports --gpu
#   • Supports --jobs N
#   • Generates an Lmod module
#
##############################################################################

# set -euo pipefail


source "$(dirname "$0")/config.sh"

parse_build_args "$@"

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
VERSION="$QE_VERSION"

INSTALL="$(install_dir "$NAME" "$VERSION")"

##############################################################################
# Prerequisites
##############################################################################

require "$MPICC"
require "$MPIFC"
require cmake
require make

echo "Checking dependencies..."

find_package_library "$OPENBLAS_ROOT"  libopenblas.so >/dev/null \
    || { echo "OpenBLAS not found."; exit 1; }

find_package_library "$SCALAPACK_ROOT" libscalapack.so >/dev/null \
    || { echo "ScaLAPACK not found."; exit 1; }

find_package_library "$FFTW_ROOT" libfftw3.so >/dev/null \
    || { echo "FFTW not found."; exit 1; }

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

echo "Finding hdf5"

find_package_library "$HDF5_ROOT" libhdf5.so >/dev/null \
    || { echo "HDF5 not found."; exit 1; }

##############################################################################
# Build / Install
##############################################################################

echo "checking module $MODULE_ONLY"

if ! $MODULE_ONLY; then

    if already_installed pw.x; then

        echo "Quantum ESPRESSO $VERSION already installed."

    else

        if $FORCE; then
            rm -rf "$INSTALL"
        fi

        ######################################################################
        # Download
        ######################################################################

        ARCHIVE="qe-$VERSION-ReleasePack.tar.gz"

        URL="https://gitlab.com/QEF/q-e/-/archive/qe-$VERSION/$ARCHIVE"

        echo
        echo "Downloading Quantum ESPRESSO..."

        download "$URL" "$ARCHIVE"

        ######################################################################
        # Extract
        ######################################################################

        echo
        echo "Extracting..."

        extract "$ARCHIVE" "q-e-qe-$VERSION"

        QE_SRC=$(find "$SRC" -maxdepth 1 -type d -name "q-e-qe-$VERSION*" | head -n1)
        if [[ -z "$QE_SRC" ]]; then
            echo "Error: Could not locate the extracted Quantum ESPRESSO source directory."
            exit 1
        fi

        echo "Using source directory: $QE_SRC"        
        ######################################################################
        # Build directory
        ######################################################################

        echo "Building directories"
        rm -rf "$BUILD/qe-$VERSION"
        mkdir -p "$BUILD/qe-$VERSION"
        cd "$BUILD/qe-$VERSION"

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
            # Edit these if necessary
            ##################################################################

            -DQE_ENABLE_MPI=ON
            -DQE_ENABLE_OPENMP=ON

            -DQE_ENABLE_SCALAPACK=ON
            -DQE_ENABLE_HDF5=ON
            -DQE_ENABLE_LIBXC=ON

            ##################################################################
        )

        ######################################################################
        # GPU build additional arguments
        ######################################################################

        if $GPU; then

            echo
            echo "GPU build enabled."

            CMAKE_ARGS+=(

                ##############################################################
                # EDIT THESE FOR YOUR SYSTEM
                ##############################################################

                -DQE_ENABLE_CUDA=ON
                -DCMAKE_CUDA_ARCHITECTURES="$CUDA_ARCHITECTURES"
                -DCMAKE_CUDA_COMPILER="$(command -v nvcc)"
                # Example:
                #
                # -DCMAKE_CUDA_ARCHITECTURES=80
                #
                # -DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc
                #
                ##############################################################

            )

        fi

        ######################################################################
        # Run CMake
        ######################################################################

        echo "PKG_CONFIG_PATH=$PKG_CONFIG_PATH"
        pkg-config --modversion libxc
        pkg-config --libs libxc
        pkg-config --cflags libxc
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

        cmake --install .``

    fi

fi

##############################################################################
# Verify installation
##############################################################################

if ! installed "$INSTALL/bin/pw.x"; then

    echo
    echo "ERROR: Quantum ESPRESSO installation failed."

    exit 1

fi

##############################################################################
# Module
##############################################################################

# write_module mpi "$NAME" "$VERSION" "$INSTALL"

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