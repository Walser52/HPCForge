#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

parse_build_args "$@"
select_toolchain
load_toolchain

##############################################################################
# Options
##############################################################################

# Build all FFTW precision variants by default.
# true  = single + double + long double
# false = double precision only
FFTW_MIXED_PRECISION=true

##############################################################################
# FFTW Installation
##############################################################################

NAME="fftw"
VERSION="$FFTW_VERSION"
INSTALL="$(install_dir "$NAME" "$VERSION")"

##############################################################################
# Prerequisites
##############################################################################

require "$CC"
require "$FC"
require make

##############################################################################
# Build and install
##############################################################################

if ! $MODULE_ONLY; then

    if already_installed "lib/libfftw3.so"; then
        echo "FFTW $VERSION already installed."

    else

        if $FORCE; then
            rm -rf "$INSTALL"
        fi

        ARCHIVE="fftw-$VERSION.tar.gz"
        URL="https://www.fftw.org/$ARCHIVE"

        echo "Downloading FFTW..."
        download "$URL" "$ARCHIVE"

        echo
        echo "Extracting..."
        extract "$ARCHIVE" "fftw-$VERSION"

        rm -rf "$BUILD/fftw-$VERSION"
        mkdir -p "$BUILD/fftw-$VERSION"

        cd "$BUILD/fftw-$VERSION"

        echo
        echo "Configuring..."

        CONFIGURE_OPTIONS=(
            --prefix="$INSTALL"
            --enable-shared
            --enable-static
            --enable-openmp
        )

        case "$FFTW_MIXED_PRECISION" in
            true)
                echo "FFTW precision: mixed (single + double + long double)"

                # Build double precision
                rm -rf "$BUILD/fftw-$VERSION"
                mkdir -p "$BUILD/fftw-$VERSION"
                cd "$BUILD/fftw-$VERSION"

                "$SRC/fftw-$VERSION/configure" \
                    "${CONFIGURE_OPTIONS[@]}" \
                    CC="$CC" \
                    FC="$FC"

                make -j"$JOBS"
                make install

                # Build single precision
                rm -rf "$BUILD/fftw-$VERSION"
                mkdir -p "$BUILD/fftw-$VERSION"
                cd "$BUILD/fftw-$VERSION"

                "$SRC/fftw-$VERSION/configure" \
                    "${CONFIGURE_OPTIONS[@]}" \
                    --enable-float \
                    CC="$CC" \
                    FC="$FC"

                make -j"$JOBS"
                make install

                # Build long double precision
                rm -rf "$BUILD/fftw-$VERSION"
                mkdir -p "$BUILD/fftw-$VERSION"
                cd "$BUILD/fftw-$VERSION"

                "$SRC/fftw-$VERSION/configure" \
                    "${CONFIGURE_OPTIONS[@]}" \
                    --enable-long-double \
                    CC="$CC" \
                    FC="$FC"

                make -j"$JOBS"
                make install
                ;;

            false)
                echo "FFTW precision: double"

                "$SRC/fftw-$VERSION/configure" \
                    "${CONFIGURE_OPTIONS[@]}" \
                    CC="$CC" \
                    FC="$FC"

                make -j"$JOBS"
                make install
                ;;

            *)
                echo "ERROR: FFTW_MIXED_PRECISION must be true or false."
                exit 1
                ;;
        esac

        "$SRC/fftw-$VERSION/configure" \
            "${CONFIGURE_OPTIONS[@]}" \
            CC="$CC" \
            FC="$FC"

        echo
        echo "Building..."

        make -j"$JOBS"

        echo
        echo "Installing..."

        make install

    fi

fi

##############################################################################
# Verify installation
##############################################################################

if ! installed "$INSTALL/lib/libfftw3.so"; then
    echo
    echo "ERROR: FFTW installation failed."
    exit 1
fi

if [[ "$FFTW_MIXED_PRECISION" == true ]]; then

    for lib in libfftw3f.so libfftw3l.so; do
        if ! installed "$INSTALL/lib/$lib"; then
            echo
            echo "ERROR: Mixed-precision FFTW installation is missing $lib"
            exit 1
        fi
    done

fi

##############################################################################
# Module
##############################################################################

# write_module compiler "$NAME" "$VERSION" "$INSTALL" ""
write_module compiler "$NAME" "$VERSION" "$INSTALL"

##############################################################################
# Summary
##############################################################################

echo
echo "=============================================================="
echo " FFTW $VERSION"
echo "=============================================================="

echo
echo "Precision:"
if [[ "$FFTW_MIXED_PRECISION" == true ]]; then
    echo "  Mixed (single + double + long double)"
else
    echo "  Double"
fi

echo
echo "Installation:"
echo "  $INSTALL"

echo
echo "Module:"
echo "  $MODULES/Compiler/$COMPILER/$COMPILER_VERSION/$NAME/$VERSION.lua"

echo
echo "Done."