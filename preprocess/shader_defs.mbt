///|

///|
fn parse_bool_text(text : String) -> Bool? {
  let trimmed = trim_trailing_semicolons(text)
  if trimmed == "true" {
    return Some(true)
  }
  if trimmed == "false" {
    return Some(false)
  }
  None
}

///|
fn check_if_operator_scope(
  shader_defs : @hashmap.HashMap[String, ShaderDefValue],
  expression : String,
  scope : Scope?,
  offset : Int,
  is_else : Bool,
) -> (Bool, String?) raise PreprocessError {
  guard parse_wgsl_shader_def_comparison(expression) is Some(comparison) else {
    return (false, None)
  }
  let def = comparison.def_name()
  if scope is None {
    return (true, Some(def))
  }
  let condition = eval_if_condition(
    shader_defs,
    def,
    comparison.operator(),
    comparison.value_text(),
    offset,
  )
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
      let parsed = @string.parse_uint(value[:], base=10) catch {
        _ =>
          raise PreprocessError::InvalidShaderDefComparisonValue(
            def, value, "uint", offset,
          )
      }
      compare_uint_values(uint_value, parsed, operator, offset)
    }
  }
}

///|
fn replace_shader_defs_in_line(
  line : String,
  shader_defs : @hashmap.HashMap[String, ShaderDefValue],
) -> String {
  let references = parse_wgsl_shader_def_references(line)
  let mut output = line
  for reference in references {
    if !reference.is_delimited() &&
      shader_defs.get(reference.name()) is Some(value) {
      output = replace_first_shader_def_reference(
        output,
        false,
        value.value_as_string(),
      )
    }
  }
  for reference in references {
    if reference.is_delimited() &&
      shader_defs.get(reference.name()) is Some(value) {
      output = replace_first_shader_def_reference(
        output,
        true,
        value.value_as_string(),
      )
    }
  }
  output
}

///|
fn replace_first_shader_def_reference(
  line : String,
  delimited : Bool,
  replacement : String,
) -> String {
  for reference in parse_wgsl_shader_def_references(line) {
    if reference.is_delimited() == delimited {
      return line[0:reference.start()].to_owned() +
        replacement +
        line[reference.end():line.length()].to_owned()
    }
  }
  line
}

///|
