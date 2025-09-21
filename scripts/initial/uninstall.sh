#!/usr/bin/env bash
# Uninstall srsRAN deps from /usr/local using manifest

set -euo pipefail

PREFIX="/usr/local"
STATE_DIR="${PREFIX}/share/srsran-install"
MANIFEST="${STATE_DIR}/manifest.txt"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo $0"
  exit 1
fi

if [[ ! -f "${MANIFEST}" ]]; then
  echo "Manifest not found: ${MANIFEST}"
  exit 1
fi

# remove files
mapfile -t files < "${MANIFEST}"
for f in "${files[@]}"; do
  [[ -n "${f}" && -e "${f}" ]] && rm -f -- "${f}" || true
done

# try to clean up now-empty directories (deep-first)
declare -A uniq_dirs=()
for f in "${files[@]}"; do
  d="$(dirname -- "${f}")"
  uniq_dirs["$d"]=1
done
# sort deepest first
while read -r d; do
  rmdir --ignore-fail-on-non-empty -- "$d" 2>/dev/null || true
done < <(printf "%s\n" "${!uniq_dirs[@]}" | awk '{ print length, $0 }' | sort -nr | cut -d" " -f2-)

# refresh dynamic linker cache
ldconfig

# remove state
rm -f -- "${MANIFEST}" || true
rmdir --ignore-fail-on-non-empty -- "${STATE_DIR}" 2>/dev/null || true

echo "Uninstall complete."
