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
test "strict WGSL translation unit rejects unparsed declarations" {
  let source =
    #|fn broken( -> u32 {
    #|  return 1u;
    #|}
    #|
  let mut failed = false
  ignore(parse_wgsl_translation_unit_strict(source)) catch {
    err => {
      debug_inspect(
        err.message(),
        content="\"WGSL declaration could not be parsed at 0: fn broken( -> u32 {\\n  return 1u;\\n}\"",
      )
      failed = true
    }
  }
  guard failed is true else { abort("expected strict parser failure") }
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
  debug_inspect(function.fn_start, content="224")
  debug_inspect(function.fn_end, content="226")
  debug_inspect(function.qualifier_start, content="None")
  debug_inspect(function.name.name, content="\"fragment\"")
  debug_inspect(function.arguments[0].name, content="\"color\"")
  debug_inspect(function.arguments[0].name_start, content="249")
  debug_inspect(function.arguments[0].name_end, content="254")
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
  debug_inspect(
    function.body.statements[0].expression_refs[0].identifiers[0].name,
    content="\"color\"",
  )
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
  debug_inspect(ty.text, content="\"array<vec4<f32>, 4>\"")
  debug_inspect(ty.arguments.length(), content="2")
  debug_inspect(ty.arguments[0].name, content="\"vec4\"")
  debug_inspect(ty.arguments[0].text, content="\"vec4<f32>\"")
  debug_inspect(ty.arguments[0].arguments[0].name, content="\"f32\"")
  debug_inspect(ty.arguments[1].name, content="\"4\"")
}

///|
test "WGSL type refs preserve template span text with spacing" {
  let source = "alias Values = array < vec4 < f32 > , 4 >;\n"
  let unit = parse_wgsl_translation_unit(source)
  guard unit.declarations[0].data is WgslGlobalDeclData::TypeAlias(alias_decl) else {
    abort("expected type alias payload")
  }
  guard alias_decl.ty_ref is Some(ty) else { abort("expected alias type ref") }
  debug_inspect(ty.text, content="\"array < vec4 < f32 > , 4 >\"")
  debug_inspect(ty.arguments[0].text, content="\"vec4 < f32 >\"")
  debug_inspect(ty.arguments[0].arguments[0].text, content="\"f32\"")
  debug_inspect(ty.arguments[1].text, content="\"4\"")
}

///|
test "WGSL type refs accept Pattern_White_Space blankspace" {
  let source = "alias Values = array\u{000C}<vec4\u{200E}<f32>\u{2029}, 4>;\n"
  let unit = parse_wgsl_translation_unit(source)
  guard unit.declarations[0].data is WgslGlobalDeclData::TypeAlias(alias_decl) else {
    abort("expected type alias payload")
  }
  guard alias_decl.ty_ref is Some(ty) else { abort("expected alias type ref") }
  debug_inspect(ty.name, content="\"array\"")
  debug_inspect(ty.arguments[0].name, content="\"vec4\"")
  debug_inspect(ty.arguments[0].arguments[0].name, content="\"f32\"")
  debug_inspect(ty.arguments[1].name, content="\"4\"")
}

///|
test "WGSL variable template lists are parsed by grammar" {
  let source =
    #|@group(0) @binding(0) var<storage, read_write> values: array<vec4<f32>, 4>;
    #|@group(0) @binding(1) var<texture_storage_2d<rgba8unorm>, write> image: texture_storage_2d<rgba8unorm, write>;
    #|
  let unit = parse_wgsl_translation_unit(source)
  guard unit.declarations[0].data is WgslGlobalDeclData::GlobalVariable(values) else {
    abort("expected values global")
  }
  debug_inspect(values.template_list.length(), content="2")
  debug_inspect(values.template_list[0], content="\"storage\"")
  debug_inspect(values.template_list[1], content="\"read_write\"")
  guard unit.declarations[1].data is WgslGlobalDeclData::GlobalVariable(image) else {
    abort("expected image global")
  }
  debug_inspect(image.template_list.length(), content="2")
  debug_inspect(
    image.template_list[0],
    content="\"texture_storage_2d<rgba8unorm>\"",
  )
  debug_inspect(image.template_list[1], content="\"write\"")
}

