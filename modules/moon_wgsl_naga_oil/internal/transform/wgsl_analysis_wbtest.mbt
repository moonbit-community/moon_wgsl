///|
fn wbtest_reference_plan_from_redirect_map(
  redirect_map : Map[String, String],
) -> WgslReferenceRewritePlan {
  let plan = WgslReferenceRewritePlan()
  for entry in redirect_map.iter() {
    let (from_name, to_name) = entry
    match WgslReferencePath::from_text(from_name) {
      Some(reference_path) =>
        plan.add_symbol_reference_binding(
          WgslComposeSymbolIdentity("wbtest.wgsl", from_name),
          reference_path,
          to_name,
        )
      None => ()
    }
  }
  plan
}

///|
fn wgsl_analysis_text_before(
  text : String,
  left : String,
  right : String,
) -> Bool {
  let parts : Array[StringView] = text.split(left).collect()
  if parts.length() < 2 {
    return false
  }
  parts[1].contains(right)
}

///|
test "dialect masking removes directives and preserves declarations" {
  let source =
    #|#define_import_path demo::shaders
    #|#define FLAG
    #|#import demo::{
    #|  shared::Globals,
    #|  math::mix_value,
    #|}
    #|const VALUE: u32 = 1u;
    #|
  let stripped = strip_wgsl_import_declarations_strict(source) catch {
    error => abort(error.message())
  }
  debug_inspect(stripped.contains("#define_import_path"), content="false")
  debug_inspect(stripped.contains("#import"), content="false")
  debug_inspect(stripped.contains("shared::Globals"), content="false")
  debug_inspect(stripped.contains("#define FLAG"), content="false")
  debug_inspect(stripped.contains("const VALUE: u32 = 1u;"), content="true")
  debug_inspect(
    utf8_byte_length(stripped),
    content=source |> utf8_byte_length |> Int::to_string,
  )
}

///|
test "tree-shaken extraction preserves multiline grouped imports" {
  let source =
    #|#define_import_path demo::functions
    #|#import demo::{
    #|  types::Input,
    #|  helpers as helpers,
    #|}
    #|fn helper_user(in: Input) -> u32 {
    #|  return helpers::pack_value_(in.value);
    #|}
    #|fn entry(in: Input) -> u32 {
    #|  return helper_user(in);
    #|}
    #|
  let extracted = extract_wgsl_module_item_origins_strict(source, ["entry"]) catch {
    error => abort(error.message())
  }
  debug_inspect(extracted.source().contains("#import"), content="true")
  debug_inspect(
    extracted.source().contains("helpers as helpers"),
    content="true",
  )
  debug_inspect(extracted.source().contains("fn helper_user"), content="true")
  debug_inspect(extracted.source().contains("fn entry"), content="true")
}

///|
test "same-line attributed declarations stay reachable" {
  let source =
    #|struct Output {
    #|  color: vec4<f32>,
    #|}
    #|@fragment fn fragment() -> Output {
    #|  var out: Output;
    #|  return out;
    #|}
    #|fn helper() -> u32 {
    #|  return 1u;
    #|}
    #|
  let extracted = @ir.tree_shake_wgsl_source_via_ir(source, ["fragment"])
  debug_inspect(extracted.contains("fn fragment"), content="true")
  debug_inspect(extracted.contains("struct Output"), content="true")
  debug_inspect(extracted.contains("fn helper"), content="false")
}

///|
test "declaration graph keeps dependencies from AST initializers" {
  let source =
    #|const BASE: u32 = 1u;
    #|const VALUE: u32 = BASE + 1u;
    #|fn use_value() -> u32 {
    #|  return VALUE;
    #|}
    #|
  let extracted = @ir.tree_shake_wgsl_source_via_ir(source, ["use_value"])
  debug_inspect(extracted.contains("const BASE"), content="true")
  debug_inspect(extracted.contains("const VALUE"), content="true")
  debug_inspect(extracted.contains("fn use_value"), content="true")
}

