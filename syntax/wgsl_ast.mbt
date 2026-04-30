///|
pub(all) enum WgslGlobalDeclKind {
  Directive
  Import
  Function
  GlobalVariable
  Const
  Override
  Struct
  TypeAlias
  ConstAssert
  Trivia
  Unknown
} derive(Eq, Debug)

///|
pub(all) struct WgslIdent {
  name : String
  start : Int
  end : Int
} derive(Debug)

///|
pub(all) struct WgslExprRef {
  text : String
  identifiers : Array[WgslIdent]
  start : Int
  end : Int
} derive(Debug)

///|
pub(all) struct WgslAttribute {
  name : String
  arguments : String
  arguments_ref : WgslExprRef?
} derive(Debug)

///|
pub(all) struct WgslTypeRef {
  name : String
  arguments : Array[WgslTypeRef]
  text : String
  start : Int
  end : Int
} derive(Debug)

///|
pub(all) struct WgslFunctionArgument {
  attributes : Array[WgslAttribute]
  name : String
  name_start : Int
  name_end : Int
  ty : String
  ty_ref : WgslTypeRef?
} derive(Debug)

///|
pub(all) struct WgslFunctionResult {
  attributes : Array[WgslAttribute]
  ty : String
  ty_ref : WgslTypeRef?
} derive(Debug)

///|
pub(all) enum WgslStatementKind {
  LocalDecl
  Block
  If
  Switch
  Loop
  Break
  Continue
  Return
  ConstAssert
  Raw
} derive(Eq, Debug)

///|
pub(all) struct WgslStatement {
  kind : WgslStatementKind
  text : String
  local_name : String?
  identifiers : Array[WgslIdent]
  start : Int
  end : Int
} derive(Debug)

///|
pub(all) struct WgslBlock {
  statements : Array[WgslStatement]
} derive(Debug)

///|
pub(all) struct WgslFunction {
  attributes : Array[WgslAttribute]
  qualifier : String
  qualifier_start : Int?
  qualifier_end : Int?
  fn_start : Int
  fn_end : Int
  name : WgslIdent
  arguments : Array[WgslFunctionArgument]
  result : WgslFunctionResult?
  body : WgslBlock
} derive(Debug)

///|
pub(all) struct WgslStructMember {
  attributes : Array[WgslAttribute]
  name : String
  name_start : Int
  name_end : Int
  ty : String
  ty_ref : WgslTypeRef?
} derive(Debug)

///|
pub(all) struct WgslStruct {
  attributes : Array[WgslAttribute]
  name : WgslIdent
  members : Array[WgslStructMember]
} derive(Debug)

///|
pub(all) struct WgslGlobalVariable {
  attributes : Array[WgslAttribute]
  name : WgslIdent
  template_list : Array[String]
  ty : String?
  ty_ref : WgslTypeRef?
  initializer : String?
  initializer_ref : WgslExprRef?
} derive(Debug)

///|
pub(all) struct WgslConst {
  name : WgslIdent
  ty : String?
  ty_ref : WgslTypeRef?
  initializer : String?
  initializer_ref : WgslExprRef?
} derive(Debug)

///|
pub(all) struct WgslOverride {
  attributes : Array[WgslAttribute]
  name : WgslIdent
  ty : String?
  ty_ref : WgslTypeRef?
  initializer : String?
  initializer_ref : WgslExprRef?
} derive(Debug)

///|
pub(all) struct WgslTypeAlias {
  name : WgslIdent
  ty : String
  ty_ref : WgslTypeRef?
} derive(Debug)

///|
pub(all) enum WgslGlobalDeclData {
  Directive(WgslDirective)
  Import(WgslDirective)
  Function(WgslFunction)
  GlobalVariable(WgslGlobalVariable)
  Const(WgslConst)
  Override(WgslOverride)
  Struct(WgslStruct)
  TypeAlias(WgslTypeAlias)
  ConstAssert(WgslExprRef)
  Raw
} derive(Debug)

///|
pub(all) struct WgslGlobalDecl {
  kind : WgslGlobalDeclKind
  data : WgslGlobalDeclData
  name : String
  text : String
  start : Int
  end : Int
}

///|
pub(all) struct WgslTranslationUnit {
  declarations : Array[WgslGlobalDecl]
}

///|
fn wgsl_ast_token_end(token : Token) -> Int {
  match token {
    Token::Identifier(text, pos) | Token::Whitespace(text, pos) =>
      pos + text.length()
    Token::Other(_, pos) => pos + 1
  }
}

///|
fn parse_wgsl_expr_ref_text(text : String, base : Int) -> WgslExprRef? {
  let (trimmed, local_start, local_end) = wgsl_trim_fragment_bounds(
    text,
    0,
    text.length(),
  )
  if trimmed == "" {
    return None
  }
  let identifiers : Array[WgslIdent] = []
  for token in tokenize(replace_comments(trimmed), false) {
    match token {
      Token::Identifier(name, pos) =>
        identifiers.push(WgslIdent::{
          name,
          start: base + local_start + pos,
          end: base + local_start + pos + name.length(),
        })
      _ => ()
    }
  }
  Some(WgslExprRef::{
    text: trimmed,
    identifiers,
    start: base + local_start,
    end: base + local_end,
  })
}

