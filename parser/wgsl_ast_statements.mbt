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
          (ty_fragment.text, parse_wgsl_type_ref_fragment(ty_fragment)),
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
        (@generated.Token::ARROW, arrow_start, arrow_end + 1),
      ]
      parser.push_attribute_tokens(tokens)
      let ty_fragment = parser.collect_until_top_level_fragment([123, 59])
      if ty_fragment.text == "" {
        return None
      }
      tokens.push(
        (
          @generated.Token::ARG_TYPE(
            (ty_fragment.text, parse_wgsl_type_ref_fragment(ty_fragment)),
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
fn wgsl_statement_local_name_from_tokens(
  tokens : Array[Token],
  is_local_decl : Bool,
) -> String? {
  guard is_local_decl else { return None }
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
fn collect_wgsl_statement_pending_local_name(
  tokens : Array[Token],
  index : Int,
  pending_local_names : Array[String],
) -> Int {
  match wgsl_statement_token_identifier(tokens[index]) {
    Some("var") => {
      let name_index = wgsl_statement_skip_template_tokens(tokens, index + 1)
      if name_index < tokens.length() {
        match wgsl_statement_token_identifier(tokens[name_index]) {
          Some(name) => pending_local_names.push(name)
          None => ()
        }
      }
      name_index
    }
    Some("let") | Some("const") => {
      let name_index = index + 1
      if name_index < tokens.length() {
        match wgsl_statement_token_identifier(tokens[name_index]) {
          Some(name) => pending_local_names.push(name)
          None => ()
        }
      }
      name_index
    }
    _ => -1
  }
}

///|
fn activate_wgsl_statement_pending_local_names(
  pending_local_names : Array[String],
  local_scopes : Array[Array[String]],
) -> Unit {
  guard local_scopes.length() > 0 else {
    pending_local_names.clear()
    return
  }
  let active_local_names = local_scopes[local_scopes.length() - 1]
  for name in pending_local_names {
    wgsl_name_list_push_unique(active_local_names, name)
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
  local_name : String?,
  identifiers : Array[WgslIdent],
) -> Unit {
  let pending_local_names : Array[String] = []
  let local_scopes : Array[Array[String]] = [[]]
  let mut skipped_local_name = false
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
          pending_local_names, local_scopes,
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
    match local_name {
      Some(name) if is_local_decl && !skipped_local_name && ident == name => {
        skipped_local_name = true
        continue
      }
      _ => ()
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
        tokens.push(Token::Other(123, pos))
        record_span(pos, pos + 1)
        self.update_view(rest)
        continue
      }
      [Token::Other(125, _), ..] if brace_depth == 0 => break
      [Token::Other(125, pos), .. rest] => {
        brace_depth = brace_depth - 1
        tokens.push(Token::Other(125, pos))
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
  if start_pos < 0 || end_pos < start_pos {
    None
  } else {
    let is_local_decl = wgsl_statement_is_local_decl(first_identifier)
    let local_name = wgsl_statement_local_name_from_tokens(
      tokens, is_local_decl,
    )
    collect_wgsl_statement_identifier_nodes(
      tokens, is_local_decl, local_name, identifiers,
    )
    Some(WgslStatement::{ local_name, identifiers })
  }
}

///|
fn WgslDeclParser::parse_block(self : WgslDeclParser) -> WgslBlock {
  let empty = WgslBlock::{ statements: [] }
  match self.collect_delimited_token_view(123, 125) {
    Some(fragment) => {
      let tokens : Array[(@generated.Token, Int, Int)] = [
        (@generated.Token::LBRACE, fragment.open_start, fragment.open_start + 1),
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
          @generated.Token::RBRACE,
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
