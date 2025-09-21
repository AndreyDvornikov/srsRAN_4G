#!/usr/bin/env bash
set -euo pipefail

has_file_caps() {
  local bin="$1" spec="$2"

  local out
  out="$(getcap "$bin" 2>/dev/null)"
  [[ -z "$out" ]] && { echo 0; return 0; }
  out="${out#*= }"

  declare -A have=()
  local grp names flags name
  for grp in $out; do
    names="${grp%%[+=]*}"
    flags=""
    [[ "$grp" == *+* ]] && flags="${grp##*+}"
    [[ "$grp" == *=* ]] && flags="${grp##*=}"
    IFS=',' read -r -a arr <<< "$names"
    for name in "${arr[@]}"; do
      have["$name"]="${have[$name]-}$flags"   # безопасно при set -u
    done
  done

  local reqflags
  for grp in $spec; do
    names="${grp%%[+=]*}"
    reqflags=""
    [[ "$grp" == *+* ]] && reqflags="${grp##*+}"
    [[ "$grp" == *=* ]] && reqflags="${grp##*=}"
    IFS=',' read -r -a arr <<< "$names"
    for name in "${arr[@]}"; do
      [[ -n "${have[$name]-}" ]] || { echo 0; return 0; }
      if [[ -n "$reqflags" ]]; then
        for ((i=0; i<${#reqflags}; i++)); do
          [[ "${have[$name]-}" == *"${reqflags:i:1}"* ]] || { echo 0; return 0; }
        done
      fi
    done
  done

  echo 1
}