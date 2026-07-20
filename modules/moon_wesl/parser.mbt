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
priv enum ParserToken {
  At(Int, Int, Int)
  LParen(Int, Int, Int)
  RParen(Int, Int, Int)
  LBrace(Int, Int, Int)
  RBrace(Int, Int, Int)
  LBracket(Int, Int, Int)
  RBracket(Int, Int, Int)
  Comma(Int, Int, Int)
  Semi(Int, Int, Int)
  Eq(Int, Int, Int)
  Lt(Int, Int, Int)
  Gt(Int, Int, Int)
  DoubleColon(Int, Int, Int)
  Ident(String, Int, Int, Int)
  Other(Int, Int, Int)
}

///|
fn ParserToken::start(self : ParserToken) -> Int {
  match self {
    At(start, _, _) => start
    LParen(start, _, _) => start
    RParen(start, _, _) => start
    LBrace(start, _, _) => start
    RBrace(start, _, _) => start
    LBracket(start, _, _) => start
    RBracket(start, _, _) => start
    Comma(start, _, _) => start
    Semi(start, _, _) => start
    Eq(start, _, _) => start
    Lt(start, _, _) => start
    Gt(start, _, _) => start
    DoubleColon(start, _, _) => start
    Ident(_, start, _, _) => start
    Other(start, _, _) => start
  }
}

///|
fn ParserToken::end(self : ParserToken) -> Int {
  match self {
    At(_, end_, _) => end_
    LParen(_, end_, _) => end_
    RParen(_, end_, _) => end_
    LBrace(_, end_, _) => end_
    RBrace(_, end_, _) => end_
    LBracket(_, end_, _) => end_
    RBracket(_, end_, _) => end_
    Comma(_, end_, _) => end_
    Semi(_, end_, _) => end_
    Eq(_, end_, _) => end_
    Lt(_, end_, _) => end_
    Gt(_, end_, _) => end_
    DoubleColon(_, end_, _) => end_
    Ident(_, _, end_, _) => end_
    Other(_, end_, _) => end_
  }
}

///|
fn ParserToken::line(self : ParserToken) -> Int {
  match self {
    At(_, _, line) => line
    LParen(_, _, line) => line
    RParen(_, _, line) => line
    LBrace(_, _, line) => line
    RBrace(_, _, line) => line
    LBracket(_, _, line) => line
    RBracket(_, _, line) => line
    Comma(_, _, line) => line
    Semi(_, _, line) => line
    Eq(_, _, line) => line
    Lt(_, _, line) => line
    Gt(_, _, line) => line
    DoubleColon(_, _, line) => line
    Ident(_, _, _, line) => line
    Other(_, _, line) => line
  }
}

///|
fn parser_is_identifier_start(code : Int) -> Bool {
  @lex.wgsl_identifier_start_code_point(code)
}

///|
fn parser_is_identifier_char(code : Int) -> Bool {
  @lex.wgsl_identifier_continue_code_point(code)
}

///|
fn parser_identifier_start_width(source : String, index : Int) -> Int {
  match @lex.wgsl_code_point_at(source, index) {
    Some((code_point, width)) if parser_is_identifier_start(code_point) => width
    _ => 0
  }
}

///|
fn parser_identifier_continue_width(source : String, index : Int) -> Int {
  match @lex.wgsl_code_point_at(source, index) {
    Some((code_point, width)) if parser_is_identifier_char(code_point) => width
    _ => 0
  }
}

///|
fn parser_identifier_continues_before(source : String, index : Int) -> Bool {
  guard index > 0 else { return false }
  let previous = index - 1
  let previous_code = source.code_unit_at(previous).to_int()
  let start = if previous_code >= 0xDC00 && previous_code <= 0xDFFF {
    previous - 1
  } else {
    previous
  }
  start >= 0 && parser_identifier_continue_width(source, start) == index - start
}

///|
fn parser_is_reserved_word(name : String) -> Bool {
  @ir.wgsl_ir_identifier_is_reserved(name) &&
  !@ir.wgsl_ir_identifier_is_predeclared_type(name)
}

///|
fn parser_validate_declaration_ident(
  name : String,
) -> Unit raise WeslCompileError {
  if !@lex.wgsl_identifier_text(name) {
    raise Parse("invalid declaration identifier `\{name}`")
  }
  if name == "_" {
    raise Parse("invalid declaration identifier `\{name}`")
  }
  if name.length() >= 2 && name[:2].to_owned() == "__" {
    raise Parse("invalid declaration identifier `\{name}`")
  }
  if parser_is_reserved_word(name) {
    raise Parse("invalid declaration identifier `\{name}`")
  }
}

///|
fn parser_lex(source : String) -> Array[ParserToken] {
  let tokens : Array[ParserToken] = []
  let mut index = 0
  let mut line = 1
  while index < source.length() {
    let code = source.code_unit_at(index).to_int()
    if code == 32 || code == 9 || code == 13 {
      index += 1
      continue
    }
    if code == 10 {
      line += 1
      index += 1
      continue
    }
    if code == 47 &&
      index + 1 < source.length() &&
      source.code_unit_at(index + 1).to_int() == 47 {
      index += 2
      while index < source.length() && source.code_unit_at(index).to_int() != 10 {
        index += 1
      }
      continue
    }
    if code == 47 &&
      index + 1 < source.length() &&
      source.code_unit_at(index + 1).to_int() == 42 {
      index += 2
      while index + 1 < source.length() {
        if source.code_unit_at(index).to_int() == 10 {
          line += 1
        }
        if source.code_unit_at(index).to_int() == 42 &&
          source.code_unit_at(index + 1).to_int() == 47 {
          index += 2
          break
        }
        index += 1
      }
      continue
    }
    if code == 58 &&
      index + 1 < source.length() &&
      source.code_unit_at(index + 1).to_int() == 58 {
      tokens.push(DoubleColon(index, index + 2, line))
      index += 2
      continue
    }
    let identifier_width = parser_identifier_start_width(source, index)
    if identifier_width > 0 {
      let start = index
      index += identifier_width
      while index < source.length() {
        let width = parser_identifier_continue_width(source, index)
        if width == 0 {
          break
        }
        index += width
      }
      tokens.push(Ident(source[start:index].to_owned(), start, index, line))
      continue
    }
    match code {
      64 => tokens.push(At(index, index + 1, line))
      40 => tokens.push(LParen(index, index + 1, line))
      41 => tokens.push(RParen(index, index + 1, line))
      123 => tokens.push(LBrace(index, index + 1, line))
      125 => tokens.push(RBrace(index, index + 1, line))
      91 => tokens.push(LBracket(index, index + 1, line))
      93 => tokens.push(RBracket(index, index + 1, line))
      44 => tokens.push(Comma(index, index + 1, line))
      59 => tokens.push(Semi(index, index + 1, line))
      61 => tokens.push(Eq(index, index + 1, line))
      60 => tokens.push(Lt(index, index + 1, line))
      62 => tokens.push(Gt(index, index + 1, line))
      _ => tokens.push(Other(index, index + 1, line))
    }
    index += 1
  }
  tokens
}

///|
fn[T] ArrayView::start(self : ArrayView[T]) -> Int = "%arrayview.start"

///|
priv struct Parser {
  source : String
  tokens : Array[ParserToken]
  mut position : Int
}

///|
fn Parser::new(source : String) -> Parser {
  { source, tokens: parser_lex(source), position: 0 }
}

///|
fn Parser::from_tokens(source : String, tokens : Array[ParserToken]) -> Parser {
  { source, tokens, position: 0 }
}

///|
fn Parser::view(self : Parser) -> ArrayView[ParserToken] {
  self.tokens[self.position:]
}

///|
fn Parser::update_view(self : Parser, view : ArrayView[ParserToken]) -> Unit {
  self.position = view.start()
}

///|
fn Parser::update_view_after_offset(self : Parser, offset : Int) -> Unit {
  let mut position = self.position
  while position < self.tokens.length() &&
        self.tokens[position].start() < offset {
    position += 1
  }
  self.position = position
}

///|
fn[A] Parser::error(
  self : Parser,
  message : String,
) -> A raise WeslCompileError {
  match self.view() {
    [token, ..] => raise Parse("\{message} at line \{token.line()}")
    [] => raise Parse("\{message} at the end of input")
  }
}

