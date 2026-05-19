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

if rg -n 'WGSL_CTS_REF:-main|WGSL_CTS_MIN_|min_parse_cases|min_ir_cases|min_template|min_execution|min_invalid|expected at least|contains only|produced only' \
  tools/check_official_wgsl_corpus.sh >"$matches_file"; then
  cat "$matches_file" >&2
  fail "official WGSL CTS gate must use a pinned ref and exact counts, not moving-main or minimum thresholds"
fi

if ! rg -n 'WGSL_CTS_EXPECTED_PARSE_CASES|expected_parse_cases' tools/check_official_wgsl_corpus.sh >/dev/null; then
  fail "official WGSL CTS gate must own exact static valid counts"
fi

if ! rg -n 'WGSL_CTS_EXPECTED_INVALID_ORACLE_ACCEPTED_CASES|expected_invalid_oracle_accepted_cases' tools/check_official_wgsl_corpus.sh >/dev/null; then
  fail "official WGSL CTS gate must own exact invalid accepted-by-oracle counts"
fi

if ! rg -n 'load_official_cts_id_manifest' tools/check_official_wgsl_corpus.sh >/dev/null; then
  fail "official WGSL CTS oracle manifest IDs must be loaded through a schema-checking helper"
fi

if ! rg -n 'load_official_cts_extracted_manifest' tools/check_official_wgsl_corpus.sh >/dev/null; then
  fail "official WGSL CTS extractor manifests must be schema-checked against generated WGSL files"
fi

if rg -n 'find "\$.*cases_dir" -name .*wc -l|find "\$.*cases_dir" -name .* -exec basename' tools/check_official_wgsl_corpus.sh |
  rg -v 'file_ids' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "official WGSL CTS case IDs must come from validated extractor manifests, not raw file scans"
fi

if rg -n 'grep -v -E .*\$.*(blocked_by_oracle|accepted_by_oracle)' tools/check_official_wgsl_corpus.sh >"$matches_file"; then
  cat "$matches_file" >&2
  fail "official WGSL CTS oracle manifests must reject malformed or duplicate IDs instead of raw grep filtering"
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

if rg -n '_ => AddressSpace::Private' ir --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "WGSL address-space lowering must reject unknown tokens instead of falling back"
fi

if rg -n -U 'fn wgsl_ir_storage_access_from_name[\s\S]*_ => StorageAccess::load\(\)' ir --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "WGSL storage-access lowering must reject unknown tokens instead of falling back"
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

if [[ ! -f resolver/module_path_policy.mbt ]]; then
  fail "resolver module path inference/defaulting policy must have a single owner"
fi

if rg -n 'fn wgsl_module_path_from_rel_path|fn wgsl_module_path_to_rel_path|default_shader_rel_path_for_module_path' \
  resolver/registry_ops.mbt resolver/module_resolution.mbt >"$matches_file"; then
  cat "$matches_file" >&2
  fail "resolver module path inference/defaulting policy must stay in resolver/module_path_policy.mbt"
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

if [[ ! -f ast_analysis/wgsl_ast_identifiers.mbt ]]; then
  fail "AST semantic identifier collection must live outside the syntax-only ast package"
fi

if rg -n 'collect_wgsl_.*identifier_nodes' ast \
  --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "AST package must not own semantic identifier collection helpers"
fi

if find metadata -maxdepth 1 -name 'source_directive_items*.mbt' | rg . >"$matches_file"; then
  cat "$matches_file" >&2
  fail "source-level WGSL directive item parsing must be owned by the directive package, not metadata"
fi

if [[ ! -f directive/source_directive_items.mbt ]]; then
  fail "directive package must own source-level WGSL directive item parsing"
fi

if rg -n 'text : String' compose/semantic_graph.mbt >"$matches_file"; then
  cat "$matches_file" >&2
  fail "semantic reference paths must derive text from structured segments"
fi

