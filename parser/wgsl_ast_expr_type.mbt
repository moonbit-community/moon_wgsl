///|
fn wgsl_expr_identifier_has_access_prefix(
  tokens : Array[WgslToken],
  index : Int,
) -> Bool {
  if index == 0 {
    return false
  }
  tokens[index - 1].is_punctuation(46) || tokens[index - 1].is_punctuation(64)
}

///|
fn wgsl_expr_ascii_digit(code : Int) -> Bool {
  code >= 48 && code <= 57
}

///|
fn wgsl_expr_ascii_hex_digit_value(code : Int) -> Int? {
  if code >= 48 && code <= 57 {
    return Some(code - 48)
  }
  if code >= 65 && code <= 70 {
    return Some(code - 65 + 10)
  }
  if code >= 97 && code <= 102 {
    return Some(code - 97 + 10)
  }
  None
}

///|
fn wgsl_expr_ascii_identifier_code(code : Int) -> Bool {
  (code >= 65 && code <= 90) ||
  (code >= 97 && code <= 122) ||
  (code >= 48 && code <= 57) ||
  code == 95
}

///|
fn wgsl_expr_token_starts_numeric_fraction(token : WgslToken) -> Bool {
  match token.punctuation_code() {
    Some(code) => wgsl_expr_ascii_digit(code)
    None => token.number_text() != None
  }
}

///|
fn wgsl_expr_number_token_end(tokens : Array[WgslToken], start : Int) -> Int {
  let mut end_index = start
  while end_index < tokens.length() {
    match tokens[end_index].punctuation_code() {
      Some(code) =>
        if wgsl_expr_ascii_identifier_code(code) ||
          code == 46 ||
          code == 43 ||
          code == 45 {
          end_index = end_index + 1
          continue
        } else {
          break
        }
      _ => break
    }
  }
  end_index
}

///|
fn parse_wgsl_uint_literal_token(text : String) -> Int? {
  let mut end = text.length()
  let mut has_suffix = false
  if end > 0 {
    let last = text.code_unit_at(end - 1).to_int()
    if last == 117 || last == 85 {
      has_suffix = true
      end = end - 1
    }
  }
  if !has_suffix {
    return None
  }
  if end <= 0 {
    return None
  }
  if end > 2 &&
    text.code_unit_at(0).to_int() == 48 &&
    (
      text.code_unit_at(1).to_int() == 120 ||
      text.code_unit_at(1).to_int() == 88
    ) {
    let mut value = 0
    for i in 2..<end {
      match wgsl_expr_ascii_hex_digit_value(text.code_unit_at(i).to_int()) {
        Some(digit) => value = value * 16 + digit
        None => return None
      }
    }
    return Some(value)
  }
  let mut value = 0
  for i in 0..<end {
    let code = text.code_unit_at(i).to_int()
    if !wgsl_expr_ascii_digit(code) {
      return None
    }
    value = value * 10 + (code - 48)
  }
  Some(value)
}

///|
fn parse_wgsl_int_literal_token(text : String) -> Int? {
  let mut end = text.length()
  if end > 0 {
    let last = text.code_unit_at(end - 1).to_int()
    if last == 105 || last == 73 {
      end = end - 1
    }
  }
  if end <= 0 {
    return None
  }
  if end > 2 &&
    text.code_unit_at(0).to_int() == 48 &&
    (
      text.code_unit_at(1).to_int() == 120 ||
      text.code_unit_at(1).to_int() == 88
    ) {
    let mut value = 0
    for i in 2..<end {
      match wgsl_expr_ascii_hex_digit_value(text.code_unit_at(i).to_int()) {
        Some(digit) => value = value * 16 + digit
        None => return None
      }
    }
    return Some(value)
  }
  let mut value = 0
  for i in 0..<end {
    let code = text.code_unit_at(i).to_int()
    if !wgsl_expr_ascii_digit(code) {
      return None
    }
    value = value * 10 + (code - 48)
  }
  Some(value)
}

///|
fn wgsl_expr_number_token_kind(text : String) -> WgslExprTokenKind {
  match parse_wgsl_uint_literal_token(text) {
    Some(value) => return WgslExprTokenKind::UintLiteral(value)
    None => ()
  }
  match parse_wgsl_int_literal_token(text) {
    Some(value) => return WgslExprTokenKind::IntLiteral(value)
    None => ()
  }
  WgslExprTokenKind::FloatLiteral
}

