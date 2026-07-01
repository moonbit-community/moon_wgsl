#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

tracker_wasm="/Users/zhengyu/.ai/skills/markdown-issue-tracker/assets/derive-tracker.wasm"
if [[ ! -f "$tracker_wasm" ]]; then
  echo "issue tracker index check failed: derive-tracker wasm not found: $tracker_wasm" >&2
  exit 1
fi

tmp_index="$(mktemp "${TMPDIR:-/tmp}/moon_wgsl_issue_index.XXXXXX")"
cleanup() {
  rm -f "$tmp_index"
}
trap cleanup EXIT

wasmtime run --dir ./issues::issues "$tracker_wasm" issues > "$tmp_index"
if ! diff -u "$tmp_index" issues/README.md; then
  echo "issue tracker index check failed: issues/README.md is stale" >&2
  exit 1
fi

echo "issue tracker index is fresh"