required_ir_split_files=(
  ir/wgsl_lower_core.mbt
  ir/wgsl_lower_globals.mbt
  ir/wgsl_lower_functions.mbt
  ir/wgsl_lower_updates.mbt
  ir/wgsl_lower_type_inference.mbt
  ir/wgsl_lower_expr_parser.mbt
  ir/wgsl_lower_global_expressions.mbt
  ir/wgsl_lower_function_expressions.mbt
  ir/wgsl_lower_calls.mbt
  ir/wgsl_lower_expression_results.mbt
  ir/wgsl_lower_expression_types.mbt
  ir/wgsl_lower_const_eval.mbt
  ir/wgsl_lower_materialization.mbt
  ir/wgsl_lower_statements.mbt
  ir/wgsl_emit_writer_policy.mbt
  ir/wgsl_emit_runtime_writer.mbt
  ir/wgsl_emit_naga_oil_writer.mbt
  ir/wgsl_naga_writer_module.mbt
  ir/wgsl_emit_final_name_plan.mbt
  ir/wgsl_emit_module.mbt
  ir/wgsl_emit_declarations.mbt
  ir/wgsl_emit_functions.mbt
  ir/wgsl_emit_types.mbt
  ir/wgsl_emit_attributes_literals.mbt
  ir/wgsl_emit_names.mbt
  ir/wgsl_emit_builtins.mbt
  ir/wgsl_emit_expressions.mbt
  ir/wgsl_emit_expression_types.mbt
  ir/wgsl_emit_statements.mbt
  ir/validation.mbt
  ir/validation_types.mbt
  ir/validation_statements.mbt
  ir/validation_expressions.mbt
  ir/validation_signatures.mbt
  ir/validation_expression_types.mbt
  ir/validation_layout.mbt
  ir/validation_handles.mbt
)
for split_file in "${required_ir_split_files[@]}"; do
  if [[ ! -f "$split_file" ]]; then
    fail "IR lower/emit responsibilities must stay split: missing ${split_file}"
  fi
done

if [[ -f ir/wgsl_lower.mbt ]]; then
  fail "IR lowerer monolith must not be reintroduced as ir/wgsl_lower.mbt"
fi

if [[ -f parser/wgsl_ast_expr_type.mbt ]]; then
  fail "parser expression/type monolith must stay split; parser/wgsl_ast_expr_type.mbt must not be reintroduced"
fi

if [[ ! -f parser/pkg.mbti ]]; then
  fail "parser package must own an explicit public interface whitelist in parser/pkg.mbti"
fi

if rg -n 'pub (fn (block|const_assert_expr|function_args|function_result|source_directive|struct_members|template_list|type_alias_tail|type_ref|typed_initializer_tail)|suberror ParseError|.*enum Token|.*enum TokenKind)' parser/pkg.mbti >"$matches_file"; then
  cat "$matches_file" >&2
  fail "parser public interface must not expose moonyacc-generated rule entrypoints or tokens"
fi

required_parser_split_files=(
  parser/wgsl_expr_tokens.mbt
  parser/wgsl_expr_node_parser.mbt
  parser/wgsl_decl_fragment_parser.mbt
  parser/wgsl_type_ref_parser.mbt
)
for parser_split_file in "${required_parser_split_files[@]}"; do
  if [[ ! -f "$parser_split_file" ]]; then
    fail "parser expression/type responsibilities must stay split: missing ${parser_split_file}"
  fi
done

while IFS= read -r source_file; do
  source_lines="$(wc -l < "$source_file" | tr -d ' ')"
  if (( source_lines > 1600 )); then
    fail "hand-written source file is too large: ${source_file} has ${source_lines} lines"
  fi
done < <(
  find ast common compose directive export import_syntax ir lex metadata parser preprocess resolver transform \
    -name '*.mbt' \
    ! -name '*_wbtest.mbt' \
    ! -name '*_test.mbt' \
    ! -name '*generated*.mbt' \
    ! -name 'xid.mbt' \
    ! -name 'regex_word.mbt' \
    -print
)

while IFS= read -r source_file; do
  source_lines="$(wc -l < "$source_file" | tr -d ' ')"
  if (( source_lines > 1600 )); then
    fail "tracked hand-written MoonBit file is too large: ${source_file} has ${source_lines} lines"
  fi
done < <(
  git ls-files '*.mbt' |
    rg -v '(^|/)([^/]*generated[^/]*\.mbt|xid\.mbt|regex_word\.mbt)$'
)

for split_file in ir/wgsl_lower_*.mbt; do
  if [[ "$split_file" == *_wbtest.mbt ]]; then
    continue
  fi
  split_lines="$(wc -l < "$split_file" | tr -d ' ')"
  if (( split_lines > 1500 )); then
    fail "IR lowerer split file is too large: ${split_file} has ${split_lines} lines"
  fi
done

if ! rg -n 'parse_wgsl_module_to_ir' ir/wgsl_lower_core.mbt >/dev/null; then
  fail "IR lowerer core must own the module lowering entrypoint"
fi

if ! rg -n 'lower_global_expression_ref' ir/wgsl_lower_global_expressions.mbt >/dev/null; then
  fail "IR lowerer global expression lowering must stay in its own split file"