///|
fn collect_wgsl_expr_ref_tokens_and_identifiers(
  text : String,
  base : Int,
  expr_tokens : Array[WgslExprToken],
  identifiers : Array[WgslIdent],
) -> Unit {
  let tokens = tokenize_wgsl(replace_comments(text), false)
  let mut i = 0
  while i < tokens.length() {
    let token = tokens[i]
    match token.identifier_text() {
      Some(name) => {
        let pos = token.pos()
        let absolute_start = base + pos
        let kind = match name {
          "true" => WgslExprTokenKind::BoolLiteral(true)
          "false" => WgslExprTokenKind::BoolLiteral(false)
          _ => WgslExprTokenKind::Identifier
        }
        expr_tokens.push(
          WgslExprToken::new(
            kind,
            name,
            absolute_start,
            absolute_start + name.length(),
          ),
        )
        if !wgsl_expr_identifier_has_access_prefix(tokens, i) &&
          kind is WgslExprTokenKind::Identifier {
          identifiers.push(
            WgslIdent::new(name, absolute_start, absolute_start + name.length()),
          )
        }
        i = i + 1
        continue
      }
      None => ()
    }
    match token.number_text() {
      Some(token_text) => {
        expr_tokens.push(
          WgslExprToken::new(
            wgsl_expr_number_token_kind(token_text),
            token_text,
            base + token.pos(),
            base + tokens[i].end(),
          ),
        )
        i = i + 1
        continue
      }
      None => ()
    }
    match token.punctuation_code() {
      Some(code) => {
        if code == 46 &&
          i + 1 < tokens.length() &&
          wgsl_expr_token_starts_numeric_fraction(tokens[i + 1]) {
          let pos = token.pos()
          let end_index = match tokens[i + 1].number_text() {
            Some(_) => i + 2
            None => wgsl_expr_number_token_end(tokens, i)
          }
          let end_pos = if end_index > i {
            tokens[end_index - 1].end()
          } else {
            tokens[i].end()
          }
          let token_text = text[pos:end_pos].to_owned()
          expr_tokens.push(
            WgslExprToken::new(
              WgslExprTokenKind::FloatLiteral,
              token_text,
              base + pos,
              base + end_pos,
            ),
          )
          i = end_index
          continue
        }
        if wgsl_expr_ascii_digit(code) {
          let pos = token.pos()
          let end_index = wgsl_expr_number_token_end(tokens, i)
          let end_pos = if end_index > i {
            tokens[end_index - 1].end()
          } else {
            tokens[i].end()
          }
          let token_text = text[pos:end_pos].to_owned()
          expr_tokens.push(
            WgslExprToken::new(
              wgsl_expr_number_token_kind(token_text),
              token_text,
              base + pos,
              base + end_pos,
            ),
          )
          i = end_index
          continue
        }
        let pos = token.pos()
        expr_tokens.push(
          WgslExprToken::new(
            WgslExprTokenKind::Punctuation(code),
            text[pos:tokens[i].end()].to_owned(),
            base + pos,
            base + tokens[i].end(),
          ),
        )
        i = i + 1
        continue
      }
      None => ()
    }
    match token.operator_text() {
      Some(operator) => {
        expr_tokens.push(
          WgslExprToken::new(
            WgslExprTokenKind::Operator(WgslExprOperator::from_text(operator)),
            operator,
            base + token.pos(),
            base + tokens[i].end(),
          ),
        )
        i = i + 1
        continue
      }
      None => ()
    }
    if token.is_whitespace() {
      i = i + 1
      continue
    }
    i = i + 1
  }
}

///|
priv struct WgslExprNodeParser {
  source_text : String
  source_start : Int
  tokens : Array[WgslExprToken]
  mut index : Int
}

///|
fn WgslExprNodeParser::new(
  source_text : String,
  source_start : Int,
  tokens : Array[WgslExprToken],
) -> WgslExprNodeParser {
  WgslExprNodeParser::{ source_text, source_start, tokens, index: 0 }
}

///|
fn WgslExprNodeParser::at_end(self : WgslExprNodeParser) -> Bool {
  self.index >= self.tokens.length()
}

///|
fn WgslExprNodeParser::peek(self : WgslExprNodeParser) -> WgslExprToken? {
  if self.at_end() {
    None
  } else {
    Some(self.tokens[self.index])
  }
}

///|
fn WgslExprNodeParser::make_node(
  self : WgslExprNodeParser,
  kind : WgslExprNodeKind,
  start : Int,
  end_ : Int,
) -> WgslExprNode {
  ignore(self)
  WgslExprNode::new(kind, start, end_)
}

///|
fn wgsl_expr_token_is_punct(token : WgslExprToken, code : Int) -> Bool {
  match token.kind() {
    WgslExprTokenKind::Punctuation(actual) => actual == code
    _ => false
  }
}

///|
fn WgslExprNodeParser::consume_punct(
  self : WgslExprNodeParser,
  code : Int,
) -> Bool {
  match self.peek() {
    Some(token) if wgsl_expr_token_is_punct(token, code) => {
      self.index = self.index + 1
      true
    }
    _ => false
  }
}

///|
fn wgsl_expr_token_is_shift_right(token : WgslExprToken) -> Bool {
  match token.kind() {
    WgslExprTokenKind::Operator(WgslExprOperator::ShiftRight) => true
    _ => false
  }
}

///|
fn WgslExprNodeParser::template_argument_end(
  self : WgslExprNodeParser,
  lt_index : Int,
) -> (Int, Int)? {
  guard lt_index >= 0 && lt_index < self.tokens.length() else { return None }
  guard wgsl_expr_token_is_punct(self.tokens[lt_index], 60) else { return None }
  let mut depth = 0
  for i in lt_index..<self.tokens.length() {
    let token = self.tokens[i]
    if wgsl_expr_token_is_punct(token, 60) {
      depth = depth + 1
      continue
    }
    if wgsl_expr_token_is_punct(token, 62) {
      depth = depth - 1
      if depth == 0 {
        return Some((i, token.start() - self.source_start))
      }
      continue
    }
    if wgsl_expr_token_is_shift_right(token) {
      if depth == 2 {
        return Some((i, token.start() + 1 - self.source_start))
      }
      if depth == 1 {
        return Some((i, token.start() - self.source_start))
      }
      if depth > 2 {
        depth = depth - 2
      }
    }
  }
  None
}