///|
fn Parser::source_slice(
  self : Parser,
  start_offset : Int,
  end_offset : Int,
) -> String {
  if start_offset >= end_offset {
    ""
  } else {
    self.source[start_offset:end_offset].to_owned()
  }
}

///|
fn Parser::item_source(self : Parser) -> String raise WeslCompileError {
  match self.tokens[:] {
    [first, ..] =>
      match self.tokens.last() {
        Some(last) => self.source_slice(first.start(), last.end())
        None => self.error("empty top-level item")
      }
    [] => self.error("empty top-level item")
  }
}

///|
fn Parser::item_span(self : Parser) -> SyntaxSpan raise WeslCompileError {
  match self.tokens[:] {
    [first, ..] =>
      match self.tokens.last() {
        Some(last) => { start_line: first.line(), end_line: last.line() }
        None => self.error("empty top-level item")
      }
    [] => self.error("empty top-level item")
  }
}

///|
fn Parser::parse_attributes(
  self : Parser,
) -> Array[Attribute] raise WeslCompileError {
  let first_token = match self.view() {
    [token, ..] => token
    [] => return []
  }
  let item_source = self.item_source()
  let parsed = @attribute_parse.parse_attributes_source(item_source)
  let attrs : Array[Attribute] = []
  let success = match parsed {
    Parsed(success) => success
    Failed(diagnostic) => {
      let byte_offset = first_token.start() + diagnostic.offset
      if diagnostic.incomplete {
        raise Parse("incomplete attribute list at byte \{byte_offset}")
      }
      raise Parse("invalid attribute list at byte \{byte_offset}")
    }
  }
  let line_base = first_token.line() - 1
  for attr in success.attributes {
    attrs.push({
      name: attr.name,
      arguments: attr.arguments,
      argument_exprs: parser_parse_attribute_argument_exprs(
        attr.name,
        attr.arguments,
        item_source,
      ),
      condition_expr: parser_parse_attribute_condition_expr(
        attr.name,
        attr.arguments,
      ),
      span: {
        start_line: line_base + attr.start_line,
        end_line: line_base + attr.end_line,
      },
    })
  }
  self.update_view_after_offset(first_token.start() + success.consumed_offset)
  attrs
}

///|
fn parser_parse_attribute_argument_exprs(
  name : String,
  arguments : String?,
  item_source : String,
) -> Array[Expression] raise WeslCompileError {
  if name == "if" || name == "elif" || name == "else" {
    return []
  }
  match arguments {
    Some(text) => {
      let expressions : Array[Expression] = []
      for part in parser_split_top_level_commas(text) {
        expressions.push(parser_parse_statement_expression(part, item_source))
      }
      expressions
    }
    None => []
  }
}

///|
fn parser_cond_expression_from_generated(
  node : @cond_expr_parse.CondExprNode,
) -> CondExpression {
  match node {
    Literal(value) => Literal(value)
    Feature(name) => Feature(name)
    Not(inner) => Not(parser_cond_expression_from_generated(inner))
    And(left, right) =>
      And(
        parser_cond_expression_from_generated(left),
        parser_cond_expression_from_generated(right),
      )
    Or(left, right) =>
      Or(
        parser_cond_expression_from_generated(left),
        parser_cond_expression_from_generated(right),
      )
  }
}

///|
fn parser_parse_attribute_condition_expr(
  name : String,
  arguments : String?,
) -> CondExpression? {
  if name != "if" && name != "elif" {
    return None
  }
  match arguments {
    Some(text) =>
      match @cond_expr_parse.parse_cond_expr_source(text) {
        Parsed(node) => Some(parser_cond_expression_from_generated(node))
        Failed(_) => None
      }
    None => None
  }
}

///|
fn Parser::item_is_import(self : Parser) -> Bool raise WeslCompileError {
  let original_position = self.position
  ignore(self.parse_attributes())
  let result = match self.view() {
    [Ident("import", _, _, _), ..] => true
    _ => false
  }
  self.position = original_position
  result
}

///|
fn parser_import_node_from_generated(
  node : @import_parse.ImportParseNode,
) -> ImportNode {
  let children : Array[ImportNode] = []
  for child in node.children {
    children.push(parser_import_node_from_generated(child))
  }
  { path_segments: node.path_segments, rename: node.rename, children }
}

///|
fn parser_struct_members_from_wgsl(
  source : String,
  members : Array[@ast.WgslStructMember],
) -> Array[StructMember] raise WeslCompileError {
  let mapped : Array[StructMember] = []
  for field in members {
    guard field.ty_ref() is Some(ty) else {
      raise Parse("struct member `\{field.name().name()}` has no type")
    }
    let type_text = source[ty.start():ty.end()].trim().to_owned()
    let attribute_text = source[field.start():field.name().start()]
      .trim()
      .to_owned()
    mapped.push({
      name: field.name().name(),
      type_text,
      type_expr: parser_type_expression_from_wgsl(source, ty),
      attributes: if attribute_text == "" {
        []
      } else {
        parser_statement_attributes(attribute_text)
      },
    })
  }
  mapped
}

///|
fn parser_function_parameters_from_generated(
  parameters : Array[@function_parse.FunctionParameterParseNode],
) -> Array[FunctionParameter] raise WeslCompileError {
  let mapped : Array[FunctionParameter] = []
  for parameter in parameters {
    mapped.push({
      name: parameter.name,
      type_text: parameter.type_text,
      type_expr: parser_parse_type_expression(parameter.type_text),
      attributes: if parameter.attributes == "" {
        []
      } else {
        parser_statement_attributes(parameter.attributes)
      },
    })
  }
  mapped
}

///|
fn parser_statement_kind_from_generated(
  kind : @statement_parse.StatementParseKind,
) -> StatementKind {
  match kind {
    Empty => Empty
    Block => Block
    Return => Return
    Discard => Discard
    If => If
    Switch => Switch
    Loop => Loop
    For => For
    While => While
    Continuing => Continuing
    Break => Break
    Continue => Continue
    BreakIf => BreakIf
    ConstAssert => ConstAssert
    Const => Const
    Let => Let
    Var => Var
    Assignment => Assignment
    CompoundAssignment => CompoundAssignment
    Increment => Increment
    Decrement => Decrement
    Call => Call
    Other => Other
  }
}

///|
fn parser_statement_declaration_kind_from_binding(
  kind : @binding_parse.BindingParseKind,
) -> StatementDeclarationKind raise WeslCompileError {
  match kind {
    Const => Const
    Let => Let
    Var => Var
    _ => raise Parse("expected local declaration statement")
  }
}

///|
fn parser_expression_type_source(
  node : @expression_parse.ExpressionTypeParseNode,
) -> String {
  let mut source = ""
  for segment in node.path {
    if source == "" {
      source = segment
    } else {
      source = source + "::" + segment
    }
  }
  if source == "" {
    source = node.ident
  } else {
    source = source + "::" + node.ident
  }
  match node.template_text {
    Some(template_text) => source + "<" + template_text + ">"
    None => source
  }
}

///|
fn parser_type_expression_from_generated(
  node : @expression_parse.ExpressionTypeParseNode,
) -> TypeExpression raise WeslCompileError {
  match node.template_text {
    Some(template_text) => {
      let parsed = parser_parse_type_expression(
        parser_expression_type_source(node),
      )
      {
        path: parsed.path,
        ident: parsed.ident,
        template_text: Some(template_text),
        template_args: parsed.template_args,
      }
    }
    None =>
      {
        path: node.path,
        ident: node.ident,
        template_text: None,
        template_args: [],
      }
  }
}

///|
fn parser_type_expression_from_wgsl(
  source : String,
  node : @ast.WgslTypeRef,
) -> TypeExpression {
  let parts : Array[String] = []
  for part in node.name().split("::") {
    parts.push(part.to_owned())
  }
  let path : Array[String] = []
  for index in 0..<(parts.length() - 1) {
    path.push(parts[index])
  }
  let template_args : Array[TypeTemplateArgument] = []
  for arg in node.template_arguments() {
    match arg {
      Type(ty) if ty.atom().kind() == Numeric =>
        template_args.push(Literal(ty.name()))
      Type(ty) =>
        template_args.push(Type(parser_type_expression_from_wgsl(source, ty)))
      Expression(expr) =>
        template_args.push(
          Literal(source[expr.start():expr.end()].trim().to_owned()),
        )
    }
  }
  { path, ident: parts[parts.length() - 1], template_text: None, template_args }
}

