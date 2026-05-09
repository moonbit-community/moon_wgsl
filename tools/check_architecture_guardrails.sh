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

if rg -n 'reference_rename_plan|global_declaration_rename_plan' transform compose \
  --glob '*.mbt' \
  --glob '!*.mbti' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "identity-backed composer bindings must not be downgraded into rename plans"
fi

if rg -n 'add_symbol_binding' compose transform \
  --glob '*.mbt' \
  --glob '!*.mbti' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "symbol rewrite plans must receive structured reference paths, not string bindings"
fi

if rg -n 'from_name : String|to_name : String|identity : WgslIrSymbolIdentity\?' compose/session.mbt >"$matches_file"; then
  cat "$matches_file" >&2
  fail "cross-phase compose/transform bindings must preserve structured reference paths and non-optional symbol targets"
fi

if rg -n -U 'WgslReferenceRewriteBinding \{[^}]*from_name|WgslReferenceRewriteBinding \{[^}]*to_name' transform/wgsl_binding.mbt >"$matches_file"; then
  cat "$matches_file" >&2
  fail "transform reference rewrite bindings must carry WgslReferencePath plus final symbol target"
fi

if rg -n 'resolved_to_name|reference_paths : @hashset\.HashSet\[String\]' compose \
  --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "compose semantic facts and live bindings must not flatten semantic objects into string-only phase state"
fi

if rg -n 'WgslSemanticReferencePath|to_transform_path|wgsl_compose_reference_path_required' compose transform \
  --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "compose and transform must share common WgslReferencePath without conversion helpers or internal aborts"
fi

if rg -n 'struct WgslReferencePath' compose transform \
  --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "WgslReferencePath must have one definition in common"
fi

if rg -n 'wgsl_compose_binding_key|wgsl_compose_binding_scope_key' compose \
  --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "compose binding keys must be typed key objects, not free string key helpers"
fi

if rg -n 'identity : WgslIrSymbolIdentity\?' transform/wgsl_binding.mbt >"$matches_file"; then
  cat "$matches_file" >&2
  fail "plain rename rules must not carry optional identity as a pseudo binding model"
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

if ! rg -n 'extract_gpuweb_cts_invalid_static_wgsl\.mjs' tools/check_official_wgsl_corpus.sh >/dev/null; then
  fail "official WGSL CTS gate must include invalid WGSL rejection coverage"
fi

if [[ ! -f testdata/gpuweb_cts_invalid_accepted_by_oracle.txt ]]; then
  fail "official WGSL invalid oracle-accepted cases must be manifest-owned"
fi

if ! rg -n 'validate_wgsl_ir_module\(shader_module\)' ir/wgsl_emit.mbt >/dev/null; then
  fail "WGSL IR emission must run internal IR validation before writing source"
fi

if rg -n 'pub (fn (parse_wgsl_module_to_ir|parse_wgsl_module_to_ir_with_generated_imports|lower_wgsl_translation_unit_to_ir|lower_wgsl_translation_unit_to_ir_with_generated_imports|emit_wgsl_module_from_ir|emit_wgsl_module_from_ir_roots)|suberror WgslIr(Lower|Emit)Error)' ir \
  --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "raw WGSL IR lower/emit APIs must remain internal; public callers must use the validated IR pipeline"
fi

if rg -n 'parse_wgsl_module_to_ir|lower_wgsl_translation_unit_to_ir|emit_wgsl_module_from_ir|WgslIr(Lower|Emit)Error|WgslIrEmitFilter|sanitize_wgsl_ir_identifier' ir/pkg.generated.mbti >"$matches_file"; then
  cat "$matches_file" >&2
  fail "IR public interface must only expose validated pipeline entrypoints, not raw lower/emit internals"
fi

if ! rg -n 'roundtrip_wgsl_source_via_ir_with_generated_imports' compose/pipeline.mbt >/dev/null; then
  fail "compose final WGSL output must enter the unified IR roundtrip pipeline"
fi

session_fields="$(sed -n '/priv struct WgslComposeSession {/,/^}/p' compose/session.mbt)"
if ! printf '%s\n' "$session_fields" | rg -n 'symbols : WgslComposeSymbolTable' >/dev/null; then
  fail "compose session must own symbol/provenance facts through WgslComposeSymbolTable"
fi
if printf '%s\n' "$session_fields" | rg -n 'source_origins|assigned_final_names|final_names|virtual_override_final_names' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "compose session must not keep symbol/source-origin facts outside WgslComposeSymbolTable"
fi

resolved_fields="$(sed -n '/priv struct WgslResolvedComposeSource {/,/^}/p' compose/pipeline.mbt)"
if printf '%s\n' "$resolved_fields" | rg -n 'source_origins|virtual_override_generated_imports' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "resolved compose output must carry the symbol table instead of duplicated provenance arrays"
fi

if ! rg -n 'WgslComposeSymbolTable::generated_import_provenance' compose/pipeline.mbt >/dev/null; then
  fail "generated import provenance must derive from the compose symbol table"
fi

