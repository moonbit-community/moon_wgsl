///|
test "AST import stripping preserves non-import items" {
  let source =
    #|#define_import_path demo::shaders
    #|#define FLAG
    #|#import demo::{
    #|  shared::Globals,
    #|  math::mix_value,
    #|}
    #|const VALUE: u32 = 1u;
    #|
  let stripped = strip_wgsl_import_declarations(source)
  debug_inspect(stripped.contains("#define_import_path"), content="false")
  debug_inspect(stripped.contains("#import"), content="false")
  debug_inspect(stripped.contains("shared::Globals"), content="false")
  debug_inspect(stripped.contains("#define FLAG"), content="true")
  debug_inspect(stripped.contains("const VALUE: u32 = 1u;"), content="true")
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
  let extracted = extract_wgsl_module_items(source, ["fragment"])
  debug_inspect(extracted.contains("@fragment fn fragment"), content="true")
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
  let extracted = extract_wgsl_module_items(source, ["use_value"])
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
  let extracted = extract_wgsl_module_items(source, ["make_output"])
  debug_inspect(extracted.contains("struct Item"), content="true")
  debug_inspect(extracted.contains("alias Items"), content="true")
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
  let extracted = extract_wgsl_module_items(source, ["entry"])
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
  let extracted = extract_wgsl_module_items(source, ["entry"])
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
  let extracted = extract_wgsl_module_items(source, ["entry"])
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
  let extracted = extract_wgsl_module_items(source, ["entry"])
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
  let extracted = extract_wgsl_module_items(source, ["entry"])
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
  let extracted = extract_wgsl_module_items(source, ["entry"])
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
  let extracted = extract_wgsl_module_items(source, ["entry"])
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
  let extracted = extract_wgsl_module_items(source, ["entry"])
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
  let extracted = extract_wgsl_module_items(source, ["entry"])
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
  let extracted = extract_wgsl_module_items(source, ["entry"])
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
  let extracted = extract_wgsl_module_items(source, ["entry"])
  debug_inspect(extracted.contains("struct Item"), content="true")
  debug_inspect(extracted.contains("const selected"), content="true")
  debug_inspect(extracted.contains("const value"), content="false")
}

///|
test "rename plan global rules do not rewrite function parameter locals" {
  let source =
    #|struct Input {
    #|  instance_index: u32,
    #|}
    #|fn read_instance(in: Input) -> u32 {
    #|  return in.instance_index;
    #|}
    #|
  let redirects : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
  redirects.set("Input", "mesh__Input")
  redirects.set("read_instance", "mesh__read_instance")
  let rewritten = rewrite_wgsl_declarations_with_rename_plan(
    source,
    build_wgsl_rename_plan_from_redirect_map(
      redirects,
      GlobalDeclarationAndReferences,
    ),
  )
  debug_inspect(rewritten.contains("struct mesh__Input"), content="true")
  debug_inspect(
    rewritten.contains("fn mesh__read_instance(in: mesh__Input)"),
    content="true",
  )
  debug_inspect(rewritten.contains("return in.instance_index;"), content="true")
  debug_inspect(rewritten.contains("mesh__in"), content="false")
}

///|
test "rename plan function-local rules rewrite parameter and body together" {
  let source =
    #|struct Input {
    #|  rgb: vec3<f32>,
    #|}
    #|fn fragment(in: Input) -> vec3<f32> {
    #|  return max(in.rgb, vec3(0.0));
    #|}
    #|
  let plan = WgslRenamePlan::empty()
  plan.add("in", "in_wgsl", FunctionLocal)
  let rewritten = rewrite_wgsl_declarations_with_rename_plan(source, plan)
  debug_inspect(
    rewritten.contains("fn fragment(in_wgsl: Input)"),
    content="true",
  )
  debug_inspect(
    rewritten.contains("return max(in_wgsl.rgb, vec3(0.0));"),
    content="true",
  )
  debug_inspect(rewritten.contains("return max(in.rgb"), content="false")
}

///|
test "rename plan function-local rules follow nested statement scopes" {
  let source =
    #|fn fragment(value: u32) -> u32 {
    #|  if (value > 0u) {
    #|    let item = value + 1u;
    #|    return item;
    #|  }
    #|  return value;
    #|}
    #|
  let plan = WgslRenamePlan::empty()
  plan.add("item", "item_wgsl", FunctionLocal)
  let rewritten = rewrite_wgsl_declarations_with_rename_plan(source, plan)
  debug_inspect(
    rewritten.contains("let item_wgsl = value + 1u;"),
    content="true",
  )
  debug_inspect(rewritten.contains("return item_wgsl;"), content="true")
  debug_inspect(rewritten.contains("let item ="), content="false")
}

///|
test "rename plan reference rules rewrite recursively scoped blocks" {
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
  let redirects : @hashmap.HashMap[String, String] = @hashmap.HashMap::new()
  redirects.set("helper", "renamed_helper")
  let rewritten = rewrite_wgsl_declarations_with_rename_plan(
    source,
    build_wgsl_rename_plan_from_redirect_map(redirects, ReferencesOnly),
  )
  debug_inspect(rewritten.contains("fn helper()"), content="true")
  debug_inspect(rewritten.contains("return renamed_helper();"), content="true")
  debug_inspect(rewritten.contains("return helper();"), content="false")
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
  let extracted = extract_wgsl_module_items(source, ["entry"])
  debug_inspect(extracted.contains("fn helper"), content="true")
  debug_inspect(extracted.contains("fn entry"), content="true")
}

///|
test "normalizer dedupes duplicate declarations by AST structure" {
  let source =
    #|struct Shared {
    #|  value: u32,
    #|}
    #|struct Shared { value : u32 }
    #|fn entry(v: Shared) -> u32 {
    #|  return v.value;
    #|}
    #|
  let normalized = normalize_wgsl_composed_declarations(source, [])
  debug_inspect(
    normalized.contains("struct Shared {\n  value: u32,\n}"),
    content="true",
  )
  debug_inspect(normalized.contains("struct Shared { value"), content="false")
  debug_inspect(normalized.contains("fn entry"), content="true")
}

///|
test "normalizer reads resource binding keys from expression and type AST" {
  let source =
    #|struct Globals { value: u32 }
    #|@group(0u) @binding(1u) var<uniform> globals: Globals;
    #|@group(0) @binding(1) var<uniform> globals_alias: Globals;
    #|fn entry() -> u32 {
    #|  return globals_alias.value;
    #|}
    #|
  let normalized = normalize_wgsl_composed_declarations(source, [])
  debug_inspect(normalized.contains("globals_alias:"), content="false")
  debug_inspect(normalized.contains("return globals.value;"), content="true")
}

///|
test "normalizer suffix rewrites require explicit alias provenance" {
  let source =
    #|fn module__helper() -> u32 {
    #|  return 1u;
    #|}
    #|fn entry() -> u32 {
    #|  return helper();
    #|}
    #|
  let untouched = normalize_wgsl_composed_declarations(source, [])
  debug_inspect(untouched.contains("return helper();"), content="true")
  let normalized = normalize_wgsl_composed_declarations(source, [
    { from_name: "module::helper", to_name: "module__helper" },
  ])
  debug_inspect(normalized.contains("return module__helper();"), content="true")
  debug_inspect(normalized.contains("return helper();"), content="false")
}
