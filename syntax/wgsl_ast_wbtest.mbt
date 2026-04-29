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

///|
test "WGSL translation unit exposes Naga-shaped declaration payloads" {
  let source =
    #|struct Vertex {
    #|  @location(0) position: vec3<f32>,
    #|  color: vec4<f32>,
    #|}
    #|@group(0) @binding(1) var<uniform> globals: Globals;
    #|alias Color = vec4<f32>;
    #|const SCALE: f32 = 2.0;
    #|@id(0) override ENABLED: bool = true;
    #|@fragment fn fragment(@location(0) color: Color) -> @location(0) vec4<f32> {
    #|  return color;
    #|}
    #|
  let unit = parse_wgsl_translation_unit(source)
  guard unit.declarations[0].data is WgslGlobalDeclData::Struct(struct_decl) else {
    abort("expected struct declaration payload")
  }
  debug_inspect(struct_decl.name.name, content="\"Vertex\"")
  debug_inspect(struct_decl.members.length(), content="2")
  debug_inspect(
    struct_decl.members[0].attributes[0].name,
    content="\"location\"",
  )
  debug_inspect(struct_decl.members[0].ty, content="\"vec3<f32>\"")
  guard unit.declarations[1].data is WgslGlobalDeclData::GlobalVariable(global) else {
    abort("expected global var payload")
  }
  debug_inspect(global.attributes.length(), content="2")
  debug_inspect(global.template_list[0], content="\"uniform\"")
  debug_inspect(global.name.name, content="\"globals\"")
  debug_inspect(global.ty, content="Some(\"Globals\")")
  guard unit.declarations[2].data is WgslGlobalDeclData::TypeAlias(alias_decl) else {
    abort("expected type alias payload")
  }
  debug_inspect(alias_decl.name.name, content="\"Color\"")
  debug_inspect(alias_decl.ty, content="\"vec4<f32>\"")
  guard unit.declarations[3].data is WgslGlobalDeclData::Const(const_decl) else {
    abort("expected const payload")
  }
  debug_inspect(const_decl.name.name, content="\"SCALE\"")
  debug_inspect(const_decl.ty, content="Some(\"f32\")")
  guard unit.declarations[4].data is WgslGlobalDeclData::Override(override_decl) else {
    abort("expected override payload")
  }
  debug_inspect(override_decl.attributes[0].name, content="\"id\"")
  debug_inspect(override_decl.name.name, content="\"ENABLED\"")
  guard unit.declarations[5].data is WgslGlobalDeclData::Function(function) else {
    abort("expected function payload")
  }
  debug_inspect(function.attributes[0].name, content="\"fragment\"")
  debug_inspect(function.name.name, content="\"fragment\"")
  debug_inspect(function.arguments[0].name, content="\"color\"")
  debug_inspect(
    function.arguments[0].attributes[0].name,
    content="\"location\"",
  )
  guard function.result is Some(result) else {
    abort("expected function result")
  }
  debug_inspect(result.attributes[0].name, content="\"location\"")
  debug_inspect(result.ty, content="\"vec4<f32>\"")
}
