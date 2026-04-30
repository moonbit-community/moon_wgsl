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
  guard unit.declarations[0].data
    is WgslGlobalDeclData::Directive(module_directive) else {
    abort("expected directive payload")
  }
  debug_inspect(module_directive.kind, content="DefineImportPath")
  guard unit.declarations[1].data
    is WgslGlobalDeclData::Import(import_directive) else {
    abort("expected import payload")
  }
  debug_inspect(import_directive.kind, content="Import")
  debug_inspect(unit.declarations[2].kind, content="Struct")
  debug_inspect(unit.declarations[3].kind, content="GlobalVariable")
  debug_inspect(unit.declarations[4].kind, content="ConstAssert")
  guard unit.declarations[4].data
    is WgslGlobalDeclData::ConstAssert(assert_expr) else {
    abort("expected const assert payload")
  }
  debug_inspect(assert_expr.text, content="\"(1 == 1)\"")
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
  debug_inspect(struct_decl.members[0].name_start, content="31")
  debug_inspect(struct_decl.members[0].name_end, content="39")
  debug_inspect(struct_decl.members[0].ty, content="\"vec3<f32>\"")
  guard struct_decl.members[0].ty_ref is Some(position_ty) else {
    abort("expected struct member type ref")
  }
  debug_inspect(position_ty.name, content="\"vec3\"")
  debug_inspect(position_ty.arguments.length(), content="1")
  debug_inspect(position_ty.arguments[0].name, content="\"f32\"")
  guard unit.declarations[1].data is WgslGlobalDeclData::GlobalVariable(global) else {
    abort("expected global var payload")
  }
  debug_inspect(global.attributes.length(), content="2")
  debug_inspect(global.template_list[0], content="\"uniform\"")
  debug_inspect(global.name.name, content="\"globals\"")
  debug_inspect(global.ty, content="Some(\"Globals\")")
  guard global.ty_ref is Some(global_ty) else {
    abort("expected global type ref")
  }
  debug_inspect(global_ty.name, content="\"Globals\"")
  debug_inspect(global.initializer, content="None")
  guard unit.declarations[2].data is WgslGlobalDeclData::TypeAlias(alias_decl) else {
    abort("expected type alias payload")
  }
  debug_inspect(alias_decl.name.name, content="\"Color\"")
  debug_inspect(alias_decl.ty, content="\"vec4<f32>\"")
  guard alias_decl.ty_ref is Some(alias_ty) else {
    abort("expected alias type ref")
  }
  debug_inspect(alias_ty.name, content="\"vec4\"")
  debug_inspect(alias_ty.arguments[0].name, content="\"f32\"")
  guard unit.declarations[3].data is WgslGlobalDeclData::Const(const_decl) else {
    abort("expected const payload")
  }
  debug_inspect(const_decl.name.name, content="\"SCALE\"")
  debug_inspect(const_decl.ty, content="Some(\"f32\")")
  guard const_decl.ty_ref is Some(const_ty) else {
    abort("expected const type ref")
  }
  debug_inspect(const_ty.name, content="\"f32\"")
  debug_inspect(const_decl.initializer, content="Some(\"2.0\")")
  guard unit.declarations[4].data is WgslGlobalDeclData::Override(override_decl) else {
    abort("expected override payload")
  }
  debug_inspect(override_decl.attributes[0].name, content="\"id\"")
  debug_inspect(override_decl.name.name, content="\"ENABLED\"")
  guard override_decl.ty_ref is Some(override_ty) else {
    abort("expected override type ref")
  }
  debug_inspect(override_ty.name, content="\"bool\"")
  debug_inspect(override_decl.initializer, content="Some(\"true\")")
  guard unit.declarations[5].data is WgslGlobalDeclData::Function(function) else {
    abort("expected function payload")
  }
  debug_inspect(function.attributes[0].name, content="\"fragment\"")
  debug_inspect(function.fn_start, content="10")
  debug_inspect(function.fn_end, content="12")
  debug_inspect(function.qualifier_start, content="None")
  debug_inspect(function.name.name, content="\"fragment\"")
  debug_inspect(function.arguments[0].name, content="\"color\"")
  debug_inspect(function.arguments[0].name_start, content="35")
  debug_inspect(function.arguments[0].name_end, content="40")
  guard function.arguments[0].ty_ref is Some(arg_ty) else {
    abort("expected argument type ref")
  }
  debug_inspect(arg_ty.name, content="\"Color\"")
  debug_inspect(
    function.arguments[0].attributes[0].name,
    content="\"location\"",
  )
  guard function.result is Some(result) else {
    abort("expected function result")
  }
  debug_inspect(result.attributes[0].name, content="\"location\"")
  debug_inspect(result.ty, content="\"vec4<f32>\"")
  guard result.ty_ref is Some(result_ty) else {
    abort("expected result type ref")
  }
  debug_inspect(result_ty.name, content="\"vec4\"")
  debug_inspect(result_ty.arguments[0].name, content="\"f32\"")
  debug_inspect(function.body.statements.length(), content="1")
  debug_inspect(function.body.statements[0].kind, content="Return")
}

