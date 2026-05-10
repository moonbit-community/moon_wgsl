///|
test "WGSL source directives parse as directive AST nodes" {
  let source =
    #|enable f16, subgroups;
    #|requires readonly_and_readwrite_storage_textures;
    #|diagnostic(warn, derivative_uniformity);
    #|fn shade() -> f32 { return 1.0; }
    #|
  let unit = parse_wgsl_translation_unit_for_test(source)
  debug_inspect(unit.declarations()[0].kind(), content="Directive")
  debug_inspect(unit.declarations()[1].kind(), content="Directive")
  debug_inspect(unit.declarations()[2].kind(), content="Directive")
  guard unit.declarations()[0].data() is WgslGlobalDeclData::Directive(enable) else {
    abort("expected enable directive")
  }
  debug_inspect(enable.kind(), content="Enable")
  debug_inspect(enable.tail(), content="\"f16, subgroups\"")
  debug_inspect(enable.start(), content="0")
  debug_inspect(enable.end(), content="22")
  debug_inspect(enable.name().start(), content="0")
  debug_inspect(enable.name().end(), content="6")
  debug_inspect(enable.tail_start(), content="7")
  debug_inspect(enable.tail_end(), content="21")
  guard unit.declarations()[2].data()
    is WgslGlobalDeclData::Directive(diagnostic) else {
    abort("expected diagnostic directive")
  }
  debug_inspect(diagnostic.kind(), content="Diagnostic")
  debug_inspect(diagnostic.tail(), content="\"(warn, derivative_uniformity)\"")
}

///|
test "WGSL hash conditionals parse as directive AST nodes" {
  let source =
    #|#ifdef ENABLED
    #|const A: u32 = 1u;
    #|#endif
    #|
  let unit = parse_wgsl_translation_unit_for_test(source)
  debug_inspect(unit.declarations()[0].kind(), content="Directive")
  guard unit.declarations()[0].data() is WgslGlobalDeclData::Directive(ifdef) else {
    abort("expected ifdef directive")
  }
  debug_inspect(ifdef.kind(), content="Ifdef")
  debug_inspect(ifdef.tail(), content="\"ENABLED\"")
  debug_inspect(ifdef.start(), content="0")
  debug_inspect(ifdef.end(), content="14")
  debug_inspect(ifdef.name().start(), content="1")
  debug_inspect(ifdef.name().end(), content="6")
  debug_inspect(ifdef.tail_start(), content="7")
  debug_inspect(ifdef.tail_end(), content="14")
  debug_inspect(unit.declarations()[1].kind(), content="Const")
  debug_inspect(unit.declarations()[2].kind(), content="Directive")
}

///|
test "WGSL hash directive spans are absolute in translation units" {
  let source =
    #|// lead
    #|#ifdef ENABLED
    #|#endif
    #|
  let unit = parse_wgsl_translation_unit_for_test(source)
  debug_inspect(unit.declarations()[0].kind(), content="Trivia")
  guard unit.declarations()[1].data() is WgslGlobalDeclData::Directive(ifdef) else {
    abort("expected ifdef directive")
  }
  debug_inspect(ifdef.start(), content="8")
  debug_inspect(ifdef.end(), content="22")
  debug_inspect(ifdef.name().start(), content="9")
  debug_inspect(ifdef.name().end(), content="14")
  debug_inspect(ifdef.tail_start(), content="15")
  debug_inspect(ifdef.tail_end(), content="22")
}

///|
test "WGSL override function payload preserves qualified target path" {
  let source =
    #|override fn mod::inner(arg: f32) -> f32 {
    #|  return inner(arg);
    #|}
    #|
  let unit = parse_wgsl_translation_unit_for_test(source)
  guard unit.declarations()[0].data() is WgslGlobalDeclData::Function(function) else {
    abort("expected function payload")
  }
  debug_inspect(function.qualifier(), content="Some(Override)")
  debug_inspect(function.qualifier_start(), content="Some(0)")
  debug_inspect(function.qualifier_end(), content="Some(8)")
  debug_inspect(function.fn_start(), content="9")
  debug_inspect(function.fn_end(), content="11")
  debug_inspect(function.name().name(), content="\"mod::inner\"")
  debug_inspect(function.name().start(), content="12")
  debug_inspect(function.name().end(), content="22")
  debug_inspect(function.arguments()[0].name().name(), content="\"arg\"")
  debug_inspect(
    function.result(),
    content=(
      #|Some(
      #|  {
      #|    attributes: [],
      #|    start: 33,
      #|    end: 39,
      #|    ty_ref: Some(
      #|      {
      #|        atom: { kind: Identifier, text: "f32", start: 36, end: 39 },
      #|        arguments: [],
      #|        template_arguments: [],
      #|        start: 36,
      #|        end: 39,
      #|      },
      #|    ),
      #|  },
      #|)
    ),
  )
}

