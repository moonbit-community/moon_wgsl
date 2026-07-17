///|
fn wbtest_add_symbol_reference_binding(
  plan : WgslReferenceRewritePlan,
  identity : WgslComposeSymbolIdentity,
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
    WgslComposeSymbolIdentity("local.wgsl", "build_shadow"),
    "build_shadow",
    "build_color",
  )
  let rewritten = rewrite_wgsl_references_with_binding_plan(
    (
      #|fn shade() -> f32 {
      #|  return build_shadow();
      #|}
      #|fn build_shadow() -> f32 {
      #|  return 1.0;
      #|}
      #|
    ),
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
    WgslComposeSymbolIdentity("local.wgsl", "build_shadow"),
    "build_shadow",
    "build_color",
  )
  let rewritten = rewrite_wgsl_references_with_binding_plan(
    (
      #|fn shade(arg: u32) -> u32 {
      #|  if (arg > 0u) {
      #|    let build_shadow = arg;
      #|    return build_shadow;
      #|  }
      #|  for (var i: u32 = 0u; i < arg; i = i + 1u) {
      #|    continue;
      #|  }
      #|  return arg;
      #|}
      #|fn build_shadow() -> u32 {
      #|  return 1u;
      #|}
      #|
    ),
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
    WgslComposeSymbolIdentity("lighting.wgsl", "build_shadow"),
    "lighting::build_shadow",
    "lighting__build_shadow",
  )
  let rewritten = rewrite_wgsl_references_with_binding_plan(
    (
      #|fn shade() -> f32 {
      #|  return lighting::build_shadow();
      #|}
      #|
    ),
    plan,
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
    WgslComposeSymbolIdentity("overridable.wgsl", "func"),
    "func",
    "funcX",
  )
  let rewritten = rewrite_wgsl_references_with_binding_plan(
    (
      #|fn shade() -> f32 {
      #|  return overridable::func();
      #|}
      #|
    ),
    plan,
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
    WgslComposeSymbolIdentity("a.wgsl", "Shared"),
    "Shared",
    "a__Shared",
  )
  wbtest_add_symbol_reference_binding(
    plan,
    WgslComposeSymbolIdentity("b.wgsl", "Shared"),
    "Shared",
    "b__Shared",
  )
  let rewritten = rewrite_wgsl_references_with_binding_plan(
    (
      #|fn shade(value: Shared) -> Shared {
      #|  return value;
      #|}
      #|
    ),
    plan,
  )
  debug_inspect(rewritten.contains("Shared"), content="true")
  debug_inspect(rewritten.contains("a__Shared"), content="false")
  debug_inspect(rewritten.contains("b__Shared"), content="false")
}

///|
test "naga_oil wb: bound rewrite keeps qualified identity when unqualified spelling is ambiguous" {
  let plan = WgslReferenceRewritePlan()
  wbtest_add_symbol_reference_binding(
    plan,
    WgslComposeSymbolIdentity("a.wgsl", "Shared"),
    "Shared",
    "a__Shared",
  )
  wbtest_add_symbol_reference_binding(
    plan,
    WgslComposeSymbolIdentity("b.wgsl", "Shared"),
    "Shared",
    "b__Shared",
  )
  wbtest_add_symbol_reference_binding(
    plan,
    WgslComposeSymbolIdentity("lib.wgsl", "Shared"),
    "lib::Shared",
    "lib__Shared",
  )
  let rewritten = rewrite_wgsl_references_with_binding_plan(
    (
      #|fn shade(value: Shared) -> f32 {
      #|  return lib::Shared(value);
      #|}
      #|
    ),
    plan,
  )
  debug_inspect(rewritten.contains("value: Shared"), content="true")
  debug_inspect(rewritten.contains("a__Shared"), content="false")
  debug_inspect(rewritten.contains("value: b__Shared"), content="false")
  debug_inspect(rewritten.contains("return b__Shared"), content="false")
  debug_inspect(
    rewritten.contains("return lib__Shared(value);"),
    content="true",
  )
  debug_inspect(rewritten.contains("lib::Shared"), content="false")
}

///|
test "naga_oil wb: bound rewrite keeps same identity reference paths independent" {
  let plan = WgslReferenceRewritePlan()
  let identity = WgslComposeSymbolIdentity("shared.wgsl", "value")
  wbtest_add_symbol_reference_binding(plan, identity, "value", "direct_value")
  wbtest_add_symbol_reference_binding(
    plan, identity, "alias::value", "alias__value",
  )
  let rewritten = rewrite_wgsl_references_with_binding_plan(
    (
      #|fn root() -> u32 {
      #|  return value() + alias::value();
      #|}
      #|
    ),
    plan,
  )
  debug_inspect(
    rewritten.contains("return direct_value() + alias__value();"),
    content="true",
  )
  debug_inspect(rewritten.contains("alias::value"), content="false")
}

///|
test "naga_oil wb: declaration rewrite preserves logical-not punctuation" {
  let plan = WgslReferenceRewritePlan()
  wbtest_add_symbol_reference_binding(
    plan,
    WgslComposeSymbolIdentity("lib.wgsl", "pred"),
    "pred",
    "predX",
  )
  let rewritten = rewrite_wgsl_declarations_with_binding_plan(
    (
      #|fn value() -> f32 {
      #|  return f32(!pred());
      #|}
      #|
    ),
    plan,
  )
  debug_inspect(rewritten.contains("return f32(!predX());"), content="true")
  debug_inspect(rewritten.contains("return f32(predX());"), content="false")
}
