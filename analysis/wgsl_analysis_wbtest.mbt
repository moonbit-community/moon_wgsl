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
