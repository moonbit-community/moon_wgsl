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
