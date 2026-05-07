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
fn metadata_scope_def_from_directive(
  directive : WgslDirective,
) -> (Bool, String?) {
  let tail = wgsl_effective_directive_tail(directive)
  let has_required_separator = directive.has_required_tail_separator()
  match wgsl_effective_directive_kind(directive) {
    WgslDirectiveKind::Ifdef =>
      if has_required_separator {
        match parse_wgsl_directive_identifier(tail) {
          Some(name) => (true, Some(name))
          None => (false, None)
        }
      } else {
        (false, None)
      }
    WgslDirectiveKind::Ifndef =>
      if has_required_separator {
        match parse_wgsl_directive_identifier(tail) {
          Some(name) => (true, Some(name))
          None => (false, None)
        }
      } else {
        (false, None)
      }
    WgslDirectiveKind::If =>
      if has_required_separator {
        match metadata_shader_def_comparison_def(tail) {
          Some(def) => (true, Some(def))
          None => (false, None)
        }
      } else {
        (false, None)
      }
    WgslDirectiveKind::Else => {
      let else_tail_has_space = wgsl_text_starts_with_tokenized_space(tail)
      if else_tail_has_space &&
        wgsl_required_space_word_tail(tail, "ifdef") is Some(rest) &&
        parse_wgsl_directive_identifier(rest) is Some(name) {
        return (true, Some(name))
      }
      if else_tail_has_space &&
        wgsl_required_space_word_tail(tail, "ifndef") is Some(rest) &&
        parse_wgsl_directive_identifier(rest) is Some(name) {
        return (true, Some(name))
      }
      if else_tail_has_space &&
        wgsl_required_space_word_tail(tail, "if") is Some(expr) &&
        metadata_shader_def_comparison_def(expr) is Some(def) {
        return (true, Some(def))
      }
      (true, None)
    }
    WgslDirectiveKind::Endif => (true, None)
    _ => (false, None)
  }
}

///|
fn metadata_shader_def_comparison_def(expression : String) -> String? {
  match parse_wgsl_shader_def_comparison(expression) {
    Some(comparison) => Some(comparison.def_name())
    None => None
  }
}

///|
fn metadata_source_line_text_end(text : String, line_start : Int) -> Int {
  wgsl_line_text_end(text, line_start)
}

///|
fn metadata_collect_source_item(
  item : WgslDirectiveScanItem,
  effective_defs : @hashset.HashSet[String],
) -> Unit {
  let mut line_start = 0
  let cleaned_text = item.source().cleaned_text()
  while line_start < cleaned_text.length() {
    let line_text_end = metadata_source_line_text_end(cleaned_text, line_start)
    let line_end = if line_text_end < cleaned_text.length() {
      line_text_end + 1
    } else {
      line_text_end
    }
    let line = cleaned_text[line_start:line_text_end].to_owned()
    collect_effective_def_names(line, effective_defs)
    line_start = line_end
  }
}

///|
fn metadata_collect_import_uses(
  source : String,
  import_state : WgslImportSubstitutionState,
  used_imports : Array[ImportDefWithOffset],
) -> Unit raise MetadataError {
  ignore(
    import_state.rewrite_source(source, 0, used_imports, true) catch {
      AmbiguousImport(position) =>
        raise MetadataError::ImportParseError(
          "Ambiguous import path for item", position,
        )
      InvalidWgslSyntax(_, _) => source
    },
  )
}
