///|
test "WGSL directive parser classifies known directives" {
  let parsed = parse_wgsl_directive_line("  #define_import_path bevy::pbr  ")
  guard parsed is Some(directive) else { abort("expected directive") }
  debug_inspect(directive.kind, content="DefineImportPath")
  debug_inspect(directive.name, content="\"define_import_path\"")
  debug_inspect(directive.tail, content="\"bevy::pbr\"")
}

///|
test "WGSL directive parser keeps unknown directives structured" {
  let parsed = parse_wgsl_directive_line("#custom thing")
  guard parsed is Some(directive) else { abort("expected directive") }
  debug_inspect(directive.kind, content="Other(\"custom\")")
  debug_inspect(directive.tail, content="\"thing\"")
  debug_inspect(
    hash_directive_tail("#custom thing", "custom"),
    content="Some(\"thing\")",
  )
  debug_inspect(hash_directive_tail("#custom thing", "import"), content="None")
}
