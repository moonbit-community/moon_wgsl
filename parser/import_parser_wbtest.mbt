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
