///|
pub fn apply_wgsl_template_consts(
  source : String,
  value_defines : @hashmap.HashMap[String, Int],
) -> String {
  let mut out = ""
  let mut copy_start = 0
  for reference in parse_wgsl_template_const_references(source, value_defines) {
    if value_defines.get(reference.name) is Some(value) {
      out = out + source[copy_start:reference.start].to_owned()
      out = out + value.to_string()
      copy_start = reference.end
    }
  }
  if copy_start < source.length() {
    out = out + source[copy_start:source.length()].to_owned()
  }
  out
}

///|
fn apply_ifdefs_strip_line_comment(text : String) -> String {
  for part in text.split("//") {
    return part.to_owned()
  }
  text
}

///|
fn apply_ifdefs_clean_directive_tail(text : String) -> String {
  apply_ifdefs_strip_line_comment(text).trim().to_owned()
}

///|
fn apply_ifdefs_parse_uint_literal(text : String) -> Int? {
  let mut token = apply_ifdefs_strip_line_comment(text).trim().to_owned()
  if token == "" {
    return None
  }
  if token.has_suffix("u") || token.has_suffix("U") {
    token = token[:token.length() - 1].to_owned().trim().to_owned()
  }
  if token == "" {
    return None
  }
  let parsed = @string.parse_int(token[:], base=10) catch { _ => return None }
  Some(parsed)
}

///|
fn apply_ifdefs_split_once(text : String, sep : String) -> (String, String)? {
  match text.find(sep) {
    Some(index) =>
      Some(
        (
          text[:index].to_owned(),
          text[index + sep.length():text.length()].to_owned(),
        ),
      )
    None => None
  }
}

///|
fn apply_ifdefs_define_value(
  defines : @hashmap.HashMap[String, Bool],
  value_defines : @hashmap.HashMap[String, Int],
  name : String,
) -> Int {
  if value_defines.get(name) is Some(value) {
    return value
  }
  if defines.get(name) is Some(flag) && flag {
    return 1
  }
  0
}

///|
fn apply_ifdefs_define_enabled(
  defines : @hashmap.HashMap[String, Bool],
  value_defines : @hashmap.HashMap[String, Int],
  name : String,
) -> Bool {
  if value_defines.contains(name) {
    return true
  }
  defines.contains(name)
}

///|
fn apply_ifdefs_parent_active(active_stack : Array[Bool]) -> Bool {
  if active_stack.length() >= 2 {
    active_stack[active_stack.length() - 2]
  } else {
    true
  }
}

///|
fn apply_ifdefs_tail_has_ascii_space(tail : String) -> Bool {
  match tokenize(tail, true) {
    [Token::Whitespace(_, 0), ..] => true
    _ => false
  }
}

///|
fn apply_ifdefs_expr_value(
  token : String,
  defines : @hashmap.HashMap[String, Bool],
  value_defines : @hashmap.HashMap[String, Int],
) -> Int {
  let text = apply_ifdefs_strip_line_comment(token).trim().to_owned()
  if text == "" {
    return 0
  }
  if text == "true" {
    return 1
  }
  if text == "false" {
    return 0
  }
  if apply_ifdefs_parse_uint_literal(text) is Some(value) {
    return value
  }
  apply_ifdefs_define_value(defines, value_defines, text)
}

///|
fn apply_ifdefs_eval_expr(
  expr : String,
  defines : @hashmap.HashMap[String, Bool],
  value_defines : @hashmap.HashMap[String, Int],
) -> Bool {
  let text = apply_ifdefs_strip_line_comment(expr).trim().to_owned()
  if text == "" {
    return false
  }
  if apply_ifdefs_split_once(text, ">=") is Some((lhs, rhs)) {
    return apply_ifdefs_expr_value(lhs, defines, value_defines) >=
      apply_ifdefs_expr_value(rhs, defines, value_defines)
  }
  if apply_ifdefs_split_once(text, "<=") is Some((lhs, rhs)) {
    return apply_ifdefs_expr_value(lhs, defines, value_defines) <=
      apply_ifdefs_expr_value(rhs, defines, value_defines)
  }
  if apply_ifdefs_split_once(text, "==") is Some((lhs, rhs)) {
    return apply_ifdefs_expr_value(lhs, defines, value_defines) ==
      apply_ifdefs_expr_value(rhs, defines, value_defines)
  }
  if apply_ifdefs_split_once(text, "!=") is Some((lhs, rhs)) {
    return apply_ifdefs_expr_value(lhs, defines, value_defines) !=
      apply_ifdefs_expr_value(rhs, defines, value_defines)
  }
  if apply_ifdefs_split_once(text, ">") is Some((lhs, rhs)) {
    return apply_ifdefs_expr_value(lhs, defines, value_defines) >
      apply_ifdefs_expr_value(rhs, defines, value_defines)
  }
  if apply_ifdefs_split_once(text, "<") is Some((lhs, rhs)) {
    return apply_ifdefs_expr_value(lhs, defines, value_defines) <
      apply_ifdefs_expr_value(rhs, defines, value_defines)
  }
  apply_ifdefs_expr_value(text, defines, value_defines) != 0
}

