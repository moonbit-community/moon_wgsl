///|
priv struct WgslIrExprTokenDepth {
  mut paren : Int
  mut angle : Int
  mut bracket : Int
  mut brace : Int
}

///|
fn WgslIrExprTokenDepth::WgslIrExprTokenDepth() -> WgslIrExprTokenDepth {
  { paren: 0, angle: 0, bracket: 0, brace: 0 }
}

///|
fn WgslIrExprTokenDepth::at_top(self : WgslIrExprTokenDepth) -> Bool {
  self.paren == 0 && self.angle == 0 && self.bracket == 0 && self.brace == 0
}

///|
fn WgslIrExprTokenDepth::observe(
  self : WgslIrExprTokenDepth,
  token : @ast.WgslExprToken,
) -> Unit {
  match token.kind() {
    Operator(ShiftRight) => {
      if self.angle >= 2 {
        self.angle = self.angle - 2
      } else {
        self.angle = 0
      }
      return
    }
    _ => ()
  }
  match token.kind() {
    Punctuation(40) => self.paren = self.paren + 1
    Punctuation(41) => self.paren = self.paren - 1
    Punctuation(60) => self.angle = self.angle + 1
    Punctuation(62) => self.angle = self.angle - 1
    Punctuation(91) => self.bracket = self.bracket + 1
    Punctuation(93) => self.bracket = self.bracket - 1
    Punctuation(123) => self.brace = self.brace + 1
    Punctuation(125) => self.brace = self.brace - 1
    _ => ()
  }
}

///|
fn wgsl_ir_expr_tokens_assignment(
  tokens : Array[@ast.WgslExprToken],
) -> (String, Array[@ast.WgslExprToken], Array[@ast.WgslExprToken])? {
  let depth = WgslIrExprTokenDepth()
  for i in 0..<tokens.length() {
    if depth.at_top() {
      match wgsl_ir_expr_assignment_at(tokens, i) {
        Some((op, consumed)) =>
          return Some(
            (
              op,
              wgsl_ir_expr_token_slice(tokens, 0, i),
              wgsl_ir_expr_token_slice(tokens, i + consumed, tokens.length()),
            ),
          )
        None => ()
      }
    }
    depth.observe(tokens[i])
  }
  None
}

///|
fn wgsl_ir_expr_assignment_at(
  tokens : Array[@ast.WgslExprToken],
  index : Int,
) -> (String, Int)? {
  guard index >= 0 && index < tokens.length() else { return None }
  match tokens[index].kind() {
    Operator(Unknown(op)) if wgsl_ir_is_compound_assignment_operator(op) =>
      Some((op, 1))
    Operator(ShiftLeft) if index + 1 < tokens.length() &&
      wgsl_ir_expr_token_is_punctuation(tokens[index + 1], 61) =>
      Some(("<<=", 2))
    Operator(ShiftRight) if index + 1 < tokens.length() &&
      wgsl_ir_expr_token_is_punctuation(tokens[index + 1], 61) =>
      Some((">>=", 2))
    Punctuation(61) => Some(("=", 1))
    _ => None
  }
}

///|
fn wgsl_ir_is_compound_assignment_operator(op : String) -> Bool {
  op == "+=" ||
  op == "-=" ||
  op == "*=" ||
  op == "/=" ||
  op == "%=" ||
  op == "&=" ||
  op == "|=" ||
  op == "^=" ||
  op == "<<=" ||
  op == ">>="
}

///|
fn wgsl_ir_expr_tokens_update_operator(
  tokens : Array[@ast.WgslExprToken],
) -> (Array[@ast.WgslExprToken], Bool)? {
  guard tokens.length() > 1 else { return None }
  let last = tokens[tokens.length() - 1]
  match last.kind() {
    Operator(Unknown("++")) =>
      Some((wgsl_ir_expr_token_slice(tokens, 0, tokens.length() - 1), true))
    Operator(Unknown("--")) =>
      Some((wgsl_ir_expr_token_slice(tokens, 0, tokens.length() - 1), false))
    _ => None
  }
}

///|
fn wgsl_ir_expr_token_slice(
  tokens : Array[@ast.WgslExprToken],
  start : Int,
  end_ : Int,
) -> Array[@ast.WgslExprToken] {
  let out : Array[@ast.WgslExprToken] = []
  for i in start..<end_ {
    out.push(tokens[i])
  }
  out
}

///|
fn wgsl_ir_expr_token_is_punctuation(
  token : @ast.WgslExprToken,
  code : Int,
) -> Bool {
  match token.kind() {
    Punctuation(value) => value == code
    _ => false
  }
}

///|
fn wgsl_ir_expr_node_from_tokens(
  tokens : Array[@ast.WgslExprToken],
) -> @ast.WgslExprNode raise WgslIrLowerError {
  guard tokens.length() > 0 else {
    raise UnsupportedExpression("empty expression token list")
  }
  let parser = WgslIrExprTokenParser::{ tokens, index: 0, failed: false }
  match parser.parse_expression(0) {
    Some(node) =>
      if parser.failed || !parser.at_end() {
        raise UnsupportedExpression("failed to parse expression token list")
      } else {
        node
      }
    None => raise UnsupportedExpression("failed to parse expression token list")
  }
}

///|
fn WgslIrExprTokenParser::at_end(self : WgslIrExprTokenParser) -> Bool {
  self.index >= self.tokens.length()
}

///|
fn WgslIrExprTokenParser::peek(
  self : WgslIrExprTokenParser,
) -> @ast.WgslExprToken? {
  self.tokens.get(self.index)
}

///|
fn WgslIrExprTokenParser::consume_punctuation(
  self : WgslIrExprTokenParser,
  code : Int,
) -> Bool {
  match self.peek() {
    Some(token) if wgsl_ir_expr_token_is_punctuation(token, code) => {
      self.index = self.index + 1
      true
    }
    _ => false
  }
}