///|
test "WGSL statement classification uses identifier tokens" {
  let source =
    #|fn demo() {
    #|  const_assert(true);
    #|  var_name = 1u;
    #|}
    #|
  let unit = parse_wgsl_translation_unit_for_test(source)
  guard unit.declarations()[0].data() is WgslGlobalDeclData::Function(function) else {
    abort("expected function payload")
  }
  debug_inspect(function.body().statements().length(), content="2")
  debug_inspect(
    function.body().statements()[1].exported_local_bindings(),
    content="[]",
  )
}

///|
test "WGSL statement payload exposes structured statement semantics" {
  let source =
    #|fn demo(input: Input) -> f32 {
    #|  var value: f32 = input.base;
    #|  switch(input.mode) {
    #|    case MODE_A: {
    #|      value = input.alt;
    #|    }
    #|    default: {
    #|      value = input.fallback;
    #|    }
    #|  }
    #|  return value;
    #|}
    #|
  let unit = parse_wgsl_translation_unit_for_test(source)
  guard unit.declarations()[0].data() is WgslGlobalDeclData::Function(function) else {
    abort("expected function payload")
  }
  match function.body().statements()[0].payload() {
    LocalDeclaration(bindings) =>
      debug_inspect(
        bindings.map(fn(binding) { binding.name().name() }),
        content=(
          #|["value"]
        ),
      )
    _ => abort("expected local declaration payload")
  }
  match function.body().statements()[1].payload() {
    Switch(Some(expr)) =>
      debug_inspect(
        wgsl_expr_ref_source_text(source, expr),
        content="\"input.mode\"",
      )
    _ => abort("expected switch payload")
  }
  debug_inspect(
    function.body().statements()[1].expressions().map(fn(item) { item.role() }),
    content=(
      #|[SwitchSelector]
    ),
  )
  match function.body().statements()[2].payload() {
    Return(Some(expr)) =>
      debug_inspect(
        wgsl_expr_ref_source_text(source, expr),
        content="\"value\"",
      )
    _ => abort("expected return payload")
  }
}

///|
test "WGSL for statement expressions keep official header roles" {
  let source =
    #|fn demo(n: u32) -> u32 {
    #|  var sum: u32 = 0u;
    #|  for (var i: u32 = 0u; i < n; i++) {
    #|    sum += i;
    #|  }
    #|  for (sum = 0u; sum < n; sum += 1u) {
    #|    sum += 2u;
    #|  }
    #|  return sum;
    #|}
    #|
  let unit = parse_wgsl_translation_unit_for_test(source)
  guard unit.declarations()[0].data() is WgslGlobalDeclData::Function(function) else {
    abort("expected function payload")
  }
  let statements = function.body().statements()
  debug_inspect(statements[1].kind(), content="For")
  debug_inspect(
    statements[1].local_bindings().map(fn(binding) { binding.name().name() }),
    content=(
      #|["i"]
    ),
  )
  debug_inspect(
    statements[1].expressions().map(fn(item) { item.role() }),
    content=(
      #|[ForCondition, ForUpdate]
    ),
  )
  debug_inspect(
    statements[1]
    .expression_refs()
    .map(fn(expr) { wgsl_expr_ref_source_text(source, expr) }),
    content=(
      #|["i < n", "i++"]
    ),
  )
  debug_inspect(statements[2].kind(), content="For")
  debug_inspect(
    statements[2].expressions().map(fn(item) { item.role() }),
    content=(
      #|[ForInitializer, ForCondition, ForUpdate]
    ),
  )
  debug_inspect(
    statements[2]
    .expression_refs()
    .map(fn(expr) { wgsl_expr_ref_source_text(source, expr) }),
    content=(
      #|["sum = 0u", "sum < n", "sum += 1u"]
    ),
  )
}

