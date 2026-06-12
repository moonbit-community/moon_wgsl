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
  modules/moon_wgsl_naga_oil/metadata modules/moon_wgsl_naga_oil/preprocess modules/moon_wgsl_naga_oil/transform modules/moon_wgsl_naga_oil/compose modules/wgsl/ir modules/wgsl/parser \
  --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "WGSL parse failures must not fall back to source text"
fi

if rg -n 'F16Bits|F16Literal => \{[[:space:]]*let .*: Int' modules/wgsl/ir --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "f16 literals must use semantic float values, not integer bit placeholders"
fi

if rg -n 'Abstract\(value\).*value\.to_int\(\)|SwitchValue::I32\(value\.to_int\(\)\)' modules/wgsl/ir --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "abstract integer lowering must use checked i32/u32 conversion helpers"
fi

if rg -n '_ => AddressSpace::Private' modules/wgsl/ir --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "WGSL address-space lowering must reject unknown tokens instead of falling back"
fi

if rg -n -U 'fn wgsl_ir_storage_access_from_name[\s\S]*_ => StorageAccess::load\(\)' modules/wgsl/ir --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "WGSL storage-access lowering must reject unknown tokens instead of falling back"
fi

if rg -n -U 'registered_source\([^)]*\)[\s\S]{0,120}None => ""|registered_source\([^)]*\)[\s\S]{0,120}None => import_path' \
  modules/moon_wgsl_naga_oil/compose --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "resolved registered-source lookups must not fabricate empty or import-path fallback values"
fi

if rg -n 'module_rel_path_for_module_path\([^)]*\) == ""|module_path_for_rel_path\([^)]*\),|session\.module_path_for_rel_path\(rel_path\)[[:space:]]*$' \
  modules/moon_wgsl_naga_oil/compose --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "modules/moon_wgsl_naga_oil/compose module path lookups must use Option, not empty-string sentinels"
fi

if ! rg -n 'remove_module_paths_for_rel_path\(module_paths, normalized_rel\)' modules/moon_wgsl_naga_oil/resolver/registry_ops.mbt >/dev/null; then
  fail "registry rel_path replacement must clear stale module-path mappings first"
fi

if [[ ! -f modules/moon_wgsl_naga_oil/resolver/module_path_policy.mbt ]]; then
  fail "modules/moon_wgsl_naga_oil/resolver module path inference/defaulting policy must have a single owner"
fi

if rg -n 'fn wgsl_module_path_from_rel_path|fn wgsl_module_path_to_rel_path|default_shader_rel_path_for_module_path' \
  modules/moon_wgsl_naga_oil/resolver/registry_ops.mbt modules/moon_wgsl_naga_oil/resolver/module_resolution.mbt >"$matches_file"; then
  cat "$matches_file" >&2
  fail "modules/moon_wgsl_naga_oil/resolver module path inference/defaulting policy must stay in modules/moon_wgsl_naga_oil/resolver/module_path_policy.mbt"
fi

if rg -n 'CachedQualifiedAliasBinding' modules/moon_wgsl_naga_oil/compose modules/moon_wgsl_naga_oil/transform modules/wgsl/ir --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "cached alias bindings must not be a separate modules/moon_wgsl_naga_oil/compose binding phase"
fi

if rg -n 'wgsl_semantic_source_contains_reference_path' \
  modules/moon_wgsl_naga_oil/compose/import_request_builder.mbt \
  modules/moon_wgsl_naga_oil/compose/import_request_execution.mbt \
  modules/moon_wgsl_naga_oil/compose/graph_execution.mbt >"$matches_file"; then
  cat "$matches_file" >&2
  fail "modules/moon_wgsl_naga_oil/compose import request retention must use structured semantic facts, not source-level reference scans"
fi

if rg -n 'pub fn WgslReferenceRewritePlan::add\(' modules/moon_wgsl_naga_oil/transform --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "reference rewrite plans must not expose unscoped string-only bindings"
fi

if rg -n 'raw_top_level_items|Token::ITEM|%token<WgslRawTopLevelItem> ITEM' modules/wgsl/parser \
  --glob '*.mbt' \
  --glob '*.mbty' \
  --glob '!top_level_ast.mbt' \
  --glob '!top_level_ast_wbtest.mbt' \
  --glob '!wgsl_raw_top_level.mbt' \
  --glob '!wgsl_ast_parser.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "raw top-level item scanning must stay modules/wgsl/parser-owned, not a generated modules/wgsl/parser start"
fi

if rg -n 'text : String' modules/wgsl/parser/wgsl_raw_top_level.mbt >"$matches_file"; then
  cat "$matches_file" >&2
  fail "raw top-level staging items must carry spans, not cached source text"
fi

if [[ ! -f modules/wgsl/ast_analysis/wgsl_ast_identifiers.mbt ]]; then
  fail "AST semantic identifier collection must live outside the syntax-only modules/wgsl/ast package"
fi

if rg -n 'collect_wgsl_.*identifier_nodes' modules/wgsl/ast \
  --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "AST package must not own semantic identifier collection helpers"
fi

if find modules/moon_wgsl_naga_oil/metadata -maxdepth 1 -name 'source_directive_items*.mbt' | rg . >"$matches_file"; then
  cat "$matches_file" >&2
  fail "source-level WGSL modules/moon_wgsl_naga_oil/directive item parsing must be owned by the modules/moon_wgsl_naga_oil/directive package, not modules/moon_wgsl_naga_oil/metadata"
fi

if [[ ! -f modules/moon_wgsl_naga_oil/directive/source_directive_items.mbt ]]; then
  fail "modules/moon_wgsl_naga_oil/directive package must own source-level WGSL modules/moon_wgsl_naga_oil/directive item parsing"
fi

if rg -n 'text : String' modules/moon_wgsl_naga_oil/compose/semantic_graph.mbt >"$matches_file"; then
  cat "$matches_file" >&2
  fail "semantic reference paths must derive text from structured segments"
fi

required_ir_split_files=(
  modules/wgsl/ir/wgsl_lower_core.mbt
  modules/wgsl/ir/wgsl_lower_globals.mbt
  modules/wgsl/ir/wgsl_lower_functions.mbt
  modules/wgsl/ir/wgsl_lower_updates.mbt
  modules/wgsl/ir/wgsl_lower_type_inference.mbt
  modules/wgsl/ir/wgsl_lower_expr_parser.mbt
  modules/wgsl/ir/wgsl_lower_global_expressions.mbt
  modules/wgsl/ir/wgsl_lower_function_expressions.mbt
  modules/wgsl/ir/wgsl_lower_calls.mbt
  modules/wgsl/ir/wgsl_lower_expression_results.mbt
  modules/wgsl/ir/wgsl_lower_expression_types.mbt
  modules/wgsl/ir/wgsl_lower_const_eval.mbt
  modules/wgsl/ir/wgsl_lower_materialization.mbt
  modules/wgsl/ir/wgsl_lower_statements.mbt
  modules/wgsl/ir/wgsl_emit_byte_plan.mbt
  modules/wgsl/ir/wgsl_emit_semantic_plan.mbt
  modules/wgsl/ir/wgsl_emit_writer_policy.mbt
  modules/wgsl/ir/wgsl_emit_runtime_writer.mbt
  modules/wgsl/ir/wgsl_writer_module.mbt
  modules/wgsl/ir/wgsl_writer_emission_plan.mbt
  modules/wgsl/ir/wgsl_emit_final_name_plan.mbt
  modules/wgsl/ir/wgsl_emit_module.mbt
  modules/wgsl/ir/wgsl_emit_declarations.mbt
  modules/wgsl/ir/wgsl_emit_functions.mbt
  modules/wgsl/ir/wgsl_emit_types.mbt
  modules/wgsl/ir/wgsl_emit_attributes_literals.mbt
  modules/wgsl/ir/wgsl_emit_names.mbt
  modules/wgsl/ir/wgsl_emit_builtins.mbt
  modules/wgsl/ir/wgsl_emit_expressions.mbt
  modules/wgsl/ir/wgsl_emit_expression_types.mbt
  modules/wgsl/ir/wgsl_emit_statements.mbt
  modules/wgsl/ir/validation.mbt
  modules/wgsl/ir/validation_types.mbt
  modules/wgsl/ir/validation_statements.mbt
  modules/wgsl/ir/validation_expressions.mbt
  modules/wgsl/ir/validation_signatures.mbt
  modules/wgsl/ir/validation_expression_types.mbt
  modules/wgsl/ir/validation_layout.mbt
  modules/wgsl/ir/validation_handles.mbt
)
for split_file in "${required_ir_split_files[@]}"; do
  if [[ ! -f "$split_file" ]]; then
    fail "IR lower/emit responsibilities must stay split: missing ${split_file}"
  fi
