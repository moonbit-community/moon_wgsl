///|
fn wgsl_name_list_contains(names : Array[String], name : String) -> Bool {
  for existing in names {
    if existing == name {
      return true
    }
  }
  false
}

///|
fn wgsl_name_list_push_unique(names : Array[String], name : String) -> Unit {
  if name == "" || wgsl_name_list_contains(names, name) {
    return
  }
  names.push(name)
}

///|
fn WgslDeclParser::parse_function_arguments(
  self : WgslDeclParser,
) -> Array[WgslFunctionArgument] {
  match self.collect_delimited_token_view(40, 41) {
    Some(fragment) => {
      let tokens = self.tokenize_function_arguments(fragment) catch {
        _ => return []
      }
      let arguments = @generated.function_args(tokens) catch { _ => return [] }
      self.drop_tokens(fragment.consumed)
      arguments
    }
    None => []
  }
}

///|
priv suberror WgslFunctionArgsTokenizeError {
  UnexpectedToken
}

///|
fn WgslDeclParser::tokenize_function_arguments(
  self : WgslDeclParser,
  fragment : WgslDelimitedTokenView,
) -> Array[(@generated.Token, Int, Int)] raise WgslFunctionArgsTokenizeError {
  let tokens : Array[(@generated.Token, Int, Int)] = [
    (@generated.Token::LPAREN, fragment.open_start, fragment.open_start + 1),
  ]
  let parser = WgslDeclParser::{
    source_text: self.source_text,
    token_view: fragment.inner,
  }
  while parser.view().length() > 0 {
    if parser.consume_if_other(44) {
      tokens.push((@generated.Token::COMMA, 0, 0))
      continue
    }
    parser.push_attribute_tokens(tokens)
    let name = match parser.consume_ident_node() {
      Some(value) => value
      None => raise WgslFunctionArgsTokenizeError::UnexpectedToken
    }
    tokens.push((@generated.Token::ARG_NAME(name), name.start, name.end))
    match parser.view() {
      [Token::Other(58, pos), .. rest] => {
        parser.update_view(rest)
        tokens.push((@generated.Token::COLON, pos, pos + 1))
      }
      _ => raise WgslFunctionArgsTokenizeError::UnexpectedToken
    }
    let ty_fragment = parser.collect_until_top_level_fragment([44])
    if ty_fragment.text == "" {
      raise WgslFunctionArgsTokenizeError::UnexpectedToken
    }
    tokens.push(
      (
        @generated.Token::ARG_TYPE(
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
      [Token::Other(44, _), ..] => continue
      [] => break
      _ => raise WgslFunctionArgsTokenizeError::UnexpectedToken
    }
  }
  tokens.push(
    (@generated.Token::RPAREN, fragment.close_start, fragment.close_start + 1),
  )
  tokens.push(
    (@generated.Token::EOF, fragment.close_start + 1, fragment.close_start + 1),
  )
  tokens
}

///|
fn WgslDeclParser::parse_function_result(
  self : WgslDeclParser,
) -> WgslFunctionResult? {
  match self.view() {
    [Token::Other(45, arrow_start), Token::Other(62, arrow_end), .. rest] => {
      let parser = WgslDeclParser::{
        source_text: self.source_text,
        token_view: rest,
      }
      let rest_len = rest.length()
      let tokens : Array[(@generated.Token, Int, Int)] = [
        (@generated.Token::ARROW(arrow_start), arrow_start, arrow_end + 1),
      ]
      parser.push_attribute_tokens(tokens)
      let ty_fragment = parser.collect_until_top_level_fragment([123, 59])
      if ty_fragment.text == "" {
        return None
      }
      tokens.push(
        (
          @generated.Token::ARG_TYPE(
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
      tokens.push((@generated.Token::EOF, ty_fragment.end, ty_fragment.end))
      let result = @generated.function_result(tokens) catch { _ => return None }
      self.drop_tokens(2 + rest_len - parser.view().length())
      result
    }
    _ => None
  }
}

///|
fn wgsl_statement_is_local_decl(first_identifier : String?) -> Bool {
  match first_identifier {
    Some("var") | Some("let") | Some("const") => true
    _ => false
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
fn wgsl_statement_local_declaration_from_tokens(
  tokens : Array[Token],
  is_local_decl : Bool,
) -> WgslIdent? {
  guard is_local_decl else { return None }
  for i in 0..<tokens.length() {
    match wgsl_statement_token_identifier(tokens[i]) {
      Some("var") => {
        let name_index = wgsl_statement_skip_template_tokens(tokens, i + 1)
        if name_index < tokens.length() {
          return match tokens[name_index] {
            Token::Identifier(name, pos) =>
              Some(WgslIdent::{ name, start: pos, end: pos + name.length() })
            _ => None
          }
        }
        return None
      }
      Some("let") | Some("const") =>
        if i + 1 < tokens.length() {
          return match tokens[i + 1] {
            Token::Identifier(name, pos) =>
              Some(WgslIdent::{ name, start: pos, end: pos + name.length() })
            _ => None
          }
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
fn collect_wgsl_statement_pending_local_name(
  tokens : Array[Token],
  index : Int,
  pending_local_names : Array[WgslIdent],
) -> Int {
  match wgsl_statement_token_identifier(tokens[index]) {
    Some("var") => {
      let name_index = wgsl_statement_skip_template_tokens(tokens, index + 1)
      if name_index < tokens.length() {
        match tokens[name_index] {
          Token::Identifier(name, pos) =>
            pending_local_names.push(WgslIdent::{
              name,
              start: pos,
              end: pos + name.length(),
            })
          _ => ()
        }
      }
      name_index
    }
    Some("let") | Some("const") => {
      let name_index = index + 1
      if name_index < tokens.length() {
        match tokens[name_index] {
          Token::Identifier(name, pos) =>
            pending_local_names.push(WgslIdent::{
              name,
              start: pos,
              end: pos + name.length(),
            })
          _ => ()
        }
      }
      name_index
    }
    _ => -1
  }
}

///|
fn activate_wgsl_statement_pending_local_names(
  pending_local_names : Array[WgslIdent],
  local_scopes : Array[Array[String]],
  local_declarations : Array[WgslIdent],
) -> Unit {
  guard local_scopes.length() > 0 else {
    pending_local_names.clear()
    return
  }
  let active_local_names = local_scopes[local_scopes.length() - 1]
  for node in pending_local_names {
    wgsl_name_list_push_unique(active_local_names, node.name)
    local_declarations.push(node)
  }
  pending_local_names.clear()
}

///|
fn wgsl_statement_scope_contains(
  local_scopes : Array[Array[String]],
  name : String,
) -> Bool {
  for scope in local_scopes {
    if wgsl_name_list_contains(scope, name) {
      return true
    }
  }
  false
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
  is_local_decl : Bool,
  exported_locals : Array[WgslIdent],
  local_declarations : Array[WgslIdent],
  identifiers : Array[WgslIdent],
) -> Unit {
  let pending_local_names : Array[WgslIdent] = []
  let local_scopes : Array[Array[String]] = [[]]
  let mut binding_index = -1
  for i in 0..<tokens.length() {
    match wgsl_statement_token_other_code(tokens[i]) {
      Some(123) => {
        local_scopes.push([])
        continue
      }
      Some(125) => {
        if local_scopes.length() > 1 {
          local_scopes.pop() |> ignore
        }
        continue
      }
      Some(59) => {
        activate_wgsl_statement_pending_local_names(
          pending_local_names, local_scopes, local_declarations,
        )
        continue
      }
      _ => ()
    }
    match wgsl_statement_token_identifier(tokens[i]) {
      Some("var") | Some("let") | Some("const") if !is_local_decl =>
        binding_index = collect_wgsl_statement_pending_local_name(
          tokens, i, pending_local_names,
        )
      _ => ()
    }
    guard tokens[i] is Token::Identifier(ident, pos) else { continue }
    if wgsl_statement_identifier_has_access_prefix(tokens, i) {
      continue
    }
    if i == binding_index {
      continue
    }
    let mut is_exported_local = false
    if is_local_decl {
      for binding in exported_locals {
        if binding.start == pos && binding.name == ident {
          is_exported_local = true
        }
      }
    }
    if is_exported_local {
      continue
    }
    if wgsl_statement_scope_contains(local_scopes, ident) {
      continue
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
  let depth = WgslTokenDepth::new()
  fn record_span(start : Int, end_ : Int) -> Unit {
    if start_pos < 0 {
      start_pos = start
    }
    end_pos = end_
  }
  fn record_token(token : Token) -> Unit {
    record_span(token.pos(), token.end())
  }
  while true {
    match self.view() {
      [Token::Other(125, _), ..] if depth.at_top() => break
      [Token::Other(59, pos), .. rest] if depth.at_top() => {
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
        depth.observe_statement_token(token)
        record_token(token)
        self.update_view(rest)
        if depth.at_top() && token is Token::Other(125, _) {
          break
        }
        continue
      }
      [] => break
    }
  }
  if start_pos < 0 || end_pos < start_pos {
    None
  } else {
    let text = self.source_text[start_pos:end_pos].to_owned()
    let is_local_decl = wgsl_statement_is_local_decl(first_identifier)
    let local_declarations : Array[WgslIdent] = []
    let exported_locals : Array[WgslIdent] = []
    match wgsl_statement_local_declaration_from_tokens(tokens, is_local_decl) {
      Some(binding) => {
        local_declarations.push(binding)
        exported_locals.push(binding)
      }
      None => ()
    }
    collect_wgsl_statement_identifier_nodes(
      tokens, is_local_decl, exported_locals, local_declarations, identifiers,
    )
    Some(WgslStatement::{
      text,
      start: start_pos,
      end: end_pos,
      local_declarations,
      exported_locals,
      identifiers,
    })
  }
}

///|
fn WgslDeclParser::parse_block(self : WgslDeclParser) -> WgslBlock {
  let empty = WgslBlock::{ start: 0, end: 0, statements: [] }
  match self.collect_delimited_token_view(123, 125) {
    Some(fragment) => {
      let tokens : Array[(@generated.Token, Int, Int)] = [
        (
          @generated.Token::LBRACE(fragment.open_start),
          fragment.open_start,
          fragment.open_start + 1,
        ),
      ]
      let parser = WgslDeclParser::{
        source_text: self.source_text,
        token_view: fragment.inner,
      }
      while parser.view().length() > 0 {
        match parser.collect_statement() {
          Some(statement) =>
            tokens.push((@generated.Token::STMT(statement), 0, 0))
          None => if parser.view() is [] { break } else { return empty }
        }
      }
      tokens.push(
        (
          @generated.Token::RBRACE(fragment.close_start),
          fragment.close_start,
          fragment.close_start + 1,
        ),
      )
      tokens.push(
        (
          @generated.Token::EOF,
          fragment.close_start + 1,
          fragment.close_start + 1,
        ),
      )
      let block = @generated.block(tokens) catch { _ => return empty }
      self.drop_tokens(fragment.consumed)
      block
    }
    None => empty
  }
}

///|
