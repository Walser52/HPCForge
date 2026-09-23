#!/usr/bin/env bash

##############################################################################
# USAGE:
#
# ./15-lammps.sh
#     Build the default CPU version.
#
# ./15-lammps.sh --gpu
#     Build the GPU version.
#
# ./15-lammps.sh --version VERSION
#     Build a specific LAMMPS version.
#
# ./15-lammps.sh --version VERSION --gpu
#     Build a specific LAMMPS version with GPU support.
#
##############################################################################
#
# LAMMPS Installer
#
# Builds LAMMPS using the common HPCForge build framework.
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

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

parse_build_args "$@"

##############################################################################
# Package information
##############################################################################

NAME="lammps"

# Set the default version here.
#
# This can be overridden with:
#
#     ./15-lammps.sh --version VERSION
#
LAMMPS_VERSION="2Sep2026"

VERSION="${VERSION_OVERRIDE:-$LAMMPS_VERSION}"


##############################################################################
# LAMMPS package configuration
##############################################################################

#
# General-purpose LAMMPS packages.
#
# Keep this list relatively conservative. Additional packages should be added
# to the appropriate category below rather than enabling everything.
#

LAMMPS_GENERAL_PACKAGES=(
    KSPACE
    MOLECULE
    MANYBODY
)


#
# Additional packages useful for materials simulations.
#

LAMMPS_MATERIALS_PACKAGES=(
    EXTRA-COMPUTE
    EXTRA-DUMP
    EXTRA-FIX
    EXTRA-MOLECULE
    EXTRA-PAIR
)


#
# Machine-learning / interatomic-potential packages.
#
# This list can be expanded as the HPCForge MLIP workflow develops.
#

LAMMPS_ML_PACKAGES=(
    ML-SNAP
    ML-IAP
)


#
# GPU packages.
#
# These are defined now so that the GPU build can be added without changing
# the package architecture.
#

LAMMPS_GPU_PACKAGES=(
    KOKKOS
    GPU
)


##############################################################################
# Toolchain
##############################################################################

set_COMPILER_nvhpc_gcc $GPU
select_toolchain
load_toolchain


##############################################################################
# Prerequisites
##############################################################################

require "$MPICC"
require "$MPICXX"
require cmake
require make


##############################################################################
# LAMMPS package configuration
##############################################################################

#
# Convert the package name used by LAMMPS into the corresponding CMake
# variable.
#
# For example:
#
#     KSPACE
#
# becomes:
#
#     -DPKG_KSPACE=ON
#
# The package arrays above remain the authoritative package list.
#

LAMMPS_CMAKE_PACKAGES=()

for package in \
    "${LAMMPS_GENERAL_PACKAGES[@]}" \
    "${LAMMPS_MATERIALS_PACKAGES[@]}" \
    "${LAMMPS_ML_PACKAGES[@]}"
do

    LAMMPS_CMAKE_PACKAGES+=("-DPKG_${package}=ON")

done


##############################################################################
# GPU package configuration
##############################################################################

if $GPU; then

    #
    # GPU support is intentionally left as a separate block.
    #
    # The exact CUDA/KOKKOS configuration will be added once the CPU build
    # is verified.
    #

    for package in "${LAMMPS_GPU_PACKAGES[@]}"; do

        LAMMPS_CMAKE_PACKAGES+=("-DPKG_${package}=ON")

    done

fi

##############################################################################
# Installation
##############################################################################

BASE_INSTALL="$(install_dir "$NAME" "$VERSION")"

INSTALL="$BASE_INSTALL/$COMPILER/$COMPILER_VERSION/$MPI/$MPI_VERSION"

BUILD_DIR="$BUILD/$NAME-$VERSION-$COMPILER-$COMPILER_VERSION-$MPI-$MPI_VERSION"



##############################################################################
# Prerequisites
##############################################################################

require "$MPICC"
require "$MPICXX"
require cmake
require make
require tar


##############################################################################
# Build / Install
##############################################################################

echo
echo "============================================================="
echo " LAMMPS $VERSION"
echo "============================================================="
echo

echo "Build configuration:"
if $GPU; then
    echo "    Accelerator : CUDA"
else
    echo "    Accelerator : CPU"
fi

