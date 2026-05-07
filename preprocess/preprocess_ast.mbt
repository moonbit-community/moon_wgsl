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
fn preprocess_blank_text(text : String) -> String {
  let mut out = ""
  let mut line_start = 0
  let mut i = 0
  while i < text.length() {
    let width = wgsl_line_break_width(text, i)
    if width > 0 {
      out = out + spaces(utf8_byte_length(text[line_start:i].to_owned()))
      out = out + text[i:i + width].to_owned()
      i = i + width
      line_start = i
    } else {
      i = i + 1
    }
  }
  if line_start < text.length() {
    out = out +
      spaces(utf8_byte_length(text[line_start:text.length()].to_owned()))
  }
  out
}

///|
fn preprocess_check_scope_directive(
  shader_defs : @hashmap.HashMap[String, ShaderDefValue],
  directive : WgslDirective,
  scope : Scope?,
  offset : Int,
) -> (Bool, String?) raise PreprocessError {
  let tail = wgsl_effective_directive_tail(directive)
  let has_required_separator = directive.has_required_tail_separator()
  match wgsl_effective_directive_kind(directive) {
    WgslDirectiveKind::Ifdef =>
      if has_required_separator {
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
      if has_required_separator {
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
      if has_required_separator {
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
  wgsl_line_text_end(text, line_start)
}

///|
fn preprocess_replace_shader_defs_in_text(
  text : String,
  shader_defs : @hashmap.HashMap[String, ShaderDefValue],
) -> String {
  let mut out = ""
  let mut line_start = 0
  while line_start < text.length() {
    let line_text_end = preprocess_source_line_text_end(text, line_start)
    let line_end = if line_text_end < text.length() {
      line_text_end + 1
    } else {
      line_text_end
    }
    let line = text[line_start:line_text_end].to_owned()
    out = out + replace_shader_defs_in_line(line, shader_defs)
    if line_end > line_text_end {
      out = out + "\n"
    }
    line_start = line_end
  }
  out
}

///|
fn preprocess_pad_rewritten_source_item(
  rewritten : String,
  reference : String,
) -> String {
  let mut out = ""
  let mut rewritten_line_start = 0
  let mut reference_line_start = 0
  while rewritten_line_start < rewritten.length() {
    let rewritten_line_text_end = preprocess_source_line_text_end(
      rewritten, rewritten_line_start,
    )
    let rewritten_line_end = if rewritten_line_text_end < rewritten.length() {
      rewritten_line_text_end + 1
    } else {
      rewritten_line_text_end
    }
    let reference_line_text_end = preprocess_source_line_text_end(
      reference, reference_line_start,
    )
    let reference_line_end = if reference_line_text_end < reference.length() {
      reference_line_text_end + 1
    } else {
      reference_line_text_end
    }
    let rewritten_line = rewritten[rewritten_line_start:rewritten_line_text_end].to_owned()
    let reference_line = reference[reference_line_start:reference_line_text_end].to_owned()
    out = out + rewritten_line
    let diff = utf8_byte_length(reference_line) -
      utf8_byte_length(rewritten_line)
    if diff > 0 {
      out = out + spaces(diff)
    }
    if rewritten_line_end > rewritten_line_text_end {
      out = out + "\n"
    }
    rewritten_line_start = rewritten_line_end
    reference_line_start = reference_line_end
  }
  out
}

///|
priv enum WgslPreprocessEmissionKind {
  BlankTrivia
  KeepTrivia
  RewriteActiveSource
}

///|
fn preprocess_emit_scanned_item(
  kind : WgslPreprocessEmissionKind,
  item : WgslDirectiveScanItem,
  shader_defs : @hashmap.HashMap[String, ShaderDefValue],
  import_state : WgslImportSubstitutionState,
  used_imports : Array[ImportDefWithOffset],
) -> String raise PreprocessError {
  let source = item.source()
  match kind {
    BlankTrivia => preprocess_blank_text(source.original_text())
    KeepTrivia => source.original_text()
    RewriteActiveSource =>
      preprocess_rewrite_source_item(
        item, shader_defs, import_state, used_imports,
      )
  }
}

///|
fn preprocess_rewrite_source_item(
  item : WgslDirectiveScanItem,
  shader_defs : @hashmap.HashMap[String, ShaderDefValue],
  import_state : WgslImportSubstitutionState,
  used_imports : Array[ImportDefWithOffset],
) -> String raise PreprocessError {
  let source = item.source()
  let replaced_original = preprocess_replace_shader_defs_in_text(
    source.original_text(),
    shader_defs,
  )
  let replaced_decommented = preprocess_replace_shader_defs_in_text(
    source.cleaned_text(),
    shader_defs,
  )
  let ignored_imports : Array[ImportDefWithOffset] = []
  let rewritten_original = import_state.rewrite_source(
    replaced_original,
    item.start(),
    ignored_imports,
    true,
  ) catch {
    AmbiguousImport(position) =>
      raise PreprocessError::ImportParseError(
        "Ambiguous import path for item", position,
      )
    InvalidWgslSyntax(message, position) =>
      raise PreprocessError::ImportParseError(message, position)
  }
  ignore(
    import_state.rewrite_source(
      replaced_decommented,
      item.start(),
      used_imports,
      false,
    ) catch {
      AmbiguousImport(position) =>
        raise PreprocessError::ImportParseError(
          "Ambiguous import path for item", position,
        )
      InvalidWgslSyntax(message, position) =>
        raise PreprocessError::ImportParseError(message, position)
    },
  )
  preprocess_pad_rewritten_source_item(rewritten_original, replaced_decommented)
}
