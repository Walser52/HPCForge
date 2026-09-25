#!/usr/bin/env bash

set -euo pipefail

###############################################################################
# GROMACS installer
#
# Usage:
#   ./16-gromacs.sh --version 2026.3 --cpu
#   ./16-gromacs.sh --version 2026.3 --gpu
#
# Installs:
#   /mnt/software/apps/gromacs/<version>-cpu
#   /mnt/software/apps/gromacs/<version>-cuda
#
# Modules:
#   gromacs/<version>-cpu
#   gromacs/<version>-cuda
###############################################################################

VERSION="2026.3"
BUILD_TYPE="Release"
BUILD_JOBS="${BUILD_JOBS:-96}"

BUILD_CPU=false
BUILD_GPU=false

SOFTWARE_ROOT="/mnt/software"
SOURCE_ROOT="${SOFTWARE_ROOT}/sources"
APP_ROOT="${SOFTWARE_ROOT}/apps/gromacs"
MODULE_ROOT="${SOFTWARE_ROOT}/modules/Core/gromacs"

###############################################################################
# Parse arguments
###############################################################################

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            VERSION="$2"
            shift 2
            ;;
        --cpu)
            BUILD_CPU=true
            shift
            ;;
        --gpu)
            BUILD_GPU=true
            shift
            ;;
        --help|-h)
            cat <<EOF

Usage:
    $0 --version VERSION --cpu
    $0 --version VERSION --gpu

Examples:
    $0 --version 2026.3 --cpu
    $0 --version 2026.3 --gpu

EOF
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ "$BUILD_CPU" == false && "$BUILD_GPU" == false ]]; then
    echo "ERROR: Specify --cpu and/or --gpu"
    exit 1
fi

###############################################################################
# General setup
###############################################################################

module purge
module use "${SOFTWARE_ROOT}/modules/Core"

mkdir -p "${SOURCE_ROOT}"
mkdir -p "${APP_ROOT}"
mkdir -p "${MODULE_ROOT}"

SOURCE="${SOURCE_ROOT}/gromacs-${VERSION}.tar.gz"
SRC_DIR="${SOURCE_ROOT}/gromacs-${VERSION}"

###############################################################################
# Download
###############################################################################

if [[ ! -f "$SOURCE" ]]; then
    echo "Downloading GROMACS ${VERSION}..."

    wget \
        -O "$SOURCE" \
        "https://ftp.gromacs.org/gromacs/gromacs-${VERSION}.tar.gz"
fi

if [[ ! -d "$SRC_DIR" ]]; then
    tar -xf "$SOURCE" -C "$SOURCE_ROOT"
fi

###############################################################################
# Common build function
###############################################################################

build_gromacs()
{
    local variant="$1"

    local INSTALL="${APP_ROOT}/${VERSION}-${variant}"
    local BUILD="${SOURCE_ROOT}/build-gromacs-${VERSION}-${variant}"

    echo
    echo "=============================================================="
    echo "Building GROMACS ${VERSION}-${variant}"
    echo "=============================================================="
    echo

    rm -rf "$BUILD"
    mkdir -p "$BUILD"

    cd "$BUILD"

    cmake "$SRC_DIR" \
        -DCMAKE_INSTALL_PREFIX="$INSTALL" \
        -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
        -DCMAKE_INSTALL_LIBDIR=lib \
        -DGMX_BUILD_OWN_FFTW=OFF \
        -DGMX_MPI=ON \
        -DGMX_OPENMP=ON \
        -DGMX_GPU=OFF \
        -DGMX_SIMD=AVX2_256 \
        -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=ON

    cmake --build . -j "$BUILD_JOBS"
    cmake --install .

    echo
    echo "Installed GROMACS ${VERSION}-${variant}"
    echo "Prefix: ${INSTALL}"
}

###############################################################################
# CPU build
###############################################################################

if [[ "$BUILD_CPU" == true ]]; then

    module purge
    module use "${SOFTWARE_ROOT}/modules/Core"

    module load gcc/13.3.0
    module load openmpi/5.0.3
    module load fftw/3.3.10

    echo
    echo "CPU toolchain:"
    gcc --version | head -1
    mpicc --version | head -1
    cmake --version | head -1

    build_gromacs "cpu"

fi

###############################################################################
# GPU build
###############################################################################

if [[ "$BUILD_GPU" == true ]]; then

    module purge
    module use "${SOFTWARE_ROOT}/modules/Core"

    module load nvhpc/26.5
    module load hpcx/2.50
    module load fftw/3.3.10

    echo
    echo "GPU toolchain:"
    nvcc --version
    cmake --version | head -1

    INSTALL="${APP_ROOT}/${VERSION}-cuda"
    BUILD="${SOURCE_ROOT}/build-gromacs-${VERSION}-cuda"

    rm -rf "$BUILD"
    mkdir -p "$BUILD"

    cd "$BUILD"

    cmake "$SRC_DIR" \
        -DCMAKE_INSTALL_PREFIX="$INSTALL" \
        -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
        -DCMAKE_INSTALL_LIBDIR=lib \
        -DGMX_BUILD_OWN_FFTW=OFF \
        -DGMX_MPI=ON \
        -DGMX_OPENMP=ON \
        -DGMX_GPU=CUDA \
        -DGMX_SIMD=AVX2_256 \
        -DCMAKE_CUDA_ARCHITECTURES=70 \
        -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=ON

    cmake --build . -j "$BUILD_JOBS"
    cmake --install .

    echo
    echo "Installed GROMACS ${VERSION}-cuda"
    echo "Prefix: ${INSTALL}"

fi

###############################################################################
# Module files
###############################################################################

create_module()
{
    local variant="$1"
    local install="${APP_ROOT}/${VERSION}-${variant}"
    local module="${MODULE_ROOT}/${VERSION}-${variant}.lua"

    cat > "$module" <<EOF
help([[
GROMACS ${VERSION} (${variant})
]])

whatis("Name: GROMACS")
whatis("Version: ${VERSION}")
whatis("Variant: ${variant}")
whatis("Description: GROMACS molecular dynamics package")

local root = "${install}"

prepend_path("PATH", pathJoin(root, "bin"))
prepend_path("LD_LIBRARY_PATH", pathJoin(root, "lib"))
prepend_path("PKG_CONFIG_PATH", pathJoin(root, "lib", "pkgconfig"))
prepend_path("CMAKE_PREFIX_PATH", root)

setenv("GMX_ROOT", root)

if isDir(pathJoin(root, "share", "gromacs")) then
    setenv("GMXDATA", pathJoin(root, "share", "gromacs"))
end
EOF

    echo "Created module: ${module}"
}

if [[ "$BUILD_CPU" == true ]]; then
    create_module "cpu"
fi

if [[ "$BUILD_GPU" == true ]]; then
    create_module "cuda"
fi

###############################################################################
# Done
###############################################################################

echo
echo "=============================================================="
echo "GROMACS installation complete"
echo "=============================================================="
echo

module purge
module use "${SOFTWARE_ROOT}/modules/Core"

if [[ "$BUILD_CPU" == true ]]; then
    echo "CPU:"
    echo "  module load gromacs/${VERSION}-cpu"
fi

if [[ "$BUILD_GPU" == true ]]; then
    echo "GPU:"
    echo "  module load gromacs/${VERSION}-cuda"
fi