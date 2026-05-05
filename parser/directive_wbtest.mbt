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
test "WGSL directive parser exposes effective naga-oil directive semantics" {
  guard parse_wgsl_directive_line("#elsewhere FLAG") is Some(else_directive) else {
    abort("expected else directive")
  }
  debug_inspect(wgsl_effective_directive_kind(else_directive), content="Else")
  debug_inspect(
    wgsl_effective_directive_tail(else_directive),
    content="\"where FLAG\"",
  )
  debug_inspect(
    wgsl_directive_line_required_tail_space("#elsewhere FLAG", "elsewhere"),
    content="true",
  )
  guard parse_wgsl_directive_line("#endif_trailing") is Some(endif_directive) else {
    abort("expected endif directive")
  }
  debug_inspect(wgsl_effective_directive_kind(endif_directive), content="Endif")
  debug_inspect(
    wgsl_effective_directive_tail(endif_directive),
    content="\"_trailing\"",
  )
}

///|
test "WGSL directive parser accepts Rust regex Unicode whitespace" {
  guard parse_wgsl_directive_line(
      "\u{00A0}#\u{00A0}define_import_path\u{3000}demo::module\u{2003}",
    )
    is Some(directive) else {
    abort("expected directive")
  }
  debug_inspect(directive.kind, content="DefineImportPath")
  debug_inspect(directive.tail, content="\"demo::module\"")
}

///|
test "WGSL shader-def reference parser preserves replacement spans" {
  let references = parse_wgsl_shader_def_references(
    "#FOO + #\tBAR + #{BAZ_2} + #{ BAD } + #+",
  )
  debug_inspect(references.length(), content="3")
  debug_inspect(references[0].name(), content="\"FOO\"")
  debug_inspect(references[0].start(), content="0")
  debug_inspect(references[0].end(), content="4")
  debug_inspect(references[0].is_delimited(), content="false")
  debug_inspect(references[1].name(), content="\"BAR\"")
  debug_inspect(references[1].start(), content="7")
  debug_inspect(references[1].end(), content="12")
  debug_inspect(references[1].is_delimited(), content="false")
  debug_inspect(references[2].name(), content="\"BAZ_2\"")
  debug_inspect(references[2].start(), content="15")
  debug_inspect(references[2].end(), content="23")
  debug_inspect(references[2].is_delimited(), content="true")
}

///|
test "WGSL shader-def reference parser accepts delimited names without trimming" {
  let references = parse_wgsl_shader_def_references("#{VALUE_1} #{ VALUE_2 }")
  debug_inspect(references.length(), content="1")
  debug_inspect(references[0].name(), content="\"VALUE_1\"")
  debug_inspect(references[0].start(), content="0")
  debug_inspect(references[0].end(), content="10")
  debug_inspect(references[0].is_delimited(), content="true")
}

///|
test "WGSL preprocessor directive syntax parser extracts names and comparisons" {
  debug_inspect(
    parse_wgsl_directive_identifier(" FLAG; trailing"),
    content="Some(\"FLAG\")",
  )
  debug_inspect(
    wgsl_required_space_word_tail(" ifdef   FLAG", "ifdef"),
    content="Some(\"FLAG\")",
  )
  debug_inspect(
    wgsl_text_starts_with_tokenized_space(" if FLAG"),
    content="true",
  )
  guard parse_wgsl_shader_def_comparison("VALUE >= -7u; ignored")
    is Some(comparison) else {
    abort("expected comparison")
  }
  debug_inspect(comparison.def_name(), content="\"VALUE\"")
  debug_inspect(comparison.operator(), content="\">=\"")
  debug_inspect(comparison.value_text(), content="\"-7u\"")
  debug_inspect(
    parse_glsl_version_directive(" #version 450 core"),
    content="Some(\"450\")",
  )
  debug_inspect(parse_glsl_version_directive("#version450"), content="None")
}

///|
test "WGSL template const reference parser preserves naga-oil boundaries" {
  let value_defines : @hashmap.HashMap[String, Int] = @hashmap.HashMap::new()
  value_defines.set("VALUE", 1)
  value_defines.set("VALUE_LONG", 2)
  let references = parse_wgsl_template_const_references(
    "#VALUE #VALUE_LONG #VALUE_IGNORED #{VALUE} #{ VALUE }", value_defines,
  )
  debug_inspect(references.length(), content="3")
  debug_inspect(references[0].name, content="\"VALUE\"")
  debug_inspect(references[0].start, content="0")
  debug_inspect(references[0].end, content="6")
  debug_inspect(references[1].name, content="\"VALUE_LONG\"")
  debug_inspect(references[1].start, content="7")
  debug_inspect(references[1].end, content="18")
  debug_inspect(references[2].name, content="\"VALUE\"")
  debug_inspect(references[2].start, content="34")
  debug_inspect(references[2].end, content="42")
}