if ! rg -n 'validate_wgsl_ir_module\(reparsed\)' ir/wgsl_pipeline.mbt >/dev/null; then
  fail "unified IR pipeline must validate emitted WGSL after reparsing it into IR"
fi

if rg -n 'normalize_wgsl_output_identifiers|normalize_wgsl_composed_declarations_with_binding_plan|unresolved_wgsl_semantic_namespace_reference' compose \
  --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "compose finalization must not use source-level semantic normalization or namespace scans"
fi

if rg -n 'emit_wgsl_tree_shaken_source_strict' export --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "export tree shaking must use IR reachability, not source-level declaration extraction"
fi

if rg -n 'pub fn (emit_wgsl_tree_shaken_source_strict|normalize_wgsl_output_identifiers|invalid_wgsl_struct_member_identifier|normalize_wgsl_composed_declarations|normalize_wgsl_composed_declarations_with_binding_plan)|pub struct WgslTreeShakenSource' transform \
  --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "transform must not expose source-level WGSL semantic rewrite/tree-shake APIs"
fi

if rg -n 'emit_wgsl_tree_shaken_source_strict|normalize_wgsl_output_identifiers|invalid_wgsl_struct_member_identifier|normalize_wgsl_composed_declarations|WgslTreeShakenSource' transform/pkg.generated.mbti >"$matches_file"; then
  cat "$matches_file" >&2
  fail "transform public interface must not expose source-level WGSL semantic rewrite/tree-shake APIs"
fi

if rg -n 'parse_wgsl_module_to_ir|emit_wgsl_module_from_ir' tools/ir_roundtrip tools/wgsl_validation_cases \
  --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "WGSL validation tools must use the unified IR roundtrip pipeline"
fi

if [[ -f testdata/external_wgsl_corpus_skips.tsv ]]; then
  fail "external WGSL corpus must not use a skipped-file manifest"
fi

if [[ -f testdata/external_wgsl_corpus_expected_failures.tsv ]]; then
  fail "external WGSL corpus must not retain an expected-failure manifest"
fi

if [[ ! -f testdata/external_wgsl_corpus_expected_invalid.tsv ]]; then
  fail "external WGSL standalone-invalid files must be classified by an expected-invalid manifest"
fi

if ! rg -n 'skipped=0' tools/check_external_wgsl_corpus.sh >/dev/null; then
  fail "external WGSL corpus gate must report zero skipped files"
fi

if [[ ! -f testdata/external_wgsl_corpus_profiles.tsv ]]; then
  fail "external WGSL corpus profiles must be manifest-owned"
fi

if ! rg -n 'EXTERNAL_WGSL_CORPUS_PROFILE_MANIFEST' tools/check_external_wgsl_corpus.sh >/dev/null; then
  fail "external WGSL corpus gate must load explicit shader profiles"
fi

if ! rg -n -- '--value-def NAME=VALUE' tools/compose_case/main.mbt >/dev/null; then
  fail "compose_case must support typed value defines for real pipeline profiles"
fi

if rg -n 'byte-exception|oracle-byte-exception|exception row|normalization exception' \
  testdata/naga_oil_upstream/compose_tests/parity_manifest.tsv \
  tools/check_moon_wgsl_byte_parity.sh \
  tools/check_naga_oil_parity_inventory.sh >"$matches_file"; then
  cat "$matches_file" >&2
  fail "naga_oil byte parity gates must not use exception or normalization classes"
fi

if rg -n 'headline|first-line|first line' \
  testdata/naga_oil_upstream/compose_tests/parity_manifest.tsv \
  tools/check_moon_wgsl_error_parity.sh >"$matches_file"; then
  cat "$matches_file" >&2
  fail "naga_oil parity gates must not use diagnostic-headline classes"
fi

if rg -n -- '--runtime-valid' tools/check_moon_wgsl_byte_parity.sh >/dev/null && \
  ! rg -n 'check_runtime_valid_case' tools/check_moon_wgsl_byte_parity.sh >/dev/null; then
  fail "byte parity must use default upstream writer output; runtime-valid mode is allowed only for the atomics validation cross-check"
fi

if ! rg -n 'compose_runtime_valid_roundtrip_case' tools/check_ir_roundtrip_corpus.sh >/dev/null; then
  fail "IR roundtrip validation must keep runtime-valid compose cases explicit"
fi

if ! rg -n 'compose_wgsl_runtime_valid' tools/wgsl_validation_cases/main.mbt >/dev/null; then
  fail "WGSL validation generators must use the explicit runtime-valid compose path"
fi

if ! rg -n 'bash tools/check_external_wgsl_corpus\.sh' .github/workflows/check.yml >/dev/null; then
  fail "CI must run the external real-project WGSL corpus gate"
fi

if ! rg -n 'expected-failures=0' tools/check_external_wgsl_corpus.sh >/dev/null; then
  fail "external WGSL corpus gate must report zero expected failures"
fi

if ! rg -n 'diff -u "\$expected_invalid_expected_keys" "\$expected_invalid_actual_keys"' tools/check_external_wgsl_corpus.sh >/dev/null; then
  fail "external WGSL corpus gate must fail unknown or stale expected-invalid cases"
fi

echo "architecture guardrails passed"