fi

if ! rg -n 'lower_function_expression_ref' ir/wgsl_lower_function_expressions.mbt >/dev/null; then
  fail "IR lowerer function expression lowering must stay in its own split file"
fi

emitter_lines="$(wc -l < ir/wgsl_emit.mbt | tr -d ' ')"
if (( emitter_lines > 250 )); then
  fail "IR emitter core must stay as entrypoint wiring only: ${emitter_lines} lines"
fi

for split_file in ir/wgsl_emit_*.mbt; do
  if [[ "$split_file" == *_wbtest.mbt ]]; then
    continue
  fi
  split_lines="$(wc -l < "$split_file" | tr -d ' ')"
  if (( split_lines > 1700 )); then
    fail "IR emitter split file is too large: ${split_file} has ${split_lines} lines"
  fi
done

if ! rg -n 'priv struct WgslIrEmitOptions' ir/wgsl_emit_writer_policy.mbt >/dev/null; then
  fail "IR emitter writer policy must own WgslIrEmitOptions"
fi

if rg -n 'priv struct WgslIrEmitOptions|fn WgslIrEmitOptions::naga_oil_writer_compatible' ir/wgsl_emit.mbt ir/wgsl_emit_module.mbt >/dev/null; then
  fail "IR emitter core/module ordering must not own writer policy"
fi

if rg -n 'order_functions_by_naga_reachability|push_naga|naga_reachable|collect_naga|naga_generated_import' ir/wgsl_emit_*.mbt >/dev/null; then
  fail "Naga function ordering must live in the Naga-compatible module view, not emitter options or emitter helpers"
fi

if ! rg -n 'fn wgsl_ir_collect_block_function_calls' ir/wgsl_naga_compat_dependencies.mbt >/dev/null; then
  fail "Naga-compatible dependency layer must own function body traversal"
fi

if [[ -f ir/wgsl_emit_name_table.mbt ]]; then
  fail "final name planning must live in ir/wgsl_emit_final_name_plan.mbt, not the old name-table file"
fi

if rg -n 'build_wgsl_ir_naga_writer_final_name_plan' ir/wgsl_emit_final_name_plan.mbt >/dev/null; then
  fail "Naga-compatible final name allocation must not live in the runtime final-name plan"
fi

if ! rg -n 'build_wgsl_ir_naga_writer_final_name_plan' ir/wgsl_naga_compat_names.mbt >/dev/null; then
  fail "Naga-compatible name layer must own final name allocation"
fi

if ! rg -n 'priv struct WgslIrNagaCompatDeclarationArena' ir/wgsl_naga_compat_declarations.mbt >/dev/null; then
  fail "Naga-compatible declaration layer must own declaration arena slots"
fi

if ! rg -n 'contains_type_declaration|contains_constant_declaration|contains_global_variable_declaration|contains_function_declaration' ir/wgsl_naga_compat_declarations.mbt >/dev/null; then
  fail "Naga writer module declaration membership must come from declaration arena slots"
fi

if ! rg -n 'module_\.contains_type_declaration|module_\.contains_constant_declaration|module_\.contains_global_variable_declaration|module_\.contains_function_declaration' ir/wgsl_emit_module.mbt >/dev/null; then
  fail "Naga writer emission must consult declaration arena membership instead of generic filter membership"
fi

user_call_arg_sites="$(rg -n 'self\.lower_user_function_call_arguments' ir --glob '*.mbt' | wc -l | tr -d ' ')"
if (( user_call_arg_sites < 2 )); then
  fail "expression-level and statement-level user function calls must share one argument-lowering path"
fi

call_arm_sites="$(rg -n 'Call\(callee, arguments\)' ir --glob '*.mbt' | wc -l | tr -d ' ')"
normalized_call_arg_sites="$(rg -n 'wgsl_ir_call_arguments\(arguments\)' ir --glob '*.mbt' | wc -l | tr -d ' ')"
if (( normalized_call_arg_sites < call_arm_sites )); then
  fail "every AST call-lowering boundary must normalize call arguments before dispatch"
fi

if rg -n -U 'let values : Array\[Handle\] = \[\][\s\S]{0,400}Statement::Call' ir --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "statement-level user function calls must not manually lower raw call arguments"
fi

if ! rg -n 'wgsl_ir_barrier_statement_from_call' ir --glob '*.mbt' >/dev/null; then
  fail "barrier builtins must lower as IR barrier statements before expression fallback"
fi

if ! rg -n 'barrier builtin has no value' ir --glob '*.mbt' >/dev/null; then
  fail "barrier builtins must be rejected explicitly in value position"
