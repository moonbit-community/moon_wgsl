///|
test "WGSL source directive item parser classifies directive section input" {
  let items = parse_wgsl_source_directive_items(
    (
      #|// keep
      #|  enable f16, subgroups; trailing
      #|  diagnostic(warn, derivative_uniformity);
      #|enable_extra();
      #|fn shade() {}
      #|
    ),
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
    (
      #|enable ;
      #|enable  ;
      #|diagnostic( , derivative_uniformity);
      #|diagnostic(off, );
      #|
    ),
  )
  debug_inspect(items[0].kind, content="PrefixCandidate")
  debug_inspect(items[1].kind, content="Enable(\"\")")
  debug_inspect(
    items[2].kind,
    content="Diagnostic(\"\", \"derivative_uniformity\")",
  )
  debug_inspect(items[3].kind, content="Diagnostic(\"off\", \"\")")
}