///|
test "declaration graph keeps dependencies from AST type refs" {
  let source =
    #|struct Item {
    #|  value: u32,
    #|}
    #|alias Items = array<Item, 4>;
    #|struct Output {
    #|  values: Items,
    #|}
    #|fn make_output() -> Output {
    #|  var out: Output;
    #|  return out;
    #|}
    #|fn unused() -> u32 {
    #|  return 1u;
    #|}
    #|
  let extracted = @ir.tree_shake_wgsl_source_via_ir(source, ["make_output"])
  debug_inspect(extracted.contains("struct Item"), content="true")
  debug_inspect(extracted.contains("values: array<Item, 4>"), content="true")
  debug_inspect(extracted.contains("struct Output"), content="true")
  debug_inspect(extracted.contains("fn make_output"), content="true")
  debug_inspect(extracted.contains("fn unused"), content="false")
}

///|
test "declaration graph does not keep globals shadowed by function locals" {
  let source =
    #|const local: u32 = 99u;
    #|const arg: u32 = 88u;
    #|const nested: u32 = 77u;
    #|const i: u32 = 66u;
    #|fn entry(arg: u32) -> u32 {
    #|  let local = arg + 1u;
    #|  if (local > 0u) {
    #|    let nested = local;
    #|    return nested;
    #|  }
    #|  for (var i: u32 = 0u; i < arg; i = i + 1u) {
    #|    continue;
    #|  }
    #|  return local;
    #|}
    #|
  let extracted = extract_wgsl_module_item_origins_strict(source, ["entry"]).source()
  debug_inspect(extracted.contains("const local"), content="false")
  debug_inspect(extracted.contains("const arg"), content="false")
  debug_inspect(extracted.contains("const nested"), content="false")
  debug_inspect(extracted.contains("const i"), content="false")
  debug_inspect(extracted.contains("fn entry"), content="true")
}

///|
test "declaration graph keeps globals referenced before local shadows" {
  let source =
    #|fn helper() -> u32 {
    #|  return 1u;
    #|}
    #|fn entry() -> u32 {
    #|  let value = helper();
    #|  let helper = 2u;
    #|  return value + helper;
    #|}
    #|
  let extracted = @ir.tree_shake_wgsl_source_via_ir(source, ["entry"])
  debug_inspect(extracted.contains("fn helper"), content="true")
  debug_inspect(extracted.contains("fn entry"), content="true")
}

///|
test "declaration graph keeps initializer callee with same local name" {
  let source =
    #|fn point_light(id: u32) -> u32 {
    #|  return id + 1u;
    #|}
    #|fn entry(light_id: u32) -> u32 {
    #|  let point_light = point_light(light_id);
    #|  return point_light;
    #|}
    #|
  let extracted = @ir.tree_shake_wgsl_source_via_ir(source, ["entry"])
  debug_inspect(extracted.contains("fn point_light"), content="true")
  debug_inspect(extracted.contains("fn entry"), content="true")
}

///|
test "declaration graph keeps local declaration type refs with same local name" {
  let source =
    #|struct View {
    #|  value: u32,
    #|}
    #|fn entry() -> u32 {
    #|  let View: View = View(1u);
    #|  return View.value;
    #|}
    #|
  let extracted = @ir.tree_shake_wgsl_source_via_ir(source, ["entry"])
  debug_inspect(extracted.contains("struct View"), content="true")
  debug_inspect(extracted.contains("fn entry"), content="true")
}

///|
test "declaration graph keeps compound initializer callee before local scope" {
  let source =
    #|fn helper(id: u32) -> u32 {
    #|  return id + 1u;
    #|}
    #|fn entry(cond: bool, light_id: u32) -> u32 {
    #|  if (cond) {
    #|    let helper = helper(light_id);
    #|    return helper;
    #|  }
    #|  return 0u;
    #|}
    #|
  let extracted = @ir.tree_shake_wgsl_source_via_ir(source, ["entry"])
  debug_inspect(extracted.contains("fn helper"), content="true")
  debug_inspect(extracted.contains("fn entry"), content="true")
}

///|
test "declaration graph keeps for initializer callee before loop local scope" {
  let source =
    #|fn helper(id: u32) -> u32 {
    #|  return id + 1u;
    #|}
    #|fn entry() -> u32 {
    #|  for (var helper: u32 = helper(0u); helper < 2u; helper = helper + 1u) {
    #|  }
    #|  return 0u;
    #|}
    #|
  let extracted = @ir.tree_shake_wgsl_source_via_ir(source, ["entry"])
  debug_inspect(extracted.contains("fn helper"), content="true")
  debug_inspect(extracted.contains("fn entry"), content="true")
}

