///|
test "WGSL translation unit classifies top-level declarations" {
  let source =
    #|#define_import_path demo::module
    #|#import demo::shared::Value
    #|struct Value {
    #|  x: u32,
    #|}
    #|@group(0) @binding(0) var<uniform> globals: Value;
    #|const_assert(1 == 1);
    #|@fragment fn fragment() -> vec4<f32> {
    #|  return vec4<f32>(1.0);
    #|}
    #|
  let unit = parse_wgsl_translation_unit(source)
  debug_inspect(unit.declarations.length(), content="6")
  debug_inspect(unit.declarations[0].kind, content="Directive")
  debug_inspect(unit.declarations[1].kind, content="Import")
  debug_inspect(unit.declarations[2].kind, content="Struct")
  debug_inspect(unit.declarations[3].kind, content="GlobalVariable")
  debug_inspect(unit.declarations[4].kind, content="ConstAssert")
  debug_inspect(unit.declarations[5].kind, content="Function")
  debug_inspect(unit.declarations[5].name, content="\"fragment\"")
}