///|
test "WGSL function arguments are parsed by grammar" {
  let source =
    #|fn shade(
    #|  @location(0) color: vec4<f32>,
    #|  values: array<vec4<f32>, 4>,
    #|) -> f32 { return values[0].x; }
    #|
  let unit = parse_wgsl_translation_unit(source)
  guard unit.declarations[0].data is WgslGlobalDeclData::Function(function) else {
    abort("expected function payload")
  }
  debug_inspect(function.arguments.length(), content="2")
  debug_inspect(
    function.arguments[0].attributes[0].name,
    content="\"location\"",
  )
  debug_inspect(function.arguments[0].name, content="\"color\"")
  guard function.arguments[0].ty_ref is Some(color_ty) else {
    abort("expected color type")
  }
  debug_inspect(color_ty.text, content="\"vec4<f32>\"")
  debug_inspect(function.arguments[1].name, content="\"values\"")
  guard function.arguments[1].ty_ref is Some(values_ty) else {
    abort("expected values type")
  }
  debug_inspect(values_ty.arguments.length(), content="2")
  debug_inspect(values_ty.arguments[0].text, content="\"vec4<f32>\"")
  debug_inspect(values_ty.arguments[1].text, content="\"4\"")
}

///|
test "WGSL struct members are parsed by grammar" {
  let source =
    #|struct Storage {
    #|  @location(0) color: vec4<f32>;
    #|  values: array<vec4<f32>, 4>;
    #|}
    #|
  let unit = parse_wgsl_translation_unit(source)
  guard unit.declarations[0].data is WgslGlobalDeclData::Struct(struct_decl) else {
    abort("expected struct payload")
  }
  debug_inspect(struct_decl.members.length(), content="2")
  debug_inspect(
    struct_decl.members[0].attributes[0].name,
    content="\"location\"",
  )
  debug_inspect(struct_decl.members[0].name, content="\"color\"")
  guard struct_decl.members[0].ty_ref is Some(color_ty) else {
    abort("expected color type")
  }
  debug_inspect(color_ty.text, content="\"vec4<f32>\"")
  debug_inspect(struct_decl.members[1].name, content="\"values\"")
  guard struct_decl.members[1].ty_ref is Some(values_ty) else {
    abort("expected values type")
  }
  debug_inspect(values_ty.arguments[0].text, content="\"vec4<f32>\"")
  debug_inspect(values_ty.arguments[1].text, content="\"4\"")
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
test "WGSL AST records spans for attributes members and signatures" {
  let source =
    #|struct Vertex {
    #|  @location(0) position: vec3<f32>,
    #|}
    #|@fragment fn fragment(@location(0) color: Color) -> @location(0) vec4<f32> {
    #|  return color;
    #|}
    #|
  let unit = parse_wgsl_translation_unit(source)
  guard unit.declarations[0].data is WgslGlobalDeclData::Struct(struct_decl) else {
    abort("expected struct")
  }
  let field = struct_decl.members[0]
  let field_attr = field.attributes[0]
  debug_inspect(
    source[field_attr.start:field_attr.end].to_owned(),
    content="\"@location(0)\"",
  )
  debug_inspect(
    source[field.start:field.end].to_owned(),
    content="\"@location(0) position: vec3<f32>\"",
  )
  guard unit.declarations[1].data is WgslGlobalDeclData::Function(function) else {
    abort("expected function")
  }
  debug_inspect(
    source[function.body.start:function.body.end].to_owned(),
    content="\"{\\n  return color;\\n}\"",
  )
  let fn_attr = function.attributes[0]
  debug_inspect(
    source[fn_attr.start:fn_attr.end].to_owned(),
    content="\"@fragment\"",
  )
  let arg = function.arguments[0]
  debug_inspect(
    source[arg.start:arg.end].to_owned(),
    content="\"@location(0) color: Color\"",
  )
  guard function.result is Some(result) else { abort("expected result") }
  debug_inspect(
    source[result.start:result.end].to_owned(),
    content="\"-> @location(0) vec4<f32>\"",
  )
}

///|
test "WGSL attributes are parsed by grammar" {
  let source =
    #|const WIDTH: u32 = 4u;
    #|@workgroup_size(WIDTH, max(1u, WIDTH - 1u), 1) @compute fn main() {
    #|}
    #|
  let unit = parse_wgsl_translation_unit(source)
  guard unit.declarations[1].data is WgslGlobalDeclData::Function(function) else {
    abort("expected function")
  }
  debug_inspect(function.attributes.length(), content="2")
  debug_inspect(function.attributes[0].name, content="\"workgroup_size\"")
  debug_inspect(
    function.attributes[0].arguments,
    content="\"WIDTH, max(1u, WIDTH - 1u), 1\"",
  )
  guard function.attributes[0].arguments_ref is Some(arguments) else {
    abort("expected attribute arguments ref")
  }
  debug_inspect(arguments.identifiers[0].name, content="\"WIDTH\"")
  debug_inspect(arguments.identifiers[1].name, content="\"max\"")
  debug_inspect(arguments.identifiers[2].name, content="\"WIDTH\"")
  debug_inspect(function.attributes[1].name, content="\"compute\"")
  debug_inspect(function.attributes[1].arguments, content="\"\"")
}

///|
test "WGSL expression refs expose token and literal AST" {
  let source =
    #|@group(0u) @binding(12) @id(true) override FLAG: bool = false;
    #|
  let unit = parse_wgsl_translation_unit(source)
  guard unit.declarations[0].data is WgslGlobalDeclData::Override(override_decl) else {
    abort("expected override")
  }
  guard override_decl.attributes[0].arguments_ref is Some(group_args) else {
    abort("expected group args")
  }
  debug_inspect(group_args.tokens[0].kind, content="UintLiteral(0)")
  guard override_decl.attributes[1].arguments_ref is Some(binding_args) else {
    abort("expected binding args")
  }
  debug_inspect(binding_args.tokens[0].kind, content="UintLiteral(12)")
  guard override_decl.attributes[2].arguments_ref is Some(id_args) else {
    abort("expected id args")
  }
  debug_inspect(id_args.tokens[0].kind, content="BoolLiteral(true)")
  guard override_decl.initializer_ref is Some(initializer) else {
    abort("expected initializer")
  }
  debug_inspect(initializer.tokens[0].kind, content="BoolLiteral(false)")
}

///|
test "WGSL typed initializer tails are parsed by grammar" {
  let source =
    #|var<private> cache: u32 = FACTOR;
    #|const INFERRED = cache + 1u;
    #|@id(1) override FLAG = ENABLED_FLAG;
    #|
  let unit = parse_wgsl_translation_unit(source)
  guard unit.declarations[0].data is WgslGlobalDeclData::GlobalVariable(global) else {
    abort("expected global variable")
  }
  debug_inspect(global.ty, content="Some(\"u32\")")
  guard global.ty_ref is Some(global_ty) else { abort("expected global type") }
  debug_inspect(global_ty.name, content="\"u32\"")
  debug_inspect(global.initializer, content="Some(\"FACTOR\")")
  guard global.initializer_ref is Some(global_initializer) else {
    abort("expected global initializer")
  }
  debug_inspect(global_initializer.identifiers[0].name, content="\"FACTOR\"")
  guard unit.declarations[1].data is WgslGlobalDeclData::Const(const_decl) else {
    abort("expected const")
  }
  debug_inspect(const_decl.ty, content="None")
  debug_inspect(const_decl.initializer, content="Some(\"cache + 1u\")")
  guard const_decl.initializer_ref is Some(const_initializer) else {
    abort("expected const initializer")
  }
  debug_inspect(const_initializer.identifiers[0].name, content="\"cache\"")
  guard unit.declarations[2].data is WgslGlobalDeclData::Override(override_decl) else {
    abort("expected override")
  }
  debug_inspect(override_decl.ty, content="None")
  debug_inspect(override_decl.initializer, content="Some(\"ENABLED_FLAG\")")
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
    @ast.collect_wgsl_decl_identifier_nodes(decl.data, nodes)
  }
  debug_inspect(nodes[0].name, content="\"vec4\"")
  debug_inspect(nodes[0].start, content="14")
  debug_inspect(nodes[1].name, content="\"f32\"")
  debug_inspect(nodes[2].name, content="\"mod::inner\"")
  debug_inspect(nodes[3].name, content="\"Alias\"")
  debug_inspect(nodes[4].name, content="\"Alias\"")
  debug_inspect(nodes.length(), content="5")
}

