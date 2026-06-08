#!/usr/bin/env bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

require_build_layout

ENB_DIR="${CONFIG_DIR}/enb/enb1"
ENB_BIN="${BUILD_DIR}/srsenb/src/srsenb"

require_file "${ENB_DIR}/enb.conf"
require_file "${ENB_BIN}"

cd "${ENB_DIR}"
exec sudo "${ENB_BIN}" enb.conf
