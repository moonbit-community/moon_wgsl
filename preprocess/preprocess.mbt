// Copyright 2026 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
pub struct Preprocessor {}

///|
pub fn Preprocessor::default() -> Preprocessor {
  Preprocessor::{  }
}

///|
pub(all) suberror PreprocessError {
  GlslInvalidVersion(Int)
  ElseWithoutCondition(Int)
  TooManyEndIfs(Int)
  NotEnoughEndIfs(Int)
  UnknownShaderDef(String, Int)
  UnknownShaderDefOperator(String, Int)
  InvalidShaderDefComparisonValue(String, String, String, Int)
  InvalidWgslDirective(String, Int, String)
  ImportParseError(String, Int)
  DefineInModule(Int)
}

///|
enum ScopeLevel {
  Active
  PreviouslyActive
  NotActive
} derive(Eq)

///|
priv struct Scope {
  levels : Array[ScopeLevel]
}

///|
priv struct ShaderDefReference {
  name : String
  start : Int
  end : Int
}

///|
priv struct WgslTemplateConstReference {
  name : String
  start : Int
  end : Int
}

///|
fn Scope::new() -> Scope {
  Scope::{ levels: [ScopeLevel::Active] }
}

///|
fn Scope::branch(
  self : Scope,
  is_else : Bool,
  condition : Bool,
  offset : Int,
) -> Unit raise PreprocessError {
  if is_else {
    let previous_scope = self.levels.pop()
    guard previous_scope is Some(previous) else {
      raise PreprocessError::ElseWithoutCondition(offset)
    }
    guard self.levels.length() > 0 else {
      raise PreprocessError::ElseWithoutCondition(offset)
    }
    let parent_scope = self.levels[self.levels.length() - 1]
    let new_scope = if parent_scope != ScopeLevel::Active {
      ScopeLevel::NotActive
    } else if previous != ScopeLevel::NotActive {
      ScopeLevel::PreviouslyActive
    } else if condition {
      ScopeLevel::Active
    } else {
      ScopeLevel::NotActive
    }
    self.levels.push(new_scope)
    return ()
  }
  let parent_scope = if self.levels.is_empty() {
    ScopeLevel::Active
  } else {
    self.levels[self.levels.length() - 1]
  }
  let new_scope = if parent_scope == ScopeLevel::Active && condition {
    ScopeLevel::Active
  } else {
    ScopeLevel::NotActive
  }
  self.levels.push(new_scope)
  ()
}

///|
fn Scope::pop(self : Scope, offset : Int) -> Unit raise PreprocessError {
  self.levels.pop() |> ignore
  if self.levels.is_empty() {
    raise PreprocessError::TooManyEndIfs(offset)
  } else {
    ()
  }
}

///|
fn Scope::active(self : Scope) -> Bool {
  self.levels[self.levels.length() - 1] == ScopeLevel::Active
}

///|
fn Scope::finish(self : Scope, offset : Int) -> Unit raise PreprocessError {
  if self.levels.length() != 1 {
    raise PreprocessError::NotEnoughEndIfs(offset)
  } else {
    ()
  }
}

///|
fn split_extensions(raw : String) -> Array[String] {
  let extensions : Array[String] = []
  for token in tokenize(raw, false) {
    match token {
      Token::Identifier(text, _) => extensions.push(text)
      _ => ()
    }
  }
  extensions
}

///|
fn shader_def_name_token_text(token : Token) -> String? {
  match token {
    Token::Identifier(text, _) => Some(text)
    Token::Other(124, _) => Some("|")
    Token::Other(code, _) if code >= 48 && code <= 57 =>
      Some(code_unit_to_string(code))
    _ => None
  }
}

///|
fn shader_def_value_token_text(token : Token) -> String? {
  match token {
    Token::Identifier(text, _) => Some(text)
    Token::Other(124, _) | Token::Other(45, _) =>
      Some(preprocess_token_text(token))
    Token::Other(code, _) if (code >= 48 && code <= 57) ||
      (code >= 65 && code <= 90) ||
      (code >= 97 && code <= 122) => Some(code_unit_to_string(code))
    _ => None
  }
}

///|
fn token_end(token : Token) -> Int {
  token.pos() + preprocess_token_text(token).length()
}

