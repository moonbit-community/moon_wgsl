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
        _ => raise UnexpectedToken
      }
      let arguments = function_args(tokens) catch { _ => raise UnexpectedToken }
      self.drop_tokens(fragment.consumed)
      arguments
    }
    None => raise UnexpectedToken
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
    (LPAREN, fragment.open_start, fragment.open_start + 1),
  ]
  let parser = WgslDeclParser::{
    source_text: self.source_text,
    source_start: self.source_start,
    token_view: fragment.inner,
  }
  while parser.view().length() > 0 {
    match parser.view() {
      [token, ..] if token.is_punctuation(35) => {
        let hash_pos = token.pos()
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
      }
      _ => ()
    }
    if parser.consume_if_other(44) {
      tokens.push((COMMA, 0, 0))
      continue
    }
    parser.push_attribute_tokens(tokens)
    let name = match parser.consume_ident_node() {
      Some(value) => value
      None => raise UnexpectedToken
    }
    tokens.push((ARG_NAME(name), name.start(), name.end()))
    match parser.view() {
      [token, .. rest] if token.is_punctuation(58) => {
        let pos = token.pos()
        parser.update_view(rest)
        tokens.push((COLON, pos, pos + 1))
      }
      _ => raise UnexpectedToken
    }
    let ty_fragment = parser.collect_until_top_level_type_fragment([44])
    if ty_fragment.text == "" {
      raise UnexpectedToken
    }
    let ty_ref = match parse_wgsl_type_ref_fragment(ty_fragment) {
      Some(value) => value
      None => raise UnexpectedToken
    }
    tokens.push((ARG_TYPE(ty_ref), ty_fragment.start, ty_fragment.end))
    match parser.view() {
      [token, ..] if token.is_punctuation(44) => continue
      [] => break
      _ => raise UnexpectedToken
    }
  }
  tokens.push((RPAREN, fragment.close_start, fragment.close_start + 1))
  tokens.push((EOF, fragment.close_start + 1, fragment.close_start + 1))
  tokens
}

