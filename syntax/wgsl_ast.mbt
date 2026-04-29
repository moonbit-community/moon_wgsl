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
} derive(Debug)

///|
pub(all) struct WgslAttribute {
  name : String
  arguments : String
} derive(Debug)

///|
pub(all) struct WgslFunctionArgument {
  attributes : Array[WgslAttribute]
  name : String
  ty : String
} derive(Debug)

///|
pub(all) struct WgslFunctionResult {
  attributes : Array[WgslAttribute]
  ty : String
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
  name : WgslIdent
  arguments : Array[WgslFunctionArgument]
  result : WgslFunctionResult?
  body : WgslBlock
} derive(Debug)

///|
pub(all) struct WgslStructMember {
  attributes : Array[WgslAttribute]
  name : String
  ty : String
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
  initializer : String?
} derive(Debug)

///|
pub(all) struct WgslConst {
  name : WgslIdent
  ty : String?
  initializer : String?
} derive(Debug)

///|
pub(all) struct WgslOverride {
  attributes : Array[WgslAttribute]
  name : WgslIdent
  ty : String?
  initializer : String?
} derive(Debug)

///|
pub(all) struct WgslTypeAlias {
  name : WgslIdent
  ty : String
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
  ConstAssert(String)
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
fn wgsl_ast_token_text(token : Token) -> String {
  match token {
    Token::Identifier(text, _) => text
    Token::Whitespace(text, _) => text
    Token::Other(code, _) => code_unit_to_string(code)
  }
}

///|
fn wgsl_ast_tokens_text(tokens : Array[Token]) -> String {
  let mut out = ""
  for token in tokens {
    out = out + wgsl_ast_token_text(token)
  }
  out
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
priv struct WgslDeclParser {
  source_text : String
  mut token_view : ArrayView[Token]
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
fn WgslDeclParser::consume_identifier(self : WgslDeclParser) -> String? {
  match self.view() {
    [Token::Identifier(name, _), .. rest] => {
      self.update_view(rest)
      Some(name)
    }
    _ => None
  }
}

///|
fn WgslDeclParser::consume_path_identifier(self : WgslDeclParser) -> String? {
  let mut name = match self.consume_identifier() {
    Some(value) => value
    None => return None
  }
  while true {
    match self.view() {
      [
        Token::Other(58, _),
        Token::Other(58, _),
        Token::Identifier(segment, _),
        .. rest,
      ] => {
        name = name + "::" + segment
        self.update_view(rest)
      }
      _ => break
    }
  }
  Some(name)
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
        if self.consume_if_other(40) {
          let parts : Array[Token] = []
          let mut depth = 1
          while depth > 0 {
            match self.view() {
              [Token::Other(40, _), .. token_rest] => {
                parts.push(Token::Other(40, 0))
                depth = depth + 1
                self.update_view(token_rest)
                continue
              }
              [Token::Other(41, _), .. token_rest] => {
                depth = depth - 1
                self.update_view(token_rest)
                if depth > 0 {
                  parts.push(Token::Other(41, 0))
                }
                continue
              }
              [token, .. token_rest] => {
                parts.push(token)
                self.update_view(token_rest)
                continue
              }
              [] => break
            }
          }
          arguments = wgsl_ast_tokens_text(parts)
        }
        attributes.push(WgslAttribute::{ name, arguments })
        continue
      }
      _ => break
    }
  }
  attributes
}