///|
test "declaration graph filters compound locals after declaration" {
  let source =
    #|const helper: u32 = 1u;
    #|fn entry(cond: bool) -> u32 {
    #|  if (cond) {
    #|    let helper = 2u;
    #|    return helper;
    #|  }
    #|  return 0u;
    #|}
    #|
  let extracted = extract_wgsl_module_item_origins_strict(source, ["entry"]).source()
  debug_inspect(extracted.contains("const helper"), content="false")
  debug_inspect(extracted.contains("fn entry"), content="true")
}

///|
test "declaration graph does not leak for header locals after loop" {
  let source =
    #|const i: u32 = 9u;
    #|fn entry() -> u32 {
    #|  for (var i: u32 = 0u; i < 2u; i = i + 1u) {
    #|  }
    #|  return i;
    #|}
    #|
  let extracted = @ir.tree_shake_wgsl_source_via_ir(source, ["entry"])
  debug_inspect(extracted.contains("const i"), content="true")
  debug_inspect(extracted.contains("fn entry"), content="true")
}

///|
test "declaration graph does not leak nested compound locals to outer block" {
  let source =
    #|const helper: u32 = 1u;
    #|fn entry(cond: bool) -> u32 {
    #|  if (cond) {
    #|    if (cond) {
    #|      let helper = 2u;
    #|    }
    #|    return helper;
    #|  }
    #|  return 0u;
    #|}
    #|
  let extracted = @ir.tree_shake_wgsl_source_via_ir(source, ["entry"])
  debug_inspect(extracted.contains("const helper"), content="true")
  debug_inspect(extracted.contains("fn entry"), content="true")
}

///|
test "declaration graph does not leak nested local shadows" {
  let source =
    #|const nested: u32 = 1u;
    #|fn entry(cond: bool) -> u32 {
    #|  if (cond) {
    #|    let nested = 2u;
    #|  }
    #|  return nested;
    #|}
    #|
  let extracted = @ir.tree_shake_wgsl_source_via_ir(source, ["entry"])
  debug_inspect(extracted.contains("const nested"), content="true")
  debug_inspect(extracted.contains("fn entry"), content="true")
}

///|
test "declaration graph ignores member access suffix dependencies" {
  let source =
    #|struct Item {
    #|  value: f32,
    #|}
    #|const value: f32 = 2.0;
    #|const selected: f32 = Item(1.0).value;
    #|fn entry() -> f32 {
    #|  return selected;
    #|}
    #|
  let extracted = @ir.tree_shake_wgsl_source_via_ir(source, ["entry"])
  debug_inspect(extracted.contains("struct Item"), content="true")
  debug_inspect(extracted.contains("const selected"), content="true")
  debug_inspect(extracted.contains("const value"), content="false")
}

///|
test "declaration graph does not resolve namespace suffix as local dependency" {
  let source =
    #|const helper: u32 = 1u;
    #|fn entry() -> u32 {
    #|  return module::helper();
    #|}
    #|
  let extracted = extract_wgsl_module_item_origins_strict(source, ["entry"]).source()
  debug_inspect(extracted.contains("const helper"), content="false")
  debug_inspect(extracted.contains("fn entry"), content="true")
}

///|
test "declaration graph reads switch case expressions without keyword leaks" {
  let source =
    #|const case: u32 = 99u;
    #|const SELECTED: u32 = 1u;
    #|fn entry(value: u32) -> u32 {
    #|  switch(value) {
    #|    case SELECTED: {
    #|      return 1u;
    #|    }
    #|    default: {
    #|    }
    #|  }
    #|  return 0u;
    #|}
    #|
  let extracted = @ir.tree_shake_wgsl_source_via_ir(source, ["entry"])
  debug_inspect(extracted.contains("const SELECTED"), content="true")
  debug_inspect(extracted.contains("const case"), content="false")
  debug_inspect(extracted.contains("fn entry"), content="true")
}

///|
test "declaration graph keeps break-if expression dependencies" {
  let source =
    #|const STOP: bool = true;
    #|fn entry() {
    #|  loop {
    #|    continuing {
    #|      break if STOP;
    #|    }
    #|  }
    #|}
    #|
  let extracted = @ir.tree_shake_wgsl_source_via_ir(source, ["entry"])
  debug_inspect(extracted.contains("const STOP"), content="true")
  debug_inspect(extracted.contains("fn entry"), content="true")
}

