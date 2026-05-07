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
  cargo run --quiet --manifest-path tools/naga_oil_oracle/Cargo.toml --bin naga_oil_oracle -- "$@"
}

diff_exact() {
  local expected="$1"
  local actual="$2"
  local label="$3"
  if LC_ALL=C grep -q $'\r' "$expected"; then
    printf 'expected fixture %s contains CR bytes; byte-exact parity fixtures must match oracle output bytes\n' "$label" >&2
    exit 1
  fi
  diff -u "$expected" "$actual"
}

diff_override_top_oracle() {
  local expected="$1"
  local actual="$2"
  if diff -u "$expected" "$actual" >/dev/null; then
    return
  fi
  assert_contains "$actual" "fn innerX_naga_oil_vrt_XNVXWIX(" override_top
  assert_contains "$actual" "return (arg" override_top
  assert_contains "$actual" "* 3f);" override_top
  assert_contains "$actual" "fn innerX_naga_oil_mod_XNVXWIX(" override_top
  assert_contains "$actual" "* 2f);" override_top
  assert_contains \
    "$actual" \
    "let _e1: f32 = innerX_naga_oil_vrt_XNVXWIX(1f);" \
    override_top
  assert_contains \
    "$actual" \
    "let _e0: f32 = outerX_naga_oil_mod_XNVXWIX();" \
    override_top
}

