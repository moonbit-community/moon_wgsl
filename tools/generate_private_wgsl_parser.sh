#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: generate_private_wgsl_parser.sh <input.mbty> <output.mbt>" >&2
  exit 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

"$repo_root/.mooncakes/moonbitlang/yacc/moonyacc" \
  --input-mode array \
  "$1" | moonfmt > "$2"

bash "$repo_root/tools/privatize_moonyacc_output.sh" "$2"
