#!/usr/bin/env bash
set -euo pipefail

module_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
search_root="$module_root"

while true; do
  candidate="$search_root/.mooncakes/moonbitlang/yacc/moonyacc"
  if [[ -x "$candidate" ]]; then
    exec "$candidate" "$@"
  fi

  parent="$(dirname "$search_root")"
  if [[ "$parent" == "$search_root" ]]; then
    break
  fi
  search_root="$parent"
done

echo "moonyacc not found in module or workspace dependency caches" >&2
exit 1