///|
fn parser_parse_type_expression(
  source : String,
) -> TypeExpression raise WeslCompileError {
  match @parser.parse_wgsl_type_ref(source) {
    Some(node) => parser_type_expression_from_wgsl(source, node)
    None => raise Parse("invalid type expression: \{source}")
  }
}

///|
fn parser_parse_optional_type_expression(
  source : String?,
) -> TypeExpression? raise WeslCompileError {
  match source {
    Some(text) => Some(parser_parse_type_expression(text))
    None => None
  }
}

///|
fn parser_parse_optional_initializer_expression(
  source : String?,
  item_source : String,
) -> Expression? raise WeslCompileError {
  match source {
    Some(text) => Some(parser_parse_statement_expression(text, item_source))
    None => None
  }
}

///|
fn parser_function_return_attributes(
  source : String,
) -> Array[Attribute] raise WeslCompileError {
  let mut arrow = -1
  let mut index = 0
  while index + 1 < source.length() {
    let code = source.code_unit_at(index).to_int()
    if code == 123 {
      break
    }
    if code == 45 && source.code_unit_at(index + 1).to_int() == 62 {
      arrow = index
      break
    }
    index += 1
  }
  if arrow < 0 {
    return []
  }
  let attr_start = parser_skip_layout_and_comments(source, arrow + 2)
  let mut cursor = attr_start
  while cursor < source.length() && source.code_unit_at(cursor).to_int() == 64 {
    cursor += 1
    while cursor < source.length() {
      let width = parser_identifier_continue_width(source, cursor)
      if width == 0 {
        break
      }
      cursor += width
    }
    cursor = parser_skip_layout_and_comments(source, cursor)
    if cursor < source.length() && source.code_unit_at(cursor).to_int() == 40 {
      let close = match parser_find_matching_delimiter(source, cursor, 40, 41) {
        Some(end_) => end_
        None => raise Parse("incomplete function return attribute list")
      }
      cursor = close + 1
    }
    cursor = parser_skip_layout_and_comments(source, cursor)
  }
  if cursor == attr_start {
    []
  } else {
    parser_statement_attributes(source[attr_start:cursor].to_owned())
  }
}

///|
fn parser_parse_const_assert_declaration(
  item_source : String,
) -> ConstAssertDeclaration raise WeslCompileError {
  let source = parser_trim_statement_semicolon(
    parser_strip_statement_attributes(item_source),
  )
  let assertion = source[12:].trim().to_owned()
  {
    assertion,
    assertion_expr: parser_parse_statement_expression(assertion, item_source),
  }
}

///|
fn parser_diagnostic_directive_from_arguments(
  arguments : Array[String],
) -> DiagnosticDirectiveDeclaration {
  { arguments, severity: arguments.get(0), rule_name: arguments.get(1) }
}

///|
fn parser_unary_operator_from_generated(
  op : @expression_parse.ExpressionUnaryOperator,
) -> UnaryOperator {
  match op {
    Negation => Negation
    LogicalNegation => LogicalNegation
    BitwiseComplement => BitwiseComplement
    Indirection => Indirection
    AddressOf => AddressOf
  }
}

///|
fn parser_binary_operator_from_generated(
  op : @expression_parse.ExpressionBinaryOperator,
) -> BinaryOperator {
  match op {
    ShortCircuitOr => ShortCircuitOr
    ShortCircuitAnd => ShortCircuitAnd
    BitwiseOr => BitwiseOr
    BitwiseXor => BitwiseXor
    BitwiseAnd => BitwiseAnd
    Equality => Equality
    Inequality => Inequality
    LessThan => LessThan
    LessThanEqual => LessThanEqual
    GreaterThan => GreaterThan
    GreaterThanEqual => GreaterThanEqual
    ShiftLeft => ShiftLeft
    ShiftRight => ShiftRight
    Addition => Addition
    Subtraction => Subtraction
    Multiplication => Multiplication
    Division => Division
    Remainder => Remainder
  }
}

///|
fn parser_assignment_operator_from_text(
  text : String,
) -> AssignmentOperator raise WeslCompileError {
  match text {
    "=" => Equal
    "+=" => PlusEqual
    "-=" => MinusEqual
    "*=" => TimesEqual
    "/=" => DivisionEqual
    "%=" => ModuloEqual
    "&=" => AndEqual
    "|=" => OrEqual
    "^=" => XorEqual
    "<<=" => ShiftLeftAssign
    ">>=" => ShiftRightAssign
    _ => raise Parse("invalid assignment operator `\{text}`")
  }
}

///|
fn parser_expression_from_generated(
  node : @expression_parse.ExpressionParseNode,
) -> Expression raise WeslCompileError {
  match node {
    Literal(text) => Literal(text)
    Bool(value) => Bool(value)
    TypeOrIdentifier(ty) =>
      TypeOrIdentifier(parser_type_expression_from_generated(ty))
    Parenthesized(expr) => Parenthesized(parser_expression_from_generated(expr))
    NamedComponent(base, component) =>
      NamedComponent(parser_expression_from_generated(base), component)
    Indexing(base, index) =>
      Indexing(
        parser_expression_from_generated(base),
        parser_expression_from_generated(index),
      )
    Unary(op, operand) =>
      Unary(
        parser_unary_operator_from_generated(op),
        parser_expression_from_generated(operand),
      )
    Binary(op, left, right) =>
      Binary(
        parser_binary_operator_from_generated(op),
        parser_expression_from_generated(left),
        parser_expression_from_generated(right),
      )
    FunctionCall(call) => {
      let arguments : Array[Expression] = []
      for argument in call.arguments {
        arguments.push(parser_expression_from_generated(argument))
      }
      FunctionCall({
        callee: parser_type_expression_from_generated(call.callee),
        arguments,
      })
    }
  }
}

///|
fn parser_assignment_operator_at_top_level(
  source : String,
) -> (String, Int, Int)? {
  let mut cursor = 0
  let mut paren_depth = 0
  let mut bracket_depth = 0
  let mut brace_depth = 0
  while cursor < source.length() {
    let code = source.code_unit_at(cursor).to_int()
    if code == 40 {
      paren_depth += 1
    } else if code == 41 {
      paren_depth -= 1
    } else if code == 91 {
      bracket_depth += 1
    } else if code == 93 {
      bracket_depth -= 1
    } else if code == 123 {
      brace_depth += 1
    } else if code == 125 {
      brace_depth -= 1
    }
    if paren_depth == 0 && bracket_depth == 0 && brace_depth == 0 {
      let next = if cursor + 1 < source.length() {
        source.code_unit_at(cursor + 1).to_int()
      } else {
        -1
      }
      let after = if cursor + 2 < source.length() {
        source.code_unit_at(cursor + 2).to_int()
      } else {
        -1
      }
      if code == 60 && next == 60 && after == 61 {
        return Some(("<<=", cursor, cursor + 3))
      }
      if code == 62 && next == 62 && after == 61 {
        return Some((">>=", cursor, cursor + 3))
      }
      if (
          code == 43 ||
          code == 45 ||
          code == 42 ||
          code == 47 ||
          code == 37 ||
          code == 38 ||
          code == 124 ||
          code == 94
        ) &&
        next == 61 {
        return Some((source[cursor:cursor + 2].to_owned(), cursor, cursor + 2))
      }
      if code == 61 {
        return Some(("=", cursor, cursor + 1))
      }
    }
    cursor += 1
  }
  None
}

///|
fn parser_parse_statement_expression(
  source : String,
  item_source : String,
) -> Expression raise WeslCompileError {
  match @expression_parse.parse_expression_source(source) {
    Parsed(node) => parser_expression_from_generated(node)
    Failed(diagnostic) => {
      if diagnostic.incomplete {
        raise Parse(
          "incomplete statement expression at byte \{diagnostic.offset}: \{item_source}",
        )
      }
      let message = match diagnostic.message {
        Some(message) => message
        None => "invalid statement expression"
      }
      raise Parse("\{message} at byte \{diagnostic.offset}: \{item_source}")
    }
  }
}

