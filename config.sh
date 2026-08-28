#!/usr/bin/env bash

##############################################################################
# HPC Build Configuration
#
# This file contains:
#
#   1. Global configuration variables
#   2. Default software versions
#   3. Installation directory layout
#   4. Common helper functions used by installer scripts
#
# Installer scripts should source this file rather than redefining paths
# or helper functions.
#
##############################################################################

##############################################################################
# Software layout
##############################################################################

SOFTWARE_ROOT="/mnt/software"

PREFIX="$SOFTWARE_ROOT/apps"
DOWNLOAD="$SOFTWARE_ROOT/downloads"
BUILD="$SOFTWARE_ROOT/build"
MODULES="$SOFTWARE_ROOT/modules"
SRC="$SOFTWARE_ROOT/sources"


##############################################################################
# Shell behaviour
##############################################################################

set -euo pipefail

trap 'echo "Error in ${BASH_SOURCE[1]} at line ${BASH_LINENO[0]}."' ERR


##############################################################################
# Default toolchain versions
##############################################################################

GCC_VERSION="13.3.0"

MPI="openmpi"
MPI_VERSION="5.0.3"


##############################################################################
# Default library versions
##############################################################################

OPENBLAS_VERSION="0.3.30"
SCALAPACK_VERSION="2.2.0"
FFTW_VERSION="3.3.10"
LIBXC_VERSION="7.0.0"
HDF5_VERSION="1.14.6"


##############################################################################
# Application versions
#
# These are retained for applications whose installers currently use the
# common configuration. New installers should preferably define their own
# application version locally.
##############################################################################

QE_VERSION="7.4"


##############################################################################
# GPU configuration
##############################################################################

GPU=false

GPU_BACKEND="cuda"

# NVIDIA compute capability
#
# V100  -> 70
# A100  -> 80
# H100  -> 90

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


##############################################################################
# Installer options
##############################################################################

MODULE_ONLY=false
FORCE=false


##############################################################################
# Build environment variables
#
# These are refreshed after the requested toolchain is loaded.
##############################################################################

CC=""
CXX=""
FC=""

MPICC=""
MPICXX=""
MPIFC=""


##############################################################################
# Download and extraction helpers
##############################################################################

download() {

    ##########################################################################
    # download URL FILE
    #
    # Downloads FILE into the common downloads directory.
    # Does nothing if the file already exists.
    ##########################################################################

    local url="$1"
    local file="$2"

    if [[ ! -f "$DOWNLOAD/$file" ]]; then

        wget -O "$DOWNLOAD/$file" "$url"

    else

        echo "$file already downloaded."

    fi
}


extract() {

    ##########################################################################
    # extract ARCHIVE DIRECTORY
    #
    # Removes any existing source directory and extracts ARCHIVE into SRC.
    ##########################################################################

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

    local file="$1"

    [[ -e "$file" ]]
}


already_installed() {

    local path="$1"

    installed "$INSTALL/$path" && ! $FORCE
}


directory_exists() {

    [[ -d "$1" ]]
}


install_dir() {

    ##########################################################################
    # install_dir PACKAGE VERSION
    #
    # Returns the installation directory appropriate for the currently
    # selected compiler/toolchain.
    ##########################################################################

    local package="$1"
    local version="$2"

    local base="$PREFIX"

    if [[ -n "$PREFIX_OVERRIDE" ]]; then
        base="$PREFIX_OVERRIDE"
    fi

    if [[ "$package" == "$COMPILER" ]]; then

        echo "$base/$COMPILER/$version"

    else

        echo "$base/$COMPILER/$COMPILER_VERSION/$package/$version"

    fi
}


##############################################################################
# Library helpers
##############################################################################

library_exists() {

    local lib="$1"

    installed "$INSTALL/lib/$lib" ||
    installed "$INSTALL/lib64/$lib"
}


find_library() {

    local lib="$1"

    if [[ -f "$INSTALL/lib/$lib" ]]; then

        echo "$INSTALL/lib/$lib"
        return 0

    fi

    if [[ -f "$INSTALL/lib64/$lib" ]]; then

        echo "$INSTALL/lib64/$lib"
        return 0

    fi

    return 1
}


