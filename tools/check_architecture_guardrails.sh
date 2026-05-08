#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
matches_file="$(mktemp "${TMPDIR:-/tmp}/moon_wgsl_guardrail_matches.XXXXXX")"
trap 'rm -f "$matches_file"' EXIT

fail() {
  echo "architecture guardrail failed: $*" >&2
  exit 1
}

if [[ -e testdata/gpuweb_cts_ir_allowlist.txt ]]; then
  fail "official WGSL CTS IR coverage must not use a handwritten allowlist"
fi

if rg -n 'gpuweb_cts_ir_allowlist|allowlist=' tools testdata \
  --glob '!tools/check_architecture_guardrails.sh' \
  --glob '!testdata/bevy_wgsl/**' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "official WGSL CTS gate must be driven by extracted cases, not allowlist state"
fi

if rg -n 'InvalidWgslSyntax\([^)]*\) => source' \
  metadata preprocess transform compose ir parser \
  --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "WGSL parse failures must not fall back to source text"
fi

if rg -n 'F16Bits|F16Literal => \{[[:space:]]*let .*: Int' ir --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "f16 literals must use semantic float values, not integer bit placeholders"
fi

if rg -n 'Abstract\(value\).*value\.to_int\(\)|SwitchValue::I32\(value\.to_int\(\)\)' ir --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "abstract integer lowering must use checked i32/u32 conversion helpers"
fi

if rg -n -U 'registered_source\([^)]*\)[\s\S]{0,120}None => ""|registered_source\([^)]*\)[\s\S]{0,120}None => import_path' \
  compose --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "resolved registered-source lookups must not fabricate empty or import-path fallback values"
fi

if rg -n 'module_rel_path_for_module_path\([^)]*\) == ""|module_path_for_rel_path\([^)]*\),|session\.module_path_for_rel_path\(rel_path\)[[:space:]]*$' \
  compose --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "compose module path lookups must use Option, not empty-string sentinels"
fi

if ! rg -n 'remove_module_paths_for_rel_path\(module_paths, normalized_rel\)' resolver/registry_ops.mbt >/dev/null; then
  fail "registry rel_path replacement must clear stale module-path mappings first"
fi

if rg -n 'CachedQualifiedAliasBinding' compose transform ir --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "cached alias bindings must not be a separate compose binding phase"
fi

if rg -n 'pub fn WgslReferenceRewritePlan::add\(' transform --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "reference rewrite plans must not expose unscoped string-only bindings"
fi

if rg -n 'raw_top_level_items|Token::ITEM|%token<WgslRawTopLevelItem> ITEM' parser \
  --glob '*.mbt' \
  --glob '*.mbty' \
  --glob '!top_level_ast.mbt' \
  --glob '!top_level_ast_wbtest.mbt' \
  --glob '!wgsl_raw_top_level.mbt' \
  --glob '!wgsl_ast_parser.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "raw top-level item scanning must stay parser-owned, not a generated parser start"
fi

if rg -n 'text : String' parser/wgsl_raw_top_level.mbt >"$matches_file"; then
  cat "$matches_file" >&2
  fail "raw top-level staging items must carry spans, not cached source text"
fi

if rg -n 'text : String' compose/semantic_graph.mbt >"$matches_file"; then
  cat "$matches_file" >&2
  fail "semantic reference paths must derive text from structured segments"
fi

lowerer_lines="$(wc -l < ir/wgsl_lower.mbt | tr -d ' ')"
if (( lowerer_lines > 8000 )); then
  fail "IR lowerer monolith is too large: ${lowerer_lines} lines"
fi

user_call_arg_sites="$(rg -n 'self\.lower_user_function_call_arguments' ir/wgsl_lower.mbt | wc -l | tr -d ' ')"
if (( user_call_arg_sites < 2 )); then
  fail "expression-level and statement-level user function calls must share one argument-lowering path"
fi

call_arm_sites="$(rg -n 'Call\(callee, arguments\)' ir/wgsl_lower.mbt | wc -l | tr -d ' ')"
normalized_call_arg_sites="$(rg -n 'wgsl_ir_call_arguments\(arguments\)' ir/wgsl_lower.mbt | wc -l | tr -d ' ')"
if (( normalized_call_arg_sites < call_arm_sites )); then
  fail "every AST call-lowering boundary must normalize call arguments before dispatch"
fi

if rg -n -U 'let values : Array\[Handle\] = \[\][\s\S]{0,400}Statement::Call' ir/wgsl_lower.mbt >"$matches_file"; then
  cat "$matches_file" >&2
  fail "statement-level user function calls must not manually lower raw call arguments"
fi

if ! rg -n 'wgsl_ir_barrier_statement_from_call' ir/wgsl_lower.mbt >/dev/null; then
  fail "barrier builtins must lower as IR barrier statements before expression fallback"
fi