///|
fn parser_parse_assignment_statement(
  source : String,
  item_source : String,
) -> AssignmentStatement raise WeslCompileError {
  match parser_assignment_operator_at_top_level(source) {
    Some((operator, start, end_)) =>
      {
        operator: parser_assignment_operator_from_text(operator),
        lhs: parser_parse_statement_expression(
          source[:start].trim().to_owned(),
          item_source,
        ),
        rhs: parser_parse_statement_expression(
          source[end_:].trim().to_owned(),
          item_source,
        ),
      }
    None => raise Parse("expected assignment operator in statement: \{source}")
  }
}

///|
fn parser_statement_assignment(
  statement : @statement_parse.StatementParseNode,
  item_source : String,
) -> AssignmentStatement? raise WeslCompileError {
  match statement.kind {
    Assignment | CompoundAssignment => {
      let source = parser_trim_statement_semicolon(
        parser_strip_statement_attributes(statement.source),
      )
      Some(parser_parse_assignment_statement(source, item_source))
    }
    _ => None
  }
}

///|
fn parser_statement_update_expression(
  statement : @statement_parse.StatementParseNode,
  item_source : String,
) -> Expression? raise WeslCompileError {
  match statement.kind {
    Increment | Decrement => {
      let source = parser_trim_statement_semicolon(
        parser_strip_statement_attributes(statement.source),
      )
      if source.length() < 2 {
        raise Parse(
          "expected update expression in statement: \{statement.source}",
        )
      }
      Some(
        parser_parse_statement_expression(
          source[:source.length() - 2].trim().to_owned(),
          item_source,
        ),
      )
    }
    _ => None
  }
}

///|
fn parser_skip_layout_and_comments(source : String, index : Int) -> Int {
  let mut cursor = index
  let mut running = true
  while running && cursor < source.length() {
    running = false
    while cursor < source.length() {
      let code = source.code_unit_at(cursor).to_int()
      if code == 32 || code == 9 || code == 10 || code == 13 {
        cursor += 1
        running = true
      } else {
        break
      }
    }
    if cursor + 1 < source.length() &&
      source.code_unit_at(cursor).to_int() == 47 {
      let next = source.code_unit_at(cursor + 1).to_int()
      if next == 47 {
        cursor += 2
        while cursor < source.length() &&
              source.code_unit_at(cursor).to_int() != 10 {
          cursor += 1
        }
        running = true
      } else if next == 42 {
        cursor += 2
        while cursor + 1 < source.length() {
          if source.code_unit_at(cursor).to_int() == 42 &&
            source.code_unit_at(cursor + 1).to_int() == 47 {
            cursor += 2
            break
          }
          cursor += 1
        }
        running = true
      }
    }
  }
  cursor
}

///|
fn parser_find_matching_delimiter(
  source : String,
  open_index : Int,
  open_code : Int,
  close_code : Int,
) -> Int? {
  if open_index >= source.length() ||
    source.code_unit_at(open_index).to_int() != open_code {
    return None
  }
  let mut cursor = open_index + 1
  let mut depth = 1
  while cursor < source.length() {
    let code = source.code_unit_at(cursor).to_int()
    if code == 47 && cursor + 1 < source.length() {
      let next = source.code_unit_at(cursor + 1).to_int()
      if next == 47 {
        cursor += 2
        while cursor < source.length() &&
              source.code_unit_at(cursor).to_int() != 10 {
          cursor += 1
        }
        continue
      }
      if next == 42 {
        cursor += 2
        while cursor + 1 < source.length() {
          if source.code_unit_at(cursor).to_int() == 42 &&
            source.code_unit_at(cursor + 1).to_int() == 47 {
            cursor += 2
            break
          }
          cursor += 1
        }
        continue
      }
    }
    if code == open_code {
      depth += 1
    } else if code == close_code {
      depth -= 1
      if depth == 0 {
        return Some(cursor)
      }
    }
    cursor += 1
  }
  None
}

///|
fn parser_parse_embedded_function_body(
  body_source : String,
  item_source : String,
) -> FunctionBody raise WeslCompileError {
  match @statement_parse.parse_function_body_source(body_source) {
    Parsed(node) =>
      parser_function_body_from_generated(node.statements, item_source)
    Failed(diagnostic) => {
      if diagnostic.incomplete {
        raise Parse(
          "incomplete embedded function body at byte \{diagnostic.offset}: \{item_source}",
        )
      }
      raise Parse(
        "invalid embedded function body at byte \{diagnostic.offset}: \{item_source}",
      )
    }
  }
}

///|
fn parser_parse_braced_statement_body(
  source : String,
  open_index : Int,
  item_source : String,
) -> (FunctionBody, Int) raise WeslCompileError {
  match parser_find_matching_delimiter(source, open_index, 123, 125) {
    Some(close_index) =>
      (
        parser_parse_embedded_function_body(
          source[open_index + 1:close_index].to_owned(),
          item_source,
        ),
        close_index,
      )
    None => raise Parse("expected statement body closing brace: \{item_source}")
  }
}

///|
fn parser_parse_parenthesized_condition(
  source : String,
  open_index : Int,
  item_source : String,
) -> (Expression, Int) raise WeslCompileError {
  match parser_find_matching_delimiter(source, open_index, 40, 41) {
    Some(close_index) =>
      (
        parser_parse_statement_expression(
          source[open_index + 1:close_index].trim().to_owned(),
          item_source,
        ),
        close_index,
      )
    None =>
      raise Parse(
        "expected statement condition closing parenthesis: \{item_source}",
      )
  }
}

///|
fn parser_find_control_body_start(source : String, index : Int) -> Int? {
  let mut cursor = index
  let mut paren_depth = 0
  let mut bracket_depth = 0
  while cursor < source.length() {
    let code = source.code_unit_at(cursor).to_int()
    if code == 47 && cursor + 1 < source.length() {
      let next = source.code_unit_at(cursor + 1).to_int()
      if next == 47 {
        cursor += 2
        while cursor < source.length() &&
              source.code_unit_at(cursor).to_int() != 10 {
          cursor += 1
        }
        continue
      }
      if next == 42 {
        cursor += 2
        while cursor + 1 < source.length() {
          if source.code_unit_at(cursor).to_int() == 42 &&
            source.code_unit_at(cursor + 1).to_int() == 47 {
            cursor += 2
            break
          }
          cursor += 1
        }
        continue
      }
    }
    if code == 40 {
      paren_depth += 1
    } else if code == 41 {
      paren_depth -= 1
    } else if code == 91 {
      bracket_depth += 1
    } else if code == 93 {
      bracket_depth -= 1
    } else if code == 123 && paren_depth == 0 && bracket_depth == 0 {
      return Some(cursor)
    }
    cursor += 1
  }
  None
}

///|
fn parser_parse_control_condition_and_body_start(
  source : String,
  start_index : Int,
  item_source : String,
) -> (Expression, Int) raise WeslCompileError {
  let condition_start = parser_skip_layout_and_comments(source, start_index)
  if condition_start < source.length() &&
    source.code_unit_at(condition_start).to_int() == 40 {
    let (condition, condition_end) = parser_parse_parenthesized_condition(
      source, condition_start, item_source,
    )
    let body_start = parser_skip_layout_and_comments(source, condition_end + 1)
    return (condition, body_start)
  }
  match parser_find_control_body_start(source, condition_start) {
    Some(body_start) =>
      (
        parser_parse_statement_expression(
          source[condition_start:body_start].trim().to_owned(),
          item_source,
        ),
        body_start,
      )
    None =>
      raise Parse(
        "expected statement control body opening brace: \{item_source}",
      )
  }
}

