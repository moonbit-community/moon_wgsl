///|
test "naga_oil wb: AST-scoped symbol redirects rewrite references but keep declarations" {
  let rewritten = rewrite_wgsl_declarations_with_rename_plan(
    "fn shade() -> f32 {\n  return build_shadow();\n}\nfn build_shadow() -> f32 {\n  return 1.0;\n}\n",
    build_wgsl_rename_plan_from_redirect_map(
      build_wgsl_symbol_redirect_map([
        { from_name: "build_shadow", to_name: "build_color" },
      ]),
      ReferencesOnly,
    ),
  )
  debug_inspect(rewritten.contains("return build_color();"), content="true")
  debug_inspect(rewritten.contains("return build_shadow();"), content="false")
  debug_inspect(rewritten.contains("fn build_shadow()"), content="true")
}

///|
test "naga_oil wb: AST-scoped symbol redirects ignore nested local shadows" {
  let rewritten = rewrite_wgsl_declarations_with_rename_plan(
    "fn shade(arg: u32) -> u32 {\n  if (arg > 0u) {\n    let build_shadow = arg;\n    return build_shadow;\n  }\n  for (var i: u32 = 0u; i < arg; i = i + 1u) {\n    continue;\n  }\n  return arg;\n}\nfn build_shadow() -> u32 {\n  return 1u;\n}\n",
    build_wgsl_rename_plan_from_redirect_map(
      build_wgsl_symbol_redirect_map([
        { from_name: "build_shadow", to_name: "build_color" },
      ]),
      ReferencesOnly,
    ),
  )
  debug_inspect(rewritten.contains("let build_shadow = arg;"), content="true")
  debug_inspect(rewritten.contains("return build_shadow;"), content="true")
  debug_inspect(rewritten.contains("fn build_shadow()"), content="true")
  debug_inspect(rewritten.contains("let build_color = arg;"), content="false")
}

///|
test "naga_oil wb: reference rewrite plan carries symbol identity" {
  let plan = WgslReferenceRewritePlan::new()
  plan.add_symbol_binding(
    "lighting.wgsl", "build_shadow", "lighting::build_shadow", "lighting__build_shadow",
  )
  let rewritten = rewrite_wgsl_references_with_binding_plan(
    "fn shade() -> f32 {\n  return lighting::build_shadow();\n}\n", plan,
  )
  debug_inspect(
    rewritten.contains("return lighting__build_shadow();"),
    content="true",
  )
  debug_inspect(rewritten.contains("lighting::build_shadow"), content="false")
}

///|
test "naga_oil wb: identity rewrite plan does not collapse ambiguous bindings" {
  let plan = WgslReferenceRewritePlan::new()
  plan.add_symbol_binding("a.wgsl", "Shared", "Shared", "a__Shared")
  plan.add_symbol_binding("b.wgsl", "Shared", "Shared", "b__Shared")
  let rewritten = rewrite_wgsl_references_with_binding_plan(
    "fn shade(value: Shared) -> Shared {\n  return value;\n}\n", plan,
  )
  debug_inspect(rewritten.contains("Shared"), content="true")
  debug_inspect(rewritten.contains("a__Shared"), content="false")
  debug_inspect(rewritten.contains("b__Shared"), content="false")
}
