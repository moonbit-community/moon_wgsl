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

echo "== naga_oil oracle: conditional missing import =="
if oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/conditional_import_fail \
  --entry top.wgsl \
  --file-path-prefix tests/conditional_import_fail \
  --error-output "$tmpdir/conditional_missing_import.txt"; then
  echo "expected oracle conditional missing import failure, got success" >&2
  exit 1
fi
diff_normalized \
  testdata/naga_oil_upstream/compose_tests/expected/conditional_missing_import.txt \
  "$tmpdir/conditional_missing_import.txt" \
  conditional_missing_import

echo "== naga_oil oracle: conditional nested missing import =="
if oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/conditional_import_fail \
  --entry top_nested.wgsl \
  --file-path-prefix tests/conditional_import_fail \
  --error-output "$tmpdir/conditional_missing_import_nested.txt"; then
  echo "expected oracle conditional nested missing import failure, got success" >&2
  exit 1
fi
diff_normalized \
  testdata/naga_oil_upstream/compose_tests/expected/conditional_missing_import_nested.txt \
  "$tmpdir/conditional_missing_import_nested.txt" \
  conditional_missing_import_nested

echo "== naga_oil oracle: duplicate imports =="
oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/dup_import \
  --entry top.wgsl \
  --output "$tmpdir/dup_import.wgsl"
diff_normalized \
  testdata/naga_oil_upstream/compose_tests/expected/dup_import.txt \
  "$tmpdir/dup_import.wgsl" \
  dup_import

echo "== naga_oil oracle: duplicate struct imports =="
oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/dup_struct_import \
  --entry top.wgsl \
  --output "$tmpdir/dup_struct_import.wgsl"
diff_normalized \
  testdata/naga_oil_upstream/compose_tests/expected/dup_struct_import.txt \
  "$tmpdir/dup_struct_import.wgsl" \
  dup_struct_import

echo "== naga_oil oracle: import in declaration =="
oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/const_in_decl \
  --entry top.wgsl \
  --output "$tmpdir/import_in_decl.wgsl"
diff_normalized \
  testdata/naga_oil_upstream/compose_tests/expected/import_in_decl.txt \
  "$tmpdir/import_in_decl.wgsl" \
  import_in_decl

echo "== naga_oil oracle: item import =="
oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/item_import \
  --entry top.wgsl \
  --output "$tmpdir/item_import.wgsl"
diff_normalized \
  testdata/naga_oil_upstream/compose_tests/expected/item_import_test.txt \
  "$tmpdir/item_import.wgsl" \
  item_import

echo "== naga_oil oracle: nested item import =="
oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/item_sub_point \
  --entry top.wgsl \
  --output "$tmpdir/item_sub_point.wgsl"
diff_normalized \
  testdata/naga_oil_upstream/compose_tests/expected/item_sub_point.txt \
  "$tmpdir/item_sub_point.wgsl" \
  item_sub_point

echo "== naga_oil oracle: quoted duplicate import name =="
oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/quoted_dup \
  --entry top.wgsl \
  --output "$tmpdir/quoted_dup.wgsl"
diff_normalized \
  testdata/naga_oil_upstream/compose_tests/expected/test_quoted_import_dup_name.txt \
  "$tmpdir/quoted_dup.wgsl" \
  quoted_dup

echo "== naga_oil oracle: shared global =="
oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/use_shared_global \
  --entry top.wgsl \
  --output "$tmpdir/use_shared_global.wgsl"
diff_normalized \
  testdata/naga_oil_upstream/compose_tests/expected/use_shared_global.txt \
  "$tmpdir/use_shared_global.wgsl" \
  use_shared_global

echo "== naga_oil oracle: imported entry point call =="
oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/call_entrypoint \
  --entry top.wgsl \
  --output "$tmpdir/wgsl_call_entrypoint.wgsl"
diff_normalized \
  testdata/naga_oil_upstream/compose_tests/expected/wgsl_call_entrypoint.txt \
  "$tmpdir/wgsl_call_entrypoint.wgsl" \
  wgsl_call_entrypoint

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

echo "== naga_oil oracle: invalid identifiers =="
oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/invalid_identifiers \
  --entry top_valid.wgsl \
  --output "$tmpdir/bad_identifiers.wgsl"
diff_normalized \
  testdata/naga_oil_upstream/compose_tests/expected/bad_identifiers.txt \
  "$tmpdir/bad_identifiers.wgsl" \
  bad_identifiers

echo "== naga_oil oracle: invalid override base =="
if oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/overrides \
  --entry top_invalid.wgsl \
  --file-path-prefix tests/overrides \
  --error-output "$tmpdir/invalid_override_base.txt"; then
  echo "expected oracle invalid override failure, got success" >&2
  exit 1
fi
diff_normalized \
  testdata/naga_oil_upstream/compose_tests/expected/invalid_override_base.txt \
  "$tmpdir/invalid_override_base.txt" \
  invalid_override_base

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

echo "== naga_oil oracle: validation diagnostic direct =="
if oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/error_test \
  --entry wgsl_valid_err.wgsl \
  --entry-only \
  --file-path-prefix tests/error_test \
  --error-output "$tmpdir/err_validation_1.txt"; then
  echo "expected oracle validation diagnostic failure, got success" >&2
  exit 1
fi
diff_normalized \
  testdata/naga_oil_upstream/compose_tests/expected/err_validation_1.txt \
  "$tmpdir/err_validation_1.txt" \
  err_validation_1

echo "== naga_oil oracle: validation diagnostic wrapped =="
if oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/error_test \
  --entry wgsl_valid_wrap.wgsl \
  --module wgsl_valid_err.wgsl \
  --additional-import valid_inc \
  --file-path-prefix tests/error_test \
  --error-output "$tmpdir/err_validation_2.txt"; then
  echo "expected oracle wrapped validation diagnostic failure, got success" >&2
  exit 1
fi
diff_normalized \
  testdata/naga_oil_upstream/compose_tests/expected/err_validation_2.txt \
  "$tmpdir/err_validation_2.txt" \
  err_validation_2

echo "preprocess parity gate passed"