///|
test "WGSL function payload exposes source-preserving statement AST" {
  let source =
    #|fn demo(value: u32) -> u32 {
    #|  var<function> local: u32 = value;
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
  debug_inspect(function.body.statements[0].kind, content="LocalDeclaration")
  debug_inspect(function.body.statements[1].kind, content="If")
  debug_inspect(function.body.statements[2].kind, content="Return")
  debug_inspect(
    function.body.statements[0].text.trim().to_owned(),
    content="\"var<function> local: u32 = value;\"",
  )
  debug_inspect(
    function.body.statements[1].text.contains("return local"),
    content="true",
  )
  debug_inspect(
    function.body.statements[2].text.trim().to_owned(),
    content="\"return 0u;\"",
  )
  debug_inspect(
    function.body.statements[0].exported_local_bindings.map(fn(binding) {
      binding.name.name
    }),
    content=(
      #|["local"]
    ),
  )
  debug_inspect(
    function.body.statements[0].local_bindings.length(),
    content="1",
  )
  debug_inspect(
    function.body.statements[0].local_bindings[0].kind,
    content="\"var\"",
  )
  debug_inspect(
    function.body.statements[0].local_bindings[0].name.name,
    content="\"local\"",
  )
  debug_inspect(
    function.body.statements[0].local_bindings[0].template_list,
    content=(
      #|["function"]
    ),
  )
  debug_inspect(
    function.body.statements[0].local_bindings[0].ty,
    content="Some(\"u32\")",
  )
  guard function.body.statements[0].local_bindings[0].ty_ref is Some(local_ty) else {
    abort("expected local type ref")
  }
  debug_inspect(local_ty.name, content="\"u32\"")
  guard function.body.statements[0].local_bindings[0].initializer_ref
    is Some(local_init) else {
    abort("expected local initializer ref")
  }
  debug_inspect(
    local_init.identifiers.map(fn(node) { node.name }),
    content=(
      #|["value"]
    ),
  )
  debug_inspect(function.body.statements[0].expression_refs, content="[]")
  debug_inspect(
    function.body.statements[1].exported_local_bindings,
    content="[]",
  )
  debug_inspect(
    function.body.statements[2].exported_local_bindings,
    content="[]",
  )
  debug_inspect(
    function.body.statements[2].expression_refs[0].identifiers.map(fn(node) {
      node.name
    }),
    content="[]",
  )
}