///|
test "declaration graph orders statement-call argument dependencies before callers" {
  let source =
    #|fn caller() {
    #|  sink(helper(1u), 2u);
    #|}
    #|fn sink(value: u32, other: u32) {
    #|}
    #|fn helper(value: u32) -> u32 {
    #|  return value;
    #|}
    #|fn entry() {
    #|  caller();
    #|}
    #|
  let extracted = extract_wgsl_module_item_origins_strict(source, ["entry"]).source()
  debug_inspect(
    wgsl_analysis_text_before(extracted, "fn helper", "fn caller"),
    content="true",
  )
  debug_inspect(
    wgsl_analysis_text_before(extracted, "fn sink", "fn caller"),
    content="true",
  )
  debug_inspect(
    wgsl_analysis_text_before(extracted, "fn caller", "fn entry"),
    content="true",
  )
}

///|
test "declaration graph orders atomic-call argument dependencies before callers" {
  let source =
    #|var<workgroup> counter: atomic<u32>;
    #|fn caller() {
    #|  atomicMax(&counter, helper(1u));
    #|}
    #|fn helper(value: u32) -> u32 {
    #|  return value;
    #|}
    #|@compute
    #|@workgroup_size(1)
    #|fn entry() {
    #|  caller();
    #|}
    #|
  let extracted = extract_wgsl_module_item_origins_strict(source, ["entry"]).source()
  debug_inspect(
    wgsl_analysis_text_before(extracted, "fn helper", "fn caller"),
    content="true",
  )
  debug_inspect(
    wgsl_analysis_text_before(extracted, "fn caller", "fn entry"),
    content="true",
  )
}

///|
test "declaration graph imports direct const arguments before callee dependencies" {
  let source =
    #|const SCALE: f32 = 0.003;
    #|const TEMPORAL_SCALE: f32 = 0.5;
    #|fn jittered() -> f32 {
    #|  return TEMPORAL_SCALE;
    #|}
    #|fn entry() -> f32 {
    #|  return jittered() + SCALE;
    #|}
    #|
  let extracted = extract_wgsl_module_item_origins_strict(source, ["entry"]).source()
  let expected =
    #|"const SCALE: f32 = 0.003;\nconst TEMPORAL_SCALE: f32 = 0.5;\nfn jittered() -> f32 {return TEMPORAL_SCALE;\n}\nfn entry() -> f32 {return jittered() + SCALE;\n}\n"
  debug_inspect(extracted, content=expected)
}

///|
test "binding plan reference rules rewrite recursively scoped blocks" {
  let source =
    #|fn helper() -> u32 {
    #|  return 1u;
    #|}
    #|fn entry(flag: bool) -> u32 {
    #|  if (flag) {
    #|    return helper();
    #|  }
    #|  return 0u;
    #|}
    #|
  let redirects : Map[String, String] = Map([])
  redirects.set("helper", "renamed_helper")
  let rewritten = rewrite_wgsl_references_with_binding_plan(
    source,
    wbtest_reference_plan_from_redirect_map(redirects),
  )
  debug_inspect(rewritten.contains("fn helper()"), content="true")
  debug_inspect(rewritten.contains("return renamed_helper();"), content="true")
  debug_inspect(rewritten.contains("return helper();"), content="false")
}

///|
test "binding plan reference rules do not rewrite statement keywords" {
  let source =
    #|fn entry(flag: bool) -> u32 {
    #|  if (flag) {
    #|    return 1u;
    #|  }
    #|  return 0u;
    #|}
    #|
  let redirects : Map[String, String] = Map([])
  redirects.set("if", "if_renamed")
  redirects.set("return", "return_renamed")
  redirects.set("let", "let_renamed")
  let rewritten = rewrite_wgsl_references_with_binding_plan(
    source,
    wbtest_reference_plan_from_redirect_map(redirects),
  )
  debug_inspect(rewritten.contains("if (flag)"), content="true")
  debug_inspect(rewritten.contains("return 1u;"), content="true")
  debug_inspect(rewritten.contains("return 0u;"), content="true")
  debug_inspect(rewritten.contains("if_renamed"), content="false")
  debug_inspect(rewritten.contains("return_renamed"), content="false")
}