done

if [[ -f modules/wgsl/ir/wgsl_lower.mbt ]]; then
  fail "IR lowerer monolith must not be reintroduced as modules/wgsl/ir/wgsl_lower.mbt"
fi

if [[ -f modules/wgsl/ir/wgsl_emit_compat_writer.mbt ]]; then
  fail "Naga-compatible writer backend must live in modules/moon_wgsl_naga, not modules/wgsl/ir"
fi

if [[ -f modules/wgsl/ir/wgsl_writer_trace.mbt ]]; then
  fail "Naga-compatible writer trace tooling must live in modules/moon_wgsl_naga, not modules/wgsl/ir"
fi

if rg -n 'compat_writer|trace_compat_writer|WgslIrEmitOptions::compat_writer|WgslIrWriterBytePlan::compat_writer|WgslIrWriterSemanticPlan::compat_writer|CompatNumericLiteralSpelling' \
  modules/wgsl/ir --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "WGSL semantic IR must not own Naga-compatible writer policy or trace entrypoints"
fi

required_naga_writer_files=(
  modules/moon_wgsl_naga/wgsl_emit_compat_writer.mbt
  modules/moon_wgsl_naga/wgsl_writer_trace.mbt
  modules/moon_wgsl_naga/wgsl_writer_module.mbt
  modules/moon_wgsl_naga/wgsl_writer_declarations.mbt
  modules/moon_wgsl_naga/wgsl_writer_emission_plan.mbt
  modules/moon_wgsl_naga/wgsl_emit_byte_plan.mbt
  modules/moon_wgsl_naga/wgsl_emit_semantic_plan.mbt
)
for naga_writer_file in "${required_naga_writer_files[@]}"; do
  if [[ ! -f "$naga_writer_file" ]]; then
    fail "Naga-compatible writer ownership split is missing ${naga_writer_file}"
  fi
done

if [[ -f modules/wgsl/parser/wgsl_ast_expr_type.mbt ]]; then
  fail "modules/wgsl/parser expression/type monolith must stay split; modules/wgsl/parser/wgsl_ast_expr_type.mbt must not be reintroduced"
fi

if [[ ! -f modules/wgsl/parser/pkg.mbti ]]; then
  fail "modules/wgsl/parser package must own an explicit public interface whitelist in modules/wgsl/parser/pkg.mbti"
fi

if rg -n 'pub (fn (block|const_assert_expr|function_args|function_result|source_directive|struct_members|template_list|type_alias_tail|type_ref|typed_initializer_tail)|suberror ParseError|.*enum Token|.*enum TokenKind)' modules/wgsl/parser/pkg.mbti >"$matches_file"; then
  cat "$matches_file" >&2
  fail "modules/wgsl/parser public interface must not expose moonyacc-generated rule entrypoints or tokens"
fi

required_parser_split_files=(
  modules/wgsl/parser/wgsl_expr_tokens.mbt
  modules/wgsl/parser/wgsl_expr_node_parser.mbt
  modules/wgsl/parser/wgsl_decl_fragment_parser.mbt
  modules/wgsl/parser/wgsl_type_ref_parser.mbt
)
for parser_split_file in "${required_parser_split_files[@]}"; do
  if [[ ! -f "$parser_split_file" ]]; then
    fail "modules/wgsl/parser expression/type responsibilities must stay split: missing ${parser_split_file}"
  fi
done

if ! rg -n 'parse_wgsl_module_to_ir' modules/wgsl/ir/wgsl_lower_core.mbt >/dev/null; then
  fail "IR lowerer core must own the module lowering entrypoint"
fi

if ! rg -n 'lower_global_expression_ref' modules/wgsl/ir/wgsl_lower_global_expressions.mbt >/dev/null; then
  fail "IR lowerer global expression lowering must stay in its own split file"
fi

if ! rg -n 'lower_function_expression_ref' modules/wgsl/ir/wgsl_lower_function_expressions.mbt >/dev/null; then
  fail "IR lowerer function expression lowering must stay in its own split file"
fi

if ! rg -n 'priv struct WgslIrEmitOptions' modules/wgsl/ir/wgsl_emit_writer_policy.mbt >/dev/null; then
  fail "IR emitter writer policy must own WgslIrEmitOptions"
fi

if rg -n 'priv struct WgslIrEmitOptions|fn WgslIrEmitOptions::naga_oil_writer_compatible' modules/wgsl/ir/wgsl_emit.mbt modules/wgsl/ir/wgsl_emit_module.mbt >/dev/null; then
  fail "IR emitter core/module ordering must not own writer policy"
fi

if ! rg -n 'priv struct WgslIrWriterSemanticPlan' modules/wgsl/ir/wgsl_emit_semantic_plan.mbt >/dev/null; then
  fail "WGSL semantic writer choices must be represented by an explicit semantic plan"
fi

if ! rg -n 'priv struct WgslIrWriterBytePlan' modules/wgsl/ir/wgsl_emit_byte_plan.mbt >/dev/null; then
  fail "WGSL byte-level writer choices must be represented by an explicit byte plan"
fi

if ! rg -n 'WgslIrImplicitFlatInterpolationBytePolicy|WgslIrStorageTextureTypeBytePolicy|storage_texture_type_separator' modules/wgsl/ir/wgsl_emit_byte_plan.mbt >/dev/null; then
  fail "WGSL byte plan must own token-level interpolation and storage-texture formatting policy"
fi

if ! rg -n 'WgslIrLocalTypeAnnotationBytePolicy|WgslIrAtomicResultLocalAnnotationBytePolicy|WgslIrNumericLiteralBytePolicy' modules/wgsl/ir/wgsl_emit_byte_plan.mbt >/dev/null; then
  fail "WGSL byte plan must own local type-annotation and numeric literal token policy"
fi

if ! rg -n 'emit_trailing_blank_after_module' modules/wgsl/ir/wgsl_emit_writer_policy.mbt modules/wgsl/ir/wgsl_emit_module.mbt >/dev/null; then
  fail "WGSL module trailing byte policy must be routed through the writer byte plan"
fi

if rg -n 'annotate_atomic_compare_exchange_result_locals : Bool|inline_generated_import_constants : Bool|fold_numeric_constant_expressions : Bool|expand_matrix_scalar_constructors : Bool|contextualize_numeric_literals : Bool|annotate_all_local_types : Bool|emit_implicit_flat_interpolation : Bool|compact_storage_texture_type_arguments : Bool|emit_source_directives : Bool' modules/wgsl/ir/wgsl_emit_writer_policy.mbt >/dev/null; then
  fail "writer backends must not be represented as a loose boolean option matrix"
fi

if rg -n 'WgslIrWriterBackendKind|backend :' modules/wgsl/ir/wgsl_emit_writer_policy.mbt >/dev/null; then
  fail "writer semantic policy must be an explicit plan, not an implicit backend switch"
