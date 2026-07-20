// Copyright 2026 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
fn parse_expression(source : String) -> Unit raise WeslCompileError {
  match @expression_parse.parse_expression_source(source) {
    Parsed(_) => ()
    Failed(diagnostic) => {
      let message = match diagnostic.message {
        Some(message) => message
        None =>
          if diagnostic.incomplete {
            "incomplete expression"
          } else {
            "unsupported expression syntax"
          }
      }
      raise Parse("\{message}: `\{source}`")
    }
  }
}

///|
fn parse_expression_ast(
  source : String,
) -> @expression_parse.ExpressionParseNode raise WeslCompileError {
  match @expression_parse.parse_expression_source(source) {
    Parsed(node) => node
    Failed(diagnostic) => {
      let message = match diagnostic.message {
        Some(message) => message
        None =>
          if diagnostic.incomplete {
            "incomplete expression"
          } else {
            "unsupported expression syntax"
          }
      }
      raise Parse("\{message}: `\{source}`")
    }
  }
}

///|
fn parse_type_specifier(source : String) -> Unit raise WeslCompileError {
  match @type_parse.parse_type_source(source) {
    Parsed(_) => ()
    Failed(diagnostic) => {
      let message = match diagnostic.message {
        Some(message) => message
        None =>
          if diagnostic.incomplete {
            "incomplete type"
          } else {
            "unsupported type syntax"
          }
      }
      raise Parse("\{message}: `\{source}`")
    }
  }
}

///|
fn parse_type_ast(
  source : String,
) -> @type_parse.TypeSpecifierParseNode raise WeslCompileError {
  match @type_parse.parse_type_source(source) {
    Parsed(node) => node
    Failed(diagnostic) => {
      let message = match diagnostic.message {
        Some(message) => message
        None =>
          if diagnostic.incomplete {
            "incomplete type"
          } else {
            "unsupported type syntax"
          }
      }
      raise Parse("\{message}: `\{source}`")
    }
  }
}

///|
test "parser: generated expression parser handles WGSL operator and template forms" {
  let valid_cases = [
    "vec2<f32>(1.0, 2.0)", "array<vec2<f32>, 2>(vec2<f32>(1, 2), vec2(3, 4))", "a < b || c > d",
    "textureSample(t, s, uv).rgba[0]", "&buffer[index + 1u]", "foo(1, 2,)", "!(a == b) && (c != d)",
    "value--7", "atomicMax(&storage_atomic_scalar, 1lu)",
  ]
  for expr in valid_cases {
    let result = try parse_expression(expr) catch {
      err => Err(err)
    } noraise {
      value => Ok(value)
    }
    match result {
      Ok(_) => ()
      Err(err) => fail("\{expr}: \{err.message()}")
    }
  }
  let invalid_cases = [
    "07", "foo(", "vec2<f32>(", "a +", "textureSample(t,, uv)",
  ]
  for expr in invalid_cases {
    let result = try parse_expression(expr) catch {
      err => Err(err)
    } noraise {
      value => Ok(value)
    }
    match result {
      Ok(_) => fail("\{expr}: expected parse failure")
      Err(_) => ()
    }
  }
}

///|
test "parser: generated expression parser returns AST nodes" {
  let ast = parse_expression_ast("textureSample(t, s, uv).rgba[0] + -value--7")
  let expected_ast =
    #|Binary(
    #|  Subtraction,
    #|  Binary(
    #|    Addition,
    #|    Indexing(
    #|      NamedComponent(
    #|        FunctionCall(
    #|          {
    #|            callee: { path: [], ident: "textureSample", template_text: None },
    #|            arguments: [
    #|              TypeOrIdentifier({ path: [], ident: "t", template_text: None }),
    #|              TypeOrIdentifier({ path: [], ident: "s", template_text: None }),
    #|              TypeOrIdentifier({ path: [], ident: "uv", template_text: None }),
    #|            ],
    #|          },
    #|        ),
    #|        "rgba",
    #|      ),
    #|      Literal("0"),
    #|    ),
    #|    Unary(
    #|      Negation,
    #|      TypeOrIdentifier({ path: [], ident: "value", template_text: None }),
    #|    ),
    #|  ),
    #|  Unary(Negation, Literal("7")),
    #|)
  debug_inspect(ast, content=expected_ast)
  let templated = parse_expression_ast(
    "package::math::make_vec<vec2<f32>, 2>(1, true)",
  )
  let expected_templated =
    #|FunctionCall(
    #|  {
    #|    callee: {
    #|      path: ["package", "math"],
    #|      ident: "make_vec",
    #|      template_text: Some("vec2<f32>, 2"),
    #|    },
    #|    arguments: [Literal("1"), Bool(true)],
    #|  },
    #|)
  debug_inspect(templated, content=expected_templated)
}