///|
fn WgslExprNodeParser::template_arguments_at(
  self : WgslExprNodeParser,
  lt_index : Int,
) -> (Array[WgslTypeArgument], Int)? {
  match self.template_argument_end(lt_index) {
    Some((gt_index, argument_end)) => {
      guard gt_index + 1 < self.tokens.length() &&
        wgsl_expr_token_is_punct(self.tokens[gt_index + 1], 40) else {
        return None
      }
      let lt_local = self.tokens[lt_index].start() - self.source_start
      Some(
        (
          parse_wgsl_type_template_arguments(
            self.source_text,
            self.source_start,
            lt_local,
            argument_end,
          ),
          gt_index,
        ),
      )
    }
    None => None
  }
}

///|
fn WgslExprNodeParser::binary_operator_at(
  self : WgslExprNodeParser,
) -> (WgslExprOperator, Int)? {
  guard self.index < self.tokens.length() else { return None }
  let first = self.tokens[self.index]
  match first.kind() {
    WgslExprTokenKind::Operator(op) => Some((op, 1))
    WgslExprTokenKind::Punctuation(124) => Some((WgslExprOperator::BitOr, 1))
    WgslExprTokenKind::Punctuation(38) => Some((WgslExprOperator::BitAnd, 1))
    WgslExprTokenKind::Punctuation(60) => Some((WgslExprOperator::Less, 1))
    WgslExprTokenKind::Punctuation(62) => Some((WgslExprOperator::Greater, 1))
    WgslExprTokenKind::Punctuation(43) => Some((WgslExprOperator::Add, 1))
    WgslExprTokenKind::Punctuation(45) => Some((WgslExprOperator::Subtract, 1))
    WgslExprTokenKind::Punctuation(42) => Some((WgslExprOperator::Multiply, 1))
    WgslExprTokenKind::Punctuation(47) => Some((WgslExprOperator::Divide, 1))
    WgslExprTokenKind::Punctuation(37) => Some((WgslExprOperator::Modulo, 1))
    WgslExprTokenKind::Punctuation(94) => Some((WgslExprOperator::BitXor, 1))
    _ => None
  }
}

///|
fn WgslExprNodeParser::parse_prefix(self : WgslExprNodeParser) -> WgslExprNode? {
  match self.peek() {
    Some(token) =>
      match token.kind() {
        WgslExprTokenKind::Punctuation(33)
        | WgslExprTokenKind::Punctuation(45)
        | WgslExprTokenKind::Punctuation(43)
        | WgslExprTokenKind::Punctuation(42)
        | WgslExprTokenKind::Punctuation(38)
        | WgslExprTokenKind::Punctuation(126) => {
          self.index = self.index + 1
          let rhs = match self.parse_prefix() {
            Some(node) => self.parse_postfix(node)
            None =>
              return Some(
                self.make_node(
                  WgslExprNodeKind::Token(token),
                  token.start(),
                  token.end(),
                ),
              )
          }
          Some(
            self.make_node(
              WgslExprNodeKind::Unary(
                WgslExprOperator::from_text(token.text()),
                rhs,
              ),
              token.start(),
              rhs.end(),
            ),
          )
        }
        WgslExprTokenKind::Punctuation(40) => {
          let start = token.start()
          self.index = self.index + 1
          let inner = self.parse_sequence_until(41)
          let end_ = match self.peek() {
            Some(close) if wgsl_expr_token_is_punct(close, 41) => {
              self.index = self.index + 1
              close.end()
            }
            _ => inner.end()
          }
          Some(self.make_node(WgslExprNodeKind::Group(inner), start, end_))
        }
        WgslExprTokenKind::Identifier => {
          self.index = self.index + 1
          Some(
            self.make_node(
              WgslExprNodeKind::Identifier(
                WgslIdent::new(token.text(), token.start(), token.end()),
              ),
              token.start(),
              token.end(),
            ),
          )
        }
        WgslExprTokenKind::BoolLiteral(_)
        | WgslExprTokenKind::UintLiteral(_)
        | WgslExprTokenKind::IntLiteral(_)
        | WgslExprTokenKind::FloatLiteral => {
          self.index = self.index + 1
          Some(
            self.make_node(
              WgslExprNodeKind::Literal(token),
              token.start(),
              token.end(),
            ),
          )
        }
        _ => {
          self.index = self.index + 1
          Some(
            self.make_node(
              WgslExprNodeKind::Token(token),
              token.start(),
              token.end(),
            ),
          )
        }
      }
    None => None
  }
}