fi

if rg -n 'match self\.backend' modules/wgsl/ir/wgsl_emit_*.mbt >"$matches_file"; then
  cat "$matches_file" >&2
  fail "writer behavior must dispatch through byte/semantic plans, not backend-name matches"
fi

if rg -n 'order_functions_by_naga_reachability|push_naga|naga_reachable|collect_naga|naga_generated_import' modules/wgsl/ir/wgsl_emit_*.mbt >/dev/null; then
  fail "Writer function ordering must live in the Writer-compatible module view, not emitter options or emitter helpers"
fi

if ! rg -n 'fn wgsl_ir_collect_block_function_calls' modules/wgsl/ir/wgsl_writer_dependencies.mbt >/dev/null; then
  fail "Writer-compatible dependency layer must own function body traversal"
fi

if [[ -f modules/wgsl/ir/wgsl_emit_name_table.mbt ]]; then
  fail "final name planning must live in modules/wgsl/ir/wgsl_emit_final_name_plan.mbt, not the old name-table file"
fi

if rg -n 'build_wgsl_ir_writer_final_name_plan' modules/wgsl/ir/wgsl_emit_final_name_plan.mbt >/dev/null; then
  fail "Writer-compatible final name allocation must not live in the runtime final-name plan"
fi

if ! rg -n 'build_wgsl_ir_writer_final_name_plan' modules/wgsl/ir/wgsl_writer_names.mbt >/dev/null; then
  fail "Writer-compatible name layer must own final name allocation"
fi

if ! rg -n 'priv struct WgslIrWriterDeclarationArena' modules/wgsl/ir/wgsl_writer_declarations.mbt >/dev/null; then
  fail "Writer-compatible declaration layer must own declaration arena slots"
fi

if ! rg -n 'priv struct WgslIrWriterArena' modules/wgsl/ir/wgsl_writer_declarations.mbt >/dev/null; then
  fail "Writer module must own an explicit writer arena, not bare declaration lists"
fi

if ! rg -n 'priv struct WgslIrWriterTypeSlot|priv struct WgslIrWriterConstantSlot|priv struct WgslIrWriterGlobalVariableSlot|priv struct WgslIrWriterFunctionSlot' modules/wgsl/ir/wgsl_writer_declarations.mbt >/dev/null; then
  fail "Writer arena must contain typed declaration slots, not only source-index arrays"
fi

if ! rg -n 'priv struct WgslIrWriterEmissionPlan' modules/wgsl/ir/wgsl_writer_emission_plan.mbt >/dev/null; then
  fail "Writer module must own an explicit declaration and entry-point emission plan"
fi

writer_module_fields="$(sed -n '/priv struct WgslIrWriterModule {/,/^}/p' modules/wgsl/ir/wgsl_writer_module.mbt)"
if printf '%s\n' "$writer_module_fields" | rg -n 'shader_module' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "Writer module must not carry the raw IR module after the writer arena has been built"
fi

if rg -n 'fn WgslIrWriterModule::(type_order|constant_order|override_order|global_variable_order|function_order|entry_point_order|should_emit_entry_point)' \
  modules/wgsl/ir/wgsl_writer_emission_plan.mbt >"$matches_file"; then
  cat "$matches_file" >&2
  fail "Writer module must expose typed slots, not source-index order helpers"
fi

if ! rg -n 'module_\.entry_point_slots\(\)' modules/wgsl/ir/wgsl_emit_module.mbt >/dev/null; then
  fail "writer entry-point emission must consume writer module entry-point slots"
fi

if rg -n 'type_emission_order|constant_emission_order|override_emission_order|global_variable_emission_order|entry_point_emission_order|function_emission_order' modules/wgsl/ir/wgsl_emit_*.mbt >"$matches_file"; then
  cat "$matches_file" >&2
  fail "WGSL emission must use writer module slots instead of emitter-owned raw IR order helpers"
fi

if ! rg -n 'module_\.type_slots\(\)|module_\.constant_slots\(\)|module_\.global_variable_slots\(\)|module_\.function_slots\(\)' modules/wgsl/ir/wgsl_emit_module.mbt >/dev/null; then
  fail "Writer module emission must consume typed writer slots instead of source-index order lists"
fi

if ! rg -n 'module_\.source_directives\(\)' modules/wgsl/ir/wgsl_emit_module.mbt >/dev/null; then
  fail "WGSL module modules/moon_wgsl_naga_oil/directive emission must consume writer module source directives"
fi

if rg -n 'self\.shader_module\.directives' modules/wgsl/ir/wgsl_emit_module.mbt >"$matches_file"; then
  cat "$matches_file" >&2
  fail "WGSL module emission must not read raw module directives after the writer view is built"
fi

if ! rg -n 'WgslIrWriterEntryPointSlot|WgslIrWriterConstAssertSlot' modules/wgsl/ir/wgsl_writer_declarations.mbt >/dev/null; then
  fail "writer module must own entry-point and const-assert slots instead of raw module scans"
fi

if rg -n 'filter : WgslIrEmitFilter\?|naga_writer_module :' modules/wgsl/ir/wgsl_emit.mbt modules/wgsl/ir/wgsl_emit_*.mbt >"$matches_file"; then
  cat "$matches_file" >&2
  fail "generic WGSL emitter must carry only the writer module, not raw filter or optional Writer state"
fi

user_call_arg_sites="$(rg -n 'self\.lower_user_function_call_arguments' modules/wgsl/ir --glob '*.mbt' | wc -l | tr -d ' ')"
if (( user_call_arg_sites < 2 )); then
  fail "expression-level and statement-level user function calls must share one argument-lowering path"
fi

call_arm_sites="$(rg -n 'Call\(callee, arguments\)' modules/wgsl/ir --glob '*.mbt' | wc -l | tr -d ' ')"
normalized_call_arg_sites="$(rg -n 'wgsl_ir_call_arguments\(arguments\)' modules/wgsl/ir --glob '*.mbt' | wc -l | tr -d ' ')"
if (( normalized_call_arg_sites < call_arm_sites )); then
  fail "every AST call-lowering boundary must normalize call arguments before dispatch"
fi

if rg -n -U 'let values : Array\[Handle\] = \[\][\s\S]{0,400}Statement::Call' modules/wgsl/ir --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "statement-level user function calls must not manually lower raw call arguments"
fi

if ! rg -n 'wgsl_ir_barrier_statement_from_call' modules/wgsl/ir --glob '*.mbt' >/dev/null; then
  fail "barrier builtins must lower as IR barrier statements before expression fallback"
fi

if ! rg -n 'barrier builtin has no value' modules/wgsl/ir --glob '*.mbt' >/dev/null; then
  fail "barrier builtins must be rejected explicitly in value position"
fi

if ! rg -n 'workgroupBarrier\(\);' modules/wgsl/ir --glob '*.mbt' >/dev/null; then
  fail "IR emitter must preserve WGSL control barrier calls"
fi

if ! rg -n 'storageBarrier\(\);' modules/wgsl/ir --glob '*.mbt' >/dev/null; then
  fail "IR emitter must preserve WGSL memory barrier calls"
fi

if rg -n 'WgslReferenceRewriteBinding \{[^}]*rel_path|WgslReferenceRewriteBinding \{[^}]*original_name' -U modules/moon_wgsl_naga_oil/transform --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "reference rewrite bindings must carry WgslIrSymbolIdentity directly"
fi

if rg -n 'reference_rename_plan|global_declaration_rename_plan' modules/moon_wgsl_naga_oil/transform modules/moon_wgsl_naga_oil/compose \
  --glob '*.mbt' \
  --glob '!*.mbti' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "identity-backed composer bindings must not be downgraded into rename plans"
fi

