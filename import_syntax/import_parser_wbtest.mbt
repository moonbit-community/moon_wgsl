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
test "WGSL import parser expands grouped item imports" {
  let targets : Array[WgslImportTarget] = []
  parse_wgsl_import_targets(
    "bevy_render::maths::{PI_2,PI,FRAC_PI_3}", "", targets,
  ) catch {
    Parse(message, _) => abort(message)
  }
  let rendered : Array[String] = []
  for target in targets {
    rendered.push("\{target.raw_path} as \{target.alias_name}")
  }
  debug_inspect(
    rendered.join("|"),
    content="\"bevy_render::maths::PI_2 as |bevy_render::maths::PI as |bevy_render::maths::FRAC_PI_3 as \"",
  )
}

///|