///|
fn WgslExprNodeParser::parse_postfix(
  self : WgslExprNodeParser,
  base : WgslExprNode,
) -> WgslExprNode {
  let mut node = base
  while true {
    match self.peek() {
      Some(token) if wgsl_expr_token_is_punct(token, 60) =>
        match self.template_arguments_at(self.index) {
          Some((args, gt_index)) => {
            self.index = gt_index + 1
            node = self.make_node(
              WgslExprNodeKind::Template(node, args),
              node.start(),
              self.tokens[gt_index].end(),
            )
            continue
          }
          None => return node
        }
      Some(token) if wgsl_expr_token_is_punct(token, 40) => {
        self.index = self.index + 1
        let args : Array[WgslExprNode] = []
        while !self.at_end() {
          match self.peek() {
            Some(close) if wgsl_expr_token_is_punct(close, 41) => {
              self.index = self.index + 1
              node = self.make_node(
                WgslExprNodeKind::Call(node, args),
                node.start(),
                close.end(),
              )
              break
            }
            _ => {
              args.push(self.parse_sequence_until_any([44, 41]))
              if self.consume_punct(44) {
                continue
              }
            }
          }
        }
        continue
      }
      Some(token) if wgsl_expr_token_is_punct(token, 46) => {
        self.index = self.index + 1
        match self.peek() {
          Some(member_token) if member_token.kind()
            is WgslExprTokenKind::Identifier => {
            self.index = self.index + 1
            node = self.make_node(
              WgslExprNodeKind::Member(
                node,
                WgslIdent::new(
                  member_token.text(),
                  member_token.start(),
                  member_token.end(),
                ),
              ),
              node.start(),
              member_token.end(),
            )
            continue
          }
          _ => return node
        }
      }
      Some(token) if wgsl_expr_token_is_punct(token, 58) &&
        self.index + 1 < self.tokens.length() &&
        wgsl_expr_token_is_punct(self.tokens[self.index + 1], 58) => {
        self.index = self.index + 2
        match self.peek() {
          Some(segment_token) if segment_token.kind()
            is WgslExprTokenKind::Identifier => {
            self.index = self.index + 1
            node = self.make_node(
              WgslExprNodeKind::PathAccess(
                node,
                WgslIdent::new(
                  segment_token.text(),
                  segment_token.start(),
                  segment_token.end(),
                ),
              ),
              node.start(),
              segment_token.end(),
            )
            continue
          }
          _ => {
            self.index = self.index - 2
            return node
          }
        }
      }
      Some(token) if wgsl_expr_token_is_punct(token, 91) => {
        self.index = self.index + 1
        let index = self.parse_sequence_until(93)
        let end_ = match self.peek() {
          Some(close) if wgsl_expr_token_is_punct(close, 93) => {
            self.index = self.index + 1
            close.end()
          }
          _ => index.end()
        }
        node = self.make_node(
          WgslExprNodeKind::Index(node, index),
          node.start(),
          end_,
        )
        continue
      }
      _ => return node
    }
  }
  node
}

///|
fn WgslExprNodeParser::parse_expression(
  self : WgslExprNodeParser,
  min_precedence : Int,
) -> WgslExprNode? {
  let prefix = match self.parse_prefix() {
    Some(value) => value
    None => return None
  }
  let mut lhs = self.parse_postfix(prefix)
  while true {
    let (op, consumed) = match self.binary_operator_at() {
      Some(value) => value
      None => break
    }
    let precedence = op.binary_precedence()
    if precedence < min_precedence {
      break
    }
    self.index = self.index + consumed
    let rhs = match self.parse_expression(precedence + 1) {
      Some(value) => value
      None => break
    }
    lhs = self.make_node(
      WgslExprNodeKind::Binary(op, lhs, rhs),
      lhs.start(),
      rhs.end(),
    )
  }
  Some(lhs)
}

///|
fn WgslExprNodeParser::parse_sequence_until_any(
  self : WgslExprNodeParser,
  stop_codes : Array[Int],
) -> WgslExprNode {
  let nodes : Array[WgslExprNode] = []
  while !self.at_end() {
    match self.peek() {
      Some(token) if token.kind() is WgslExprTokenKind::Punctuation(code) &&
        stop_codes.contains(code) => break
      _ => ()
    }
    match self.parse_expression(0) {
      Some(node) => nodes.push(node)
      None => break
    }
    if self.consume_punct(44) {
      continue
    }
    match self.peek() {
      Some(token) if token.kind() is WgslExprTokenKind::Punctuation(code) &&
        stop_codes.contains(code) => break
      _ => ()
    }
  }
  match nodes {
    [single] => single
    [] =>
      self.make_node(
        WgslExprNodeKind::Sequence([]),
        self.source_start,
        self.source_start,
      )
    _ => {
      let start = nodes[0].start()
      let end_ = nodes[nodes.length() - 1].end()
      self.make_node(WgslExprNodeKind::Sequence(nodes), start, end_)
    }
  }
}

///|
fn WgslExprNodeParser::parse_sequence_until(
  self : WgslExprNodeParser,
  stop_code : Int,
) -> WgslExprNode {
  self.parse_sequence_until_any([stop_code])
}

///|
fn parse_wgsl_expr_node(
  source_text : String,
  base : Int,
  tokens : Array[WgslExprToken],
) -> WgslExprNode? {
  if tokens.length() == 0 {
    return None
  }
  Some(
    WgslExprNodeParser::new(source_text, base, tokens).parse_sequence_until_any([],
    ),
  )
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
  let expr_tokens : Array[WgslExprToken] = []
  let identifiers : Array[WgslIdent] = []
  collect_wgsl_expr_ref_tokens_and_identifiers(
    trimmed,
    base + local_start,
    expr_tokens,
    identifiers,
  )
  let root = parse_wgsl_expr_node(trimmed, base + local_start, expr_tokens)
  Some(
    WgslExprRef::new(
      expr_tokens,
      identifiers,
      root,
      base + local_start,
      base + local_end,
    ),
  )
}

///|
fn parse_wgsl_expr_ref_fragment(fragment : WgslTextFragment) -> WgslExprRef? {
  if fragment.start < 0 || fragment.end < fragment.start {
    return None
  }
  parse_wgsl_expr_ref_text(fragment.text, fragment.start)
}

///|
priv struct WgslDeclParser {
  source_text : String
  source_start : Int
  mut token_view : ArrayView[WgslToken]
}

