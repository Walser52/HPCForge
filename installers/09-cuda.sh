#!/usr/bin/env bash

set -euo pipefail

# source "$(dirname "$0")/config.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"


parse_build_args "$@"

##############################################################################
# CUDA Toolkit Installation
##############################################################################

NAME="cuda"
VERSION="$CUDA_VERSION"
INSTALL="$CUDA_HOME"

##############################################################################
# Prerequisites
##############################################################################

require wget
require nvidia-smi

##############################################################################
# Build / Install
##############################################################################

if ! $MODULE_ONLY; then

    if installed "$INSTALL/bin/nvcc" && ! $FORCE; then

        echo "CUDA Toolkit $VERSION already installed."

    else

        if $FORCE; then
            rm -rf "$INSTALL"
        fi

        mkdir -p "$INSTALL"

        ######################################################################
        # NVIDIA Runfile
        ######################################################################

        echo "Downloading CUDA Toolkit... "
        download "$CUDA_URL" "$CUDA_RUNFILE"


        TMP="$SOFTWARE_ROOT/tmp"
        mkdir -p "$TMP"

        echo "Installing CUDA..."
        echo "Runfile: $DOWNLOAD/$CUDA_RUNFILE"
        echo "Install: $INSTALL"
        echo "Temporary directory: $TMP"

        TMPDIR="$TMP" \
        sh "$DOWNLOAD/$CUDA_RUNFILE" \
            --tmpdir="$TMP" \
            --toolkit \
            --override \
            --toolkitpath="$INSTALL"

    fi

fi

##############################################################################
# Verify installation
##############################################################################

if ! installed "$INSTALL/bin/nvcc"; then

    echo
    echo "ERROR: CUDA Toolkit installation failed."
    exit 1

fi

##############################################################################
# Write module
##############################################################################

MODULE_DIR="$MODULES/Core/cuda"

mkdir -p "$MODULE_DIR"

cat > "$MODULE_DIR/$VERSION.lua" <<EOF
help([[
CUDA Toolkit $VERSION
]])

whatis("CUDA Toolkit $VERSION")

family("cuda")

local root="$INSTALL"

prepend_path("PATH", pathJoin(root,"bin"))

if isDir(pathJoin(root,"lib64")) then
    prepend_path("LD_LIBRARY_PATH", pathJoin(root,"lib64"))
    prepend_path("LIBRARY_PATH", pathJoin(root,"lib64"))
    prepend_path("PKG_CONFIG_PATH", pathJoin(root,"lib64","pkgconfig"))
end

if isDir(pathJoin(root,"include")) then
    prepend_path("CPATH", pathJoin(root,"include"))
end

setenv("CUDA_HOME", root)
setenv("CUDA_PATH", root)
EOF

##############################################################################
# Summary
##############################################################################

echo
echo "Installing CUDA Toolkit only."
echo "The NVIDIA driver will NOT be modified."

echo
echo "=============================================================="
echo " CUDA Toolkit $VERSION"
echo "=============================================================="

echo
echo "Installation:"
echo "  $INSTALL"

echo
echo "Detected GPU(s):"
nvidia-smi --query-gpu=name --format=csv,noheader

echo
echo "Module:"
echo "  $MODULE_DIR/$VERSION.lua"

echo
echo "Done."