echo "    Compiler    : $COMPILER/$COMPILER_VERSION"
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

    if installed "$INSTALL/bin/lmp" && ! $FORCE; then

        echo "LAMMPS $VERSION is already installed."
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

        ARCHIVE="lammps-src-$VERSION.tar.gz"

        URL="https://github.com/lammps/lammps/releases/download/patch_$VERSION/$ARCHIVE"

        echo
        echo "Downloading LAMMPS..."
        echo "    $URL"

        download "$URL" "$ARCHIVE"


        ######################################################################
        # Extract
        ######################################################################

        echo
        echo "Extracting..."

        extract "$ARCHIVE" "lammps-$VERSION"

        LAMMPS_SRC="$SRC/lammps-$VERSION"

        if [[ ! -d "$LAMMPS_SRC" ]]; then

            echo
            echo "ERROR: Could not locate the extracted LAMMPS source directory."
            echo
            echo "Expected:"
            echo "    $LAMMPS_SRC"
            echo

            exit 1

        fi

        echo "Using source directory:"
        echo "    $LAMMPS_SRC"


        ######################################################################
        # Build directory
        ######################################################################

        echo
        echo "Preparing build directory..."

        rm -rf "$BUILD_DIR"
        mkdir -p "$BUILD_DIR"

        cd "$BUILD_DIR"



        ######################################################################
        # Validate requested packages
        ######################################################################

        echo
        echo "Checking requested LAMMPS packages..."

        for package in \
            "${LAMMPS_GENERAL_PACKAGES[@]}" \
            "${LAMMPS_MATERIALS_PACKAGES[@]}"
        do

            PACKAGE_DIR="$LAMMPS_SRC/src/$package"

            if [[ ! -d "$PACKAGE_DIR" ]]; then

                echo
                echo "ERROR: Requested LAMMPS package was not found:"
                echo
                echo "    $package"
                echo
                echo "Expected package directory:"
                echo "    $PACKAGE_DIR"
                echo

                exit 1

            fi

            echo "    Found: $package"

        done


        ######################################################################
        # CMake configuration
        ######################################################################

        echo
        echo "Configuring LAMMPS..."

        CMAKE_ARGS=(
            -DCMAKE_INSTALL_PREFIX="$INSTALL"
            -DCMAKE_BUILD_TYPE="$BUILD_TYPE"

            ##################################################################
            # Compilers
            ##################################################################

            -DCMAKE_CXX_COMPILER="$MPICXX"

            ##################################################################
            # Parallel execution
            ##################################################################

            -DBUILD_MPI=ON
            -DBUILD_OMP=ON

            ##################################################################
            # Build options
            ##################################################################

            -DBUILD_SHARED_LIBS=ON

            ##################################################################
            # Packages
            ##################################################################

            "${LAMMPS_CMAKE_PACKAGES[@]}"
        )


        ######################################################################
        # CPU configuration
        ######################################################################

        if ! $GPU; then

            echo
            echo "CPU build enabled."

            CMAKE_ARGS+=(
                -DPKG_OPENMP=ON
            )

        fi


        ######################################################################
        # GPU configuration
        ######################################################################

        if $GPU; then

            echo
            echo "GPU build requested."

            #
            # GPU/KOKKOS configuration will be added here.
            #
            # Do not add CUDA-specific CMake options yet.
            #

        fi


        ######################################################################
        # Display CMake configuration
        ######################################################################

        echo
        echo "CMake configuration:"
        echo

        printf '    %s\n' "${CMAKE_ARGS[@]}"

        echo


        ######################################################################
        # Run CMake
        ######################################################################

        cmake \
            -S "$LAMMPS_SRC/cmake" \
            -B "$BUILD_DIR" \
            "${CMAKE_ARGS[@]}"

        ######################################################################
        # Build
        ######################################################################

        echo
        echo "Building..."

        cmake --build "$BUILD_DIR" --parallel "$JOBS"


        ######################################################################
        # Install
        ######################################################################

        echo
        echo "Installing..."

        cmake --install "$BUILD_DIR"

    fi

fi


##############################################################################
# Verify installation
##############################################################################

if ! installed "$INSTALL/bin/lmp"; then

    echo
    echo "ERROR: LAMMPS installation failed."
    echo
    echo "Expected executable:"
    echo "    $INSTALL/bin/lmp"
    echo

    exit 1

fi

echo
echo "LAMMPS executable:"
echo "    $INSTALL/bin/lmp"

# echo
# echo "LAMMPS version:"
# "$INSTALL/bin/lmp" -help


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
    "$MPI/$MPI_VERSION"

##############################################################################
# Summary
##############################################################################


EXECUTABLES=("lmp")
summary "LAMMPS" "${EXECUTABLES[@]}"

echo
echo "Packages:"
for package in \
    "${LAMMPS_GENERAL_PACKAGES[@]}" \
    "${LAMMPS_MATERIALS_PACKAGES[@]}" \
    "${LAMMPS_ML_PACKAGES[@]}"
do
    echo "    $package"
done