///|
fn parse_shader_def_references(line : String) -> Array[ShaderDefReference] {
  let references : Array[ShaderDefReference] = []
  let tokens = tokenize(line, true)
  let mut i = 0
  while i < tokens.length() {
    guard tokens[i] is Token::Other(35, start) else {
      i = i + 1
      continue
    }
    let mut j = i + 1
    while j < tokens.length() {
      match tokens[j] {
        Token::Whitespace(_, _) => j = j + 1
        _ => break
      }
    }
    guard j < tokens.length() else {
      i = i + 1
      continue
    }
    match tokens[j] {
      Token::Other(123, _) => {
        let body_start = token_end(tokens[j])
        let mut k = j + 1
        while k < tokens.length() {
          match tokens[k] {
            Token::Other(125, _) => break
            _ => k = k + 1
          }
        }
        if k < tokens.length() {
          let name = line[body_start:tokens[k].pos()]
            .to_owned()
            .trim()
            .to_owned()
          if name != "" {
            references.push(ShaderDefReference::{
              name,
              start,
              end: token_end(tokens[k]),
            })
          }
          i = k + 1
        } else {
          i = i + 1
        }
      }
      _ => {
        let name_start = tokens[j].pos()
        let mut name = ""
        while j < tokens.length() {
          match shader_def_name_token_text(tokens[j]) {
            Some(text) => {
              name = name + text
              j = j + 1
            }
            None => break
          }
        }
        if name != "" {
          references.push(ShaderDefReference::{
            name,
            start,
            end: if j > 0 {
              token_end(tokens[j - 1])
            } else {
              name_start
            },
          })
          i = j
        } else {
          i = i + 1
        }
      }
    }
  }
  references
}

///|
fn wgsl_template_const_name_boundary(text : String, name : String) -> Bool {
  if text.length() == name.length() {
    return true
  }
  if text.length() < name.length() {
    return false
  }
  let tail = text[name.length():text.length()].to_owned()
  for prefix in ["_", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"] {
    if tail.has_prefix(prefix) {
      return false
    }
  }
  for
    prefix in [
      "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O",
      "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
    ] {
    if tail.has_prefix(prefix) {
      return false
    }
  }
  true
}

///|
fn longest_wgsl_template_const_prefix(
  text : String,
  value_defines : @hashmap.HashMap[String, Int],
) -> String? {
  let mut best = ""
  for entry in value_defines.iter() {
    let (name, _) = entry
    if name.length() > best.length() &&
      starts_with_text(text, name) &&
      wgsl_template_const_name_boundary(text, name) {
      best = name
    }
  }
  if best == "" {
    None
  } else {
    Some(best)
  }
}

///|
fn parse_wgsl_template_const_references(
  source : String,
  value_defines : @hashmap.HashMap[String, Int],
) -> Array[WgslTemplateConstReference] {
  let references : Array[WgslTemplateConstReference] = []
  let tokens = tokenize(source, true)
  let mut i = 0
  while i < tokens.length() {
    guard tokens[i] is Token::Other(35, start) else {
      i = i + 1
      continue
    }
    guard i + 1 < tokens.length() else {
      i = i + 1
      continue
    }
    match tokens[i + 1] {
      Token::Other(123, _) => {
        let body_start = token_end(tokens[i + 1])
        let mut j = i + 2
        while j < tokens.length() {
          match tokens[j] {
            Token::Other(125, _) => break
            _ => j = j + 1
          }
        }
        if j < tokens.length() {
          let name = source[body_start:tokens[j].pos()]
            .to_owned()
            .trim()
            .to_owned()
          references.push(WgslTemplateConstReference::{
            name,
            start,
            end: token_end(tokens[j]),
          })
          i = j + 1
        } else {
          i = i + 1
        }
      }
      Token::Identifier(text, pos) =>
        match longest_wgsl_template_const_prefix(text, value_defines) {
          Some(name) => {
            references.push(WgslTemplateConstReference::{
              name,
              start,
              end: pos + name.length(),
            })
            i = i + 2
          }
          None => i = i + 1
        }
      _ => i = i + 1
    }
  }
  references
}

///|
fn collect_effective_def_names(
  line : String,
  effective_defs : @hashset.HashSet[String],
) -> Unit {
  for reference in parse_shader_def_references(line) {
    effective_defs.add(reference.name)
  }
}