if ! rg -n 'barrier builtin has no value' ir/wgsl_lower.mbt >/dev/null; then
  fail "barrier builtins must be rejected explicitly in value position"
fi

if ! rg -n 'workgroupBarrier\(\);' ir/wgsl_emit.mbt >/dev/null; then
  fail "IR emitter must preserve WGSL control barrier calls"
fi

if ! rg -n 'storageBarrier\(\);' ir/wgsl_emit.mbt >/dev/null; then
  fail "IR emitter must preserve WGSL memory barrier calls"
fi

if rg -n 'WgslReferenceRewriteBinding \{[^}]*rel_path|WgslReferenceRewriteBinding \{[^}]*original_name' -U transform --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "reference rewrite bindings must carry WgslIrSymbolIdentity directly"
fi

if ! rg -n 'roundtrip_and_validate_wgsl "\$tmpdir/bevy_pbr_forward\.wgsl"' tools/check_wgsl_validation.sh >/dev/null; then
  fail "WGSL validation gate must IR-roundtrip full Bevy PBR forward"
fi

if ! rg -n 'roundtrip_and_validate_wgsl "\$tmpdir/mgstudio_mesh3d_forward\.wgsl"' tools/check_wgsl_validation.sh >/dev/null; then
  fail "WGSL validation gate must IR-roundtrip MGStudio mesh3d forward"
fi

if [[ ! -f testdata/wgsl_corpus_manifest.tsv ]]; then
  fail "WGSL corpus coverage must be driven by a manifest"
fi

if ! rg -n 'bash tools/check_wgsl_corpus_matrix\.sh' .github/workflows/check.yml >/dev/null; then
  fail "CI must run the manifest-driven WGSL corpus matrix"
fi

if [[ ! -f testdata/wgsl_builtin_coverage_manifest.tsv ]]; then
  fail "WGSL builtin coverage must be driven by a manifest"
fi

if ! rg -n 'bash tools/check_wgsl_builtin_coverage\.sh' .github/workflows/check.yml >/dev/null; then
  fail "CI must run the WGSL builtin coverage gate"
fi

if [[ ! -f testdata/wgsl_differential_generated_manifest.tsv ]]; then
  fail "WGSL generated differential coverage must be driven by a manifest"
fi

if ! rg -n 'bash tools/check_wgsl_differential_generated\.sh' .github/workflows/check.yml >/dev/null; then
  fail "CI must run the WGSL generated differential gate"
fi

if ! rg -n 'bash tools/check_moon_test_filters\.sh' .github/workflows/check.yml >/dev/null; then
  fail "CI must fail targeted moon test filters that match zero tests"
fi

if ! rg -n 'ir-builtin-atomic-barrier-compute' testdata/wgsl_corpus_manifest.tsv >/dev/null; then
  fail "WGSL corpus matrix must include explicit atomic and barrier builtin coverage"
fi

if ! rg -n 'ir-builtin-ray-query' testdata/wgsl_corpus_manifest.tsv >/dev/null; then
  fail "WGSL corpus matrix must include explicit ray query builtin coverage"
fi

if ! rg -n 'generated-bevy-pbr-forward' testdata/wgsl_corpus_manifest.tsv >/dev/null; then
  fail "WGSL corpus matrix must include full Bevy PBR forward"
fi

if ! rg -n 'generated-mgstudio-mesh3d-forward' testdata/wgsl_corpus_manifest.tsv >/dev/null; then
  fail "WGSL corpus matrix must include MGStudio mesh3d forward"
fi

if ! rg -n 'bash tools/check_wgpu_validation\.sh' .github/workflows/check.yml >/dev/null; then
  fail "CI must run native wgpu runtime validation"
fi

if [[ ! -f testdata/naga_oil_upstream/compose_tests/parity_manifest.tsv ]]; then
  fail "naga_oil expected fixtures must be classified by a parity manifest"
fi

if ! rg -n 'bash tools/check_naga_oil_parity_inventory\.sh' .github/workflows/check.yml >/dev/null; then
  fail "CI must run the naga_oil parity inventory gate"
fi

if ! rg -n 'bash tools/check_moon_wgsl_error_parity\.sh' .github/workflows/check.yml >/dev/null; then
  fail "CI must run moon_wgsl source-level error parity"
fi

if ! rg -n 'compute-storage-read' tools/check_wgpu_validation.sh tools/wgpu_validation \
  --glob '!tools/wgpu_validation/_build/**' \
  --glob '!tools/wgpu_validation/.mooncakes/**' >/dev/null; then
  fail "wgpu validation must include explicit read-only storage layout coverage"
fi

if ! rg -n 'moon run tools/ir_roundtrip -- --input "\$case_file" --output "\$emitted"' tools/check_official_wgsl_corpus.sh >/dev/null; then
  fail "official WGSL CTS gate must lower every extracted case through IR"
fi

echo "architecture guardrails passed"