///|
fn wgsl_ir_expr_make_node(
  kind : @ast.WgslExprNodeKind,
  start : Int,
  end_ : Int,
) -> @ast.WgslExprNode {
  WgslExprNode(kind, start, end_)
}

///|
fn WgslIrExprTokenParser::parse_expression(
  self : WgslIrExprTokenParser,
  min_precedence : Int,
) -> @ast.WgslExprNode? {
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
    lhs = wgsl_ir_expr_make_node(Binary(op, lhs, rhs), lhs.start(), rhs.end())
  }
  Some(lhs)
}

///|
fn WgslIrExprTokenParser::parse_prefix(
  self : WgslIrExprTokenParser,
) -> @ast.WgslExprNode? {
  match self.peek() {
    Some(token) =>
      match token.kind() {
        Identifier => {
          self.index = self.index + 1
          Some(
            wgsl_ir_expr_make_node(
              Identifier(WgslIdent(token.text(), token.start(), token.end())),
              token.start(),
              token.end(),
            ),
          )
        }
        BoolLiteral(_) | NumericLiteral(_) => {
          self.index = self.index + 1
          Some(
            wgsl_ir_expr_make_node(Literal(token), token.start(), token.end()),
          )
        }
        Punctuation(33)
        | Punctuation(45)
        | Punctuation(43)
        | Punctuation(42)
        | Punctuation(38)
        | Punctuation(126) => {
          self.index = self.index + 1
          let rhs = match self.parse_prefix() {
            Some(node) => node
            None => {
              self.failed = true
              return None
            }
          }
          Some(
            wgsl_ir_expr_make_node(
              Unary(@ast.WgslExprOperator::from_text(token.text()), rhs),
              token.start(),
              rhs.end(),
            ),
          )
        }
        Punctuation(40) => {
          let start = token.start()
          self.index = self.index + 1
          let inner = self.parse_sequence_until_any([41])
          let end_ = match self.peek() {
            Some(close) if wgsl_ir_expr_token_is_punctuation(close, 41) => {
              self.index = self.index + 1
              close.end()
            }
            _ => inner.end()
          }
          Some(wgsl_ir_expr_make_node(Group(inner), start, end_))
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
fn WgslIrExprTokenParser::parse_postfix(
  self : WgslIrExprTokenParser,
  base : @ast.WgslExprNode,
) -> @ast.WgslExprNode {
  let mut node = base
  while true {
    match self.peek() {
      Some(token) if wgsl_ir_expr_token_is_punctuation(token, 40) => {
        self.index = self.index + 1
        let args : Array[@ast.WgslExprNode] = []
        while !self.at_end() {
          match self.peek() {
            Some(close) if wgsl_ir_expr_token_is_punctuation(close, 41) => {
              self.index = self.index + 1
              node = wgsl_ir_expr_make_node(
                Call(node, args),
                node.start(),
                close.end(),
              )
              break
            }
            _ => {
              args.push(self.parse_sequence_until_any([44, 41]))
              if self.consume_punctuation(44) {
                continue
              }
            }
          }
        }
        continue
      }
      Some(token) if wgsl_ir_expr_token_is_punctuation(token, 46) => {
        self.index = self.index + 1
        match self.peek() {
          Some(member_token) if member_token.kind() is Identifier => {
            self.index = self.index + 1
            node = wgsl_ir_expr_make_node(
              Member(
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
      Some(token) if wgsl_ir_expr_token_is_punctuation(token, 91) => {
        self.index = self.index + 1
        let index = self.parse_sequence_until_any([93])
        let end_ = match self.peek() {
          Some(close) if wgsl_ir_expr_token_is_punctuation(close, 93) => {
            self.index = self.index + 1
            close.end()
          }
          _ => index.end()
        }
        node = wgsl_ir_expr_make_node(Index(node, index), node.start(), end_)
        continue
      }
      _ => return node
    }
  }
  node
}

///|
fn WgslIrExprTokenParser::parse_sequence_until_any(
  self : WgslIrExprTokenParser,
  stop_codes : Array[Int],
) -> @ast.WgslExprNode {
  let nodes : Array[@ast.WgslExprNode] = []
  while !self.at_end() {
    match self.peek() {
      Some(token) if token.kind() is Punctuation(code) &&
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
    if self.consume_punctuation(44) {
      continue
    }
    match self.peek() {
      Some(token) if token.kind() is Punctuation(code) &&
        stop_codes.contains(code) => break
      _ => ()
    }
  }
  match nodes {
    [single] => single
    [] => wgsl_ir_expr_make_node(Sequence([]), 0, 0)
    _ =>
      wgsl_ir_expr_make_node(
        Sequence(nodes),
        nodes[0].start(),
        nodes[nodes.length() - 1].end(),
      )
  }
}

///|
fn WgslIrExprTokenParser::binary_operator_at(
  self : WgslIrExprTokenParser,
) -> (@ast.WgslExprOperator, Int)? {
  guard self.index < self.tokens.length() else { return None }
  match self.tokens[self.index].kind() {
    Operator(op) => Some((op, 1))
    Punctuation(124) => Some((BitOr, 1))
    Punctuation(38) => Some((BitAnd, 1))
    Punctuation(60) => Some((Less, 1))
    Punctuation(62) => Some((Greater, 1))
    Punctuation(43) => Some((Add, 1))
    Punctuation(45) => Some((Subtract, 1))
    Punctuation(42) => Some((Multiply, 1))
    Punctuation(47) => Some((Divide, 1))
    Punctuation(37) => Some((Modulo, 1))
    Punctuation(94) => Some((BitXor, 1))
    _ => None
  }
}
