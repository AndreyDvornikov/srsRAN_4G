#!/usr/bin/env bash

set -euo pipefail

sudo pkill -9 -f 'srs(enb|ue|epc)' 2>/dev/null || true
reset
