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
  Some(
    WgslFunction::new(
      attributes,
      qualifier,
      qualifier_start,
      qualifier_end,
      fn_keyword.start,
      fn_keyword.end,
      name,
      arguments,
      result,
      body,
    ),
  )
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
      let members = struct_members(tokens) catch { _ => return [] }
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
) -> Array[(Token, Int, Int)] raise WgslStructMembersTokenizeError {
  let tokens : Array[(Token, Int, Int)] = [
    (
      Token::LBRACE(fragment.open_start),
      fragment.open_start,
      fragment.open_start + 1,
    ),
  ]
  let parser = WgslDeclParser::{
    source_text: self.source_text,
    source_start: self.source_start,
    token_view: fragment.inner,
  }
  while parser.view().length() > 0 {
    match parser.view() {
      [WgslToken::Other(44, pos), .. rest] => {
        parser.update_view(rest)
        tokens.push((Token::COMMA, pos, pos + 1))
        continue
      }
      [WgslToken::Other(59, pos), .. rest] => {
        parser.update_view(rest)
        tokens.push((Token::SEMI, pos, pos + 1))
        continue
      }
      _ => ()
    }
    parser.push_attribute_tokens(tokens)
    let name = match parser.consume_ident_node() {
      Some(value) => value
      None => raise WgslStructMembersTokenizeError::UnexpectedToken
    }
    tokens.push((Token::MEMBER_NAME(name), name.start, name.end))
    match parser.view() {
      [WgslToken::Other(58, pos), .. rest] => {
        parser.update_view(rest)
        tokens.push((Token::COLON, pos, pos + 1))
      }
      _ => raise WgslStructMembersTokenizeError::UnexpectedToken
    }
    let ty_fragment = parser.collect_until_top_level_fragment([44, 59])
    if ty_fragment.text == "" {
      raise WgslStructMembersTokenizeError::UnexpectedToken
    }
    tokens.push(
      (
        Token::MEMBER_TYPE(
          (
            ty_fragment.text,
            parse_wgsl_type_ref_fragment(ty_fragment),
            ty_fragment.start,
            ty_fragment.end,
          ),
        ),
        ty_fragment.start,
        ty_fragment.end,
      ),
    )
    match parser.view() {
      [WgslToken::Other(44, _), ..] | [WgslToken::Other(59, _), ..] => continue
      [] => break
      _ => raise WgslStructMembersTokenizeError::UnexpectedToken
    }
  }
  tokens.push(
    (
      Token::RBRACE(fragment.close_start),
      fragment.close_start,
      fragment.close_start + 1,
    ),
  )
  tokens.push((Token::EOF, fragment.close_start + 1, fragment.close_start + 1))
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
  Some(WgslStruct::new(attributes, name, self.parse_struct_members()))
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
  let tail = self.parse_typed_initializer_tail()
  Some(
    WgslGlobalVariable::new(
      attributes,
      name,
      template_list,
      tail.ty,
      tail.ty_ref,
      tail.initializer,
      tail.initializer_ref,
    ),
  )
}

///|
priv struct WgslTypedInitializerTail {
  ty : String?
  ty_ref : WgslTypeRef?
  initializer : String?
  initializer_ref : WgslExprRef?
}

///|
fn WgslTypedInitializerTail::empty() -> WgslTypedInitializerTail {
  WgslTypedInitializerTail::{
    ty: None,
    ty_ref: None,
    initializer: None,
    initializer_ref: None,
  }
}

///|
fn WgslDeclParser::parse_typed_initializer_tail(
  self : WgslDeclParser,
) -> WgslTypedInitializerTail {
  let tokens : Array[(Token, Int, Int)] = []
  match self.view() {
    [WgslToken::Other(58, pos), .. rest] => {
      self.update_view(rest)
      tokens.push((Token::COLON, pos, pos + 1))
      let ty_fragment = self.collect_until_top_level_fragment([61, 59])
      if ty_fragment.text != "" {
        tokens.push(
          (
            Token::DECL_TYPE(
              (
                ty_fragment.text,
                parse_wgsl_type_ref_fragment(ty_fragment),
                ty_fragment.start,
                ty_fragment.end,
              ),
            ),
            ty_fragment.start,
            ty_fragment.end,
          ),
        )
      }
    }
    _ => ()
  }
  match self.view() {
    [WgslToken::Other(61, pos), .. rest] => {
      self.update_view(rest)
      tokens.push((Token::EQUAL, pos, pos + 1))
      let initializer = self.collect_until_top_level_fragment([59])
      if initializer.text != "" {
        tokens.push(
          (
            Token::INIT_EXPR(
              (initializer.text, parse_wgsl_expr_ref_fragment(initializer)),
            ),
            initializer.start,
            initializer.end,
          ),
        )
      }
    }
    _ => ()
  }
  tokens.push(
    (Token::EOF, self.source_text.length(), self.source_text.length()),
  )
  let parsed = typed_initializer_tail(tokens) catch {
    _ => return WgslTypedInitializerTail::empty()
  }
  match parsed {
    (ty, ty_ref, initializer, initializer_ref) =>
      WgslTypedInitializerTail::{ ty, ty_ref, initializer, initializer_ref }
  }
}

///|
fn WgslDeclParser::parse_const(self : WgslDeclParser) -> WgslConst? {
  let name = match self.consume_ident_node() {
    Some(value) => value
    None => return None
  }
  let tail = self.parse_typed_initializer_tail()
  Some(
    WgslConst::new(
      name,
      tail.ty,
      tail.ty_ref,
      tail.initializer,
      tail.initializer_ref,
    ),
  )
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
  let tail = self.parse_typed_initializer_tail()
  Some(
    WgslOverride::new(
      attributes,
      name,
      tail.ty,
      tail.ty_ref,
      tail.initializer,
      tail.initializer_ref,
    ),
  )
}

