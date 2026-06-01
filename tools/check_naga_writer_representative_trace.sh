#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

out_dir="${MOON_WGSL_NAGA_WRITER_TRACE_DIR:-_build/parity/naga_writer_trace}"
manifest="${MOON_WGSL_NAGA_WRITER_TRACE_MANIFEST:-testdata/naga_writer_trace_cases.tsv}"
rm -rf "$out_dir"
mkdir -p "$out_dir"

if [[ ! -f "$manifest" ]]; then
  echo "naga writer trace manifest not found: $manifest" >&2
  exit 1
fi

awk -F '\t' '
  NR == 1 {
    expected = "id\tfixture_root\tentry\tfunction_prefix\tbool_defs\tvalue_defs\tadditional_imports\tcapabilities"
    if ($0 != expected) {
      print "invalid naga writer trace manifest header: " $0 > "/dev/stderr"
      exit 1
    }
    next
  }
  NF != 8 {
    print "invalid naga writer trace manifest row " NR ": expected 8 tab-separated fields, got " NF > "/dev/stderr"
    exit 1
  }
  $1 == "" || $2 == "" || $3 == "" || $4 == "" {
    print "invalid naga writer trace manifest row " NR ": id, fixture_root, entry, and function_prefix are required" > "/dev/stderr"
    exit 1
  }
  seen[$1]++ {
    print "duplicate naga writer trace case id: " $1 > "/dev/stderr"
    exit 1
  }
' "$manifest"

append_csv_arg() {
  local csv="$1"
  local flag="$2"
  shift 2
  if [[ "$csv" == "-" || "$csv" == "" ]]; then
    return 0
  fi
  local item
  IFS=',' read -r -a items <<< "$csv"
  for item in "${items[@]}"; do
    "$@" "$flag" "$item"
  done
}

push_moon_arg() {
  moon_args+=("$1" "$2")
}

push_oracle_arg() {
  oracle_args+=("$1" "$2")
}

normalize_oracle_trace() {
  local inventory="$1"
  local function_prefix="$2"
  local output="$3"
  awk -F '\t' -v prefix="fn:${function_prefix}" '
  $1 == "function" { active = index($2, prefix) == 1 }
  active && $1 == "expression" {
    kind = $4
    sub(/\(.*/, "", kind)
    sub(/ \{.*/, "", kind)
    print "expression\t" $3 "\t" kind
  }
  active && $1 == "body" {
    body = $3
    statement = 0
    while (match(body, /(Emit\(\[[0-9]+\.\.[0-9]+\]\)|Call \{[^}]*result: Some\(\[[0-9]+\]\)[^}]*\}|Return \{[^}]*\})/)) {
      item = substr(body, RSTART, RLENGTH)
      if (item ~ /^Emit/) {
        range = item
        sub(/^Emit\(\[/, "", range)
        sub(/\]\)$/, "", range)
        split(range, parts, "\\.\\.")
        start = parts[1] + 0
        end = parts[2] - 1
        print "statement\t" statement "\tEmit(" start ".." end ")"
      } else if (item ~ /^Call/) {
        result = item
        sub(/^.*result: Some\(\[/, "", result)
        sub(/\]\).*$/, "", result)
        print "statement\t" statement "\tCall(result=" result ")"
      } else if (item ~ /^Return/) {
        print "statement\t" statement "\tReturn"
      }
      body = substr(body, RSTART + RLENGTH)
      statement = statement + 1
    }
  }
' "$inventory" > "$output"
}

normalize_moon_trace() {
  local trace="$1"
  local output="$2"
  awk -F '\t' '
  $1 == "expression" { print "expression\t" $3 "\t" $4 }
  $1 == "statement" { print "statement\t" $3 "\t" $4 }
' "$trace" > "$output"
}