///|
test "WGSL statement expression refs skip local declarations and member access" {
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
    function.body.statements[0].exported_local_bindings.map(fn(binding) {
      binding.name.name
    }),
    content=(
      #|["local"]
    ),
  )
  guard function.body.statements[0].local_bindings[0].initializer_ref
    is Some(local_init) else {
    abort("expected local initializer ref")
  }
  debug_inspect(
    local_init.identifiers.map(fn(node) { node.name }),
    content=(
      #|["input"]
    ),
  )
  debug_inspect(
    function.body.statements[1].expression_refs[0].identifiers.map(fn(node) {
      node.name
    }),
    content=(
      #|["local", "input"]
    ),
  )
}

///|
test "WGSL global declaration identifier collection excludes locals" {
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
    @ast.collect_wgsl_decl_global_declared_identifier_nodes(decl.data, nodes)
  }
  debug_inspect(
    nodes.map(fn(node) { node.name }),
    content=(
      #|["Alias", "Vertex", "make_vertex"]
    ),
  )
}

///|
test "WGSL declaration identifier collection excludes function locals" {
  let source =
    #|struct GlobalValue {
    #|  value: u32,
    #|}
    #|fn demo(GlobalValue: u32) -> u32 {
    #|  let local = GlobalValue;
    #|  return local;
    #|}
    #|
  let unit = parse_wgsl_translation_unit(source)
  guard unit.declarations[1].data is WgslGlobalDeclData::Function(function) else {
    abort("expected function payload")
  }
  let nodes : Array[WgslIdent] = []
  @ast.collect_wgsl_decl_identifier_nodes(
    WgslGlobalDeclData::Function(function),
    nodes,
  )
  debug_inspect(
    nodes.map(fn(node) { node.name }),
    content=(
      #|["u32", "u32"]
    ),
  )
}

