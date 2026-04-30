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
}

///|
test "WGSL directive parser exposes kind-based tails" {
  debug_inspect(
    wgsl_directive_tail("#import bevy::view", WgslDirectiveKind::Import),
    content="Some(\"bevy::view\")",
  )
  debug_inspect(
    wgsl_directive_tail("#import bevy::view", WgslDirectiveKind::Define),
    content="None",
  )
}

///|
test "WGSL directive parser supports naga-oil prefix else endif semantics" {
  debug_inspect(
    wgsl_directive_prefix_tail("#elsewhere", WgslDirectiveKind::Else),
    content="Some(\"where\")",
  )
  debug_inspect(
    wgsl_directive_prefix_tail("#endif_trailing", WgslDirectiveKind::Endif),
    content="Some(\"_trailing\")",
  )
}
