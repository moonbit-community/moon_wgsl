///|
test "WGSL identifier collection exposes source spans" {
  let source =
    #|alias Alias = vec4<f32>;
    #|override fn mod::inner(value: Alias) -> Alias {
    #|  return value;
    #|}
    #|
  let unit = parse_wgsl_translation_unit_for_test(source)
  let nodes : Array[WgslIdent] = []
  for decl in unit.declarations() {
    @ast_analysis.collect_wgsl_decl_identifier_nodes(decl.data(), nodes)
  }
  debug_inspect(nodes[0].name(), content="\"vec4\"")
  debug_inspect(nodes[0].start(), content="14")
  debug_inspect(nodes[1].name(), content="\"f32\"")
  debug_inspect(nodes[2].name(), content="\"mod::inner\"")
  debug_inspect(nodes[3].name(), content="\"Alias\"")
  debug_inspect(nodes[4].name(), content="\"Alias\"")
  debug_inspect(nodes.length(), content="5")
}

///|
test "WGSL type identifier collection ignores numeric type atoms" {
  let source =
    #|alias Alias = vec4<f32>;
    #|alias Sized = array<Alias, 4>;
    #|
  let unit = parse_wgsl_translation_unit_for_test(source)
  let nodes : Array[WgslIdent] = []
  for decl in unit.declarations() {
    @ast_analysis.collect_wgsl_decl_identifier_nodes(decl.data(), nodes)
  }
  debug_inspect(
    nodes.map(fn(node) { node.name() }),
    content=(
      #|["vec4", "f32", "array", "Alias"]
    ),
  )
  guard unit.declarations()[1].data() is TypeAlias(alias_decl) else {
    abort("expected type alias")
  }
  guard alias_decl.ty_ref() is Some(sized_ty) else {
    abort("expected type alias type")
  }
  debug_inspect(sized_ty.arguments()[1].atom().kind(), content="Numeric")
}

