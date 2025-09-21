#!/usr/bin/env bash
# Minimal install to /usr/local: shared|static|all (default: shared)

set -euo pipefail

MODE="${1:-shared}"   # shared | static | all

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE}")" && pwd -P)"
SRC_ROOT="${SCRIPT_DIR}/dependencies"

PREFIX="/usr/local"
DEST_INC="${PREFIX}/include"
DEST_LIB="${PREFIX}/lib"
DEST_PKG="${DEST_LIB}/pkgconfig"
STATE_DIR="${PREFIX}/share/srsran-install"
MANIFEST="${STATE_DIR}/manifest.txt"

[[ $EUID -eq 0 ]] || { echo "Run as root: sudo $0 [shared|static|all]"; exit 1; }

mkdir -p "${DEST_INC}" "${DEST_LIB}" "${DEST_PKG}" "${STATE_DIR}"
: > "${MANIFEST}"

echo "[1/3] Install headers -> ${DEST_INC}"
# Копируем все include/ в /usr/local/include (сливаем деревья)
while IFS= read -r incdir; do
  find "$incdir" -type f -print0 | while IFS= read -r -d '' f; do
    rel="${f#"$incdir/"}"
    dst="${DEST_INC}/${rel}"
    install -D -m 0644 "$f" "$dst"
    echo "$dst" >> "${MANIFEST}"
  done
done < <(find "$SRC_ROOT" -type d -name include)

echo "[2/3] Install libs ($MODE) -> ${DEST_LIB}"
copy_lib() {
  local f="$1"
  local rel="${f##*/}"
  local dst="${DEST_LIB}/${rel}"
  # so* исполняемые (755), статические 644
  local mode=0755
  [[ "$f" == *.a ]] && mode=0644
  install -m "$mode" -D "$f" "$dst"
  echo "$dst" >> "${MANIFEST}"
}

# shared .so*
if [[ "$MODE" == "shared" || "$MODE" == "all" ]]; then
  while IFS= read -r f; do copy_lib "$f"; done \
    < <(find "$SRC_ROOT" -type f -path "*/lib/*" -name "*.so*" ! -name "*.la")
fi

# static .a
if [[ "$MODE" == "static" || "$MODE" == "all" ]]; then
  while IFS= read -r f; do copy_lib "$f"; done \
    < <(find "$SRC_ROOT" -type f -path "*/lib/*" -name "*.a")
fi

echo "[3/3] Install pkg-config -> ${DEST_PKG}"
while IFS= read -r pcdir; do
  find "$pcdir" -type f -name "*.pc" -print0 | while IFS= read -r -d '' f; do
    dst="${DEST_PKG}/$(basename "$f")"
    install -D -m 0644 "$f" "$dst"
    echo "$dst" >> "${MANIFEST}"
  done
done < <(find "$SRC_ROOT" -type d -name pkgconfig)

# Обновляем кэш и симлинки shared-библиотек (ldconfig делает ссылки libX.so -> libX.so.M -> libX.so.M.m)[6][9]
if [[ "$MODE" == "shared" || "$MODE" == "all" ]]; then
  ldconfig
fi

echo "Installed files: $(wc -l < "${MANIFEST}")"
echo "Manifest: ${MANIFEST}"
echo "Mode: ${MODE}"
