///|
test "WGSL GLSL version directive parser extracts versions" {
  debug_inspect(
    parse_glsl_version_directive(" #version 450 core"),
    content="Some(\"450\")",
  )
  debug_inspect(parse_glsl_version_directive("#version450"), content="None")
}

///|
test "WGSL directive parser classifies known directives" {
  let parsed = parse_wgsl_directive_line("  #define_import_path bevy::pbr  ")
  guard parsed is Some(directive) else { abort("expected directive") }
  debug_inspect(directive.kind(), content="DefineImportPath")
  debug_inspect(directive.name().name(), content="\"define_import_path\"")
  debug_inspect(directive.tail(), content="\"bevy::pbr\"")
  debug_inspect(directive.start(), content="2")
  debug_inspect(directive.end(), content="31")
  debug_inspect(directive.name().start(), content="3")
  debug_inspect(directive.name().end(), content="21")
  debug_inspect(directive.tail_start(), content="22")
  debug_inspect(directive.tail_end(), content="31")
}

///|
test "WGSL directive parser keeps unknown directives structured" {
  let parsed = parse_wgsl_directive_line("#custom thing")
  guard parsed is Some(directive) else { abort("expected directive") }
  debug_inspect(directive.kind(), content="Other")
  debug_inspect(directive.tail(), content="\"thing\"")
  debug_inspect(directive.start(), content="0")
  debug_inspect(directive.end(), content="13")
  debug_inspect(directive.name().start(), content="1")
  debug_inspect(directive.name().end(), content="7")
  debug_inspect(directive.tail_start(), content="8")
  debug_inspect(directive.tail_end(), content="13")
}

///|
test "WGSL directive parser accepts Rust regex Unicode whitespace" {
  guard parse_wgsl_directive_line(
      "\u{00A0}#\u{00A0}define_import_path\u{3000}demo::module\u{2003}",
    )
    is Some(directive) else {
    abort("expected directive")
  }
  debug_inspect(directive.kind(), content="DefineImportPath")
  debug_inspect(directive.tail(), content="\"demo::module\"")
}
