#!/usr/bin/env bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

require_build_layout

EPC_BIN="${BUILD_DIR}/srsepc/src/srsepc"
EPC_CONF="${CONFIG_DIR}/epc/epc.conf"

require_file "${EPC_BIN}"
require_file "${EPC_CONF}"

cd "${BUILD_DIR}"
exec sudo "${EPC_BIN}" "${EPC_CONF}"