///|
fn parse_wgsl_expr_ref_fragment(fragment : WgslTextFragment) -> WgslExprRef? {
  if fragment.start < 0 || fragment.end < fragment.start {
    return None
  }
  parse_wgsl_expr_ref_text(fragment.text, fragment.start)
}

///|
fn parse_required_wgsl_expr_ref_fragment(
  fragment : WgslTextFragment,
) -> WgslExprRef {
  match parse_wgsl_expr_ref_fragment(fragment) {
    Some(expr) => expr
    None =>
      WgslExprRef::{
        text: fragment.text,
        identifiers: [],
        start: fragment.start,
        end: fragment.end,
      }
  }
}

///|
priv struct WgslDeclParser {
  source_text : String
  mut token_view : ArrayView[Token]
}

///|
priv struct WgslTextFragment {
  text : String
  start : Int
  end : Int
}

///|
fn WgslDeclParser::new(text : String) -> WgslDeclParser {
  let tokens = tokenize(replace_comments(text), false)
  WgslDeclParser::{ source_text: text, token_view: tokens[:] }
}

///|
fn WgslDeclParser::view(self : WgslDeclParser) -> ArrayView[Token] {
  self.token_view
}

///|
fn WgslDeclParser::update_view(
  self : WgslDeclParser,
  view : ArrayView[Token],
) -> Unit {
  self.token_view = view
}

///|
fn WgslDeclParser::consume_if_other(self : WgslDeclParser, code : Int) -> Bool {
  match self.view() {
    [Token::Other(actual, _), .. rest] if actual == code => {
      self.update_view(rest)
      true
    }
    _ => false
  }
}

///|
fn WgslDeclParser::consume_ident_node(self : WgslDeclParser) -> WgslIdent? {
  match self.view() {
    [Token::Identifier(name, pos), .. rest] => {
      self.update_view(rest)
      Some(WgslIdent::{ name, start: pos, end: pos + name.length() })
    }
    _ => None
  }
}

///|
fn WgslDeclParser::consume_path_ident_node(self : WgslDeclParser) -> WgslIdent? {
  let first = match self.consume_ident_node() {
    Some(value) => value
    None => return None
  }
  let mut name = first.name
  let mut end = first.end
  while true {
    match self.view() {
      [
        Token::Other(58, _),
        Token::Other(58, _),
        Token::Identifier(segment, segment_pos),
        .. rest,
      ] => {
        name = name + "::" + segment
        end = segment_pos + segment.length()
        self.update_view(rest)
      }
      _ => break
    }
  }
  Some(WgslIdent::{ name, start: first.start, end })
}

///|
fn WgslDeclParser::parse_attributes(
  self : WgslDeclParser,
) -> Array[WgslAttribute] {
  let attributes : Array[WgslAttribute] = []
  while true {
    match self.view() {
      [Token::Other(64, _), Token::Identifier(name, _), .. rest] => {
        self.update_view(rest)
        let mut arguments = ""
        let mut arguments_ref : WgslExprRef? = None
        match self.view() {
          [Token::Other(40, open_pos), .. token_rest] => {
            self.update_view(token_rest)
            let arg_start = open_pos + 1
            let mut arg_end = arg_start
            let mut depth = 1
            while depth > 0 {
              match self.view() {
                [Token::Other(40, _), .. nested_rest] => {
                  depth = depth + 1
                  self.update_view(nested_rest)
                  continue
                }
                [Token::Other(41, close_pos), .. nested_rest] => {
                  depth = depth - 1
                  self.update_view(nested_rest)
                  if depth == 0 {
                    arg_end = close_pos
                    break
                  }
                  continue
                }
                [_, .. nested_rest] => {
                  self.update_view(nested_rest)
                  continue
                }
                [] => break
              }
            }
            if arg_end >= arg_start {
              arguments = self.source_text[arg_start:arg_end].to_owned()
              arguments_ref = parse_wgsl_expr_ref_text(arguments, arg_start)
            }
          }
          _ => ()
        }
        attributes.push(WgslAttribute::{ name, arguments, arguments_ref })
        continue
      }
      _ => break
    }
  }
  attributes
}