fi

if ! rg -n 'workgroupBarrier\(\);' ir --glob '*.mbt' >/dev/null; then
  fail "IR emitter must preserve WGSL control barrier calls"
fi

if ! rg -n 'storageBarrier\(\);' ir --glob '*.mbt' >/dev/null; then
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

if [[ -f common/types.mbt ]]; then
  fail "common DTO ownership must stay split by domain, not collapse back into common/types.mbt"
fi

required_common_domain_files=(
  common/shader_defs.mbt
  common/import_types.mbt
  common/directive_types.mbt
  common/preprocess_types.mbt
  common/source_types.mbt
  common/diagnostic_types.mbt
  common/compose_export_types.mbt
)
for common_file in "${required_common_domain_files[@]}"; do
  if [[ ! -f "$common_file" ]]; then
    fail "common DTO ownership split is missing ${common_file}"
  fi
done

if rg -n -U 'WgslReferenceRewriteBinding \{[^}]*from_name|WgslReferenceRewriteBinding \{[^}]*to_name' transform/wgsl_binding.mbt >"$matches_file"; then
  cat "$matches_file" >&2
  fail "transform reference rewrite bindings must carry WgslReferencePath plus final symbol target"
fi

if rg -n 'resolved_to_name|reference_paths : @set\.Set\[String\]' compose \
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

if ! rg -n 'WGSL_CORPUS_EXPECTED_CASES|expected_case_count' tools/check_wgsl_corpus_matrix.sh >/dev/null; then
  fail "WGSL corpus matrix must exact-gate its case count"
fi

if ! rg -n 'WGSL_CORPUS_EXPECTED_RUNTIME_VALID_COMPOSE_CASES|runtime-valid compose row has.*expected 1' tools/check_wgsl_corpus_matrix.sh >/dev/null; then
  fail "WGSL corpus matrix must schema-check and exact-gate runtime-valid compose cases"
fi

if rg -n 'manifest row has.*expected 9|NF < 9|grep -v -E .*\$runtime_valid_compose_manifest' tools/check_wgsl_corpus_matrix.sh >"$matches_file"; then
  if rg -n 'NF < 9|grep -v -E .*\$runtime_valid_compose_manifest' "$matches_file" >/dev/null; then
    cat "$matches_file" >&2
    fail "WGSL corpus matrix manifests must use exact schema checks instead of weak filtering"
  fi
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

if [[ ! -f tools/generate_wgsl_differential_case.mjs ]]; then
  fail "WGSL generated differential source catalog must be owned by the deterministic generator"
fi

if ! rg -n 'node "\$generator" --list' tools/check_wgsl_differential_generated.sh >/dev/null; then
  fail "WGSL generated differential gate must compare manifest case ids against the generator catalog"
fi

if ! rg -n 'bash tools/check_wgsl_differential_generated\.sh' .github/workflows/check.yml >/dev/null; then
  fail "CI must run the WGSL generated differential gate"
fi

if [[ ! -f testdata/wgsl_corpus_runtime_valid_compose.txt ]]; then
  fail "WGSL corpus matrix runtime-valid compose cases must be manifest-owned"
fi

if ! rg -n 'WGSL_CORPUS_RUNTIME_VALID_COMPOSE_MANIFEST' tools/check_wgsl_corpus_matrix.sh >/dev/null; then
  fail "WGSL corpus matrix must load explicit runtime-valid compose cases"
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

if ! rg -n 'extract_gpuweb_cts_template_wgsl\.mjs' tools/check_official_wgsl_corpus.sh >/dev/null; then
  fail "official WGSL CTS gate must include template-generated WGSL coverage"
fi

if [[ ! -f testdata/gpuweb_cts_invalid_accepted_by_oracle.txt ]]; then
  fail "official WGSL invalid oracle-accepted cases must be manifest-owned"
fi

if [[ ! -f testdata/gpuweb_cts_template_ir_blocked_by_oracle.txt ]]; then
  fail "official WGSL template IR oracle-blocked cases must be manifest-owned"
fi

if [[ ! -f testdata/gpuweb_cts_template_invalid_accepted_by_oracle.txt ]]; then
  fail "official WGSL template invalid oracle-accepted cases must be manifest-owned"
fi

if ! rg -n 'validate_wgsl_ir_module\(self\.shader_module\)' ir/wgsl_emit_runtime_writer.mbt >/dev/null; then
  fail "runtime WGSL writer backend must run internal IR validation before writing source"
fi