///|
test "parser: generated type parser handles nested WGSL type specifiers" {
  let valid_cases = [
    "f32", "vec4<f32>", "mat4x4<f16>", "array<vec3<f32>, 4>", "array<array<f32, 2>, 3>",
    "ptr<storage, DynamicArray, read_write>", "package::shared::Payload", "foo::bar::Texture<vec2<f32>, N>",
    "array<u32, 1,>", "ptr<storage,>", "array<i32, 1 << 1>",
  ]
  for ty in valid_cases {
    let result = try parse_type_specifier(ty) catch {
      err => Err(err)
    } noraise {
      value => Ok(value)
    }
    match result {
      Ok(_) => ()
      Err(err) => fail("\{ty}: \{err.message()}")
    }
  }
  let invalid_cases = ["", "array<", "vec2<f32", "array<f32,, 2>", "foo::"]
  for ty in invalid_cases {
    let result = try parse_type_specifier(ty) catch {
      err => Err(err)
    } noraise {
      value => Ok(value)
    }
    match result {
      Ok(_) => fail("\{ty}: expected parse failure")
      Err(_) => ()
    }
  }
}

///|
test "parser: generated type parser returns AST nodes" {
  let ast = parse_type_ast("package::shared::Payload<array<vec3<f32>, 4>, -1>")
  let expected =
    #|{
    #|  path: ["package", "shared"],
    #|  ident: "Payload",
    #|  template_args: [
    #|    Type(
    #|      {
    #|        path: [],
    #|        ident: "array",
    #|        template_args: [
    #|          Type(
    #|            {
    #|              path: [],
    #|              ident: "vec3",
    #|              template_args: [Type({ path: [], ident: "f32", template_args: [] })],
    #|            },
    #|          ),
    #|          Literal("4"),
    #|        ],
    #|      },
    #|    ),
    #|    Literal("-1"),
    #|  ],
    #|}
  debug_inspect(ast, content=expected)
}