///|
fn WgslDeclParser::collect_until_top_level_fragment(
  self : WgslDeclParser,
  stops : Array[Int],
) -> WgslTextFragment {
  let mut start_pos = -1
  let mut end_pos = -1
  fn record_token(token : Token) -> Unit {
    if start_pos < 0 {
      start_pos = token.pos()
    }
    end_pos = wgsl_ast_token_end(token)
  }
  let mut paren_depth = 0
  let mut angle_depth = 0
  let mut bracket_depth = 0
  while true {
    match self.view() {
      [Token::Other(code, _), ..] if paren_depth == 0 &&
        angle_depth == 0 &&
        bracket_depth == 0 &&
        stops.contains(code) => break
      [Token::Other(40, pos), .. rest] => {
        paren_depth = paren_depth + 1
        if start_pos < 0 {
          start_pos = pos
        }
        end_pos = pos + 1
        self.update_view(rest)
        continue
      }
      [Token::Other(41, pos), .. rest] => {
        paren_depth = paren_depth - 1
        if start_pos < 0 {
          start_pos = pos
        }
        end_pos = pos + 1
        self.update_view(rest)
        continue
      }
      [Token::Other(60, pos), .. rest] => {
        angle_depth = angle_depth + 1
        if start_pos < 0 {
          start_pos = pos
        }
        end_pos = pos + 1
        self.update_view(rest)
        continue
      }
      [Token::Other(62, pos), .. rest] => {
        angle_depth = angle_depth - 1
        if start_pos < 0 {
          start_pos = pos
        }
        end_pos = pos + 1
        self.update_view(rest)
        continue
      }
      [Token::Other(91, pos), .. rest] => {
        bracket_depth = bracket_depth + 1
        if start_pos < 0 {
          start_pos = pos
        }
        end_pos = pos + 1
        self.update_view(rest)
        continue
      }
      [Token::Other(93, pos), .. rest] => {
        bracket_depth = bracket_depth - 1
        if start_pos < 0 {
          start_pos = pos
        }
        end_pos = pos + 1
        self.update_view(rest)
        continue
      }
      [token, .. rest] => {
        record_token(token)
        self.update_view(rest)
        continue
      }
      [] => break
    }
  }
  let text = if start_pos < 0 || end_pos < start_pos {
    ""
  } else {
    self.source_text[start_pos:end_pos].to_owned().trim().to_owned()
  }
  WgslTextFragment::{ text, start: start_pos, end: end_pos }
}

///|
fn WgslDeclParser::collect_until_top_level(
  self : WgslDeclParser,
  stops : Array[Int],
) -> String {
  self.collect_until_top_level_fragment(stops).text
}

///|
fn wgsl_trim_fragment_bounds(
  text : String,
  start : Int,
  end_ : Int,
) -> (String, Int, Int) {
  let mut left = start
  let mut right = end_
  while left < right {
    let code = text.code_unit_at(left).to_int()
    if code == 32 || code == 9 || code == 10 || code == 13 {
      left = left + 1
      continue
    }
    break
  }
  while right > left {
    let code = text.code_unit_at(right - 1).to_int()
    if code == 32 || code == 9 || code == 10 || code == 13 {
      right = right - 1
      continue
    }
    break
  }
  (text[left:right].to_owned(), left, right)
}

///|
fn parse_wgsl_type_ref_text(text : String, base : Int) -> WgslTypeRef? {
  let (trimmed, local_start, local_end) = wgsl_trim_fragment_bounds(
    text,
    0,
    text.length(),
  )
  if trimmed == "" {
    return None
  }
  let tokens = tokenize(trimmed, false)
  if tokens.length() == 0 {
    return None
  }
  let name = match tokens[0] {
    Token::Identifier(value, _) => value
    _ => trimmed
  }
  let arguments : Array[WgslTypeRef] = []
  let mut open_index = -1
  for i in 1..<tokens.length() {
    match tokens[i] {
      Token::Other(60, _) => {
        open_index = i
        break
      }
      _ => ()
    }
  }
  if open_index >= 0 {
    let mut depth = 1
    let mut arg_start = tokens[open_index].pos() + 1
    let mut i = open_index + 1
    while i < tokens.length() && depth > 0 {
      match tokens[i] {
        Token::Other(60, _) => depth = depth + 1
        Token::Other(62, pos) => {
          depth = depth - 1
          if depth == 0 {
            let (arg_text, arg_local_start, _) = wgsl_trim_fragment_bounds(
              trimmed, arg_start, pos,
            )
            match
              parse_wgsl_type_ref_text(
                arg_text,
                base + local_start + arg_local_start,
              ) {
              Some(arg) => arguments.push(arg)
              None => ()
            }
            break
          }
        }
        Token::Other(44, pos) if depth == 1 => {
          let (arg_text, arg_local_start, _) = wgsl_trim_fragment_bounds(
            trimmed, arg_start, pos,
          )
          match
            parse_wgsl_type_ref_text(
              arg_text,
              base + local_start + arg_local_start,
            ) {
            Some(arg) => arguments.push(arg)
            None => ()
          }
          arg_start = pos + 1
        }
        _ => ()
      }
      i = i + 1
    }
  }
  Some(WgslTypeRef::{
    name,
    arguments,
    text: trimmed,
    start: base + local_start,
    end: base + local_end,
  })
}

///|
fn parse_wgsl_type_ref_fragment(fragment : WgslTextFragment) -> WgslTypeRef? {
  if fragment.start < 0 || fragment.end < fragment.start {
    return None
  }
  parse_wgsl_type_ref_text(fragment.text, fragment.start)
}

///|
fn WgslDeclParser::parse_template_list(self : WgslDeclParser) -> Array[String] {
  let templates : Array[String] = []
  if !self.consume_if_other(60) {
    return templates
  }
  while true {
    let value = self.collect_until_top_level([44, 62])
    if value != "" {
      templates.push(value)
    }
    if self.consume_if_other(44) {
      continue
    }
    self.consume_if_other(62) |> ignore
    break
  }
  templates
}