///|
fn parse_define_value(raw_value : String) -> ShaderDefValue {
  let value = trim_trailing_semicolons(raw_value)
  if value == "" {
    return ShaderDefValue::Bool(true)
  }
  if value == "true" {
    return ShaderDefValue::Bool(true)
  }
  if value == "false" {
    return ShaderDefValue::Bool(false)
  }
  let parsed_unsigned = @string.parse_int(value[:], base=10) catch { _ => -1 }
  if parsed_unsigned >= 0 {
    return ShaderDefValue::UInt(parsed_unsigned.reinterpret_as_uint())
  }
  let parsed = @string.parse_int(value[:], base=10) catch {
    _ => return ShaderDefValue::Bool(false)
  }
  ShaderDefValue::Int(parsed)
}

///|
fn split_define_name_and_value(text : String) -> (String, String) {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return ("", "")
  }
  let tokens = tokenize(trimmed, true)
  let mut i = 0
  let mut name = ""
  while i < tokens.length() {
    match shader_def_name_token_text(tokens[i]) {
      Some(text) => {
        name = name + text
        i = i + 1
      }
      None => break
    }
  }
  if name == "" {
    return ("", "")
  }
  while i < tokens.length() {
    match tokens[i] {
      Token::Whitespace(_, _) => i = i + 1
      _ => break
    }
  }
  let mut value = ""
  while i < tokens.length() {
    match shader_def_value_token_text(tokens[i]) {
      Some(text) => value = value + text
      None => break
    }
    i = i + 1
  }
  (name, value)
}

///|
fn first_space_separated_token(text : String) -> String {
  let trimmed = text.trim().to_owned()
  let tokens = tokenize(trimmed, true)
  let mut output = ""
  for token in tokens {
    match token {
      Token::Whitespace(_, _) => break
      _ => output = output + preprocess_token_text(token)
    }
  }
  output
}

///|
fn starts_with_tokenized_space(text : String) -> Bool {
  match tokenize(text, true) {
    [Token::Whitespace(_, 0), ..] => true
    _ => false
  }
}

///|
fn parse_glsl_version_directive(line : String) -> String? {
  let trimmed = line.trim().to_owned()
  let tokens = tokenize(trimmed, false)
  match tokens {
    [Token::Other(35, 0), Token::Identifier("version", _), ..] => ()
    _ => return None
  }
  guard tokens.length() > 2 else { return None }
  let start = tokens[2].pos()
  let mut end = start
  let mut i = 2
  while i < tokens.length() {
    match tokens[i] {
      Token::Other(code, pos) if code >= 48 && code <= 57 && pos == end => {
        end = end + 1
        i = i + 1
      }
      _ => break
    }
  }
  if end > start {
    Some(trimmed[start:end].to_owned())
  } else {
    None
  }
}

///|
fn semicolon_directive_body(line : String, keyword : String) -> String? {
  let trimmed = line.trim().to_owned()
  let tokens = tokenize(trimmed, false)
  match tokens {
    [Token::Identifier(actual, start), ..] if actual == keyword && start == 0 => {
      let body_start = keyword.length()
      for token in tokens {
        match token {
          Token::Other(59, semicolon_pos) =>
            if semicolon_pos > body_start {
              return Some(
                trimmed[body_start:semicolon_pos].to_owned().trim().to_owned(),
              )
            } else {
              return None
            }
          _ => ()
        }
      }
      None
    }
    _ => None
  }
}

///|
fn parse_diagnostic_directive_body(line : String) -> (String, String)? {
  match tokenize(line.trim().to_owned(), false) {
    [
      Token::Identifier("diagnostic", 0),
      Token::Other(40, _),
      Token::Identifier(severity, _),
      Token::Other(44, _),
      Token::Identifier(rule, _),
      Token::Other(41, _),
      Token::Other(59, _),
      ..,
    ] => Some((severity, rule))
    _ => None
  }
}

///|
fn wgsl_source_directive_keyword(line : String) -> String? {
  match tokenize(line.trim().to_owned(), false) {
    [Token::Identifier(keyword, _), ..] => Some(keyword)
    _ => None
  }
}

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
fn directive_identifier(text : String) -> String? {
  let trimmed = trim_trailing_semicolons(text)
  let tokens = tokenize(trimmed, false)
  let mut out = ""
  let mut expect_identifier = true
  for token in tokens {
    match token {
      Token::Identifier(ident, _) if expect_identifier => {
        out = out + ident
        expect_identifier = false
      }
      Token::Other(124, _) if !expect_identifier => {
        out = out + "|"
        expect_identifier = true
      }
      _ => break
    }
  }
  if out == "" || expect_identifier {
    None
  } else {
    Some(out)
  }
}

