source "$(dirname "$0")/config.sh"

parse_build_args "$@"

NAME="gcc"
VERSION="$(gcc -dumpfullversion)"
INSTALL="$(install_dir "$NAME" "$VERSION")"

##############################################################################
# Prerequisites
##############################################################################

require gcc
require g++
require gfortran

##############################################################################
# Install
##############################################################################

if ! $MODULE_ONLY; then

    if already_installed gcc; then
        echo "GCC $VERSION already configured."
    else

        echo "Configuring GCC $VERSION"

        mkdir -p "$INSTALL/bin"

        ln -sf "$(command -v gcc)"      "$INSTALL/bin/gcc"
        ln -sf "$(command -v g++)"      "$INSTALL/bin/g++"
        ln -sf "$(command -v gfortran)" "$INSTALL/bin/gfortran"

        gcc --version       > "$INSTALL/GCC_VERSION.txt"
        g++ --version      >> "$INSTALL/GCC_VERSION.txt"
        gfortran --version >> "$INSTALL/GCC_VERSION.txt"

    fi

fi

##############################################################################
# Verify
##############################################################################

if ! installed "$INSTALL/bin/gcc"; then
    echo "GCC installation failed."
    exit 1
fi

##############################################################################
# Module
##############################################################################

write_module core "$NAME" "$VERSION" "$INSTALL" '
family("compiler")


setenv("CC", pathJoin(root,"bin","gcc"))
setenv("CXX", pathJoin(root,"bin","g++"))
setenv("FC", pathJoin(root,"bin","gfortran"))
'

##############################################################################
# Summary
##############################################################################

echo
echo "Configured GCC $VERSION"

echo "Installation:"
echo "  $INSTALL"

echo "Module:"
echo "  $MODULES/Core/gcc/$VERSION.lua"