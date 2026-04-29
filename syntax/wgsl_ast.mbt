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
} derive(Debug)

///|
pub(all) struct WgslConst {
  name : WgslIdent
  ty : String?
} derive(Debug)

///|
pub(all) struct WgslOverride {
  attributes : Array[WgslAttribute]
  name : WgslIdent
  ty : String?
} derive(Debug)

///|
pub(all) struct WgslTypeAlias {
  name : WgslIdent
  ty : String
} derive(Debug)

///|
pub(all) enum WgslGlobalDeclData {
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
priv struct WgslDeclParser {
  mut token_view : ArrayView[Token]
}

///|
fn WgslDeclParser::new(text : String) -> WgslDeclParser {
  let tokens = tokenize(replace_comments(text), false)
  WgslDeclParser::{ token_view: tokens[:] }
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
fn wgsl_statement_kind_from_text(text : String) -> WgslStatementKind {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return WgslStatementKind::Raw
  }
  if starts_with_text(trimmed, "var") ||
    starts_with_text(trimmed, "let") ||
    starts_with_text(trimmed, "const") {
    return WgslStatementKind::LocalDecl
  }
  if starts_with_text(trimmed, "if") {
    return WgslStatementKind::If
  }
  if starts_with_text(trimmed, "switch") {
    return WgslStatementKind::Switch
  }
  if starts_with_text(trimmed, "loop") ||
    starts_with_text(trimmed, "for") ||
    starts_with_text(trimmed, "while") {
    return WgslStatementKind::Loop
  }
  if starts_with_text(trimmed, "break") {
    return WgslStatementKind::Break
  }
  if starts_with_text(trimmed, "continue") {
    return WgslStatementKind::Continue
  }
  if starts_with_text(trimmed, "return") {
    return WgslStatementKind::Return
  }
  if starts_with_text(trimmed, "const_assert") {
    return WgslStatementKind::ConstAssert
  }
  WgslStatementKind::Raw
}

///|
fn WgslDeclParser::collect_statement_text(self : WgslDeclParser) -> String {
  let parts : Array[Token] = []
  let mut brace_depth = 0
  let mut paren_depth = 0
  while true {
    match self.view() {
      [Token::Other(123, _), .. rest] => {
        brace_depth = brace_depth + 1
        parts.push(Token::Other(123, 0))
        self.update_view(rest)
        continue
      }
      [Token::Other(125, _), ..] if brace_depth == 0 => break
      [Token::Other(125, _), .. rest] => {
        brace_depth = brace_depth - 1
        parts.push(Token::Other(125, 0))
        self.update_view(rest)
        if brace_depth == 0 {
          break
        }
        continue
      }
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
      [Token::Other(59, _), .. rest] if brace_depth == 0 && paren_depth == 0 => {
        parts.push(Token::Other(59, 0))
        self.update_view(rest)
        break
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
fn WgslDeclParser::parse_block(self : WgslDeclParser) -> WgslBlock {
  let statements : Array[WgslStatement] = []
  if !self.consume_if_other(123) {
    return WgslBlock::{ statements, }
  }
  while true {
    if self.consume_if_other(125) {
      break
    }
    let text = self.collect_statement_text()
    if text != "" {
      statements.push(WgslStatement::{
        kind: wgsl_statement_kind_from_text(text),
        text,
      })
    } else if self.view() is [] {
      break
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
  let name = match self.consume_identifier() {
    Some(value) => value
    None => return None
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
  Some(WgslGlobalVariable::{
    attributes,
    name: WgslIdent::{ name, },
    template_list,
    ty,
  })
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
  Some(WgslConst::{ name: WgslIdent::{ name, }, ty })
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
  Some(WgslOverride::{ attributes, name: WgslIdent::{ name, }, ty })
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
    ConstAssert(_) | Raw => ""
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
    WgslTopLevelKind::Declaration => parse_wgsl_declaration_data(item.text)
    _ => WgslGlobalDeclData::Raw
  }
  let kind = match item.kind {
    WgslTopLevelKind::Trivia => WgslGlobalDeclKind::Trivia
    WgslTopLevelKind::Import => WgslGlobalDeclKind::Import
    WgslTopLevelKind::DefineImportPath | WgslTopLevelKind::Define =>
      WgslGlobalDeclKind::Directive
    WgslTopLevelKind::Declaration => wgsl_global_decl_kind_from_data(data)
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
