///|
fn import_targets_error(input : String) -> String {
  let targets : Array[WgslImportTarget] = []
  parse_wgsl_import_targets(input, "", targets) catch {
    Parse(message, offset) => return "ERR \{offset.to_string()} \{message}"
  }
  "OK"
}

///|
test "naga_oil wb: import target parser treats regex whitespace as empty" {
  debug_inspect(
    import_targets_error("\u{00A0}"),
    content="\"ERR 2 expected import path\"",
  )
}

///|
test "naga_oil wb: import target parser rejects tokens after semicolon" {
  debug_inspect(
    import_targets_error("a; b"),
    content="\"ERR 3 unexpected token after ';'\"",
  )
  debug_inspect(
    import_targets_error("a;;"),
    content="\"ERR 2 unexpected token after ';'\"",
  )
}

///|
test "naga_oil wb: import target parser handles non-BMP other token widths" {
  debug_inspect(
    import_targets_error("💡"),
    content="\"ERR 0 unexpected token\"",
  )
  debug_inspect(
    import_targets_error("a; 💡"),
    content="\"ERR 3 unexpected token after ';'\"",
  )
}

///|
test "WGSL import parser classifies empty import specs" {
  debug_inspect(
    parse_wgsl_import_spec_is_empty_or_final_semicolon(""),
    content="true",
  )
  debug_inspect(
    parse_wgsl_import_spec_is_empty_or_final_semicolon(" ; "),
    content="true",
  )
  debug_inspect(
    parse_wgsl_import_spec_is_empty_or_final_semicolon("a::b"),
    content="false",
  )
}

///|
test "WGSL import parser builds alias prefixes" {
  debug_inspect(
    parse_wgsl_import_alias_prefix("demo::math"),
    content="\"demo_math\"",
  )
  debug_inspect(
    parse_wgsl_import_alias_prefix("\"quoted path\""),
    content="\"import\"",
  )
  debug_inspect(
    parse_wgsl_import_alias_prefix("bad-name::Item"),
    content="\"bad_name_Item\"",
  )
}