///|
pub fn apply_wgsl_ifdefs(
  source : String,
  defines : @hashmap.HashMap[String, Bool],
  value_defines : @hashmap.HashMap[String, Int],
) -> String {
  let mut out = ""
  let active_stack : Array[Bool] = [true]
  let branch_taken_stack : Array[Bool] = []
  for line in source_lines(source) {
    let trimmed = line.trim().to_owned()
    if wgsl_directive_tail(trimmed, WgslDirectiveKind::Ifdef) is Some(tail) {
      let name = apply_ifdefs_clean_directive_tail(tail)
      let cond = apply_ifdefs_define_enabled(defines, value_defines, name)
      let parent = active_stack[active_stack.length() - 1]
      active_stack.push(parent && cond)
      branch_taken_stack.push(cond)
      continue
    }
    if wgsl_directive_tail(trimmed, WgslDirectiveKind::Ifndef) is Some(tail) {
      let name = apply_ifdefs_clean_directive_tail(tail)
      let cond = !apply_ifdefs_define_enabled(defines, value_defines, name)
      let parent = active_stack[active_stack.length() - 1]
      active_stack.push(parent && cond)
      branch_taken_stack.push(cond)
      continue
    }
    if wgsl_directive_tail(trimmed, WgslDirectiveKind::If) is Some(tail) {
      let expr = apply_ifdefs_clean_directive_tail(tail)
      let cond = apply_ifdefs_eval_expr(expr, defines, value_defines)
      let parent = active_stack[active_stack.length() - 1]
      active_stack.push(parent && cond)
      branch_taken_stack.push(cond)
      continue
    }
    if wgsl_directive_prefix_tail(trimmed, WgslDirectiveKind::Else)
      is Some(else_tail) &&
      apply_ifdefs_tail_has_ascii_space(else_tail) &&
      word_tail(else_tail, "ifdef") is Some(tail) {
      if branch_taken_stack.length() > 0 {
        let idx = branch_taken_stack.length() - 1
        let name = apply_ifdefs_clean_directive_tail(tail)
        let cond = !branch_taken_stack[idx] &&
          apply_ifdefs_define_enabled(defines, value_defines, name)
        let parent = apply_ifdefs_parent_active(active_stack)
        active_stack[active_stack.length() - 1] = parent && cond
        branch_taken_stack[idx] = branch_taken_stack[idx] || cond
      }
      continue
    }
    if wgsl_directive_prefix_tail(trimmed, WgslDirectiveKind::Else)
      is Some(else_tail) &&
      apply_ifdefs_tail_has_ascii_space(else_tail) &&
      word_tail(else_tail, "ifndef") is Some(tail) {
      if branch_taken_stack.length() > 0 {
        let idx = branch_taken_stack.length() - 1
        let name = apply_ifdefs_clean_directive_tail(tail)
        let cond = !branch_taken_stack[idx] &&
          !apply_ifdefs_define_enabled(defines, value_defines, name)
        let parent = apply_ifdefs_parent_active(active_stack)
        active_stack[active_stack.length() - 1] = parent && cond
        branch_taken_stack[idx] = branch_taken_stack[idx] || cond
      }
      continue
    }
    if wgsl_directive_prefix_tail(trimmed, WgslDirectiveKind::Else)
      is Some(else_tail) &&
      apply_ifdefs_tail_has_ascii_space(else_tail) &&
      word_tail(else_tail, "if") is Some(tail) {
      if branch_taken_stack.length() > 0 {
        let idx = branch_taken_stack.length() - 1
        let cond = !branch_taken_stack[idx] &&
          apply_ifdefs_eval_expr(tail, defines, value_defines)
        let parent = apply_ifdefs_parent_active(active_stack)
        active_stack[active_stack.length() - 1] = parent && cond
        branch_taken_stack[idx] = branch_taken_stack[idx] || cond
      }
      continue
    }
    if wgsl_directive_prefix_tail(trimmed, WgslDirectiveKind::Else) is Some(_) {
      if branch_taken_stack.length() > 0 {
        let idx = branch_taken_stack.length() - 1
        let cond = !branch_taken_stack[idx]
        let parent = apply_ifdefs_parent_active(active_stack)
        active_stack[active_stack.length() - 1] = parent && cond
        branch_taken_stack[idx] = branch_taken_stack[idx] || cond
      }
      continue
    }
    if wgsl_directive_prefix_tail(trimmed, WgslDirectiveKind::Endif) is Some(_) {
      if active_stack.length() > 1 {
        active_stack.pop() |> ignore
      }
      if branch_taken_stack.length() > 0 {
        branch_taken_stack.pop() |> ignore
      }
      continue
    }
    if active_stack[active_stack.length() - 1] {
      out = "\{out}\{line}\n"
    }
  }
  out
}

///|
pub fn apply_wgsl_ifdefs_strict(
  source : String,
  shader_defs : @hashmap.HashMap[String, ShaderDefValue],
) -> String raise PreprocessError {
  let mut out = ""
  let scope = Scope::new()
  let original_lines : Array[String] = []
  let decommented_lines : Array[String] = []
  for line in source_lines(source) {
    original_lines.push(line)
  }
  for line in source_lines(replace_comments(source)) {
    decommented_lines.push(line)
  }
  let mut offset = 0
  let mut line_index = 0
  while line_index < decommented_lines.length() {
    let line = decommented_lines[line_index]
    let original_line = if line_index < original_lines.length() {
      original_lines[line_index]
    } else {
      line
    }
    let (is_scope, _) = check_scope(shader_defs, line, Some(scope), offset)
    if !is_scope && scope.active() {
      out = "\{out}\{original_line}\n"
    }
    offset = offset + original_line.length() + 1
    line_index = line_index + 1
  }
  scope.finish(offset)
  out
}

///|
pub fn active_wgsl_ifdef_line_flags_strict(
  source : String,
  shader_defs : @hashmap.HashMap[String, ShaderDefValue],
) -> Array[Bool] raise PreprocessError {
  let scope = Scope::new()
  let flags : Array[Bool] = []
  let mut offset = 0
  for line in source_lines(replace_comments(source)) {
    let (is_scope, _) = check_scope(shader_defs, line, Some(scope), offset)
    flags.push(!is_scope && scope.active())
    offset = offset + line.length() + 1
  }
  scope.finish(offset)
  flags
}