///|
priv struct WgslTextFragment {
  text : String
  start : Int
  end : Int
}

///|
priv struct WgslDelimitedTokenView {
  inner : ArrayView[WgslToken]
  open_start : Int
  close_start : Int
  consumed : Int
}

///|
priv struct WgslTokenDepth {
  mut paren : Int
  mut angle : Int
  mut bracket : Int
  mut brace : Int
}

///|
fn WgslTokenDepth::new() -> WgslTokenDepth {
  WgslTokenDepth::{ paren: 0, angle: 0, bracket: 0, brace: 0 }
}

///|
fn WgslTokenDepth::at_top(self : WgslTokenDepth) -> Bool {
  self.paren == 0 && self.angle == 0 && self.bracket == 0 && self.brace == 0
}

///|
fn WgslTokenDepth::observe(self : WgslTokenDepth, token : WgslToken) -> Unit {
  match token.operator_text() {
    Some(">>") => {
      if self.angle >= 2 {
        self.angle = self.angle - 2
      } else {
        self.angle = 0
      }
      return
    }
    _ => ()
  }
  match token.punctuation_code() {
    Some(40) => self.paren = self.paren + 1
    Some(41) => self.paren = self.paren - 1
    Some(60) => self.angle = self.angle + 1
    Some(62) => self.angle = self.angle - 1
    Some(91) => self.bracket = self.bracket + 1
    Some(93) => self.bracket = self.bracket - 1
    Some(123) => self.brace = self.brace + 1
    Some(125) => self.brace = self.brace - 1
    _ => ()
  }
}

///|
fn WgslTokenDepth::observe_statement_token(
  self : WgslTokenDepth,
  token : WgslToken,
) -> Unit {
  match token.punctuation_code() {
    Some(40) => self.paren = self.paren + 1
    Some(41) => self.paren = self.paren - 1
    Some(91) => self.bracket = self.bracket + 1
    Some(93) => self.bracket = self.bracket - 1
    Some(123) => self.brace = self.brace + 1
    Some(125) => self.brace = self.brace - 1
    _ => ()
  }
}

///|
fn wgsl_shift_token(token : WgslToken, offset : Int) -> WgslToken {
  token.shift(offset)
}

///|
fn tokenize_at(
  source : String,
  emit_whitespace : Bool,
  source_start : Int,
) -> Array[WgslToken] {
  let tokens : Array[WgslToken] = []
  for token in tokenize_wgsl(source, emit_whitespace) {
    tokens.push(wgsl_shift_token(token, source_start))
  }
  tokens
}

///|
fn WgslDeclParser::new_at(text : String, source_start : Int) -> WgslDeclParser {
  let tokens = tokenize_at(replace_comments(text), false, source_start)
  WgslDeclParser::{ source_text: text, source_start, token_view: tokens[:] }
}

///|
fn WgslDeclParser::directive_line_end_at_hash(
  self : WgslDeclParser,
  absolute_hash_pos : Int,
) -> Int? {
  let local_hash_pos = absolute_hash_pos - self.source_start
  if local_hash_pos < 0 || local_hash_pos >= self.source_text.length() {
    return None
  }
  let cleaned = replace_comments(self.source_text)
  let line_start = top_level_line_start(cleaned, local_hash_pos)
  guard wgsl_regex_trim_whitespace(
      cleaned[line_start:local_hash_pos].to_owned(),
    ) ==
    "" else {
    return None
  }
  let line_end = top_level_line_end(cleaned, local_hash_pos)
  if parse_wgsl_directive_line(cleaned[local_hash_pos:line_end].to_owned())
    is Some(_) {
    Some(self.source_start + line_end)
  } else {
    None
  }
}

///|
fn WgslDeclParser::slice(
  self : WgslDeclParser,
  start : Int,
  end_ : Int,
) -> String {
  let local_start = start - self.source_start
  let local_end = end_ - self.source_start
  if local_start < 0 ||
    local_end < local_start ||
    local_end > self.source_text.length() {
    return ""
  }
  self.source_text[local_start:local_end].to_owned()
}

///|
fn WgslDeclParser::view(self : WgslDeclParser) -> ArrayView[WgslToken] {
  self.token_view
}

///|
fn WgslDeclParser::update_view(
  self : WgslDeclParser,
  view : ArrayView[WgslToken],
) -> Unit {
  self.token_view = view
}

///|
fn WgslDeclParser::consume_if_other(self : WgslDeclParser, code : Int) -> Bool {
  match self.view() {
    [token, .. rest] if token.is_punctuation(code) => {
      self.update_view(rest)
      true
    }
    _ => false
  }
}

///|
fn WgslDeclParser::consume_ident_node(self : WgslDeclParser) -> WgslIdent? {
  match self.view() {
    [token, .. rest] if token.identifier_text() is Some(name) => {
      let pos = token.pos()
      self.update_view(rest)
      Some(WgslIdent::new(name, pos, pos + name.length()))
    }
    _ => None
  }
}

///|
fn WgslDeclParser::drop_tokens(self : WgslDeclParser, count : Int) -> Unit {
  let mut view = self.view()
  let mut remaining = count
  while remaining > 0 {
    match view {
      [_, .. rest] => {
        view = rest
        remaining = remaining - 1
      }
      [] => break
    }
  }
  self.update_view(view)
}

