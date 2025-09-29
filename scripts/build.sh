#!/usr/bin/env bash

set -e

_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE}")" && pwd -P)"

source "$_SCRIPT_DIR/helpers/args.sh"
source "$_SCRIPT_DIR/helpers/terminal.sh" 

ROOT_DIR="$(cd -- "${_SCRIPT_DIR}/.." && pwd -P)"

BUILD_TYPE=${1:-Debug}
BUILD_TYPE=$(echo "$BUILD_TYPE" | tr '[:upper:]' '[:lower:]')

if [ "$BUILD_TYPE" = "debug" ]; then
  BUILD_TYPE="Debug"
elif [ "$BUILD_TYPE" = "release" ]; then
  BUILD_TYPE="Release"
else
  echo "Usage: $0 [debug|release]"
  exit 1
fi

BUILD_DIR="${ROOT_DIR}/build/${BUILD_TYPE,,}"

mkdir -p "$BUILD_DIR"

echo "Configuring $BUILD_TYPE build in $BUILD_DIR..."

cmake -S "$ROOT_DIR" -B "$BUILD_DIR" \
  -DSRSGUI_LIBRARIES="$_SCRIPT_DIR/dependencies/libsrsgui-build/linux/2.0/x86_64/lib/libsrsgui.so" \
  -DSRSGUI_INCLUDE_DIRS="$_SCRIPT_DIR/dependencies/libsrsgui-build/linux/2.0/x86_64/include" \
  -DCMAKE_BUILD_TYPE=$BUILD_TYPE "${app_argv[@]}"

echo "Building $BUILD_TYPE..."
cmake --build "$BUILD_DIR" -- -j$(nproc) "${app_argv[@]}"

echo "Build completed in $BUILD_DIR"