///|
test "WGSL statement AST records nested and loop local declarations" {
  let source =
    #|fn demo(arg: u32) -> u32 {
    #|  if (arg > 0u) {
    #|    let nested = arg;
    #|    return nested;
    #|  }
    #|  for (var i: u32 = 0u; i < arg; i = i + 1u) {
    #|    continue;
    #|  }
    #|  return arg;
    #|}
    #|
  let unit = parse_wgsl_translation_unit(source)
  guard unit.declarations[0].data is WgslGlobalDeclData::Function(function) else {
    abort("expected function payload")
  }
  debug_inspect(function.body.statements[0].kind, content="If")
  debug_inspect(function.body.statements[1].kind, content="For")
  debug_inspect(function.body.statements[2].kind, content="Return")
  debug_inspect(function.body.statements[0].blocks.length(), content="1")
  debug_inspect(
    function.body.statements[0].blocks[0].statements.map(fn(statement) {
      statement.kind
    }),
    content=(
      #|[LocalDeclaration, Return]
    ),
  )
  debug_inspect(function.body.statements[1].blocks.length(), content="1")
  debug_inspect(
    function.body.statements[1].blocks[0].statements[0].kind,
    content="Continue",
  )
  debug_inspect(
    function.body.statements[0].local_bindings.map(fn(binding) {
      binding.name.name
    }),
    content="[]",
  )
  debug_inspect(
    function.body.statements[0].blocks[0].statements[0].local_bindings.map(fn(
      binding,
    ) {
      binding.name.name
    }),
    content=(
      #|["nested"]
    ),
  )
  debug_inspect(
    function.body.statements[0].expression_refs[0].identifiers.map(fn(node) {
      node.name
    }),
    content=(
      #|["arg"]
    ),
  )
  debug_inspect(
    function.body.statements[0].exported_local_bindings,
    content="[]",
  )
  debug_inspect(
    function.body.statements[1].local_bindings.map(fn(binding) {
      binding.name.name
    }),
    content=(
      #|["i"]
    ),
  )
  debug_inspect(
    function.body.statements[1].local_bindings.length(),
    content="1",
  )
  debug_inspect(
    function.body.statements[1].local_bindings[0].name.name,
    content="\"i\"",
  )
  debug_inspect(
    function.body.statements[1].local_bindings[0].ty,
    content="Some(\"u32\")",
  )
  debug_inspect(
    function.body.statements[1].expression_refs.map(fn(expr) { expr.text }),
    content=(
      #|["i < arg", "i = i + 1u"]
    ),
  )
  debug_inspect(
    function.body.statements[1].expression_refs[0].identifiers.map(fn(node) {
      node.name
    }),
    content=(
      #|["i", "arg"]
    ),
  )
  debug_inspect(
    function.body.statements[1].exported_local_bindings,
    content="[]",
  )
  let nodes : Array[WgslIdent] = []
  @ast.collect_wgsl_decl_identifier_nodes(
    WgslGlobalDeclData::Function(function),
    nodes,
  )
  debug_inspect(
    nodes.map(fn(node) { node.name }),
    content=(
      #|["u32", "u32", "u32"]
    ),
  )
}

