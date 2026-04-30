#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

oracle() {
  cargo run --quiet --manifest-path tools/naga_oil_oracle/Cargo.toml -- "$@"
}

echo "== moon_wgsl source-level preprocessing parity tests =="
moon test \
  preprocess_test.mbt \
  composer_test.mbt \
  upstream_compose_parity_test.mbt \
  bevy_wgsl_parity_test.mbt \
  naga_oil_upstream_mirror_wbtest.mbt

echo "== naga_oil oracle: simple compose =="
oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/simple \
  --entry top.wgsl \
  --output "$tmpdir/simple_compose.wgsl"
diff -u \
  testdata/naga_oil_upstream/compose_tests/expected/simple_compose.txt \
  "$tmpdir/simple_compose.wgsl"

echo "== naga_oil oracle: additional import override =="
oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/add_imports \
  --entry top.wgsl \
  --additional-import plugin \
  --output "$tmpdir/additional_import.wgsl"
diff -u \
  testdata/naga_oil_upstream/compose_tests/expected/additional_import.txt \
  "$tmpdir/additional_import.wgsl"

echo "== naga_oil oracle: parser diagnostic =="
if oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/error_test \
  --entry wgsl_parse_err.wgsl \
  --entry-only \
  --file-path-prefix tests/error_test \
  --error-output "$tmpdir/err_parse.txt"; then
  echo "expected oracle parse diagnostic failure, got success" >&2
  exit 1
fi
diff -u \
  testdata/naga_oil_upstream/compose_tests/expected/err_parse.txt \
  "$tmpdir/err_parse.txt"

echo "preprocess parity gate passed"