///|
fn WgslDeclParser::parse_function_arguments(
  self : WgslDeclParser,
) -> Array[WgslFunctionArgument] {
  let arguments : Array[WgslFunctionArgument] = []
  if !self.consume_if_other(40) {
    return arguments
  }
  while true {
    if self.consume_if_other(41) {
      break
    }
    let attributes = self.parse_attributes()
    match self.consume_ident_node() {
      Some(name_node) => {
        self.consume_if_other(58) |> ignore
        let ty_fragment = self.collect_until_top_level_fragment([44, 41])
        let ty = ty_fragment.text
        arguments.push(WgslFunctionArgument::{
          attributes,
          name: name_node.name,
          name_start: name_node.start,
          name_end: name_node.end,
          ty,
          ty_ref: parse_wgsl_type_ref_fragment(ty_fragment),
        })
      }
      None => ()
    }
    if self.consume_if_other(44) {
      continue
    }
    self.consume_if_other(41) |> ignore
    break
  }
  arguments
}

///|
fn WgslDeclParser::parse_function_result(
  self : WgslDeclParser,
) -> WgslFunctionResult? {
  match self.view() {
    [Token::Other(45, _), Token::Other(62, _), .. rest] => {
      self.update_view(rest)
      let attributes = self.parse_attributes()
      let ty_fragment = self.collect_until_top_level_fragment([123, 59])
      let ty = ty_fragment.text
      Some(WgslFunctionResult::{
        attributes,
        ty,
        ty_ref: parse_wgsl_type_ref_fragment(ty_fragment),
      })
    }
    _ => None
  }
}

///|
fn wgsl_statement_kind_from_first_identifier(
  first_identifier : String?,
) -> WgslStatementKind {
  match first_identifier {
    Some("var") | Some("let") | Some("const") => WgslStatementKind::LocalDecl
    Some("if") => WgslStatementKind::If
    Some("switch") => WgslStatementKind::Switch
    Some("loop") | Some("for") | Some("while") => WgslStatementKind::Loop
    Some("break") => WgslStatementKind::Break
    Some("continue") => WgslStatementKind::Continue
    Some("return") => WgslStatementKind::Return
    Some("const_assert") => WgslStatementKind::ConstAssert
    _ => WgslStatementKind::Raw
  }
}

///|
fn wgsl_statement_token_identifier(token : Token) -> String? {
  match token {
    Token::Identifier(ident, _) => Some(ident)
    _ => None
  }
}

///|
fn wgsl_statement_token_other_code(token : Token) -> Int? {
  match token {
    Token::Other(code, _) => Some(code)
    _ => None
  }
}

///|
fn wgsl_statement_skip_template_tokens(
  tokens : Array[Token],
  start : Int,
) -> Int {
  if start >= tokens.length() {
    return start
  }
  guard wgsl_statement_token_other_code(tokens[start]) is Some(60) else {
    return start
  }
  let mut depth = 1
  let mut i = start + 1
  while i < tokens.length() && depth > 0 {
    match wgsl_statement_token_other_code(tokens[i]) {
      Some(60) => depth = depth + 1
      Some(62) => depth = depth - 1
      _ => ()
    }
    i = i + 1
  }
  i
}

///|
fn wgsl_statement_local_name_from_tokens(
  tokens : Array[Token],
  kind : WgslStatementKind,
) -> String? {
  guard kind == WgslStatementKind::LocalDecl else { return None }
  for i in 0..<tokens.length() {
    match wgsl_statement_token_identifier(tokens[i]) {
      Some("var") => {
        let name_index = wgsl_statement_skip_template_tokens(tokens, i + 1)
        if name_index < tokens.length() {
          return wgsl_statement_token_identifier(tokens[name_index])
        }
        return None
      }
      Some("let") | Some("const") =>
        if i + 1 < tokens.length() {
          return wgsl_statement_token_identifier(tokens[i + 1])
        } else {
          return None
        }
      Some(_) => return None
      None => ()
    }
  }
  None
}

///|
fn wgsl_statement_identifier_has_access_prefix(
  tokens : Array[Token],
  index : Int,
) -> Bool {
  if index == 0 {
    return false
  }
  match tokens[index - 1] {
    Token::Other(46, _) | Token::Other(64, _) => true
    _ => false
  }
}

///|
fn collect_wgsl_statement_identifier_nodes(
  tokens : Array[Token],
  kind : WgslStatementKind,
  local_name : String?,
  identifiers : Array[WgslIdent],
) -> Unit {
  let mut skipped_local_name = false
  for i in 0..<tokens.length() {
    guard tokens[i] is Token::Identifier(ident, pos) else { continue }
    if wgsl_statement_identifier_has_access_prefix(tokens, i) {
      continue
    }
    match local_name {
      Some(name) if kind == WgslStatementKind::LocalDecl &&
        !skipped_local_name &&
        ident == name => {
        skipped_local_name = true
        continue
      }
      _ => ()
    }
    identifiers.push(WgslIdent::{
      name: ident,
      start: pos,
      end: pos + ident.length(),
    })
  }
}