///|
fn WgslDeclParser::collect_until_top_level(
  self : WgslDeclParser,
  stops : Array[Int],
) -> String {
  let parts : Array[Token] = []
  let mut paren_depth = 0
  let mut angle_depth = 0
  let mut bracket_depth = 0
  while true {
    match self.view() {
      [Token::Other(code, _), ..] if paren_depth == 0 &&
        angle_depth == 0 &&
        bracket_depth == 0 &&
        stops.contains(code) => break
      [Token::Other(40, _), .. rest] => {
        paren_depth = paren_depth + 1
        parts.push(Token::Other(40, 0))
        self.update_view(rest)
        continue
      }
      [Token::Other(41, _), .. rest] => {
        paren_depth = paren_depth - 1
        parts.push(Token::Other(41, 0))
        self.update_view(rest)
        continue
      }
      [Token::Other(60, _), .. rest] => {
        angle_depth = angle_depth + 1
        parts.push(Token::Other(60, 0))
        self.update_view(rest)
        continue
      }
      [Token::Other(62, _), .. rest] => {
        angle_depth = angle_depth - 1
        parts.push(Token::Other(62, 0))
        self.update_view(rest)
        continue
      }
      [Token::Other(91, _), .. rest] => {
        bracket_depth = bracket_depth + 1
        parts.push(Token::Other(91, 0))
        self.update_view(rest)
        continue
      }
      [Token::Other(93, _), .. rest] => {
        bracket_depth = bracket_depth - 1
        parts.push(Token::Other(93, 0))
        self.update_view(rest)
        continue
      }
      [token, .. rest] => {
        parts.push(token)
        self.update_view(rest)
        continue
      }
      [] => break
    }
  }
  wgsl_ast_tokens_text(parts).trim().to_owned()
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
    match self.consume_identifier() {
      Some(name) => {
        self.consume_if_other(58) |> ignore
        let ty = self.collect_until_top_level([44, 41])
        arguments.push(WgslFunctionArgument::{ attributes, name, ty })
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
      let ty = self.collect_until_top_level([123, 59])
      Some(WgslFunctionResult::{ attributes, ty })
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
fn WgslDeclParser::collect_statement(self : WgslDeclParser) -> WgslStatement? {
  let tokens : Array[Token] = []
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
        match (first_identifier, token) {
          (None, Token::Identifier(ident, _)) => first_identifier = Some(ident)
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
    Some(WgslStatement::{
      kind,
      text,
      local_name: wgsl_statement_local_name_from_tokens(tokens, kind),
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
) -> WgslFunction? {
  let name = if qualifier == "override" {
    match self.consume_path_identifier() {
      Some(value) => value
      None => return None
    }
  } else {
    match self.consume_identifier() {
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
    name: WgslIdent::{ name, },
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
    match self.consume_identifier() {
      Some(name) => {
        self.consume_if_other(58) |> ignore
        let ty = self.collect_until_top_level([44, 59, 125])
        members.push(WgslStructMember::{ attributes, name, ty })
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
  let name = match self.consume_identifier() {
    Some(value) => value
    None => return None
  }
  Some(WgslStruct::{
    attributes,
    name: WgslIdent::{ name, },
    members: self.parse_struct_members(),
  })
}

///|
fn WgslDeclParser::parse_global_variable(
  self : WgslDeclParser,
  attributes : Array[WgslAttribute],
) -> WgslGlobalVariable? {
  let template_list = self.parse_template_list()
  let name = match self.consume_identifier() {
    Some(value) => value
    None => return None
  }
  let ty : String? = if self.consume_if_other(58) {
    let parsed = self.collect_until_top_level([61, 59])
    if parsed == "" {
      None
    } else {
      Some(parsed)
    }
  } else {
    None
  }
  let initializer = self.parse_optional_initializer()
  Some(WgslGlobalVariable::{
    attributes,
    name: WgslIdent::{ name, },
    template_list,
    ty,
    initializer,
  })
}

///|
fn WgslDeclParser::parse_optional_initializer(self : WgslDeclParser) -> String? {
  if !self.consume_if_other(61) {
    return None
  }
  let parsed = self.collect_until_top_level([59])
  if parsed == "" {
    None
  } else {
    Some(parsed)
  }
}

///|
fn WgslDeclParser::parse_const(self : WgslDeclParser) -> WgslConst? {
  let name = match self.consume_identifier() {
    Some(value) => value
    None => return None
  }
  let ty : String? = if self.consume_if_other(58) {
    let parsed = self.collect_until_top_level([61, 59])
    if parsed == "" {
      None
    } else {
      Some(parsed)
    }
  } else {
    None
  }
  let initializer = self.parse_optional_initializer()
  Some(WgslConst::{ name: WgslIdent::{ name, }, ty, initializer })
}

///|
fn WgslDeclParser::parse_override(
  self : WgslDeclParser,
  attributes : Array[WgslAttribute],
) -> WgslOverride? {
  let name = match self.consume_identifier() {
    Some(value) => value
    None => return None
  }
  let ty : String? = if self.consume_if_other(58) {
    let parsed = self.collect_until_top_level([61, 59])
    if parsed == "" {
      None
    } else {
      Some(parsed)
    }
  } else {
    None
  }
  let initializer = self.parse_optional_initializer()
  Some(WgslOverride::{ attributes, name: WgslIdent::{ name, }, ty, initializer })
}

///|
fn WgslDeclParser::parse_type_alias(self : WgslDeclParser) -> WgslTypeAlias? {
  let name = match self.consume_identifier() {
    Some(value) => value
    None => return None
  }
  self.consume_if_other(61) |> ignore
  let ty = self.collect_until_top_level([59])
  Some(WgslTypeAlias::{ name: WgslIdent::{ name, }, ty })
}

///|
fn WgslDeclParser::parse_decl_data(self : WgslDeclParser) -> WgslGlobalDeclData {
  let attributes = self.parse_attributes()
  match self.consume_identifier() {
    Some("virtual") =>
      match self.consume_identifier() {
        Some("fn") =>
          match self.parse_function(attributes, "virtual") {
            Some(function) => WgslGlobalDeclData::Function(function)
            None => WgslGlobalDeclData::Raw
          }
        _ => WgslGlobalDeclData::Raw
      }
    Some("override") =>
      match self.view() {
        [Token::Identifier("fn", _), .. rest] => {
          self.update_view(rest)
          match self.parse_function(attributes, "override") {
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
    Some("fn") =>
      match self.parse_function(attributes, "") {
        Some(function) => WgslGlobalDeclData::Function(function)
        None => WgslGlobalDeclData::Raw
      }
    Some("var") =>
      match self.parse_global_variable(attributes) {
        Some(value) => WgslGlobalDeclData::GlobalVariable(value)
        None => WgslGlobalDeclData::Raw
      }
    Some("struct") =>
      match self.parse_struct(attributes) {
        Some(value) => WgslGlobalDeclData::Struct(value)
        None => WgslGlobalDeclData::Raw
      }
    Some("const") =>
      match self.parse_const() {
        Some(value) => WgslGlobalDeclData::Const(value)
        None => WgslGlobalDeclData::Raw
      }
    Some("const_assert") =>
      WgslGlobalDeclData::ConstAssert(self.collect_until_top_level([59]))
    Some("alias") | Some("type") =>
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