if ! rg -n 'validate_wgsl_ir_module\(self\.shader_module\)' ir/wgsl_emit_naga_oil_writer.mbt >/dev/null; then
  fail "naga-oil WGSL writer backend must run internal IR validation before writing source"
fi

if ! rg -n 'build_wgsl_ir_naga_writer_module\(' ir/wgsl_emit_naga_oil_writer.mbt >/dev/null; then
  fail "naga-oil WGSL writer backend must build a Naga-compatible module view before emission"
fi

if ! rg -n 'naga_writer_module: Some\(self\.view\)' ir/wgsl_emit_naga_oil_writer.mbt >/dev/null; then
  fail "naga-oil WGSL writer backend must emit through the Naga-compatible module view"
fi

if [[ ! -f ir/wgsl_emit_expression_temp_plan.mbt ]]; then
  fail "WGSL expression temporary naming must be owned by the writer arena temp plan"
fi

if ! rg -n 'allocate_function_body_names_from_arena' ir/wgsl_emit_expression_temp_plan.mbt >/dev/null; then
  fail "WGSL function body names must be allocated from expression arena provenance"
fi

if rg -n 'WgslIrFunctionScope::function_expression_temporary_name|scope\.function_expression_temporary_name|baked_function_expressions|record_baked_function_expression|projected_temporary_name_offset|hidden_temporary_name_indices|hide_temporary_name_indices|record_projected_temporary_expression' \
  ir --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "expression temporary names must not be assigned by lowering scope counters or emitter baked-name writeback"
fi

if [[ ! -f ir/pkg.mbti ]]; then
  fail "IR package must own an explicit public interface whitelist in ir/pkg.mbti"
fi

if rg -n 'pub (struct|enum|typealias) (Module|ModuleInfo|EntryPoint|Function|FunctionArgument|FunctionResult|Statement|Block|Expression|Literal|Type|TypeInner|Scalar|VectorSize|AddressSpace|StorageAccess|Binding|BuiltIn|Handle|ExpressionArena|TypeArena|FunctionArena|ConstantArena|DiagnosticFilterArena|GlobalVariable|LocalVariable|Override|Constant|StructMember|ImageClass|ImageDimension|StorageFormat|WgslIrEmitter|WgslIrLowerer|WgslIrValidator)' ir/pkg.mbti >"$matches_file"; then
  cat "$matches_file" >&2
  fail "IR public interface must not expose internal IR model, arenas, handles, lowerer, emitter, or validator types"
fi

if rg -n 'pub\(all\) struct WgslIrGeneratedImportProvenance|pub (struct|fn WgslIrImportEdge::) WgslIrImportEdge|WgslIrSymbolNode|record_import_edge' ir/pkg.mbti >"$matches_file"; then
  cat "$matches_file" >&2
  fail "IR public symbol-linking surface must expose only opaque compose contracts, not graph internals or provenance fields"
fi

if rg -n 'pub (fn (parse_wgsl_module_to_ir|parse_wgsl_module_to_ir_with_generated_imports|lower_wgsl_translation_unit_to_ir|lower_wgsl_translation_unit_to_ir_with_generated_imports|emit_wgsl_module_from_ir|emit_wgsl_module_from_ir_roots)|suberror WgslIr(Lower|Emit)Error)' ir \
  --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "raw WGSL IR lower/emit APIs must remain internal; public callers must use the validated IR pipeline"
fi

if rg -n 'parse_wgsl_module_to_ir|lower_wgsl_translation_unit_to_ir|lower_validated_wgsl_source_to_ir|emit_validated_wgsl_source_from_ir|emit_wgsl_module_from_ir|WgslIr(Lower|Emit)Error|WgslIrEmitFilter|sanitize_wgsl_ir_identifier' ir/pkg.mbti >"$matches_file"; then
  cat "$matches_file" >&2
  fail "IR explicit public interface must only expose validated pipeline entrypoints, not raw lower/emit internals"
fi

if rg -n 'parse_wgsl_module_to_ir|lower_wgsl_translation_unit_to_ir|lower_validated_wgsl_source_to_ir|emit_validated_wgsl_source_from_ir|emit_wgsl_module_from_ir|WgslIr(Lower|Emit)Error|WgslIrEmitFilter|sanitize_wgsl_ir_identifier' ir/pkg.generated.mbti >"$matches_file"; then
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

if [[ -f compose/import_graph.mbt ]]; then
  fail "compose import graph stages must not collapse back into compose/import_graph.mbt"
fi