///|
fn WgslDeclParser::collect_statement(self : WgslDeclParser) -> WgslStatement? {
  let tokens : Array[Token] = []
  let identifiers : Array[WgslIdent] = []
  let mut first_identifier : String? = None
  let mut start_pos = -1
  let mut end_pos = -1
  let mut brace_depth = 0
  let mut paren_depth = 0
  fn record_span(start : Int, end_ : Int) -> Unit {
    if start_pos < 0 {
      start_pos = start
    }
    end_pos = end_
  }
  fn record_token(token : Token) -> Unit {
    record_span(token.pos(), wgsl_ast_token_end(token))
  }
  while true {
    match self.view() {
      [Token::Other(123, pos), .. rest] => {
        brace_depth = brace_depth + 1
        record_span(pos, pos + 1)
        self.update_view(rest)
        continue
      }
      [Token::Other(125, _), ..] if brace_depth == 0 => break
      [Token::Other(125, pos), .. rest] => {
        brace_depth = brace_depth - 1
        record_span(pos, pos + 1)
        self.update_view(rest)
        if brace_depth == 0 {
          break
        }
        continue
      }
      [Token::Other(40, pos), .. rest] => {
        paren_depth = paren_depth + 1
        record_span(pos, pos + 1)
        self.update_view(rest)
        continue
      }
      [Token::Other(41, pos), .. rest] => {
        paren_depth = paren_depth - 1
        record_span(pos, pos + 1)
        self.update_view(rest)
        continue
      }
      [Token::Other(59, pos), .. rest] if brace_depth == 0 && paren_depth == 0 => {
        record_span(pos, pos + 1)
        self.update_view(rest)
        break
      }
      [token, .. rest] => {
        match token {
          Token::Identifier(ident, _) =>
            if first_identifier is None {
              first_identifier = Some(ident)
            }
          _ => ()
        }
        tokens.push(token)
        record_token(token)
        self.update_view(rest)
        continue
      }
      [] => break
    }
  }
  let text = if start_pos < 0 || end_pos < start_pos {
    ""
  } else {
    self.source_text[start_pos:end_pos].to_owned().trim().to_owned()
  }
  if text == "" {
    None
  } else {
    let kind = wgsl_statement_kind_from_first_identifier(first_identifier)
    let local_name = wgsl_statement_local_name_from_tokens(tokens, kind)
    collect_wgsl_statement_identifier_nodes(
      tokens, kind, local_name, identifiers,
    )
    Some(WgslStatement::{
      kind,
      text,
      local_name,
      identifiers,
      start: start_pos,
      end: end_pos,
    })
  }
}

///|
fn WgslDeclParser::parse_block(self : WgslDeclParser) -> WgslBlock {
  let statements : Array[WgslStatement] = []
  if !self.consume_if_other(123) {
    return WgslBlock::{ statements, }
  }
  while true {
    if self.consume_if_other(125) {
      break
    }
    match self.collect_statement() {
      Some(statement) => statements.push(statement)
      None => if self.view() is [] { break }
    }
  }
  WgslBlock::{ statements, }
}

///|
fn WgslDeclParser::parse_function(
  self : WgslDeclParser,
  attributes : Array[WgslAttribute],
  qualifier : String,
  qualifier_start : Int?,
  qualifier_end : Int?,
  fn_keyword : WgslIdent,
) -> WgslFunction? {
  let name = if qualifier == "override" {
    match self.consume_path_ident_node() {
      Some(value) => value
      None => return None
    }
  } else {
    match self.consume_ident_node() {
      Some(value) => value
      None => return None
    }
  }
  let arguments = self.parse_function_arguments()
  let result = self.parse_function_result()
  let body = self.parse_block()
  Some(WgslFunction::{
    attributes,
    qualifier,
    qualifier_start,
    qualifier_end,
    fn_start: fn_keyword.start,
    fn_end: fn_keyword.end,
    name,
    arguments,
    result,
    body,
  })
}

///|
fn WgslDeclParser::parse_struct_members(
  self : WgslDeclParser,
) -> Array[WgslStructMember] {
  let members : Array[WgslStructMember] = []
  if !self.consume_if_other(123) {
    return members
  }
  while true {
    if self.consume_if_other(125) {
      break
    }
    let attributes = self.parse_attributes()
    match self.consume_ident_node() {
      Some(name_node) => {
        self.consume_if_other(58) |> ignore
        let ty_fragment = self.collect_until_top_level_fragment([44, 59, 125])
        let ty = ty_fragment.text
        members.push(WgslStructMember::{
          attributes,
          name: name_node.name,
          name_start: name_node.start,
          name_end: name_node.end,
          ty,
          ty_ref: parse_wgsl_type_ref_fragment(ty_fragment),
        })
      }
      None => ()
    }
    if self.consume_if_other(44) || self.consume_if_other(59) {
      continue
    }
    self.consume_if_other(125) |> ignore
    break
  }
  members
}

