///|
fn wbtest_add_symbol_reference_binding(
  plan : WgslReferenceRewritePlan,
  identity : WgslIrSymbolIdentity,
  reference_name : String,
  final_name : String,
) -> Unit {
  match WgslReferencePath::from_text(reference_name) {
    Some(reference_path) =>
      plan.add_symbol_reference_binding(identity, reference_path, final_name)
    None => abort("expected valid reference path")
  }
}

///|
test "naga_oil wb: AST-scoped symbol redirects rewrite references but keep declarations" {
  let plan = WgslReferenceRewritePlan()
  wbtest_add_symbol_reference_binding(
    plan,
    WgslIrSymbolIdentity("local.wgsl", "build_shadow"),
    "build_shadow",
    "build_color",
  )
  let rewritten = rewrite_wgsl_references_with_binding_plan(
    "fn shade() -> f32 {\n  return build_shadow();\n}\nfn build_shadow() -> f32 {\n  return 1.0;\n}\n",
    plan,
  )
  debug_inspect(rewritten.contains("return build_color();"), content="true")
  debug_inspect(rewritten.contains("return build_shadow();"), content="false")
  debug_inspect(rewritten.contains("fn build_shadow()"), content="true")
}

///|
test "naga_oil wb: AST-scoped symbol redirects ignore nested local shadows" {
  let plan = WgslReferenceRewritePlan()
  wbtest_add_symbol_reference_binding(
    plan,
    WgslIrSymbolIdentity("local.wgsl", "build_shadow"),
    "build_shadow",
    "build_color",
  )
  let rewritten = rewrite_wgsl_references_with_binding_plan(
    "fn shade(arg: u32) -> u32 {\n  if (arg > 0u) {\n    let build_shadow = arg;\n    return build_shadow;\n  }\n  for (var i: u32 = 0u; i < arg; i = i + 1u) {\n    continue;\n  }\n  return arg;\n}\nfn build_shadow() -> u32 {\n  return 1u;\n}\n",
    plan,
  )
  debug_inspect(rewritten.contains("let build_shadow = arg;"), content="true")
  debug_inspect(rewritten.contains("return build_shadow;"), content="true")
  debug_inspect(rewritten.contains("fn build_shadow()"), content="true")
  debug_inspect(rewritten.contains("let build_color = arg;"), content="false")
}

///|
test "naga_oil wb: reference rewrite plan carries symbol identity" {
  let plan = WgslReferenceRewritePlan()
  wbtest_add_symbol_reference_binding(
    plan,
    WgslIrSymbolIdentity("lighting.wgsl", "build_shadow"),
    "lighting::build_shadow",
    "lighting__build_shadow",
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
test "naga_oil wb: unqualified bindings do not rewrite qualified references" {
  let plan = WgslReferenceRewritePlan()
  wbtest_add_symbol_reference_binding(
    plan,
    WgslIrSymbolIdentity("overridable.wgsl", "func"),
    "func",
    "funcX",
  )
  let rewritten = rewrite_wgsl_references_with_binding_plan(
    "fn shade() -> f32 {\n  return overridable::func();\n}\n", plan,
  )
  debug_inspect(
    rewritten.contains("return overridable::func();"),
    content="true",
  )
  debug_inspect(rewritten.contains("overridable::funcX"), content="false")
}

///|
test "naga_oil wb: identity rewrite plan does not collapse ambiguous bindings" {
  let plan = WgslReferenceRewritePlan()
  wbtest_add_symbol_reference_binding(
    plan,
    WgslIrSymbolIdentity("a.wgsl", "Shared"),
    "Shared",
    "a__Shared",
  )
  wbtest_add_symbol_reference_binding(
    plan,
    WgslIrSymbolIdentity("b.wgsl", "Shared"),
    "Shared",
    "b__Shared",
  )
  let rewritten = rewrite_wgsl_references_with_binding_plan(
    "fn shade(value: Shared) -> Shared {\n  return value;\n}\n", plan,
  )
  debug_inspect(rewritten.contains("Shared"), content="true")
  debug_inspect(rewritten.contains("a__Shared"), content="false")
  debug_inspect(rewritten.contains("b__Shared"), content="false")
}

///|
test "naga_oil wb: declaration rewrite preserves logical-not punctuation" {
  let plan = WgslReferenceRewritePlan()
  wbtest_add_symbol_reference_binding(
    plan,
    WgslIrSymbolIdentity("lib.wgsl", "pred"),
    "pred",
    "predX",
  )
  let rewritten = rewrite_wgsl_declarations_with_binding_plan(
    "fn value() -> f32 {\n  return f32(!pred());\n}\n", plan,
  )
  debug_inspect(rewritten.contains("return f32(!predX());"), content="true")
  debug_inspect(rewritten.contains("return f32(predX());"), content="false")
}
