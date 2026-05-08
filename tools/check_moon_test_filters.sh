#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

manifest="${MOON_TEST_FILTER_MANIFEST:-testdata/moon_test_filter_manifest.txt}"

fail() {
  printf 'Moon test filter guard failed: %s\n' "$*" >&2
  exit 1
}

[[ -f "$manifest" ]] || fail "missing filter manifest: $manifest"

filter_count=0
matched_count=0
while IFS= read -r filter; do
  [[ -n "$filter" ]] || continue
  [[ "$filter" != \#* ]] || continue
  filter_count=$((filter_count + 1))
  output="$(moon test --outline --filter "$filter")"
  matches="$(printf '%s\n' "$output" | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')"
  if ((matches == 0)); then
    printf 'filter matched no tests: %s\n' "$filter" >&2
    fail "targeted moon test filters must never silently select zero tests"
  fi
  matched_count=$((matched_count + matches))
done < "$manifest"

((filter_count > 0)) || fail "filter manifest contains no filters"

echo "Moon test filter guard passed: filters=$filter_count matched-tests=$matched_count"