///|
fn WgslDeclParser::parse_struct(
  self : WgslDeclParser,
  attributes : Array[WgslAttribute],
) -> WgslStruct? {
  let name = match self.consume_ident_node() {
    Some(value) => value
    None => return None
  }
  Some(WgslStruct::{ attributes, name, members: self.parse_struct_members() })
}

///|
fn WgslDeclParser::parse_global_variable(
  self : WgslDeclParser,
  attributes : Array[WgslAttribute],
) -> WgslGlobalVariable? {
  let template_list = self.parse_template_list()
  let name = match self.consume_ident_node() {
    Some(value) => value
    None => return None
  }
  let mut ty_ref : WgslTypeRef? = None
  let ty : String? = if self.consume_if_other(58) {
    let parsed = self.collect_until_top_level_fragment([61, 59])
    if parsed.text == "" {
      None
    } else {
      ty_ref = parse_wgsl_type_ref_fragment(parsed)
      Some(parsed.text)
    }
  } else {
    None
  }
  let (initializer, initializer_ref) = self.parse_optional_initializer()
  Some(WgslGlobalVariable::{
    attributes,
    name,
    template_list,
    ty,
    ty_ref,
    initializer,
    initializer_ref,
  })
}

///|
fn WgslDeclParser::parse_optional_initializer(
  self : WgslDeclParser,
) -> (String?, WgslExprRef?) {
  if !self.consume_if_other(61) {
    return (None, None)
  }
  let parsed = self.collect_until_top_level_fragment([59])
  if parsed.text == "" {
    (None, None)
  } else {
    (Some(parsed.text), parse_wgsl_expr_ref_fragment(parsed))
  }
}

///|
fn WgslDeclParser::parse_const(self : WgslDeclParser) -> WgslConst? {
  let name = match self.consume_ident_node() {
    Some(value) => value
    None => return None
  }
  let mut ty_ref : WgslTypeRef? = None
  let ty : String? = if self.consume_if_other(58) {
    let parsed = self.collect_until_top_level_fragment([61, 59])
    if parsed.text == "" {
      None
    } else {
      ty_ref = parse_wgsl_type_ref_fragment(parsed)
      Some(parsed.text)
    }
  } else {
    None
  }
  let (initializer, initializer_ref) = self.parse_optional_initializer()
  Some(WgslConst::{ name, ty, ty_ref, initializer, initializer_ref })
}

///|
fn WgslDeclParser::parse_override(
  self : WgslDeclParser,
  attributes : Array[WgslAttribute],
) -> WgslOverride? {
  let name = match self.consume_ident_node() {
    Some(value) => value
    None => return None
  }
  let mut ty_ref : WgslTypeRef? = None
  let ty : String? = if self.consume_if_other(58) {
    let parsed = self.collect_until_top_level_fragment([61, 59])
    if parsed.text == "" {
      None
    } else {
      ty_ref = parse_wgsl_type_ref_fragment(parsed)
      Some(parsed.text)
    }
  } else {
    None
  }
  let (initializer, initializer_ref) = self.parse_optional_initializer()
  Some(WgslOverride::{
    attributes,
    name,
    ty,
    ty_ref,
    initializer,
    initializer_ref,
  })
}

///|
fn WgslDeclParser::parse_type_alias(self : WgslDeclParser) -> WgslTypeAlias? {
  let name = match self.consume_ident_node() {
    Some(value) => value
    None => return None
  }
  self.consume_if_other(61) |> ignore
  let ty_fragment = self.collect_until_top_level_fragment([59])
  let ty = ty_fragment.text
  Some(WgslTypeAlias::{
    name,
    ty,
    ty_ref: parse_wgsl_type_ref_fragment(ty_fragment),
  })
}