if rg -n 'add_symbol_binding' modules/moon_wgsl_naga_oil/compose modules/moon_wgsl_naga_oil/transform \
  --glob '*.mbt' \
  --glob '!*.mbti' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "symbol rewrite plans must receive structured reference paths, not string bindings"
fi

if rg -n 'from_name : String|to_name : String|identity : WgslIrSymbolIdentity\?' modules/moon_wgsl_naga_oil/compose/session.mbt >"$matches_file"; then
  cat "$matches_file" >&2
  fail "cross-phase modules/moon_wgsl_naga_oil/compose/modules/moon_wgsl_naga_oil/transform bindings must preserve structured reference paths and non-optional symbol targets"
fi

if [[ -f modules/wgsl/common/types.mbt ]]; then
  fail "modules/wgsl/common DTO ownership must stay split by domain, not collapse back into modules/wgsl/common/types.mbt"
fi

required_common_domain_files=(
  modules/wgsl/common/shader_defs.mbt
  modules/wgsl/common/import_types.mbt
  modules/wgsl/common/directive_types.mbt
  modules/wgsl/common/preprocess_types.mbt
  modules/wgsl/common/source_types.mbt
  modules/wgsl/common/diagnostic_types.mbt
  modules/wgsl/common/compose_export_types.mbt
)
for common_file in "${required_common_domain_files[@]}"; do
  if [[ ! -f "$common_file" ]]; then
    fail "modules/wgsl/common DTO ownership split is missing ${common_file}"
  fi
done

if rg -n -U 'WgslReferenceRewriteBinding \{[^}]*from_name|WgslReferenceRewriteBinding \{[^}]*to_name' modules/moon_wgsl_naga_oil/transform/wgsl_binding.mbt >"$matches_file"; then
  cat "$matches_file" >&2
  fail "modules/moon_wgsl_naga_oil/transform reference rewrite bindings must carry WgslReferencePath plus final symbol target"
fi

if rg -n 'resolved_to_name|reference_paths : @set\.Set\[String\]' modules/moon_wgsl_naga_oil/compose \
  --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "modules/moon_wgsl_naga_oil/compose semantic facts and live bindings must not flatten semantic objects into string-only phase state"
fi

if rg -n 'WgslSemanticReferencePath|to_transform_path|wgsl_compose_reference_path_required' modules/moon_wgsl_naga_oil/compose modules/moon_wgsl_naga_oil/transform \
  --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "modules/moon_wgsl_naga_oil/compose and modules/moon_wgsl_naga_oil/transform must share modules/wgsl/common WgslReferencePath without conversion helpers or internal aborts"
fi

if rg -n 'struct WgslReferencePath' modules/moon_wgsl_naga_oil/compose modules/moon_wgsl_naga_oil/transform \
  --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "WgslReferencePath must have one definition in modules/wgsl/common"
fi

if rg -n 'wgsl_compose_binding_key|wgsl_compose_binding_scope_key' modules/moon_wgsl_naga_oil/compose \
  --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "modules/moon_wgsl_naga_oil/compose binding keys must be typed key objects, not free string key helpers"
fi

if rg -n 'identity : WgslIrSymbolIdentity\?' modules/moon_wgsl_naga_oil/transform/wgsl_binding.mbt >"$matches_file"; then
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

if ! rg -n 'WGSL_CORPUS_EXPECTED_RUNTIME_VALID_COMPOSE_CASES|runtime-valid modules/moon_wgsl_naga_oil/compose row has.*expected 1' tools/check_wgsl_corpus_matrix.sh >/dev/null; then
  fail "WGSL corpus matrix must schema-check and exact-gate runtime-valid modules/moon_wgsl_naga_oil/compose cases"
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
  fail "WGSL corpus matrix runtime-valid modules/moon_wgsl_naga_oil/compose cases must be manifest-owned"
fi

if ! rg -n 'WGSL_CORPUS_RUNTIME_VALID_COMPOSE_MANIFEST' tools/check_wgsl_corpus_matrix.sh >/dev/null; then
  fail "WGSL corpus matrix must load explicit runtime-valid modules/moon_wgsl_naga_oil/compose cases"
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

if ! rg -n 'validate_wgsl_ir_module\(self\.shader_module\)' modules/wgsl/ir/wgsl_emit_runtime_writer.mbt >/dev/null; then
  fail "runtime WGSL writer backend must run internal IR validation before writing source"
fi

if ! rg -n 'validate_wgsl_ir_module\(self\.shader_module\)' modules/moon_wgsl_naga/wgsl_emit_compat_writer.mbt >/dev/null; then
  fail "compat WGSL writer backend must run internal IR validation before writing source"
fi

if ! rg -n 'build_wgsl_ir_writer_module\(' modules/moon_wgsl_naga/wgsl_emit_compat_writer.mbt >/dev/null; then
  fail "compat WGSL writer backend must build a Writer-compatible module view before emission"
fi

if ! rg -n 'writer_module: self\.view' modules/moon_wgsl_naga/wgsl_emit_compat_writer.mbt >/dev/null; then
  fail "compat WGSL writer backend must emit through the Writer-compatible module view"
fi

if ! rg -n 'build_wgsl_ir_runtime_writer_module\(' modules/wgsl/ir/wgsl_emit_runtime_writer.mbt >/dev/null; then
  fail "runtime WGSL writer backend must build a writer module before emission"
fi

if [[ ! -f modules/wgsl/ir/wgsl_emit_expression_temp_plan.mbt ]]; then
  fail "WGSL expression temporary naming must be owned by the writer arena temp plan"
fi

if ! rg -n 'allocate_function_body_names_from_arena' modules/wgsl/ir/wgsl_emit_expression_temp_plan.mbt >/dev/null; then
  fail "WGSL function body names must be allocated from expression arena provenance"
fi

if ! rg -n 'priv struct WgslIrFunctionBodyWriterPlan' modules/wgsl/ir/wgsl_emit_expression_temp_plan.mbt >/dev/null; then
  fail "WGSL writer temporary planning must be represented as a function-body arena plan"
fi

if ! rg -n 'contains_materialized_expression|temporary_index' modules/wgsl/ir/wgsl_writer_function_plan.mbt >/dev/null; then
  fail "Writer-compatible function plan must own materialized expression membership and temp index calculation"
fi

if ! rg -n 'local_declaration_order|needs_blank_after_local_declarations' modules/wgsl/ir/wgsl_writer_function_plan.mbt >/dev/null; then
  fail "Writer-compatible function plan must own local declaration order"
fi

if [[ ! -f modules/wgsl/ir/wgsl_emit_body_emission_plan.mbt ]]; then
  fail "WGSL function statement emission must be owned by BodyEmissionPlanner"
fi

if ! rg -n 'priv struct BodyEmissionPlanner|priv struct WgslIrStatementWriterPlanItem|fn BodyEmissionPlanner::statement_plan|fn BodyEmissionPlanner::push_statement_emit_ranges' modules/wgsl/ir/wgsl_emit_body_emission_plan.mbt >/dev/null; then
  fail "BodyEmissionPlanner must own statement order, skip policy, blank policy, and emit-range construction"
fi

if ! rg -n 'body_emission : BodyEmissionPlanner|BodyEmissionPlanner::from_function' modules/wgsl/ir/wgsl_emit_expression_temp_plan.mbt >/dev/null; then
  fail "Writer function body plans must carry the body emission planner"
fi

if rg -n 'priv struct WgslIrStatementWriterPlanItem|fn WgslIrFunctionBodyWriterPlan::statement_is_elided_local_alias_declaration|fn wgsl_ir_push_naga_(named_expression_emit_ranges|statement_emit_ranges)|fn wgsl_ir_flush_naga_named_expression_emit_range|fn wgsl_ir_block_contains_expression_emit' modules/wgsl/ir --glob '*.mbt' --glob '!wgsl_emit_body_emission_plan.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "statement emission planning and emit-range builders must not be split back into lowerer/temp-plan helpers"
fi