///|
fn parser_split_for_header(
  source : String,
) -> Array[String] raise WeslCompileError {
  let parts : Array[String] = []
  let mut cursor = 0
  let mut part_start = 0
  let mut paren_depth = 0
  let mut bracket_depth = 0
  let mut brace_depth = 0
  while cursor < source.length() {
    let code = source.code_unit_at(cursor).to_int()
    if code == 47 && cursor + 1 < source.length() {
      let next = source.code_unit_at(cursor + 1).to_int()
      if next == 47 {
        cursor += 2
        while cursor < source.length() &&
              source.code_unit_at(cursor).to_int() != 10 {
          cursor += 1
        }
        continue
      }
      if next == 42 {
        cursor += 2
        while cursor + 1 < source.length() {
          if source.code_unit_at(cursor).to_int() == 42 &&
            source.code_unit_at(cursor + 1).to_int() == 47 {
            cursor += 2
            break
          }
          cursor += 1
        }
        continue
      }
    }
    if code == 40 {
      paren_depth += 1
    } else if code == 41 {
      paren_depth -= 1
    } else if code == 91 {
      bracket_depth += 1
    } else if code == 93 {
      bracket_depth -= 1
    } else if code == 123 {
      brace_depth += 1
    } else if code == 125 {
      brace_depth -= 1
    } else if code == 59 &&
      paren_depth == 0 &&
      bracket_depth == 0 &&
      brace_depth == 0 {
      parts.push(source[part_start:cursor].trim().to_owned())
      part_start = cursor + 1
    }
    cursor += 1
  }
  parts.push(source[part_start:].trim().to_owned())
  if parts.length() != 3 {
    raise Parse("expected three for-loop header segments")
  }
  parts
}

///|
fn parser_for_initializer(
  source : String,
  item_source : String,
) -> ForInitializer? raise WeslCompileError {
  let text = source.trim().to_owned()
  if text == "" {
    return None
  }
  let stripped = parser_strip_statement_attributes(text)
  if stripped.has_prefix("const ") ||
    stripped.has_prefix("let ") ||
    stripped.has_prefix("var ") {
    return Some(
      Declaration(parser_parse_statement_declaration(stripped, item_source)),
    )
  }
  match parser_assignment_operator_at_top_level(stripped) {
    Some(_) =>
      Some(Assignment(parser_parse_assignment_statement(stripped, item_source)))
    None =>
      Some(Expression(parser_parse_statement_expression(stripped, item_source)))
  }
}

///|
fn parser_for_update(
  source : String,
  item_source : String,
) -> ForUpdate? raise WeslCompileError {
  let text = parser_trim_statement_semicolon(
    parser_strip_statement_attributes(source),
  )
  if text == "" {
    return None
  }
  if text.has_suffix("++") {
    return Some(
      Increment(
        parser_parse_statement_expression(
          text[:text.length() - 2].trim().to_owned(),
          item_source,
        ),
      ),
    )
  }
  if text.has_suffix("--") {
    return Some(
      Decrement(
        parser_parse_statement_expression(
          text[:text.length() - 2].trim().to_owned(),
          item_source,
        ),
      ),
    )
  }
  match parser_assignment_operator_at_top_level(text) {
    Some(_) =>
      Some(Assignment(parser_parse_assignment_statement(text, item_source)))
    None =>
      Some(Expression(parser_parse_statement_expression(text, item_source)))
  }
}

///|
fn parser_keyword_at(source : String, index : Int, keyword : String) -> Bool {
  if index + keyword.length() > source.length() {
    return false
  }
  if source[index:index + keyword.length()] != keyword {
    return false
  }
  let before_ok = if index == 0 {
    true
  } else {
    !parser_identifier_continues_before(source, index)
  }
  let after = index + keyword.length()
  let after_ok = if after >= source.length() {
    true
  } else {
    parser_identifier_continue_width(source, after) == 0
  }
  before_ok && after_ok
}

///|
fn parser_find_switch_clause_header_end(
  source : String,
  index : Int,
) -> (Int, Int)? {
  let mut cursor = index
  let mut paren_depth = 0
  let mut bracket_depth = 0
  while cursor < source.length() {
    let code = source.code_unit_at(cursor).to_int()
    if code == 47 && cursor + 1 < source.length() {
      let next = source.code_unit_at(cursor + 1).to_int()
      if next == 47 {
        cursor += 2
        while cursor < source.length() &&
              source.code_unit_at(cursor).to_int() != 10 {
          cursor += 1
        }
        continue
      }
      if next == 42 {
        cursor += 2
        while cursor + 1 < source.length() {
          if source.code_unit_at(cursor).to_int() == 42 &&
            source.code_unit_at(cursor + 1).to_int() == 47 {
            cursor += 2
            break
          }
          cursor += 1
        }
        continue
      }
    }
    if code == 40 {
      paren_depth += 1
    } else if code == 41 {
      paren_depth -= 1
    } else if code == 91 {
      bracket_depth += 1
    } else if code == 93 {
      bracket_depth -= 1
    } else if paren_depth == 0 && bracket_depth == 0 {
      if code == 58 {
        return Some(
          (cursor, parser_skip_layout_and_comments(source, cursor + 1)),
        )
      }
      if code == 123 {
        return Some((cursor, cursor))
      }
    }
    cursor += 1
  }
  None
}

///|
fn parser_skip_switch_clause_attributes(source : String, index : Int) -> Int {
  let mut cursor = parser_skip_layout_and_comments(source, index)
  let mut running = true
  while running && cursor < source.length() {
    running = false
    if source.code_unit_at(cursor).to_int() == 64 {
      cursor += 1
      let start_width = parser_identifier_start_width(source, cursor)
      if start_width == 0 {
        return index
      }
      cursor += start_width
      while cursor < source.length() {
        let width = parser_identifier_continue_width(source, cursor)
        if width == 0 {
          break
        }
        cursor += width
      }
      cursor = parser_skip_layout_and_comments(source, cursor)
      if cursor < source.length() && source.code_unit_at(cursor).to_int() == 40 {
        let (end_, ok) = parser_skip_balanced_attribute_arguments(
          source,
          cursor + 1,
        )
        if !ok {
          return index
        }
        cursor = end_
      }
      cursor = parser_skip_layout_and_comments(source, cursor)
      running = true
    }
  }
  cursor
}

///|
fn parser_switch_clause_header_at(source : String, index : Int) -> Int? {
  let header = parser_skip_switch_clause_attributes(source, index)
  if parser_keyword_at(source, header, "case") ||
    parser_keyword_at(source, header, "default") {
    Some(header)
  } else {
    None
  }
}

///|
fn parser_find_next_switch_clause(source : String, index : Int) -> Int {
  let mut cursor = index
  let mut paren_depth = 0
  let mut bracket_depth = 0
  let mut brace_depth = 0
  while cursor < source.length() {
    let code = source.code_unit_at(cursor).to_int()
    if code == 47 && cursor + 1 < source.length() {
      let next = source.code_unit_at(cursor + 1).to_int()
      if next == 47 {
        cursor += 2
        while cursor < source.length() &&
              source.code_unit_at(cursor).to_int() != 10 {
          cursor += 1
        }
        continue
      }
      if next == 42 {
        cursor += 2
        while cursor + 1 < source.length() {
          if source.code_unit_at(cursor).to_int() == 42 &&
            source.code_unit_at(cursor + 1).to_int() == 47 {
            cursor += 2
            break
          }
          cursor += 1
        }
        continue
      }
    }
    if code == 40 {
      paren_depth += 1
    } else if code == 41 {
      paren_depth -= 1
    } else if code == 91 {
      bracket_depth += 1
    } else if code == 93 {
      bracket_depth -= 1
    } else if code == 123 {
      brace_depth += 1
    } else if code == 125 {
      brace_depth -= 1
    }
    if paren_depth == 0 && bracket_depth == 0 && brace_depth == 0 {
      if parser_switch_clause_header_at(source, cursor) is Some(_) {
        return cursor
      }
    }
    cursor += 1
  }
  source.length()
}

///|
fn parser_split_top_level_commas(source : String) -> Array[String] {
  let parts : Array[String] = []
  let mut cursor = 0
  let mut part_start = 0
  let mut paren_depth = 0
  let mut bracket_depth = 0
  let mut brace_depth = 0
  while cursor < source.length() {
    let code = source.code_unit_at(cursor).to_int()
    if code == 40 {
      paren_depth += 1
    } else if code == 41 {
      paren_depth -= 1
    } else if code == 91 {
      bracket_depth += 1
    } else if code == 93 {
      bracket_depth -= 1
    } else if code == 123 {
      brace_depth += 1
    } else if code == 125 {
      brace_depth -= 1
    } else if code == 44 &&
      paren_depth == 0 &&
      bracket_depth == 0 &&
      brace_depth == 0 {
      parts.push(source[part_start:cursor].trim().to_owned())
      part_start = cursor + 1
    }
    cursor += 1
  }
  let tail = source[part_start:].trim().to_owned()
  if tail != "" {
    parts.push(tail)
  }
  parts
}

