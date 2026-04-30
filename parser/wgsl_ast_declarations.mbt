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
  match self.collect_delimited_token_view(123, 125) {
    Some(fragment) => {
      let tokens = self.tokenize_struct_members(fragment) catch {
        _ => return []
      }
      let members = @generated.struct_members(tokens) catch { _ => return [] }
      self.drop_tokens(fragment.consumed)
      members
    }
    None => []
  }
}

///|
priv suberror WgslStructMembersTokenizeError {
  UnexpectedToken
}

///|
fn WgslDeclParser::tokenize_struct_members(
  self : WgslDeclParser,
  fragment : WgslDelimitedTokenView,
) -> Array[(@generated.Token, Int, Int)] raise WgslStructMembersTokenizeError {
  let tokens : Array[(@generated.Token, Int, Int)] = [
    (@generated.Token::LBRACE, fragment.open_start, fragment.open_start + 1),
  ]
  let parser = WgslDeclParser::{
    source_text: self.source_text,
    token_view: fragment.inner,
  }
  while parser.view().length() > 0 {
    match parser.view() {
      [Token::Other(44, pos), .. rest] => {
        parser.update_view(rest)
        tokens.push((@generated.Token::COMMA, pos, pos + 1))
        continue
      }
      [Token::Other(59, pos), .. rest] => {
        parser.update_view(rest)
        tokens.push((@generated.Token::SEMI, pos, pos + 1))
        continue
      }
      _ => ()
    }
    let attributes = parser.parse_attributes()
    tokens.push((@generated.Token::DECL_ATTRS(attributes), 0, 0))
    let name = match parser.consume_ident_node() {
      Some(value) => value
      None => raise WgslStructMembersTokenizeError::UnexpectedToken
    }
    tokens.push((@generated.Token::MEMBER_NAME(name), name.start, name.end))
    match parser.view() {
      [Token::Other(58, pos), .. rest] => {
        parser.update_view(rest)
        tokens.push((@generated.Token::COLON, pos, pos + 1))
      }
      _ => raise WgslStructMembersTokenizeError::UnexpectedToken
    }
    let ty_fragment = parser.collect_until_top_level_fragment([44, 59])
    if ty_fragment.text == "" {
      raise WgslStructMembersTokenizeError::UnexpectedToken
    }
    tokens.push(
      (
        @generated.Token::MEMBER_TYPE(
          (ty_fragment.text, parse_wgsl_type_ref_fragment(ty_fragment)),
        ),
        ty_fragment.start,
        ty_fragment.end,
      ),
    )
    match parser.view() {
      [Token::Other(44, _), ..] | [Token::Other(59, _), ..] => continue
      [] => break
      _ => raise WgslStructMembersTokenizeError::UnexpectedToken
    }
  }
  tokens.push(
    (@generated.Token::RBRACE, fragment.close_start, fragment.close_start + 1),
  )
  tokens.push(
    (@generated.Token::EOF, fragment.close_start + 1, fragment.close_start + 1),
  )
  tokens
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
fn WgslDeclParser::parse_source_directive(
  self : WgslDeclParser,
  keyword : WgslIdent,
  kind : WgslDirectiveKind,
) -> WgslDirective {
  let tail = self.collect_until_top_level_fragment([59]).text
  WgslDirective::{
    kind,
    name: keyword.name,
    tail,
    text: self.source_text.trim().to_owned(),
  }
}

///|
fn WgslDeclParser::decl_head_token(
  _self : WgslDeclParser,
  ident : WgslIdent,
) -> @generated.Token? {
  match ident.name {
    "virtual" => Some(@generated.Token::KW_VIRTUAL(ident))
    "override" => Some(@generated.Token::KW_OVERRIDE(ident))
    "fn" => Some(@generated.Token::KW_FN(ident))
    "var" => Some(@generated.Token::KW_VAR(ident))
    "struct" => Some(@generated.Token::KW_STRUCT(ident))
    "const" => Some(@generated.Token::KW_CONST(ident))
    "const_assert" => Some(@generated.Token::KW_CONST_ASSERT(ident))
    "alias" => Some(@generated.Token::KW_ALIAS(ident))
    "type" => Some(@generated.Token::KW_TYPE(ident))
    "enable" => Some(@generated.Token::KW_ENABLE(ident))
    "requires" => Some(@generated.Token::KW_REQUIRES(ident))
    "diagnostic" => Some(@generated.Token::KW_DIAGNOSTIC(ident))
    _ => None
  }
}

///|
fn WgslDeclParser::parse_decl_head(self : WgslDeclParser) -> WgslDeclHead {
  let attributes = self.parse_attributes()
  let tokens : Array[(@generated.Token, Int, Int)] = [
    (@generated.Token::DECL_ATTRS(attributes), 0, 0),
  ]
  let mut view = self.view()
  let mut emitted = 0
  while emitted < 2 {
    match view {
      [Token::Identifier(name, pos), .. rest] => {
        let ident = WgslIdent::{ name, start: pos, end: pos + name.length() }
        match self.decl_head_token(ident) {
          Some(token) => tokens.push((token, ident.start, ident.end))
          None => ()
        }
        view = rest
        emitted = emitted + 1
        continue
      }
      _ => break
    }
  }
  tokens.push(
    (
      @generated.Token::EOF,
      self.source_text.length(),
      self.source_text.length(),
    ),
  )
  let head = @generated.decl_head(tokens) catch {
    _ => WgslDeclHead::raw(attributes)
  }
  self.drop_tokens(head.consumed)
  head
}

///|
fn WgslDeclParser::parse_decl_data(self : WgslDeclParser) -> WgslGlobalDeclData {
  let head = self.parse_decl_head()
  match head.kind {
    Function =>
      match head.fn_keyword {
        Some(fn_keyword) =>
          match
            self.parse_function(
              head.attributes,
              head.qualifier,
              head.qualifier_start,
              head.qualifier_end,
              fn_keyword,
            ) {
            Some(function) => WgslGlobalDeclData::Function(function)
            None => WgslGlobalDeclData::Raw
          }
        None => WgslGlobalDeclData::Raw
      }
    Override =>
      match self.parse_override(head.attributes) {
        Some(value) => WgslGlobalDeclData::Override(value)
        None => WgslGlobalDeclData::Raw
      }
    GlobalVariable =>
      match self.parse_global_variable(head.attributes) {
        Some(value) => WgslGlobalDeclData::GlobalVariable(value)
        None => WgslGlobalDeclData::Raw
      }
    Struct =>
      match self.parse_struct(head.attributes) {
        Some(value) => WgslGlobalDeclData::Struct(value)
        None => WgslGlobalDeclData::Raw
      }
    Const =>
      match self.parse_const() {
        Some(value) => WgslGlobalDeclData::Const(value)
        None => WgslGlobalDeclData::Raw
      }
    ConstAssert =>
      WgslGlobalDeclData::ConstAssert(
        parse_required_wgsl_expr_ref_fragment(
          self.collect_until_top_level_fragment([59]),
        ),
      )
    TypeAlias =>
      match self.parse_type_alias() {
        Some(value) => WgslGlobalDeclData::TypeAlias(value)
        None => WgslGlobalDeclData::Raw
      }
    SourceDirective(kind) =>
      match head.keyword {
        Some(keyword) =>
          WgslGlobalDeclData::Directive(
            self.parse_source_directive(keyword, kind),
          )
        None => WgslGlobalDeclData::Raw
      }
    Raw => WgslGlobalDeclData::Raw
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
