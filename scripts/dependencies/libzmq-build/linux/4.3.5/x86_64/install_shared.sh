#!/usr/bin/env bash

set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Run as root: sudo $0"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

LIB_PKG_CONFIG_FNAME="libzmq.pc"
LIB_PKG_CONFIG_FPATH="${SCRIPT_DIR}/lib/pkgconfig/$LIB_PKG_CONFIG_FNAME"

SOURCE_DIR="${SCRIPT_DIR}"

if [ ! -f "$LIB_PKG_CONFIG_FPATH" ]; then
    echo "Error: $LIB_PKG_CONFIG_FNAME not found at $LIB_PKG_CONFIG_FPATH"
    exit 1
fi

INSTALL_PREFIX="/usr/local"

INSTALL_LIB_DIR="$INSTALL_PREFIX/lib"
INSTALL_SHARE_DIR="$INSTALL_PREFIX/share"
INSTALL_DOC_DIR="$INSTALL_SHARE_DIR/doc/czmq"
INSTALL_INCLUDE_DIR="$INSTALL_PREFIX/include"

PREFIX_PATTERN="#INSTALL_PREFIX_FOR_EDIT#"

#############################################################

echo "Install $LIB_PKG_CONFIG_FNAME dependencies."

sudo apt-get install -y libtool pkg-config build-essential

echo "Installing shared libraries..."
cp "$SOURCE_DIR/lib/libzmq.so" "$INSTALL_LIB_DIR/"
cp "$SOURCE_DIR/lib/libzmq.so.5" "$INSTALL_LIB_DIR/"
cp "$SOURCE_DIR/lib/libzmq.so.5.2.5" "$INSTALL_LIB_DIR/"
chmod 755 "$INSTALL_LIB_DIR"/libzmq.so*

echo "Installing pkg-config file..."
cp "$LIB_PKG_CONFIG_FPATH" "$INSTALL_LIB_DIR/pkgconfig/"
chmod 644 "$INSTALL_LIB_DIR/pkgconfig/$LIB_PKG_CONFIG_FNAME"

echo "  Updating prefix in $LIB_PKG_CONFIG_FNAME..."
sed -i "s|$PREFIX_PATTERN|$INSTALL_PREFIX|g" "$INSTALL_LIB_DIR/pkgconfig/$LIB_PKG_CONFIG_FNAME"

echo "Installing CMake configuration files..."
echo "Nothing to install"

echo "Installing header files..."
if [ -d "$SOURCE_DIR/include" ]; then
    echo "  Creating include directory..."
    mkdir -p "$INSTALL_INCLUDE_DIR"
    
    echo "  Copying header files..."
    cp -r "$SOURCE_DIR/include"/* "$INSTALL_INCLUDE_DIR/"
    
    echo "  Setting permissions for header files..."
    find "$INSTALL_INCLUDE_DIR" -name "*.h" -type f -exec chmod 644 {} \;
    find "$INSTALL_INCLUDE_DIR" -type d -exec chmod 755 {} \;
    
    echo "  Header files installed to $INSTALL_INCLUDE_DIR"
    
    echo "  Installed headers:"
    find "$INSTALL_INCLUDE_DIR" -name "*.h" -type f | sed 's/^/    /' | head -10
    HEADER_COUNT=$(find "$INSTALL_INCLUDE_DIR" -name "*.h" -type f | wc -l)
    if [ "$HEADER_COUNT" -gt 10 ]; then
        echo "    ... and $((HEADER_COUNT - 10)) more files"
    fi
else
    echo "  Warning: No include directory found at $SOURCE_DIR/include"
fi