///|
fn parser_parse_switch_selectors(
  source : String,
  item_source : String,
) -> Array[Expression] raise WeslCompileError {
  let selectors : Array[Expression] = []
  for selector in parser_split_top_level_commas(source) {
    selectors.push(parser_parse_statement_expression(selector, item_source))
  }
  selectors
}

///|
fn parser_parse_switch_case_body(
  source : String,
  item_source : String,
) -> FunctionBody raise WeslCompileError {
  let trimmed = source.trim().to_owned()
  let body_start = parser_skip_layout_and_comments(trimmed, 0)
  if body_start < trimmed.length() &&
    trimmed.code_unit_at(body_start).to_int() == 123 {
    match parser_find_matching_delimiter(trimmed, body_start, 123, 125) {
      Some(close_index) => {
        let after_body = parser_skip_layout_and_comments(
          trimmed,
          close_index + 1,
        )
        if after_body == trimmed.length() {
          return parser_parse_embedded_function_body(
            trimmed[body_start + 1:close_index].to_owned(),
            item_source,
          )
        }
      }
      None => ()
    }
  }
  parser_parse_embedded_function_body(trimmed, item_source)
}

///|
fn parser_parse_switch_cases(
  source : String,
  item_source : String,
) -> Array[SwitchCase] raise WeslCompileError {
  let cases : Array[SwitchCase] = []
  let mut cursor = parser_skip_layout_and_comments(source, 0)
  while cursor < source.length() {
    let header = match parser_switch_clause_header_at(source, cursor) {
      Some(header) => header
      None =>
        raise Parse("expected switch case or default clause: \{item_source}")
    }
    let is_default = parser_keyword_at(source, header, "default")
    let keyword_len = if is_default {
      7
    } else if parser_keyword_at(source, header, "case") {
      4
    } else {
      raise Parse("expected switch case or default clause: \{item_source}")
    }
    let header_start = parser_skip_layout_and_comments(
      source,
      header + keyword_len,
    )
    let (header_end, body_start) = match
      parser_find_switch_clause_header_end(source, header_start) {
      Some(result) => result
      None => raise Parse("expected switch clause body: \{item_source}")
    }
    let selectors = if is_default {
      []
    } else {
      parser_parse_switch_selectors(
        source[header_start:header_end].trim().to_owned(),
        item_source,
      )
    }
    let body_end = parser_find_next_switch_clause(source, body_start)
    cases.push({
      selectors,
      is_default,
      body: parser_parse_switch_case_body(
        source[body_start:body_end].trim().to_owned(),
        item_source,
      ),
      attributes: parser_statement_attributes(source[cursor:header].to_owned()),
    })
    cursor = parser_skip_layout_and_comments(source, body_end)
  }
  cases
}

///|
fn parser_statement_block_control(
  source : String,
  item_source : String,
) -> ControlStatement raise WeslCompileError {
  let body_start = parser_skip_layout_and_comments(source, 0)
  let (body, _) = parser_parse_braced_statement_body(
    source, body_start, item_source,
  )
  Block({ body, })
}

///|
fn parser_statement_loop_control(
  source : String,
  item_source : String,
) -> ControlStatement raise WeslCompileError {
  let body_start = parser_skip_layout_and_comments(source, 4)
  let (body, _) = parser_parse_braced_statement_body(
    source, body_start, item_source,
  )
  Loop({ body, })
}

///|
fn parser_statement_for_control(
  source : String,
  item_source : String,
) -> ControlStatement raise WeslCompileError {
  let header_start = parser_skip_layout_and_comments(source, 3)
  match parser_find_matching_delimiter(source, header_start, 40, 41) {
    Some(header_end) => {
      let parts = parser_split_for_header(
        source[header_start + 1:header_end].to_owned(),
      )
      let condition : Expression? = if parts[1] == "" {
        None
      } else {
        Some(parser_parse_statement_expression(parts[1], item_source))
      }
      let body_start = parser_skip_layout_and_comments(source, header_end + 1)
      let (body, _) = parser_parse_braced_statement_body(
        source, body_start, item_source,
      )
      For({
        initializer: parser_for_initializer(parts[0], item_source),
        condition,
        update: parser_for_update(parts[2], item_source),
        body,
      })
    }
    None =>
      raise Parse(
        "expected for-loop header closing parenthesis: \{item_source}",
      )
  }
}

///|
fn parser_statement_switch_control(
  source : String,
  item_source : String,
) -> ControlStatement raise WeslCompileError {
  let (selector, body_start) = parser_parse_control_condition_and_body_start(
    source, 6, item_source,
  )
  let body_end = match
    parser_find_matching_delimiter(source, body_start, 123, 125) {
    Some(body_end) => body_end
    None => raise Parse("expected switch body closing brace: \{item_source}")
  }
  Switch({
    selector,
    cases: parser_parse_switch_cases(
      source[body_start + 1:body_end].to_owned(),
      item_source,
    ),
  })
}

///|
fn parser_statement_continuing_control(
  source : String,
  item_source : String,
) -> ControlStatement raise WeslCompileError {
  let body_start = parser_skip_layout_and_comments(source, 10)
  let (body, _) = parser_parse_braced_statement_body(
    source, body_start, item_source,
  )
  Continuing({ body, })
}

///|
fn parser_statement_while_control(
  source : String,
  item_source : String,
) -> ControlStatement raise WeslCompileError {
  let (condition, body_start) = parser_parse_control_condition_and_body_start(
    source, 5, item_source,
  )
  let (body, _) = parser_parse_braced_statement_body(
    source, body_start, item_source,
  )
  While({ condition, body })
}

///|
fn parser_statement_if_control(
  source : String,
  item_source : String,
) -> ControlStatement raise WeslCompileError {
  let (condition, body_start) = parser_parse_control_condition_and_body_start(
    source, 2, item_source,
  )
  let (body, body_end) = parser_parse_braced_statement_body(
    source, body_start, item_source,
  )
  let after_body = parser_skip_layout_and_comments(source, body_end + 1)
  let else_body = if source[after_body:].trim().has_prefix("else") {
    let else_start = parser_skip_layout_and_comments(source, after_body + 4)
    if else_start < source.length() &&
      source.code_unit_at(else_start).to_int() == 123 {
      let (body, _) = parser_parse_braced_statement_body(
        source, else_start, item_source,
      )
      Some(body)
    } else {
      Some(
        parser_parse_embedded_function_body(
          source[else_start:].trim().to_owned(),
          item_source,
        ),
      )
    }
  } else {
    None
  }
  If({ condition, body, else_body })
}

///|
fn parser_statement_control(
  statement : @statement_parse.StatementParseNode,
  item_source : String,
) -> ControlStatement? raise WeslCompileError {
  let source = parser_strip_statement_attributes(statement.source)
  match statement.kind {
    Block => Some(parser_statement_block_control(source, item_source))
    If => Some(parser_statement_if_control(source, item_source))
    Switch => Some(parser_statement_switch_control(source, item_source))
    Loop => Some(parser_statement_loop_control(source, item_source))
    For => Some(parser_statement_for_control(source, item_source))
    While => Some(parser_statement_while_control(source, item_source))
    Continuing => Some(parser_statement_continuing_control(source, item_source))
    _ => None
  }
}

///|
fn parser_statement_attributes(
  source : String,
) -> Array[Attribute] raise WeslCompileError {
  match @attribute_parse.parse_attributes_source(source) {
    Parsed(success) => {
      let attrs : Array[Attribute] = []
      for attr in success.attributes {
        attrs.push({
          name: attr.name,
          arguments: attr.arguments,
          argument_exprs: parser_parse_attribute_argument_exprs(
            attr.name,
            attr.arguments,
            source,
          ),
          condition_expr: parser_parse_attribute_condition_expr(
            attr.name,
            attr.arguments,
          ),
          span: { start_line: attr.start_line, end_line: attr.end_line },
        })
      }
      attrs
    }
    Failed(diagnostic) => {
      if diagnostic.incomplete {
        raise Parse(
          "incomplete statement attribute list at byte \{diagnostic.offset}",
        )
      }
      raise Parse(
        "invalid statement attribute list at byte \{diagnostic.offset}",
      )
    }
  }
}