///|
test "parser: generated attribute parser preserves leading attributes" {
  let source = "@group(0)\n@binding(textureIndex(1 + foo(2)))\nvar color_texture: texture_2d<f32>;\n"

  let unit = try! parse_translation_unit(
    try! parse_module_path("demo"),
    source,
    true,
  )
  debug_inspect(unit.global_declarations.length(), content="1")
  let declaration = unit.global_declarations[0]
  let expected_attributes =
    #|[
    #|  {
    #|    name: "group",
    #|    arguments: Some("0"),
    #|    argument_exprs: [Literal("0")],
    #|    condition_expr: None,
    #|    span: { start_line: 1, end_line: 1 },
    #|  },
    #|  {
    #|    name: "binding",
    #|    arguments: Some("textureIndex(1 + foo(2))"),
    #|    argument_exprs: [
    #|      FunctionCall(
    #|        {
    #|          callee: {
    #|            path: [],
    #|            ident: "textureIndex",
    #|            template_text: None,
    #|            template_args: [],
    #|          },
    #|          arguments: [
    #|            Binary(
    #|              Addition,
    #|              Literal("1"),
    #|              FunctionCall(
    #|                {
    #|                  callee: { path: [], ident: "foo", template_text: None, template_args: [] },
    #|                  arguments: [Literal("2")],
    #|                },
    #|              ),
    #|            ),
    #|          ],
    #|        },
    #|      ),
    #|    ],
    #|    condition_expr: None,
    #|    span: { start_line: 2, end_line: 2 },
    #|  },
    #|]

  debug_inspect(declaration.attributes, content=expected_attributes)
  debug_inspect(declaration.ident(), content="Some(\"color_texture\")")
  let result = try
    parse_translation_unit(
      try! parse_module_path("demo"),
      "@group(0\nvar value: i32;",
      true,
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  match result {
    Ok(_) => fail("expected unclosed attribute failure")
    Err(_) => ()
  }
}

///|
test "parser: generated struct parser records member names and types" {
  let unit = try! parse_translation_unit(
    try! parse_module_path("demo"),
    "struct VertexOutput {\n  @builtin(position) clip_position: vec4<f32>,\n  color: array<vec3<f32>, 4>,\n  index: u32\n};\n",
    true,
  )
  match unit.global_declarations[0].header {
    Struct(header) => {
      let expected_members =
        #|[
        #|  {
        #|    name: "clip_position",
        #|    type_text: "vec4<f32>",
        #|    type_expr: {
        #|      path: [],
        #|      ident: "vec4",
        #|      template_text: None,
        #|      template_args: [Type({ path: [], ident: "f32", template_text: None, template_args: [] })],
        #|    },
        #|    attributes: [
        #|      {
        #|        name: "builtin",
        #|        arguments: Some("position"),
        #|        argument_exprs: [
        #|          TypeOrIdentifier(
        #|            {
        #|              path: [],
        #|              ident: "position",
        #|              template_text: None,
        #|              template_args: [],
        #|            },
        #|          ),
        #|        ],
        #|        condition_expr: None,
        #|        span: { start_line: 1, end_line: 1 },
        #|      },
        #|    ],
        #|  },
        #|  {
        #|    name: "color",
        #|    type_text: "array<vec3<f32>, 4>",
        #|    type_expr: {
        #|      path: [],
        #|      ident: "array",
        #|      template_text: None,
        #|      template_args: [
        #|        Type(
        #|          {
        #|            path: [],
        #|            ident: "vec3",
        #|            template_text: None,
        #|            template_args: [Type({ path: [], ident: "f32", template_text: None, template_args: [] })],
        #|          },
        #|        ),
        #|        Literal("4"),
        #|      ],
        #|    },
        #|    attributes: [],
        #|  },
        #|  {
        #|    name: "index",
        #|    type_text: "u32",
        #|    type_expr: { path: [], ident: "u32", template_text: None, template_args: [] },
        #|    attributes: [],
        #|  },
        #|]

      debug_inspect(header.members, content=expected_members)
    }
    _ => fail("expected struct declaration")
  }
}

///|
test "parser: generated function parser records signature" {
  let source =
    #|@fragment
    #|fn shade<T>(
    #|  @location(0) color: vec4<f32>,
    #|  index: array<u32, 4>,
    #|) -> @location(0) vec4<f32> {
    #|  return color;
    #|}
    #|
  let unit = try! parse_translation_unit(
    try! parse_module_path("demo"),
    source,
    true,
  )
  match unit.global_declarations[0].header {
    Function(header) => {
      debug_inspect(header.name, content="\"shade\"")
      debug_inspect(header.generic_parameters, content="Some(\"T\")")
      let expected_parameters =
        #|[
        #|  {
        #|    name: "color",
        #|    type_text: "vec4<f32>",
        #|    type_expr: {
        #|      path: [],
        #|      ident: "vec4",
        #|      template_text: None,
        #|      template_args: [Type({ path: [], ident: "f32", template_text: None, template_args: [] })],
        #|    },
        #|    attributes: [
        #|      {
        #|        name: "location",
        #|        arguments: Some("0"),
        #|        argument_exprs: [Literal("0")],
        #|        condition_expr: None,
        #|        span: { start_line: 1, end_line: 1 },
        #|      },
        #|    ],
        #|  },
        #|  {
        #|    name: "index",
        #|    type_text: "array<u32, 4>",
        #|    type_expr: {
        #|      path: [],
        #|      ident: "array",
        #|      template_text: None,
        #|      template_args: [
        #|        Type({ path: [], ident: "u32", template_text: None, template_args: [] }),
        #|        Literal("4"),
        #|      ],
        #|    },
        #|    attributes: [],
        #|  },
        #|]

      debug_inspect(header.parameters, content=expected_parameters)
      debug_inspect(header.return_type, content="Some(\"vec4<f32>\")")
      let expected_return_attributes =
        #|[
        #|  {
        #|    name: "location",
        #|    arguments: Some("0"),
        #|    argument_exprs: [Literal("0")],
        #|    condition_expr: None,
        #|    span: { start_line: 1, end_line: 1 },
        #|  },
        #|]
      debug_inspect(
        header.return_attributes,
        content=expected_return_attributes,
      )
      let expected_return_type =
        #|Some(
        #|  {
        #|    path: [],
        #|    ident: "vec4",
        #|    template_text: None,
        #|    template_args: [Type({ path: [], ident: "f32", template_text: None, template_args: [] })],
        #|  },
        #|)
      debug_inspect(header.return_type_expr, content=expected_return_type)
      let expected_body =
        #|[
        #|  {
        #|    kind: Return,
        #|    source: "return color;",
        #|    expression: Some(TypeOrIdentifier({ path: [], ident: "color", template_text: None, template_args: [] })),
        #|    declaration: None,
        #|    assignment: None,
        #|    update_expression: None,
        #|    control: None,
        #|    attributes: [],
        #|  },
        #|]

      debug_inspect(header.body.statements, content=expected_body)
    }
    _ => fail("expected function declaration")
  }
}

///|
test "parser: generated statement parser classifies function body statements" {
  let source =
    #|fn statements() {
    #|  @if(true) storageBarrier();
    #|  const offset: u32 = 1u;
    #|  var value: i32 = 0;
    #|  let limit: i32 = 4;
    #|  value += 1;
    #|  value++;
    #|  if (value > limit) { break; }
    #|  loop { continuing { break if value > 10; } }
    #|  for (var i: u32 = 0u; i < 4u; i++) { value = value + 1; }
    #|  switch value { @if(true) case 0, 1: { value = 2; } @else default: { return; } }
    #|  textureStore(tex, coord, vec4<f32>());
    #|  return;
    #|}
    #|
  let unit = try! parse_translation_unit(
    try! parse_module_path("demo"),
    source,
    true,
  )
  match unit.global_declarations[0].header {
    Function(header) => {
      let kinds : Array[StatementKind] = []
      for statement in header.body.statements {
        kinds.push(statement.kind)
      }
      let expected_kinds =
        #|[
        #|  Call,
        #|  Const,
        #|  Var,
        #|  Let,
        #|  CompoundAssignment,
        #|  Increment,
        #|  If,
        #|  Loop,
        #|  For,
        #|  Switch,
        #|  Call,
        #|  Return,
        #|]
      debug_inspect(kinds, content=expected_kinds)
      let expected_call =
        #|Some(
        #|  FunctionCall(
        #|    {
        #|      callee: {
        #|        path: [],
        #|        ident: "textureStore",
        #|        template_text: None,
        #|        template_args: [],
        #|      },
        #|      arguments: [
        #|        TypeOrIdentifier({ path: [], ident: "tex", template_text: None, template_args: [] }),
        #|        TypeOrIdentifier({ path: [], ident: "coord", template_text: None, template_args: [] }),
        #|        FunctionCall(
        #|          {
        #|            callee: {
        #|              path: [],
        #|              ident: "vec4",
        #|              template_text: Some("f32"),
        #|              template_args: [Type({ path: [], ident: "f32", template_text: None, template_args: [] })],
        #|            },
        #|            arguments: [],
        #|          },
        #|        ),
        #|      ],
        #|    },
        #|  ),
        #|)
      debug_inspect(
        header.body.statements[10].expression,
        content=expected_call,
      )
      let expected_conditional_call =
        #|Some(
        #|  FunctionCall(
        #|    {
        #|      callee: {
        #|        path: [],
        #|        ident: "storageBarrier",
        #|        template_text: None,
        #|        template_args: [],
        #|      },
        #|      arguments: [],
        #|    },
        #|  ),
        #|)
      debug_inspect(
        header.body.statements[0].expression,
        content=expected_conditional_call,
      )
      let expected_statement_attrs =
        #|[
        #|  {
        #|    name: "if",
        #|    arguments: Some("true"),
        #|    argument_exprs: [],
        #|    condition_expr: Some(Literal(true)),
        #|    span: { start_line: 1, end_line: 1 },
        #|  },
        #|]
      debug_inspect(
        header.body.statements[0].attributes,
        content=expected_statement_attrs,
      )
      let expected_const_declaration =
        #|Some(
        #|  {
        #|    kind: Const,
        #|    name: Some("offset"),
        #|    template_arguments: None,
        #|    type_text: Some("u32"),
        #|    type_expr: Some({ path: [], ident: "u32", template_text: None, template_args: [] }),
        #|    initializer: Some("1u"),
        #|    initializer_expr: Some(Literal("1u")),
        #|  },
        #|)
      debug_inspect(
        header.body.statements[1].declaration,
        content=expected_const_declaration,
      )
      let expected_assignment =
        #|Some(
        #|  {
        #|    operator: PlusEqual,
        #|    lhs: TypeOrIdentifier({ path: [], ident: "value", template_text: None, template_args: [] }),
        #|    rhs: Literal("1"),
        #|  },
        #|)
      debug_inspect(
        header.body.statements[4].assignment,
        content=expected_assignment,
      )
      debug_inspect(
        header.body.statements[5].update_expression,
        content="Some(TypeOrIdentifier({ path: [], ident: \"value\", template_text: None, template_args: [] }))",
      )
      let expected_if_control =
        #|Some(
        #|  If(
        #|    {
        #|      condition: Binary(
        #|        GreaterThan,
        #|        TypeOrIdentifier({ path: [], ident: "value", template_text: None, template_args: [] }),
        #|        TypeOrIdentifier({ path: [], ident: "limit", template_text: None, template_args: [] }),
        #|      ),
        #|      body: {
        #|        statements: [
        #|          {
        #|            kind: Break,
        #|            source: "break;",
        #|            expression: None,
        #|            declaration: None,
        #|            assignment: None,
        #|            update_expression: None,
        #|            control: None,
        #|            attributes: [],
        #|          },
        #|        ],
        #|      },
        #|      else_body: None,
        #|    },
        #|  ),
        #|)
      debug_inspect(
        header.body.statements[6].control,
        content=expected_if_control,
      )
      let expected_loop_control =
        #|Some(
        #|  Loop(
        #|    {
        #|      body: {
        #|        statements: [
        #|          {
        #|            kind: Continuing,
        #|            source: "continuing { break if value > 10; }",
        #|            expression: None,
        #|            declaration: None,
        #|            assignment: None,
        #|            update_expression: None,
        #|            control: Some(
        #|              Continuing(
        #|                {
        #|                  body: {
        #|                    statements: [
        #|                      {
        #|                        kind: BreakIf,
        #|                        source: "break if value > 10;",
        #|                        expression: Some(
        #|                          Binary(
        #|                            GreaterThan,
        #|                            TypeOrIdentifier({ path: [], ident: "value", template_text: None, template_args: [] }),
        #|                            Literal("10"),
        #|                          ),
        #|                        ),
        #|                        declaration: None,
        #|                        assignment: None,
        #|                        update_expression: None,
        #|                        control: None,
        #|                        attributes: [],
        #|                      },
        #|                    ],
        #|                  },
        #|                },
        #|              ),
        #|            ),
        #|            attributes: [],
        #|          },
        #|        ],
        #|      },
        #|    },
        #|  ),
        #|)
      debug_inspect(
        header.body.statements[7].control,
        content=expected_loop_control,
      )
      let expected_for_control =
        #|Some(
        #|  For(
        #|    {
        #|      initializer: Some(
        #|        Declaration(
        #|          {
        #|            kind: Var,
        #|            name: Some("i"),
        #|            template_arguments: None,
        #|            type_text: Some("u32"),
        #|            type_expr: Some({ path: [], ident: "u32", template_text: None, template_args: [] }),
        #|            initializer: Some("0u"),
        #|            initializer_expr: Some(Literal("0u")),
        #|          },
        #|        ),
        #|      ),
        #|      condition: Some(
        #|        Binary(
        #|          LessThan,
        #|          TypeOrIdentifier({ path: [], ident: "i", template_text: None, template_args: [] }),
        #|          Literal("4u"),
        #|        ),
        #|      ),
        #|      update: Some(Increment(TypeOrIdentifier({ path: [], ident: "i", template_text: None, template_args: [] }))),
        #|      body: {
        #|        statements: [
        #|          {
        #|            kind: Assignment,
        #|            source: "value = value + 1;",
        #|            expression: None,
        #|            declaration: None,
        #|            assignment: Some(
        #|              {
        #|                operator: Equal,
        #|                lhs: TypeOrIdentifier({ path: [], ident: "value", template_text: None, template_args: [] }),
        #|                rhs: Binary(
        #|                  Addition,
        #|                  TypeOrIdentifier({ path: [], ident: "value", template_text: None, template_args: [] }),
        #|                  Literal("1"),
        #|                ),
        #|              },
        #|            ),
        #|            update_expression: None,
        #|            control: None,
        #|            attributes: [],
        #|          },
        #|        ],
        #|      },
        #|    },
        #|  ),
        #|)
      debug_inspect(
        header.body.statements[8].control,
        content=expected_for_control,
      )
      match header.body.statements[9].control {
        Some(Switch(switch_)) => {
          debug_inspect(
            switch_.selector,
            content="TypeOrIdentifier({ path: [], ident: \"value\", template_text: None, template_args: [] })",
          )
          debug_inspect(switch_.cases.length(), content="2")
          debug_inspect(switch_.cases[0].selectors.length(), content="2")
          debug_inspect(switch_.cases[0].is_default, content="false")
          debug_inspect(switch_.cases[1].is_default, content="true")
          let expected_switch_case_attrs =
            #|[
            #|  {
            #|    name: "if",
            #|    arguments: Some("true"),
            #|    argument_exprs: [],
            #|    condition_expr: Some(Literal(true)),
            #|    span: { start_line: 1, end_line: 1 },
            #|  },
            #|]
          debug_inspect(
            switch_.cases[0].attributes,
            content=expected_switch_case_attrs,
          )
          let expected_switch_default_attrs =
            #|[
            #|  {
            #|    name: "else",
            #|    arguments: None,
            #|    argument_exprs: [],
            #|    condition_expr: None,
            #|    span: { start_line: 1, end_line: 1 },
            #|  },
            #|]
          debug_inspect(
            switch_.cases[1].attributes,
            content=expected_switch_default_attrs,
          )
          debug_inspect(
            switch_.cases[0].body.statements[0].kind,
            content="Assignment",
          )
        }
        _ => fail("expected switch control statement")
      }
      debug_inspect(header.body.statements[11].expression, content="None")
    }
    _ => fail("expected function declaration")
  }
}

///|
test "parser: generated binding parser records type annotations and initializers" {
  let source =
    #|alias color = vec4<f32>;
    #|const scale: f32 = 2.0;
    #|override enabled: bool = true;
    #|let index: u32 = 4u;
    #|@group(0) @binding(0) var<storage, read_write> values: array<f32>;
    #|
  let unit = try! parse_translation_unit(
    try! parse_module_path("demo"),
    source,
    true,
  )
  match unit.global_declarations[0].header {
    Alias(header) => {
      debug_inspect(header.target, content="Some(\"vec4<f32>\")")
      let expected_target_type =
        #|Some(
        #|  {
        #|    path: [],
        #|    ident: "vec4",
        #|    template_text: None,
        #|    template_args: [Type({ path: [], ident: "f32", template_text: None, template_args: [] })],
        #|  },
        #|)
      debug_inspect(header.target_type, content=expected_target_type)
    }
    _ => fail("expected alias declaration")
  }
  match unit.global_declarations[1].header {
    Const(header) => {
      debug_inspect(header.type_text, content="Some(\"f32\")")
      debug_inspect(header.initializer, content="Some(\"2.0\")")
    }
    _ => fail("expected const declaration")
  }
  match unit.global_declarations[2].header {
    Override(header) => {
      debug_inspect(header.type_text, content="Some(\"bool\")")
      debug_inspect(header.initializer, content="Some(\"true\")")
    }
    _ => fail("expected override declaration")
  }
  match unit.global_declarations[3].header {
    Let(header) => {
      debug_inspect(header.type_text, content="Some(\"u32\")")
      debug_inspect(header.initializer, content="Some(\"4u\")")
    }
    _ => fail("expected let declaration")
  }
  match unit.global_declarations[4].header {
    Var(header) => {
      debug_inspect(
        header.template_arguments,
        content="Some(\"storage, read_write\")",
      )
      debug_inspect(header.type_text, content="Some(\"array<f32>\")")
      let expected_var_type =
        #|Some(
        #|  {
        #|    path: [],
        #|    ident: "array",
        #|    template_text: None,
        #|    template_args: [Type({ path: [], ident: "f32", template_text: None, template_args: [] })],
        #|  },
        #|)
      debug_inspect(header.type_expr, content=expected_var_type)
      debug_inspect(header.initializer, content="None")
    }
    _ => fail("expected var declaration")
  }
}

///|
test "parser: expression type templates are structured in root AST" {
  let source =
    #|fn templates() {
    #|  let value = array<vec2<f32>, 2>(vec2<f32>(), vec2<f32>());
    #|}
    #|
  let unit = try! parse_translation_unit(
    try! parse_module_path("demo"),
    source,
    true,
  )
  match unit.global_declarations[0].header {
    Function(header) =>
      match header.body.statements[0].declaration {
        Some(declaration) =>
          match declaration.initializer_expr {
            Some(FunctionCall(call)) => {
              let expected_callee =
                #|{
                #|  path: [],
                #|  ident: "array",
                #|  template_text: Some("vec2<f32>, 2"),
                #|  template_args: [
                #|    Type(
                #|      {
                #|        path: [],
                #|        ident: "vec2",
                #|        template_text: None,
                #|        template_args: [Type({ path: [], ident: "f32", template_text: None, template_args: [] })],
                #|      },
                #|    ),
                #|    Literal("2"),
                #|  ],
                #|}
              debug_inspect(call.callee, content=expected_callee)
            }
            _ => fail("expected function call initializer")
          }
        _ => fail("expected declaration statement")
      }
    _ => fail("expected function declaration")
  }
}

///|
test "parser: generated directive parser records directive arguments" {
  let unit = try! parse_translation_unit(
    try! parse_module_path("demo"),
    "enable f16, chromium_experimental_full_ptr_parameters;\nrequires readonly_and_readwrite_storage_textures;\ndiagnostic(off, derivative_uniformity);\n",
    true,
  )
  match unit.global_declarations[0].header {
    EnableDirective(header) =>
      debug_inspect(
        header.names,
        content="[\"f16\", \"chromium_experimental_full_ptr_parameters\"]",
      )
    _ => fail("expected enable directive")
  }
  match unit.global_declarations[1].header {
    RequiresDirective(header) =>
      debug_inspect(
        header.names,
        content="[\"readonly_and_readwrite_storage_textures\"]",
      )
    _ => fail("expected requires directive")
  }
  match unit.global_declarations[2].header {
    DiagnosticDirective(header) => {
      debug_inspect(
        header.arguments,
        content="[\"off\", \"derivative_uniformity\"]",
      )
      debug_inspect(header.severity, content="Some(\"off\")")
      debug_inspect(header.rule_name, content="Some(\"derivative_uniformity\")")
    }
    _ => fail("expected diagnostic directive")
  }
}

///|
test "parser: global const_assert records structured expression" {
  let unit = try! parse_translation_unit(
    try! parse_module_path("demo"),
    "@if(true) const_assert Payload(1).value == expected;",
    true,
  )
  match unit.global_declarations[0].header {
    ConstAssert(header) => {
      debug_inspect(
        header.assertion,
        content="\"Payload(1).value == expected\"",
      )
      let expected_expr =
        #|Binary(
        #|  Equality,
        #|  NamedComponent(
        #|    FunctionCall(
        #|      {
        #|        callee: { path: [], ident: "Payload", template_text: None, template_args: [] },
        #|        arguments: [Literal("1")],
        #|      },
        #|    ),
        #|    "value",
        #|  ),
        #|  TypeOrIdentifier(
        #|    {
        #|      path: [],
        #|      ident: "expected",
        #|      template_text: None,
        #|      template_args: [],
        #|    },
        #|  ),
        #|)
      debug_inspect(header.assertion_expr, content=expected_expr)
    }
    _ => fail("expected const_assert declaration")
  }
}