required_compose_stage_files=(
  compose/stage_objects.mbt
  compose/final_name_plan.mbt
  compose/source_preparation.mbt
  compose/import_request_builder.mbt
  compose/import_request_execution.mbt
  compose/finalize.mbt
)
for stage_file in "${required_compose_stage_files[@]}"; do
  if [[ ! -f "$stage_file" ]]; then
    fail "compose graph/rewrite responsibilities must stay staged: missing ${stage_file}"
  fi
done

if ! rg -n 'priv struct WgslImportGraphBuilder|priv struct WgslReachabilityPlan|priv struct WgslFinalNameAllocator|priv struct WgslComposeEmitter' compose/stage_objects.mbt >/dev/null; then
  fail "compose stage objects must explicitly model import graph, reachability, final-name allocation, and emission stages"
fi

if ! rg -n 'WgslImportGraphBuilder\(self, session\)\.complete_execution' compose/pipeline.mbt >/dev/null; then
  fail "compose pipeline must enter graph execution through WgslImportGraphBuilder"
fi

if ! rg -n 'WgslReachabilityPlan\(facts, bindings\)\.live_binding_plan' compose/finalize.mbt >/dev/null; then
  fail "compose finalization must enter live binding through WgslReachabilityPlan"
fi

if ! rg -n 'WgslFinalNameAllocator\(' compose/import_request_execution.mbt >/dev/null; then
  fail "compose import emission must allocate final names through WgslFinalNameAllocator"
fi

if ! rg -n 'WgslComposeEmitter\(self, session\)\.emit_source_with_path|WgslComposeEmitter\(self, session\)\.emit_root' compose/pipeline.mbt compose/import_request_execution.mbt >/dev/null; then
  fail "compose source assembly must enter emission through WgslComposeEmitter"
fi

if rg -n 'fn Composer::(resolve_wgsl_source_with_path|resolve_root_wgsl_source_into_session|plan_wgsl_compose_graph_with_path|plan_wgsl_import_request_batch)' compose --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "compose graph planning and source emission internals must live on explicit stage objects, not Composer methods"
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

if rg -n 'WgslRenamePlan|WgslRenameRule|WgslRenameMaps|build_wgsl_rename_maps|collect_wgsl_block_rewrite_nodes|target_for_reference' transform \
  --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "transform must not own name-first semantic rename policy"
fi

required_transform_rewrite_files=(
  transform/rewrite_plan.mbt
  transform/rewrite_collectors.mbt
  transform/wgsl_binding.mbt
)
for rewrite_file in "${required_transform_rewrite_files[@]}"; do
  if [[ ! -f "$rewrite_file" ]]; then
    fail "transform rewrite backend must keep plan, collector, and facade responsibilities split: missing ${rewrite_file}"
  fi
done

transform_binding_lines="$(wc -l < transform/wgsl_binding.mbt | tr -d ' ')"
if (( transform_binding_lines > 140 )); then
  fail "transform WGSL binding facade must not absorb rewrite-plan or AST-collector policy: ${transform_binding_lines} lines"
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

if [[ ! -f testdata/external_wgsl_corpus_expected_invalid_normalized_by_ir.tsv ]]; then
  fail "external WGSL expected-invalid IR-normalized cases must be manifest-owned"
fi

if ! rg -n 'skipped=0' tools/check_external_wgsl_corpus.sh >/dev/null; then
  fail "external WGSL corpus gate must report zero skipped files"
fi

if [[ ! -f testdata/external_wgsl_corpus_profiles.tsv ]]; then
  fail "external WGSL corpus profiles must be manifest-owned"
fi

if rg -n 'min_valid|min_composed|>= min_valid|>= min_composed' \
  testdata/external_wgsl_corpus_manifest.tsv \
  tools/check_external_wgsl_corpus.sh >"$matches_file"; then
  cat "$matches_file" >&2
  fail "external WGSL corpus repository counts must be exact, not minimum thresholds"
fi

if ! rg -n 'expected_files.*expected_source_valid.*expected_composed_valid.*expected_invalid' testdata/external_wgsl_corpus_manifest.tsv >/dev/null; then
  fail "external WGSL corpus manifest must own exact per-repository counts"
fi

if ! rg -n 'external corpus manifest row has.*expected 9' tools/check_external_wgsl_corpus.sh >/dev/null; then
  fail "external WGSL corpus manifest must enforce exact TSV schema width"
fi

if ! rg -n 'expected-invalid manifest row has.*expected 4' tools/check_external_wgsl_corpus.sh >/dev/null; then
  fail "external WGSL expected-invalid manifest must enforce exact TSV schema width"