find_package_library() {

    ##########################################################################
    # find_package_library ROOT LIBRARY
    ##########################################################################

    local root="$1"
    local lib="$2"

    if [[ -f "$root/lib/$lib" ]]; then

        echo "$root/lib/$lib"
        return 0

    fi

    if [[ -f "$root/lib64/$lib" ]]; then

        echo "$root/lib64/$lib"
        return 0

    fi

    return 1
}


##############################################################################
# Package location helpers
##############################################################################

find_package_include() {

    local root="$1"

    if [[ -d "$root/include" ]]; then

        echo "$root/include"
        return 0

    fi

    return 1
}


find_package_libdir() {

    local root="$1"

    if [[ -d "$root/lib64" ]]; then

        echo "$root/lib64"
        return 0

    fi

    if [[ -d "$root/lib" ]]; then

        echo "$root/lib"
        return 0

    fi

    return 1
}


find_package_cmake() {

    local root="$1"

    if [[ -d "$root/lib64/cmake" ]]; then

        echo "$root/lib64/cmake"
        return 0

    fi

    if [[ -d "$root/lib/cmake" ]]; then

        echo "$root/lib/cmake"
        return 0

    fi

    return 1
}


find_package_pkgconfig() {

    local root="$1"

    if [[ -d "$root/lib64/pkgconfig" ]]; then

        echo "$root/lib64/pkgconfig"
        return 0

    fi

    if [[ -d "$root/lib/pkgconfig" ]]; then

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

    if [[ ! -x "$CUDA_HOME/bin/nvcc" ]]; then

        echo
        echo "ERROR: CUDA Toolkit not installed."
        echo
        echo "Run:"
        echo "    ./09-cuda.sh"
        echo

        exit 1

    fi
}


##############################################################################
# Toolchain selection
##############################################################################

select_toolchain() {

    ##########################################################################
    # GPU builds use NVHPC.
    # CPU builds use GCC.
    ##########################################################################

    if $GPU; then

        COMPILER="nvhpc"

    else

        COMPILER="gcc"

    fi


    case "$COMPILER" in

        gcc)

            COMPILER_VERSION="$GCC_VERSION"

            # Default MPI remains OpenMPI.
            MPI="openmpi"

            ;;


        nvhpc)

            COMPILER_VERSION="$NVHPC_VERSION"

            MPI="hpcx"
            MPI_VERSION="$HPCX_VERSION"

            ;;

        *)

            echo
            echo "ERROR: Unknown compiler toolchain: $COMPILER"
            echo

            exit 1

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


##############################################################################
# Load toolchain
##############################################################################

load_toolchain() {

    ##########################################################################
    # load_toolchain [MPI_VERSION]
    #
    # Without an argument:
    #
    #     Load the default MPI version from config.sh.
    #
    # With an argument:
    #
    #     Load the explicitly requested MPI version.
    #
    # Example:
    #
    #     load_toolchain
    #     load_toolchain 4.1.8
    #
    ##########################################################################

    local requested_mpi="${1:-$MPI_VERSION}"


    module purge

    module use "$MODULES/Core"


    case "$COMPILER" in

        gcc)

            module load "gcc/$COMPILER_VERSION"

            if $GPU; then

                module load "cuda/$CUDA_VERSION"

            fi

            module load "$MPI/$requested_mpi"

            MPI_VERSION="$requested_mpi"

            CC=$(command -v gcc)
            CXX=$(command -v g++)
            FC=$(command -v gfortran)

            ;;


        nvhpc)

            module load "nvhpc/$COMPILER_VERSION"
            module load "hpcx/$HPCX_VERSION"

            MPI="hpcx"
            MPI_VERSION="$HPCX_VERSION"

            CC=$(command -v nvc)
            CXX=$(command -v nvc++)
            FC=$(command -v nvfortran)

            ;;


        *)

            echo
            echo "ERROR: Unknown compiler toolchain: $COMPILER"
            echo

            exit 1

            ;;

    esac

    MPICC=$(command -v mpicc)
    MPICXX=$(command -v mpicxx)
    MPIFC=$(command -v mpifort)
    MPIRUN=$(command -v mpirun)

    export CC CXX FC
    export MPICC MPICXX MPIFC MPIRUN

}


##############################################################################
# Dependency loading
##############################################################################

