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
  let mut i = 0
  while i < text.length() {
    let code = text.code_unit_at(i).to_int()
    if code == 32 || code == 9 {
      i = i + 1
      continue
    }
    break
  }
  let def_start = i
  while i < text.length() {
    let code = text.code_unit_at(i).to_int()
    if code == 124 ||
      code == 95 ||
      code > 127 ||
      (code >= 48 && code <= 57) ||
      (code >= 65 && code <= 90) ||
      (code >= 97 && code <= 122) {
      i = i + 1
      continue
    }
    break
  }
  guard i > def_start else { return None }
  let def = text[def_start:i].to_owned()
  while i < text.length() {
    let code = text.code_unit_at(i).to_int()
    if code == 32 || code == 9 {
      i = i + 1
      continue
    }
    break
  }
  let operator_start = i
  while i < text.length() {
    let code = text.code_unit_at(i).to_int()
    if code == 61 || code == 33 || code == 60 || code == 62 {
      i = i + 1
      continue
    }
    break
  }
  let operator = text[operator_start:i].to_owned()
  while i < text.length() {
    let code = text.code_unit_at(i).to_int()
    if code == 32 || code == 9 {
      i = i + 1
      continue
    }
    break
  }
  let value_start = i
  while i < text.length() {
    let code = text.code_unit_at(i).to_int()
    if code == 45 ||
      code == 124 ||
      code == 95 ||
      code > 127 ||
      (code >= 48 && code <= 57) ||
      (code >= 65 && code <= 90) ||
      (code >= 97 && code <= 122) {
      i = i + 1
      continue
    }
    break
  }
  if i == value_start {
    None
  } else {
    let value = text[value_start:i].to_owned()
    Some((def, operator, value))
  }
}

///|
fn check_if_operator_scope(
  shader_defs : @hashmap.HashMap[String, ShaderDefValue],
  expression : String,
  scope : Scope?,
  offset : Int,
  is_else : Bool,
) -> (Bool, String?) raise PreprocessError {
  guard parse_if_operator_expression(expression) is Some((def, operator, value)) else {
    return (false, None)
  }
  if scope is None {
    return (true, Some(def))
  }
  let condition = eval_if_condition(shader_defs, def, operator, value, offset)
  guard scope is Some(scope_state) else { abort("unreachable missing scope") }
  scope_state.branch(is_else, condition, offset)
  (true, Some(def))
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
      let (is_scope, def) = check_if_operator_scope(
        shader_defs, expr, scope, offset, true,
      )
      if is_scope {
        return (true, def)
      }
    }
  }
  if wgsl_directive_tail(line, WgslDirectiveKind::If) is Some(expr) {
    let (is_scope, def) = check_if_operator_scope(
      shader_defs, expr, scope, offset, false,
    )
    if is_scope {
      return (true, def)
    }
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
