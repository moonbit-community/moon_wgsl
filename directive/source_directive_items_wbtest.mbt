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