///|
test "WGSL struct parser accepts preprocessing directives inside members" {
  let source =
    #|struct LightingInput {
    #|#ifdef STANDARD_MATERIAL_CLEARCOAT
    #|  layers: array<LayerLightingInput, 2>,
    #|#else   // STANDARD_MATERIAL_CLEARCOAT
    #|  layers: array<LayerLightingInput, 1>,
    #|#endif  // STANDARD_MATERIAL_CLEARCOAT
    #|  P: vec3<f32>,
    #|  F0_dielectric: vec3<f32>,
    #|}
    #|
  let unit = parse_wgsl_translation_unit_strict(source) catch {
    _ => abort("expected strict struct parse")
  }
  guard unit.declarations()[0].data() is WgslGlobalDeclData::Struct(struct_decl) else {
    abort("expected struct")
  }
  debug_inspect(struct_decl.members().length(), content="4")
  debug_inspect(struct_decl.members()[2].name().name(), content="\"P\"")
}

///|
test "WGSL struct parser accepts Bevy LightingInput member shape" {
  let source =
    #|struct LightingInput {
    #|#ifdef STANDARD_MATERIAL_CLEARCOAT
    #|    layers: array<LayerLightingInput, 2>,
    #|#else   // STANDARD_MATERIAL_CLEARCOAT
    #|    layers: array<LayerLightingInput, 1>,
    #|#endif  // STANDARD_MATERIAL_CLEARCOAT
    #|
    #|    // The world-space position.
    #|    P: vec3<f32>,
    #|    // The vector to the view.
    #|    V: vec3<f32>,
    #|
    #|    // The diffuse color of the material.
    #|    diffuse_color: vec3<f32>,
    #|
    #|    // The 0-1 metallic factor of the material.
    #|    metallic: f32,
    #|
    #|    // Specular reflectance at the normal incidence angle.
    #|    F0_dielectric: vec3<f32>,
    #|    F0_metallic: vec3<f32>,
    #|
    #|    // Constants for the BRDF approximation.
    #|    //
    #|    // See `EnvBRDFApprox` in
    #|    // <https://www.unrealengine.com/en-US/blog/physically-based-shading-on-mobile>.
    #|    // What we call `F_ab` they call `AB`.
    #|    F_ab: vec2<f32>,
    #|
    #|#ifdef STANDARD_MATERIAL_CLEARCOAT
    #|    // The strength of the clearcoat layer.
    #|    clearcoat_strength: f32,
    #|#endif  // STANDARD_MATERIAL_CLEARCOAT
    #|
    #|#ifdef STANDARD_MATERIAL_ANISOTROPY
    #|    // The anisotropy strength, reflecting the amount of increased roughness in
    #|    // the tangent direction.
    #|    anisotropy: f32,
    #|    // The tangent direction for anisotropy: i.e. the direction in which
    #|    // roughness increases.
    #|    Ta: vec3<f32>,
    #|    // The bitangent direction, which is the cross product of the normal with
    #|    // the tangent direction.
    #|    Ba: vec3<f32>,
    #|#endif  // STANDARD_MATERIAL_ANISOTROPY
    #|}
    #|
  let unit = parse_wgsl_translation_unit_strict(source) catch {
    _ => abort("expected strict Bevy struct parse")
  }
  guard unit.declarations()[0].data() is WgslGlobalDeclData::Struct(struct_decl) else {
    abort("expected struct")
  }
  debug_inspect(struct_decl.members().length() > 10, content="true")
}