///|
fn WgslDeclParser::collect_delimited_token_view(
  self : WgslDeclParser,
  open_code : Int,
  close_code : Int,
) -> WgslDelimitedTokenView? {
  let view = self.view()
  let open_start = match view {
    [token, ..] if token.is_punctuation(open_code) => token.pos()
    _ => return None
  }
  let mut depth = 0
  for i in 0..<view.length() {
    if view[i].is_punctuation(open_code) {
      depth = depth + 1
    } else if view[i].is_punctuation(close_code) {
      let pos = view[i].pos()
      depth = depth - 1
      if depth == 0 {
        return Some(WgslDelimitedTokenView::{
          inner: view[1:i],
          open_start,
          close_start: pos,
          consumed: i + 1,
        })
      }
    }
  }
  None
}

///|
fn WgslDeclParser::consume_path_ident_node(self : WgslDeclParser) -> WgslIdent? {
  let first = match self.consume_ident_node() {
    Some(value) => value
    None => return None
  }
  let mut name = first.name()
  let mut end = first.end()
  while true {
    match self.view() {
      [colon_a, colon_b, segment_token, .. rest] if colon_a.is_punctuation(58) &&
        colon_b.is_punctuation(58) &&
        segment_token.identifier_text() is Some(segment) => {
        let segment_pos = segment_token.pos()
        name = name + "::" + segment
        end = segment_pos + segment.length()
        self.update_view(rest)
      }
      _ => break
    }
  }
  Some(WgslIdent::new(name, first.start(), end))
}

///|
fn WgslDeclParser::push_attribute_tokens(
  self : WgslDeclParser,
  tokens : Array[(Token, Int, Int)],
) -> Unit {
  while true {
    match self.view() {
      [at_token, name_token, .. rest] if at_token.is_punctuation(64) &&
        name_token.identifier_text() is Some(name) => {
        let at_pos = at_token.pos()
        let name_pos = name_token.pos()
        self.update_view(rest)
        tokens.push((Token::AT(at_pos), at_pos, at_pos + 1))
        tokens.push(
          (
            Token::ATTR_NAME(
              WgslIdent::new(name, name_pos, name_pos + name.length()),
            ),
            name_pos,
            name_pos + name.length(),
          ),
        )
        match self.collect_delimited_token_view(40, 41) {
          Some(arguments_fragment) => {
            let argument_start = arguments_fragment.open_start + 1
            let argument_end = arguments_fragment.close_start
            if argument_end >= argument_start {
              tokens.push(
                (
                  Token::ATTR_ARGS(
                    (
                      parse_wgsl_expr_ref_text(
                        self.slice(argument_start, argument_end),
                        argument_start,
                      ),
                      arguments_fragment.close_start + 1,
                    ),
                  ),
                  arguments_fragment.open_start,
                  arguments_fragment.close_start + 1,
                ),
              )
            }
            self.drop_tokens(arguments_fragment.consumed)
          }
          _ => ()
        }
        continue
      }
      _ => break
    }
  }
}

///|
fn WgslDeclParser::collect_until_top_level_fragment(
  self : WgslDeclParser,
  stops : Array[Int],
) -> WgslTextFragment {
  self.collect_until_top_level_fragment_with_mode(stops, false)
}

///|
fn WgslDeclParser::collect_until_top_level_type_fragment(
  self : WgslDeclParser,
  stops : Array[Int],
) -> WgslTextFragment {
  self.collect_until_top_level_fragment_with_mode(stops, true)
}