fi

if ! rg -n 'duplicate expected-invalid row' tools/check_external_wgsl_corpus.sh >/dev/null; then
  fail "external WGSL expected-invalid manifest must reject duplicate rows"
fi

if ! rg -n 'EXTERNAL_WGSL_CORPUS_PROFILE_MANIFEST' tools/check_external_wgsl_corpus.sh >/dev/null; then
  fail "external WGSL corpus gate must load explicit shader profiles"
fi

if ! rg -n 'profile_expected_keys|profile_used_keys|profile-coverage\.diff' tools/check_external_wgsl_corpus.sh >/dev/null; then
  fail "external WGSL corpus profile manifest must be checked for stale or unconsumed rows"
fi

if [[ ! -f testdata/external_wgsl_corpus_profile_modes.tsv ]]; then
  fail "external WGSL corpus profile execution modes must be manifest-owned"
fi

if ! rg -n 'profile_mode_expected|profile_mode_actual|profile-mode\.diff' tools/check_external_wgsl_corpus.sh >/dev/null; then
  fail "external WGSL corpus profiles must gate raw vs compose execution modes"
fi

if [[ ! -f testdata/external_wgsl_corpus_compose_sources.tsv ]]; then
  fail "external WGSL corpus compose sources must be manifest-owned"
fi

if ! rg -n 'compose_source_expected|compose_source_actual|compose-source\.diff' tools/check_external_wgsl_corpus.sh >/dev/null; then
  fail "external WGSL corpus gate must exact-gate the concrete compose source files"
fi

if ! rg -n 'blockDepth|lineComment' tools/check_external_wgsl_corpus.sh >/dev/null; then
  fail "external WGSL corpus preprocessor classification must be comment-aware"
fi

if ! rg -n 'check_preprocessor_directive_classifier' tools/check_external_wgsl_corpus.sh >/dev/null; then
  fail "external WGSL corpus preprocessor classification must have synthetic self-tests"
fi

if ! rg -n -F '*(import|define|define_import_path|if|ifdef|ifndef|else|elif|endif)\b' tools/check_external_wgsl_corpus.sh >/dev/null; then
  fail "external WGSL corpus gate must recognize naga-oil-style preprocessor directives, including spaced # directives and #define"
fi

if ! rg -n 'validated_capabilities=.*source_capabilities_file' tools/check_external_wgsl_corpus.sh >/dev/null; then
  fail "external WGSL corpus gate must carry profile capabilities into final emitted validation"
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

if rg -n '_min_valid|_min_composed|min_valid|min_composed' tools/check_external_naga_oil_compose_parity.sh >"$matches_file"; then
  cat "$matches_file" >&2
  fail "external naga-oil compose parity must consume the exact-count external repo manifest schema"
fi

if ! rg -n 'external naga-oil compose parity row has.*expected 7' tools/check_external_naga_oil_compose_parity.sh >/dev/null; then
  fail "external naga-oil compose parity manifest must enforce exact TSV schema width"
fi

if ! rg -n 'EXTERNAL_NAGA_OIL_COMPOSE_PARITY_EXPECTED_CASES|expected_case_count' tools/check_external_naga_oil_compose_parity.sh >/dev/null; then
  fail "external naga-oil compose parity gate must exact-gate its manifest case count"
fi

if ! rg -n 'expected_case_count="\$\{EXTERNAL_NAGA_OIL_COMPOSE_PARITY_EXPECTED_CASES:-150\}"' tools/check_external_naga_oil_compose_parity.sh >/dev/null; then
  fail "external naga-oil compose parity must default to the full 150-case Bevy compose-source inventory"
fi

if [[ ! -f testdata/external_naga_oil_compose_oracle_blocked.tsv ]]; then
  fail "external naga-oil compose parity oracle-blocked cases must be manifest-owned"
fi

if [[ ! -f testdata/external_naga_oil_compose_writer_drift.tsv ]]; then
  fail "external naga-oil compose parity writer/order/name drift must be manifest-owned"
fi

if [[ ! -f testdata/external_naga_oil_compose_byte_drift.tsv ]]; then
  fail "external naga-oil compose parity byte drift must be manifest-owned"
fi

external_compose_case_count="$(awk -F '\t' '$0 !~ /^($|#)/ && $1 != "id" { count += 1 } END { print count + 0 }' testdata/external_naga_oil_compose_parity.tsv)"
if (( external_compose_case_count != 150 )); then
  fail "external naga-oil compose parity manifest must contain the full 150-case inventory, got ${external_compose_case_count}"
