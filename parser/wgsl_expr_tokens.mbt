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
fn wgsl_expr_numeric_literal_base(text : String) -> WgslNumericLiteralBase {
  if text.length() >= 2 &&
    text.code_unit_at(0).to_int() == 48 &&
    (
      text.code_unit_at(1).to_int() == 120 ||
      text.code_unit_at(1).to_int() == 88
    ) {
    Hexadecimal
  } else {
    Decimal
  }
}

///|
fn wgsl_expr_numeric_literal_suffix(
  category : WgslNumericLiteralCategory,
) -> WgslNumericLiteralSuffix {
  match category {
    I32Literal => I32Suffix
    U32Literal => U32Suffix
    F32Literal => F32Suffix
    F16Literal => F16Suffix
    _ => NoSuffix
  }
}

///|
fn wgsl_expr_integer_body_is_valid(text : String, end : Int) -> Bool {
  if end <= 0 {
    return false
  }
  if end > 2 &&
    text.code_unit_at(0).to_int() == 48 &&
    (
      text.code_unit_at(1).to_int() == 120 ||
      text.code_unit_at(1).to_int() == 88
    ) {
    guard end > 2 else { return false }
    for i in 2..<end {
      match wgsl_expr_ascii_hex_digit_value(text.code_unit_at(i).to_int()) {
        Some(_) => ()
        None => return false
      }
    }
    return true
  }
  for i in 0..<end {
    if !wgsl_expr_ascii_digit(text.code_unit_at(i).to_int()) {
      return false
    }
  }
  true
}

///|
fn wgsl_expr_uint_literal_token_is_valid(text : String) -> Bool {
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
    return false
  }
  wgsl_expr_integer_body_is_valid(text, end)
}

///|
fn wgsl_expr_int_literal_token_is_valid(text : String) -> Bool {
  let mut end = text.length()
  if end > 0 {
    let last = text.code_unit_at(end - 1).to_int()
    if last == 105 || last == 73 {
      end = end - 1
    }
  }
  wgsl_expr_integer_body_is_valid(text, end)
}

///|
fn wgsl_expr_ascii_alpha(code : Int) -> Bool {
  (code >= 65 && code <= 90) || (code >= 97 && code <= 122)
}

///|
fn wgsl_expr_float_literal_token_is_valid(text : String) -> Bool {
  if text.length() == 0 {
    return false
  }
  let mut end = text.length()
  let last = text.code_unit_at(end - 1).to_int()
  if last == 102 || last == 70 || last == 104 || last == 72 {
    end = end - 1
  }
  if end <= 0 {
    return false
  }
  let last_body = text.code_unit_at(end - 1).to_int()
  if last_body == 43 ||
    last_body == 45 ||
    last_body == 69 ||
    last_body == 80 ||
    last_body == 101 ||
    last_body == 112 {
    return false
  }
  if end > 2 &&
    text.code_unit_at(0).to_int() == 48 &&
    (
      text.code_unit_at(1).to_int() == 120 ||
      text.code_unit_at(1).to_int() == 88
    ) {
    let mut has_hex_digit = false
    let mut has_exponent = false
    for i in 2..<end {
      let code = text.code_unit_at(i).to_int()
      if wgsl_expr_ascii_hex_digit_value(code) != None {
        has_hex_digit = true
        continue
      }
      if code == 46 {
        continue
      }
      if code == 80 || code == 112 {
        has_exponent = true
        continue
      }
      if (code == 43 || code == 45) && i > 2 {
        let previous = text.code_unit_at(i - 1).to_int()
        if previous == 80 || previous == 112 {
          continue
        }
      }
      return false
    }
    return has_hex_digit && has_exponent
  }
  let mut has_float_marker = false
  for i in 0..<end {
    let code = text.code_unit_at(i).to_int()
    if wgsl_expr_ascii_digit(code) {
      continue
    }
    if code == 46 {
      has_float_marker = true
      continue
    }
    if code == 69 || code == 101 {
      has_float_marker = true
      continue
    }
    if (code == 43 || code == 45) && i > 0 {
      let previous = text.code_unit_at(i - 1).to_int()
      if previous == 69 || previous == 101 {
        continue
      }
    }
    if wgsl_expr_ascii_alpha(code) {
      return false
    }
    return false
  }
  has_float_marker || last == 102 || last == 70 || last == 104 || last == 72
}

///|
fn wgsl_expr_number_token_kind(text : String) -> WgslExprTokenKind {
  let category = if wgsl_expr_uint_literal_token_is_valid(text) {
    WgslNumericLiteralCategory::U32Literal
  } else if wgsl_expr_int_literal_token_is_valid(text) {
    if text.length() > 0 &&
      (
        text.code_unit_at(text.length() - 1).to_int() == 105 ||
        text.code_unit_at(text.length() - 1).to_int() == 73
      ) {
      I32Literal
    } else {
      AbstractIntLiteral
    }
  } else if wgsl_expr_float_literal_token_is_valid(text) {
    if text.length() > 0 {
      match text[text.length() - 1:].to_owned().to_lower() {
        "f" => F32Literal
        "h" => F16Literal
        _ => AbstractFloatLiteral
      }
    } else {
      AbstractFloatLiteral
    }
  } else {
    InvalidNumericLiteral
  }
  NumericLiteral({
    raw_text: text,
    base: wgsl_expr_numeric_literal_base(text),
    suffix: wgsl_expr_numeric_literal_suffix(category),
    category,
  })
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
          "false" => BoolLiteral(false)
          _ => Identifier
        }
        expr_tokens.push(
          WgslExprToken(
            kind,
            name,
            absolute_start,
            absolute_start + name.length(),
          ),
        )
        if !wgsl_expr_identifier_has_access_prefix(tokens, i) &&
          kind is Identifier {
          identifiers.push(
            WgslIdent(name, absolute_start, absolute_start + name.length()),
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
          WgslExprToken(
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
            WgslExprToken(
              wgsl_expr_number_token_kind(token_text),
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
            WgslExprToken(
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
          WgslExprToken(
            Punctuation(code),
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
          WgslExprToken(
            Operator(WgslExprOperator::from_text(operator)),
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
