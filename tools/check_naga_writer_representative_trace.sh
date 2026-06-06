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

push_moon_module_arg() {
  moon_module_args+=("$1" "$2")
}

push_oracle_arg() {
  oracle_args+=("$1" "$2")
}

append_moon_value_defs() {
  local csv="$1"
  local moon_push="$2"
  [[ "$csv" == "-" || "$csv" == "" ]] && return 0
  local item
  IFS=',' read -r -a items <<< "$csv"
  for item in "${items[@]}"; do
    [[ -n "$item" ]] || continue
    [[ "$item" != *=raw:* ]] || continue
    "$moon_push" --value-def "$item"
  done
}

append_value_defs() {
  local csv="$1"
  local moon_push="$2"
  local oracle_push="$3"
  [[ "$csv" == "-" || "$csv" == "" ]] && return 0
  local item
  IFS=',' read -r -a items <<< "$csv"
  for item in "${items[@]}"; do
    [[ -n "$item" ]] || continue
    [[ "$item" != *=raw:* ]] || continue
    "$moon_push" --value-def "$item"
    "$oracle_push" --def "$item"
  done
}

materialize_raw_template_value_defs() {
  local fixture_root="$1"
  local entry="$2"
  local value_defs="$3"
  local case_dir="$4"
  local overlay="$fixture_root"

  [[ -n "$value_defs" && "$value_defs" != "-" ]] || {
    printf '%s\n' "$fixture_root"
    return 0
  }

  IFS=',' read -r -a values <<< "$value_defs"
  local raw_values=()
  local value
  for value in "${values[@]}"; do
    [[ -n "$value" ]] || continue
    [[ "$value" == *=raw:* ]] || continue
    raw_values+=("$value")
  done

  if (( ${#raw_values[@]} == 0 )); then
    printf '%s\n' "$fixture_root"
    return 0
  fi

  overlay="$case_dir/raw-overlay"
  mkdir -p "$overlay"
  cp -R "$fixture_root/." "$overlay/"
  rm -rf "$overlay/.git"
  local target="$overlay/$entry"
  [[ -f "$target" ]] || {
    echo "raw template overlay entry not found: $entry" >&2
    return 1
  }

  for value in "${raw_values[@]}"; do
    local name="${value%%=*}"
    local raw="${value#*=raw:}"
    [[ -n "$name" ]] || {
      echo "raw template value-def has empty name: $value" >&2
      return 1
    }
    FROM="##${name}##" TO="$raw" perl -0pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/g' "$target"
  done

  printf '%s\n' "$overlay"
}

select_oracle_trace_label() {
  local inventory="$1"
  local function_prefix="$2"
  awk -F '\t' -v prefix="$function_prefix" '
  $1 == "function" {
    if ($2 == ("entry#0:" prefix) || $2 ~ ("^entry#[0-9]+:" prefix "$")) {
      print $2
      exit
    }
    if ($2 == ("fn:" prefix) && exact_fn == "") {
      exact_fn = $2
    }
    if (index($2, "fn:" prefix) == 1 && prefix_fn == "") {
      prefix_fn = $2
    }
    if ($2 ~ ("^entry#[0-9]+:" prefix) && prefix_entry == "") {
      prefix_entry = $2
    }
  }
  END {
    if (exact_fn != "") {
      print exact_fn
    } else if (prefix_fn != "") {
      print prefix_fn
    } else if (prefix_entry != "") {
      print prefix_entry
    }
  }
' "$inventory" | sed -n '1p'
}

trace_label_function_name() {
  local label="$1"
  case "$label" in
    fn:*)
      printf '%s\n' "${label#fn:}"
      ;;
    entry#:*)
      printf '%s\n' "${label#*:}"
      ;;
    entry#*:*)
      printf '%s\n' "${label#*:}"
      ;;
    *)
      printf '%s\n' "$label"
      ;;
  esac
}

select_oracle_text_function_name() {
  local wgsl="$1"
  local function_prefix="$2"
  local selected_label="$3"
  local source_name
  source_name="$(trace_label_function_name "$selected_label")"
  awk -v source_name="$source_name" -v function_prefix="$function_prefix" '
  $0 ~ ("^fn " source_name "\\(") {
    print source_name
    exit
  }
  $0 ~ ("^fn " function_prefix "[A-Za-z0-9_]*\\(") {
    line = $0
    sub(/^fn /, "", line)
    sub(/\(.*/, "", line)
    print line
    exit
  }
' "$wgsl" | sed -n '1p'
}

normalize_oracle_trace() {
  local inventory="$1"
  local selected_label="$2"
  local output="$3"
  awk -F '\t' -v selected_label="$selected_label" '
  $1 == "function" { active = $2 == selected_label }
  active && $1 == "expression" {
    kind = $4
    sub(/\(.*/, "", kind)
    sub(/ \{.*/, "", kind)
    print "expression\t" $3 "\t" kind
  }
' "$inventory" > "$output"
}

normalize_moon_trace() {
  local trace="$1"
  local output="$2"
  awk -F '\t' '
  $1 == "expression" { print "expression\t" $3 "\t" $4 }
' "$trace" > "$output"
}

normalize_oracle_bindings() {
  local inventory="$1"
  local wgsl="$2"
  local selected_label="$3"
  local function_name="$4"
  local output="$5"
  awk -F '\t' -v selected_label="$selected_label" -v function_name="$function_name" -v wgsl="$wgsl" '
  BEGIN {
    while ((getline line < wgsl) > 0) {
      if (line ~ ("^fn " function_name "\\(")) {
        signature = line
        sub(/^fn [^(]*\(/, "", signature)
        sub(/ *\{.*$/, "", signature)
        sub(/\) *$/, "", signature)
        count = split(signature, params, ",")
        for (i = 1; i <= count; i = i + 1) {
          param = params[i]
          gsub(/^ +| +$/, "", param)
          gsub(/@[A-Za-z_][A-Za-z0-9_]*\([^)]*\) */, "", param)
          sub(/:.*/, "", param)
          gsub(/^ +| +$/, "", param)
          split(param, parts, " ")
          final_arg[i - 1] = parts[length(parts)]
        }
        break
      }
    }
    close(wgsl)
  }
  $1 == "function" { active = $2 == selected_label }
  active && $1 == "named-expression" { final_name[$3] = $4 }
  active && $1 == "expression" && $4 ~ /^FunctionArgument/ {
    arg_index = $4
    sub(/^FunctionArgument\(/, "", arg_index)
    sub(/\).*$/, "", arg_index)
    if (arg_index in final_arg) {
      print "binding\t" $3 "\t" final_arg[arg_index]
    } else if ($3 in final_name) {
      print "binding\t" $3 "\t" final_name[$3]
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
  local wgsl="$1"
  local function_name="$2"
  local output="$3"
  awk -v function_name="$function_name" '
  $0 ~ ("^fn " function_name "\\(") {
    active = 1
    depth = 0
  }
  active {
    for (i = 1; i <= length($0); i = i + 1) {
      ch = substr($0, i, 1)
      if (ch == "{") {
        depth = depth + 1
      } else if (ch == "}") {
        depth = depth - 1
      }
    }
    if ($0 ~ /^[ ]*let _e[0-9]+:/) {
      temp = $0
      sub(/^[ ]*let /, "", temp)
      sub(/:.*/, "", temp)
      expression = temp
      sub(/^_e/, "", expression)
      print "materialized\t" expression "\ttemp=" temp
    }
    if (depth == 0 && $0 ~ /}/) {
      active = 0
    }
  }
' "$wgsl" > "$output"
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

normalize_oracle_helper_temps() {
  local wgsl="$1"
  local function_name="$2"
  local output="$3"
  awk -v function_name="$function_name" '
  $0 ~ ("^fn " function_name "\\(") {
    active = 1
    depth = 0
  }
  active {
    for (i = 1; i <= length($0); i = i + 1) {
      ch = substr($0, i, 1)
      if (ch == "{") {
        depth = depth + 1
      } else if (ch == "}") {
        depth = depth - 1
      }
    }
    if ($0 ~ /^[ ]*let _e[0-9]+:/) {
      temp = $0
      sub(/^[ ]*let /, "", temp)
      sub(/:.*/, "", temp)
      expression = temp
      sub(/^_e/, "", expression)
      print "helper-temp\t" count++ "\texpression=" expression "\ttemp=" temp
    }
    if (depth == 0 && $0 ~ /}/) {
      active = 0
    }
  }
' "$wgsl" > "$output"
}

normalize_moon_helper_temps() {
  local trace="$1"
  local output="$2"
  awk -F '\t' '
  $1 == "expression" && $0 ~ /materialized=true/ {
    temp = field_value($0, "temp")
    print "helper-temp\t" count++ "\texpression=" $3 "\ttemp=" temp
  }
  function field_value(row, key, text) {
    text = row
    sub("^.*\t" key "=", "", text)
    sub(/\t.*$/, "", text)
    return text
  }
' "$trace" > "$output"
}

normalize_oracle_local_declarations() {
  local inventory="$1"
  local selected_label="$2"
  local output="$3"
  awk -F '\t' -v selected_label="$selected_label" '
  $1 == "function" { active = $2 == selected_label }
  active && $1 == "local" {
    print "local-declare\t" count++ "\tlocal=" $3 "\tinit=" local_init($0)
  }
  function local_init(row, init) {
    init = row
    sub(/^.*\tinit=/, "", init)
    if (init == "None") {
      return "-"
    }
    sub(/^Some\(\[/, "", init)
    sub(/\]\).*$/, "", init)
    return init
  }
' "$inventory" > "$output"
}

normalize_moon_local_declarations() {
  local trace="$1"
  local output="$2"
  awk -F '\t' '
  $1 == "local" {
    init[$3] = field_value($0, "init")
    generated[$3] = field_value($0, "generated")
  }
  $1 == "writer-local-declare" {
    local = field_value($0, "local")
    source_local = field_value($0, "source_local")
    if (source_local == $0) {
      source_local = local
    }
    if (source_local in init) {
      print "local-declare\t" count++ "\tlocal=" local "\tinit=" init[source_local]
    }
  }
  function field_value(row, key, text) {
    text = row
    sub("^.*\t" key "=", "", text)
    sub(/\t.*$/, "", text)
    return text
  }
' "$trace" > "$output"
}

normalize_oracle_statements() {
  local inventory="$1"
  local selected_label="$2"
  local output="$3"
  awk -F '\t' -v selected_label="$selected_label" '
  $1 == "function" { active = $2 == selected_label }
  active && $1 == "raw-statement" && $4 != "Emit(empty)" {
    emit_statement($4)
  }
  END { flush_statements() }
  function statement_width(kind) {
    if (kind ~ /^Emit\([0-9]+\.\.[0-9]+\)$/) {
      return emit_end(kind) - emit_start(kind) + 1
    }
    return 1
  }
  function emit_statement(kind, start, end, i) {
    if (kind ~ /^Emit\([0-9]+\.\.[0-9]+\)$/) {
      start = emit_start(kind)
      end = emit_end(kind)
      for (i = start; i <= end; i = i + 1) {
        append_statement("Emit(" i ")")
      }
      return
    }
    append_statement(kind)
  }
  function append_statement(kind) {
    rows[count++] = kind
  }
  function flush_statements(upper, i) {
    upper = count
    if (upper > 0 && rows[upper - 1] == "Return") {
      upper = upper - 1
    }
    for (i = 0; i < upper; i = i + 1) {
      print "statement\t" i "\t" rows[i]
    }
  }
  function emit_start(kind, text) {
    text = kind
    sub(/^Emit\(/, "", text)
    sub(/\.\..*$/, "", text)
    return text + 0
  }
  function emit_end(kind, text) {
    text = kind
    sub(/^Emit\([0-9]+\.\./, "", text)
    sub(/\)$/, "", text)
    return text + 0
  }
' "$inventory" > "$output"
}

normalize_moon_statements() {
  local trace="$1"
  local output="$2"
  awk -F '\t' '
  $1 == "raw-statement" {
    emit_statement($4)
  }
  END { flush_statements() }
  function statement_width(kind) {
    if (kind ~ /^Emit\([0-9]+\.\.[0-9]+\)$/) {
      return emit_end(kind) - emit_start(kind) + 1
    }
    return 1
  }
  function emit_statement(kind, start, end, i) {
    if (kind ~ /^Emit\([0-9]+\.\.[0-9]+\)$/) {
      start = emit_start(kind)
      end = emit_end(kind)
      for (i = start; i <= end; i = i + 1) {
        append_statement("Emit(" i ")")
      }
      return
    }
    append_statement(kind)
  }
  function append_statement(kind) {
    rows[count++] = kind
  }
  function flush_statements(upper, i) {
    upper = count
    if (upper > 0 && rows[upper - 1] == "Return") {
      upper = upper - 1
    }
    for (i = 0; i < upper; i = i + 1) {
      print "statement\t" i "\t" rows[i]
    }
  }
  function emit_start(kind, text) {
    text = kind
    sub(/^Emit\(/, "", text)
    sub(/\.\..*$/, "", text)
    return text + 0
  }
  function emit_end(kind, text) {
    text = kind
    sub(/^Emit\([0-9]+\.\./, "", text)
    sub(/\)$/, "", text)
    return text + 0
  }
' "$trace" > "$output"
}

normalize_module_declaration_slots() {
  local trace="$1"
  local output="$2"
  awk -F '\t' '
  $1 == "slot" && ($2 == "constant" || $2 == "override" || $2 == "global" || $2 == "function" || $2 == "entry_point") {
    root = $0
    sub(/^.*\troot=/, "", root)
    sub(/\t.*$/, "", root)
    if (root != "emit") {
      next
    }
    name = $0
    sub(/^.*\tfinal=/, "", name)
    sub(/\t.*$/, "", name)
    print "slot\t" $2 "\t" name
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
  local statement_drift=0
  local module_drift=0
  local helper_temp_drift=0
  local local_declaration_drift=0

  mkdir -p "$case_dir"
  local compose_root
  compose_root="$(materialize_raw_template_value_defs "$fixture_root" "$entry" "$value_defs" "$case_dir")" || return 1
  moon_args=(
    --fixture-root "$compose_root"
    --entry "$entry"
    --naga-writer-trace-function "$function_prefix"
    --output "$case_dir/moon.trace"
  )
  moon_module_args=(
    --fixture-root "$compose_root"
    --entry "$entry"
    --naga-writer-trace-module
    --output "$case_dir/moon.module"
  )
  oracle_args=(
    --fixture-root "$compose_root"
    --entry "$entry"
    --output "$case_dir/oracle.wgsl"
    --expression-inventory "$case_dir/oracle.inventory"
    --module-inventory "$case_dir/oracle.module"
  )

  append_csv_arg "$bool_defs" --def push_moon_arg
  append_csv_arg "$bool_defs" --def push_moon_module_arg
  append_csv_arg "$bool_defs" --def push_oracle_arg
  append_value_defs "$value_defs" push_moon_arg push_oracle_arg
  append_moon_value_defs "$value_defs" push_moon_module_arg
  append_csv_arg "$additional_imports" --additional-import push_moon_arg
  append_csv_arg "$additional_imports" --additional-import push_moon_module_arg
  append_csv_arg "$additional_imports" --additional-import push_oracle_arg
  append_csv_arg "$capabilities" --capability push_oracle_arg

  if ! moon run tools/compose_case -- "${moon_args[@]}"; then
    echo "failed to collect moon writer trace: $id" >&2
    return 1
  fi
  if ! moon run tools/compose_case -- "${moon_module_args[@]}"; then
    echo "failed to collect moon module trace: $id" >&2
    return 1
  fi
  if ! cargo run --quiet --manifest-path tools/naga_oil_oracle/Cargo.toml --bin naga_oil_oracle -- "${oracle_args[@]}"; then
    echo "failed to collect oracle writer trace: $id" >&2
    return 1
  fi
  for required in "$case_dir/moon.trace" "$case_dir/moon.module" "$case_dir/oracle.wgsl" "$case_dir/oracle.inventory" "$case_dir/oracle.module"; do
    if [[ ! -s "$required" ]]; then
      echo "missing or empty trace artifact for $id: $required" >&2
      return 1
    fi
  done
  local oracle_trace_label
  oracle_trace_label="$(select_oracle_trace_label "$case_dir/oracle.inventory" "$function_prefix")"
  if [[ -z "$oracle_trace_label" ]]; then
    echo "oracle trace function not found for $id: $function_prefix" >&2
    return 1
  fi
  local oracle_function_name
  oracle_function_name="$(select_oracle_text_function_name "$case_dir/oracle.wgsl" "$function_prefix" "$oracle_trace_label")"
  if [[ -z "$oracle_function_name" ]]; then
    echo "oracle writer function not found for $id: $function_prefix" >&2
    return 1
  fi

  normalize_oracle_trace "$case_dir/oracle.inventory" "$oracle_trace_label" "$case_dir/oracle.expression-order"
  normalize_moon_trace "$case_dir/moon.trace" "$case_dir/moon.expression-order"
  normalize_oracle_bindings "$case_dir/oracle.inventory" "$case_dir/oracle.wgsl" "$oracle_trace_label" "$oracle_function_name" "$case_dir/oracle.bindings"
  normalize_moon_bindings "$case_dir/moon.trace" "$case_dir/moon.bindings"
  normalize_oracle_materialized "$case_dir/oracle.wgsl" "$oracle_function_name" "$case_dir/oracle.materialized"
  normalize_moon_materialized "$case_dir/moon.trace" "$case_dir/moon.materialized"
  normalize_oracle_helper_temps "$case_dir/oracle.wgsl" "$oracle_function_name" "$case_dir/oracle.helper-temps"
  normalize_moon_helper_temps "$case_dir/moon.trace" "$case_dir/moon.helper-temps"
  normalize_oracle_local_declarations "$case_dir/oracle.inventory" "$oracle_trace_label" "$case_dir/oracle.local-declarations"
  normalize_moon_local_declarations "$case_dir/moon.trace" "$case_dir/moon.local-declarations"
  normalize_oracle_statements "$case_dir/oracle.inventory" "$oracle_trace_label" "$case_dir/oracle.statements"
  normalize_moon_statements "$case_dir/moon.trace" "$case_dir/moon.statements"
  normalize_module_declaration_slots "$case_dir/oracle.module" "$case_dir/oracle.module-slots"
  normalize_module_declaration_slots "$case_dir/moon.module" "$case_dir/moon.module-slots"

  diff -u "$case_dir/oracle.expression-order" "$case_dir/moon.expression-order" > "$case_dir/expression-order.diff" || expression_drift=1
  diff -u "$case_dir/oracle.bindings" "$case_dir/moon.bindings" > "$case_dir/bindings.diff" || binding_drift=1
  diff -u "$case_dir/oracle.materialized" "$case_dir/moon.materialized" > "$case_dir/materialized.diff" || materialized_drift=1
  diff -u "$case_dir/oracle.helper-temps" "$case_dir/moon.helper-temps" > "$case_dir/helper-temps.diff" || helper_temp_drift=1
  diff -u "$case_dir/oracle.local-declarations" "$case_dir/moon.local-declarations" > "$case_dir/local-declarations.diff" || local_declaration_drift=1
  diff -u "$case_dir/oracle.statements" "$case_dir/moon.statements" > "$case_dir/statements.diff" || statement_drift=1
  diff -u "$case_dir/oracle.module-slots" "$case_dir/moon.module-slots" > "$case_dir/module-slots.diff" || module_drift=1

  if [[ "$expression_drift" == 0 && "$binding_drift" == 0 && "$materialized_drift" == 0 && "$helper_temp_drift" == 0 && "$local_declaration_drift" == 0 && "$statement_drift" == 0 && "$module_drift" == 0 ]]; then
    echo "naga writer representative trace parity passed: $id: $entry :: $function_prefix"
    return 0
  fi

  echo "naga writer representative trace drift: $id: $entry :: $function_prefix" >&2
  echo "artifacts: $case_dir" >&2
  [[ "$expression_drift" == 0 ]] || sed -n '1,120p' "$case_dir/expression-order.diff" >&2
  [[ "$binding_drift" == 0 ]] || sed -n '1,120p' "$case_dir/bindings.diff" >&2
  [[ "$materialized_drift" == 0 ]] || sed -n '1,120p' "$case_dir/materialized.diff" >&2
  [[ "$helper_temp_drift" == 0 ]] || sed -n '1,120p' "$case_dir/helper-temps.diff" >&2
  [[ "$local_declaration_drift" == 0 ]] || sed -n '1,120p' "$case_dir/local-declarations.diff" >&2
  [[ "$statement_drift" == 0 ]] || sed -n '1,120p' "$case_dir/statements.diff" >&2
  [[ "$module_drift" == 0 ]] || sed -n '1,120p' "$case_dir/module-slots.diff" >&2
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