fi

external_oracle_blocked_count="$(awk -F '\t' '$0 !~ /^($|#)/ && $1 != "id" { count += 1 } END { print count + 0 }' testdata/external_naga_oil_compose_oracle_blocked.tsv)"
if (( external_oracle_blocked_count != 1 )); then
  fail "external naga-oil compose parity oracle-blocked manifest must contain exactly one pinned-upstream blocked case, got ${external_oracle_blocked_count}"
fi

if ! rg -n 'diff -u "\$writer_drift_expected" "\$writer_drift_actual"' tools/check_external_naga_oil_compose_parity.sh >/dev/null; then
  fail "external naga-oil compose parity writer drift manifest must be exact-gated against observed writer drift rows"
fi

if ! rg -n 'diff -u "\$byte_drift_expected" "\$byte_drift_actual"' tools/check_external_naga_oil_compose_parity.sh >/dev/null; then
  fail "external naga-oil compose parity byte drift manifest must be exact-gated against observed byte drift rows"
fi

if [[ ! -f tools/naga_oil_oracle/src/bin/wgsl_writer_fingerprint.rs ]]; then
  fail "external naga-oil compose parity must own a writer/order/name fingerprint tool"
fi

if ! rg -n 'wgsl_writer_fingerprint' tools/check_external_naga_oil_compose_parity.sh tools/naga_oil_oracle/src/bin/wgsl_writer_fingerprint.rs >/dev/null; then
  fail "external naga-oil compose parity must execute the writer/order/name fingerprint tool"
fi

if ! rg -n 'writer-drift\.diff|byte-drift\.diff|compose-source-parity\.diff|materialize_profile_source_overlay|append_detected_capabilities' tools/check_external_naga_oil_compose_parity.sh >/dev/null; then
  fail "external naga-oil compose parity must exact-gate full inventory coverage, profile overlays, detected capabilities, and drift manifests"
fi

if ! rg -n 'diff -u --label expected --label actual' tools/check_external_naga_oil_compose_parity.sh >/dev/null; then
  fail "external naga-oil compose parity drift hashes must be independent of temporary diff paths"
fi

if ! rg -n 'materialize_raw_template_value_defs|raw-overlay' tools/check_external_naga_oil_compose_parity.sh >/dev/null; then
  fail "external naga-oil compose parity must materialize raw template value defs before comparing with the upstream oracle"
fi

if ! rg -n 'cached_repo_id|cached_checkout' tools/check_external_naga_oil_compose_parity.sh >/dev/null; then
  fail "external naga-oil compose parity must cache repository checkouts so full-inventory gates can scale"
fi

if ! rg -n 'expected-failures=0' tools/check_external_wgsl_corpus.sh >/dev/null; then
  fail "external WGSL corpus gate must report zero expected failures"
fi

if ! rg -n 'diff -u "\$expected_invalid_expected_keys" "\$expected_invalid_actual_keys"' tools/check_external_wgsl_corpus.sh >/dev/null; then
  fail "external WGSL corpus gate must fail unknown or stale expected-invalid cases"
fi

if ! rg -n 'diff -u "\$expected_invalid_normalized_expected_keys" "\$expected_invalid_normalized_actual_keys"' tools/check_external_wgsl_corpus.sh >/dev/null; then
  fail "external WGSL corpus gate must fail unknown or stale expected-invalid IR-normalized cases"
fi

if rg -n 'Milky2018/moon_wgsl/transform' metadata/moon.pkg preprocess/moon.pkg >"$matches_file"; then
  cat "$matches_file" >&2
  fail "metadata and preprocess must not depend on transform; import substitution owns preprocessing import rewrites"
fi

if rg -n 'WgslImportSubstitution(State|Error)|import_syntax' transform/pkg.generated.mbti transform/moon.pkg >"$matches_file"; then
  cat "$matches_file" >&2
  fail "transform public API must not expose preprocessing import substitution contracts"
fi

if [[ ! -f import_substitution/pkg.mbti || ! -f source_rewrite/pkg.mbti || ! -f transform/pkg.mbti ]]; then
  fail "import substitution, source rewrite, and transform packages must own explicit public interface whitelists"
fi

if rg -n 'WgslImportSubstitution(State|Error)|WgslTokenReplacement|emit_wgsl_|tokenize_wgsl_|import_syntax' transform/pkg.mbti >"$matches_file"; then
  cat "$matches_file" >&2
  fail "transform explicit public interface must not expose preprocessing or source rewrite backend contracts"
fi

echo "architecture guardrails passed"
