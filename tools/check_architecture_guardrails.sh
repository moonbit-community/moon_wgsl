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

section() {
  echo "architecture guardrail: $*"
}

require_file() {
  local path="$1"
  local reason="$2"
  [[ -f "$path" || -L "$path" ]] || fail "$reason: missing $path"
}

forbid_path() {
  local path="$1"
  local reason="$2"
  [[ ! -e "$path" ]] || fail "$reason: found $path"
}

require_rg() {
  local pattern="$1"
  local path="$2"
  local reason="$3"
  rg -n "$pattern" "$path" >/dev/null || fail "$reason"
}

forbid_rg() {
  local pattern="$1"
  local path="$2"
  local reason="$3"
  shift 3
  if rg -n "$pattern" "$path" "$@" >"$matches_file"; then
    cat "$matches_file" >&2
    fail "$reason"
  fi
}

require_workflow_gate() {
  local script="$1"
  require_rg "bash ${script//./\\.}" .github/workflows/check.yml "CI must run $script"
}

section "metadata"
python3 tools/check_architecture_metadata.py
python3 tools/check_docs_freshness.py

section "module boundaries"
forbid_rg \
  'moonbitlang/x|moonbitlang/core/(env|process)' \
  modules \
  "published modules must stay pure and leave host I/O to workspace/application adapters" \
  --glob 'moon.mod' --glob 'moon.pkg' --glob '*.mbt' --glob '*.mbti'

required_boundary_files=(
  modules/wgsl/ir/pkg.mbti
  modules/wgsl/parser/pkg.mbti
  modules/wgsl/ir/wgsl_emit_expression_types.mbt
  modules/wgsl/ir/wgsl_emit_filter.mbt
  modules/wgsl/ir/wgsl_emit_types.mbt
  modules/moon_wgsl_naga/pipeline.mbt
  modules/moon_wgsl_naga/wgsl_emit_compat_writer.mbt
  modules/moon_wgsl_naga/wgsl_writer_trace.mbt
  modules/moon_wgsl_naga_oil/compose/pipeline.mbt
  modules/moon_wgsl_naga_oil/compose/stage_objects.mbt
  modules/moon_wgsl_naga_oil/compose/final_name_plan.mbt
  modules/moon_wgsl_naga_oil/compose/source_preparation.mbt
  modules/moon_wgsl_naga_oil/compose/import_request_builder.mbt
  modules/moon_wgsl_naga_oil/compose/import_request_execution.mbt
  modules/moon_wgsl_naga_oil/compose/finalize.mbt
  modules/moon_wgsl_naga_oil/internal/transform/rewrite_plan.mbt
  modules/moon_wgsl_naga_oil/internal/transform/rewrite_collectors.mbt
  modules/moon_wgsl_naga_oil/internal/transform/wgsl_binding.mbt
)
for file in "${required_boundary_files[@]}"; do
  require_file "$file" "required architecture boundary file"
done

legacy_paths=(
  modules/wgsl/ir/wgsl_lower.mbt
  modules/wgsl/ir/wgsl_emit_compat_writer.mbt
  modules/wgsl/ir/wgsl_writer_trace.mbt
  modules/wgsl/parser/wgsl_ast_expr_type.mbt
  modules/wgsl/common/types.mbt
  modules/moon_wgsl_naga_oil/compose/import_graph.mbt
  modules/moon_wgsl_naga/wgsl_emit_expression_types.mbt
  modules/moon_wgsl_naga/wgsl_emit_filter.mbt
  modules/moon_wgsl_naga/wgsl_emit_types.mbt
  testdata/gpuweb_cts_ir_allowlist.txt
  testdata/external_wgsl_corpus_skips.tsv
  testdata/external_wgsl_corpus_expected_failures.tsv
)
for path in "${legacy_paths[@]}"; do
  forbid_path "$path" "legacy architecture path must not be reintroduced"
done

section "public API surfaces"
forbid_rg \
  'Naga|naga_oil|compat_writer|trace_compat_writer|WgslIrEmitOptions|WgslIrWriter(Byte|Semantic)Plan' \
  modules/wgsl/ir/pkg.mbti \
  "WGSL core IR public surface must not expose compatibility-writer policy"

