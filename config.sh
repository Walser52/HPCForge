#!/usr/bin/env bash

##############################################################################
# HPC Build Configuration
#
# This file contains:
#
#   1. Global configuration variables
#   2. Version numbers for all software packages
#   3. Installation directory layout
#   4. Helper functions used by installer scripts
#
# Installer scripts should source this file rather than redefining paths or
# helper functions.
#
# Directory layout:
#
#   ~/apps/
#       gcc/<version>/
#           openmpi/<version>/
#           openblas/<version>/
#           scalapack/<version>/
#           fftw/<version>/
#           libxc/<version>/
#           hdf5/<version>/
#           qe/<version>/
#
# Sources:
#   ~/scripts/sources
#
# Downloads:
#   ~/scripts/downloads
#
# Build directories:
#   ~/scripts/build
#
# Modules:
#   ~/modules
#
##############################################################################

##############################################################################
# User Configuration
#
# These are the only variables that users are expected to modify.
#
# PREFIX            Installation prefix
# COMPILER          Compiler family
# COMPILER_VERSION  Compiler version
#
# Package versions
#   MPI_VERSION
#   OPENBLAS_VERSION
#   SCALAPACK_VERSION
#   FFTW_VERSION
#   LIBXC_VERSION
#   HDF5_VERSION
#   QE_VERSION
#
##############################################################################

SOFTWARE_ROOT="/mnt/software"   #Mount point for software root.

PREFIX="$SOFTWARE_ROOT/apps"
DOWNLOAD="$SOFTWARE_ROOT/downloads"
BUILD="$SOFTWARE_ROOT/build"
MODULES="$SOFTWARE_ROOT/modules"
SRC="$SOFTWARE_ROOT/sources"

##############################################################################
# Common installer options
##############################################################################

MODULE_ONLY=false
FORCE=false

set -euo pipefail

trap 'echo "Error in ${BASH_SOURCE[1]} at line ${BASH_LINENO[0]}."' ERR


##############################################################################
# GCC toolchain
##############################################################################

GCC_VERSION="13.3.0"

##############################################################################
# Versions 
##############################################################################


MPI="openmpi"
MPI_VERSION="5.0.3"

OPENBLAS_VERSION="0.3.30"
SCALAPACK_VERSION="2.2.0"
FFTW_VERSION="3.3.10"
LIBXC_VERSION="7.0.0"
HDF5_VERSION="1.14.6"
QE_VERSION="7.4"

##############################################################################
# GPU Configuration
##############################################################################

# Enable GPU support by default? Set true if you want GPU support.
GPU=false

# GPU backend
GPU_BACKEND="cuda"

# CUDA installation

# NVIDIA compute capability
#
# V100  -> 70
# A100  -> 80
# H100  -> 90
#
# CUDA_VERSION="12.2"
# CUDA_PATCH="12.2.2"
CUDA_VERSION="12.9"
CUDA_PATCH="12.9.0"

CUDA_ARCHITECTURES="70"

CUDA_HOME="$PREFIX/cuda/$CUDA_VERSION"

CUDA_RUNFILE="cuda_12.9.0_575.51.03_linux.run"
CUDA_URL="https://developer.download.nvidia.com/compute/cuda/$CUDA_PATCH/local_installers/$CUDA_RUNFILE"
##############################################################################
# NVIDIA HPC SDK
##############################################################################

NVHPC_VERSION="26.5"
NVHPC_BUILD="2026_265"

HPCX_VERSION="2.50"

NVHPC_ROOT="$PREFIX/nvhpc"

NVHPC_INSTALLER="nvhpc_${NVHPC_BUILD}_Linux_x86_64_cuda_multi.tar.gz"

NVHPC_URL="https://developer.download.nvidia.com/hpc-sdk/${NVHPC_VERSION}/${NVHPC_INSTALLER}"
#sample url: https://developer.download.nvidia.com/hpc-sdk/26.5/nvhpc_2026_265_Linux_x86_64_cuda_multi.tar.gz


##############################################################################
# Build tools
##############################################################################

CC=$(command -v gcc)
CXX=$(command -v g++)
FC=$(command -v gfortran)

MPICC=$(command -v mpicc)
MPICXX=$(command -v mpicxx)
MPIFC=$(command -v mpifort)



##############################################################################
# Download and extraction helpers
##############################################################################