///|
fn parser_trim_statement_semicolon(source : String) -> String {
  let trimmed = source.trim().to_owned()
  if trimmed.has_suffix(";") {
    trimmed[:trimmed.length() - 1].trim().to_owned()
  } else {
    trimmed
  }
}

///|
fn parser_skip_balanced_attribute_arguments(
  source : String,
  index : Int,
) -> (Int, Bool) {
  let mut cursor = index
  let mut depth = 1
  while cursor < source.length() {
    let code = source.code_unit_at(cursor).to_int()
    if code == 40 {
      depth += 1
    } else if code == 41 {
      depth -= 1
      if depth == 0 {
        return (cursor + 1, true)
      }
    }
    cursor += 1
  }
  (cursor, false)
}

///|
fn parser_strip_statement_attributes(source : String) -> String {
  let mut cursor = 0
  while cursor < source.length() {
    while cursor < source.length() {
      let code = source.code_unit_at(cursor).to_int()
      if code == 32 || code == 9 || code == 10 || code == 13 {
        cursor += 1
      } else {
        break
      }
    }
    if cursor >= source.length() || source.code_unit_at(cursor).to_int() != 64 {
      break
    }
    cursor += 1
    let start_width = parser_identifier_start_width(source, cursor)
    if start_width == 0 {
      break
    }
    cursor += start_width
    while cursor < source.length() {
      let width = parser_identifier_continue_width(source, cursor)
      if width == 0 {
        break
      }
      cursor += width
    }
    while cursor < source.length() {
      let code = source.code_unit_at(cursor).to_int()
      if code == 32 || code == 9 || code == 10 || code == 13 {
        cursor += 1
      } else {
        break
      }
    }
    if cursor < source.length() && source.code_unit_at(cursor).to_int() == 40 {
      let (end_, ok) = parser_skip_balanced_attribute_arguments(
        source,
        cursor + 1,
      )
      if !ok {
        break
      }
      cursor = end_
    }
  }
  source[cursor:].trim().to_owned()
}

///|
fn parser_statement_expression(
  statement : @statement_parse.StatementParseNode,
  item_source : String,
) -> Expression? raise WeslCompileError {
  let source = parser_trim_statement_semicolon(
    parser_strip_statement_attributes(statement.source),
  )
  match statement.kind {
    Return => {
      let rest = source[6:].trim().to_owned()
      if rest == "" {
        None
      } else {
        Some(parser_parse_statement_expression(rest, item_source))
      }
    }
    ConstAssert =>
      Some(
        parser_parse_statement_expression(
          source[12:].trim().to_owned(),
          item_source,
        ),
      )
    BreakIf =>
      Some(
        parser_parse_statement_expression(
          source[8:].trim().to_owned(),
          item_source,
        ),
      )
    Call => Some(parser_parse_statement_expression(source, item_source))
    _ => None
  }
}

///|
fn parser_parse_statement_declaration(
  source : String,
  item_source : String,
) -> StatementDeclaration raise WeslCompileError {
  let binding = match @binding_parse.parse_binding_source(source) {
    Parsed(node) => node
    Failed(diagnostic) => {
      if diagnostic.incomplete {
        raise Parse(
          "incomplete statement declaration at byte \{diagnostic.offset}: \{item_source}",
        )
      }
      raise Parse(
        "invalid statement declaration at byte \{diagnostic.offset}: \{item_source}",
      )
    }
  }
  {
    kind: parser_statement_declaration_kind_from_binding(binding.kind),
    name: binding.name,
    template_arguments: binding.var_template,
    type_text: binding.type_text,
    type_expr: parser_parse_optional_type_expression(binding.type_text),
    initializer: binding.initializer,
    initializer_expr: match binding.initializer {
      Some(expr) => Some(parser_parse_statement_expression(expr, item_source))
      None => None
    },
  }
}

///|
fn parser_statement_declaration(
  statement : @statement_parse.StatementParseNode,
  item_source : String,
) -> StatementDeclaration? raise WeslCompileError {
  match statement.kind {
    Const | Let | Var =>
      Some(
        parser_parse_statement_declaration(
          parser_strip_statement_attributes(statement.source),
          item_source,
        ),
      )
    _ => None
  }
}

///|
fn parser_function_body_from_generated(
  statements : Array[@statement_parse.StatementParseNode],
  item_source : String,
) -> FunctionBody raise WeslCompileError {
  let mapped : Array[Statement] = []
  for statement in statements {
    mapped.push({
      kind: parser_statement_kind_from_generated(statement.kind),
      source: statement.source,
      expression: parser_statement_expression(statement, item_source),
      declaration: parser_statement_declaration(statement, item_source),
      assignment: parser_statement_assignment(statement, item_source),
      update_expression: parser_statement_update_expression(
        statement, item_source,
      ),
      control: parser_statement_control(statement, item_source),
      attributes: parser_statement_attributes(statement.source),
    })
  }
  { statements: mapped }
}

///|
fn Parser::parse_function_body_with_yacc(
  self : Parser,
  body_source : String,
  item_source : String,
) -> FunctionBody raise WeslCompileError {
  match @statement_parse.parse_function_body_source(body_source) {
    Parsed(node) =>
      parser_function_body_from_generated(node.statements, item_source)
    Failed(diagnostic) => {
      let byte_offset = if self.tokens.length() > 0 {
        self.tokens[0].start() + diagnostic.offset
      } else {
        diagnostic.offset
      }
      if diagnostic.incomplete {
        raise Parse(
          "incomplete function body at byte \{byte_offset}: \{item_source}",
        )
      }
      raise Parse(
        "invalid function body at byte \{byte_offset}: \{item_source}",
      )
    }
  }
}

///|
fn Parser::parse_binding_with_yacc(
  self : Parser,
  item_source : String,
) -> @binding_parse.BindingParseNode raise WeslCompileError {
  match @binding_parse.parse_binding_source(item_source) {
    Parsed(node) => node
    Failed(diagnostic) => {
      let byte_offset = if self.tokens.length() > 0 {
        self.tokens[0].start() + diagnostic.offset
      } else {
        diagnostic.offset
      }
      if diagnostic.incomplete {
        raise Parse(
          "incomplete binding declaration at byte \{byte_offset}: \{item_source}",
        )
      }
      raise Parse(
        "invalid binding declaration at byte \{byte_offset}: \{item_source}",
      )
    }
  }
}

///|
fn Parser::parse_directive_with_yacc(
  self : Parser,
  item_source : String,
) -> @directive_parse.DirectiveParseNode raise WeslCompileError {
  match @directive_parse.parse_directive_source(item_source) {
    Parsed(node) => node
    Failed(diagnostic) => {
      let byte_offset = if self.tokens.length() > 0 {
        self.tokens[0].start() + diagnostic.offset
      } else {
        diagnostic.offset
      }
      if diagnostic.incomplete {
        raise Parse(
          "incomplete directive at byte \{byte_offset}: \{item_source}",
        )
      }
      raise Parse("invalid directive at byte \{byte_offset}: \{item_source}")
    }
  }
}

///|
fn Parser::parse_import_tree_with_yacc(
  self : Parser,
  context : String,
  item_source : String,
) -> Array[ImportNode] raise WeslCompileError {
  let first_start = match self.view() {
    [token, ..] => token.start()
    [] =>
      raise Parse("unsupported import statement (\{context}): \{item_source}")
  }
  let tree_end = match self.tokens.last() {
    Some(Semi(start, _, _)) => start
    _ =>
      raise Parse("unsupported import statement (\{context}): \{item_source}")
  }
  let tree_source = self.source_slice(first_start, tree_end)
  let parsed = @import_parse.parse_import_tree_source(tree_source)
  let generated_items = match parsed {
    Parsed(nodes) => nodes
    Failed(diagnostic) => {
      let byte_offset = first_start + diagnostic.offset
      if diagnostic.incomplete {
        raise Parse(
          "incomplete import statement at byte \{byte_offset} (\{context}): \{item_source}",
        )
      }
      raise Parse(
        "invalid import statement at byte \{byte_offset} (\{context}): \{item_source}",
      )
    }
  }
  let items : Array[ImportNode] = []
  for item in generated_items {
    items.push(parser_import_node_from_generated(item))
  }
  while true {
    match self.view() {
      [Semi(_, _, _), ..] => break
      [_, .. rest] => self.update_view(rest)
      [] =>
        raise Parse("unsupported import statement (\{context}): \{item_source}")
    }
  }
  items
}