///|
test "WGSL parser accepts official directives and statement attributes" {
  let source =
    #|enable f16, subgroups;
    #|requires readonly_and_readwrite_storage_textures;
    #|diagnostic(off, derivative_uniformity);
    #|const N: u32 = 3u;
    #|alias Values = array<vec4<f32>, N + 1u>;
    #|@compute @workgroup_size(1, 2, 3)
    #|fn main(@builtin(global_invocation_id) gid: vec3<u32>) @diagnostic(off, derivative_uniformity) {
    #|  @diagnostic(off, derivative_uniformity) if gid.x > 0u {
    #|    var<function> values: Values;
    #|    _ = values[0];
    #|  }
    #|}
    #|
  let unit = parse_wgsl_translation_unit_for_test(source)
  debug_inspect(unit.declarations().length(), content="6")
  debug_inspect(unit.declarations()[0].kind(), content="Directive")
  debug_inspect(unit.declarations()[1].kind(), content="Directive")
  debug_inspect(unit.declarations()[2].kind(), content="Directive")
  guard unit.declarations()[4].data()
    is WgslGlobalDeclData::TypeAlias(alias_decl) else {
    abort("expected type alias")
  }
  guard alias_decl.ty_ref() is Some(alias_ty) else {
    abort("expected alias type")
  }
  debug_inspect(
    alias_ty.canonical_text(),
    content="\"array<vec4<f32>, N + 1u>\"",
  )
  debug_inspect(alias_ty.template_arguments().length(), content="2")
  match alias_ty.template_arguments()[1] {
    Expression(expr) =>
      debug_inspect(
        expr.identifiers().map(fn(ident) { ident.name() }),
        content=(
          #|["N"]
        ),
      )
    _ => abort("expected expression template argument")
  }
  guard unit.declarations()[5].data() is WgslGlobalDeclData::Function(function) else {
    abort("expected function")
  }
  debug_inspect(function.body_attributes().length(), content="1")
  debug_inspect(
    function.body_attributes()[0].name().name(),
    content="\"diagnostic\"",
  )
  let first_statement = function.body().statements()[0]
  debug_inspect(first_statement.kind(), content="If")
  debug_inspect(first_statement.attributes().length(), content="1")
  debug_inspect(
    first_statement.attributes()[0].name().name(),
    content="\"diagnostic\"",
  )
  match first_statement.payload() {
    If(Some(condition)) =>
      debug_inspect(
        wgsl_expr_ref_source_text(source, condition),
        content="\"gid.x > 0u\"",
      )
    _ => abort("expected if condition")
  }
}

///|
test "WGSL parser classifies official loop continuing and switch clauses" {
  let source =
    #|fn main(mode: u32) -> u32 {
    #|  var value: u32 = 0u;
    #|  loop {
    #|    value++;
    #|    continuing {
    #|      break if value > 4u;
    #|    }
    #|  }
    #|  switch mode {
    #|    case 0u, 1u: {
    #|      value += 1u;
    #|    }
    #|    default {
    #|      value += 2u;
    #|    }
    #|  }
    #|  return value;
    #|}
    #|
  let unit = parse_wgsl_translation_unit_for_test(source)
  guard unit.declarations()[0].data() is WgslGlobalDeclData::Function(function) else {
    abort("expected function")
  }
  debug_inspect(function.body().statements()[1].kind(), content="Loop")
  let loop_body = function.body().statements()[1].blocks()[0]
  debug_inspect(loop_body.statements()[1].kind(), content="Continuing")
  debug_inspect(
    loop_body.statements()[1].blocks()[0].statements()[0].kind(),
    content="Break",
  )
  debug_inspect(function.body().statements()[2].kind(), content="Switch")
  let switch_body = function.body().statements()[2].blocks()[0]
  debug_inspect(switch_body.statements()[0].kind(), content="Case")
  guard switch_body.statements()[0].payload()
    is WgslStatementPayload::Case(selectors) else {
    abort("expected case selector payload")
  }
  debug_inspect(
    selectors.map(fn(selector) { wgsl_case_selector_snapshot(source, selector) }),
    content=(
      #|["0u", "1u"]
    ),
  )
  debug_inspect(switch_body.statements()[1].kind(), content="DefaultCase")
}

///|
test "WGSL parser models default as a case selector" {
  let source =
    #|fn main(value: u32) {
    #|  switch value @diagnostic(off, derivative_uniformity) {
    #|    case 0u, default, : {
    #|      return;
    #|    }
    #|  }
    #|}
    #|
  let unit = parse_wgsl_translation_unit_for_test(source)
  guard unit.declarations()[0].data() is WgslGlobalDeclData::Function(function) else {
    abort("expected function")
  }
  match function.body().statements()[0].payload() {
    Switch(Some(selector)) =>
      debug_inspect(
        wgsl_expr_ref_source_text(source, selector),
        content="\"value\"",
      )
    _ => abort("expected switch selector")
  }
  let switch_body = function.body().statements()[0].blocks()[0]
  let case_statement = switch_body.statements()[0]
  guard case_statement.payload() is WgslStatementPayload::Case(selectors) else {
    abort("expected case payload")
  }
  debug_inspect(
    selectors.map(fn(selector) { wgsl_case_selector_snapshot(source, selector) }),
    content=(
      #|["0u", "default"]
    ),
  )
  debug_inspect(
    case_statement.expressions().map(fn(item) { item.role() }),
    content=(
      #|[CaseSelector]
    ),
  )
}

