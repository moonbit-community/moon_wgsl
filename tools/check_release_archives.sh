#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

module_version() {
  sed -n 's/^version = "\([^"]*\)"$/\1/p' "$1" | head -n 1
}

modules=(wgsl moon_wgsl_naga moon_wgsl_naga_oil moon_wgsl moon_wesl)
for module in "${modules[@]}"; do
  moon -C "modules/$module" package
done

release_root="$(mktemp -d "${TMPDIR:-/tmp}/moon_wgsl-release-archives.XXXXXX")"
trap 'rm -rf "$release_root"' EXIT
for module in "${modules[@]}"; do
  version="$(module_version "modules/$module/moon.mod")"
  archive="$repo_root/_build/publish/Milky2018-$module-$version.zip"
  unzip -tq "$archive"
  mkdir -p "$release_root/$module"
  unzip -q "$archive" -d "$release_root/$module"
done

# Force all published grammar rules to regenerate their outputs. Checking only
# the source workspace can hide a broken tool invocation behind existing files.
python3 - "$release_root" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
outputs = {module: 0 for module in ("wgsl", "moon_wesl", "moon_wgsl_naga_oil")}
for package in root.rglob("moon.pkg"):
    for block in re.findall(r"dev_build\((.*?)\)", package.read_text(), re.S):
        output = re.search(r'output:\s*"([^"]+)"', block)
        if output:
            (package.parent / output.group(1)).unlink(missing_ok=True)
            module = package.relative_to(root).parts[0]
            outputs[module] += 1
assert all(outputs.values()), outputs
print("Regenerating published parser outputs:", outputs)
PY

printf '%s\n' \
  'members = [' \
  '  "./wgsl",' \
  '  "./moon_wgsl_naga",' \
  '  "./moon_wgsl_naga_oil",' \
  '  "./moon_wgsl",' \
  '  "./moon_wesl",' \
  ']' >"$release_root/moon.work"

moon -C "$release_root" update
moon -C "$release_root" info --target all
moon -C "$release_root" check --target all --warn-list +73 --deny-warn
moon -C "$release_root" test \
  wgsl/ir \
  moon_wgsl_naga_oil/internal/import_syntax \
  moon_wesl \
  --target all
