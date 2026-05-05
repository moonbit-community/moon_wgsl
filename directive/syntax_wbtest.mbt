///|
fn directive_from_source(source : String) -> @ast.WgslDirective {
  let items = @parser.parse_wgsl_directive_scan_items(source)
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