///|
test "WGSL type refs expose nested template arguments" {
  let source = "alias Values = array<vec4<f32>, 4>;\n"
  let unit = parse_wgsl_translation_unit(source)
  guard unit.declarations[0].data is WgslGlobalDeclData::TypeAlias(alias_decl) else {
    abort("expected type alias payload")
  }
  guard alias_decl.ty_ref is Some(ty) else { abort("expected alias type ref") }
  debug_inspect(ty.name, content="\"array\"")
  debug_inspect(ty.arguments.length(), content="2")
  debug_inspect(ty.arguments[0].name, content="\"vec4\"")
  debug_inspect(ty.arguments[0].arguments[0].name, content="\"f32\"")
  debug_inspect(ty.arguments[1].name, content="\"4\"")
}

///|
test "WGSL expression refs expose attribute and initializer identifiers" {
  let source =
    #|const BASE: u32 = 1u;
    #|const FACTOR: u32 = BASE + 1u;
    #|@id(FACTOR) override VALUE: bool = ENABLED_FLAG;
    #|
  let unit = parse_wgsl_translation_unit(source)
  guard unit.declarations[1].data is WgslGlobalDeclData::Const(const_decl) else {
    abort("expected const payload")
  }
  guard const_decl.initializer_ref is Some(const_initializer) else {
    abort("expected const initializer ref")
  }
  debug_inspect(const_initializer.identifiers[0].name, content="\"BASE\"")
  guard unit.declarations[2].data is WgslGlobalDeclData::Override(override_decl) else {
    abort("expected override payload")
  }
  guard override_decl.attributes[0].arguments_ref is Some(attr_args) else {
    abort("expected attribute arguments ref")
  }
  debug_inspect(attr_args.identifiers[0].name, content="\"FACTOR\"")
  guard override_decl.initializer_ref is Some(override_initializer) else {
    abort("expected override initializer ref")
  }
  debug_inspect(
    override_initializer.identifiers[0].name,
    content="\"ENABLED_FLAG\"",
  )
}

///|
test "WGSL identifier collection exposes source spans" {
  let source =
    #|alias Alias = vec4<f32>;
    #|override fn mod::inner(value: Alias) -> Alias {
    #|  return value;
    #|}
    #|
  let unit = parse_wgsl_translation_unit(source)
  let nodes : Array[WgslIdent] = []
  for decl in unit.declarations {
    collect_wgsl_decl_identifier_nodes(decl.data, nodes)
  }
  debug_inspect(nodes[0].name, content="\"vec4\"")
  debug_inspect(nodes[0].start, content="14")
  debug_inspect(nodes[1].name, content="\"f32\"")
  debug_inspect(nodes[2].name, content="\"mod::inner\"")
  debug_inspect(nodes[3].name, content="\"Alias\"")
  debug_inspect(nodes[4].name, content="\"Alias\"")
  debug_inspect(nodes[5].name, content="\"return\"")
  debug_inspect(nodes[6].name, content="\"value\"")
}

