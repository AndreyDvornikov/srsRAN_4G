#!/usr/bin/env bash
set -euo pipefail

_APP_ARGS=()

_ARGS_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE}")" && pwd -P)"
_ARGS_ALL_ARGS=("$@")

EXEC_REL_TYPE="release"
EXEC_REL_ON_RELEASE=0
EXEC_REL_ON_DEBUG=0
EXEC_REL_ERR_PARSED=0

GDB_ON=0
GDB_ADDR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -args|--)
      shift
      app_argv=( "$@" )
      break
      ;;
    *)
      script_args+=( "$1" )
      shift
      ;;
  esac
done

set -- "${script_args[@]}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -rel|--rel)
      [[ $# -ge 2 ]] || { echo "-rel/--rel requires value" >&2; EXEC_REL_ERR_PARSED=1; break; }
      EXEC_REL_TYPE="${2,,}"
      shift 2
      ;;
    -rel=*|--rel=*)
      EXEC_REL_TYPE="${1#*=}"
      EXEC_REL_TYPE="${EXEC_REL_TYPE,,}"
      shift
      ;;
    -gdb|--gdb)
      GDB_ON=1
      if [[ $# -ge 2 && "$2" != -* ]]; then
        GDB_ADDR="$2"
        shift 2
      else
        shift
      fi
      ;;
    -gdb=*|--gdb=*)
      GDB_ON=1
      GDB_ADDR="${1#*=}"
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      EXEC_REL_ERR_PARSED=1
      shift
      ;;
  esac
done

case "$EXEC_REL_TYPE" in
  ""|release) EXEC_REL_ON_RELEASE=1 ;;
  debug)      EXEC_REL_ON_DEBUG=1 ;;
  *)          EXEC_REL_ERR_PARSED=1 ;;
esac


echo "REL=$EXEC_REL_TYPE, GDB_ON=$GDB_ON, GDB_ADDR='$GDB_ADDR', tail: ${app_argv[*]}"