load_dependency() {

    ##########################################################################
    # load_dependency PACKAGE [VERSION]
    #
    # Loads one dependency.
    #
    # If VERSION is omitted, the default version from config.sh is used.
    #
    # Examples:
    #
    #     load_dependency openblas
    #     load_dependency openblas 0.3.30
    #     load_dependency openmpi 4.1.8
    #
    ##########################################################################

    local package="$1"
    local version="${2:-}"


    case "$package" in

        openmpi)

            [[ -n "$version" ]] || version="$MPI_VERSION"

            module load "openmpi/$version"

            MPI="openmpi"
            MPI_VERSION="$version"

            MPI_ROOT="$TOOLCHAIN/$MPI/$MPI_VERSION"

            ;;


        openblas)

            [[ -n "$version" ]] || version="$OPENBLAS_VERSION"

            module load "openblas/$version"

            OPENBLAS_VERSION="$version"
            OPENBLAS_ROOT="$TOOLCHAIN/openblas/$OPENBLAS_VERSION"

            ;;


        fftw)

            [[ -n "$version" ]] || version="$FFTW_VERSION"

            module load "fftw/$version"

            FFTW_VERSION="$version"
            FFTW_ROOT="$TOOLCHAIN/fftw/$FFTW_VERSION"

            ;;


        scalapack)

            [[ -n "$version" ]] || version="$SCALAPACK_VERSION"

            module load "scalapack/$version"

            SCALAPACK_VERSION="$version"
            SCALAPACK_ROOT="$TOOLCHAIN/scalapack/$SCALAPACK_VERSION"

            ;;


        libxc)

            [[ -n "$version" ]] || version="$LIBXC_VERSION"

            module load "libxc/$version"

            LIBXC_VERSION="$version"
            LIBXC_ROOT="$TOOLCHAIN/libxc/$LIBXC_VERSION"

            ;;


        hdf5)

            [[ -n "$version" ]] || version="$HDF5_VERSION"

            module load "hdf5/$version"

            HDF5_VERSION="$version"
            HDF5_ROOT="$TOOLCHAIN/hdf5/$HDF5_VERSION"

            ;;


        *)

            echo
            echo "ERROR: Unknown dependency: $package"
            echo

            exit 1

            ;;

    esac
}


##############################################################################
# Multiple dependency loader
##############################################################################

load_dependencies() {

    for package in "$@"; do

        load_dependency "$package"

    done
}


##############################################################################
# Parse installer command-line options
##############################################################################

parse_build_args() {

    MODULE_ONLY=false
    FORCE=false

    GPU=false

    BUILD_TYPE="Release"

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

                if [[ $# -eq 0 ]]; then

                    echo "Error: --jobs requires an argument."
                    exit 1

                fi

                JOBS="$1"

                ;;


            --prefix)

                shift

                if [[ $# -eq 0 ]]; then

                    echo "Error: --prefix requires an argument."
                    exit 1

                fi

                PREFIX_OVERRIDE="$1"

                ;;


            --version)

                shift

                if [[ $# -eq 0 ]]; then

                    echo "Error: --version requires an argument."
                    exit 1

                fi

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
# write_module LEVEL NAME VERSION ROOT [EXTRA] [DEPENDENCIES...]
#
# LEVEL:
#
#   core
#       Compiler, CUDA, etc.
#
#   compiler
#       Libraries built with a compiler.
#
#   mpi
#       Applications/libraries built with a compiler + MPI.
#
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

        if [[ "$extra" == *'family("mpi")'* ]]; then

                hierarchy=$(cat <<EOF
prepend_path("MODULEPATH",
             pathJoin("$MODULES",
                      "MPI",
                      "$COMPILER",
                      "$COMPILER_VERSION",
                      "$MPI",
                      "$version"))
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


    if [[ "$GPU_BACKEND" != "cuda" ]]; then

        echo
        echo "ERROR: Unsupported GPU backend: $GPU_BACKEND"
        echo

        exit 1

    fi


    if [[ ! -d "$CUDA_HOME" ]]; then

        echo
        echo "ERROR: CUDA_HOME does not exist:"
        echo
        echo "    $CUDA_HOME"
        echo

        exit 1

    fi


    if [[ ! -x "$CUDA_HOME/bin/nvcc" ]]; then

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