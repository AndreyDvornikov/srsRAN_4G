#!/usr/bin/env bash

set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Run as root: sudo $0"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

LIB_PKG_CONFIG_FNAME="libczmq.pc"
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

sudo apt-get install -y libnss3-dev libnspr4-dev pkg-config

echo "Installing shared libraries..."
cp "$SOURCE_DIR/lib/libczmq.so" "$INSTALL_LIB_DIR/"
cp "$SOURCE_DIR/lib/libczmq.so.4" "$INSTALL_LIB_DIR/"
cp "$SOURCE_DIR/lib/libczmq.so.4.2.1" "$INSTALL_LIB_DIR/"
cp "$SOURCE_DIR/lib/libczmq.so.4.2.2" "$INSTALL_LIB_DIR/"
chmod 755 "$INSTALL_LIB_DIR"/libczmq.so*

echo "Installing pkg-config file..."
cp "$LIB_PKG_CONFIG_FPATH" "$INSTALL_LIB_DIR/pkgconfig/"
chmod 644 "$INSTALL_LIB_DIR/pkgconfig/libczmq.pc"

echo "  Updating prefix in libczmq.pc..."
sed -i "s|$PREFIX_PATTERN|$INSTALL_PREFIX|g" "$INSTALL_LIB_DIR/pkgconfig/libczmq.pc"

echo "Installing CMake configuration files..."

echo "  Installing lib CMake files..."
mkdir -p "$INSTALL_LIB_DIR/cmake/czmq/"
cp "$SOURCE_DIR/lib/cmake/czmq/czmqConfig.cmake" "$INSTALL_LIB_DIR/cmake/czmq/"
cp "$SOURCE_DIR/lib/cmake/czmq/czmqConfigVersion.cmake" "$INSTALL_LIB_DIR/cmake/czmq/"
cp "$SOURCE_DIR/lib/cmake/czmq/czmqTargets.cmake" "$INSTALL_LIB_DIR/cmake/czmq/"
cp "$SOURCE_DIR/lib/cmake/czmq/czmqTargets-debug.cmake" "$INSTALL_LIB_DIR/cmake/czmq/"

echo "  Installing share CMake files..."
mkdir -p "$INSTALL_SHARE_DIR/cmake/czmq/"
cp "$SOURCE_DIR/share/cmake/czmq/czmqConfig.cmake" "$INSTALL_SHARE_DIR/cmake/czmq/"
cp "$SOURCE_DIR/share/cmake/czmq/czmqConfigVersion.cmake" "$INSTALL_SHARE_DIR/cmake/czmq/"
cp "$SOURCE_DIR/share/cmake/czmq/czmqTargets.cmake" "$INSTALL_SHARE_DIR/cmake/czmq/"
cp "$SOURCE_DIR/share/cmake/czmq/czmqTargets-relwithdebinfo.cmake" "$INSTALL_SHARE_DIR/cmake/czmq/"

chmod 644 "$INSTALL_LIB_DIR"/cmake/czmq/*
chmod 644 "$INSTALL_SHARE_DIR"/cmake/czmq/*

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