if ! rg -n 'priv struct WgslIrFunctionWriterPlan' modules/wgsl/ir/wgsl_writer_function_plan.mbt >/dev/null; then
  fail "Writer-compatible function lowering must be represented by WgslIrFunctionWriterPlan"
fi

if ! rg -n 'arena : WgslIrExpressionWriterPlan|call : WgslIrCallArgumentWriterPlan|short_circuit : WgslIrShortCircuitWriterPlan|materialization : WgslIrMaterializationWriterPlan|body : WgslIrFunctionBodyWriterPlan|names : WgslIrNameWriterPlan' modules/wgsl/ir/wgsl_writer_function_plan.mbt >/dev/null; then
  fail "WgslIrFunctionWriterPlan must own arena, call, short-circuit, materialization, body, and name subplans"
fi

if ! rg -n 'function_plan : WgslIrFunctionWriterPlan' modules/wgsl/ir/wgsl_writer_declarations.mbt >/dev/null; then
  fail "writer function and entry-point slots must carry the precomputed Writer-compatible function plan"
fi

if ! rg -n 'function_plan : WgslIrFunctionWriterPlan' modules/wgsl/ir/wgsl_emit_functions.mbt modules/wgsl/ir/wgsl_emit_statements.mbt modules/wgsl/ir/wgsl_writer_names.mbt >/dev/null; then
  fail "Writer-compatible writer and name allocation must consume WgslIrFunctionWriterPlan"
fi

if [[ ! -f modules/moon_wgsl_naga/wgsl_writer_plan_invariants_wbtest.mbt ]]; then
  fail "Writer compatibility model invariants must be tested through a dedicated plan-invariant gate"
fi

if ! rg -n 'WgslIrWriterPlanInvariantCase|Writer compat plan invariants are table driven|plan-arena|plan-calls|plan-short-circuit|plan-body|plan-names' modules/moon_wgsl_naga/wgsl_writer_plan_invariants_wbtest.mbt >/dev/null; then
  fail "Writer compatibility plan invariant tests must be table-driven and cover arena, calls, short-circuit, body, and names"
fi

if ! rg -n 'plan-arena|plan-calls|plan-short-circuit|plan-materialization|plan-body|plan-names' modules/moon_wgsl_naga/wgsl_writer_function_plan.mbt >/dev/null; then
  fail "Writer compatibility function trace must expose structured plan sections"
fi

if rg -n 'Writer compat function plan dump exposes unified planning sections|IR emitter matches writer temp slots around nested call arguments|IR emitter counts implicit matrix scalar constructor columns in writer arena order' modules/wgsl/ir --glob '*wbtest.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "case-by-case Writer symptom tests must be replaced by plan invariant fixtures"
fi

if rg -n 'body_plan\(\)|slot\.body_plan\(\)|body_plan : WgslIrFunctionBodyWriterPlan' \
  modules/wgsl/ir/wgsl_emit_functions.mbt \
  modules/wgsl/ir/wgsl_emit_statements.mbt \
  modules/wgsl/ir/wgsl_writer_names.mbt \
  modules/wgsl/ir/wgsl_emit_expression_temp_plan.mbt \
  modules/wgsl/ir/wgsl_writer_function_plan.mbt \
  modules/moon_wgsl_naga/wgsl_emit_functions.mbt \
  modules/moon_wgsl_naga/wgsl_emit_statements.mbt \
  modules/moon_wgsl_naga/wgsl_writer_names.mbt \
  modules/moon_wgsl_naga/wgsl_emit_expression_temp_plan.mbt \
  modules/moon_wgsl_naga/wgsl_writer_trace.mbt \
  modules/moon_wgsl_naga/wgsl_writer_function_plan.mbt >"$matches_file"; then
  cat "$matches_file" >&2
  fail "Writer-compatible writer path must not expose or re-extract raw function body plans"
fi

if [[ ! -f modules/wgsl/ir/wgsl_lower_expression_arena_scheduler.mbt ]]; then
  fail "WGSL expression arena ordering must be owned by ExpressionArenaScheduler"
fi

if ! rg -n 'priv struct ExpressionArenaScheduler' modules/wgsl/ir/wgsl_lower_expression_arena_scheduler.mbt >/dev/null; then
  fail "ExpressionArenaScheduler must be the concrete expression-ordering scheduler"
fi

for scheduler_entry in \
  'binary_predeclares_left_associative_reference_roots' \
  'binary_lowers_right_before_left' \
  'constructor_arguments_delay_literals' \
  'constructor_argument_is_literal_like'; do
  if ! rg -n "$scheduler_entry" modules/wgsl/ir/wgsl_lower_expression_arena_scheduler.mbt >/dev/null; then
    fail "ExpressionArenaScheduler is missing required entry: $scheduler_entry"
  fi
done

if rg -n 'binary_expression_lowers_right_before_left|binary_expression_predeclares_left_associative_reference_roots|wgsl_ir_binary_right_subtree_has_higher_precedence|wgsl_ir_binary_preserves_left_first_across_higher_precedence_right|wgsl_ir_binary_predeclares_sibling_member_roots|wgsl_ir_constructor_arguments_delay_literals|wgsl_ir_constructor_argument_is_literal_like|wgsl_ir_constructor_argument_has_ordered_effect' modules/wgsl/ir --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "expression arena ordering must not be split back into legacy lowerer helper predicates"
fi

if [[ ! -f modules/wgsl/ir/wgsl_lower_call_argument_planner.mbt ]]; then
  fail "WGSL user-call argument ordering must be owned by CallArgumentPlanner"
fi

if ! rg -n 'priv struct CallArgumentPlanner|fn CallArgumentPlanner::lower_arguments' modules/wgsl/ir/wgsl_lower_call_argument_planner.mbt >/dev/null; then
  fail "CallArgumentPlanner must own structured user-call argument scheduling"
fi

if ! rg -n 'call_argument_planner\(.*\)|planner\.lower_arguments\(\)' modules/wgsl/ir/wgsl_lower_calls.mbt >/dev/null; then
  fail "lower_user_function_call_arguments must delegate to CallArgumentPlanner"
fi

if rg -n 'call_argument_is_naga_deferred_const_like|call_argument_uses_naga_reference_predeclare|lower_user_function_call_argument_dependencies|call_value_argument_lowers_before_prior_direct_argument|lower_later_reference_argument_before_direct_argument|lower_next_call_reference_argument_run|call_argument_is_existing_expression_alias|call_argument_is_existing_expression_alias_reference|lower_call_reference_argument_run|call_reference_argument_has_dynamic_indexed_root|call_reference_access_base_has_dynamic_index|call_argument_is_naga_reference_access_chain|call_argument_access_root_is_naga_reference' modules/wgsl/ir --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "call argument scheduling must not be split back into legacy lowerer lookahead predicates"
fi

if [[ ! -f modules/wgsl/ir/wgsl_lower_short_circuit_planner.mbt ]]; then
  fail "WGSL short-circuit materialization must be owned by ShortCircuitPlanner"
fi

if ! rg -n 'priv struct ShortCircuitPlanner' modules/wgsl/ir/wgsl_lower_short_circuit_planner.mbt >/dev/null; then
  fail "ShortCircuitPlanner must be the concrete short-circuit materialization planner"
fi

for short_circuit_entry in \
  'materialize_value_handle' \
  'materialize_value_node' \
  'materialize_condition_handle' \
  'materialize_condition_node' \
  'materialize_branch_handle' \
  'materialize_branch_node' \
  'append_result_load' \
  'allocate_result_local'; do
  if ! rg -n "$short_circuit_entry" modules/wgsl/ir/wgsl_lower_short_circuit_planner.mbt >/dev/null; then
    fail "ShortCircuitPlanner is missing required entry: $short_circuit_entry"
  fi
