///|
fn directive_from_source(source : String) -> @ast.WgslDirective {
  let items = parse_wgsl_directive_scan_items(source)
  guard items.length() == 1 else { abort("expected one directive item") }
  match items[0].kind() {
    Directive(directive) => directive
    _ => abort("expected directive")
  }
}

///|
test "WGSL directive semantics exposes effective naga-oil directives" {
  let else_directive = directive_from_source("#elsewhere FLAG")
  debug_inspect(wgsl_effective_directive_kind(else_directive), content="Else")
  debug_inspect(
    wgsl_effective_directive_tail(else_directive),
    content="\"where FLAG\"",
  )
  debug_inspect(else_directive.has_tail(), content="true")
  let endif_directive = directive_from_source("#endif_trailing")
  debug_inspect(wgsl_effective_directive_kind(endif_directive), content="Endif")
  debug_inspect(
    wgsl_effective_directive_tail(endif_directive),
    content="\"_trailing\"",
  )
}

///|
test "WGSL preprocessor directive syntax extracts names and comparisons" {
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
  debug_inspect(comparison.operator(), content="GreaterEqual")
  debug_inspect(comparison.value_text(), content="\"-7u\"")
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
test "WGSL template const reference parser preserves naga-oil boundaries" {
  let value_defines : @hashmap.HashMap[String, @common.ShaderDefValue] = @hashmap.HashMap([],
  )
  value_defines.set("VALUE", @common.ShaderDefValue::Int(1))
  value_defines.set("VALUE_LONG", @common.ShaderDefValue::Int(2))
  let references = parse_wgsl_template_const_references(
    "#VALUE #VALUE_LONG #VALUE_IGNORED #{VALUE} #{ VALUE }", value_defines,
  )
  debug_inspect(references.length(), content="3")
  debug_inspect(references[0].name(), content="\"VALUE\"")
  debug_inspect(references[0].start(), content="0")
  debug_inspect(references[0].end(), content="6")
  debug_inspect(references[1].name(), content="\"VALUE_LONG\"")
  debug_inspect(references[1].start(), content="7")
  debug_inspect(references[1].end(), content="18")
  debug_inspect(references[2].name(), content="\"VALUE\"")
  debug_inspect(references[2].start(), content="34")
  debug_inspect(references[2].end(), content="42")
}
