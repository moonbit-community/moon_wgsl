///|
fn preprocess_token_text(token : WgslToken) -> String {
  match token {
    WgslToken::Identifier(text, _) => text
    WgslToken::Whitespace(text, _) => text
    WgslToken::Other(code, _) => code_unit_to_string(code)
  }
}

///|
fn parse_if_operator_expression(
  expression : String,
) -> (String, String, String)? {
  let text = trim_trailing_semicolons(expression)
  let tokens = tokenize(text, false)
  let mut i = 0
  let mut def = ""
  while i < tokens.length() {
    match tokens[i] {
      WgslToken::Identifier(ident, _) => def = def + ident
      WgslToken::Other(124, _) => def = def + "|"
      _ => break
    }
    i = i + 1
  }
  guard def != "" else { return None }
  let mut operator = ""
  while i < tokens.length() {
    match tokens[i] {
      WgslToken::Other(code, _) if code == 61 ||
        code == 33 ||
        code == 60 ||
        code == 62 => operator = operator + code_unit_to_string(code)
      _ => break
    }
    i = i + 1
  }
  guard operator != "" else { return None }
  let mut value = ""
  while i < tokens.length() {
    match shader_def_value_token_text(tokens[i]) {
      Some(text) => value = value + text
      None => break
    }
    i = i + 1
  }
  if value == "" {
    None
  } else {
    Some((def, operator, value))
  }
}

///|
fn compare_bool_values(
  lhs : Bool,
  rhs : Bool,
  operator : String,
  offset : Int,
) -> Bool raise PreprocessError {
  match operator {
    "==" => lhs == rhs
    "!=" => lhs != rhs
    ">" => lhs > rhs
    ">=" => lhs >= rhs
    "<" => lhs < rhs
    "<=" => lhs <= rhs
    _ => raise PreprocessError::UnknownShaderDefOperator(operator, offset)
  }
}

///|
fn compare_int_values(
  lhs : Int,
  rhs : Int,
  operator : String,
  offset : Int,
) -> Bool raise PreprocessError {
  match operator {
    "==" => lhs == rhs
    "!=" => lhs != rhs
    ">" => lhs > rhs
    ">=" => lhs >= rhs
    "<" => lhs < rhs
    "<=" => lhs <= rhs
    _ => raise PreprocessError::UnknownShaderDefOperator(operator, offset)
  }
}

///|
fn compare_uint_values(
  lhs : UInt,
  rhs : UInt,
  operator : String,
  offset : Int,
) -> Bool raise PreprocessError {
  match operator {
    "==" => lhs == rhs
    "!=" => lhs != rhs
    ">" => lhs > rhs
    ">=" => lhs >= rhs
    "<" => lhs < rhs
    "<=" => lhs <= rhs
    _ => raise PreprocessError::UnknownShaderDefOperator(operator, offset)
  }
}

///|
fn eval_if_condition(
  shader_defs : @hashmap.HashMap[String, ShaderDefValue],
  def : String,
  operator : String,
  value : String,
  offset : Int,
) -> Bool raise PreprocessError {
  guard shader_defs.get(def) is Some(def_value) else {
    raise PreprocessError::UnknownShaderDef(def, offset)
  }
  match def_value {
    ShaderDefValue::Bool(bool_value) =>
      match parse_bool_text(value) {
        Some(expected) =>
          compare_bool_values(bool_value, expected, operator, offset)
        None =>
          raise PreprocessError::InvalidShaderDefComparisonValue(
            def, value, "bool", offset,
          )
      }
    ShaderDefValue::Int(int_value) => {
      let parsed = @string.parse_int(value[:], base=10) catch {
        _ =>
          raise PreprocessError::InvalidShaderDefComparisonValue(
            def, value, "int", offset,
          )
      }
      compare_int_values(int_value, parsed, operator, offset)
    }
    ShaderDefValue::UInt(uint_value) => {
      let parsed = @string.parse_int(value[:], base=10) catch {
        _ =>
          raise PreprocessError::InvalidShaderDefComparisonValue(
            def, value, "uint", offset,
          )
      }
      if parsed < 0 {
        raise PreprocessError::InvalidShaderDefComparisonValue(
          def, value, "uint", offset,
        )
      }
      compare_uint_values(
        uint_value,
        parsed.reinterpret_as_uint(),
        operator,
        offset,
      )
    }
  }
}