///|
fn Parser::parse_import_statement(
  self : Parser,
  current_path : ModulePath,
) -> ImportStatement raise WeslCompileError {
  let item_source = self.item_source().trim().to_owned()
  let span = self.item_span()
  let context = span.context(current_path)
  guard self.tokens.last() is Some(Semi(_, _, _)) else {
    raise Parse("unsupported import statement (\{context}): \{item_source}")
  }
  let attrs = self.parse_attributes() catch {
    Parse(reason) => raise Parse("\{reason} (\{context})")
    err => raise err
  }
  guard self.view() is [Ident("import", _, _, _), .. after_import] else {
    raise Parse("unsupported import statement (\{context}): \{item_source}")
  }
  self.update_view(after_import)
  let items = self.parse_import_tree_with_yacc(context, item_source)
  if items.is_empty() {
    raise Parse("unsupported import statement (\{context}): \{item_source}")
  }
  let statement = ImportStatement::{
    span,
    attributes: attrs,
    entries: items,
    source: item_source,
  }
  ignore(statement.flatten_items(current_path))
  statement
}

///|
fn Parser::parse_global_declaration(
  self : Parser,
) -> GlobalDeclaration raise WeslCompileError {
  let span = self.item_span()
  let item_source = self.item_source().trim().to_owned()
  let attrs = self.parse_attributes()
  let parsed = @global_parse.parse_global_header_source(item_source)
  let header = match parsed {
    Parsed(Function(name)) => {
      parser_validate_declaration_ident(name)
      let function_node = match
        @function_parse.parse_function_source(item_source) {
        Parsed(node) => node
        Failed(diagnostic) => {
          let byte_offset = if self.tokens.length() > 0 {
            self.tokens[0].start() + diagnostic.offset
          } else {
            diagnostic.offset
          }
          if diagnostic.incomplete {
            raise Parse(
              "incomplete function declaration at byte \{byte_offset}: \{item_source}",
            )
          }
          raise Parse(
            "invalid function declaration at byte \{byte_offset}: \{item_source}",
          )
        }
      }
      GlobalDeclarationHeader::Function({
        name,
        generic_parameters: function_node.generic_parameters,
        parameters: parser_function_parameters_from_generated(
          function_node.parameters,
        ),
        return_type: function_node.return_type,
        return_type_expr: parser_parse_optional_type_expression(
          function_node.return_type,
        ),
        return_attributes: parser_function_return_attributes(item_source),
        body: self.parse_function_body_with_yacc(
          function_node.body_text,
          item_source,
        ),
      })
    }
    Parsed(Struct(name)) => {
      parser_validate_declaration_ident(name)
      let struct_ = match @parser.parse_wgsl_struct(item_source) {
        Some(struct_) => struct_
        None => raise Parse("invalid struct declaration: \{item_source}")
      }
      let members = parser_struct_members_from_wgsl(
        item_source,
        struct_.members(),
      )
      Struct({ name, members })
    }
    Parsed(Alias(name)) => {
      parser_validate_declaration_ident(name)
      let binding = self.parse_binding_with_yacc(item_source)
      Alias({
        name,
        target: binding.type_text,
        target_type: parser_parse_optional_type_expression(binding.type_text),
      })
    }
    Parsed(Const(name)) => {
      parser_validate_declaration_ident(name)
      let binding = self.parse_binding_with_yacc(item_source)
      Const({
        name,
        type_text: binding.type_text,
        type_expr: parser_parse_optional_type_expression(binding.type_text),
        initializer: binding.initializer,
        initializer_expr: parser_parse_optional_initializer_expression(
          binding.initializer,
          item_source,
        ),
      })
    }
    Parsed(Override(name)) => {
      parser_validate_declaration_ident(name)
      let binding = self.parse_binding_with_yacc(item_source)
      Override({
        name,
        type_text: binding.type_text,
        type_expr: parser_parse_optional_type_expression(binding.type_text),
        initializer: binding.initializer,
        initializer_expr: parser_parse_optional_initializer_expression(
          binding.initializer,
          item_source,
        ),
      })
    }
    Parsed(Let(name)) => {
      parser_validate_declaration_ident(name)
      let binding = self.parse_binding_with_yacc(item_source)
      Let({
        name,
        type_text: binding.type_text,
        type_expr: parser_parse_optional_type_expression(binding.type_text),
        initializer: binding.initializer,
        initializer_expr: parser_parse_optional_initializer_expression(
          binding.initializer,
          item_source,
        ),
      })
    }
    Parsed(Var(var_header)) => {
      match var_header.name {
        Some(name) => parser_validate_declaration_ident(name)
        None => ()
      }
      let binding = self.parse_binding_with_yacc(item_source)
      Var({
        name: var_header.name,
        template_arguments: binding.var_template,
        type_text: binding.type_text,
        type_expr: parser_parse_optional_type_expression(binding.type_text),
        initializer: binding.initializer,
        initializer_expr: parser_parse_optional_initializer_expression(
          binding.initializer,
          item_source,
        ),
      })
    }
    Parsed(ConstAssert) =>
      ConstAssert(parser_parse_const_assert_declaration(item_source))
    Parsed(EnableDirective) => {
      let directive = self.parse_directive_with_yacc(item_source)
      EnableDirective({ names: directive.arguments })
    }
    Parsed(RequiresDirective) => {
      let directive = self.parse_directive_with_yacc(item_source)
      RequiresDirective({ names: directive.arguments })
    }
    Parsed(DiagnosticDirective) => {
      let directive = self.parse_directive_with_yacc(item_source)
      DiagnosticDirective(
        parser_diagnostic_directive_from_arguments(directive.arguments),
      )
    }
    Parsed(Other) => Other
    Failed(diagnostic) => {
      let byte_offset = if self.tokens.length() > 0 {
        self.tokens[0].start() + diagnostic.offset
      } else {
        diagnostic.offset
      }
      if diagnostic.incomplete {
        raise Parse(
          "incomplete global declaration at byte \{byte_offset}: \{item_source}",
        )
      }
      raise Parse(
        "invalid global declaration at byte \{byte_offset}: \{item_source}",
      )
    }
  }
  { header, attributes: attrs, source: item_source, span }
}

///|
fn parser_top_level_item_parsers(
  source : String,
) -> Array[Parser] raise WeslCompileError {
  let root_parser = Parser::new(source)
  let spans = match @item_parse.parse_top_level_items_source(source) {
    Parsed(spans) => spans
    Failed(diagnostic) => {
      if diagnostic.incomplete {
        raise Parse(
          "unexpected end of top-level item at byte \{diagnostic.offset}",
        )
      }
      raise Parse("invalid top-level item at byte \{diagnostic.offset}")
    }
  }
  let parsers : Array[Parser] = []
  for span in spans {
    let tokens : Array[ParserToken] = []
    for token in root_parser.tokens {
      if token.start() >= span.start_offset && token.end() <= span.end_offset {
        tokens.push(token)
      }
    }
    if !tokens.is_empty() {
      parsers.push(Parser::from_tokens(source, tokens))
    }
  }
  parsers
}

///|
pub fn parse_global_declarations(
  source : String,
) -> Array[GlobalDeclaration] raise WeslCompileError {
  let declarations : Array[GlobalDeclaration] = []
  for item_parser in parser_top_level_item_parsers(source) {
    if item_parser.item_is_import() {
      continue
    }
    declarations.push(item_parser.parse_global_declaration())
  }
  declarations
}

///|
pub fn parse_translation_unit(
  current_path : ModulePath,
  source : String,
  parse_imports : Bool,
) -> TranslationUnit raise WeslCompileError {
  let imports : Array[ImportStatement] = []
  let global_declarations : Array[GlobalDeclaration] = []
  for item_parser in parser_top_level_item_parsers(source) {
    if item_parser.item_is_import() {
      if parse_imports {
        imports.push(item_parser.parse_import_statement(current_path))
      }
      continue
    }
    global_declarations.push(item_parser.parse_global_declaration())
  }
  { imports, global_declarations }
}