///|
test "WGSL function payload exposes statement AST spans" {
  let source =
    #|fn demo(value: u32) -> u32 {
    #|  var<function> local: u32 = value;
    #|  if (local > 0u) {
    #|    return local;
    #|  }
    #|  return 0u;
    #|}
    #|
  let unit = parse_wgsl_translation_unit_for_test(source)
  guard unit.declarations()[0].data() is Function(function) else {
    abort("expected function payload")
  }
  debug_inspect(function.body().statements().length(), content="3")
  debug_inspect(
    function.body().statements()[0].kind(),
    content="LocalDeclaration",
  )
  debug_inspect(function.body().statements()[1].kind(), content="If")
  debug_inspect(function.body().statements()[2].kind(), content="Return")
  debug_inspect(
    function.body().statements()[0]
    .exported_local_bindings()
    .map(fn(binding) { binding.name().name() }),
    content=(
      #|["local"]
    ),
  )
  debug_inspect(
    function.body().statements()[0].local_bindings().length(),
    content="1",
  )
  debug_inspect(
    function.body().statements()[0].local_bindings()[0].kind(),
    content="Var",
  )
  debug_inspect(
    function.body().statements()[0].local_bindings()[0].name().name(),
    content="\"local\"",
  )
  debug_inspect(
    function.body().statements()[0].local_bindings()[0].template_list()[0].name(),
    content="\"function\"",
  )
  guard function.body().statements()[0].local_bindings()[0].ty_ref()
    is Some(local_ty) else {
    abort("expected local type ref")
  }
  debug_inspect(local_ty.name(), content="\"u32\"")
  debug_inspect(local_ty.name(), content="\"u32\"")
  guard function.body().statements()[0].local_bindings()[0].initializer_ref()
    is Some(local_init) else {
    abort("expected local initializer ref")
  }
  debug_inspect(
    local_init.identifiers().map(fn(node) { node.name() }),
    content=(
      #|["value"]
    ),
  )
  debug_inspect(function.body().statements()[0].expression_refs(), content="[]")
  debug_inspect(
    function.body().statements()[1].exported_local_bindings(),
    content="[]",
  )
  debug_inspect(
    function.body().statements()[2].exported_local_bindings(),
    content="[]",
  )
  debug_inspect(
    function.body().statements()[2].expression_refs()[0]
    .identifiers()
    .map(fn(node) { node.name() }),
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
  let unit = parse_wgsl_translation_unit_for_test(source)
  guard unit.declarations()[0].data() is Function(function) else {
    abort("expected function payload")
  }
  debug_inspect(
    function.body().statements()[0]
    .exported_local_bindings()
    .map(fn(binding) { binding.name().name() }),
    content=(
      #|["local"]
    ),
  )
  guard function.body().statements()[0].local_bindings()[0].initializer_ref()
    is Some(local_init) else {
    abort("expected local initializer ref")
  }
  debug_inspect(
    local_init.identifiers().map(fn(node) { node.name() }),
    content=(
      #|["input"]
    ),
  )
  debug_inspect(
    function.body().statements()[1].expression_refs()[0]
    .identifiers()
    .map(fn(node) { node.name() }),
    content=(
      #|["local", "input"]
    ),
  )
}

///|
test "WGSL expression refs expose structured expression root" {
  let source =
    #|fn demo(input: Vertex, index: u32) -> f32 {
    #|  return compute(input.values[index] + 1.0).x;
    #|}
    #|
  let unit = parse_wgsl_translation_unit_for_test(source)
  guard unit.declarations()[0].data() is Function(function) else {
    abort("expected function payload")
  }
  let expr = function.body().statements()[0].expression_refs()[0]
  guard expr.root() is Some(root) else { abort("expected expression root") }
  debug_inspect(
    function.body().statements()[0].expressions().map(fn(item) { item.role() }),
    content=(
      #|[ReturnValue]
    ),
  )
  debug_inspect(
    root.kind(),
    content=(
      #|Member(
      #|  {
      #|    kind: Call(
      #|      {
      #|        kind: Identifier({ name: "compute", start: 53, end: 60 }),
      #|        start: 53,
      #|        end: 60,
      #|      },
      #|      [
      #|        {
      #|          kind: Binary(
      #|            Add,
      #|            {
      #|              kind: Index(
      #|                {
      #|                  kind: Member(
      #|                    {
      #|                      kind: Identifier({ name: "input", start: 61, end: 66 }),
      #|                      start: 61,
      #|                      end: 66,
      #|                    },
      #|                    { name: "values", start: 67, end: 73 },
      #|                  ),
      #|                  start: 61,
      #|                  end: 73,
      #|                },
      #|                {
      #|                  kind: Identifier({ name: "index", start: 74, end: 79 }),
      #|                  start: 74,
      #|                  end: 79,
      #|                },
      #|              ),
      #|              start: 61,
      #|              end: 80,
      #|            },
      #|            {
      #|              kind: Literal(
      #|                {
      #|                  kind: NumericLiteral(
      #|                    {
      #|                      raw_text: "1.0",
      #|                      base: Decimal,
      #|                      suffix: NoSuffix,
      #|                      category: AbstractFloatLiteral,
      #|                    },
      #|                  ),
      #|                  text: "1.0",
      #|                  start: 83,
      #|                  end: 86,
      #|                },
      #|              ),
      #|              start: 83,
      #|              end: 86,
      #|            },
      #|          ),
      #|          start: 61,
      #|          end: 86,
      #|        },
      #|      ],
      #|    ),
      #|    start: 53,
      #|    end: 87,
      #|  },
      #|  { name: "x", start: 88, end: 89 },
      #|)
    ),
  )
}

///|
test "WGSL expression parser uses lexer compound operator tokens" {
  let source =
    #|fn demo(input: Vertex) -> bool {
    #|  return input.x >= 1.0;
    #|}
    #|
  let unit = parse_wgsl_translation_unit_for_test(source)
  guard unit.declarations()[0].data() is Function(function) else {
    abort("expected function payload")
  }
  let expr = function.body().statements()[0].expression_refs()[0]
  guard expr.root() is Some(root) else { abort("expected expression root") }
  debug_inspect(
    root.kind(),
    content=(
      #|Binary(
      #|  GreaterEqual,
      #|  {
      #|    kind: Member(
      #|      {
      #|        kind: Identifier({ name: "input", start: 42, end: 47 }),
      #|        start: 42,
      #|        end: 47,
      #|      },
      #|      { name: "x", start: 48, end: 49 },
      #|    ),
      #|    start: 42,
      #|    end: 49,
      #|  },
      #|  {
      #|    kind: Literal(
      #|      {
      #|        kind: NumericLiteral(
      #|          {
      #|            raw_text: "1.0",
      #|            base: Decimal,
      #|            suffix: NoSuffix,
      #|            category: AbstractFloatLiteral,
      #|          },
      #|        ),
      #|        text: "1.0",
      #|        start: 53,
      #|        end: 56,
      #|      },
      #|    ),
      #|    start: 53,
      #|    end: 56,
      #|  },
      #|)
    ),
  )
}

///|
test "WGSL expression parser structures template elaborated calls" {
  let source =
    #|alias Color = vec4<f32>;
    #|fn demo(value: f32) -> Color {
    #|  return vec4<f32>(value);
    #|}
    #|
  let unit = parse_wgsl_translation_unit_for_test(source)
  guard unit.declarations()[1].data() is Function(function) else {
    abort("expected function payload")
  }
  let expr = function.body().statements()[0].expression_refs()[0]
  debug_inspect(
    wgsl_expr_ref_source_text(source, expr),
    content="\"vec4<f32>(value)\"",
  )
  match expr.root() {
    Some(root) =>
      match root.kind() {
        Call(callee, args) => {
          debug_inspect(args.length(), content="1")
          match callee.kind() {
            Template(base, template_args) => {
              debug_inspect(template_args.length(), content="1")
              match base.kind() {
                Identifier(ident) =>
                  debug_inspect(ident.name(), content="\"vec4\"")
                _ => abort("expected template base identifier")
              }
              match template_args[0] {
                Type(ty) => debug_inspect(ty.name(), content="\"f32\"")
                _ => abort("expected type template argument")
              }
            }
            _ => abort("expected template callee")
          }
        }
        _ => abort("expected call root")
      }
    None => abort("expected expression root")
  }
}

///|
test "WGSL expression parser binds postfix calls inside unary operands" {
  let source =
    #|fn demo(a: vec3<f32>, b: vec3<f32>) -> vec3<f32> {
    #|  return -cross(a, b);
    #|}
    #|
  let unit = parse_wgsl_translation_unit_for_test(source)
  guard unit.declarations()[0].data() is Function(function) else {
    abort("expected function payload")
  }
  let expr = function.body().statements()[0].expression_refs()[0]
  debug_inspect(
    wgsl_expr_ref_source_text(source, expr),
    content="\"-cross(a, b)\"",
  )
  match expr.root() {
    Some(root) =>
      match root.kind() {
        Unary(op, rhs) => {
          debug_inspect(op.text(), content="\"-\"")
          match rhs.kind() {
            Call(callee, args) => {
              debug_inspect(args.length(), content="2")
              match callee.kind() {
                Identifier(ident) =>
                  debug_inspect(ident.name(), content="\"cross\"")
                _ => abort("expected call callee identifier")
              }
            }
            _ => abort("expected unary operand call")
          }
        }
        _ => abort("expected unary root")
      }
    None => abort("expected expression root")
  }
}

///|
test "WGSL statement parser keeps nested if condition separate from block" {
  let source =
    #|fn clip(L: array<vec3<f32>, 4>) {
    #|  for (var i: u32 = 0u; i < 4u; i = i + 1u) {
    #|    let a: vec3<f32> = L[i];
    #|    let b: vec3<f32> = L[(i + 1u) % 4u];
    #|    if ((a.z >= 0f) != (b.z >= 0f)) {
    #|      let t: f32 = a.z / (a.z - b.z);
    #|    }
    #|  }
    #|}
    #|
  let unit = parse_wgsl_translation_unit_for_test(source)
  guard unit.declarations()[0].data() is Function(function) else {
    abort("expected function payload")
  }
  let for_stmt = function.body().statements()[0]
  let if_stmt = for_stmt.blocks()[0].statements()[2]
  let expr = if_stmt.expression_refs()[0]
  debug_inspect(
    wgsl_expr_ref_source_text(source, expr),
    content="\"(a.z >= 0f) != (b.z >= 0f)\"",
  )
  match expr.root() {
    Some(root) =>
      match root.kind() {
        Binary(op, _, _) => debug_inspect(op.text(), content="\"!=\"")
        _ => abort("expected binary condition root")
      }
    None => abort("expected condition root")
  }
}

///|
test "WGSL statement parser attaches continuing only to loop statements" {
  let source =
    #|fn demo() {
    #|  var i: i32 = 0i;
    #|  loop {
    #|    if ((i >= 0i) != (i < 4i)) {
    #|      i = i + 1i;
    #|    }
    #|    continuing {
    #|      i = i + 1i;
    #|    }
    #|  }
    #|}
    #|
  let unit = parse_wgsl_translation_unit_for_test(source)
  guard unit.declarations()[0].data() is Function(function) else {
    abort("expected function payload")
  }
  let loop_stmt = function.body().statements()[1]
  let loop_body = loop_stmt.blocks()[0]
  let if_stmt = loop_body.statements()[0]
  debug_inspect(loop_stmt.blocks().length(), content="1")
  debug_inspect(if_stmt.blocks().length(), content="1")
  debug_inspect(loop_body.statements()[1].kind(), content="Continuing")
  let expr = if_stmt.expression_refs()[0]
  debug_inspect(
    wgsl_expr_ref_source_text(source, expr),
    content="\"(i >= 0i) != (i < 4i)\"",
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
  let unit = parse_wgsl_translation_unit_for_test(source)
  let nodes : Array[WgslIdent] = []
  for decl in unit.declarations() {
    @ast_analysis.collect_wgsl_decl_global_declared_identifier_nodes(
      decl.data(),
      nodes,
    )
  }
  debug_inspect(
    nodes.map(fn(node) { node.name() }),
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
  let unit = parse_wgsl_translation_unit_for_test(source)
  guard unit.declarations()[1].data() is Function(function) else {
    abort("expected function payload")
  }
  let nodes : Array[WgslIdent] = []
  @ast_analysis.collect_wgsl_decl_identifier_nodes(Function(function), nodes)
  debug_inspect(
    nodes.map(fn(node) { node.name() }),
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
  let unit = parse_wgsl_translation_unit_for_test(source)
  guard unit.declarations()[0].data() is Function(function) else {
    abort("expected function payload")
  }
  debug_inspect(function.body().statements()[0].kind(), content="If")
  debug_inspect(function.body().statements()[1].kind(), content="For")
  debug_inspect(function.body().statements()[2].kind(), content="Return")
  debug_inspect(function.body().statements()[0].blocks().length(), content="1")
  debug_inspect(
    function.body().statements()[0].blocks()[0]
    .statements()
    .map(fn(statement) { statement.kind() }),
    content=(
      #|[LocalDeclaration, Return]
    ),
  )
  debug_inspect(function.body().statements()[1].blocks().length(), content="1")
  debug_inspect(
    function.body().statements()[1].blocks()[0].statements()[0].kind(),
    content="Continue",
  )
  debug_inspect(
    function.body().statements()[0]
    .local_bindings()
    .map(fn(binding) { binding.name().name() }),
    content="[]",
  )
  debug_inspect(
    function.body().statements()[0].blocks()[0].statements()[0]
    .local_bindings()
    .map(fn(binding) { binding.name().name() }),
    content=(
      #|["nested"]
    ),
  )
  debug_inspect(
    function.body().statements()[0].expression_refs()[0]
    .identifiers()
    .map(fn(node) { node.name() }),
    content=(
      #|["arg"]
    ),
  )
  debug_inspect(
    function.body().statements()[0].exported_local_bindings(),
    content="[]",
  )
  debug_inspect(
    function.body().statements()[1]
    .local_bindings()
    .map(fn(binding) { binding.name().name() }),
    content=(
      #|["i"]
    ),
  )
  debug_inspect(
    function.body().statements()[1].local_bindings().length(),
    content="1",
  )
  debug_inspect(
    function.body().statements()[1].local_bindings()[0].name().name(),
    content="\"i\"",
  )
  guard function.body().statements()[1].local_bindings()[0].ty_ref()
    is Some(loop_ty) else {
    abort("expected loop local type ref")
  }
  debug_inspect(loop_ty.name(), content="\"u32\"")
  debug_inspect(
    function.body().statements()[1]
    .expression_refs()
    .map(fn(expr) { wgsl_expr_ref_source_text(source, expr) }),
    content=(
      #|["i < arg", "i = i + 1u"]
    ),
  )
  debug_inspect(
    function.body().statements()[1].expression_refs()[0]
    .identifiers()
    .map(fn(node) { node.name() }),
    content=(
      #|["i", "arg"]
    ),
  )
  debug_inspect(
    function.body().statements()[1].exported_local_bindings(),
    content="[]",
  )
  let nodes : Array[WgslIdent] = []
  @ast_analysis.collect_wgsl_decl_identifier_nodes(Function(function), nodes)
  debug_inspect(
    nodes.map(fn(node) { node.name() }),
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
  let unit = parse_wgsl_translation_unit_for_test(source)
  guard unit.declarations()[0].data() is Function(function) else {
    abort("expected function")
  }
  let statement = function.body().statements()[0]
  debug_inspect(statement.kind(), content="If")
  debug_inspect(statement.blocks().length(), content="2")
  debug_inspect(
    statement.expression_refs()[0].identifiers().map(fn(node) { node.name() }),
    content=(
      #|["arg"]
    ),
  )
  debug_inspect(
    statement
    .expression_refs()
    .map(fn(expr) { wgsl_expr_ref_source_text(source, expr) }),
    content=(
      #|["arg > 0u"]
    ),
  )
  debug_inspect(statement.blocks()[0].statements()[0].kind(), content="Return")
  debug_inspect(
    statement.blocks()[0].statements()[0]
    .expression_refs()
    .map(fn(expr) { wgsl_expr_ref_source_text(source, expr) }),
    content=(
      #|["1u"]
    ),
  )
  debug_inspect(statement.blocks()[1].statements()[0].kind(), content="Return")
  debug_inspect(
    source[statement.blocks()[1].start():statement.blocks()[1].end()].to_owned(),
    content="\"{\\n    return 0u;\\n  }\"",
  )
}

///|
test "WGSL statement AST preserves else-if conditions structurally" {
  let source =
    #|fn demo(arg: u32) -> u32 {
    #|  if arg == 0u {
    #|    return 0u;
    #|  } else if arg == 1u || arg == 2u {
    #|    return 1u;
    #|  } else {
    #|    return 3u;
    #|  }
    #|}
    #|
  let unit = parse_wgsl_translation_unit_for_test(source)
  guard unit.declarations()[0].data() is Function(function) else {
    abort("expected function")
  }
  let statement = function.body().statements()[0]
  debug_inspect(statement.kind(), content="If")
  debug_inspect(statement.blocks().length(), content="3")
  debug_inspect(
    statement
    .expressions()
    .filter(fn(expr) { expr.role() == Condition })
    .map(fn(expr) { wgsl_expr_ref_source_text(source, expr.expression()) }),
    content=(
      #|["arg == 0u", "arg == 1u || arg == 2u"]
    ),
  )
  debug_inspect(
    statement
    .blocks()
    .map(fn(block) { block.statements()[0].expression_refs()[0] })
    .map(fn(expr) { wgsl_expr_ref_source_text(source, expr) }),
    content=(
      #|["0u", "1u", "3u"]
    ),
  )
}

///|