///|
fn check_scope(
  shader_defs : @hashmap.HashMap[String, ShaderDefValue],
  line : String,
  scope : Scope?,
  offset : Int,
) -> (Bool, String?) raise PreprocessError {
  if wgsl_directive_tail(line, WgslDirectiveKind::Ifdef) is Some(rest) &&
    directive_identifier(rest) is Some(name) {
    let condition = shader_defs.contains(name)
    if scope is Some(scope_state) {
      scope_state.branch(false, condition, offset)
    }
    return (true, Some(name))
  }
  if wgsl_directive_tail(line, WgslDirectiveKind::Ifndef) is Some(rest) &&
    directive_identifier(rest) is Some(name) {
    let condition = !shader_defs.contains(name)
    if scope is Some(scope_state) {
      scope_state.branch(false, condition, offset)
    }
    return (true, Some(name))
  }
  if wgsl_directive_prefix_tail(line, WgslDirectiveKind::Else)
    is Some(else_tail) {
    let else_tail_has_space = starts_with_tokenized_space(else_tail)
    if else_tail_has_space &&
      word_tail(else_tail, "ifdef") is Some(rest) &&
      directive_identifier(rest) is Some(name) {
      let condition = shader_defs.contains(name)
      if scope is Some(scope_state) {
        scope_state.branch(true, condition, offset)
      }
      return (true, Some(name))
    }
    if else_tail_has_space &&
      word_tail(else_tail, "ifndef") is Some(rest) &&
      directive_identifier(rest) is Some(name) {
      let condition = !shader_defs.contains(name)
      if scope is Some(scope_state) {
        scope_state.branch(true, condition, offset)
      }
      return (true, Some(name))
    }
    if else_tail_has_space && word_tail(else_tail, "if") is Some(expr) {
      guard parse_if_operator_expression(expr) is Some((def, operator, value)) else {
        raise PreprocessError::UnknownShaderDefOperator("", offset)
      }
      if scope is None {
        return (true, Some(def))
      }
      let condition = eval_if_condition(
        shader_defs, def, operator, value, offset,
      )
      guard scope is Some(scope_state) else {
        abort("unreachable missing scope")
      }
      scope_state.branch(true, condition, offset)
      return (true, Some(def))
    }
  }
  if wgsl_directive_tail(line, WgslDirectiveKind::If) is Some(expr) {
    guard parse_if_operator_expression(expr) is Some((def, operator, value)) else {
      raise PreprocessError::UnknownShaderDefOperator("", offset)
    }
    if scope is None {
      return (true, Some(def))
    }
    let condition = eval_if_condition(shader_defs, def, operator, value, offset)
    guard scope is Some(scope_state) else { abort("unreachable missing scope") }
    scope_state.branch(false, condition, offset)
    return (true, Some(def))
  }
  if wgsl_directive_prefix_tail(line, WgslDirectiveKind::Else) is Some(_) {
    if scope is Some(scope_state) {
      scope_state.branch(true, true, offset)
    }
    return (true, None)
  }
  if wgsl_directive_prefix_tail(line, WgslDirectiveKind::Endif) is Some(_) {
    if scope is Some(scope_state) {
      scope_state.pop(offset)
    }
    return (true, None)
  }
  (false, None)
}

///|
fn replace_shader_defs_in_line(
  line : String,
  shader_defs : @hashmap.HashMap[String, ShaderDefValue],
) -> String {
  let mut output = ""
  let mut copy_start = 0
  for reference in parse_shader_def_references(line) {
    if shader_defs.get(reference.name) is Some(value) {
      output = output + line[copy_start:reference.start].to_owned()
      output = output + value.value_as_string()
      copy_start = reference.end
    }
  }
  if copy_start < line.length() {
    output = output + line[copy_start:line.length()].to_owned()
  }
  output
}

///|