download() {
##############################################################################
# download URL FILE
#
# Downloads FILE from URL into the downloads directory.
# The file is only downloaded if it does not already exist.
##############################################################################
    local url="$1"
    local file="$2"

    if [ ! -f "$DOWNLOAD/$file" ]; then
        wget -O "$DOWNLOAD/$file" "$url"
    else
        echo "$file already downloaded."
    fi
}

extract() {
##############################################################################
# extract ARCHIVE DIRECTORY
#
# Removes any existing source directory and extracts ARCHIVE into SRC.
##############################################################################
    local archive="$1"
    local dirname="$2"

    cd "$SRC"

    rm -rf "$dirname"

    tar xf "$DOWNLOAD/$archive"
}



##############################################################################
# Filesystem helpers
##############################################################################

installed() {
    # installed PATH. Returns success if PATH exists.
    local file="$1"

    [ -e "$file" ]
}

already_installed() {
    local path="$1"

    #assumes everything is in bin
    # installed "$INSTALL/bin/$executable" && ! $FORCE 
    
    
    installed "$INSTALL/$path" && ! $FORCE
}

directory_exists() {
    [ -d "$1" ]
}

install_dir() {

    local package="$1"
    local version="$2"

    local base="$PREFIX"

    if [ -n "$PREFIX_OVERRIDE" ]; then
        base="$PREFIX_OVERRIDE"
    fi

    if [ "$package" = "$COMPILER" ]; then
        echo "$base/$COMPILER/$version"
    else
        echo "$base/$COMPILER/$COMPILER_VERSION/$package/$version"
    fi
}

library_exists() {
    local lib="$1"

    installed "$INSTALL/lib/$lib" ||
    installed "$INSTALL/lib64/$lib"
}

find_library() {

    local lib="$1"

    if [ -f "$INSTALL/lib/$lib" ]; then
        echo "$INSTALL/lib/$lib"
        return
    fi

    if [ -f "$INSTALL/lib64/$lib" ]; then
        echo "$INSTALL/lib64/$lib"
        return
    fi

    return 1
}

find_package_library() {
    # library_exists() and find_library() currently look in $INSTALL, 
        # i.e. the package currently being built.
    # You may need to look into say OpenBLAS, rather than ScaLAPACK directory.
    local root="$1"
    local lib="$2"

    if [ -f "$root/lib/$lib" ]; then
        echo "$root/lib/$lib"
        return
    fi

    if [ -f "$root/lib64/$lib" ]; then
        echo "$root/lib64/$lib"
        return
    fi

    return 1
}

##############################################################################
# Package location helpers
##############################################################################

find_package_include() {

    local root="$1"

    if [ -d "$root/include" ]; then
        echo "$root/include"
        return 0
    fi

    return 1
}

find_package_libdir() {

    local root="$1"

    if [ -d "$root/lib64" ]; then
        echo "$root/lib64"
        return 0
    fi

    if [ -d "$root/lib" ]; then
        echo "$root/lib"
        return 0
    fi

    return 1
}


find_package_cmake() {

    local root="$1"

    if [ -d "$root/lib64/cmake" ]; then
        echo "$root/lib64/cmake"
        return 0
    fi

    if [ -d "$root/lib/cmake" ]; then
        echo "$root/lib/cmake"
        return 0
    fi

    return 1
}

find_package_pkgconfig() {

    local root="$1"

    if [ -d "$root/lib64/pkgconfig" ]; then
        echo "$root/lib64/pkgconfig"
        return 0
    fi

    if [ -d "$root/lib/pkgconfig" ]; then
        echo "$root/lib/pkgconfig"
        return 0
    fi

    return 1
}
##############################################################################
# Build environment helpers
##############################################################################

require() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Error: '$1' not found."
        exit 1
    }
}

require_gpu() {

    require nvidia-smi

    if [ ! -x "$CUDA_HOME/bin/nvcc" ]; then
        echo
        echo "ERROR: CUDA Toolkit not installed."
        echo
        echo "Run:"
        echo "    ./09-cuda.sh"
        echo
        exit 1
    fi
}

require gcc
require g++
require gfortran
require cmake
require make