forbid_rg \
  'lower_wgsl_translation_unit_to_ir|lower_validated_wgsl_source_to_ir|emit_validated_wgsl_source_from_ir|emit_wgsl_module_from_ir|WgslIrEmitError|WgslIrEmitFilter' \
  modules/wgsl/ir/pkg.mbti \
  "WGSL core IR public surface must not expose raw lowerer/emitter internals"

forbid_rg \
  'roundtrip_wgsl_source_via_ir_with_generated_imports_and_import_arena_events|trace_compat_writer_.*with_generated_imports_and_import_arena_events|with_import_context|WgslNagaWriterMode' \
  modules/moon_wgsl_naga/pkg.generated.mbti \
  "Naga compatibility public surface must not expose internal provenance or writer implementation names"

forbid_rg \
  'pub (fn (block|const_assert_expr|function_args|function_result|source_directive|struct_members|template_list|type_alias_tail|type_ref|typed_initializer_tail)|suberror ParseError|.*enum Token|.*enum TokenKind)' \
  modules/wgsl/parser/pkg.mbti \
  "WGSL parser public interface must not expose generated parser rule entrypoints or tokens"

section "compatibility ownership"
forbid_rg \
  'compat_writer|trace_compat_writer|CompatNumericLiteralSpelling|WgslIrEmitOptions::compat_writer|WgslIrWriterBytePlan::compat_writer|WgslIrWriterSemanticPlan::compat_writer' \
  modules/wgsl/ir \
  "WGSL core IR must not own Naga-compatible writer policy" \
  --glob '*.mbt'

require_rg 'build_wgsl_ir_writer_module\(' modules/moon_wgsl_naga/wgsl_emit_compat_writer.mbt \
  "Naga-compatible writer must build a writer module view before emission"
require_rg 'writer_module: self\.view' modules/moon_wgsl_naga/wgsl_emit_compat_writer.mbt \
  "Naga-compatible writer must emit through its writer module view"
require_rg 'validate_wgsl_ir_module\(self\.shader_module\)' modules/moon_wgsl_naga/wgsl_emit_compat_writer.mbt \
  "Naga-compatible writer must validate IR before writing source"
require_rg 'validate_wgsl_ir_module\(self\.shader_module\)' modules/wgsl/ir/wgsl_emit_runtime_writer.mbt \
  "runtime writer must validate IR before writing source"

section "composer pipeline"
require_rg 'roundtrip_wgsl_compose_source\(' modules/moon_wgsl_naga_oil/compose/pipeline.mbt \
  "naga-oil compose output must enter the unified IR roundtrip pipeline"
require_rg 'WgslNagaComposeContext::from_import_graph\(' modules/moon_wgsl_naga_oil/compose/pipeline.mbt \
  "naga-oil compose must pass import provenance through a structured compose context"
require_rg 'WgslImportGraphBuilder\(self, session\)\.complete_execution' modules/moon_wgsl_naga_oil/compose/pipeline.mbt \
  "compose graph execution must enter through WgslImportGraphBuilder"
require_rg 'WgslReachabilityPlan\(facts, bindings\)\.live_binding_plan' modules/moon_wgsl_naga_oil/compose/finalize.mbt \
  "compose finalization must enter live binding through WgslReachabilityPlan"
require_rg 'WgslFinalNameAllocator\(' modules/moon_wgsl_naga_oil/compose/import_request_execution.mbt \
  "compose import emission must allocate final names through WgslFinalNameAllocator"
require_rg 'WgslComposeEmitter\(self, session\)\.emit_source_with_path|WgslComposeEmitter\(self, session\)\.emit_root' \
  modules/moon_wgsl_naga_oil/compose \
  "compose source assembly must enter through WgslComposeEmitter"

forbid_rg \
  'active_scan_source|normalize_wgsl_output_identifiers|normalize_wgsl_composed_declarations_with_binding_plan|unresolved_wgsl_semantic_namespace_reference' \
  modules/moon_wgsl_naga_oil/compose \
  "compose must not use source-level scan strings or semantic source normalization" \
  --glob '*.mbt'

