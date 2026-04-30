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
fn collect_wgsl_statement_local_names_from_tokens(
  tokens : Array[Token],
  names : Array[String],
) -> Unit {
  for i in 0..<tokens.length() {
    match wgsl_statement_token_identifier(tokens[i]) {
      Some("var") => {
        let name_index = wgsl_statement_skip_template_tokens(tokens, i + 1)
        if name_index < tokens.length() {
          match wgsl_statement_token_identifier(tokens[name_index]) {
            Some(name) => wgsl_name_list_push_unique(names, name)
            None => ()
          }
        }
      }
      Some("let") | Some("const") =>
        if i + 1 < tokens.length() {
          match wgsl_statement_token_identifier(tokens[i + 1]) {
            Some(name) => wgsl_name_list_push_unique(names, name)
            None => ()
          }
        }
      _ => ()
    }
  }
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
  local_names : Array[String],
  identifiers : Array[WgslIdent],
) -> Unit {
  let mut skipped_local_name = false
  for i in 0..<tokens.length() {
    guard tokens[i] is Token::Identifier(ident, pos) else { continue }
    if wgsl_statement_identifier_has_access_prefix(tokens, i) {
      continue
    }
    match local_name {
      Some(name) if is_local_decl && !skipped_local_name && ident == name => {
        skipped_local_name = true
        continue
      }
      _ => ()
    }
    if wgsl_name_list_contains(local_names, ident) {
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
  if start_pos < 0 || end_pos < start_pos {
    None
  } else {
    let is_local_decl = wgsl_statement_is_local_decl(first_identifier)
    let local_name = wgsl_statement_local_name_from_tokens(
      tokens, is_local_decl,
    )
    let local_names : Array[String] = []
    collect_wgsl_statement_local_names_from_tokens(tokens, local_names)
    collect_wgsl_statement_identifier_nodes(
      tokens, is_local_decl, local_name, local_names, identifiers,
    )
    Some(WgslStatement::{ local_name, identifiers })
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
