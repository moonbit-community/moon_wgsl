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
  for item in raw.split(",") {
    let text = item.to_owned().trim().to_owned()
    if text != "" {
      extensions.push(text)
    }
  }
  extensions
}

///|
fn collect_effective_def_names(
  line : String,
  effective_defs : @hashset.HashSet[String],
) -> Unit {
  let mut i = 0
  while i < line.length() {
    if line.code_unit_at(i).to_int() == 35 { // '#'
      let mut scan = i + 1
      while scan < line.length() {
        let code = line.code_unit_at(scan).to_int()
        if code == 32 || code == 9 {
          scan = scan + 1
          continue
        }
        break
      }
      if scan < line.length() && line.code_unit_at(scan).to_int() == 123 { // '{'
        let mut j = scan + 1
        while j < line.length() && line.code_unit_at(j).to_int() != 125 { // '}'
          j = j + 1
        }
        if j < line.length() {
          let name = line[scan + 1:j].to_owned().trim().to_owned()
          if name != "" {
            effective_defs.add(name)
          }
          i = j + 1
          continue
        }
      }
      let mut j = scan
      while j < line.length() {
        let code = line.code_unit_at(j).to_int()
        let continue_name = (code >= 65 && code <= 90) ||
          (code >= 97 && code <= 122) ||
          (code >= 48 && code <= 57) ||
          code == 95 ||
          code == 124
        if !continue_name {
          break
        }
        j = j + 1
      }
      if j > scan {
        effective_defs.add(line[scan:j].to_owned())
        i = j
        continue
      }
    }
    i = i + 1
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
  if value.has_suffix("u") || value.has_suffix("U") {
    let unsigned_text = value[:value.length() - 1].to_owned().trim().to_owned()
    let parsed = @string.parse_int(unsigned_text[:], base=10) catch {
      _ => return ShaderDefValue::Bool(false)
    }
    return ShaderDefValue::UInt(parsed.reinterpret_as_uint())
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
  let mut i = 0
  while i < trimmed.length() {
    let code = trimmed.code_unit_at(i).to_int()
    if code == 32 || code == 9 {
      return (
        trimmed[:i].to_owned().trim().to_owned(),
        first_space_separated_token(trimmed[i:trimmed.length()].to_owned()),
      )
    }
    i = i + 1
  }
  (trimmed, "")
}

///|
fn first_space_separated_token(text : String) -> String {
  let trimmed = text.trim().to_owned()
  let mut i = 0
  while i < trimmed.length() {
    let code = trimmed.code_unit_at(i).to_int()
    if code == 32 || code == 9 {
      break
    }
    i = i + 1
  }
  trimmed[:i].to_owned()
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
  let mut i = 0
  while i < trimmed.length() {
    let code = trimmed.code_unit_at(i).to_int()
    let is_ident = (code >= 65 && code <= 90) ||
      (code >= 97 && code <= 122) ||
      (code >= 48 && code <= 57) ||
      code == 95 ||
      code == 124
    if !is_ident {
      break
    }
    i = i + 1
  }
  if i == 0 {
    None
  } else {
    Some(trimmed[:i].to_owned())
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
    let is_ident = (code >= 65 && code <= 90) ||
      (code >= 97 && code <= 122) ||
      (code >= 48 && code <= 57) ||
      code == 95 ||
      code == 124
    if !is_ident {
      break
    }
    i = i + 1
  }
  guard i > 0 else { return None }
  let def = text[:i].to_owned()
  while i < text.length() {
    let code = text.code_unit_at(i).to_int()
    if code == 32 || code == 9 {
      i = i + 1
      continue
    }
    break
  }
  let op_start = i
  while i < text.length() {
    let code = text.code_unit_at(i).to_int()
    if code == 61 || code == 33 || code == 60 || code == 62 {
      i = i + 1
      continue
    }
    break
  }
  let operator = text[op_start:i].to_owned()
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
    let is_value = (code >= 65 && code <= 90) ||
      (code >= 97 && code <= 122) ||
      (code >= 48 && code <= 57) ||
      code == 95 ||
      code == 124 ||
      code == 45
    if !is_value {
      break
    }
    i = i + 1
  }
  if value_start == i {
    return None
  }
  Some((def, operator, text[value_start:i].to_owned()))
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
      let parsed_text = if value.has_suffix("u") || value.has_suffix("U") {
        value[:value.length() - 1].to_owned()
      } else {
        value
      }
      let parsed = @string.parse_int(parsed_text[:], base=10) catch {
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
  if hash_directive_tail(line, "ifdef") is Some(rest) &&
    directive_identifier(rest) is Some(name) {
    let condition = shader_defs.contains(name)
    if scope is Some(scope_state) {
      scope_state.branch(false, condition, offset)
    }
    return (true, Some(name))
  }
  if hash_directive_tail(line, "ifndef") is Some(rest) &&
    directive_identifier(rest) is Some(name) {
    let condition = !shader_defs.contains(name)
    if scope is Some(scope_state) {
      scope_state.branch(false, condition, offset)
    }
    return (true, Some(name))
  }
  if hash_directive_tail(line, "else") is Some(else_tail) {
    if word_tail(else_tail, "ifdef") is Some(rest) &&
      directive_identifier(rest) is Some(name) {
      let condition = shader_defs.contains(name)
      if scope is Some(scope_state) {
        scope_state.branch(true, condition, offset)
      }
      return (true, Some(name))
    }
    if word_tail(else_tail, "ifndef") is Some(rest) &&
      directive_identifier(rest) is Some(name) {
      let condition = !shader_defs.contains(name)
      if scope is Some(scope_state) {
        scope_state.branch(true, condition, offset)
      }
      return (true, Some(name))
    }
    if word_tail(else_tail, "if") is Some(expr) &&
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
  if hash_directive_tail(line, "if") is Some(expr) &&
    parse_if_operator_expression(expr) is Some((def, operator, value)) {
    if scope is None {
      return (true, Some(def))
    }
    let condition = eval_if_condition(shader_defs, def, operator, value, offset)
    guard scope is Some(scope_state) else { abort("unreachable missing scope") }
    scope_state.branch(false, condition, offset)
    return (true, Some(def))
  }
  if hash_directive_tail(line, "else") is Some(_) {
    if scope is Some(scope_state) {
      scope_state.branch(true, true, offset)
    }
    return (true, None)
  }
  if hash_directive_tail(line, "endif") is Some(_) {
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
  let mut scan = 0
  let mut copy_start = 0
  while scan < line.length() {
    if line.code_unit_at(scan).to_int() != 35 { // '#'
      scan = scan + 1
      continue
    }

    let start = scan
    scan = scan + 1
    while scan < line.length() {
      let code = line.code_unit_at(scan).to_int()
      if code == 32 || code == 9 {
        scan = scan + 1
        continue
      }
      break
    }

    if scan < line.length() && line.code_unit_at(scan).to_int() == 123 { // '{'
      let mut j = scan + 1
      while j < line.length() && line.code_unit_at(j).to_int() != 125 { // '}'
        j = j + 1
      }
      if j < line.length() {
        let name = line[scan + 1:j].to_owned().trim().to_owned()
        if shader_defs.get(name) is Some(value) {
          output = output + line[copy_start:start].to_owned()
          output = output + value.value_as_string()
          scan = j + 1
          copy_start = scan
          continue
        }
      }
      scan = start + 1
      continue
    }

    let mut j = scan
    while j < line.length() {
      let code = line.code_unit_at(j).to_int()
      let is_ident = (code >= 65 && code <= 90) ||
        (code >= 97 && code <= 122) ||
        (code >= 48 && code <= 57) ||
        code == 95 ||
        code == 124
      if !is_ident {
        break
      }
      j = j + 1
    }
    if j > scan {
      let name = line[scan:j].to_owned()
      if shader_defs.get(name) is Some(value) {
        output = output + line[copy_start:start].to_owned()
        output = output + value.value_as_string()
        scan = j
        copy_start = scan
        continue
      }
    }

    scan = start + 1
  }
  if copy_start < line.length() {
    output = output + line[copy_start:line.length()].to_owned()
  }
  output
}

///|
pub fn Preprocessor::extract_wgsl_directives(
  _self : Preprocessor,
  source : String,
) -> (String, WgslDirectives) {
  let directives = WgslDirectives::default()
  let cleaned_lines : Array[String] = []
  let mut in_directive_section = true
  let mut line_index = 0
  for line_item in source.split("\n") {
    let line = line_item.to_owned()
    let trimmed = line.trim().to_owned()

    if trimmed == "" || starts_with_text(trimmed, "//") {
      cleaned_lines.push(line)
      line_index = line_index + 1
      continue
    }

    if in_directive_section {
      if starts_with_text(trimmed, "enable ") && trimmed.has_suffix(";") {
        cleaned_lines.push("")
        directives.enables.push(EnableDirective::{
          extensions: split_extensions(
            trimmed[7:trimmed.length() - 1].to_owned(),
          ),
          source_location: line_index,
        })
        line_index = line_index + 1
        continue
      }
      if starts_with_text(trimmed, "requires ") && trimmed.has_suffix(";") {
        cleaned_lines.push("")
        directives.requires.push(RequiresDirective::{
          extensions: split_extensions(
            trimmed[9:trimmed.length() - 1].to_owned(),
          ),
          source_location: line_index,
        })
        line_index = line_index + 1
        continue
      }
      if starts_with_text(trimmed, "diagnostic(") && trimmed.has_suffix(");") {
        let body = trimmed[11:trimmed.length() - 2].to_owned()
        if body.find(",") is Some(comma_index) {
          cleaned_lines.push("")
          directives.diagnostics.push(DiagnosticDirective::{
            severity: body[:comma_index].to_owned().trim().to_owned(),
            rule: body[comma_index + 1:body.length()]
            .to_owned()
            .trim()
            .to_owned(),
            source_location: line_index,
          })
          line_index = line_index + 1
          continue
        }
      }
      if !starts_with_text(trimmed, "enable") &&
        !starts_with_text(trimmed, "requires") &&
        !starts_with_text(trimmed, "diagnostic") {
        in_directive_section = false
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
  for line_item in source.split("\n") {
    original_lines.push(line_item.to_owned())
  }
  for line_item in replace_comments(source).split("\n") {
    decommented_lines.push(line_item.to_owned())
  }

  let mut final_string = ""
  let mut offset = 0
  let mut line_index = 0
  while line_index < decommented_lines.length() {
    let mut line = decommented_lines[line_index]
    let original_line = original_lines[line_index]
    let mut output = false
    let trimmed = line.trim().to_owned()

    if starts_with_text(trimmed, "#version ") {
      let version = trim_trailing_semicolons(
        trimmed[9:trimmed.length()].to_owned(),
      )
      if version != "440" && version != "450" {
        raise PreprocessError::GlslInvalidVersion(offset)
      }
    } else {
      let (is_scope, _) = check_scope(shader_defs, line, Some(scope), offset)
      if is_scope ||
        hash_directive_tail(trimmed, "define_import_path") is Some(_) ||
        hash_directive_tail(trimmed, "define") is Some(_) {
        ()
      } else if scope.active() {
        if hash_directive_tail(trimmed, "import") is Some(_) {
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

  for line_item in stripped.split("\n") {
    lines.push(line_item.to_owned())
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
    } else if hash_directive_tail(trimmed, "import") is Some(_) {
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
    } else if hash_directive_tail(trimmed, "define_import_path")
      is Some(raw_name) {
      let import_path = trim_trailing_semicolons(
        first_space_separated_token(raw_name),
      )
      if import_path != "" {
        name = Some(import_path)
      }
    } else if hash_directive_tail(trimmed, "define") is Some(raw_define) {
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