forbid_rg \
  'reference_rename_plan|global_declaration_rename_plan|WgslRenamePlan|WgslRenameRule|WgslRenameMaps|build_wgsl_rename_maps' \
  modules/moon_wgsl_naga_oil \
  "naga-oil rewrite paths must remain identity/plan backed, not name-first rename maps" \
  --glob '*.mbt'

section "no fallback semantics"
forbid_rg \
  'InvalidWgslSyntax\([^)]*\) => source|_ => AddressSpace::Private|Abstract\(value\).*value\.to_int\(\)|SwitchValue::I32\(value\.to_int\(\)\)' \
  modules \
  "semantic lowering must reject or type-check invalid inputs instead of falling back" \
  --glob '*.mbt'

forbid_rg \
  'registered_source\([^)]*\)[[:space:][:graph:]]{0,160}(None => ""|None => import_path)|module_rel_path_for_module_path\([^)]*\) == ""' \
  modules/moon_wgsl_naga_oil \
  "resolver/compose must not fabricate empty-string fallback values" \
  --glob '*.mbt'

forbid_rg \
  'emit_wgsl_tree_shaken_source_strict|normalize_wgsl_output_identifiers|invalid_wgsl_struct_member_identifier|normalize_wgsl_composed_declarations|WgslTreeShakenSource' \
  modules/moon_wgsl_naga_oil/internal/transform/pkg.generated.mbti \
  "internal transform interface must not expose obsolete source-level semantic rewrite/tree-shake APIs"

section "corpus and CI gates"
required_manifests=(
  testdata/wgsl_corpus_manifest.tsv
  testdata/wgsl_builtin_coverage_manifest.tsv
  testdata/wgsl_differential_generated_manifest.tsv
  testdata/wgsl_corpus_runtime_valid_compose.txt
  testdata/external_wgsl_corpus_expected_invalid.tsv
  testdata/external_wgsl_corpus_expected_invalid_normalized_by_ir.tsv
  testdata/naga_oil_upstream/compose_tests/parity_manifest.tsv
  testdata/gpuweb_cts_invalid_accepted_by_oracle.txt
  testdata/gpuweb_cts_template_ir_blocked_by_oracle.txt
  testdata/gpuweb_cts_template_invalid_accepted_by_oracle.txt
)
for manifest in "${required_manifests[@]}"; do
  require_file "$manifest" "coverage/classification manifest must be owned by the repository"
done

required_ci_gates=(
  tools/check_architecture_guardrails.sh
  tools/check_moon_test_filters.sh
  tools/check_ir_roundtrip_corpus.sh
  tools/check_wgsl_validation.sh
  tools/check_wgsl_corpus_matrix.sh
  tools/check_wgsl_builtin_coverage.sh
  tools/check_wgsl_differential_generated.sh
  tools/check_wgpu_validation.sh
  tools/check_moon_wgsl_byte_parity.sh
  tools/check_external_naga_oil_compose_parity.sh
  tools/check_moon_wgsl_error_parity.sh
  tools/check_naga_oil_parity_inventory.sh
  tools/check_preprocess_parity.sh
  tools/check_official_wgsl_corpus.sh
  tools/check_external_wgsl_corpus.sh
)
for gate in "${required_ci_gates[@]}"; do
  require_workflow_gate "$gate"
done

require_rg 'WGSL_CORPUS_EXPECTED_CASES|expected_case_count' tools/check_wgsl_corpus_matrix.sh \
  "WGSL corpus matrix must exact-gate its case count"
require_rg 'node "\$generator" --list' tools/check_wgsl_differential_generated.sh \
  "generated differential gate must compare manifest IDs against the generator catalog"
require_rg 'load_official_cts_id_manifest' tools/check_official_wgsl_corpus.sh \
  "official WGSL CTS oracle manifests must be schema-checked"
require_rg 'skipped=0' tools/check_external_wgsl_corpus.sh \
  "external WGSL corpus gate must report zero skipped files"

section "done"
echo "architecture guardrails passed"