///|
fn WgslDeclParser::parse_decl_data(self : WgslDeclParser) -> WgslGlobalDeclData {
  let attributes = self.parse_attributes()
  match self.consume_ident_node() {
    Some(keyword) if keyword.name == "virtual" =>
      match self.consume_ident_node() {
        Some(fn_keyword) if fn_keyword.name == "fn" =>
          match
            self.parse_function(
              attributes,
              "virtual",
              Some(keyword.start),
              Some(keyword.end),
              fn_keyword,
            ) {
            Some(function) => WgslGlobalDeclData::Function(function)
            None => WgslGlobalDeclData::Raw
          }
        _ => WgslGlobalDeclData::Raw
      }
    Some(keyword) if keyword.name == "override" =>
      match self.view() {
        [Token::Identifier("fn", fn_pos), .. rest] => {
          self.update_view(rest)
          match
            self.parse_function(
              attributes,
              "override",
              Some(keyword.start),
              Some(keyword.end),
              WgslIdent::{ name: "fn", start: fn_pos, end: fn_pos + 2 },
            ) {
            Some(function) => WgslGlobalDeclData::Function(function)
            None => WgslGlobalDeclData::Raw
          }
        }
        _ =>
          match self.parse_override(attributes) {
            Some(value) => WgslGlobalDeclData::Override(value)
            None => WgslGlobalDeclData::Raw
          }
      }
    Some(keyword) if keyword.name == "fn" =>
      match self.parse_function(attributes, "", None, None, keyword) {
        Some(function) => WgslGlobalDeclData::Function(function)
        None => WgslGlobalDeclData::Raw
      }
    Some(keyword) if keyword.name == "var" =>
      match self.parse_global_variable(attributes) {
        Some(value) => WgslGlobalDeclData::GlobalVariable(value)
        None => WgslGlobalDeclData::Raw
      }
    Some(keyword) if keyword.name == "struct" =>
      match self.parse_struct(attributes) {
        Some(value) => WgslGlobalDeclData::Struct(value)
        None => WgslGlobalDeclData::Raw
      }
    Some(keyword) if keyword.name == "const" =>
      match self.parse_const() {
        Some(value) => WgslGlobalDeclData::Const(value)
        None => WgslGlobalDeclData::Raw
      }
    Some(keyword) if keyword.name == "const_assert" =>
      WgslGlobalDeclData::ConstAssert(
        parse_required_wgsl_expr_ref_fragment(
          self.collect_until_top_level_fragment([59]),
        ),
      )
    Some(keyword) if keyword.name == "alias" || keyword.name == "type" =>
      match self.parse_type_alias() {
        Some(value) => WgslGlobalDeclData::TypeAlias(value)
        None => WgslGlobalDeclData::Raw
      }
    _ => WgslGlobalDeclData::Raw
  }
}

///|
fn wgsl_global_decl_kind_from_data(
  data : WgslGlobalDeclData,
) -> WgslGlobalDeclKind {
  match data {
    Function(_) => WgslGlobalDeclKind::Function
    GlobalVariable(_) => WgslGlobalDeclKind::GlobalVariable
    Const(_) => WgslGlobalDeclKind::Const
    Override(_) => WgslGlobalDeclKind::Override
    Struct(_) => WgslGlobalDeclKind::Struct
    TypeAlias(_) => WgslGlobalDeclKind::TypeAlias
    ConstAssert(_) => WgslGlobalDeclKind::ConstAssert
    Directive(_) => WgslGlobalDeclKind::Directive
    Import(_) => WgslGlobalDeclKind::Import
    Raw => WgslGlobalDeclKind::Unknown
  }
}

///|
fn wgsl_decl_data_name(data : WgslGlobalDeclData) -> String {
  match data {
    Function(function) => function.name.name
    GlobalVariable(global) => global.name.name
    Const(value) => value.name.name
    Override(value) => value.name.name
    Struct(value) => value.name.name
    TypeAlias(value) => value.name.name
    Directive(_) | Import(_) | ConstAssert(_) | Raw => ""
  }
}

///|
fn collect_wgsl_expr_ref_identifier_nodes(
  expr_ref : WgslExprRef?,
  nodes : Array[WgslIdent],
) -> Unit {
  match expr_ref {
    Some(expr) =>
      for ident in expr.identifiers {
        nodes.push(ident)
      }
    None => ()
  }
}

///|
fn collect_wgsl_type_ref_identifier_nodes(
  ty_ref : WgslTypeRef?,
  nodes : Array[WgslIdent],
) -> Unit {
  match ty_ref {
    Some(ty) => {
      nodes.push(WgslIdent::{
        name: ty.name,
        start: ty.start,
        end: ty.start + ty.name.length(),
      })
      for argument in ty.arguments {
        collect_wgsl_type_ref_identifier_nodes(Some(argument), nodes)
      }
    }
    None => ()
  }
}

///|
fn collect_wgsl_attribute_identifier_nodes(
  attributes : Array[WgslAttribute],
  nodes : Array[WgslIdent],
) -> Unit {
  for attr in attributes {
    collect_wgsl_expr_ref_identifier_nodes(attr.arguments_ref, nodes)
  }
}

