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
priv enum WgslPreprocessItemKind {
  Source
  GlslVersion(String)
  Directive(WgslDirective)
}

///|
priv struct WgslPreprocessItem {
  kind : WgslPreprocessItemKind
  start : Int
  required_tail_space : Bool
  original_text : String
  cleaned_text : String
}

///|
priv struct WgslPreprocessLine {
  original : String
  cleaned : String
  start : Int
}

///|
fn preprocess_build_lines(source : String) -> Array[WgslPreprocessLine] {
  let original_lines = source_lines(source)
  let cleaned_lines = source_lines(replace_comments_naga_oil(source))
  let lines : Array[WgslPreprocessLine] = []
  let mut offset = 0
  for i in 0..<original_lines.length() {
    let original = original_lines[i]
    let cleaned = if i < cleaned_lines.length() {
      cleaned_lines[i]
    } else {
      original
    }
    lines.push(WgslPreprocessLine::{ original, cleaned, start: offset })
    offset = offset + utf8_byte_length(original) + 1
  }
  lines
}

///|
fn preprocess_parse_line_directive(
  line : WgslPreprocessLine,
) -> WgslPreprocessItemKind? {
  match parse_glsl_version_directive(line.cleaned) {
    Some(version) => return Some(WgslPreprocessItemKind::GlslVersion(version))
    None => ()
  }
  match parse_wgsl_directive_line_at(line.cleaned, line.start) {
    Some(directive) => Some(WgslPreprocessItemKind::Directive(directive))
    None => None
  }
}

///|
fn preprocess_line_required_tail_space(line : String, name : String) -> Bool {
  let trimmed = wgsl_regex_trim_whitespace(line)
  guard trimmed.length() > 0 && trimmed.code_unit_at(0).to_int() == 35 else {
    return false
  }
  let name_start = wgsl_regex_skip_whitespace(trimmed, 1)
  let space_pos = name_start + name.length()
  guard space_pos < trimmed.length() else { return false }
  wgsl_regex_whitespace_code_point(trimmed.code_unit_at(space_pos).to_int())
}

///|
fn preprocess_import_item_line_end(
  lines : Array[WgslPreprocessLine],
  line_index : Int,
) -> Int {
  let mut item_end = line_index + 1
  let mut balance = naga_oil_raw_import_brace_balance_next(
    0,
    lines[line_index].cleaned,
  )
  while balance > 0 && item_end < lines.length() {
    balance = naga_oil_raw_import_brace_balance_next(
      balance,
      lines[item_end].cleaned,
    )
    item_end = item_end + 1
  }
  item_end
}

///|
fn preprocess_join_lines(
  lines : Array[WgslPreprocessLine],
  start : Int,
  end_ : Int,
  cleaned : Bool,
) -> String {
  let mut out = ""
  for i in start..<end_ {
    if cleaned {
      out = out + lines[i].cleaned
    } else {
      out = out + lines[i].original
    }
    out = out + "\n"
  }
  out
}

///|
fn preprocess_push_line_item(
  items : Array[WgslPreprocessItem],
  lines : Array[WgslPreprocessLine],
  kind : WgslPreprocessItemKind,
  start : Int,
  end_ : Int,
) -> Unit {
  if end_ <= start {
    return
  }
  let required_tail_space = match kind {
    WgslPreprocessItemKind::Directive(directive) =>
      preprocess_line_required_tail_space(lines[start].cleaned, directive.name)
    _ => false
  }
  items.push(WgslPreprocessItem::{
    kind,
    start: lines[start].start,
    required_tail_space,
    original_text: preprocess_join_lines(lines, start, end_, false),
    cleaned_text: preprocess_join_lines(lines, start, end_, true),
  })
}

