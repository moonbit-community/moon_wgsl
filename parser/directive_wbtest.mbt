///|
test "WGSL directive parser classifies known directives" {
  let parsed = parse_wgsl_directive_line("  #define_import_path bevy::pbr  ")
  guard parsed is Some(directive) else { abort("expected directive") }
  debug_inspect(directive.kind, content="DefineImportPath")
  debug_inspect(directive.name, content="\"define_import_path\"")
  debug_inspect(directive.tail, content="\"bevy::pbr\"")
  debug_inspect(directive.start, content="2")
  debug_inspect(directive.end, content="31")
  debug_inspect(directive.name_start, content="3")
  debug_inspect(directive.name_end, content="21")
  debug_inspect(directive.tail_start, content="22")
  debug_inspect(directive.tail_end, content="31")
}

///|
test "WGSL directive parser keeps unknown directives structured" {
  let parsed = parse_wgsl_directive_line("#custom thing")
  guard parsed is Some(directive) else { abort("expected directive") }
  debug_inspect(directive.kind, content="Other(\"custom\")")
  debug_inspect(directive.tail, content="\"thing\"")
  debug_inspect(directive.start, content="0")
  debug_inspect(directive.end, content="13")
  debug_inspect(directive.name_start, content="1")
  debug_inspect(directive.name_end, content="7")
  debug_inspect(directive.tail_start, content="8")
  debug_inspect(directive.tail_end, content="13")
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

///|
test "WGSL directive parser accepts Rust regex Unicode whitespace" {
  debug_inspect(
    wgsl_directive_tail(
      "\u{00A0}#\u{00A0}define_import_path\u{3000}demo::module\u{2003}",
      WgslDirectiveKind::DefineImportPath,
    ),
    content="Some(\"demo::module\")",
  )
}

///|
test "WGSL source directive item parser classifies directive section input" {
  let items = parse_wgsl_source_directive_items(
    "// keep\n  enable f16, subgroups; trailing\n  diagnostic(warn, derivative_uniformity);\nenable_extra();\nfn shade() {}\n",
  )
  debug_inspect(items.length(), content="5")
  debug_inspect(items[0].kind, content="Trivia")
  debug_inspect(items[1].kind, content="Enable(\"f16, subgroups\")")
  debug_inspect(
    items[2].kind,
    content="Diagnostic(\"warn\", \"derivative_uniformity\")",
  )
  debug_inspect(items[3].kind, content="PrefixCandidate")
  debug_inspect(items[4].kind, content="Source")
}

///|
test "WGSL source directive item parser preserves naga-oil empty body distinction" {
  let items = parse_wgsl_source_directive_items(
    "enable ;\nenable  ;\ndiagnostic( , derivative_uniformity);\ndiagnostic(off, );\n",
  )
  debug_inspect(items[0].kind, content="PrefixCandidate")
  debug_inspect(items[1].kind, content="Enable(\"\")")
  debug_inspect(
    items[2].kind,
    content="Diagnostic(\"\", \"derivative_uniformity\")",
  )
  debug_inspect(items[3].kind, content="Diagnostic(\"off\", \"\")")
}

///|
test "WGSL shader-def reference parser preserves replacement spans" {
  let references = parse_wgsl_shader_def_references(
    "#FOO + #\tBAR + #{BAZ_2} + #{ BAD } + #+",
  )
  debug_inspect(references.length(), content="3")
  debug_inspect(references[0].name, content="\"FOO\"")
  debug_inspect(references[0].start, content="0")
  debug_inspect(references[0].end, content="4")
  debug_inspect(references[0].delimited, content="false")
  debug_inspect(references[1].name, content="\"BAR\"")
  debug_inspect(references[1].start, content="7")
  debug_inspect(references[1].end, content="12")
  debug_inspect(references[1].delimited, content="false")
  debug_inspect(references[2].name, content="\"BAZ_2\"")
  debug_inspect(references[2].start, content="15")
  debug_inspect(references[2].end, content="23")
  debug_inspect(references[2].delimited, content="true")
}

///|
test "WGSL shader-def reference parser accepts delimited names without trimming" {
  let references = parse_wgsl_shader_def_references("#{VALUE_1} #{ VALUE_2 }")
  debug_inspect(references.length(), content="1")
  debug_inspect(references[0].name, content="\"VALUE_1\"")
  debug_inspect(references[0].start, content="0")
  debug_inspect(references[0].end, content="10")
  debug_inspect(references[0].delimited, content="true")
}