done

if ! rg -n 'short_circuit_planner\(.*\)' modules/wgsl/ir/wgsl_lower_control_flow.mbt modules/wgsl/ir/wgsl_lower_statements.mbt modules/wgsl/ir/wgsl_lower_materialization.mbt >/dev/null; then
  fail "short-circuit control-flow, return, and nested materialization paths must enter ShortCircuitPlanner"
fi

if rg -n 'materialize_short_circuit_expression|materialize_short_circuit_condition|materialize_short_circuit_branch|append_short_circuit_result|allocate_short_circuit_result' modules/wgsl/ir --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "short-circuit materialization must not be split back into legacy lowerer helpers"
fi

if rg -n 'WgslIrFunctionBodyWriterPlan::from_function\(function\)' modules/wgsl/ir/wgsl_emit_functions.mbt modules/wgsl/ir/wgsl_emit_statements.mbt >"$matches_file"; then
  cat "$matches_file" >&2
  fail "function emission must consume WgslIrFunctionWriterPlan instead of rebuilding body plans from raw IR"
fi

if rg -n 'WgslIrFunctionBodyWriterPlan::from_function\(function\)' modules/wgsl/ir/wgsl_writer_names.mbt modules/wgsl/ir/wgsl_emit_final_name_plan.mbt >"$matches_file"; then
  cat "$matches_file" >&2
  fail "final-name allocation must consume WgslIrFunctionWriterPlan instead of rebuilding body plans from raw IR"
fi

if rg -n 'build_wgsl_ir_runtime_final_name_plan' modules/wgsl/ir --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "runtime and compat writers must share the writer-slot final-name plan"
fi

if rg -n 'statement_is_local_var_declaration|statement_is_any_local_var_declaration' modules/wgsl/ir/wgsl_emit_statements.mbt >/dev/null; then
  fail "statement emitter must consume body-plan statement items instead of owning local declaration scanning"
fi

if rg -n 'WgslIrFunctionScope::function_expression_temporary_name|scope\.function_expression_temporary_name|baked_function_expressions|record_baked_function_expression|projected_temporary_name_offset|hidden_temporary_name_indices|hide_temporary_name_indices|record_projected_temporary_expression' \
  modules/wgsl/ir --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "expression temporary names must not be assigned by lowering scope counters or emitter baked-name writeback"
fi

if [[ ! -f modules/wgsl/ir/pkg.mbti ]]; then
  fail "IR package must own an explicit public interface whitelist in modules/wgsl/ir/pkg.mbti"
fi

if rg -n 'pub (struct|enum|typealias) (Module|ModuleInfo|EntryPoint|Function|FunctionArgument|FunctionResult|Statement|Block|Expression|Literal|Type|TypeInner|Scalar|VectorSize|AddressSpace|StorageAccess|Binding|BuiltIn|Handle|ExpressionArena|TypeArena|FunctionArena|ConstantArena|DiagnosticFilterArena|GlobalVariable|LocalVariable|Override|Constant|StructMember|ImageClass|ImageDimension|StorageFormat|WgslIrEmitter|WgslIrLowerer|WgslIrValidator)' modules/wgsl/ir/pkg.mbti >"$matches_file"; then
  cat "$matches_file" >&2
  fail "IR public interface must not expose internal IR model, arenas, handles, lowerer, emitter, or validator types"
fi

if rg -n 'Naga|naga_oil|compat_writer|trace_compat_writer|WgslIrEmitOptions|WgslIrWriterBytePlan|WgslIrWriterSemanticPlan' modules/wgsl/ir/pkg.mbti >"$matches_file"; then
  cat "$matches_file" >&2
  fail "IR public surface must expose semantic IR contracts only, not Naga-compatible writer policy"
fi

if rg -n 'pub (fn (lower_wgsl_translation_unit_to_ir|lower_wgsl_translation_unit_to_ir_with_generated_imports|emit_wgsl_module_from_ir|emit_wgsl_module_from_ir_roots)|suberror WgslIrEmitError)' modules/wgsl/ir \
  --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "raw WGSL IR AST-lower and emit APIs must remain internal; public callers must use semantic parse/validate or the validated pipeline"
fi

if rg -n 'lower_wgsl_translation_unit_to_ir|lower_validated_wgsl_source_to_ir|emit_validated_wgsl_source_from_ir|emit_wgsl_module_from_ir|WgslIrEmitError|WgslIrEmitFilter' modules/wgsl/ir/pkg.mbti >"$matches_file"; then
  cat "$matches_file" >&2
  fail "IR explicit public interface must not expose raw AST-lower/emit internals"
fi

if rg -n 'lower_wgsl_translation_unit_to_ir|lower_validated_wgsl_source_to_ir|emit_validated_wgsl_source_from_ir|emit_wgsl_module_from_ir|WgslIrEmitError|WgslIrEmitFilter' modules/wgsl/ir/pkg.generated.mbti >"$matches_file"; then
  cat "$matches_file" >&2
  fail "IR public interface must not expose raw AST-lower/emit internals"
fi

if ! rg -n 'roundtrip_wgsl_source_via_ir_with_generated_imports' modules/moon_wgsl_naga_oil/compose/pipeline.mbt >/dev/null; then
  fail "modules/moon_wgsl_naga_oil/compose final WGSL output must enter the unified IR roundtrip pipeline"
fi

session_fields="$(sed -n '/priv struct WgslComposeSession {/,/^}/p' modules/moon_wgsl_naga_oil/compose/session.mbt)"
if ! printf '%s\n' "$session_fields" | rg -n 'symbols : WgslComposeSymbolTable' >/dev/null; then
  fail "modules/moon_wgsl_naga_oil/compose session must own symbol/provenance facts through WgslComposeSymbolTable"
fi
if printf '%s\n' "$session_fields" | rg -n 'source_origins|assigned_final_names|final_names|virtual_override_final_names' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "modules/moon_wgsl_naga_oil/compose session must not keep symbol/source-origin facts outside WgslComposeSymbolTable"
fi

resolved_fields="$(sed -n '/priv struct WgslResolvedComposeSource {/,/^}/p' modules/moon_wgsl_naga_oil/compose/pipeline.mbt)"
if printf '%s\n' "$resolved_fields" | rg -n 'source_origins|virtual_override_generated_imports' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "resolved modules/moon_wgsl_naga_oil/compose output must carry the symbol table instead of duplicated provenance arrays"
fi

if [[ -f modules/moon_wgsl_naga_oil/compose/import_graph.mbt ]]; then
  fail "modules/moon_wgsl_naga_oil/compose import graph stages must not collapse back into modules/moon_wgsl_naga_oil/compose/import_graph.mbt"
fi

required_compose_stage_files=(
  modules/moon_wgsl_naga_oil/compose/stage_objects.mbt
  modules/moon_wgsl_naga_oil/compose/final_name_plan.mbt
  modules/moon_wgsl_naga_oil/compose/source_preparation.mbt
  modules/moon_wgsl_naga_oil/compose/import_request_builder.mbt
  modules/moon_wgsl_naga_oil/compose/import_request_execution.mbt
  modules/moon_wgsl_naga_oil/compose/finalize.mbt
)
for stage_file in "${required_compose_stage_files[@]}"; do
  if [[ ! -f "$stage_file" ]]; then
    fail "modules/moon_wgsl_naga_oil/compose graph/rewrite responsibilities must stay staged: missing ${stage_file}"
  fi
done