///|
pub fn collect_wgsl_decl_identifier_nodes(
  data : WgslGlobalDeclData,
  nodes : Array[WgslIdent],
) -> Unit {
  match data {
    WgslGlobalDeclData::Function(function) => {
      collect_wgsl_attribute_identifier_nodes(function.attributes, nodes)
      if function.qualifier == "override" {
        nodes.push(function.name)
      }
      for argument in function.arguments {
        collect_wgsl_attribute_identifier_nodes(argument.attributes, nodes)
        collect_wgsl_type_ref_identifier_nodes(argument.ty_ref, nodes)
      }
      match function.result {
        Some(result) => {
          collect_wgsl_attribute_identifier_nodes(result.attributes, nodes)
          collect_wgsl_type_ref_identifier_nodes(result.ty_ref, nodes)
        }
        None => ()
      }
      for statement in function.body.statements {
        for ident in statement.identifiers {
          nodes.push(ident)
        }
      }
    }
    WgslGlobalDeclData::Struct(struct_decl) => {
      collect_wgsl_attribute_identifier_nodes(struct_decl.attributes, nodes)
      for struct_member in struct_decl.members {
        collect_wgsl_attribute_identifier_nodes(struct_member.attributes, nodes)
        collect_wgsl_type_ref_identifier_nodes(struct_member.ty_ref, nodes)
      }
    }
    WgslGlobalDeclData::GlobalVariable(global) => {
      collect_wgsl_attribute_identifier_nodes(global.attributes, nodes)
      collect_wgsl_type_ref_identifier_nodes(global.ty_ref, nodes)
      collect_wgsl_expr_ref_identifier_nodes(global.initializer_ref, nodes)
    }
    WgslGlobalDeclData::Const(const_decl) => {
      collect_wgsl_type_ref_identifier_nodes(const_decl.ty_ref, nodes)
      collect_wgsl_expr_ref_identifier_nodes(const_decl.initializer_ref, nodes)
    }
    WgslGlobalDeclData::Override(override_decl) => {
      collect_wgsl_attribute_identifier_nodes(override_decl.attributes, nodes)
      collect_wgsl_type_ref_identifier_nodes(override_decl.ty_ref, nodes)
      collect_wgsl_expr_ref_identifier_nodes(
        override_decl.initializer_ref,
        nodes,
      )
    }
    WgslGlobalDeclData::TypeAlias(alias_decl) =>
      collect_wgsl_type_ref_identifier_nodes(alias_decl.ty_ref, nodes)
    WgslGlobalDeclData::ConstAssert(expr) =>
      for ident in expr.identifiers {
        nodes.push(ident)
      }
    WgslGlobalDeclData::Directive(_) | WgslGlobalDeclData::Import(_) | Raw => ()
  }
}

///|
pub fn collect_wgsl_decl_identifier_names(
  data : WgslGlobalDeclData,
  names : Array[String],
) -> Unit {
  let nodes : Array[WgslIdent] = []
  collect_wgsl_decl_identifier_nodes(data, nodes)
  for node in nodes {
    names.push(node.name)
  }
}

///|
pub fn collect_wgsl_source_identifier_nodes(
  source : String,
  nodes : Array[WgslIdent],
) -> Unit {
  for decl in parse_wgsl_translation_unit(source).declarations {
    collect_wgsl_decl_identifier_nodes(decl.data, nodes)
  }
}

///|
pub fn collect_wgsl_source_identifier_names(
  source : String,
  names : Array[String],
) -> Unit {
  let nodes : Array[WgslIdent] = []
  collect_wgsl_source_identifier_nodes(source, nodes)
  for node in nodes {
    names.push(node.name)
  }
}

///|
fn parse_wgsl_declaration_data(text : String) -> WgslGlobalDeclData {
  WgslDeclParser::new(text).parse_decl_data()
}

///|
fn parse_wgsl_declaration_name(text : String) -> String {
  wgsl_decl_data_name(parse_wgsl_declaration_data(text))
}

///|
priv struct WgslAstParser {
  mut item_view : ArrayView[WgslTopLevelItem]
}

///|
fn WgslAstParser::new(source : String) -> WgslAstParser {
  let items = parse_wgsl_top_level_items(source)
  WgslAstParser::{ item_view: items[:] }
}

///|
fn WgslAstParser::view(self : WgslAstParser) -> ArrayView[WgslTopLevelItem] {
  self.item_view
}

///|
fn WgslAstParser::update_view(
  self : WgslAstParser,
  view : ArrayView[WgslTopLevelItem],
) -> Unit {
  self.item_view = view
}

///|
fn WgslAstParser::parse_global_decl(
  _self : WgslAstParser,
  item : WgslTopLevelItem,
) -> WgslGlobalDecl {
  let data = match item.kind {
    WgslTopLevelKind::DefineImportPath | WgslTopLevelKind::Define =>
      match parse_wgsl_directive_line(item.text) {
        Some(directive) => WgslGlobalDeclData::Directive(directive)
        None => WgslGlobalDeclData::Raw
      }
    WgslTopLevelKind::Import =>
      match parse_wgsl_directive_line(item.text) {
        Some(directive) => WgslGlobalDeclData::Import(directive)
        None => WgslGlobalDeclData::Raw
      }
    WgslTopLevelKind::Declaration => parse_wgsl_declaration_data(item.text)
    _ => WgslGlobalDeclData::Raw
  }
  let kind = match item.kind {
    WgslTopLevelKind::Trivia => WgslGlobalDeclKind::Trivia
    _ => wgsl_global_decl_kind_from_data(data)
  }
  WgslGlobalDecl::{
    kind,
    data,
    name: if item.name == "" {
      wgsl_decl_data_name(data)
    } else {
      item.name
    },
    text: item.text,
    start: item.start,
    end: item.end,
  }
}

///|
fn WgslAstParser::parse_translation_unit(
  self : WgslAstParser,
) -> WgslTranslationUnit {
  let declarations : Array[WgslGlobalDecl] = []
  while true {
    match self.view() {
      [item, .. rest] => {
        declarations.push(self.parse_global_decl(item))
        self.update_view(rest)
        continue
      }
      [] => break
    }
  }
  WgslTranslationUnit::{ declarations, }
}

///|
pub fn parse_wgsl_translation_unit(source : String) -> WgslTranslationUnit {
  WgslAstParser::new(source).parse_translation_unit()
}
