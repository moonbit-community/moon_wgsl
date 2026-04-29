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
test "same-line attributed entry points stay reachable" {
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
  debug_inspect(
    wgsl_source_declares_entry_point(source, "fragment"),
    content="true",
  )
  let extracted = extract_wgsl_module_items(source, ["fragment"])
  debug_inspect(extracted.contains("@fragment fn fragment"), content="true")
  debug_inspect(extracted.contains("struct Output"), content="true")
  debug_inspect(extracted.contains("fn helper"), content="false")
}

///|
test "commented entry point attributes do not mark functions as entry points" {
  let source =
    #|// @fragment belongs to a comment, not to helper.
    #|fn helper() -> u32 {
    #|  return 1u;
    #|}
    #|
  debug_inspect(
    wgsl_source_declares_entry_point(source, "helper"),
    content="false",
  )
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
