///|
test "virtual override base detection does not collapse namespace suffixes" {
  let source =
    #|virtual fn func() -> f32 {
    #|  return 1.0;
    #|}
    #|override fn func() -> f32 {
    #|  return other::func();
    #|}
    #|
  let plan = WgslReferenceRewritePlan()
  let output = apply_wgsl_virtual_overrides_with_binding_plan(source, plan)
  debug_inspect(output.contains("__virtual_base"), content="false")
  debug_inspect(output.contains("return other::func();"), content="true")
}

///|
test "virtual override base rewrite uses AST scope for local shadows" {
  let source =
    #|virtual fn mod__inner() -> f32 {
    #|  return 1.0;
    #|}
    #|override fn mod::inner() -> f32 {
    #|  let value = mod::inner();
    #|  let mod__inner = 2.0;
    #|  return value + mod__inner;
    #|}
    #|
  let plan = WgslReferenceRewritePlan()
  match WgslReferencePath::from_text("mod::inner") {
    Some(reference_path) =>
      plan.add_symbol_reference_binding(
        WgslComposeSymbolIdentity("mod.wgsl", "inner"),
        reference_path,
        "mod__inner",
      )
    None => abort("expected valid reference path")
  }
  let output = apply_wgsl_virtual_overrides_with_binding_plan(source, plan)
  debug_inspect(
    output.contains("fn mod__inner__virtual_base() -> f32"),
    content="true",
  )
  debug_inspect(
    output.contains("let value = mod__inner__virtual_base();"),
    content="true",
  )
  debug_inspect(output.contains("let mod__inner = 2.0;"), content="true")
  debug_inspect(output.contains("return value + mod__inner;"), content="true")
}

///|
test "virtual override dispatch rewrites qualified imported targets structurally" {
  let source =
    #|virtual fn funcX() -> f32 {
    #|  return 1.0;
    #|}
    #|override fn overridable::func() -> f32 {
    #|  return overridable::func() + 1.0;
    #|}
    #|fn entry_point() -> f32 {
    #|  return overridable::func();
    #|}
    #|
  let plan = WgslReferenceRewritePlan()
  match WgslReferencePath::from_text("overridable::func") {
    Some(reference_path) =>
      plan.add_symbol_reference_binding(
        WgslComposeSymbolIdentity("overridable.wgsl", "func"),
        reference_path,
        "funcX",
      )
    None => abort("expected valid reference path")
  }
  plan.add_virtual_override_binding("overridable::func", "funcX", "funcY")
  let output = apply_wgsl_virtual_overrides_with_binding_plan(source, plan)
  debug_inspect(output.contains("fn funcY() -> f32"), content="true")
  debug_inspect(output.contains("return funcX() + 1.0;"), content="true")
  debug_inspect(output.contains("return funcY();"), content="true")
  debug_inspect(output.contains("overridable::func"), content="false")
}