if ! rg -n 'priv struct WgslImportGraphBuilder|priv struct WgslReachabilityPlan|priv struct WgslFinalNameAllocator|priv struct WgslComposeEmitter' modules/moon_wgsl_naga_oil/compose/stage_objects.mbt >/dev/null; then
  fail "modules/moon_wgsl_naga_oil/compose stage objects must explicitly model import graph, reachability, final-name allocation, and emission stages"
fi

if ! rg -n 'WgslImportGraphBuilder\(self, session\)\.complete_execution' modules/moon_wgsl_naga_oil/compose/pipeline.mbt >/dev/null; then
  fail "modules/moon_wgsl_naga_oil/compose pipeline must enter graph execution through WgslImportGraphBuilder"
fi

if ! rg -n 'WgslReachabilityPlan\(facts, bindings\)\.live_binding_plan' modules/moon_wgsl_naga_oil/compose/finalize.mbt >/dev/null; then
  fail "modules/moon_wgsl_naga_oil/compose finalization must enter live binding through WgslReachabilityPlan"
fi

if ! rg -n 'WgslFinalNameAllocator\(' modules/moon_wgsl_naga_oil/compose/import_request_execution.mbt >/dev/null; then
  fail "modules/moon_wgsl_naga_oil/compose import emission must allocate final names through WgslFinalNameAllocator"
fi

if ! rg -n 'WgslComposeEmitter\(self, session\)\.emit_source_with_path|WgslComposeEmitter\(self, session\)\.emit_root' modules/moon_wgsl_naga_oil/compose/pipeline.mbt modules/moon_wgsl_naga_oil/compose/import_request_execution.mbt >/dev/null; then
  fail "modules/moon_wgsl_naga_oil/compose source assembly must enter emission through WgslComposeEmitter"
fi

if rg -n 'fn Composer::(resolve_wgsl_source_with_path|resolve_root_wgsl_source_into_session|plan_wgsl_compose_graph_with_path|plan_wgsl_import_request_batch)' modules/moon_wgsl_naga_oil/compose --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "modules/moon_wgsl_naga_oil/compose graph planning and source emission internals must live on explicit stage objects, not Composer methods"
fi

if ! rg -n 'WgslComposeSymbolTable::generated_import_provenance' modules/moon_wgsl_naga_oil/compose/pipeline.mbt >/dev/null; then
  fail "generated import provenance must derive from the modules/moon_wgsl_naga_oil/compose symbol table"
fi

if ! rg -n 'validate_wgsl_ir_module\(reparsed\)' modules/wgsl/ir/wgsl_pipeline.mbt >/dev/null; then
  fail "unified IR pipeline must validate emitted WGSL after reparsing it into IR"
fi

if rg -n 'normalize_wgsl_output_identifiers|normalize_wgsl_composed_declarations_with_binding_plan|unresolved_wgsl_semantic_namespace_reference' modules/moon_wgsl_naga_oil/compose \
  --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "modules/moon_wgsl_naga_oil/compose finalization must not use source-level semantic normalization or namespace scans"
fi

if rg -n 'emit_wgsl_tree_shaken_source_strict' modules/moon_wgsl_naga_oil/export --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "export tree shaking must use IR reachability, not source-level declaration extraction"
fi

if rg -n 'pub fn (emit_wgsl_tree_shaken_source_strict|normalize_wgsl_output_identifiers|invalid_wgsl_struct_member_identifier|normalize_wgsl_composed_declarations|normalize_wgsl_composed_declarations_with_binding_plan)|pub struct WgslTreeShakenSource' modules/moon_wgsl_naga_oil/transform \
  --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "modules/moon_wgsl_naga_oil/transform must not expose source-level WGSL semantic rewrite/tree-shake APIs"
fi

if rg -n 'WgslRenamePlan|WgslRenameRule|WgslRenameMaps|build_wgsl_rename_maps|collect_wgsl_block_rewrite_nodes|target_for_reference' modules/moon_wgsl_naga_oil/transform \
  --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "modules/moon_wgsl_naga_oil/transform must not own name-first semantic rename policy"
fi

required_transform_rewrite_files=(
  modules/moon_wgsl_naga_oil/transform/rewrite_plan.mbt
  modules/moon_wgsl_naga_oil/transform/rewrite_collectors.mbt
  modules/moon_wgsl_naga_oil/transform/wgsl_binding.mbt
)
for rewrite_file in "${required_transform_rewrite_files[@]}"; do
  if [[ ! -f "$rewrite_file" ]]; then
    fail "modules/moon_wgsl_naga_oil/transform rewrite backend must keep plan, collector, and facade responsibilities split: missing ${rewrite_file}"
  fi
done

if rg -n 'emit_wgsl_tree_shaken_source_strict|normalize_wgsl_output_identifiers|invalid_wgsl_struct_member_identifier|normalize_wgsl_composed_declarations|WgslTreeShakenSource' modules/moon_wgsl_naga_oil/transform/pkg.generated.mbti >"$matches_file"; then
  cat "$matches_file" >&2
  fail "modules/moon_wgsl_naga_oil/transform public interface must not expose source-level WGSL semantic rewrite/tree-shake APIs"
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
  fail "external WGSL corpus profiles must gate raw vs modules/moon_wgsl_naga_oil/compose execution modes"
fi

if [[ ! -f testdata/external_wgsl_corpus_compose_sources.tsv ]]; then
  fail "external WGSL corpus modules/moon_wgsl_naga_oil/compose sources must be manifest-owned"
fi

if ! rg -n 'compose_source_expected|compose_source_actual|modules/moon_wgsl_naga_oil/compose-source\.diff' tools/check_external_wgsl_corpus.sh >/dev/null; then
  fail "external WGSL corpus gate must exact-gate the concrete modules/moon_wgsl_naga_oil/compose source files"
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

if [[ ! -f testdata/naga_oil_upstream/compose_tests/error_parity_cases.tsv ]]; then
  fail "naga_oil diagnostic parity cases must be owned by a manifest"
fi

if ! rg -n 'expected 6|machine-readable diagnostic summary drift|rendered diagnostic byte drift' tools/check_moon_wgsl_error_parity.sh >/dev/null; then
  fail "diagnostic parity gate must schema-check rows and compare summary plus byte diagnostics"
fi

if ! rg -n 'cargo run .*--bin naga_oil_oracle|diff -u "\$oracle_summary" "\$moon_summary"|diff -u "\$oracle_output" "\$moon_output"' tools/check_moon_wgsl_error_parity.sh >/dev/null; then
  fail "diagnostic parity gate must compare moon_wgsl directly against the pinned naga_oil oracle"
fi

if rg -n -- '--runtime-valid' tools/check_moon_wgsl_byte_parity.sh >/dev/null && \
  ! rg -n 'check_runtime_valid_case' tools/check_moon_wgsl_byte_parity.sh >/dev/null; then
  fail "byte parity must use default upstream writer output; runtime-valid mode is allowed only for the atomics validation cross-check"
fi

if ! rg -n 'compose_runtime_valid_roundtrip_case' tools/check_ir_roundtrip_corpus.sh >/dev/null; then
  fail "IR roundtrip validation must keep runtime-valid modules/moon_wgsl_naga_oil/compose cases explicit"
fi

if ! rg -n 'compose_wgsl_runtime_valid' tools/wgsl_validation_cases/main.mbt >/dev/null; then
  fail "WGSL validation generators must use the explicit runtime-valid modules/moon_wgsl_naga_oil/compose path"
fi

if ! rg -n 'bash tools/check_external_wgsl_corpus\.sh' .github/workflows/check.yml >/dev/null; then
  fail "CI must run the external real-project WGSL corpus gate"
fi

if rg -n '_min_valid|_min_composed|min_valid|min_composed' tools/check_external_naga_oil_compose_parity.sh >"$matches_file"; then
  cat "$matches_file" >&2
  fail "external naga-oil modules/moon_wgsl_naga_oil/compose parity must consume the exact-count external repo manifest schema"
