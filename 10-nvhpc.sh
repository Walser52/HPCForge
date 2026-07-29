#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/config.sh"

parse_build_args "$@"

##############################################################################
# NVIDIA HPC SDK Installation
##############################################################################

NAME="nvhpc"
VERSION="$NVHPC_VERSION"
# INSTALL="$NVHPC_ROOT/$VERSION"
INSTALL="$NVHPC_ROOT"
SOURCE_DIR="$SRC/${NVHPC_INSTALLER%.tar.gz}"

##############################################################################
# Prerequisites
##############################################################################

require tar
require wget

##############################################################################
# Build and install
##############################################################################

NVFORTRAN="$INSTALL/Linux_x86_64/$VERSION/compilers/bin/nvfortran"

if ! $MODULE_ONLY; then

  if [ -x "$NVFORTRAN" ]; then
        echo "NVHPC $VERSION already installed."

    else

        if $FORCE; then
            rm -rf "$INSTALL"
        fi

        mkdir -p "$PREFIX/nvhpc"

        ARCHIVE="$NVHPC_INSTALLER"

        if [ ! -f "$DOWNLOAD/$ARCHIVE" ]; then
            echo "Downloading NVIDIA HPC SDK..."
            download "$NVHPC_URL" "$ARCHIVE"
        fi


        mkdir -p "$SRC"

        if [ ! -d "$SOURCE_DIR" ]; then
            echo "Extracting..."
            tar -xzf "$DOWNLOAD/$ARCHIVE" -C "$SRC"
        fi

        echo
        echo "Installing NVIDIA HPC SDK..."

        cd "$SOURCE_DIR"

        export NVHPC_SILENT=true
        export NVHPC_INSTALL_DIR="$INSTALL"

        ./install
    fi

fi


    

echo
echo "Verifying installation..."

require "$NVFORTRAN"
"$NVFORTRAN" --version


EXTRA=$(cat <<EOF
local sdk = pathJoin(root, "Linux_x86_64", "$VERSION")

setenv("NVHPC_ROOT", sdk)
setenv("NVCOMPILER", sdk)
--------------------------------------------------
-- Compilers
--------------------------------------------------

prepend_path("PATH", pathJoin(sdk, "compilers", "bin"))
prepend_path("LD_LIBRARY_PATH", pathJoin(sdk, "compilers", "lib"))
prepend_path("LIBRARY_PATH", pathJoin(sdk, "compilers", "lib"))
prepend_path("CPATH", pathJoin(sdk, "compilers", "include"))
prepend_path("MANPATH", pathJoin(sdk, "compilers", "man"))

--------------------------------------------------
-- CUDA
--------------------------------------------------

prepend_path("PATH", pathJoin(sdk, "cuda", "bin"))
prepend_path("LD_LIBRARY_PATH", pathJoin(sdk, "cuda", "lib64"))

--------------------------------------------------
-- HPC-X MPI
--------------------------------------------------

local hpcx = pathJoin(sdk, "comm_libs", "hpcx")

prepend_path("PATH", pathJoin(hpcx, "bin"))

EOF
)

# Write nvhpc module
COMPILER="nvhpc"
COMPILER_VERSION="$NVHPC_VERSION"

write_module core "$NAME" "$VERSION" "$INSTALL" "$EXTRA"


# Write hpcx module
MPI="hpcx"
MPI_VERSION="$HPCX_VERSION"

write_module compiler \
    "hpcx" \
    "$HPCX_VERSION" \
    "$NVHPC_ROOT/Linux_x86_64/$NVHPC_VERSION/comm_libs/hpcx" \
    'family("mpi")'