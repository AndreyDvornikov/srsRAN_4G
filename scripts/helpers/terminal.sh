#!/usr/bin/env bash

set -euo pipefail

_TERMINAL_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE}")" && pwd -P)"

open_in_console_gui() {
    local hold=1
    if [[ "${1-}" == "--no-hold" ]]; then
        hold=0
        shift
    fi

    # Нечего запускать
    (($#)) || return 1

    # Предпочитаем gnome-terminal, но на Debian/Ubuntu можно и через x-terminal-emulator
    if command -v gnome-terminal >/dev/null 2>&1; then
        if (( hold )); then
            setsid -f gnome-terminal -- \
                bash -lc '
                    "$@"
                    rc=$?
                    echo
                    echo "Process exited with code $rc"
                    echo "Press Ctrl-D or close the window..."
                    exec bash
                ' bash "$@" \
                >/dev/null 2>&1 &
        else
            setsid -f gnome-terminal -- \
                bash -lc 'exec "$@"' bash "$@" \
                >/dev/null 2>&1 &
        fi
        return 0
    fi

    if command -v x-terminal-emulator >/dev/null 2>&1; then
        if (( hold )); then
            setsid -f x-terminal-emulator -e \
                bash -lc '
                    "$@"
                    rc=$?
                    echo
                    echo "Process exited with code $rc"
                    echo "Press Ctrl-D or close the window..."
                    exec bash
                ' bash "$@" \
                >/dev/null 2>&1 &
        else
            setsid -f x-terminal-emulator -e \
                bash -lc 'exec "$@"' bash "$@" \
                >/dev/null 2>&1 &
        fi
        return 0
    fi

    return 1
}
