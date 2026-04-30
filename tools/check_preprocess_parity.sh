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

diff_normalized() {
  local expected="$1"
  local actual="$2"
  local label="$3"
  perl -pe 's/\r$//' "$expected" > "$tmpdir/$label.expected"
  perl -pe 's/\r$//' "$actual" > "$tmpdir/$label.actual"
  diff -u "$tmpdir/$label.expected" "$tmpdir/$label.actual"
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
diff_normalized \
  testdata/naga_oil_upstream/compose_tests/expected/simple_compose.txt \
  "$tmpdir/simple_compose.wgsl" \
  simple_compose

echo "== naga_oil oracle: additional import override =="
oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/add_imports \
  --entry top.wgsl \
  --additional-import plugin \
  --output "$tmpdir/additional_import.wgsl"
diff_normalized \
  testdata/naga_oil_upstream/compose_tests/expected/additional_import.txt \
  "$tmpdir/additional_import.wgsl" \
  additional_import

echo "== naga_oil oracle: big shaderdefs =="
big_shaderdef_args=()
for i in $(seq 1 67); do
  big_shaderdef_args+=(--def "a$i")
done
oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/big_shaderdefs \
  --entry top.wgsl \
  "${big_shaderdef_args[@]}" \
  --output "$tmpdir/big_shaderdefs.wgsl"
diff_normalized \
  testdata/naga_oil_upstream/compose_tests/expected/big_shaderdefs.txt \
  "$tmpdir/big_shaderdefs.wgsl" \
  big_shaderdefs

echo "== naga_oil oracle: conditional import A =="
oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/conditional_import \
  --entry top.wgsl \
  --def USE_A \
  --output "$tmpdir/conditional_import_a.wgsl"
diff_normalized \
  testdata/naga_oil_upstream/compose_tests/expected/conditional_import_a.txt \
  "$tmpdir/conditional_import_a.wgsl" \
  conditional_import_a

echo "== naga_oil oracle: conditional import B =="
oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/conditional_import \
  --entry top.wgsl \
  --output "$tmpdir/conditional_import_b.wgsl"
diff_normalized \
  testdata/naga_oil_upstream/compose_tests/expected/conditional_import_b.txt \
  "$tmpdir/conditional_import_b.wgsl" \
  conditional_import_b

echo "== naga_oil oracle: problematic expressions =="
oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/problematic_expressions \
  --entry top.wgsl \
  --output "$tmpdir/problematic_expressions.wgsl"
diff_normalized \
  testdata/naga_oil_upstream/compose_tests/expected/problematic_expressions.txt \
  "$tmpdir/problematic_expressions.wgsl" \
  problematic_expressions

echo "== naga_oil oracle: atomics =="
oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/atomics \
  --entry top.wgsl \
  --output "$tmpdir/atomics.wgsl"
diff_normalized \
  testdata/naga_oil_upstream/compose_tests/expected/atomics.txt \
  "$tmpdir/atomics.wgsl" \
  atomics

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
diff_normalized \
  testdata/naga_oil_upstream/compose_tests/expected/err_parse.txt \
  "$tmpdir/err_parse.txt" \
  err_parse

echo "preprocess parity gate passed"
