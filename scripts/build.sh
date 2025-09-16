#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"

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
cmake -S "$ROOT_DIR" -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=$BUILD_TYPE

echo "Building $BUILD_TYPE..."
cmake --build "$BUILD_DIR" -- -j$(nproc)

echo "Build completed in $BUILD_DIR"