///|
fn parse_wgsl_preprocess_items(source : String) -> Array[WgslPreprocessItem] {
  let lines = preprocess_build_lines(source)
  let items : Array[WgslPreprocessItem] = []
  let mut pending_start = 0
  let mut line_index = 0
  while line_index < lines.length() {
    match preprocess_parse_line_directive(lines[line_index]) {
      Some(kind) => {
        preprocess_push_line_item(
          items,
          lines,
          WgslPreprocessItemKind::Source,
          pending_start,
          line_index,
        )
        let item_end = match kind {
          WgslPreprocessItemKind::Directive(directive) =>
            if directive.kind == WgslDirectiveKind::Import {
              preprocess_import_item_line_end(lines, line_index)
            } else {
              line_index + 1
            }
          _ => line_index + 1
        }
        preprocess_push_line_item(items, lines, kind, line_index, item_end)
        pending_start = item_end
        line_index = item_end
      }
      None => line_index = line_index + 1
    }
  }
  preprocess_push_line_item(
    items,
    lines,
    WgslPreprocessItemKind::Source,
    pending_start,
    lines.length(),
  )
  items
}

///|
fn preprocess_blank_text(text : String) -> String {
  let mut out = ""
  let mut line_start = 0
  for i in 0..<text.length() {
    if text.code_unit_at(i).to_int() == 10 {
      out = out + spaces(utf8_byte_length(text[line_start:i].to_owned()))
      out = out + "\n"
      line_start = i + 1
    }
  }
  if line_start < text.length() {
    out = out +
      spaces(utf8_byte_length(text[line_start:text.length()].to_owned()))
  }
  out
}

///|
fn preprocess_effective_directive_tail(directive : WgslDirective) -> String {
  match directive.kind {
    WgslDirectiveKind::Else =>
      if directive.tail == "" {
        ""
      } else {
        " \{directive.tail}"
      }
    WgslDirectiveKind::Endif => directive.tail
    WgslDirectiveKind::Other(name) =>
      if name.has_prefix("else") {
        let suffix = name["else".length():name.length()].to_owned()
        if directive.tail == "" {
          suffix
        } else {
          "\{suffix} \{directive.tail}"
        }
      } else if name.has_prefix("endif") {
        let suffix = name["endif".length():name.length()].to_owned()
        if directive.tail == "" {
          suffix
        } else {
          "\{suffix} \{directive.tail}"
        }
      } else {
        directive.tail
      }
    _ => directive.tail
  }
}

///|
fn preprocess_effective_directive_kind(
  directive : WgslDirective,
) -> WgslDirectiveKind {
  match directive.kind {
    WgslDirectiveKind::Other(name) =>
      if name.has_prefix("else") {
        WgslDirectiveKind::Else
      } else if name.has_prefix("endif") {
        WgslDirectiveKind::Endif
      } else {
        directive.kind
      }
    _ => directive.kind
  }
}