##############################################################################
# Module helpers
##############################################################################
select_toolchain() {

    # GPU builds always use NVHPC
    if $GPU; then
        COMPILER="nvhpc"
    else
        COMPILER="gcc"
    fi

    case "$COMPILER" in

        gcc)
            COMPILER_VERSION="$GCC_VERSION"
            ;;

        nvhpc)
            COMPILER_VERSION="$NVHPC_VERSION"

            MPI="hpcx"
            MPI_VERSION="$HPCX_VERSION"
            ;;

    esac

    TOOLCHAIN="$PREFIX/$COMPILER/$COMPILER_VERSION"

    MPI_ROOT="$TOOLCHAIN/$MPI/$MPI_VERSION"
    OPENBLAS_ROOT="$TOOLCHAIN/openblas/$OPENBLAS_VERSION"
    FFTW_ROOT="$TOOLCHAIN/fftw/$FFTW_VERSION"
    LIBXC_ROOT="$TOOLCHAIN/libxc/$LIBXC_VERSION"
    HDF5_ROOT="$TOOLCHAIN/hdf5/$HDF5_VERSION"
    SCALAPACK_ROOT="$TOOLCHAIN/scalapack/$SCALAPACK_VERSION"
    QE_ROOT="$TOOLCHAIN/qe/$QE_VERSION"
}

load_toolchain() {

    module purge
    module use "$MODULES/Core"


    case "$COMPILER" in

        gcc)

            module load "gcc/$COMPILER_VERSION"

            if $GPU; then
                module load "cuda/$CUDA_VERSION"
            fi

            module load "openmpi/$MPI_VERSION"

            CC=$(command -v gcc)
            CXX=$(command -v g++)
            FC=$(command -v gfortran)
            ;;

        nvhpc)

            module load "nvhpc/$COMPILER_VERSION"
            module load "hpcx/$HPCX_VERSION"
            # HPC-X comes with the NVHPC module.
            CC=$(command -v nvc)
            CXX=$(command -v nvc++)
            FC=$(command -v nvfortran)
            ;;

    esac

    MPICC=$(command -v mpicc)
    MPICXX=$(command -v mpicxx)
    MPIFC=$(command -v mpifort)

    export CC CXX FC MPICC MPICXX MPIFC
}

load_dependencies() {
    for pkg in "$@"; do
        case "$pkg" in
            openblas)  module load "openblas/$OPENBLAS_VERSION" ;;
            fftw)      module load "fftw/$FFTW_VERSION" ;;
            scalapack) module load "scalapack/$SCALAPACK_VERSION" ;;
            libxc)     module load "libxc/$LIBXC_VERSION" ;;
            hdf5)      module load "hdf5/$HDF5_VERSION" ;;
            *) echo "Unknown dependency: $pkg"; exit 1 ;;
        esac
    done
}

##############################################################################
# Parse common installer command-line options
#
# Supported options:
#   --module-only   Skip build/install and regenerate module file only.
#   --force         Reinstall even if already installed.
##############################################################################



##############################################################################
# Parse build command-line options
#
# Supported options:
#
#   --module-only
#       Regenerate module file only.
#
#   --force
#       Rebuild even if already installed.
#
#   --gpu
#       Enable GPU build.
#
#   --debug
#       Build with Debug configuration.
#
#   --release
#       Build with Release configuration (default).
#
#   --jobs N
#       Number of parallel compilation jobs.
#
#   --prefix DIR
#       Override installation prefix.
#
##############################################################################

parse_build_args() {

    MODULE_ONLY=false
    FORCE=false

    GPU=false

    BUILD_TYPE="Release"

    # JOBS="$(nproc)"
    JOBS="${JOBS:-$(nproc)}"

    PREFIX_OVERRIDE=""
    VERSION_OVERRIDE=""

    while [[ $# -gt 0 ]]; do

        case "$1" in

            --module-only)

                MODULE_ONLY=true
                ;;

            --force)

                FORCE=true
                ;;

            --gpu)

                GPU=true
                ;;

            --cpu)

                GPU=false
                ;;

            --debug)

                BUILD_TYPE="Debug"
                ;;

            --release)

                BUILD_TYPE="Release"
                ;;

            --jobs)

                shift
                JOBS="$1"
                ;;

            --prefix)

                shift
                PREFIX_OVERRIDE="$1"
                ;;

            --version)

                shift
                VERSION_OVERRIDE="$1"
                ;;

            --help|-h)

                cat <<EOF

Usage:

    $0 [OPTIONS]

General options

    --module-only
        Regenerate only the module file.

    --force
        Rebuild even if already installed.

Build configuration

    --cpu
        Build the CPU version (default).

    --gpu
        Build the GPU/CUDA version.

    --debug
        Build a Debug version.

    --release
        Build a Release version.

Performance

    --jobs N
        Use N compilation jobs.
        Default: $(nproc)

Installation

    --prefix DIR
        Override installation prefix.

Version

    --version VERSION
        Override the default software version.