///|
test "declaration graph keeps dependencies from recursively scoped blocks" {
  let source =
    #|fn helper() -> u32 {
    #|  return 1u;
    #|}
    #|fn entry(flag: bool) -> u32 {
    #|  if (flag) {
    #|    {
    #|      return helper();
    #|    }
    #|  }
    #|  return 0u;
    #|}
    #|
  let extracted = @ir.tree_shake_wgsl_source_via_ir(source, ["entry"])
  debug_inspect(extracted.contains("fn helper"), content="true")
  debug_inspect(extracted.contains("fn entry"), content="true")
}

///|
test "analysis reachability resolves transitive dependencies" {
  let source =
    #|const BASE: u32 = 1u;
    #|const VALUE: u32 = BASE + 1u;
    #|fn entry() -> u32 {
    #|  return VALUE;
    #|}
    #|
  let unit = parse_wgsl_translation_unit_strict(source) catch {
    _ => abort("expected valid WGSL parse")
  }
  let reachable = collect_wgsl_reachable_declaration_names(
    unit.declarations(),
    ["entry"],
  )
  let names = reachable.included_names
  names.sort()
  debug_inspect(names.join(","), content="\"BASE,VALUE,entry\"")
  debug_inspect(reachable.missing_root_items.length(), content="0")
}

///|
test "analysis reachability respects function local shadowing" {
  let source =
    #|const helper: u32 = 1u;
    #|fn entry() -> u32 {
    #|  let helper = 2u;
    #|  return helper;
    #|}
    #|
  let unit = parse_wgsl_translation_unit_strict(source) catch {
    _ => abort("expected valid WGSL parse")
  }
  let reachable = collect_wgsl_reachable_declaration_names(
    unit.declarations(),
    ["entry"],
  )
  let names = reachable.included_names
  names.sort()
  debug_inspect(names.join(","), content="\"entry\"")
}

///|
test "naga dependency order records full module function arena side effects" {
  let source =
    #|fn earlier_unused() -> u32 {
    #|  return late_helper();
    #|}
    #|
    #|fn selected_a() -> u32 {
    #|  return 1u;
    #|}
    #|
    #|fn selected_b() -> u32 {
    #|  return 2u;
    #|}
    #|
    #|fn late_helper() -> u32 {
    #|  return 3u;
    #|}
    #|
  let origins = collect_wgsl_naga_dependency_ordered_item_origins_strict(source) catch {
    _ => abort("expected valid WGSL parse")
  }
  let names : Array[String] = []
  for origin in origins {
    names.push(origin.name())
  }
  debug_inspect(
    names.join(","),
    content="\"late_helper,earlier_unused,selected_a,selected_b\"",
  )
}

///|
test "naga dependency pull records earlier declarations that pull later items" {
  let source =
    #|fn earlier_unused() -> u32 {
    #|  return late_helper();
    #|}
    #|
    #|fn selected_a() -> u32 {
    #|  return 1u;
    #|}
    #|
    #|fn late_helper() -> u32 {
    #|  return 3u;
    #|}
    #|
  let origins = collect_wgsl_naga_dependency_pulled_item_origins_strict(source) catch {
    _ => abort("expected valid WGSL parse")
  }
  debug_inspect(origins.length(), content="1")
  debug_inspect(origins[0].name(), content="\"late_helper\"")
}

///|
test "module item extraction excludes Core placeholders for oil directives" {
  let source =
    #|#define_import_path bevy_pbr::ambient
    #|
    #|#import bevy_pbr::{
    #|    lighting::{EnvBRDFApprox, F_AB},
    #|    mesh_view_bindings::lights,
    #|}
    #|
    #|struct AmbientResult {
    #|  value: f32,
    #|}
    #|
    #|fn ambient_light() -> AmbientResult {
    #|  return AmbientResult(
    #|    EnvBRDFApprox(1.0, F_AB(1.0, 1.0)) + lights.ambient_color.x,
    #|  );
    #|}
    #|
  let extraction = extract_wgsl_module_item_origins_strict(source, [
    "ambient_light",
  ]) catch {
    error => abort(error.message())
  }
  let extracted = extraction.source()
  debug_inspect(extracted.contains("#define_import_path"), content="false")
  debug_inspect(extracted.contains("#import bevy_pbr::{"), content="true")
  debug_inspect(
    extracted.contains("mesh_view_bindings::lights"),
    content="true",
  )
  debug_inspect(extracted.contains("fn ambient_light()"), content="true")
  debug_inspect(extracted.contains("struct AmbientResult"), content="true")
}
