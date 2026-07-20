#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

module_version() {
  sed -n 's/^version = "\([^"]*\)"$/\1/p' "$1" | head -n 1
}

workspace_version="$(module_version modules/wgsl/moon.mod)"
wesl_version="$(module_version modules/moon_wesl/moon.mod)"

for module in wgsl moon_wgsl_naga moon_wgsl_naga_oil moon_wgsl moon_wesl; do
  moon -C "modules/$module" package
done

wgsl_archive="$repo_root/_build/publish/Milky2018-wgsl-$workspace_version.zip"
wesl_archive="$repo_root/_build/publish/Milky2018-moon_wesl-$wesl_version.zip"
unzip -tq "$wgsl_archive"
unzip -tq "$wesl_archive"

release_root="$(mktemp -d "${TMPDIR:-/tmp}/moon_wgsl-release-archives.XXXXXX")"
trap 'rm -rf "$release_root"' EXIT
mkdir -p "$release_root/wgsl" "$release_root/moon_wesl"
unzip -q "$wgsl_archive" -d "$release_root/wgsl"
unzip -q "$wesl_archive" -d "$release_root/moon_wesl"
printf '%s\n' \
  'members = [' \
  '  "./wgsl",' \
  '  "./moon_wesl",' \
  ']' >"$release_root/moon.work"

moon -C "$release_root" update
moon -C "$release_root" info --target all
moon -C "$release_root" check --target all --warn-list +73 --deny-warn
moon -C "$release_root" test \
  wgsl/ir \
  moon_wesl \
  moon_wesl/cmd/wesl \
  moon_wesl/internal/wgsl_validation \
  --target all