///|
test "WGSL function payload exposes source-preserving statement AST" {
  let source =
    #|fn demo(value: u32) -> u32 {
    #|  var local: u32 = value;
    #|  if (local > 0u) {
    #|    return local;
    #|  }
    #|  return 0u;
    #|}
    #|
  let unit = parse_wgsl_translation_unit(source)
  guard unit.declarations[0].data is WgslGlobalDeclData::Function(function) else {
    abort("expected function payload")
  }
  debug_inspect(function.body.statements.length(), content="3")
  debug_inspect(function.body.statements[0].kind, content="LocalDecl")
  debug_inspect(
    function.body.statements[0].local_name,
    content="Some(\"local\")",
  )
  debug_inspect(function.body.statements[0].start, content="31")
  debug_inspect(function.body.statements[0].end, content="54")
  debug_inspect(
    function.body.statements[0].identifiers[0].name,
    content="\"var\"",
  )
  debug_inspect(
    function.body.statements[0].identifiers[1].name,
    content="\"u32\"",
  )
  debug_inspect(function.body.statements[1].kind, content="If")
  debug_inspect(function.body.statements[2].kind, content="Return")
  debug_inspect(
    function.body.statements[2].identifiers[0].name,
    content="\"return\"",
  )
  debug_inspect(
    function.body.statements[1].text.contains("return local;"),
    content="true",
  )
}

///|
test "WGSL statement identifiers skip local declarations and member access" {
  let source =
    #|fn demo(input: Vertex) -> f32 {
    #|  let local = input.position.x;
    #|  return local + input.color.r;
    #|}
    #|
  let unit = parse_wgsl_translation_unit(source)
  guard unit.declarations[0].data is WgslGlobalDeclData::Function(function) else {
    abort("expected function payload")
  }
  debug_inspect(
    function.body.statements[0].local_name,
    content="Some(\"local\")",
  )
  debug_inspect(
    function.body.statements[0].identifiers.map(fn(node) { node.name }),
    content=(
      #|["let", "input"]
    ),
  )
  debug_inspect(
    function.body.statements[1].identifiers.map(fn(node) { node.name }),
    content=(
      #|["return", "local", "input"]
    ),
  )
}

///|
test "WGSL declaration identifier collection exposes declared names" {
  let source =
    #|alias Alias = vec4<f32>;
    #|struct Vertex { value: Alias }
    #|fn make_vertex(input: Alias) -> Vertex {
    #|  return Vertex(input);
    #|}
    #|
  let unit = parse_wgsl_translation_unit(source)
  let nodes : Array[WgslIdent] = []
  for decl in unit.declarations {
    collect_wgsl_decl_declared_identifier_nodes(decl.data, nodes)
  }
  debug_inspect(
    nodes.map(fn(node) { node.name }),
    content=(
      #|["Alias", "Vertex", "make_vertex", "input"]
    ),
  )
}

///|
test "WGSL override function payload preserves qualified target path" {
  let source =
    #|override fn mod::inner(arg: f32) -> f32 {
    #|  return inner(arg);
    #|}
    #|
  let unit = parse_wgsl_translation_unit(source)
  guard unit.declarations[0].data is WgslGlobalDeclData::Function(function) else {
    abort("expected function payload")
  }
  debug_inspect(function.qualifier, content="\"override\"")
  debug_inspect(function.qualifier_start, content="Some(0)")
  debug_inspect(function.qualifier_end, content="Some(8)")
  debug_inspect(function.fn_start, content="9")
  debug_inspect(function.fn_end, content="11")
  debug_inspect(function.name.name, content="\"mod::inner\"")
  debug_inspect(function.name.start, content="12")
  debug_inspect(function.name.end, content="22")
  debug_inspect(function.arguments[0].name, content="\"arg\"")
  debug_inspect(
    function.result,
    content=(
      #|Some(
      #|  {
      #|    attributes: [],
      #|    ty: "f32",
      #|    ty_ref: Some({ name: "f32", arguments: [], text: "f32", start: 36, end: 39 }),
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
  let unit = parse_wgsl_translation_unit(source)
  guard unit.declarations[0].data is WgslGlobalDeclData::Function(function) else {
    abort("expected function payload")
  }
  debug_inspect(function.body.statements[0].kind, content="ConstAssert")
  debug_inspect(function.body.statements[1].kind, content="Raw")
  debug_inspect(function.body.statements[1].local_name, content="None")
}