///|
fn preprocess_check_scope_directive(
  shader_defs : @hashmap.HashMap[String, ShaderDefValue],
  directive : WgslDirective,
  required_tail_space : Bool,
  scope : Scope?,
  offset : Int,
) -> (Bool, String?) raise PreprocessError {
  let tail = preprocess_effective_directive_tail(directive)
  match preprocess_effective_directive_kind(directive) {
    WgslDirectiveKind::Ifdef =>
      if required_tail_space {
        match parse_wgsl_directive_identifier(tail) {
          Some(name) => {
            let condition = shader_defs.contains(name)
            if scope is Some(scope_state) {
              scope_state.branch(false, condition, offset)
            }
            (true, Some(name))
          }
          None => (false, None)
        }
      } else {
        (false, None)
      }
    WgslDirectiveKind::Ifndef =>
      if required_tail_space {
        match parse_wgsl_directive_identifier(tail) {
          Some(name) => {
            let condition = !shader_defs.contains(name)
            if scope is Some(scope_state) {
              scope_state.branch(false, condition, offset)
            }
            (true, Some(name))
          }
          None => (false, None)
        }
      } else {
        (false, None)
      }
    WgslDirectiveKind::If =>
      if required_tail_space {
        check_if_operator_scope(shader_defs, tail, scope, offset, false)
      } else {
        (false, None)
      }
    WgslDirectiveKind::Else => {
      let else_tail_has_space = wgsl_text_starts_with_tokenized_space(tail)
      if else_tail_has_space &&
        wgsl_required_space_word_tail(tail, "ifdef") is Some(rest) &&
        parse_wgsl_directive_identifier(rest) is Some(name) {
        let condition = shader_defs.contains(name)
        if scope is Some(scope_state) {
          scope_state.branch(true, condition, offset)
        }
        return (true, Some(name))
      }
      if else_tail_has_space &&
        wgsl_required_space_word_tail(tail, "ifndef") is Some(rest) &&
        parse_wgsl_directive_identifier(rest) is Some(name) {
        let condition = !shader_defs.contains(name)
        if scope is Some(scope_state) {
          scope_state.branch(true, condition, offset)
        }
        return (true, Some(name))
      }
      if else_tail_has_space &&
        wgsl_required_space_word_tail(tail, "if") is Some(expr) {
        let (is_scope, def) = check_if_operator_scope(
          shader_defs, expr, scope, offset, true,
        )
        if is_scope {
          return (true, def)
        }
      }
      if scope is Some(scope_state) {
        scope_state.branch(true, true, offset)
      }
      (true, None)
    }
    WgslDirectiveKind::Endif => {
      if scope is Some(scope_state) {
        scope_state.pop(offset)
      }
      (true, None)
    }
    _ => (false, None)
  }
}

///|
fn preprocess_source_line_text_end(text : String, line_start : Int) -> Int {
  let mut i = line_start
  while i < text.length() {
    if text.code_unit_at(i).to_int() == 10 {
      return i
    }
    i = i + 1
  }
  text.length()
}

///|
fn preprocess_rewrite_source_item(
  item : WgslPreprocessItem,
  shader_defs : @hashmap.HashMap[String, ShaderDefValue],
  declared_imports : Array[DeclaredImportBinding],
  used_imports : Array[ImportDefWithOffset],
) -> String raise PreprocessError {
  let mut out = ""
  let mut virtual_offset = item.start
  let mut line_start = 0
  while line_start < item.original_text.length() {
    let line_text_end = preprocess_source_line_text_end(
      item.original_text,
      line_start,
    )
    let line_end = if line_text_end < item.original_text.length() {
      line_text_end + 1
    } else {
      line_text_end
    }
    let original_line = item.original_text[line_start:line_text_end].to_owned()
    let cleaned_line = item.cleaned_text[line_start:line_text_end].to_owned()
    let replaced_original = replace_shader_defs_in_line(
      original_line, shader_defs,
    )
    let replaced_decommented = replace_shader_defs_in_line(
      cleaned_line, shader_defs,
    )
    let ignored_imports : Array[ImportDefWithOffset] = []
    let item_replaced_line = substitute_identifiers(
      replaced_original, virtual_offset, declared_imports, ignored_imports, true,
    ) catch {
      AmbiguousImport(position) =>
        raise PreprocessError::ImportParseError(
          "Ambiguous import path for item", position,
        )
    }
    ignore(
      substitute_identifiers(
        replaced_decommented, virtual_offset, declared_imports, used_imports, false,
      ) catch {
        AmbiguousImport(position) =>
          raise PreprocessError::ImportParseError(
            "Ambiguous import path for item", position,
          )
      },
    )
    out = out + item_replaced_line
    let diff = utf8_byte_length(cleaned_line) -
      utf8_byte_length(item_replaced_line)
    if diff > 0 {
      out = out + spaces(diff)
    }
    if line_end > line_text_end {
      out = out + "\n"
      virtual_offset = virtual_offset + utf8_byte_length(replaced_original) + 1
    } else {
      virtual_offset = virtual_offset + utf8_byte_length(replaced_original)
    }
    line_start = line_end
  }
  out
}
