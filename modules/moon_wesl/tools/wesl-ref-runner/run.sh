#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-/tmp/moon_wesl_wesl_ref_runner_target}"
exec cargo run --quiet --manifest-path "$repo_root/tools/wesl-ref-runner/Cargo.toml" -- "$@"