///|
fn preprocess_token_text(token : Token) -> String {
  match token {
    Token::Identifier(text, _) => text
    Token::Whitespace(text, _) => text
    Token::Other(code, _) => code_unit_to_string(code)
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
      Token::Identifier(ident, _) => def = def + ident
      Token::Other(124, _) => def = def + "|"
      _ => break
    }
    i = i + 1
  }
  guard def != "" else { return None }
  let mut operator = ""
  while i < tokens.length() {
    match tokens[i] {
      Token::Other(code, _) if code == 61 ||
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
    if else_tail_has_space &&
      word_tail(else_tail, "if") is Some(expr) &&
      parse_if_operator_expression(expr) is Some((def, operator, value)) {
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
  if wgsl_directive_tail(line, WgslDirectiveKind::If) is Some(expr) &&
    parse_if_operator_expression(expr) is Some((def, operator, value)) {
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
fn strict_shader_def_enabled(
  shader_defs : @hashmap.HashMap[String, ShaderDefValue],
  name : String,
) -> Bool {
  shader_defs.contains(name)
}

///|
pub fn apply_wgsl_ifdefs_strict(
  source : String,
  shader_defs : @hashmap.HashMap[String, ShaderDefValue],
) -> String raise PreprocessError {
  let mut out = ""
  let active_stack : Array[Bool] = [true]
  let branch_taken_stack : Array[Bool] = []
  let mut offset = 0
  for line in source_lines(source) {
    let trimmed = line.trim().to_owned()
    if wgsl_directive_tail(trimmed, WgslDirectiveKind::Ifdef) is Some(tail) {
      let name = apply_ifdefs_clean_directive_tail(tail)
      let cond = strict_shader_def_enabled(shader_defs, name)
      let parent = active_stack[active_stack.length() - 1]
      active_stack.push(parent && cond)
      branch_taken_stack.push(cond)
      offset = offset + line.length() + 1
      continue
    }
    if wgsl_directive_tail(trimmed, WgslDirectiveKind::Ifndef) is Some(tail) {
      let name = apply_ifdefs_clean_directive_tail(tail)
      let cond = !strict_shader_def_enabled(shader_defs, name)
      let parent = active_stack[active_stack.length() - 1]
      active_stack.push(parent && cond)
      branch_taken_stack.push(cond)
      offset = offset + line.length() + 1
      continue
    }
    if wgsl_directive_tail(trimmed, WgslDirectiveKind::If) is Some(tail) {
      let expr = apply_ifdefs_clean_directive_tail(tail)
      guard parse_if_operator_expression(expr) is Some((def, operator, value)) else {
        raise PreprocessError::UnknownShaderDefOperator("", offset)
      }
      let cond = eval_if_condition(shader_defs, def, operator, value, offset)
      let parent = active_stack[active_stack.length() - 1]
      active_stack.push(parent && cond)
      branch_taken_stack.push(cond)
      offset = offset + line.length() + 1
      continue
    }
    if wgsl_directive_prefix_tail(trimmed, WgslDirectiveKind::Else)
      is Some(else_tail) &&
      apply_ifdefs_tail_has_ascii_space(else_tail) &&
      word_tail(else_tail, "ifdef") is Some(tail) {
      if branch_taken_stack.length() == 0 {
        raise PreprocessError::ElseWithoutCondition(offset)
      }
      let idx = branch_taken_stack.length() - 1
      let name = apply_ifdefs_clean_directive_tail(tail)
      let cond = !branch_taken_stack[idx] &&
        strict_shader_def_enabled(shader_defs, name)
      let parent = apply_ifdefs_parent_active(active_stack)
      active_stack[active_stack.length() - 1] = parent && cond
      branch_taken_stack[idx] = branch_taken_stack[idx] || cond
      offset = offset + line.length() + 1
      continue
    }
    if wgsl_directive_prefix_tail(trimmed, WgslDirectiveKind::Else)
      is Some(else_tail) &&
      apply_ifdefs_tail_has_ascii_space(else_tail) &&
      word_tail(else_tail, "ifndef") is Some(tail) {
      if branch_taken_stack.length() == 0 {
        raise PreprocessError::ElseWithoutCondition(offset)
      }
      let idx = branch_taken_stack.length() - 1
      let name = apply_ifdefs_clean_directive_tail(tail)
      let cond = !branch_taken_stack[idx] &&
        !strict_shader_def_enabled(shader_defs, name)
      let parent = apply_ifdefs_parent_active(active_stack)
      active_stack[active_stack.length() - 1] = parent && cond
      branch_taken_stack[idx] = branch_taken_stack[idx] || cond
      offset = offset + line.length() + 1
      continue
    }
    if wgsl_directive_prefix_tail(trimmed, WgslDirectiveKind::Else)
      is Some(else_tail) &&
      apply_ifdefs_tail_has_ascii_space(else_tail) &&
      word_tail(else_tail, "if") is Some(tail) {
      if branch_taken_stack.length() == 0 {
        raise PreprocessError::ElseWithoutCondition(offset)
      }
      let idx = branch_taken_stack.length() - 1
      guard parse_if_operator_expression(tail) is Some((def, operator, value)) else {
        raise PreprocessError::UnknownShaderDefOperator("", offset)
      }
      let cond = !branch_taken_stack[idx] &&
        eval_if_condition(shader_defs, def, operator, value, offset)
      let parent = apply_ifdefs_parent_active(active_stack)
      active_stack[active_stack.length() - 1] = parent && cond
      branch_taken_stack[idx] = branch_taken_stack[idx] || cond
      offset = offset + line.length() + 1
      continue
    }
    if wgsl_directive_prefix_tail(trimmed, WgslDirectiveKind::Else) is Some(_) {
      if branch_taken_stack.length() == 0 {
        raise PreprocessError::ElseWithoutCondition(offset)
      }
      let idx = branch_taken_stack.length() - 1
      let cond = !branch_taken_stack[idx]
      let parent = apply_ifdefs_parent_active(active_stack)
      active_stack[active_stack.length() - 1] = parent && cond
      branch_taken_stack[idx] = branch_taken_stack[idx] || cond
      offset = offset + line.length() + 1
      continue
    }
    if wgsl_directive_prefix_tail(trimmed, WgslDirectiveKind::Endif) is Some(_) {
      if active_stack.length() <= 1 {
        raise PreprocessError::TooManyEndIfs(offset)
      }
      active_stack.pop() |> ignore
      if branch_taken_stack.length() > 0 {
        branch_taken_stack.pop() |> ignore
      }
      offset = offset + line.length() + 1
      continue
    }
    if active_stack[active_stack.length() - 1] {
      out = "\{out}\{line}\n"
    }
    offset = offset + line.length() + 1
  }
  if active_stack.length() != 1 {
    raise PreprocessError::NotEnoughEndIfs(offset)
  }
  out
}

///|
pub fn Preprocessor::extract_wgsl_directives(
  _self : Preprocessor,
  source : String,
) -> (String, WgslDirectives) raise PreprocessError {
  let directives = WgslDirectives::default()
  let cleaned_lines : Array[String] = []
  let mut in_directive_section = true
  let mut line_index = 0
  for line in source_lines(source) {
    let trimmed = line.trim().to_owned()

    if trimmed == "" || replace_comments(trimmed).trim().to_owned() == "" {
      cleaned_lines.push(line)
      line_index = line_index + 1
      continue
    }

    if in_directive_section {
      if semicolon_directive_body(trimmed, "enable") is Some(body) {
        let extensions = split_extensions(body)
        if extensions.is_empty() {
          raise PreprocessError::InvalidWgslDirective(
            trimmed, line_index, "No extensions specified",
          )
        }
        cleaned_lines.push("")
        directives.enables.push(EnableDirective::{
          extensions,
          source_location: line_index,
        })
        line_index = line_index + 1
        continue
      }
      if semicolon_directive_body(trimmed, "requires") is Some(body) {
        let extensions = split_extensions(body)
        if extensions.is_empty() {
          raise PreprocessError::InvalidWgslDirective(
            trimmed, line_index, "No extensions specified",
          )
        }
        cleaned_lines.push("")
        directives.requires.push(RequiresDirective::{
          extensions,
          source_location: line_index,
        })
        line_index = line_index + 1
        continue
      }
      if parse_diagnostic_directive_body(trimmed) is Some((severity, rule)) {
        if severity != "off" &&
          severity != "info" &&
          severity != "warn" &&
          severity != "error" {
          raise PreprocessError::InvalidWgslDirective(
            trimmed,
            line_index,
            "Invalid severity '\{severity}'. Must be one of: off, info, warn, error",
          )
        }
        cleaned_lines.push("")
        directives.diagnostics.push(DiagnosticDirective::{
          severity,
          rule,
          source_location: line_index,
        })
        line_index = line_index + 1
        continue
      }
      match wgsl_source_directive_keyword(trimmed) {
        Some("enable") | Some("requires") | Some("diagnostic") => ()
        _ => in_directive_section = false
      }
    }

    cleaned_lines.push(line)
    line_index = line_index + 1
  }

  let mut cleaned_source = ""
  for i in 0..<cleaned_lines.length() {
    if i > 0 {
      cleaned_source = "\{cleaned_source}\n"
    }
    cleaned_source = cleaned_source + cleaned_lines[i]
  }

  (cleaned_source, directives)
}

///|
pub fn Preprocessor::preprocess(
  _self : Preprocessor,
  source : String,
  shader_defs : @hashmap.HashMap[String, ShaderDefValue],
) -> PreprocessOutput raise PreprocessError {
  let declared_imports : Array[DeclaredImportBinding] = []
  let used_imports : Array[ImportDefWithOffset] = []
  let scope = Scope::new()
  let original_lines : Array[String] = []
  let decommented_lines : Array[String] = []
  for line_item in source_lines(source) {
    original_lines.push(line_item)
  }
  for line_item in source_lines(replace_comments(source)) {
    decommented_lines.push(line_item)
  }

  let mut final_string = ""
  let mut offset = 0
  let mut line_index = 0
  while line_index < decommented_lines.length() {
    let mut line = decommented_lines[line_index]
    let original_line = original_lines[line_index]
    let mut output = false
    let trimmed = line.trim().to_owned()

    if parse_glsl_version_directive(trimmed) is Some(version) {
      if version != "440" && version != "450" {
        raise PreprocessError::GlslInvalidVersion(offset)
      }
    } else {
      let (is_scope, _) = check_scope(shader_defs, line, Some(scope), offset)
      if is_scope ||
        wgsl_directive_tail(trimmed, WgslDirectiveKind::DefineImportPath)
        is Some(_) ||
        wgsl_directive_tail(trimmed, WgslDirectiveKind::Define) is Some(_) {
        ()
      } else if scope.active() {
        if wgsl_directive_tail(trimmed, WgslDirectiveKind::Import) is Some(_) {
          let mut import_lines = ""
          let mut open_count = 0
          let initial_offset = offset
          while true {
            final_string = final_string + spaces(line.length())
            offset = offset + line.length() + 1
            open_count = open_count + import_brace_balance(line)
            import_lines = "\{import_lines}\{line}\n"
            if open_count == 0 || line_index + 1 >= decommented_lines.length() {
              break
            }
            final_string = "\{final_string}\n"
            line_index = line_index + 1
            line = decommented_lines[line_index]
          }
          parse_imports(import_lines, declared_imports) catch {
            Parse(message, line_offset) =>
              raise PreprocessError::ImportParseError(
                message,
                initial_offset + line_offset,
              )
          }
          output = true
        } else {
          let replaced_original = replace_shader_defs_in_line(
            original_line, shader_defs,
          )
          let replaced_decommented = replace_shader_defs_in_line(
            line, shader_defs,
          )
          let ignored_imports : Array[ImportDefWithOffset] = []
          let item_replaced_line = substitute_identifiers(
            replaced_original, offset, declared_imports, ignored_imports, true,
          ) catch {
            AmbiguousImport(position) =>
              raise PreprocessError::ImportParseError(
                "Ambiguous import path for item", position,
              )
          }
          ignore(
            substitute_identifiers(
              replaced_decommented, offset, declared_imports, used_imports, false,
            ) catch {
              AmbiguousImport(position) =>
                raise PreprocessError::ImportParseError(
                  "Ambiguous import path for item", position,
                )
            },
          )
          final_string = "\{final_string}\{item_replaced_line}"
          let diff = line.length() - item_replaced_line.length()
          if diff > 0 {
            final_string = "\{final_string}\{spaces(diff)}"
          }
          offset = offset + original_line.length() + 1
          output = true
        }
      }
    }

    if !output {
      final_string = "\{final_string}\{spaces(line.length())}"
      offset = offset + line.length() + 1
    }
    final_string = "\{final_string}\n"
    line_index = line_index + 1
  }

  scope.finish(offset)
  PreprocessOutput::{ preprocessed_source: final_string, imports: used_imports }
}

///|
fn try_get_preprocessor_metadata(
  source : String,
  allow_defines : Bool,
) -> PreprocessorMetaData raise PreprocessError {
  let preprocessor = Preprocessor::default()
  let (cleaned_for_directives, wgsl_directives) = preprocessor.extract_wgsl_directives(
    source,
  )
  let stripped = replace_comments(cleaned_for_directives)

  let declared_imports : Array[DeclaredImportBinding] = []
  let used_imports : Array[ImportDefWithOffset] = []
  let defines : @hashmap.HashMap[String, ShaderDefValue] = @hashmap.HashMap::new()
  let effective_defs : @hashset.HashSet[String] = @hashset.HashSet::new()
  let lines : Array[String] = []
  let mut name : String? = None
  let mut offset = 0

  for line_item in source_lines(stripped) {
    lines.push(line_item)
  }

  let mut line_index = 0
  while line_index < lines.length() {
    let line = lines[line_index]
    let trimmed = line.trim().to_owned()
    let (is_scope, def) = check_scope(
      @hashmap.HashMap::new(),
      line,
      None,
      offset,
    )

    if is_scope {
      if def is Some(def_name) {
        effective_defs.add(def_name)
      }
    } else if wgsl_directive_tail(trimmed, WgslDirectiveKind::Import) is Some(_) {
      let mut import_lines = "\{line}\n"
      let mut open_count = import_brace_balance(line)
      let initial_offset = offset

      while open_count > 0 && line_index + 1 < lines.length() {
        line_index = line_index + 1
        let next_line = lines[line_index]
        import_lines = "\{import_lines}\{next_line}\n"
        open_count = open_count + import_brace_balance(next_line)
        offset = offset + next_line.length() + 1
      }

      parse_imports(import_lines, declared_imports) catch {
        Parse(message, line_offset) =>
          raise PreprocessError::ImportParseError(
            message,
            initial_offset + line_offset,
          )
      }
    } else if wgsl_directive_tail(trimmed, WgslDirectiveKind::DefineImportPath)
      is Some(raw_name) {
      let import_path = trim_trailing_semicolons(
        first_space_separated_token(raw_name),
      )
      if import_path != "" {
        name = Some(import_path)
      }
    } else if wgsl_directive_tail(trimmed, WgslDirectiveKind::Define)
      is Some(raw_define) {
      if allow_defines {
        let (define_name, define_value) = split_define_name_and_value(
          raw_define,
        )
        if define_name != "" {
          defines.set(define_name, parse_define_value(define_value))
        }
      } else {
        raise PreprocessError::DefineInModule(offset)
      }
    } else {
      collect_effective_def_names(line, effective_defs)
      ignore(
        substitute_identifiers(
          line, offset, declared_imports, used_imports, true,
        ) catch {
          AmbiguousImport(position) =>
            raise PreprocessError::ImportParseError(
              "Ambiguous import path for item", position,
            )
        },
      )
    }

    offset = offset + line.length() + 1
    line_index = line_index + 1
  }

  PreprocessorMetaData::{
    name,
    imports: used_imports,
    defines,
    effective_defs,
    wgsl_directives,
    cleaned_source: cleaned_for_directives,
  }
}

///|
pub fn get_preprocessor_metadata(source : String) -> PreprocessorMetaData {
  try_get_preprocessor_metadata(source, true) catch {
    _ =>
      PreprocessorMetaData::{
        name: None,
        imports: [],
        defines: @hashmap.HashMap::new(),
        effective_defs: @hashset.HashSet::new(),
        wgsl_directives: WgslDirectives::default(),
        cleaned_source: source,
      }
  }
}

///|
pub fn get_preprocessor_data(
  source : String,
) -> (
  String?,
  Array[ImportDefinition],
  @hashmap.HashMap[String, ShaderDefValue],
) {
  let metadata = get_preprocessor_metadata(source)
  let imports : Array[ImportDefinition] = []
  for import_with_offset in metadata.imports {
    imports.push(import_with_offset.definition)
  }
  (metadata.name, imports, metadata.defines)
}