///|
fn WgslDeclParser::parse_type_alias(self : WgslDeclParser) -> WgslTypeAlias? {
  let name = match self.consume_ident_node() {
    Some(value) => value
    None => return None
  }
  match self.parse_type_alias_tail() {
    Some((ty, ty_ref)) => Some(WgslTypeAlias::new(name, ty, ty_ref))
    None => None
  }
}

///|
fn WgslDeclParser::parse_type_alias_tail(
  self : WgslDeclParser,
) -> (String, WgslTypeRef?)? {
  let tokens : Array[(Token, Int, Int)] = []
  match self.view() {
    [WgslToken::Other(61, pos), .. rest] => {
      self.update_view(rest)
      tokens.push((Token::EQUAL, pos, pos + 1))
    }
    _ => return None
  }
  let ty_fragment = self.collect_until_top_level_fragment([59])
  if ty_fragment.text == "" {
    return None
  }
  tokens.push(
    (
      Token::DECL_TYPE(
        (
          ty_fragment.text,
          parse_wgsl_type_ref_fragment(ty_fragment),
          ty_fragment.start,
          ty_fragment.end,
        ),
      ),
      ty_fragment.start,
      ty_fragment.end,
    ),
  )
  tokens.push((Token::EOF, ty_fragment.end, ty_fragment.end))
  Some(type_alias_tail(tokens) catch { _ => return None })
}

///|
fn WgslDeclParser::parse_source_directive(
  self : WgslDeclParser,
  keyword : WgslIdent,
  token : Token,
) -> WgslDirective? {
  let tail_fragment = self.collect_until_top_level_fragment([59])
  let text = wgsl_trim_blankspace(self.source_text)
  let (tail_text, tail_start, tail_end) = if tail_fragment.start >= 0 {
    let (trimmed, local_start, local_end) = wgsl_trim_fragment_bounds(
      self.source_text,
      tail_fragment.start - self.source_start,
      tail_fragment.end - self.source_start,
    )
    (trimmed, self.source_start + local_start, self.source_start + local_end)
  } else {
    ("", keyword.end, keyword.end)
  }
  let tokens : Array[(Token, Int, Int)] = [
    (Token::SOURCE_TEXT(text), 0, 0),
    (token, keyword.start, keyword.end),
  ]
  if tail_text != "" {
    tokens.push(
      (
        Token::DIRECTIVE_TAIL((tail_text, tail_start, tail_end)),
        tail_start,
        tail_end,
      ),
    )
  }
  tokens.push(
    (Token::EOF, self.source_text.length(), self.source_text.length()),
  )
  Some(source_directive(tokens) catch { _ => return None })
}

///|
fn WgslDeclParser::parse_const_assert(self : WgslDeclParser) -> WgslExprRef {
  let expr = parse_required_wgsl_expr_ref_fragment(
    self.collect_until_top_level_fragment([59]),
  )
  let tokens : Array[(Token, Int, Int)] = [
    (Token::EXPR_REF(expr), expr.start, expr.end),
    (Token::EOF, expr.end, expr.end),
  ]
  const_assert_expr(tokens) catch {
    _ => expr
  }
}

///|
fn WgslDeclParser::decl_head_token(
  _self : WgslDeclParser,
  ident : WgslIdent,
) -> Token? {
  match ident.name {
    "virtual" => Some(Token::KW_VIRTUAL(ident))
    "override" => Some(Token::KW_OVERRIDE(ident))
    "fn" => Some(Token::KW_FN(ident))
    "var" => Some(Token::KW_VAR(ident))
    "struct" => Some(Token::KW_STRUCT(ident))
    "const" => Some(Token::KW_CONST(ident))
    "const_assert" => Some(Token::KW_CONST_ASSERT(ident))
    "alias" => Some(Token::KW_ALIAS(ident))
    "type" => Some(Token::KW_TYPE(ident))
    "enable" => Some(Token::KW_ENABLE(ident))
    "requires" => Some(Token::KW_REQUIRES(ident))
    "diagnostic" => Some(Token::KW_DIAGNOSTIC(ident))
    _ => None
  }
}

///|
fn WgslDeclParser::parse_decl_head(self : WgslDeclParser) -> WgslDeclHead {
  let tokens : Array[(Token, Int, Int)] = []
  self.push_attribute_tokens(tokens)
  let mut view = self.view()
  let mut emitted = 0
  while emitted < 2 {
    match view {
      [WgslToken::Identifier(name, pos), .. rest] => {
        let ident = WgslIdent::new(name, pos, pos + name.length())
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
    (Token::EOF, self.source_text.length(), self.source_text.length()),
  )
  let head = decl_head(tokens) catch { _ => WgslDeclHead::raw([]) }
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
    ConstAssert => WgslGlobalDeclData::ConstAssert(self.parse_const_assert())
    TypeAlias =>
      match self.parse_type_alias() {
        Some(value) => WgslGlobalDeclData::TypeAlias(value)
        None => WgslGlobalDeclData::Raw
      }
    SourceDirective =>
      match head.keyword {
        Some(keyword) =>
          match self.decl_head_token(keyword) {
            Some(token) =>
              match self.parse_source_directive(keyword, token) {
                Some(value) => WgslGlobalDeclData::Directive(value)
                None => WgslGlobalDeclData::Raw
              }
            None => WgslGlobalDeclData::Raw
          }
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