EOF
                exit 0
                ;;

            *)

                echo "Unknown option: $1"
                echo
                echo "Run '$0 --help' for usage."
                exit 1
                ;;

        esac

        shift

    done
}


##############################################################################
# Write an Lmod module file
#
# write_module LEVEL NAME VERSION ROOT [EXTRA]
#
# LEVEL:
#   core       Compiler, CUDA, etc.
#   compiler   Libraries built with a compiler
#   mpi        Applications/libraries built with a compiler + MPI
##############################################################################
write_module() {


    local level="$1"
    local name="$2"
    local version="$3"
    local root="$4"

    shift 4

    local extra=""

    if [[ $# -gt 0 ]]; then
        extra="$1"
        shift
    fi

    local dependencies=("$@")


    local module_dir
    local hierarchy=""

    local dependency_code=""

    for dep in "${dependencies[@]}"; do
        dependency_code+="depends_on(\"$dep\")"$'\n'
    done

    case "$level" in

        core)
            module_dir="$MODULES/Core/$name"

            hierarchy=$(cat <<EOF
prepend_path("MODULEPATH",
             pathJoin("$MODULES",
                      "Compiler",
                      "$COMPILER",
                      "$COMPILER_VERSION"))
EOF
)
            ;;

        compiler)
            module_dir="$MODULES/Compiler/$COMPILER/$COMPILER_VERSION/$name"

            echo "name=$name MPI=$MPI"
            
            # Only MPI implementations expose the MPI layer
            if [ "$level" = "compiler" ] && [[ "$extra" == *'family("mpi")'* ]]; then
                hierarchy=$(cat <<EOF
prepend_path("MODULEPATH",
             pathJoin("$MODULES",
                      "MPI",
                      "$COMPILER",
                      "$COMPILER_VERSION",
                      "$MPI",
                      "$MPI_VERSION"))
EOF
)
            fi
            ;;

        mpi)
            module_dir="$MODULES/MPI/$COMPILER/$COMPILER_VERSION/$MPI/$MPI_VERSION/$name"
            ;;

        *)
            echo "Unknown module level: $level"
            exit 1
            ;;
    esac

    mkdir -p "$module_dir"

    cat > "$module_dir/$version.lua" <<EOF
help([[
$name $version
]])

whatis("$name $version")

local root="$root"

$hierarchy

$dependency_code

$extra

prepend_path("PATH", pathJoin(root, "bin"))

if isDir(pathJoin(root, "lib")) then
    prepend_path("LD_LIBRARY_PATH", pathJoin(root, "lib"))
    prepend_path("LIBRARY_PATH", pathJoin(root, "lib"))
    prepend_path("PKG_CONFIG_PATH", pathJoin(root, "lib", "pkgconfig"))
end

if isDir(pathJoin(root, "lib64")) then
    prepend_path("LD_LIBRARY_PATH", pathJoin(root, "lib64"))
    prepend_path("LIBRARY_PATH", pathJoin(root, "lib64"))
    prepend_path("PKG_CONFIG_PATH", pathJoin(root, "lib64", "pkgconfig"))
end

if isDir(pathJoin(root, "include")) then
    prepend_path("CPATH", pathJoin(root, "include"))
end

if isDir(pathJoin(root, "share", "man")) then
    prepend_path("MANPATH", pathJoin(root, "share", "man"))
end
EOF

}

##############################################################################
# GPU validation
##############################################################################

validate_gpu_configuration() {

    if ! $GPU; then
        return 0
    fi

    if [ "$GPU_BACKEND" != "cuda" ]; then
        echo
        echo "ERROR: Unsupported GPU backend: $GPU_BACKEND"
        echo
        exit 1
    fi

    if [ ! -d "$CUDA_HOME" ]; then
        echo
        echo "ERROR: CUDA_HOME does not exist:"
        echo
        echo "    $CUDA_HOME"
        echo
        exit 1
    fi

    if [ ! -x "$CUDA_HOME/bin/nvcc" ]; then
        echo
        echo "ERROR: nvcc not found."
        echo
        echo "Expected:"
        echo
        echo "    $CUDA_HOME/bin/nvcc"
        echo
        exit 1
    fi

    if [[ ! "$CUDA_ARCHITECTURES" =~ ^[0-9]+$ ]]; then
        echo
        echo "ERROR: Invalid CUDA_ARCHITECTURES:"
        echo
        echo "    $CUDA_ARCHITECTURES"
        echo
        exit 1
    fi

}