///|
test "WGSL statement AST parses multiple branch blocks structurally" {
  let source =
    #|fn demo(arg: u32) -> u32 {
    #|  if (arg > 0u) {
    #|    return 1u;
    #|  } else {
    #|    return 0u;
    #|  }
    #|}
    #|
  let unit = parse_wgsl_translation_unit(source)
  guard unit.declarations[0].data is WgslGlobalDeclData::Function(function) else {
    abort("expected function")
  }
  let statement = function.body.statements[0]
  debug_inspect(statement.kind, content="If")
  debug_inspect(statement.blocks.length(), content="2")
  debug_inspect(
    statement.expression_refs[0].identifiers.map(fn(node) { node.name }),
    content=(
      #|["arg"]
    ),
  )
  debug_inspect(
    statement.expression_refs.map(fn(expr) { expr.text }),
    content=(
      #|["arg > 0u"]
    ),
  )
  debug_inspect(statement.blocks[0].statements[0].kind, content="Return")
  debug_inspect(
    statement.blocks[0].statements[0].expression_refs.map(fn(expr) { expr.text }),
    content=(
      #|["1u"]
    ),
  )
  debug_inspect(statement.blocks[1].statements[0].kind, content="Return")
  debug_inspect(
    source[statement.blocks[1].start:statement.blocks[1].end].to_owned(),
    content="\"{\\n    return 0u;\\n  }\"",
  )
}

///|
test "WGSL source directives parse as directive AST nodes" {
  let source =
    #|enable f16, subgroups;
    #|requires readonly_and_readwrite_storage_textures;
    #|diagnostic(warn, derivative_uniformity);
    #|fn shade() -> f32 { return 1.0; }
    #|
  let unit = parse_wgsl_translation_unit(source)
  debug_inspect(unit.declarations[0].kind, content="Directive")
  debug_inspect(unit.declarations[1].kind, content="Directive")
  debug_inspect(unit.declarations[2].kind, content="Directive")
  guard unit.declarations[0].data is WgslGlobalDeclData::Directive(enable) else {
    abort("expected enable directive")
  }
  debug_inspect(enable.kind, content="Enable")
  debug_inspect(enable.tail, content="\"f16, subgroups\"")
  debug_inspect(enable.start, content="0")
  debug_inspect(enable.end, content="22")
  debug_inspect(enable.name_start, content="0")
  debug_inspect(enable.name_end, content="6")
  debug_inspect(enable.tail_start, content="7")
  debug_inspect(enable.tail_end, content="21")
  guard unit.declarations[2].data is WgslGlobalDeclData::Directive(diagnostic) else {
    abort("expected diagnostic directive")
  }
  debug_inspect(diagnostic.kind, content="Diagnostic")
  debug_inspect(diagnostic.tail, content="\"(warn, derivative_uniformity)\"")
}

///|
test "WGSL hash conditionals parse as directive AST nodes" {
  let source =
    #|#ifdef ENABLED
    #|const A: u32 = 1u;
    #|#endif
    #|
  let unit = parse_wgsl_translation_unit(source)
  debug_inspect(unit.declarations[0].kind, content="Directive")
  guard unit.declarations[0].data is WgslGlobalDeclData::Directive(ifdef) else {
    abort("expected ifdef directive")
  }
  debug_inspect(ifdef.kind, content="Ifdef")
  debug_inspect(ifdef.tail, content="\"ENABLED\"")
  debug_inspect(ifdef.start, content="0")
  debug_inspect(ifdef.end, content="14")
  debug_inspect(ifdef.name_start, content="1")
  debug_inspect(ifdef.name_end, content="6")
  debug_inspect(ifdef.tail_start, content="7")
  debug_inspect(ifdef.tail_end, content="14")
  debug_inspect(unit.declarations[1].kind, content="Const")
  debug_inspect(unit.declarations[2].kind, content="Directive")
}

///|
test "WGSL hash directive spans are absolute in translation units" {
  let source =
    #|// lead
    #|#ifdef ENABLED
    #|#endif
    #|
  let unit = parse_wgsl_translation_unit(source)
  debug_inspect(unit.declarations[0].kind, content="Trivia")
  guard unit.declarations[1].data is WgslGlobalDeclData::Directive(ifdef) else {
    abort("expected ifdef directive")
  }
  debug_inspect(ifdef.start, content="8")
  debug_inspect(ifdef.end, content="22")
  debug_inspect(ifdef.name_start, content="9")
  debug_inspect(ifdef.name_end, content="14")
  debug_inspect(ifdef.tail_start, content="15")
  debug_inspect(ifdef.tail_end, content="22")
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
      #|    start: 33,
      #|    end: 39,
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
  debug_inspect(function.body.statements.length(), content="2")
  debug_inspect(
    function.body.statements[1].exported_local_bindings,
    content="[]",
  )
}
