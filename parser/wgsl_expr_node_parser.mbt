///|
priv struct WgslExprNodeParser {
  source_text : String
  source_start : Int
  tokens : Array[WgslExprToken]
  mut index : Int
  mut failed : Bool
}

///|
fn WgslExprNodeParser::WgslExprNodeParser(
  source_text : String,
  source_start : Int,
  tokens : Array[WgslExprToken],
) -> WgslExprNodeParser {
  WgslExprNodeParser::{
    source_text,
    source_start,
    tokens,
    index: 0,
    failed: false,
  }
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
  WgslExprNode(kind, start, end_)
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
fn WgslExprNodeParser::assignment_operator_at(
  self : WgslExprNodeParser,
) -> (String, Int)? {
  guard self.index < self.tokens.length() else { return None }
  let first = self.tokens[self.index]
  match first.kind() {
    WgslExprTokenKind::Punctuation(61) => Some(("=", 1))
    WgslExprTokenKind::Operator(WgslExprOperator::Unknown(op)) =>
      match op {
        "+=" | "-=" | "*=" | "/=" | "%=" | "&=" | "|=" | "^=" => Some((op, 1))
        _ => None
      }
    WgslExprTokenKind::Operator(WgslExprOperator::ShiftLeft) =>
      if self.index + 1 < self.tokens.length() &&
        wgsl_expr_token_is_punct(self.tokens[self.index + 1], 61) {
        Some(("<<=", 2))
      } else {
        None
      }
    WgslExprTokenKind::Operator(WgslExprOperator::ShiftRight) =>
      if self.index + 1 < self.tokens.length() &&
        wgsl_expr_token_is_punct(self.tokens[self.index + 1], 61) {
        Some((">>=", 2))
      } else {
        None
      }
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
            None => {
              self.failed = true
              return None
            }
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
                WgslIdent(token.text(), token.start(), token.end()),
              ),
              token.start(),
              token.end(),
            ),
          )
        }
        WgslExprTokenKind::Punctuation(35) => {
          let start = token.start()
          self.index = self.index + 1
          let end_ = match self.peek() {
            Some(open) if wgsl_expr_token_is_punct(open, 123) => {
              self.index = self.index + 1
              while !self.at_end() {
                match self.peek() {
                  Some(close) if wgsl_expr_token_is_punct(close, 125) => {
                    self.index = self.index + 1
                    break
                  }
                  Some(_) => self.index = self.index + 1
                  None => break
                }
              }
              match self.tokens.get(self.index - 1) {
                Some(last) => last.end()
                None => token.end()
              }
            }
            Some(name_token) if name_token.kind()
              is WgslExprTokenKind::Identifier => {
              self.index = self.index + 1
              name_token.end()
            }
            _ => token.end()
          }
          Some(
            self.make_node(
              WgslExprNodeKind::ShaderDefTemplate(
                self.source_text[start - self.source_start:end_ -
                self.source_start].to_owned(),
              ),
              start,
              end_,
            ),
          )
        }
        WgslExprTokenKind::BoolLiteral(_)
        | WgslExprTokenKind::NumericLiteral(_) => {
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
          self.failed = true
          None
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
              args.push(self.parse_argument_until_any([44, 41]))
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
                WgslIdent(
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
                WgslIdent(
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
      Some(token) =>
        match token.kind() {
          WgslExprTokenKind::Operator(WgslExprOperator::Unknown(op)) =>
            if op == "++" || op == "--" {
              self.index = self.index + 1
              node = self.make_node(
                WgslExprNodeKind::PostfixUpdate(op, node),
                node.start(),
                token.end(),
              )
              continue
            } else {
              return node
            }
          _ => return node
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
      None => {
        self.failed = true
        break
      }
    }
    lhs = self.make_node(
      WgslExprNodeKind::Binary(op, lhs, rhs),
      lhs.start(),
      rhs.end(),
    )
  }
  if min_precedence == 0 {
    match self.assignment_operator_at() {
      Some((op, consumed)) => {
        self.index = self.index + consumed
        match self.parse_expression(0) {
          Some(rhs) =>
            lhs = self.make_node(
              WgslExprNodeKind::Assignment(op, lhs, rhs),
              lhs.start(),
              rhs.end(),
            )
          None => self.failed = true
        }
      }
      None => ()
    }
  }
  Some(lhs)
}

///|
fn WgslExprNodeParser::parse_argument_until_any(
  self : WgslExprNodeParser,
  stop_codes : Array[Int],
) -> WgslExprNode {
  match self.peek() {
    Some(token) if token.kind() is WgslExprTokenKind::Punctuation(code) &&
      stop_codes.contains(code) =>
      self.make_node(
        WgslExprNodeKind::Sequence([]),
        self.source_start,
        self.source_start,
      )
    _ =>
      match self.parse_expression(0) {
        Some(node) => node
        None => {
          self.failed = true
          self.make_node(
            WgslExprNodeKind::Sequence([]),
            self.source_start,
            self.source_start,
          )
        }
      }
  }
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
      None => {
        self.failed = true
        break
      }
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
  let parser = WgslExprNodeParser(source_text, base, tokens)
  let node = parser.parse_sequence_until_any([])
  if parser.failed || !parser.at_end() {
    None
  } else {
    Some(node)
  }
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
  for token in expr_tokens {
    match token.kind() {
      WgslExprTokenKind::NumericLiteral(literal) =>
        if literal.category == WgslNumericLiteralCategory::InvalidNumericLiteral {
          return None
        }
      _ => ()
    }
  }
  let root = match
    parse_wgsl_expr_node(trimmed, base + local_start, expr_tokens) {
    Some(node) => Some(node)
    None => return None
  }
  Some(
    WgslExprRef(
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