///|
fn WgslDeclParser::collect_until_top_level_fragment_with_mode(
  self : WgslDeclParser,
  stops : Array[Int],
  track_angle : Bool,
) -> WgslTextFragment {
  let mut start_pos = -1
  let mut end_pos = -1
  fn record_token(token : WgslToken) -> Unit {
    if start_pos < 0 {
      start_pos = token.pos()
    }
    end_pos = token.end()
  }
  let depth = WgslTokenDepth::new()
  while true {
    match self.view() {
      [token, ..] if depth.at_top() &&
        token.is_punctuation(35) &&
        self.directive_line_end_at_hash(token.pos()) is Some(_) => break
      [token, ..] if depth.at_top() &&
        token.punctuation_code() is Some(code) &&
        stops.contains(code) => break
      [token, .. rest] => {
        if track_angle {
          depth.observe(token)
        } else {
          depth.observe_statement_token(token)
        }
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
    wgsl_trim_blankspace(self.slice(start_pos, end_pos))
  }
  WgslTextFragment::{ text, start: start_pos, end: end_pos }
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
    if wgsl_blankspace_code_point(code) {
      left = left + 1
      continue
    }
    break
  }
  while right > left {
    let code = text.code_unit_at(right - 1).to_int()
    if wgsl_blankspace_code_point(code) {
      right = right - 1
      continue
    }
    break
  }
  (text[left:right].to_owned(), left, right)
}

///|
fn parse_wgsl_type_ref_text(text : String, base : Int) -> WgslTypeRef? {
  let (trimmed, local_start, _) = wgsl_trim_fragment_bounds(
    text,
    0,
    text.length(),
  )
  if trimmed == "" {
    return None
  }
  let source_start = base + local_start
  Some(
    type_ref(tokenize_wgsl_type_ref(trimmed, source_start)) catch {
      _ => return None
    },
  )
}

///|
fn wgsl_type_ref_space(code : Int) -> Bool {
  wgsl_blankspace_code_point(code)
}

///|
fn wgsl_type_ref_delimiter(code : Int) -> Bool {
  code == 60 || code == 62 || code == 44
}

///|
fn wgsl_type_atom_is_identifier_path(text : String) -> Bool {
  if text == "" {
    return false
  }
  let parts = text.split("::")
  for part in parts {
    let segment = part.to_owned()
    if segment == "" || !wgsl_regex_word_text(segment) {
      return false
    }
  }
  true
}

///|
fn wgsl_type_atom_kind(text : String) -> WgslTypeAtomKind {
  if text.length() == 0 {
    return WgslTypeAtomKind::Unknown
  }
  let first = text.code_unit_at(0).to_int()
  if first >= 48 && first <= 57 {
    WgslTypeAtomKind::Numeric
  } else if wgsl_type_atom_is_identifier_path(text) {
    WgslTypeAtomKind::Identifier
  } else {
    WgslTypeAtomKind::Unknown
  }
}

///|
fn wgsl_type_ref_top_level_template_start(source : String) -> Int? {
  let mut paren = 0
  let mut bracket = 0
  let mut brace = 0
  for i in 0..<source.length() {
    let code = source.code_unit_at(i).to_int()
    match code {
      40 => paren = paren + 1
      41 => paren = paren - 1
      91 => bracket = bracket + 1
      93 => bracket = bracket - 1
      123 => brace = brace + 1
      125 => brace = brace - 1
      60 if paren == 0 && bracket == 0 && brace == 0 => return Some(i)
      _ => ()
    }
  }
  None
}

///|
fn wgsl_type_ref_matching_template_end(source : String, lt_index : Int) -> Int? {
  let mut angle = 0
  let mut paren = 0
  let mut bracket = 0
  let mut brace = 0
  for i in lt_index..<source.length() {
    let code = source.code_unit_at(i).to_int()
    match code {
      40 => paren = paren + 1
      41 => paren = paren - 1
      91 => bracket = bracket + 1
      93 => bracket = bracket - 1
      123 => brace = brace + 1
      125 => brace = brace - 1
      60 if paren == 0 && bracket == 0 && brace == 0 => angle = angle + 1
      62 if paren == 0 && bracket == 0 && brace == 0 => {
        angle = angle - 1
        if angle == 0 {
          return Some(i)
        }
      }
      _ => ()
    }
  }
  None
}

///|
fn wgsl_template_arg_has_top_level_expression_operator(text : String) -> Bool {
  let mut angle = 0
  let mut paren = 0
  let mut bracket = 0
  let mut brace = 0
  let mut i = 0
  while i < text.length() {
    let code = text.code_unit_at(i).to_int()
    match code {
      40 => paren = paren + 1
      41 => paren = paren - 1
      91 => bracket = bracket + 1
      93 => bracket = bracket - 1
      123 => brace = brace + 1
      125 => brace = brace - 1
      60 if paren == 0 && bracket == 0 && brace == 0 => angle = angle + 1
      62 if paren == 0 && bracket == 0 && brace == 0 && angle > 0 =>
        angle = angle - 1
      33 | 37 | 38 | 42 | 43 | 45 | 47 | 61 | 94 | 124 =>
        if angle == 0 && paren == 0 && bracket == 0 && brace == 0 {
          return true
        }
      _ => ()
    }
    i = i + 1
  }
  false
}

///|
fn split_wgsl_template_argument_fragments(
  source : String,
  inner_start : Int,
  inner_end : Int,
) -> Array[WgslTextFragment] {
  let fragments : Array[WgslTextFragment] = []
  let mut angle = 0
  let mut paren = 0
  let mut bracket = 0
  let mut brace = 0
  let mut start = inner_start
  let mut i = inner_start
  while i < inner_end {
    let code = source.code_unit_at(i).to_int()
    match code {
      40 => paren = paren + 1
      41 => paren = paren - 1
      91 => bracket = bracket + 1
      93 => bracket = bracket - 1
      123 => brace = brace + 1
      125 => brace = brace - 1
      60 if paren == 0 && bracket == 0 && brace == 0 => angle = angle + 1
      62 if paren == 0 && bracket == 0 && brace == 0 && angle > 0 =>
        angle = angle - 1
      44 if angle == 0 && paren == 0 && bracket == 0 && brace == 0 => {
        let (trimmed, local_start, local_end) = wgsl_trim_fragment_bounds(
          source[start:i].to_owned(),
          0,
          i - start,
        )
        if trimmed != "" {
          fragments.push(WgslTextFragment::{
            text: trimmed,
            start: start + local_start,
            end: start + local_end,
          })
        }
        start = i + 1
      }
      _ => ()
    }
    i = i + 1
  }
  let (trimmed, local_start, local_end) = wgsl_trim_fragment_bounds(
    source[start:inner_end].to_owned(),
    0,
    inner_end - start,
  )
  if trimmed != "" {
    fragments.push(WgslTextFragment::{
      text: trimmed,
      start: start + local_start,
      end: start + local_end,
    })
  }
  fragments
}

///|
fn parse_wgsl_type_template_argument(
  fragment : WgslTextFragment,
  source_start : Int,
) -> WgslTypeArgument? {
  let absolute_start = source_start + fragment.start
  if !wgsl_template_arg_has_top_level_expression_operator(fragment.text) {
    match parse_wgsl_type_ref_text(fragment.text, absolute_start) {
      Some(ty) => return Some(WgslTypeArgument::Type(ty))
      None => ()
    }
  }
  match parse_wgsl_expr_ref_text(fragment.text, absolute_start) {
    Some(expr) => Some(WgslTypeArgument::Expression(expr))
    None => None
  }
}

///|
fn parse_wgsl_type_template_arguments(
  source : String,
  source_start : Int,
  lt_index : Int,
  gt_index : Int,
) -> Array[WgslTypeArgument] {
  let arguments : Array[WgslTypeArgument] = []
  for
    fragment in split_wgsl_template_argument_fragments(
      source,
      lt_index + 1,
      gt_index,
    ) {
    match parse_wgsl_type_template_argument(fragment, source_start) {
      Some(argument) => arguments.push(argument)
      None => ()
    }
  }
  arguments
}

///|
fn tokenize_wgsl_type_ref(
  source : String,
  source_start : Int,
) -> Array[(Token, Int, Int)] {
  let tokens : Array[(Token, Int, Int)] = []
  match wgsl_type_ref_top_level_template_start(source) {
    Some(lt_index) if lt_index > 0 =>
      match wgsl_type_ref_matching_template_end(source, lt_index) {
        Some(gt_index) if gt_index == source.length() - 1 => {
          let (atom_text, atom_local_start, atom_local_end) = wgsl_trim_fragment_bounds(
            source[0:lt_index].to_owned(),
            0,
            lt_index,
          )
          let atom_start = source_start + atom_local_start
          let atom_end = source_start + atom_local_end
          tokens.push(
            (
              Token::TYPE_ATOM(
                WgslTypeAtom::new(
                  wgsl_type_atom_kind(atom_text),
                  atom_text,
                  atom_start,
                  atom_end,
                ),
              ),
              atom_start,
              atom_end,
            ),
          )
          tokens.push(
            (
              Token::TYPE_ARGS(
                (
                  parse_wgsl_type_template_arguments(
                    source, source_start, lt_index, gt_index,
                  ),
                  source_start + gt_index + 1,
                ),
              ),
              source_start + lt_index,
              source_start + gt_index + 1,
            ),
          )
          tokens.push(
            (
              Token::EOF,
              source_start + source.length(),
              source_start + source.length(),
            ),
          )
          return tokens
        }
        _ => ()
      }
    _ => ()
  }
  let mut i = 0
  while i < source.length() {
    let code = source.code_unit_at(i).to_int()
    if wgsl_type_ref_space(code) {
      i = i + 1
      continue
    }
    let start = i
    let absolute_start = source_start + start
    if code == 60 {
      tokens.push(
        (
          Token::TYPE_LT(source_start + start + 1),
          absolute_start,
          absolute_start + 1,
        ),
      )
      i = i + 1
      continue
    }
    if code == 62 {
      tokens.push(
        (
          Token::TYPE_GT(source_start + start + 1),
          absolute_start,
          absolute_start + 1,
        ),
      )
      i = i + 1
      continue
    }
    if code == 44 {
      tokens.push((Token::COMMA, absolute_start, absolute_start + 1))
      i = i + 1
      continue
    }
    while i < source.length() {
      let next = source.code_unit_at(i).to_int()
      if wgsl_type_ref_space(next) || wgsl_type_ref_delimiter(next) {
        break
      }
      i = i + 1
    }
    let absolute_end = source_start + i
    let text = source[start:i].to_owned()
    tokens.push(
      (
        Token::TYPE_ATOM(
          WgslTypeAtom::new(
            wgsl_type_atom_kind(text),
            text,
            absolute_start,
            absolute_end,
          ),
        ),
        absolute_start,
        absolute_end,
      ),
    )
  }
  tokens.push(
    (Token::EOF, source_start + source.length(), source_start + source.length()),
  )
  tokens
}

///|
fn parse_wgsl_type_ref_fragment(fragment : WgslTextFragment) -> WgslTypeRef? {
  if fragment.start < 0 || fragment.end < fragment.start {
    return None
  }
  parse_wgsl_type_ref_text(fragment.text, fragment.start)
}

///|
priv struct WgslTemplateListFragment {
  text : String
  start : Int
  consumed : Int
}

///|
fn WgslDeclParser::collect_template_list_fragment(
  self : WgslDeclParser,
) -> WgslTemplateListFragment? {
  let view = self.view()
  guard view is [open_token, ..] && open_token.is_punctuation(60) else {
    return None
  }
  let open_pos = open_token.pos()
  let mut depth = 0
  let mut consumed = 0
  let mut end_pos = -1
  while consumed < view.length() {
    if view[consumed].is_punctuation(60) {
      depth = depth + 1
    } else if view[consumed].is_punctuation(62) {
      let pos = view[consumed].pos()
      depth = depth - 1
      if depth == 0 {
        end_pos = pos + 1
        consumed = consumed + 1
        break
      }
    }
    consumed = consumed + 1
  }
  guard end_pos >= open_pos else { return None }
  Some(WgslTemplateListFragment::{
    text: self.slice(open_pos, end_pos),
    start: open_pos,
    consumed,
  })
}

///|
fn WgslDeclParser::parse_template_list(
  self : WgslDeclParser,
) -> Array[WgslTypeRef] {
  match self.collect_template_list_fragment() {
    Some(fragment) => {
      let parsed = template_list(
        tokenize_wgsl_type_ref(fragment.text, fragment.start),
      ) catch {
        _ => return []
      }
      self.drop_tokens(fragment.consumed)
      parsed
    }
    None => []
  }
}

///|
