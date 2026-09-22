#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
imports=${OMARCHY_SHELL_PATH:-/usr/share/omarchy/shell}
qmllint=${QMLLINT:-}

if [[ -z "$qmllint" ]]; then
  if command -v pyside6-qmllint >/dev/null 2>&1; then
    qmllint=$(command -v pyside6-qmllint)
  elif command -v qmllint >/dev/null 2>&1; then
    qmllint=$(command -v qmllint)
  elif [[ -x /usr/lib/qt6/bin/qmllint ]]; then
    qmllint=/usr/lib/qt6/bin/qmllint
  else
    printf '%s\n' "Qt 6 qmllint is required (Arch: qt6-declarative; other systems: PySide6-Essentials)." >&2
    exit 127
  fi
fi

import_root=$(mktemp -d "${TMPDIR:-/tmp}/omarchy-sunshine-qml.XXXXXX")
trap 'rm -rf -- "$import_root"' EXIT
ln -s "$imports" "$import_root/qs"

"$qmllint" \
  --ignore-settings \
  -W 0 \
  --import disable \
  --missing-property disable \
  --missing-type disable \
  --unresolved-type disable \
  --unqualified disable \
  -I "$import_root" \
  "$root/BarWidget.qml" "$root/Panel.qml" "$root/Service.qml"