fi

if ! rg -n 'external naga-oil compose parity row has.*expected 7' tools/check_external_naga_oil_compose_parity.sh >/dev/null; then
  fail "external naga-oil modules/moon_wgsl_naga_oil/compose parity manifest must enforce exact TSV schema width"
fi

if ! rg -n 'EXTERNAL_NAGA_OIL_COMPOSE_PARITY_EXPECTED_CASES|expected_case_count' tools/check_external_naga_oil_compose_parity.sh >/dev/null; then
  fail "external naga-oil modules/moon_wgsl_naga_oil/compose parity gate must exact-gate its manifest case count"
fi

if ! rg -n 'expected_case_count="\$\{EXTERNAL_NAGA_OIL_COMPOSE_PARITY_EXPECTED_CASES:-170\}"' tools/check_external_naga_oil_compose_parity.sh >/dev/null; then
  fail "external naga-oil compose parity must default to the full 170-case real-project compose-source inventory"
fi

if [[ ! -f testdata/external_naga_oil_compose_oracle_blocked.tsv ]]; then
  fail "external naga-oil modules/moon_wgsl_naga_oil/compose parity oracle-blocked cases must be manifest-owned"
fi

if [[ ! -f testdata/external_naga_oil_compose_writer_drift.tsv ]]; then
  fail "external naga-oil modules/moon_wgsl_naga_oil/compose parity writer/order/name drift must keep an empty sentinel manifest"
fi

if [[ -f testdata/external_naga_oil_compose_byte_drift.tsv ||
      -f testdata/external_naga_oil_compose_drift_taxonomy.tsv ||
      -f testdata/external_naga_oil_compose_byte_trace_roots.tsv ||
      -f tools/check_external_naga_oil_drift_taxonomy.sh ]]; then
  fail "external naga-oil modules/moon_wgsl_naga_oil/compose byte drift is no longer allowlisted; remove legacy drift inventory files and fix regressions structurally"
fi

external_compose_case_count="$(awk -F '\t' '$0 !~ /^($|#)/ && $1 != "id" { count += 1 } END { print count + 0 }' testdata/external_naga_oil_compose_parity.tsv)"
if (( external_compose_case_count != 170 )); then
  fail "external naga-oil compose parity manifest must contain the full 170-case inventory, got ${external_compose_case_count}"
fi

external_oracle_blocked_count="$(awk -F '\t' '$0 !~ /^($|#)/ && $1 != "id" { count += 1 } END { print count + 0 }' testdata/external_naga_oil_compose_oracle_blocked.tsv)"
if (( external_oracle_blocked_count != 21 )); then
  fail "external naga-oil compose parity oracle-blocked manifest must contain exactly 21 pinned-upstream blocked cases, got ${external_oracle_blocked_count}"
fi

if ! rg -n 'writer/order/name drift is no longer allowlisted|fix WGSL-283 structurally' tools/check_external_naga_oil_compose_parity.sh >/dev/null; then
  fail "external naga-oil modules/moon_wgsl_naga_oil/compose parity writer drift must hard-fail instead of being allowlisted"
fi

if rg -n 'MOON_WGSL_ALLOW_KNOWN_DRIFT|EXTERNAL_NAGA_OIL_COMPOSE_PARITY_BYTE_DRIFT_MANIFEST|byte_drift_manifest|byte_drift_expected|known drift allowed|legacy drift-manifest' \
  tools/check_external_naga_oil_compose_parity.sh .github/workflows/check.yml >/dev/null; then
  fail "external naga-oil modules/moon_wgsl_naga_oil/compose parity must not retain legacy known byte-drift mode"
fi

if ! rg -n 'rm -rf "\$failure_dir"' tools/check_external_naga_oil_compose_parity.sh >/dev/null ||
   ! rg -n 'cp "\$byte_diff" "\$failure_dir/diffs/\$label\.byte\.diff"' tools/check_external_naga_oil_compose_parity.sh >/dev/null; then
  fail "external naga-oil modules/moon_wgsl_naga_oil/compose parity must rebuild current byte-drift artifacts in both strict and known-drift modes"
fi

if [[ ! -f tools/naga_oil_oracle/src/bin/wgsl_writer_fingerprint.rs ]]; then
  fail "external naga-oil modules/moon_wgsl_naga_oil/compose parity must own a writer/order/name fingerprint tool"
fi

if ! rg -n 'wgsl_writer_fingerprint' tools/check_external_naga_oil_compose_parity.sh tools/naga_oil_oracle/src/bin/wgsl_writer_fingerprint.rs >/dev/null; then
  fail "external naga-oil modules/moon_wgsl_naga_oil/compose parity must execute the writer/order/name fingerprint tool"
fi

if ! rg -n 'writer-drift\.diff|byte-drift\.diff|modules/moon_wgsl_naga_oil/compose-source-parity\.diff|materialize_profile_source_overlay|append_detected_capabilities' tools/check_external_naga_oil_compose_parity.sh >/dev/null; then
  fail "external naga-oil modules/moon_wgsl_naga_oil/compose parity must exact-gate full inventory coverage, profile overlays, detected capabilities, and drift manifests"
fi

if ! rg -n 'diff -u --label expected --label actual' tools/check_external_naga_oil_compose_parity.sh >/dev/null; then
  fail "external naga-oil modules/moon_wgsl_naga_oil/compose parity drift hashes must be independent of temporary diff paths"
fi

if ! rg -n 'materialize_raw_template_value_defs|raw-overlay' tools/check_external_naga_oil_compose_parity.sh >/dev/null; then
  fail "external naga-oil modules/moon_wgsl_naga_oil/compose parity must materialize raw template value defs before comparing with the upstream oracle"
fi

if ! rg -n 'cached_repo_id|cached_checkout' tools/check_external_naga_oil_compose_parity.sh >/dev/null; then
  fail "external naga-oil modules/moon_wgsl_naga_oil/compose parity must cache repository checkouts so full-inventory gates can scale"
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

if rg -n 'Milky2018/moon_wgsl/modules/moon_wgsl_naga_oil/transform' modules/moon_wgsl_naga_oil/metadata/moon.pkg modules/moon_wgsl_naga_oil/preprocess/moon.pkg >"$matches_file"; then
  cat "$matches_file" >&2
  fail "modules/moon_wgsl_naga_oil/metadata and modules/moon_wgsl_naga_oil/preprocess must not depend on modules/moon_wgsl_naga_oil/transform; import substitution owns preprocessing import rewrites"
fi

if rg -n 'WgslImportSubstitution(State|Error)|import_syntax' modules/moon_wgsl_naga_oil/transform/pkg.generated.mbti modules/moon_wgsl_naga_oil/transform/moon.pkg >"$matches_file"; then
  cat "$matches_file" >&2
  fail "modules/moon_wgsl_naga_oil/transform public API must not expose preprocessing import substitution contracts"
fi

if [[ ! -f modules/moon_wgsl_naga_oil/import_substitution/pkg.mbti || ! -f modules/moon_wgsl_naga_oil/source_rewrite/pkg.mbti || ! -f modules/moon_wgsl_naga_oil/transform/pkg.mbti ]]; then
  fail "import substitution, source rewrite, and modules/moon_wgsl_naga_oil/transform packages must own explicit public interface whitelists"
fi

if rg -n 'WgslImportSubstitution(State|Error)|WgslTokenReplacement|emit_wgsl_|tokenize_wgsl_|import_syntax' modules/moon_wgsl_naga_oil/transform/pkg.mbti >"$matches_file"; then
  cat "$matches_file" >&2
  fail "modules/moon_wgsl_naga_oil/transform explicit public interface must not expose preprocessing or source rewrite backend contracts"
fi

echo "architecture guardrails passed"