normalize_oracle_bindings() {
  local inventory="$1"
  local wgsl="$2"
  local function_prefix="$3"
  local output="$4"
  awk -F '\t' -v prefix="fn:${function_prefix}" -v function_prefix="$function_prefix" -v wgsl="$wgsl" '
  BEGIN {
    while ((getline line < wgsl) > 0) {
      if (line ~ ("^fn " function_prefix) || line ~ ("^fn " function_prefix "[A-Za-z0-9_]*\\(")) {
        signature = line
        sub(/^fn [^(]*\(/, "", signature)
        sub(/\).*/, "", signature)
        count = split(signature, params, ",")
        for (i = 1; i <= count; i = i + 1) {
          param = params[i]
          gsub(/^ +| +$/, "", param)
          sub(/:.*/, "", param)
          final_arg[i - 1] = param
        }
        break
      }
    }
    close(wgsl)
  }
  $1 == "function" { active = index($2, prefix) == 1 }
  active && $1 == "expression" && $4 ~ /^FunctionArgument/ {
    arg_index = $4
    sub(/^FunctionArgument\(/, "", arg_index)
    sub(/\).*$/, "", arg_index)
    if (arg_index in final_arg) {
      print "binding\t" $3 "\t" final_arg[arg_index]
    }
  }
' "$inventory" > "$output"
}

normalize_moon_bindings() {
  local trace="$1"
  local output="$2"
  awk -F '\t' '
  $1 == "binding" && $3 == "argument" { print "binding\t" $4 "\t" $5 }
' "$trace" > "$output"
}

normalize_oracle_materialized() {
  local inventory="$1"
  local function_prefix="$2"
  local output="$3"
  awk -F '\t' -v prefix="fn:${function_prefix}" '
  $1 == "function" { active = index($2, prefix) == 1 }
  active && $1 == "body" {
    text = $0
    while (match(text, /result: Some\(\[[0-9]+\]\)/)) {
      item = substr(text, RSTART, RLENGTH)
      gsub(/[^0-9]/, "", item)
      print "materialized\t" item "\ttemp=_e" item
      text = substr(text, RSTART + RLENGTH)
    }
  }
' "$inventory" > "$output"
}

normalize_moon_materialized() {
  local trace="$1"
  local output="$2"
  awk -F '\t' '
  $1 == "expression" && $0 ~ /materialized=true/ {
    temp = $0
    sub(/^.*\ttemp=/, "", temp)
    sub(/\t.*$/, "", temp)
    print "materialized\t" $3 "\ttemp=" temp
  }
' "$trace" > "$output"
}

run_case() {
  local id="$1"
  local fixture_root="$2"
  local entry="$3"
  local function_prefix="$4"
  local bool_defs="$5"
  local value_defs="$6"
  local additional_imports="$7"
  local capabilities="$8"
  local case_dir="$out_dir/$id"
  local expression_drift=0
  local binding_drift=0
  local materialized_drift=0

  mkdir -p "$case_dir"
  moon_args=(
    --fixture-root "$fixture_root"
    --entry "$entry"
    --naga-writer-trace-function "$function_prefix"
    --output "$case_dir/moon.trace"
  )
  oracle_args=(
    --fixture-root "$fixture_root"
    --entry "$entry"
    --output "$case_dir/oracle.wgsl"
    --expression-inventory "$case_dir/oracle.inventory"
  )

  append_csv_arg "$bool_defs" --def push_moon_arg
  append_csv_arg "$bool_defs" --def push_oracle_arg
  append_csv_arg "$value_defs" --value-def push_moon_arg
  append_csv_arg "$value_defs" --def push_oracle_arg
  append_csv_arg "$additional_imports" --additional-import push_moon_arg
  append_csv_arg "$additional_imports" --additional-import push_oracle_arg
  append_csv_arg "$capabilities" --capability push_oracle_arg

  moon run tools/compose_case -- "${moon_args[@]}"
  cargo run --quiet --manifest-path tools/naga_oil_oracle/Cargo.toml --bin naga_oil_oracle -- "${oracle_args[@]}"

  normalize_oracle_trace "$case_dir/oracle.inventory" "$function_prefix" "$case_dir/oracle.expression-order"
  normalize_moon_trace "$case_dir/moon.trace" "$case_dir/moon.expression-order"
  normalize_oracle_bindings "$case_dir/oracle.inventory" "$case_dir/oracle.wgsl" "$function_prefix" "$case_dir/oracle.bindings"
  normalize_moon_bindings "$case_dir/moon.trace" "$case_dir/moon.bindings"
  normalize_oracle_materialized "$case_dir/oracle.inventory" "$function_prefix" "$case_dir/oracle.materialized"
  normalize_moon_materialized "$case_dir/moon.trace" "$case_dir/moon.materialized"

  diff -u "$case_dir/oracle.expression-order" "$case_dir/moon.expression-order" > "$case_dir/expression-order.diff" || expression_drift=1
  diff -u "$case_dir/oracle.bindings" "$case_dir/moon.bindings" > "$case_dir/bindings.diff" || binding_drift=1
  diff -u "$case_dir/oracle.materialized" "$case_dir/moon.materialized" > "$case_dir/materialized.diff" || materialized_drift=1

  if [[ "$expression_drift" == 0 && "$binding_drift" == 0 && "$materialized_drift" == 0 ]]; then
    echo "naga writer representative trace parity passed: $id: $entry :: $function_prefix"
    return 0
  fi

  echo "naga writer representative trace drift: $id: $entry :: $function_prefix" >&2
  echo "artifacts: $case_dir" >&2
  [[ "$expression_drift" == 0 ]] || sed -n '1,120p' "$case_dir/expression-order.diff" >&2
  [[ "$binding_drift" == 0 ]] || sed -n '1,120p' "$case_dir/bindings.diff" >&2
  [[ "$materialized_drift" == 0 ]] || sed -n '1,120p' "$case_dir/materialized.diff" >&2
  return 1
}

failures=0
case_count=0
while IFS=$'\t' read -r id fixture_root entry function_prefix bool_defs value_defs additional_imports capabilities; do
  if [[ "$id" == "id" ]]; then
    continue
  fi
  case_count=$((case_count + 1))
  run_case "$id" "$fixture_root" "$entry" "$function_prefix" "$bool_defs" "$value_defs" "$additional_imports" "$capabilities" || failures=$((failures + 1))
done < "$manifest"

if [[ "$failures" == 0 ]]; then
  echo "naga writer representative trace parity passed: $case_count case(s)"
  exit 0
fi

echo "naga writer representative trace drift: $failures of $case_count case(s)" >&2
if [[ "${MOON_WGSL_ALLOW_KNOWN_TRACE_DRIFT:-0}" == 1 ]]; then
  exit 0
fi
exit 1
