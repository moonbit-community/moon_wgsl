///|
priv suberror WgslFunctionArgsParseError {
  UnexpectedToken
}

///|
fn WgslDeclParser::parse_function_arguments_checked(
  self : WgslDeclParser,
) -> Array[WgslFunctionArgument] raise WgslFunctionArgsParseError {
  match self.collect_delimited_token_view(40, 41) {
    Some(fragment) => {
      let tokens = self.tokenize_function_arguments(fragment) catch {
        _ => raise WgslFunctionArgsParseError::UnexpectedToken
      }
      let arguments = function_args(tokens) catch {
        _ => raise WgslFunctionArgsParseError::UnexpectedToken
      }
      self.drop_tokens(fragment.consumed)
      arguments
    }
    None => raise WgslFunctionArgsParseError::UnexpectedToken
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
) -> Array[(Token, Int, Int)] raise WgslFunctionArgsTokenizeError {
  let tokens : Array[(Token, Int, Int)] = [
    (Token::LPAREN, fragment.open_start, fragment.open_start + 1),
  ]
  let parser = WgslDeclParser::{
    source_text: self.source_text,
    source_start: self.source_start,
    token_view: fragment.inner,
  }
  while parser.view().length() > 0 {
    match parser.view() {
      [WgslToken::Other(35, hash_pos), ..] =>
        match parser.directive_line_end_at_hash(hash_pos) {
          Some(line_end) => {
            while parser.view().length() > 0 &&
                  parser.view()[0].pos() < line_end {
              parser.drop_tokens(1)
            }
            continue
          }
          None => ()
        }
      _ => ()
    }
    if parser.consume_if_other(44) {
      tokens.push((Token::COMMA, 0, 0))
      continue
    }
    parser.push_attribute_tokens(tokens)
    let name = match parser.consume_ident_node() {
      Some(value) => value
      None => raise WgslFunctionArgsTokenizeError::UnexpectedToken
    }
    tokens.push((Token::ARG_NAME(name), name.start, name.end))
    match parser.view() {
      [WgslToken::Other(58, pos), .. rest] => {
        parser.update_view(rest)
        tokens.push((Token::COLON, pos, pos + 1))
      }
      _ => raise WgslFunctionArgsTokenizeError::UnexpectedToken
    }
    let ty_fragment = parser.collect_until_top_level_fragment([44])
    if ty_fragment.text == "" {
      raise WgslFunctionArgsTokenizeError::UnexpectedToken
    }
    tokens.push(
      (
        Token::ARG_TYPE(
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
      [WgslToken::Other(44, _), ..] => continue
      [] => break
      _ => raise WgslFunctionArgsTokenizeError::UnexpectedToken
    }
  }
  tokens.push((Token::RPAREN, fragment.close_start, fragment.close_start + 1))
  tokens.push((Token::EOF, fragment.close_start + 1, fragment.close_start + 1))
  tokens
}

///|
fn WgslDeclParser::parse_function_result(
  self : WgslDeclParser,
) -> WgslFunctionResult? {
  match self.view() {
    [
      WgslToken::Other(45, arrow_start),
      WgslToken::Other(62, arrow_end),
      .. rest,
    ] => {
      let parser = WgslDeclParser::{
        source_text: self.source_text,
        source_start: self.source_start,
        token_view: rest,
      }
      let rest_len = rest.length()
      let tokens : Array[(Token, Int, Int)] = [
        (Token::ARROW(arrow_start), arrow_start, arrow_end + 1),
      ]
      parser.push_attribute_tokens(tokens)
      let ty_fragment = parser.collect_until_top_level_fragment([123, 59])
      if ty_fragment.text == "" {
        return None
      }
      tokens.push(
        (
          Token::ARG_TYPE(
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
      let result = function_result(tokens) catch { _ => return None }
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
fn wgsl_statement_kind_from_tokens(
  first_identifier : String?,
  tokens : Array[WgslToken],
) -> WgslStatementKind {
  match first_identifier {
    Some("var") | Some("let") | Some("const") =>
      WgslStatementKind::LocalDeclaration
    Some("return") => WgslStatementKind::Return
    Some("if") => WgslStatementKind::If
    Some("for") => WgslStatementKind::For
    Some("while") => WgslStatementKind::While
    Some("loop") => WgslStatementKind::Loop
    Some("switch") => WgslStatementKind::Switch
    Some("break") => WgslStatementKind::Break
    Some("continue") => WgslStatementKind::Continue
    Some("discard") => WgslStatementKind::Discard
    Some("const_assert") => WgslStatementKind::ConstAssert
    Some(_) => WgslStatementKind::Expression
    None =>
      match tokens {
        [WgslToken::Other(123, _), ..] => WgslStatementKind::Compound
        [] => WgslStatementKind::Empty
        _ => WgslStatementKind::Expression
      }
  }
}

///|
fn wgsl_statement_token_identifier(token : WgslToken) -> String? {
  match token {
    WgslToken::Identifier(ident, _) => Some(ident)
    _ => None
  }
}

///|
fn WgslDeclParser::parse_statement_local_binding(
  self : WgslDeclParser,
  tokens : Array[WgslToken],
  keyword_index : Int,
) -> WgslLocalDeclaration? {
  guard keyword_index >= 0 && keyword_index < tokens.length() else {
    return None
  }
  let kind = match wgsl_statement_token_identifier(tokens[keyword_index]) {
    Some("var") => "var"
    Some("let") => "let"
    Some("const") => "const"
    _ => return None
  }
  let parser = WgslDeclParser::{
    source_text: self.source_text,
    source_start: self.source_start,
    token_view: tokens[keyword_index + 1:],
  }
  let template_list = if kind == "var" {
    parser.parse_template_list()
  } else {
    []
  }
  let name = match parser.consume_ident_node() {
    Some(value) => value
    None => return None
  }
  let tail = parser.parse_typed_initializer_tail()
  Some(
    WgslLocalDeclaration::new(
      kind,
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
fn collect_wgsl_statement_local_binding(
  tokens : Array[WgslToken],
  index : Int,
  local_bindings : Array[WgslLocalDeclaration],
  owner : WgslDeclParser,
) -> Unit {
  match wgsl_statement_token_identifier(tokens[index]) {
    Some("var") =>
      match owner.parse_statement_local_binding(tokens, index) {
        Some(binding) => local_bindings.push(binding)
        None => ()
      }
    Some("let") | Some("const") =>
      match owner.parse_statement_local_binding(tokens, index) {
        Some(binding) => local_bindings.push(binding)
        None => ()
      }
    _ => ()
  }
}

///|
fn collect_wgsl_statement_local_bindings(
  owner : WgslDeclParser,
  tokens : Array[WgslToken],
  is_local_decl : Bool,
  local_bindings : Array[WgslLocalDeclaration],
) -> Unit {
  guard !is_local_decl else { return }
  for i in 0..<tokens.length() {
    match wgsl_statement_token_identifier(tokens[i]) {
      Some("var") | Some("let") | Some("const") =>
        collect_wgsl_statement_local_binding(tokens, i, local_bindings, owner)
      _ => ()
    }
  }
}

///|
fn WgslDeclParser::parse_block_tokens(
  self : WgslDeclParser,
  open_start : Int,
  close_start : Int,
  inner : ArrayView[WgslToken],
) -> WgslBlock {
  let empty = WgslBlock::new(0, 0, [])
  let tokens : Array[(Token, Int, Int)] = [
    (Token::LBRACE(open_start), open_start, open_start + 1),
  ]
  let parser = WgslDeclParser::{
    source_text: self.source_text,
    source_start: self.source_start,
    token_view: inner,
  }
  while parser.view().length() > 0 {
    match parser.collect_statement() {
      Some(statement) => tokens.push((Token::STMT(statement), 0, 0))
      None => if parser.view() is [] { break } else { return empty }
    }
  }
  tokens.push((Token::RBRACE(close_start), close_start, close_start + 1))
  tokens.push((Token::EOF, close_start + 1, close_start + 1))
  block(tokens) catch {
    _ => empty
  }
}

///|
fn WgslDeclParser::collect_statement_blocks(
  self : WgslDeclParser,
  tokens : Array[WgslToken],
) -> Array[WgslBlock] {
  let blocks : Array[WgslBlock] = []
  let open_stack : Array[Int] = []
  for i in 0..<tokens.length() {
    match tokens[i] {
      WgslToken::Other(123, _) => open_stack.push(i)
      WgslToken::Other(125, close_start) =>
        match open_stack.pop() {
          Some(open_index) =>
            if open_stack.is_empty() {
              let open_start = tokens[open_index].pos()
              blocks.push(
                self.parse_block_tokens(
                  open_start,
                  close_start,
                  tokens[open_index + 1:i],
                ),
              )
            }
          None => ()
        }
      _ => ()
    }
  }
  blocks
}

///|
fn collect_wgsl_statement_scope_tokens(
  tokens : Array[WgslToken],
) -> Array[WgslToken] {
  let scope_tokens : Array[WgslToken] = []
  let mut block_depth = 0
  for token in tokens {
    match token {
      WgslToken::Other(123, _) => {
        block_depth = block_depth + 1
        continue
      }
      WgslToken::Other(125, _) if block_depth > 0 => {
        block_depth = block_depth - 1
        continue
      }
      _ => ()
    }
    if block_depth == 0 {
      scope_tokens.push(token)
    }
  }
  scope_tokens
}

///|
fn wgsl_statement_top_level_token_index(
  tokens : Array[WgslToken],
  start : Int,
  code : Int,
) -> Int {
  wgsl_statement_top_level_token_index_until(
    tokens,
    start,
    tokens.length(),
    code,
  )
}

///|
fn wgsl_statement_top_level_token_index_until(
  tokens : Array[WgslToken],
  start : Int,
  end_ : Int,
  code : Int,
) -> Int {
  let depth = WgslTokenDepth::new()
  let limit = if end_ < tokens.length() { end_ } else { tokens.length() }
  for i in start..<limit {
    match tokens[i] {
      WgslToken::Other(actual, _) if depth.at_top() && actual == code =>
        return i
      _ => ()
    }
    depth.observe_statement_token(tokens[i])
  }
  -1
}

///|
fn wgsl_statement_delimited_end(
  tokens : Array[WgslToken],
  open_index : Int,
  open_code : Int,
  close_code : Int,
) -> Int {
  guard open_index >= 0 && open_index < tokens.length() else { return -1 }
  guard tokens[open_index] is WgslToken::Other(code, _) && code == open_code else {
    return -1
  }
  let mut depth = 0
  for i in open_index..<tokens.length() {
    match tokens[i] {
      WgslToken::Other(actual, _) if actual == open_code => depth = depth + 1
      WgslToken::Other(actual, _) if actual == close_code => {
        depth = depth - 1
        if depth == 0 {
          return i
        }
      }
      _ => ()
    }
  }
  -1
}

///|
fn wgsl_statement_push_expr_ref(
  owner : WgslDeclParser,
  tokens : Array[WgslToken],
  start : Int,
  end_ : Int,
  expression_refs : Array[WgslExprRef],
) -> Unit {
  guard start >= 0 && end_ > start && end_ <= tokens.length() else { return }
  let expr_start = tokens[start].pos()
  let expr_end = tokens[end_ - 1].end()
  match
    parse_wgsl_expr_ref_text(owner.slice(expr_start, expr_end), expr_start) {
    Some(expr) => expression_refs.push(expr)
    None => ()
  }
}

///|
fn wgsl_statement_top_level_identifier_index(
  tokens : Array[WgslToken],
  start : Int,
  end_ : Int,
  ident : String,
) -> Int {
  let depth = WgslTokenDepth::new()
  let limit = if end_ < tokens.length() { end_ } else { tokens.length() }
  for i in start..<limit {
    match tokens[i] {
      WgslToken::Identifier(actual, _) if depth.at_top() && actual == ident =>
        return i
      _ => ()
    }
    depth.observe_statement_token(tokens[i])
  }
  -1
}

///|
fn wgsl_statement_starts_with_local_binding(
  tokens : Array[WgslToken],
  start : Int,
  end_ : Int,
) -> Bool {
  guard start >= 0 && start < end_ && start < tokens.length() else {
    return false
  }
  match tokens[start] {
    WgslToken::Identifier("var", _)
    | WgslToken::Identifier("let", _)
    | WgslToken::Identifier("const", _) => true
    _ => false
  }
}

///|
fn wgsl_statement_collect_condition_expr(
  owner : WgslDeclParser,
  tokens : Array[WgslToken],
  keyword_index : Int,
  expression_refs : Array[WgslExprRef],
) -> Int {
  let expr_start = keyword_index + 1
  guard expr_start < tokens.length() else { return expr_start }
  match tokens[expr_start] {
    WgslToken::Other(40, _) => {
      let close_index = wgsl_statement_delimited_end(tokens, expr_start, 40, 41)
      if close_index > expr_start {
        wgsl_statement_push_expr_ref(
          owner,
          tokens,
          expr_start + 1,
          close_index,
          expression_refs,
        )
        return close_index + 1
      }
      expr_start
    }
    _ => {
      let else_index = wgsl_statement_top_level_identifier_index(
        tokens,
        expr_start,
        tokens.length(),
        "else",
      )
      let expr_end = if else_index >= 0 { else_index } else { tokens.length() }
      wgsl_statement_push_expr_ref(
        owner, tokens, expr_start, expr_end, expression_refs,
      )
      expr_end
    }
  }
}

///|
fn wgsl_statement_collect_for_header_exprs(
  owner : WgslDeclParser,
  tokens : Array[WgslToken],
  for_index : Int,
  expression_refs : Array[WgslExprRef],
) -> Int {
  let header_start = for_index + 1
  guard header_start < tokens.length() else { return header_start }
  guard tokens[header_start] is WgslToken::Other(40, _) else {
    return header_start
  }
  let header_end = wgsl_statement_delimited_end(tokens, header_start, 40, 41)
  guard header_end > header_start else { return header_start }
  let first_end = wgsl_statement_top_level_token_index_until(
    tokens,
    header_start + 1,
    header_end,
    59,
  )
  if first_end < 0 {
    return header_end + 1
  }
  if !wgsl_statement_starts_with_local_binding(
      tokens,
      header_start + 1,
      first_end,
    ) {
    wgsl_statement_push_expr_ref(
      owner,
      tokens,
      header_start + 1,
      first_end,
      expression_refs,
    )
  }
  let second_start = first_end + 1
  let second_end = wgsl_statement_top_level_token_index_until(
    tokens, second_start, header_end, 59,
  )
  if second_end < 0 {
    wgsl_statement_push_expr_ref(
      owner, tokens, second_start, header_end, expression_refs,
    )
    return header_end + 1
  }
  wgsl_statement_push_expr_ref(
    owner, tokens, second_start, second_end, expression_refs,
  )
  wgsl_statement_push_expr_ref(
    owner,
    tokens,
    second_end + 1,
    header_end,
    expression_refs,
  )
  header_end + 1
}

///|
fn collect_wgsl_statement_expression_refs(
  owner : WgslDeclParser,
  tokens : Array[WgslToken],
  kind : WgslStatementKind,
  expression_refs : Array[WgslExprRef],
) -> Unit {
  match kind {
    LocalDeclaration | Empty | Continue | Discard | Compound => return
    Break => {
      match tokens {
        [_, WgslToken::Identifier("if", _), ..] =>
          wgsl_statement_push_expr_ref(
            owner,
            tokens,
            2,
            tokens.length(),
            expression_refs,
          )
        _ => ()
      }
      return
    }
    Return => {
      wgsl_statement_push_expr_ref(
        owner,
        tokens,
        1,
        tokens.length(),
        expression_refs,
      )
      return
    }
    ConstAssert => {
      if tokens.length() > 1 && tokens[1] is WgslToken::Other(40, _) {
        let close_index = wgsl_statement_delimited_end(tokens, 1, 40, 41)
        if close_index > 1 {
          wgsl_statement_push_expr_ref(
            owner, tokens, 2, close_index, expression_refs,
          )
          return
        }
      }
      wgsl_statement_push_expr_ref(
        owner,
        tokens,
        1,
        tokens.length(),
        expression_refs,
      )
      return
    }
    For =>
      for i in 0..<tokens.length() {
        match tokens[i] {
          WgslToken::Identifier("for", _) => {
            wgsl_statement_collect_for_header_exprs(
              owner, tokens, i, expression_refs,
            )
            |> ignore
            return
          }
          _ => ()
        }
      }
    If | While | Switch => {
      let mut i = 0
      while i < tokens.length() {
        match tokens[i] {
          WgslToken::Identifier("if", _)
          | WgslToken::Identifier("while", _)
          | WgslToken::Identifier("switch", _) =>
            i = wgsl_statement_collect_condition_expr(
              owner, tokens, i, expression_refs,
            )
          WgslToken::Identifier("case", _) => {
            let colon = wgsl_statement_top_level_token_index(tokens, i + 1, 58)
            let expr_end = if colon >= 0 { colon } else { tokens.length() }
            wgsl_statement_push_expr_ref(
              owner,
              tokens,
              i + 1,
              expr_end,
              expression_refs,
            )
            i = expr_end
          }
          _ => i = i + 1
        }
      }
      return
    }
    Expression => {
      match tokens {
        [WgslToken::Identifier("case", _), ..] => {
          let colon = wgsl_statement_top_level_token_index(tokens, 1, 58)
          let expr_end = if colon >= 0 { colon } else { tokens.length() }
          wgsl_statement_push_expr_ref(
            owner, tokens, 1, expr_end, expression_refs,
          )
          return
        }
        [WgslToken::Identifier("default", _), ..] => return
        _ => ()
      }
      wgsl_statement_push_expr_ref(
        owner,
        tokens,
        0,
        tokens.length(),
        expression_refs,
      )
      return
    }
    Loop => return
  }
}

///|
fn wgsl_statement_view_continues_after_block(
  view : ArrayView[WgslToken],
) -> Bool {
  match view {
    [WgslToken::Identifier("else", _), ..] => true
    [WgslToken::Identifier("continuing", _), ..] => true
    _ => false
  }
}

///|
fn WgslDeclParser::collect_statement(self : WgslDeclParser) -> WgslStatement? {
  let tokens : Array[WgslToken] = []
  let expression_refs : Array[WgslExprRef] = []
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
  fn record_token(token : WgslToken) -> Unit {
    record_span(token.pos(), token.end())
  }
  while true {
    match self.view() {
      [WgslToken::Other(125, _), ..] if depth.at_top() => break
      [WgslToken::Other(59, pos), .. rest] if depth.at_top() => {
        record_span(pos, pos + 1)
        self.update_view(rest)
        break
      }
      [token, .. rest] => {
        match token {
          WgslToken::Identifier(ident, _) =>
            if first_identifier is None {
              first_identifier = Some(ident)
            }
          _ => ()
        }
        tokens.push(token)
        depth.observe_statement_token(token)
        record_token(token)
        self.update_view(rest)
        if depth.at_top() && token is WgslToken::Other(125, _) {
          if wgsl_statement_view_continues_after_block(self.view()) {
            continue
          }
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
    let text = self.slice(start_pos, end_pos)
    let is_local_decl = wgsl_statement_is_local_decl(first_identifier)
    let kind = wgsl_statement_kind_from_tokens(first_identifier, tokens)
    let scope_tokens = collect_wgsl_statement_scope_tokens(tokens)
    let local_bindings : Array[WgslLocalDeclaration] = []
    let exported_local_bindings : Array[WgslLocalDeclaration] = []
    if is_local_decl {
      match self.parse_statement_local_binding(scope_tokens, 0) {
        Some(local_binding) => {
          local_bindings.push(local_binding)
          exported_local_bindings.push(local_binding)
        }
        None => ()
      }
    }
    collect_wgsl_statement_local_bindings(
      self, scope_tokens, is_local_decl, local_bindings,
    )
    collect_wgsl_statement_expression_refs(
      self, scope_tokens, kind, expression_refs,
    )
    let blocks = self.collect_statement_blocks(tokens)
    Some(
      WgslStatement::new(
        kind, text, start_pos, end_pos, blocks, local_bindings, exported_local_bindings,
        expression_refs,
      ),
    )
  }
}

///|
fn WgslDeclParser::parse_block(self : WgslDeclParser) -> WgslBlock {
  let empty = WgslBlock::new(0, 0, [])
  match self.collect_delimited_token_view(123, 125) {
    Some(fragment) => {
      let block = self.parse_block_tokens(
        fragment.open_start,
        fragment.close_start,
        fragment.inner,
      )
      self.drop_tokens(fragment.consumed)
      block
    }
    None => empty
  }
}

///|
