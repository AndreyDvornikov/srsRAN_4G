#!/usr/bin/env bash

set -euo pipefail

_TERMINAL_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE}")" && pwd -P)"

open_in_console_gui() { 
    local hold=1
    if [[ "$1" == "--no-hold" ]]; then hold=0; shift; fi

    local cmd_str
    cmd_str=$(printf "%q " "$@")

    if command -v konsole >/dev/null; then
        if (( hold )); then
            setsid -f konsole --hold -e bash -lc "$cmd_str" >/dev/null 2>&1 &
        else
            setsid -f konsole -e bash -lc "$cmd_str" >/dev/null 2>&1 &
        fi
        return 0
    fi

    return 1
}