///|
fn WgslDeclParser::parse_function_result(
  self : WgslDeclParser,
) -> WgslFunctionResult? {
  match self.view() {
    [arrow_token, .. rest] if arrow_token.is_operator("->") => {
      let arrow_start = arrow_token.pos()
      let parser = WgslDeclParser::{
        source_text: self.source_text,
        source_start: self.source_start,
        token_view: rest,
      }
      let rest_len = rest.length()
      let tokens : Array[(Token, Int, Int)] = [
        (ARROW(arrow_start), arrow_start, arrow_start + 2),
      ]
      parser.push_attribute_tokens(tokens)
      let ty_fragment = parser.collect_until_top_level_type_fragment([123, 59])
      if ty_fragment.text == "" {
        return None
      }
      let ty_ref = match parse_wgsl_type_ref_fragment(ty_fragment) {
        Some(value) => value
        None => return None
      }
      tokens.push((ARG_TYPE(ty_ref), ty_fragment.start, ty_fragment.end))
      tokens.push((EOF, ty_fragment.end, ty_fragment.end))
      let result = function_result(tokens) catch { _ => return None }
      self.drop_tokens(1 + rest_len - parser.view().length())
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
fn wgsl_statement_assignment_operator_at(
  tokens : Array[WgslToken],
  index : Int,
) -> (String, Int)? {
  guard index >= 0 && index < tokens.length() else { return None }
  match tokens[index].operator_text() {
    Some(op) =>
      if op == "+=" ||
        op == "-=" ||
        op == "*=" ||
        op == "/=" ||
        op == "%=" ||
        op == "&=" ||
        op == "|=" ||
        op == "^=" {
        return Some((op, 1))
      } else if op == "<<" &&
        index + 1 < tokens.length() &&
        tokens[index + 1].is_punctuation(61) {
        return Some(("<<=", 2))
      } else if op == ">>" &&
        index + 1 < tokens.length() &&
        tokens[index + 1].is_punctuation(61) {
        return Some((">>=", 2))
      }
    None => ()
  }
  if tokens[index].is_punctuation(61) {
    Some(("=", 1))
  } else {
    None
  }
}

///|
fn wgsl_statement_assignment_operator(
  tokens : Array[WgslToken],
) -> (Int, String, Int)? {
  let depth = WgslTokenDepth()
  for i in 0..<tokens.length() {
    if depth.at_top() {
      match wgsl_statement_assignment_operator_at(tokens, i) {
        Some((text, consumed)) => return Some((i, text, consumed))
        None => ()
      }
    }
    depth.observe_statement_token(tokens[i])
  }
  None
}

///|
fn wgsl_statement_is_update(
  tokens : Array[WgslToken],
  operator : String,
) -> Bool {
  guard tokens.length() > 1 else { return false }
  match tokens[tokens.length() - 1].operator_text() {
    Some(text) if text == operator => {
      let depth = WgslTokenDepth()
      for i in 0..<(tokens.length() - 1) {
        depth.observe_statement_token(tokens[i])
      }
      depth.at_top()
    }
    _ => false
  }
}

///|
fn wgsl_statement_is_function_call_tokens(tokens : Array[WgslToken]) -> Bool {
  guard tokens.length() >= 3 else { return false }
  guard tokens[tokens.length() - 1].is_punctuation(41) else { return false }
  let depth = WgslTokenDepth()
  for i in 0..<tokens.length() {
    if depth.at_top() && tokens[i].is_punctuation(40) {
      let close_index = wgsl_statement_delimited_end(tokens, i, 40, 41)
      return close_index == tokens.length() - 1 && i > 0
    }
    depth.observe_statement_token(tokens[i])
  }
  false
}

///|
fn wgsl_statement_expression_kind_from_tokens(
  tokens : Array[WgslToken],
) -> WgslStatementKind {
  match wgsl_statement_assignment_operator(tokens) {
    Some(_) => return Assignment
    None => ()
  }
  if wgsl_statement_is_update(tokens, "++") {
    return Increment
  }
  if wgsl_statement_is_update(tokens, "--") {
    return Decrement
  }
  if wgsl_statement_is_function_call_tokens(tokens) {
    return FunctionCall
  }
  Expression
}

///|
fn wgsl_statement_kind_from_tokens(
  first_identifier : String?,
  tokens : Array[WgslToken],
) -> WgslStatementKind {
  match first_identifier {
    Some("var") | Some("let") | Some("const") => LocalDeclaration
    Some("return") => Return
    Some("if") => If
    Some("for") => For
    Some("while") => While
    Some("loop") => Loop
    Some("continuing") => Continuing
    Some("switch") => Switch
    Some("case") => Case
    Some("default") => DefaultCase
    Some("break") => Break
    Some("continue") => Continue
    Some("discard") => Discard
    Some("const_assert") => ConstAssert
    Some(_) => wgsl_statement_expression_kind_from_tokens(tokens)
    None =>
      match tokens {
        [token, ..] if token.is_punctuation(123) => Compound
        [] => Empty
        _ => wgsl_statement_expression_kind_from_tokens(tokens)
      }
  }
}

///|
fn wgsl_statement_token_identifier(token : WgslToken) -> String? {
  token.identifier_text()
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
    Some("var") => WgslLocalDeclarationKind::Var
    Some("let") => Let
    Some("const") => Const
    _ => return None
  }
  let parser = WgslDeclParser::{
    source_text: self.source_text,
    source_start: self.source_start,
    token_view: tokens[keyword_index + 1:],
  }
  let template_list = if kind == Var {
    parser.parse_template_list()
  } else {
    []
  }
  let name = match parser.consume_ident_node() {
    Some(value) => value
    None => return None
  }
  let tail = parser.parse_typed_initializer_tail_checked() catch {
    _ => return None
  }
  match (kind, tail.initializer_ref) {
    (Let, None) | (Const, None) => return None
    _ => ()
  }
  Some(
    WgslLocalDeclaration(
      kind,
      name,
      template_list,
      tail.ty_ref,
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
priv suberror WgslBlockParseError {
  UnexpectedToken
}

///|
fn WgslDeclParser::parse_block_tokens_checked(
  self : WgslDeclParser,
  open_start : Int,
  close_start : Int,
  inner : ArrayView[WgslToken],
) -> WgslBlock raise WgslBlockParseError {
  let tokens : Array[(Token, Int, Int)] = [
    (LBRACE(open_start), open_start, open_start + 1),
  ]
  let parser = WgslDeclParser::{
    source_text: self.source_text,
    source_start: self.source_start,
    token_view: inner,
  }
  while parser.view().length() > 0 {
    match parser.collect_statement() {
      Some(statement) => tokens.push((STMT(statement), 0, 0))
      None => if parser.view() is [] { break } else { raise UnexpectedToken }
    }
  }
  tokens.push((RBRACE(close_start), close_start, close_start + 1))
  tokens.push((EOF, close_start + 1, close_start + 1))
  block(tokens) catch {
    _ => raise UnexpectedToken
  }
}

///|
fn WgslDeclParser::parse_block_tokens(
  self : WgslDeclParser,
  open_start : Int,
  close_start : Int,
  inner : ArrayView[WgslToken],
) -> WgslBlock {
  self.parse_block_tokens_checked(open_start, close_start, inner) catch {
    _ => WgslBlock(0, 0, [])
  }
}

///|
fn WgslDeclParser::collect_statement_blocks(
  self : WgslDeclParser,
  tokens : Array[WgslToken],
) -> Array[WgslBlock] {
  let blocks : Array[WgslBlock] = []
  let open_stack : Array[Int] = []
  let source_template = WgslTokenDepth()
  for i in 0..<tokens.length() {
    if source_template.observe_source_template(tokens[i]) {
      continue
    }
    if tokens[i].is_punctuation(123) {
      open_stack.push(i)
    } else if tokens[i].is_punctuation(125) {
      let close_start = tokens[i].pos()
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
  let source_template = WgslTokenDepth()
  for token in tokens {
    let source_template_token = source_template.observe_source_template(token)
    if !source_template_token && token.is_punctuation(123) {
      block_depth = block_depth + 1
      continue
    }
    if !source_template_token && token.is_punctuation(125) && block_depth > 0 {
      block_depth = block_depth - 1
      continue
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
  let depth = WgslTokenDepth()
  let limit = if end_ < tokens.length() { end_ } else { tokens.length() }
  for i in start..<limit {
    if depth.at_top() && tokens[i].is_punctuation(code) {
      return i
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
  guard tokens[open_index].is_punctuation(open_code) else { return -1 }
  let mut depth = 0
  for i in open_index..<tokens.length() {
    if tokens[i].is_punctuation(open_code) {
      depth = depth + 1
    } else if tokens[i].is_punctuation(close_code) {
      depth = depth - 1
      if depth == 0 {
        return i
      }
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
  role : WgslStatementExpressionRole,
  expression_refs : Array[WgslExprRef],
  expressions : Array[WgslStatementExpression],
) -> Unit {
  guard start >= 0 && end_ > start && end_ <= tokens.length() else { return }
  match
    parse_wgsl_expr_ref_token_range(
      owner.source_text,
      owner.source_start,
      tokens,
      start,
      end_,
    ) {
    Some(expr) => {
      expression_refs.push(expr)
      expressions.push(WgslStatementExpression(role, expr))
    }
    None => ()
  }
}

///|
fn wgsl_statement_push_comma_expr_refs(
  owner : WgslDeclParser,
  tokens : Array[WgslToken],
  start : Int,
  end_ : Int,
  role : WgslStatementExpressionRole,
  expression_refs : Array[WgslExprRef],
  expressions : Array[WgslStatementExpression],
) -> Unit {
  guard start >= 0 && end_ > start && end_ <= tokens.length() else { return }
  let depth = WgslTokenDepth()
  let mut item_start = start
  for i in start..<end_ {
    if depth.at_top() && tokens[i].is_punctuation(44) {
      wgsl_statement_push_expr_ref(
        owner, tokens, item_start, i, role, expression_refs, expressions,
      )
      item_start = i + 1
    }
    depth.observe_statement_token(tokens[i])
  }
  wgsl_statement_push_expr_ref(
    owner, tokens, item_start, end_, role, expression_refs, expressions,
  )
}

///|
fn wgsl_statement_case_selectors_from_tokens(
  owner : WgslDeclParser,
  tokens : Array[WgslToken],
  start : Int,
  end_ : Int,
  expression_refs : Array[WgslExprRef],
  expressions : Array[WgslStatementExpression],
) -> Array[WgslCaseSelector] {
  let selectors : Array[WgslCaseSelector] = []
  guard start >= 0 && end_ > start && end_ <= tokens.length() else {
    return selectors
  }
  let depth = WgslTokenDepth()
  let mut item_start = start
  fn push_selector(item_end : Int) -> Unit {
    guard item_end > item_start else { return }
    if item_start + 1 == item_end && tokens[item_start].is_identifier("default") {
      selectors.push(DefaultSelector)
      return
    }
    match owner.expr_ref_from_token_range(tokens, item_start, item_end) {
      Some(expr) => {
        expression_refs.push(expr)
        expressions.push(WgslStatementExpression(CaseSelector, expr))
        selectors.push(ExpressionSelector(expr))
      }
      None => ()
    }
  }
  for i in start..<end_ {
    if depth.at_top() && tokens[i].is_punctuation(44) {
      push_selector(i)
      item_start = i + 1
    }
    depth.observe_statement_token(tokens[i])
  }
  push_selector(end_)
  selectors
}

///|
fn WgslDeclParser::expr_ref_from_token_range(
  self : WgslDeclParser,
  tokens : Array[WgslToken],
  start : Int,
  end_ : Int,
) -> WgslExprRef? {
  guard start >= 0 && end_ > start && end_ <= tokens.length() else {
    return None
  }
  parse_wgsl_expr_ref_token_range(
    self.source_text,
    self.source_start,
    tokens,
    start,
    end_,
  )
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
  tokens[start].is_identifier("var") ||
  tokens[start].is_identifier("let") ||
  tokens[start].is_identifier("const")
}

///|
fn wgsl_statement_control_expression_end(
  tokens : Array[WgslToken],
  start : Int,
) -> Int {
  let depth = WgslTokenDepth()
  for i in start..<tokens.length() {
    if depth.at_top() &&
      (
        tokens[i].is_punctuation(123) ||
        tokens[i].is_punctuation(64) ||
        tokens[i].is_identifier("else")
      ) {
      return i
    }
    depth.observe_statement_token(tokens[i])
  }
  tokens.length()
}

///|
fn wgsl_statement_collect_condition_expr(
  owner : WgslDeclParser,
  tokens : Array[WgslToken],
  keyword_index : Int,
  role : WgslStatementExpressionRole,
  expression_refs : Array[WgslExprRef],
  expressions : Array[WgslStatementExpression],
) -> Int {
  let expr_start = keyword_index + 1
  guard expr_start < tokens.length() else { return expr_start }
  if tokens[expr_start].is_punctuation(40) {
    let close_index = wgsl_statement_delimited_end(tokens, expr_start, 40, 41)
    if close_index > expr_start {
      if close_index + 1 < tokens.length() &&
        tokens[close_index + 1].is_punctuation(123) {
        wgsl_statement_push_expr_ref(
          owner,
          tokens,
          expr_start + 1,
          close_index,
          role,
          expression_refs,
          expressions,
        )
        return close_index + 1
      }
      let expr_end = wgsl_statement_control_expression_end(tokens, expr_start)
      if close_index + 1 < expr_end {
        wgsl_statement_push_expr_ref(
          owner, tokens, expr_start, expr_end, role, expression_refs, expressions,
        )
        return expr_end
      }
      wgsl_statement_push_expr_ref(
        owner,
        tokens,
        expr_start + 1,
        close_index,
        role,
        expression_refs,
        expressions,
      )
      return close_index + 1
    }
    expr_start
  } else {
    let expr_end = wgsl_statement_control_expression_end(tokens, expr_start)
    wgsl_statement_push_expr_ref(
      owner, tokens, expr_start, expr_end, role, expression_refs, expressions,
    )
    expr_end
  }
}

///|
fn wgsl_statement_collect_for_header_exprs(
  owner : WgslDeclParser,
  tokens : Array[WgslToken],
  for_index : Int,
  expression_refs : Array[WgslExprRef],
  expressions : Array[WgslStatementExpression],
) -> Int {
  let header_start = for_index + 1
  guard header_start < tokens.length() else { return header_start }
  guard tokens[header_start].is_punctuation(40) else { return header_start }
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
      ForInitializer,
      expression_refs,
      expressions,
    )
  }
  let second_start = first_end + 1
  let second_end = wgsl_statement_top_level_token_index_until(
    tokens, second_start, header_end, 59,
  )
  if second_end < 0 {
    wgsl_statement_push_expr_ref(
      owner,
      tokens,
      second_start,
      header_end,
      ForCondition,
      expression_refs,
      expressions,
    )
    return header_end + 1
  }
  wgsl_statement_push_expr_ref(
    owner,
    tokens,
    second_start,
    second_end,
    ForCondition,
    expression_refs,
    expressions,
  )
  wgsl_statement_push_expr_ref(
    owner,
    tokens,
    second_end + 1,
    header_end,
    ForUpdate,
    expression_refs,
    expressions,
  )
  header_end + 1
}

///|
fn collect_wgsl_statement_expression_refs(
  owner : WgslDeclParser,
  tokens : Array[WgslToken],
  kind : WgslStatementKind,
  expression_refs : Array[WgslExprRef],
  expressions : Array[WgslStatementExpression],
) -> Unit {
  match kind {
    LocalDeclaration
    | Empty
    | Continue
    | Discard
    | Compound
    | Continuing
    | DefaultCase => return
    Break => {
      match tokens {
        [_, token, ..] if token.is_identifier("if") =>
          wgsl_statement_push_expr_ref(
            owner,
            tokens,
            2,
            tokens.length(),
            BreakIf,
            expression_refs,
            expressions,
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
        ReturnValue,
        expression_refs,
        expressions,
      )
      return
    }
    ConstAssert => {
      if tokens.length() > 1 && tokens[1].is_punctuation(40) {
        let close_index = wgsl_statement_delimited_end(tokens, 1, 40, 41)
        if close_index > 1 {
          wgsl_statement_push_expr_ref(
            owner,
            tokens,
            2,
            close_index,
            ConstAssertValue,
            expression_refs,
            expressions,
          )
          return
        }
      }
      wgsl_statement_push_expr_ref(
        owner,
        tokens,
        1,
        tokens.length(),
        ConstAssertValue,
        expression_refs,
        expressions,
      )
      return
    }
    For =>
      for i in 0..<tokens.length() {
        if tokens[i].is_identifier("for") {
          wgsl_statement_collect_for_header_exprs(
            owner, tokens, i, expression_refs, expressions,
          )
          |> ignore
          return
        }
      }
    If | While => {
      let mut i = 0
      while i < tokens.length() {
        if tokens[i].is_identifier("if") || tokens[i].is_identifier("while") {
          i = wgsl_statement_collect_condition_expr(
            owner,
            tokens,
            i,
            Condition,
            expression_refs,
            expressions,
          )
        } else if tokens[i].is_identifier("case") {
          let colon = wgsl_statement_top_level_token_index(tokens, i + 1, 58)
          let expr_end = if colon >= 0 { colon } else { tokens.length() }
          wgsl_statement_push_comma_expr_refs(
            owner,
            tokens,
            i + 1,
            expr_end,
            CaseSelector,
            expression_refs,
            expressions,
          )
          i = expr_end
        } else {
          i = i + 1
        }
      }
      return
    }
    Switch => {
      let mut i = 0
      while i < tokens.length() {
        if tokens[i].is_identifier("switch") {
          i = wgsl_statement_collect_condition_expr(
            owner,
            tokens,
            i,
            SwitchSelector,
            expression_refs,
            expressions,
          )
        } else if tokens[i].is_identifier("case") {
          let colon = wgsl_statement_top_level_token_index(tokens, i + 1, 58)
          let expr_end = if colon >= 0 { colon } else { tokens.length() }
          wgsl_statement_push_comma_expr_refs(
            owner,
            tokens,
            i + 1,
            expr_end,
            CaseSelector,
            expression_refs,
            expressions,
          )
          i = expr_end
        } else {
          i = i + 1
        }
      }
      return
    }
    Assignment => {
      match wgsl_statement_assignment_operator(tokens) {
        Some((op_index, _, consumed)) => {
          wgsl_statement_push_expr_ref(
            owner,
            tokens,
            0,
            op_index,
            AssignmentLhs,
            expression_refs,
            expressions,
          )
          wgsl_statement_push_expr_ref(
            owner,
            tokens,
            op_index + consumed,
            tokens.length(),
            AssignmentRhs,
            expression_refs,
            expressions,
          )
        }
        None => ()
      }
      return
    }
    Increment | Decrement => {
      wgsl_statement_push_expr_ref(
        owner,
        tokens,
        0,
        tokens.length() - 1,
        UpdateTarget,
        expression_refs,
        expressions,
      )
      return
    }
    FunctionCall => {
      wgsl_statement_push_expr_ref(
        owner,
        tokens,
        0,
        tokens.length(),
        FunctionCallValue,
        expression_refs,
        expressions,
      )
      return
    }
    Expression => {
      match tokens {
        [token, ..] if token.is_identifier("case") => {
          let colon = wgsl_statement_top_level_token_index(tokens, 1, 58)
          let expr_end = if colon >= 0 { colon } else { tokens.length() }
          wgsl_statement_push_comma_expr_refs(
            owner,
            tokens,
            1,
            expr_end,
            CaseSelector,
            expression_refs,
            expressions,
          )
          return
        }
        [token, ..] if token.is_identifier("default") => return
        _ => ()
      }
      wgsl_statement_push_expr_ref(
        owner,
        tokens,
        0,
        tokens.length(),
        ExpressionValue,
        expression_refs,
        expressions,
      )
      return
    }
    Loop => return
    Case => return
  }
}

///|
fn wgsl_statement_view_continues_after_block(
  view : ArrayView[WgslToken],
  first_identifier : String?,
) -> Bool {
  match first_identifier {
    Some("if") =>
      match view {
        [token, ..] if token.is_identifier("else") => true
        _ => false
      }
    Some("loop") =>
      match view {
        [token, ..] if token.is_identifier("continuing") => true
        _ => false
      }
    _ => false
  }
}

///|
fn wgsl_statement_first_expression_by_role(
  expressions : Array[WgslStatementExpression],
  role : WgslStatementExpressionRole,
) -> WgslExprRef? {
  for expression in expressions {
    if expression.role() == role {
      return Some(expression.expression())
    }
  }
  None
}

///|
fn wgsl_statement_has_expression_role(
  expressions : Array[WgslStatementExpression],
  role : WgslStatementExpressionRole,
) -> Bool {
  wgsl_statement_first_expression_by_role(expressions, role) is Some(_)
}

///|
fn wgsl_statement_has_invalid_expression(
  kind : WgslStatementKind,
  tokens : Array[WgslToken],
  expressions : Array[WgslStatementExpression],
  missing_semicolon_at_statement_boundary : Bool,
) -> Bool {
  for token in tokens {
    if token.is_punctuation(35) {
      return false
    }
  }
  if wgsl_statement_requires_semicolon(kind, tokens) &&
    missing_semicolon_at_statement_boundary {
    return true
  }
  match kind {
    Return =>
      tokens.length() > 1 &&
      !wgsl_statement_has_expression_role(expressions, ReturnValue)
    ConstAssert =>
      tokens.length() > 1 &&
      !wgsl_statement_has_expression_role(expressions, ConstAssertValue)
    FunctionCall =>
      !wgsl_statement_has_expression_role(expressions, FunctionCallValue)
    Expression =>
      match tokens {
        [token, ..] if token.is_punctuation(35) => false
        [token, ..] if token.is_identifier("case") ||
          token.is_identifier("default") => false
        [] => false
        _ => !wgsl_statement_has_expression_role(expressions, ExpressionValue)
      }
    Increment | Decrement =>
      !wgsl_statement_has_expression_role(expressions, UpdateTarget)
    Assignment =>
      !wgsl_statement_has_expression_role(expressions, AssignmentLhs) ||
      !wgsl_statement_has_expression_role(expressions, AssignmentRhs)
    _ => false
  }
}

///|
fn wgsl_statement_requires_semicolon(
  kind : WgslStatementKind,
  tokens : Array[WgslToken],
) -> Bool {
  match tokens {
    [token, ..] if token.is_punctuation(35) => return false
    [token, ..] if token.is_identifier("case") || token.is_identifier("default") =>
      return false
    [] => return false
    _ => ()
  }
  match kind {
    LocalDeclaration
    | Return
    | Break
    | Continue
    | Discard
    | ConstAssert
    | Assignment
    | Increment
    | Decrement
    | FunctionCall
    | Expression => true
    _ => false
  }
}

///|
fn wgsl_statement_payload_from_ast(
  kind : WgslStatementKind,
  first_identifier : String?,
  assignment_operator : String?,
  local_bindings : Array[WgslLocalDeclaration],
  case_selectors : Array[WgslCaseSelector],
  expressions : Array[WgslStatementExpression],
) -> WgslStatementPayload {
  match kind {
    Empty => Empty
    LocalDeclaration => LocalDeclaration(local_bindings)
    Return =>
      Return(wgsl_statement_first_expression_by_role(expressions, ReturnValue))
    If => If(wgsl_statement_first_expression_by_role(expressions, Condition))
    For => For(expressions)
    While =>
      While(wgsl_statement_first_expression_by_role(expressions, Condition))
    Loop => Loop
    Continuing => Compound
    Switch =>
      Switch(
        wgsl_statement_first_expression_by_role(expressions, SwitchSelector),
      )
    Break =>
      Break(wgsl_statement_first_expression_by_role(expressions, BreakIf))
    Continue => Continue
    Discard => Discard
    ConstAssert =>
      ConstAssert(
        wgsl_statement_first_expression_by_role(expressions, ConstAssertValue),
      )
    Compound => Compound
    Case => Case(case_selectors)
    DefaultCase => DefaultCase
    Assignment =>
      Assignment(
        match assignment_operator {
          Some(text) => text
          None => ""
        },
        wgsl_statement_first_expression_by_role(expressions, AssignmentLhs),
        wgsl_statement_first_expression_by_role(expressions, AssignmentRhs),
      )
    Increment =>
      Increment(
        wgsl_statement_first_expression_by_role(expressions, UpdateTarget),
      )
    Decrement =>
      Decrement(
        wgsl_statement_first_expression_by_role(expressions, UpdateTarget),
      )
    FunctionCall =>
      FunctionCall(
        wgsl_statement_first_expression_by_role(expressions, FunctionCallValue),
      )
    Expression =>
      match first_identifier {
        Some("case") => Case(case_selectors)
        Some("default") => DefaultCase
        _ =>
          Expression(
            wgsl_statement_first_expression_by_role(
              expressions,
              ExpressionValue,
            ),
          )
      }
  }
}

///|
fn wgsl_statement_leading_attributes(
  owner : WgslDeclParser,
  tokens : Array[WgslToken],
) -> (Array[WgslAttribute], Int) {
  let attributes : Array[WgslAttribute] = []
  let mut index = 0
  while index + 1 < tokens.length() {
    guard tokens[index].is_punctuation(64) else { break }
    let at_token = tokens[index]
    let name_token = tokens[index + 1]
    let name = match name_token.identifier_text() {
      Some(text) => WgslIdent(text, name_token.pos(), name_token.end())
      None => break
    }
    let mut end_ = name.end()
    let mut next_index = index + 2
    let mut arguments_ref : WgslExprRef? = None
    if next_index < tokens.length() && tokens[next_index].is_punctuation(40) {
      let close_index = wgsl_statement_delimited_end(tokens, next_index, 40, 41)
      if close_index > next_index {
        end_ = tokens[close_index].end()
        arguments_ref = owner.expr_ref_from_token_range(
          tokens,
          next_index + 1,
          close_index,
        )
        next_index = close_index + 1
      }
    }
    attributes.push(WgslAttribute(name, at_token.pos(), end_, arguments_ref))
    index = next_index
  }
  (attributes, index)
}

///|
fn WgslDeclParser::collect_statement(self : WgslDeclParser) -> WgslStatement? {
  let tokens : Array[WgslToken] = []
  let expression_refs : Array[WgslExprRef] = []
  let expressions : Array[WgslStatementExpression] = []
  let mut first_identifier : String? = None
  let mut start_pos = -1
  let mut end_pos = -1
  let mut missing_semicolon_at_statement_boundary = false
  let depth = WgslTokenDepth()
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
      [token, ..] if depth.at_top() && token.is_punctuation(125) => {
        if tokens.length() > 0 {
          missing_semicolon_at_statement_boundary = true
        }
        break
      }
      [token, .. rest] if depth.at_top() && token.is_punctuation(59) => {
        let pos = token.pos()
        record_span(pos, pos + 1)
        self.update_view(rest)
        break
      }
      [token, .. rest] => {
        match token.identifier_text() {
          Some(ident) if first_identifier is None =>
            first_identifier = Some(ident)
          _ => ()
        }
        tokens.push(token)
        depth.observe_statement_token(token)
        record_token(token)
        self.update_view(rest)
        if depth.at_top() && token.is_punctuation(125) {
          if wgsl_statement_view_continues_after_block(
              self.view(),
              first_identifier,
            ) {
            continue
          }
          break
        }
        continue
      }
      [] => {
        if tokens.length() > 0 {
          missing_semicolon_at_statement_boundary = true
        }
        break
      }
    }
  }
  if start_pos < 0 || end_pos < start_pos {
    None
  } else {
    let (attributes, body_start) = wgsl_statement_leading_attributes(
      self, tokens,
    )
    let body_tokens = tokens[body_start:].to_owned()
    let body_first_identifier = match body_tokens {
      [token, ..] => token.identifier_text()
      [] => first_identifier
    }
    let is_local_decl = wgsl_statement_is_local_decl(body_first_identifier)
    let kind = wgsl_statement_kind_from_tokens(
      body_first_identifier, body_tokens,
    )
    let scope_tokens = collect_wgsl_statement_scope_tokens(body_tokens)
    let local_bindings : Array[WgslLocalDeclaration] = []
    let exported_local_bindings : Array[WgslLocalDeclaration] = []
    if is_local_decl {
      match self.parse_statement_local_binding(scope_tokens, 0) {
        Some(local_binding) => {
          local_bindings.push(local_binding)
          exported_local_bindings.push(local_binding)
        }
        None => return None
      }
    }
    collect_wgsl_statement_local_bindings(
      self, scope_tokens, is_local_decl, local_bindings,
    )
    collect_wgsl_statement_expression_refs(
      self, scope_tokens, kind, expression_refs, expressions,
    )
    let case_selectors = if kind == Case {
      let colon = wgsl_statement_top_level_token_index(scope_tokens, 1, 58)
      let selector_end = if colon >= 0 { colon } else { scope_tokens.length() }
      wgsl_statement_case_selectors_from_tokens(
        self, scope_tokens, 1, selector_end, expression_refs, expressions,
      )
    } else {
      []
    }
    let assignment_operator = match
      wgsl_statement_assignment_operator(scope_tokens) {
      Some((_, text, _)) => Some(text)
      None => None
    }
    let payload = wgsl_statement_payload_from_ast(
      kind, body_first_identifier, assignment_operator, local_bindings, case_selectors,
      expressions,
    )
    let invalid_expression = wgsl_statement_has_invalid_expression(
      kind, scope_tokens, expressions, missing_semicolon_at_statement_boundary,
    )
    let blocks = self.collect_statement_blocks(tokens)
    Some(
      WgslStatement(
        kind, attributes, payload, blocks, local_bindings, exported_local_bindings,
        expression_refs, expressions, invalid_expression,
      ),
    )
  }
}

///|
fn WgslDeclParser::parse_block_checked(
  self : WgslDeclParser,
) -> WgslBlock raise WgslBlockParseError {
  match self.collect_delimited_token_view(123, 125) {
    Some(fragment) => {
      let block = self.parse_block_tokens_checked(
        fragment.open_start,
        fragment.close_start,
        fragment.inner,
      )
      self.drop_tokens(fragment.consumed)
      block
    }
    None => raise UnexpectedToken
  }
}

///|
