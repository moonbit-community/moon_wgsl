///|
fn parse_wgsl_translation_unit_for_test(source : String) -> WgslTranslationUnit {
  parse_wgsl_translation_unit_strict(source) catch {
    error => abort(error.message())
  }
}

///|
fn wgsl_expr_ref_source_text(source : String, expr : WgslExprRef) -> String {
  source[expr.start():expr.end()].to_owned()
}

///|
fn wgsl_case_selector_snapshot(
  source : String,
  selector : WgslCaseSelector,
) -> String {
  match selector {
    DefaultSelector => "default"
    ExpressionSelector(expr) => wgsl_expr_ref_source_text(source, expr)
  }
}

///|
test "WGSL translation unit classifies top-level declarations" {
  let source =
    #|#define_import_path demo::module
    #|;
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
  let unit = parse_wgsl_translation_unit_for_test(source)
  debug_inspect(unit.declarations().length(), content="7")
  debug_inspect(unit.declarations()[0].kind(), content="Directive")
  debug_inspect(unit.declarations()[1].kind(), content="Trivia")
  debug_inspect(unit.declarations()[2].kind(), content="Import")
  guard unit.declarations()[0].data()
    is WgslGlobalDeclData::Directive(module_directive) else {
    abort("expected directive payload")
  }
  debug_inspect(module_directive.kind(), content="DefineImportPath")
  guard unit.declarations()[2].data()
    is WgslGlobalDeclData::Import(import_directive) else {
    abort("expected import payload")
  }
  debug_inspect(import_directive.kind(), content="Import")
  debug_inspect(unit.declarations()[3].kind(), content="Struct")
  debug_inspect(unit.declarations()[4].kind(), content="GlobalVariable")
  debug_inspect(unit.declarations()[5].kind(), content="ConstAssert")
  guard unit.declarations()[5].data()
    is WgslGlobalDeclData::ConstAssert(assert_expr) else {
    abort("expected const assert payload")
  }
  debug_inspect(
    wgsl_expr_ref_source_text(source, assert_expr),
    content="\"(1 == 1)\"",
  )
  debug_inspect(unit.declarations()[6].kind(), content="Function")
  debug_inspect(unit.declarations()[6].name(), content="\"fragment\"")
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
test "strict WGSL translation unit rejects malformed typed initializer tails" {
  let sources = [
    (
      #|const VALUE: = 1u;
    ),
    (
      #|@group(0) @binding(0) var<uniform> globals: ;
    ),
    (
      #|override FLAG: bool = ;
    ),
    (
      #|const_assert;
    ),
  ]
  for source in sources {
    let mut failed = false
    ignore(parse_wgsl_translation_unit_strict(source)) catch {
      _ => failed = true
    }
    guard failed is true else {
      abort("expected strict parser failure for \{source}")
    }
  }
}

///|
test "strict WGSL translation unit rejects invalid numeric literals" {
  let sources = ["const A = 1foo;\n", "const A = 0x;\n", "const A = 1e+;\n"]
  for source in sources {
    let mut failed = false
    ignore(parse_wgsl_translation_unit_strict(source)) catch {
      _ => failed = true
    }
    guard failed is true else {
      abort(
        "expected invalid numeric literal to fail strict parsing: \{source}",
      )
    }
  }
}

///|
test "strict WGSL translation unit rejects semicolonless simple statements" {
  let sources = [
    (
      #|fn assignment_missing_semicolon() {
      #|  var z = 0.0;
      #|  z = 1.0
      #|}
    ),
    (
      #|fn return_missing_semicolon() -> u32 {
      #|  return 1u
      #|}
    ),
    (
      #|fn call_missing_semicolon() {
      #|  workgroupBarrier()
      #|}
    ),
  ]
  for source in sources {
    let mut failed = false
    ignore(parse_wgsl_translation_unit_strict(source)) catch {
      _ => failed = true
    }
    guard failed is true else {
      abort("expected missing statement semicolon to fail: \{source}")
    }
  }
}

///|
test "WGSL numeric literal tokens expose raw descriptor" {
  let source =
    #|const A = 3221225472u;
    #|const B = 0x10i;
    #|const C = 1.0h;
  let unit = parse_wgsl_translation_unit_for_test(source)
  guard unit.declarations()[0].data() is WgslGlobalDeclData::Const(a) else {
    abort("expected const A")
  }
  guard a.initializer_ref() is Some(a_init) else { abort("expected init A") }
  guard a_init.tokens()[0].numeric_literal() is Some(a_literal) else {
    abort("expected numeric descriptor")
  }
  debug_inspect(a_literal.raw_text, content="\"3221225472u\"")
  debug_inspect(a_literal.base, content="Decimal")
  debug_inspect(a_literal.suffix, content="U32Suffix")
  debug_inspect(a_literal.category, content="U32Literal")
  guard unit.declarations()[1].data() is WgslGlobalDeclData::Const(b) else {
    abort("expected const B")
  }
  guard b.initializer_ref() is Some(b_init) else { abort("expected init B") }
  guard b_init.tokens()[0].numeric_literal() is Some(b_literal) else {
    abort("expected numeric descriptor")
  }
  debug_inspect(b_literal.base, content="Hexadecimal")
  debug_inspect(b_literal.suffix, content="I32Suffix")
  debug_inspect(b_literal.category, content="I32Literal")
  guard unit.declarations()[2].data() is WgslGlobalDeclData::Const(c) else {
    abort("expected const C")
  }
  guard c.initializer_ref() is Some(c_init) else { abort("expected init C") }
  guard c_init.tokens()[0].numeric_literal() is Some(c_literal) else {
    abort("expected numeric descriptor")
  }
  debug_inspect(c_literal.suffix, content="F16Suffix")
  debug_inspect(c_literal.category, content="F16Literal")
}

///|
test "strict WGSL translation unit rejects malformed expression tokens" {
  let sources = [
    "const A = @;\n", "const_assert(@);\n", "fn f() { return *; }\n",
  ]
  for source in sources {
    let mut failed = false
    ignore(parse_wgsl_translation_unit_strict(source)) catch {
      _ => failed = true
    }
    guard failed is true else {
      abort("expected malformed expression to fail strict parsing: \{source}")
    }
  }
}

///|
test "strict WGSL translation unit rejects official global const without initializer" {
  let source =
    #|const VALUE: u32;
  let mut failed = false
  ignore(parse_wgsl_translation_unit_strict(source)) catch {
    _ => failed = true
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
  let unit = parse_wgsl_translation_unit_for_test(source)
  guard unit.declarations()[0].data() is WgslGlobalDeclData::Struct(struct_decl) else {
    abort("expected struct declaration payload")
  }
  debug_inspect(struct_decl.name().name(), content="\"Vertex\"")
  debug_inspect(struct_decl.members().length(), content="2")
  debug_inspect(
    struct_decl.members()[0].attributes()[0].name().name(),
    content="\"location\"",
  )
  debug_inspect(struct_decl.members()[0].name().start(), content="31")
  debug_inspect(struct_decl.members()[0].name().end(), content="39")
  guard struct_decl.members()[0].ty_ref() is Some(position_ty) else {
    abort("expected struct member type ref")
  }
  debug_inspect(position_ty.canonical_text(), content="\"vec3<f32>\"")
  debug_inspect(position_ty.name(), content="\"vec3\"")
  debug_inspect(position_ty.arguments().length(), content="1")
  debug_inspect(position_ty.arguments()[0].name(), content="\"f32\"")
  guard unit.declarations()[1].data()
    is WgslGlobalDeclData::GlobalVariable(global) else {
    abort("expected global var payload")
  }
  debug_inspect(global.attributes().length(), content="2")
  debug_inspect(global.template_list()[0].name(), content="\"uniform\"")
  debug_inspect(global.name().name(), content="\"globals\"")
  guard global.ty_ref() is Some(global_ty) else {
    abort("expected global type ref")
  }
  debug_inspect(global_ty.name(), content="\"Globals\"")
  debug_inspect(global.initializer_ref(), content="None")
  guard unit.declarations()[2].data()
    is WgslGlobalDeclData::TypeAlias(alias_decl) else {
    abort("expected type alias payload")
  }
  debug_inspect(alias_decl.name().name(), content="\"Color\"")
  guard alias_decl.ty_ref() is Some(alias_ty) else {
    abort("expected alias type ref")
  }
  debug_inspect(alias_ty.canonical_text(), content="\"vec4<f32>\"")
  debug_inspect(alias_ty.name(), content="\"vec4\"")
  debug_inspect(alias_ty.arguments()[0].name(), content="\"f32\"")
  guard unit.declarations()[3].data() is WgslGlobalDeclData::Const(const_decl) else {
    abort("expected const payload")
  }
  debug_inspect(const_decl.name().name(), content="\"SCALE\"")
  guard const_decl.ty_ref() is Some(const_ty) else {
    abort("expected const type ref")
  }
  debug_inspect(const_ty.name(), content="\"f32\"")
  guard const_decl.initializer_ref() is Some(const_initializer) else {
    abort("expected const initializer")
  }
  debug_inspect(const_initializer.tokens()[0].text(), content="\"2.0\"")
  guard unit.declarations()[4].data()
    is WgslGlobalDeclData::Override(override_decl) else {
    abort("expected override payload")
  }
  debug_inspect(override_decl.attributes()[0].name().name(), content="\"id\"")
  debug_inspect(override_decl.name().name(), content="\"ENABLED\"")
  guard override_decl.ty_ref() is Some(override_ty) else {
    abort("expected override type ref")
  }
  debug_inspect(override_ty.name(), content="\"bool\"")
  guard override_decl.initializer_ref() is Some(override_initializer) else {
    abort("expected override initializer")
  }
  debug_inspect(override_initializer.tokens()[0].text(), content="\"true\"")
  guard unit.declarations()[5].data() is WgslGlobalDeclData::Function(function) else {
    abort("expected function payload")
  }
  debug_inspect(function.attributes()[0].name().name(), content="\"fragment\"")
  debug_inspect(function.fn_start(), content="224")
  debug_inspect(function.fn_end(), content="226")
  debug_inspect(function.qualifier_start(), content="None")
  debug_inspect(function.name().name(), content="\"fragment\"")
  debug_inspect(function.arguments()[0].name().name(), content="\"color\"")
  debug_inspect(function.arguments()[0].name().start(), content="249")
  debug_inspect(function.arguments()[0].name().end(), content="254")
  guard function.arguments()[0].ty_ref() is Some(arg_ty) else {
    abort("expected argument type ref")
  }
  debug_inspect(arg_ty.name(), content="\"Color\"")
  debug_inspect(
    function.arguments()[0].attributes()[0].name().name(),
    content="\"location\"",
  )
  guard function.result() is Some(result) else {
    abort("expected function result")
  }
  debug_inspect(result.attributes()[0].name().name(), content="\"location\"")
  guard result.ty_ref() is Some(result_ty) else {
    abort("expected result type ref")
  }
  debug_inspect(result_ty.canonical_text(), content="\"vec4<f32>\"")
  debug_inspect(result_ty.name(), content="\"vec4\"")
  debug_inspect(result_ty.arguments()[0].name(), content="\"f32\"")
  debug_inspect(function.body().statements().length(), content="1")
  debug_inspect(
    function.body().statements()[0].expression_refs()[0].identifiers()[0].name(),
    content="\"color\"",
  )
}

///|
test "WGSL type refs expose nested template arguments" {
  let source = "alias Values = array<vec4<f32>, 4>;\n"
  let unit = parse_wgsl_translation_unit_for_test(source)
  guard unit.declarations()[0].data()
    is WgslGlobalDeclData::TypeAlias(alias_decl) else {
    abort("expected type alias payload")
  }
  guard alias_decl.ty_ref() is Some(ty) else {
    abort("expected alias type ref")
  }
  debug_inspect(ty.name(), content="\"array\"")
  debug_inspect(ty.canonical_text(), content="\"array<vec4<f32>, 4>\"")
  debug_inspect(ty.arguments().length(), content="2")
  debug_inspect(ty.arguments()[0].name(), content="\"vec4\"")
  debug_inspect(ty.arguments()[0].canonical_text(), content="\"vec4<f32>\"")
  debug_inspect(ty.arguments()[0].arguments()[0].name(), content="\"f32\"")
  debug_inspect(ty.arguments()[1].name(), content="\"4\"")
}

///|
test "WGSL type refs parse adjacent generic closes" {
  guard parse_wgsl_type_ref_text("array<mat4x4<f32>>", 0) is Some(ty) else {
    abort("expected nested type ref")
  }
  debug_inspect(ty.name(), content="\"array\"")
  debug_inspect(ty.arguments()[0].name(), content="\"mat4x4\"")
  debug_inspect(ty.arguments()[0].arguments()[0].name(), content="\"f32\"")
}

///|
test "WGSL declarations parse adjacent generic type closes" {
  let source =
    #|@group(2) @binding(1) var<storage> joint_matrices: array<mat4x4<f32>>;
    #|
  let unit = parse_wgsl_translation_unit_for_test(source)
  guard unit.declarations()[0].data()
    is WgslGlobalDeclData::GlobalVariable(global) else {
    abort("expected global variable")
  }
  guard global.ty_ref() is Some(ty) else {
    abort("expected global variable type")
  }
  debug_inspect(ty.canonical_text(), content="\"array<mat4x4<f32>>\"")
}

///|
test "WGSL initializer fragments do not treat comparison as type depth" {
  let source = "const LESS = value < limit;\n"
  let unit = parse_wgsl_translation_unit_for_test(source)
  guard unit.declarations()[0].data() is WgslGlobalDeclData::Const(value) else {
    abort("expected const")
  }
  guard value.initializer_ref() is Some(initializer) else {
    abort("expected initializer")
  }
  debug_inspect(initializer.end(), content="26")
}

///|
test "WGSL struct member parser skips conditional directive lines" {
  let source =
    #|struct Globals {
    #|  frame_count: u32,
    #|#ifdef SIXTEEN_BYTE_ALIGNMENT
    #|  _webgl2_padding: f32
    #|#endif
    #|};
    #|
  let unit = parse_wgsl_translation_unit_for_test(source)
  guard unit.declarations()[0].data() is WgslGlobalDeclData::Struct(value) else {
    abort("expected struct")
  }
  debug_inspect(value.members().length(), content="2")
  debug_inspect(value.members()[1].name().name(), content="\"_webgl2_padding\"")
  guard value.members()[1].ty_ref() is Some(padding_ty) else {
    abort("expected padding type")
  }
  debug_inspect(padding_ty.name(), content="\"f32\"")
}

///|
test "WGSL type refs normalize template spacing structurally" {
  let source = "alias Values = array < vec4 < f32 > , 4 >;\n"
  let unit = parse_wgsl_translation_unit_for_test(source)
  guard unit.declarations()[0].data()
    is WgslGlobalDeclData::TypeAlias(alias_decl) else {
    abort("expected type alias payload")
  }
  guard alias_decl.ty_ref() is Some(ty) else {
    abort("expected alias type ref")
  }
  debug_inspect(ty.canonical_text(), content="\"array<vec4<f32>, 4>\"")
  debug_inspect(ty.arguments()[0].canonical_text(), content="\"vec4<f32>\"")
  debug_inspect(
    ty.arguments()[0].arguments()[0].canonical_text(),
    content="\"f32\"",
  )
  debug_inspect(ty.arguments()[1].canonical_text(), content="\"4\"")
}

///|
test "WGSL type refs ignore comments around template delimiters" {
  let source =
    #|alias Atomic = atomic
    #|  /* comment */
    #|  <i32>;
    #|
  let unit = parse_wgsl_translation_unit_for_test(source)
  guard unit.declarations()[0].data()
    is WgslGlobalDeclData::TypeAlias(alias_decl) else {
    abort("expected type alias payload")
  }
  guard alias_decl.ty_ref() is Some(ty) else {
    abort("expected alias type ref")
  }
  debug_inspect(ty.name(), content="\"atomic\"")
  debug_inspect(ty.canonical_text(), content="\"atomic<i32>\"")
  debug_inspect(ty.arguments()[0].canonical_text(), content="\"i32\"")
}

///|
test "WGSL type refs accept Pattern_White_Space blankspace" {
  let source = "alias Values = array\u{000C}<vec4\u{200E}<f32>\u{2029}, 4>;\n"
  let unit = parse_wgsl_translation_unit_for_test(source)
  guard unit.declarations()[0].data()
    is WgslGlobalDeclData::TypeAlias(alias_decl) else {
    abort("expected type alias payload")
  }
  guard alias_decl.ty_ref() is Some(ty) else {
    abort("expected alias type ref")
  }
  debug_inspect(ty.name(), content="\"array\"")
  debug_inspect(ty.arguments()[0].name(), content="\"vec4\"")
  debug_inspect(ty.arguments()[0].arguments()[0].name(), content="\"f32\"")
  debug_inspect(ty.arguments()[1].name(), content="\"4\"")
}

///|
test "WGSL variable template lists are parsed by grammar" {
  let source =
    #|@group(0) @binding(0) var<storage, read_write> values: array<vec4<f32>, 4>;
    #|@group(0) @binding(1) var<texture_storage_2d<rgba8unorm>, write> image: texture_storage_2d<rgba8unorm, write>;
    #|
  let unit = parse_wgsl_translation_unit_for_test(source)
  guard unit.declarations()[0].data()
    is WgslGlobalDeclData::GlobalVariable(values) else {
    abort("expected values global")
  }
  debug_inspect(values.template_list().length(), content="2")
  debug_inspect(values.template_list()[0].name(), content="\"storage\"")
  debug_inspect(values.template_list()[1].name(), content="\"read_write\"")
  guard unit.declarations()[1].data()
    is WgslGlobalDeclData::GlobalVariable(image) else {
    abort("expected image global")
  }
  debug_inspect(image.template_list().length(), content="2")
  debug_inspect(
    image.template_list()[0].canonical_text(),
    content="\"texture_storage_2d<rgba8unorm>\"",
  )
  debug_inspect(image.template_list()[1].name(), content="\"write\"")
}

///|
test "WGSL function arguments are parsed by grammar" {
  let source =
    #|fn shade(
    #|  @location(0) color: vec4<f32>,
    #|  values: array<vec4<f32>, 4>,
    #|) -> f32 { return values[0].x; }
    #|
  let unit = parse_wgsl_translation_unit_for_test(source)
  guard unit.declarations()[0].data() is WgslGlobalDeclData::Function(function) else {
    abort("expected function payload")
  }
  debug_inspect(function.arguments().length(), content="2")
  debug_inspect(
    function.arguments()[0].attributes()[0].name().name(),
    content="\"location\"",
  )
  debug_inspect(function.arguments()[0].name().name(), content="\"color\"")
  guard function.arguments()[0].ty_ref() is Some(color_ty) else {
    abort("expected color type")
  }
  debug_inspect(color_ty.canonical_text(), content="\"vec4<f32>\"")
  debug_inspect(function.arguments()[1].name().name(), content="\"values\"")
  guard function.arguments()[1].ty_ref() is Some(values_ty) else {
    abort("expected values type")
  }
  debug_inspect(values_ty.arguments().length(), content="2")
  debug_inspect(
    values_ty.arguments()[0].canonical_text(),
    content="\"vec4<f32>\"",
  )
  debug_inspect(values_ty.arguments()[1].canonical_text(), content="\"4\"")
}

///|
test "WGSL struct members are parsed by grammar" {
  let source =
    #|struct Storage {
    #|  @location(0) color: vec4<f32>;
    #|  values: array<vec4<f32>, 4>;
    #|}
    #|
  let unit = parse_wgsl_translation_unit_for_test(source)
  guard unit.declarations()[0].data() is WgslGlobalDeclData::Struct(struct_decl) else {
    abort("expected struct payload")
  }
  debug_inspect(struct_decl.members().length(), content="2")
  debug_inspect(
    struct_decl.members()[0].attributes()[0].name().name(),
    content="\"location\"",
  )
  debug_inspect(struct_decl.members()[0].name().name(), content="\"color\"")
  guard struct_decl.members()[0].ty_ref() is Some(color_ty) else {
    abort("expected color type")
  }
  debug_inspect(color_ty.canonical_text(), content="\"vec4<f32>\"")
  debug_inspect(struct_decl.members()[1].name().name(), content="\"values\"")
  guard struct_decl.members()[1].ty_ref() is Some(values_ty) else {
    abort("expected values type")
  }
  debug_inspect(
    values_ty.arguments()[0].canonical_text(),
    content="\"vec4<f32>\"",
  )
  debug_inspect(values_ty.arguments()[1].canonical_text(), content="\"4\"")
}

///|
test "WGSL expression refs expose attribute and initializer identifiers" {
  let source =
    #|const BASE: u32 = 1u;
    #|const FACTOR: u32 = BASE + 1u;
    #|@id(FACTOR) override VALUE: bool = ENABLED_FLAG;
    #|
  let unit = parse_wgsl_translation_unit_for_test(source)
  guard unit.declarations()[1].data() is WgslGlobalDeclData::Const(const_decl) else {
    abort("expected const payload")
  }
  guard const_decl.initializer_ref() is Some(const_initializer) else {
    abort("expected const initializer ref")
  }
  debug_inspect(const_initializer.identifiers()[0].name(), content="\"BASE\"")
  guard unit.declarations()[2].data()
    is WgslGlobalDeclData::Override(override_decl) else {
    abort("expected override payload")
  }
  guard override_decl.attributes()[0].arguments_ref() is Some(attr_args) else {
    abort("expected attribute arguments ref")
  }
  debug_inspect(attr_args.identifiers()[0].name(), content="\"FACTOR\"")
  guard override_decl.initializer_ref() is Some(override_initializer) else {
    abort("expected override initializer ref")
  }
  debug_inspect(
    override_initializer.identifiers()[0].name(),
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
  let unit = parse_wgsl_translation_unit_for_test(source)
  guard unit.declarations()[0].data() is WgslGlobalDeclData::Struct(struct_decl) else {
    abort("expected struct")
  }
  let field = struct_decl.members()[0]
  let field_attr = field.attributes()[0]
  debug_inspect(
    source[field_attr.start():field_attr.end()].to_owned(),
    content="\"@location(0)\"",
  )
  debug_inspect(
    source[field.start():field.end()].to_owned(),
    content="\"@location(0) position: vec3<f32>\"",
  )
  guard unit.declarations()[1].data() is WgslGlobalDeclData::Function(function) else {
    abort("expected function")
  }
  debug_inspect(
    source[function.body().start():function.body().end()].to_owned(),
    content="\"{\\n  return color;\\n}\"",
  )
  let fn_attr = function.attributes()[0]
  debug_inspect(
    source[fn_attr.start():fn_attr.end()].to_owned(),
    content="\"@fragment\"",
  )
  let arg = function.arguments()[0]
  debug_inspect(
    source[arg.start():arg.end()].to_owned(),
    content="\"@location(0) color: Color\"",
  )
  guard function.result() is Some(result) else { abort("expected result") }
  debug_inspect(
    source[result.start():result.end()].to_owned(),
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
  let unit = parse_wgsl_translation_unit_for_test(source)
  guard unit.declarations()[1].data() is WgslGlobalDeclData::Function(function) else {
    abort("expected function")
  }
  debug_inspect(function.attributes().length(), content="2")
  debug_inspect(
    function.attributes()[0].name().name(),
    content="\"workgroup_size\"",
  )
  guard function.attributes()[0].arguments_ref() is Some(arguments) else {
    abort("expected attribute arguments ref")
  }
  debug_inspect(arguments.identifiers()[0].name(), content="\"WIDTH\"")
  debug_inspect(arguments.identifiers()[1].name(), content="\"max\"")
  debug_inspect(arguments.identifiers()[2].name(), content="\"WIDTH\"")
  debug_inspect(function.attributes()[1].name().name(), content="\"compute\"")
  debug_inspect(function.attributes()[1].arguments_ref(), content="None")
}

///|
test "WGSL expression refs expose token and literal AST" {
  let source =
    #|@group(0u) @binding(12) @id(true) override FLAG: bool = false;
    #|
  let unit = parse_wgsl_translation_unit_for_test(source)
  guard unit.declarations()[0].data()
    is WgslGlobalDeclData::Override(override_decl) else {
    abort("expected override")
  }
  guard override_decl.attributes()[0].arguments_ref() is Some(group_args) else {
    abort("expected group args")
  }
  debug_inspect(
    group_args.tokens()[0].kind(),
    content=(
      #|NumericLiteral(
      #|  {
      #|    raw_text: "0u",
      #|    base: Decimal,
      #|    suffix: U32Suffix,
      #|    category: U32Literal,
      #|  },
      #|)
    ),
  )
  guard override_decl.attributes()[1].arguments_ref() is Some(binding_args) else {
    abort("expected binding args")
  }
  debug_inspect(
    binding_args.tokens()[0].kind(),
    content=(
      #|NumericLiteral(
      #|  {
      #|    raw_text: "12",
      #|    base: Decimal,
      #|    suffix: NoSuffix,
      #|    category: AbstractIntLiteral,
      #|  },
      #|)
    ),
  )
  guard override_decl.attributes()[2].arguments_ref() is Some(id_args) else {
    abort("expected id args")
  }
  debug_inspect(id_args.tokens()[0].kind(), content="BoolLiteral(true)")
  guard override_decl.initializer_ref() is Some(initializer) else {
    abort("expected initializer")
  }
  debug_inspect(initializer.tokens()[0].kind(), content="BoolLiteral(false)")
}

///|
test "WGSL expression refs preserve large u32 literals as unsigned" {
  let source =
    #|const MASK: u32 = 3221225472u;
    #|
  let unit = parse_wgsl_translation_unit_for_test(source)
  guard unit.declarations()[0].data() is WgslGlobalDeclData::Const(const_decl) else {
    abort("expected const")
  }
  guard const_decl.initializer_ref() is Some(initializer) else {
    abort("expected initializer")
  }
  debug_inspect(
    initializer.tokens()[0].kind(),
    content=(
      #|NumericLiteral(
      #|  {
      #|    raw_text: "3221225472u",
      #|    base: Decimal,
      #|    suffix: U32Suffix,
      #|    category: U32Literal,
      #|  },
      #|)
    ),
  )
}

///|
test "WGSL typed initializer tails are parsed by grammar" {
  let source =
    #|var<private> cache: u32 = FACTOR;
    #|const INFERRED = cache + 1u;
    #|@id(1) override FLAG = ENABLED_FLAG;
    #|
  let unit = parse_wgsl_translation_unit_for_test(source)
  guard unit.declarations()[0].data()
    is WgslGlobalDeclData::GlobalVariable(global) else {
    abort("expected global variable")
  }
  guard global.ty_ref() is Some(global_ty) else {
    abort("expected global type")
  }
  debug_inspect(global_ty.name(), content="\"u32\"")
  guard global.initializer_ref() is Some(global_initializer) else {
    abort("expected global initializer")
  }
  debug_inspect(
    global_initializer.identifiers()[0].name(),
    content="\"FACTOR\"",
  )
  guard unit.declarations()[1].data() is WgslGlobalDeclData::Const(const_decl) else {
    abort("expected const")
  }
  debug_inspect(const_decl.ty_ref(), content="None")
  guard const_decl.initializer_ref() is Some(const_initializer) else {
    abort("expected const initializer")
  }
  debug_inspect(const_initializer.identifiers()[0].name(), content="\"cache\"")
  guard unit.declarations()[2].data()
    is WgslGlobalDeclData::Override(override_decl) else {
    abort("expected override")
  }
  debug_inspect(override_decl.ty_ref(), content="None")
  guard override_decl.initializer_ref() is Some(override_initializer) else {
    abort("expected override initializer")
  }
  debug_inspect(
    override_initializer.identifiers()[0].name(),
    content="\"ENABLED_FLAG\"",
  )
}

///|
