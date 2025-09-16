#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE}")" && pwd -P)"
WORKDIR="${SCRIPT_DIR}/../build/debug/srsenb/src"
cd "$WORKDIR"

BINARY="./srsenb"
ALL_ARGS=("$@")

GDBSERVER_PORT=${GDBSERVER_PORT:-2345}

echo "Starting srsenb under gdbserver on port ${GDBSERVER_PORT}..."
exec gdbserver ":${GDBSERVER_PORT}" "$BINARY" "${ALL_ARGS[@]}"
