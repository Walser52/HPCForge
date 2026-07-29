#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

mkdir -p \
    "$PREFIX" \
    "$DOWNLOAD" \
    "$BUILD" \
    "$SRC" \
    "$MODULES"

source /usr/share/lmod/lmod/init/bash

module unuse "$MODULES/Core" 2>/dev/null || true
module use "$MODULES/Core"