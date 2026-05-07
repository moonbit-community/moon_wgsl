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

if rg -n 'CachedQualifiedAliasBinding' compose transform ir --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "cached alias bindings must not be a separate compose binding phase"
fi

if rg -n 'pub fn WgslReferenceRewritePlan::add\(' transform --glob '*.mbt' >"$matches_file"; then
  cat "$matches_file" >&2
  fail "reference rewrite plans must not expose unscoped string-only bindings"
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
