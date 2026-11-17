#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
mkdir -p .local/reports .local/imports/qs
shell_source="${OMARCHY_PATH:-/usr/share/omarchy}/shell"
for module in Commons Ui; do
  if [[ ! -e $module ]]; then ln -s "$shell_source/$module" "$module"; fi
  if [[ ! -e .local/imports/qs/$module ]]; then ln -s "$shell_source/$module" ".local/imports/qs/$module"; fi
done
python3 -m unittest discover -s tests -v 2>&1 | tee .local/reports/installer-tests.log
omarchy plugin validate ./plugin
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen timeout 20s quickshell -p "$PWD/test.qml" --no-color 2>&1 | tee .local/reports/qml-tests.log
rg 'ETHEREAL TESTS: [0-9]+ passed, 0 failed' .local/reports/qml-tests.log
/usr/lib/qt6/bin/qmllint -I "$PWD/.local/imports" plugin/LockView.qml plugin/Ethereal.qml plugin/LightTrail.qml
# PanelWindow needs the native Wayland backend even when not instantiated.
timeout 15s quickshell -p "$PWD/compile.qml" --no-color 2>&1 | tee .local/reports/service-compile.log
rg 'ETHEREAL SERVICE COMPILE: PASS' .local/reports/service-compile.log
python3 - <<'PY'
from pathlib import Path
source = Path('plugin/Service.qml').read_text()
stock = Path('upstream/omarchy-lock/Service.qml').read_text()
assert source.replace('        userName: root.userName\n', '').replace('      userName: root.userName\n', '') == stock
for name in ('FingerprintModel.js', 'poster.sh'):
    assert (Path('plugin') / name).read_bytes() == (Path('upstream/omarchy-lock') / name).read_bytes()
print('Upstream authentication preserved: two display bindings only.')
PY