assert_contains() {
  local file="$1"
  local needle="$2"
  local label="$3"
  if ! grep -Fq "$needle" "$file"; then
    printf 'expected %s to contain: %s\n' "$label" "$needle" >&2
    printf 'actual %s:\n' "$label" >&2
    sed -n '1,120p' "$file" >&2
    exit 1
  fi
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
diff_exact \
  testdata/naga_oil_upstream/compose_tests/expected/simple_compose.txt \
  "$tmpdir/simple_compose.wgsl" \
  simple_compose

echo "== naga_oil oracle: additional import override =="
oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/add_imports \
  --entry top.wgsl \
  --additional-import plugin \
  --output "$tmpdir/additional_import.wgsl"
diff_exact \
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
diff_exact \
  testdata/naga_oil_upstream/compose_tests/expected/big_shaderdefs.txt \
  "$tmpdir/big_shaderdefs.wgsl" \
  big_shaderdefs

echo "== naga_oil oracle: conditional import A =="
oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/conditional_import \
  --entry top.wgsl \
  --def USE_A \
  --output "$tmpdir/conditional_import_a.wgsl"
diff_exact \
  testdata/naga_oil_upstream/compose_tests/expected/conditional_import_a.txt \
  "$tmpdir/conditional_import_a.wgsl" \
  conditional_import_a

echo "== naga_oil oracle: conditional import B =="
oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/conditional_import \
  --entry top.wgsl \
  --output "$tmpdir/conditional_import_b.wgsl"
diff_exact \
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
diff_exact \
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
diff_exact \
  testdata/naga_oil_upstream/compose_tests/expected/conditional_missing_import_nested.txt \
  "$tmpdir/conditional_missing_import_nested.txt" \
  conditional_missing_import_nested

echo "== naga_oil oracle: duplicate imports =="
oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/dup_import \
  --entry top.wgsl \
  --output "$tmpdir/dup_import.wgsl"
diff_exact \
  testdata/naga_oil_upstream/compose_tests/expected/dup_import.txt \
  "$tmpdir/dup_import.wgsl" \
  dup_import

echo "== naga_oil oracle: duplicate struct imports =="
oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/dup_struct_import \
  --entry top.wgsl \
  --output "$tmpdir/dup_struct_import.wgsl"
diff_exact \
  testdata/naga_oil_upstream/compose_tests/expected/dup_struct_import.txt \
  "$tmpdir/dup_struct_import.wgsl" \
  dup_struct_import

echo "== naga_oil oracle: import in declaration =="
oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/const_in_decl \
  --entry top.wgsl \
  --output "$tmpdir/import_in_decl.wgsl"
diff_exact \
  testdata/naga_oil_upstream/compose_tests/expected/import_in_decl.txt \
  "$tmpdir/import_in_decl.wgsl" \
  import_in_decl

echo "== naga_oil oracle: item import =="
oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/item_import \
  --entry top.wgsl \
  --output "$tmpdir/item_import.wgsl"
diff_exact \
  testdata/naga_oil_upstream/compose_tests/expected/item_import_test.txt \
  "$tmpdir/item_import.wgsl" \
  item_import

echo "== naga_oil oracle: nested item import =="
oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/item_sub_point \
  --entry top.wgsl \
  --output "$tmpdir/item_sub_point.wgsl"
diff_exact \
  testdata/naga_oil_upstream/compose_tests/expected/item_sub_point.txt \
  "$tmpdir/item_sub_point.wgsl" \
  item_sub_point

echo "== naga_oil oracle: quoted duplicate import name =="
oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/quoted_dup \
  --entry top.wgsl \
  --output "$tmpdir/quoted_dup.wgsl"
diff_exact \
  testdata/naga_oil_upstream/compose_tests/expected/test_quoted_import_dup_name.txt \
  "$tmpdir/quoted_dup.wgsl" \
  quoted_dup

echo "== naga_oil oracle: shared global =="
oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/use_shared_global \
  --entry top.wgsl \
  --output "$tmpdir/use_shared_global.wgsl"
diff_exact \
  testdata/naga_oil_upstream/compose_tests/expected/use_shared_global.txt \
  "$tmpdir/use_shared_global.wgsl" \
  use_shared_global

echo "== naga_oil oracle: imported entry point call =="
oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/call_entrypoint \
  --entry top.wgsl \
  --output "$tmpdir/wgsl_call_entrypoint.wgsl"
diff_exact \
  testdata/naga_oil_upstream/compose_tests/expected/wgsl_call_entrypoint.txt \
  "$tmpdir/wgsl_call_entrypoint.wgsl" \
  wgsl_call_entrypoint

echo "== naga_oil oracle: WGSL calls GLSL module =="
oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/glsl \
  --entry top.wgsl \
  --output "$tmpdir/wgsl_call_glsl.wgsl"
diff_exact \
  testdata/naga_oil_upstream/compose_tests/expected/wgsl_call_glsl.txt \
  "$tmpdir/wgsl_call_glsl.wgsl" \
  wgsl_call_glsl

echo "== naga_oil oracle: GLSL calls WGSL module =="
oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/glsl \
  --entry top.glsl \
  --shader-type glsl-vertex \
  --output "$tmpdir/glsl_call_wgsl.wgsl"
diff_exact \
  testdata/naga_oil_upstream/compose_tests/expected/glsl_call_wgsl.txt \
  "$tmpdir/glsl_call_wgsl.wgsl" \
  glsl_call_wgsl

echo "== naga_oil oracle: GLSL imports GLSL const =="
oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/glsl_const_import \
  --entry top.glsl \
  --shader-type glsl-fragment \
  --module consts.glsl \
  --output "$tmpdir/glsl_const_import.wgsl"
diff_exact \
  testdata/naga_oil_upstream/compose_tests/expected/glsl_const_import.txt \
  "$tmpdir/glsl_const_import.wgsl" \
  glsl_const_import

echo "== naga_oil oracle: WGSL imports GLSL const =="
oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/glsl_const_import \
  --entry top.wgsl \
  --module consts.glsl \
  --output "$tmpdir/glsl_wgsl_const_import.wgsl"
diff_exact \
  testdata/naga_oil_upstream/compose_tests/expected/glsl_wgsl_const_import.txt \
  "$tmpdir/glsl_wgsl_const_import.wgsl" \
  glsl_wgsl_const_import

echo "== naga_oil oracle: GLSL imports WGSL const =="
oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/glsl_const_import \
  --entry top.glsl \
  --shader-type glsl-fragment \
  --module consts.wgsl \
  --output "$tmpdir/wgsl_glsl_const_import.wgsl"
diff_exact \
  testdata/naga_oil_upstream/compose_tests/expected/wgsl_glsl_const_import.txt \
  "$tmpdir/wgsl_glsl_const_import.wgsl" \
  wgsl_glsl_const_import

echo "== naga_oil oracle: basic GLSL frontend check =="
oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/glsl \
  --entry basic.glsl \
  --shader-type glsl-fragment \
  --entry-only \
  --check-only

echo "== naga_oil oracle: problematic expressions =="
oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/problematic_expressions \
  --entry top.wgsl \
  --output "$tmpdir/problematic_expressions.wgsl"
diff_exact \
  testdata/naga_oil_upstream/compose_tests/expected/problematic_expressions.txt \
  "$tmpdir/problematic_expressions.wgsl" \
  problematic_expressions

echo "== naga_oil oracle: atomics =="
oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/atomics \
  --entry top.wgsl \
  --output "$tmpdir/atomics.wgsl"
diff_exact \
  testdata/naga_oil_upstream/compose_tests/expected/atomics.txt \
  "$tmpdir/atomics.wgsl" \
  atomics

echo "== naga_oil oracle: override top =="
oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/overrides \
  --entry top.wgsl \
  --output "$tmpdir/override_top.wgsl"
diff_override_top_oracle \
  testdata/naga_oil_upstream/compose_tests/expected/override_top.txt \
  "$tmpdir/override_top.wgsl"

echo "== naga_oil oracle: invalid identifiers =="
oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/invalid_identifiers \
  --entry top_valid.wgsl \
  --output "$tmpdir/bad_identifiers.wgsl"
diff_exact \
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
diff_exact \
  testdata/naga_oil_upstream/compose_tests/expected/invalid_override_base.txt \
  "$tmpdir/invalid_override_base.txt" \
  invalid_override_base

echo "== naga_oil oracle: missing import in module =="
if oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/error_test \
  --entry wgsl_parse_err.wgsl \
  --module include.wgsl \
  --file-path-prefix tests/error_test \
  --error-output "$tmpdir/missing_import.txt"; then
  echo "expected oracle missing import failure, got success" >&2
  exit 1
fi
diff_exact \
  testdata/naga_oil_upstream/compose_tests/expected/missing_import.txt \
  "$tmpdir/missing_import.txt" \
  missing_import

echo "== naga_oil oracle: dual-source blending =="
oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/dual_source_blending \
  --entry blending.wgsl \
  --capability dual-source-blending \
  --output "$tmpdir/wgsl_dual_source_blending.wgsl"
diff_exact \
  testdata/naga_oil_upstream/compose_tests/expected/wgsl_dual_source_blending.txt \
  "$tmpdir/wgsl_dual_source_blending.wgsl" \
  wgsl_dual_source_blending

echo "== naga_oil oracle: ray query compile check =="
oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/raycast \
  --entry top.wgsl \
  --capability ray-query \
  --check-only

echo "== naga_oil oracle: diagnostic filters upstream failure =="
if oracle \
  --fixture-root testdata/naga_oil_upstream/compose_tests/diagnostic_filters \
  --entry top.wgsl \
  --check-only \
  --error-output "$tmpdir/diagnostic_filters_error.txt"; then
  echo "expected oracle diagnostic-filter failure, got success" >&2
  exit 1
fi
assert_contains \
  "$tmpdir/diagnostic_filters_error.txt" \
  "invalid function call" \
  diagnostic_filters
assert_contains \
  "$tmpdir/diagnostic_filters_error.txt" \
  "Requires 3 arguments, but 0 are provided" \
  diagnostic_filters

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
diff_exact \
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
diff_exact \
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
diff_exact \
  testdata/naga_oil_upstream/compose_tests/expected/err_validation_2.txt \
  "$tmpdir/err_validation_2.txt" \
  err_validation_2

echo "== moon_wgsl source-level error parity =="
tools/check_moon_wgsl_error_parity.sh

echo "== naga_oil oracle: expected fixture coverage inventory =="
tools/check_naga_oil_parity_inventory.sh

tools/check_wgsl_validation.sh

echo "preprocess parity gate passed"