///|
test "WGSL parser structures assignment update and call statements" {
  let source =
    #|fn work(value: u32) {
    #|}
    #|fn main() {
    #|  var value: u32 = 0u;
    #|  value = value + 1u;
    #|  value += 2u;
    #|  value <<= 1u;
    #|  value++;
    #|  value--;
    #|  work(value, 1u, value + 2u);
    #|  _ = value;
    #|}
    #|
  let unit = parse_wgsl_translation_unit_for_test(source)
  guard unit.declarations()[1].data() is WgslGlobalDeclData::Function(function) else {
    abort("expected main function")
  }
  let statements = function.body().statements()
  debug_inspect(statements[1].kind(), content="Assignment")
  debug_inspect(statements[2].kind(), content="Assignment")
  debug_inspect(statements[3].kind(), content="Assignment")
  debug_inspect(statements[4].kind(), content="Increment")
  debug_inspect(statements[5].kind(), content="Decrement")
  debug_inspect(statements[6].kind(), content="FunctionCall")
  debug_inspect(statements[7].kind(), content="Assignment")
  guard statements[1].payload()
    is WgslStatementPayload::Assignment(assign_op, assign_lhs, assign_rhs) else {
    abort("expected plain assignment payload")
  }
  debug_inspect(assign_op, content="\"=\"")
  guard assign_lhs is Some(lhs) else { abort("expected assignment lhs") }
  guard assign_rhs is Some(rhs) else { abort("expected assignment rhs") }
  debug_inspect(wgsl_expr_ref_source_text(source, lhs), content="\"value\"")
  debug_inspect(
    wgsl_expr_ref_source_text(source, rhs),
    content="\"value + 1u\"",
  )
  guard statements[2].payload()
    is WgslStatementPayload::Assignment(compound_op, _, _) else {
    abort("expected compound assignment payload")
  }
  debug_inspect(compound_op, content="\"+=\"")
  guard statements[3].payload()
    is WgslStatementPayload::Assignment(shift_op, _, _) else {
    abort("expected shift assignment payload")
  }
  debug_inspect(shift_op, content="\"<<=\"")
  guard statements[4].payload()
    is WgslStatementPayload::Increment(increment_target) else {
    abort("expected increment payload")
  }
  guard increment_target is Some(increment_expr) else {
    abort("expected increment target")
  }
  debug_inspect(
    wgsl_expr_ref_source_text(source, increment_expr),
    content="\"value\"",
  )
  guard statements[5].payload()
    is WgslStatementPayload::Decrement(decrement_target) else {
    abort("expected decrement payload")
  }
  guard decrement_target is Some(decrement_expr) else {
    abort("expected decrement target")
  }
  debug_inspect(
    wgsl_expr_ref_source_text(source, decrement_expr),
    content="\"value\"",
  )
  guard statements[6].payload() is WgslStatementPayload::FunctionCall(call_expr) else {
    abort("expected function call payload")
  }
  guard call_expr is Some(call_ref) else { abort("expected call expression") }
  debug_inspect(
    wgsl_expr_ref_source_text(source, call_ref),
    content="\"work(value, 1u, value + 2u)\"",
  )
  match call_ref.root() {
    Some(root) =>
      match root.kind() {
        WgslExprNodeKind::Call(_, arguments) =>
          debug_inspect(arguments.length(), content="3")
        _ => abort("expected parsed call root")
      }
    None => abort("expected parsed call root")
  }
  guard statements[7].payload()
    is WgslStatementPayload::Assignment(phony_op, phony_lhs, _) else {
    abort("expected phony assignment payload")
  }
  debug_inspect(phony_op, content="\"=\"")
  guard phony_lhs is Some(phony_expr) else { abort("expected phony lhs") }
  debug_inspect(wgsl_expr_ref_source_text(source, phony_expr), content="\"_\"")
}

///|
test "WGSL identifier collection exposes qualified function calls" {
  let source =
    #|fn entry_point() -> f32 {
    #|  return overridable::func(1.0, 2.0);
    #|}
    #|
  let unit = parse_wgsl_translation_unit_for_test(source)
  guard unit.declarations()[0].data() is WgslGlobalDeclData::Function(function) else {
    abort("expected function payload")
  }
  let nodes : Array[WgslIdent] = []
  @ast_analysis.collect_wgsl_function_body_identifier_nodes(function, nodes)
  debug_inspect(
    nodes.map(fn(node) { node.name() }),
    content=(
      #|["overridable::func"]
    ),
  )
}
