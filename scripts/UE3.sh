#!/usr/bin/env bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

require_build_layout

UE_BIN="${BUILD_DIR}/srsue/src/srsue"
UE_CONF="${CONFIG_DIR}/ue/ue3/ue.conf"

require_file "${UE_BIN}"
require_file "${UE_CONF}"

cd "${BUILD_DIR}"
exec sudo "${UE_BIN}" "${UE_CONF}"
