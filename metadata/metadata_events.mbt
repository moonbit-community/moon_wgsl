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
priv enum WgslMetadataItemKind {
  Source
  Directive(WgslDirective)
}

///|
priv struct WgslMetadataItem {
  kind : WgslMetadataItemKind
  start : Int
  required_tail_space : Bool
  cleaned_text : String
}

///|
priv struct WgslMetadataLine {
  cleaned : String
  start : Int
}

///|
fn metadata_build_lines(source : String) -> Array[WgslMetadataLine] {
  let cleaned_lines = source_lines(replace_comments_naga_oil(source))
  let lines : Array[WgslMetadataLine] = []
  let mut offset = 0
  for line in source_lines(source) {
    let cleaned = if lines.length() < cleaned_lines.length() {
      cleaned_lines[lines.length()]
    } else {
      line
    }
    lines.push(WgslMetadataLine::{ cleaned, start: offset })
    offset = offset + utf8_byte_length(line) + 1
  }
  lines
}

///|
fn metadata_line_required_tail_space(line : String, name : String) -> Bool {
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
fn metadata_parse_line_directive(
  line : WgslMetadataLine,
) -> WgslMetadataItemKind? {
  match parse_wgsl_directive_line_at(line.cleaned, line.start) {
    Some(directive) => Some(WgslMetadataItemKind::Directive(directive))
    None => None
  }
}

///|
fn metadata_import_item_line_end(
  lines : Array[WgslMetadataLine],
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
fn metadata_join_lines(
  lines : Array[WgslMetadataLine],
  start : Int,
  end_ : Int,
) -> String {
  let mut out = ""
  for i in start..<end_ {
    out = out + lines[i].cleaned + "\n"
  }
  out
}

///|
fn metadata_push_line_item(
  items : Array[WgslMetadataItem],
  lines : Array[WgslMetadataLine],
  kind : WgslMetadataItemKind,
  start : Int,
  end_ : Int,
) -> Unit {
  if end_ <= start {
    return
  }
  let required_tail_space = match kind {
    WgslMetadataItemKind::Directive(directive) =>
      metadata_line_required_tail_space(lines[start].cleaned, directive.name)
    _ => false
  }
  items.push(WgslMetadataItem::{
    kind,
    start: lines[start].start,
    required_tail_space,
    cleaned_text: metadata_join_lines(lines, start, end_),
  })
}

///|
fn parse_wgsl_metadata_items(source : String) -> Array[WgslMetadataItem] {
  let lines = metadata_build_lines(source)
  let items : Array[WgslMetadataItem] = []
  let mut pending_start = 0
  let mut line_index = 0
  while line_index < lines.length() {
    match metadata_parse_line_directive(lines[line_index]) {
      Some(kind) => {
        metadata_push_line_item(
          items,
          lines,
          WgslMetadataItemKind::Source,
          pending_start,
          line_index,
        )
        let item_end = match kind {
          WgslMetadataItemKind::Directive(directive) =>
            if directive.kind == WgslDirectiveKind::Import {
              metadata_import_item_line_end(lines, line_index)
            } else {
              line_index + 1
            }
          _ => line_index + 1
        }
        metadata_push_line_item(items, lines, kind, line_index, item_end)
        pending_start = item_end
        line_index = item_end
      }
      None => line_index = line_index + 1
    }
  }
  metadata_push_line_item(
    items,
    lines,
    WgslMetadataItemKind::Source,
    pending_start,
    lines.length(),
  )
  items
}

///|
fn metadata_effective_directive_tail(directive : WgslDirective) -> String {
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
fn metadata_effective_directive_kind(
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
fn metadata_scope_def_from_directive(
  directive : WgslDirective,
  required_tail_space : Bool,
) -> (Bool, String?) {
  let tail = metadata_effective_directive_tail(directive)
  match metadata_effective_directive_kind(directive) {
    WgslDirectiveKind::Ifdef =>
      if required_tail_space {
        match parse_wgsl_directive_identifier(tail) {
          Some(name) => (true, Some(name))
          None => (false, None)
        }
      } else {
        (false, None)
      }
    WgslDirectiveKind::Ifndef =>
      if required_tail_space {
        match parse_wgsl_directive_identifier(tail) {
          Some(name) => (true, Some(name))
          None => (false, None)
        }
      } else {
        (false, None)
      }
    WgslDirectiveKind::If =>
      if required_tail_space {
        match wgsl_shader_def_comparison_def(tail) {
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
        wgsl_shader_def_comparison_def(expr) is Some(def) {
        return (true, Some(def))
      }
      (true, None)
    }
    WgslDirectiveKind::Endif => (true, None)
    _ => (false, None)
  }
}

///|
fn metadata_source_line_text_end(text : String, line_start : Int) -> Int {
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
fn metadata_collect_source_item(
  item : WgslMetadataItem,
  declared_imports : Array[DeclaredImportBinding],
  used_imports : Array[ImportDefWithOffset],
  effective_defs : @hashset.HashSet[String],
) -> Unit raise MetadataError {
  let mut line_start = 0
  while line_start < item.cleaned_text.length() {
    let line_text_end = metadata_source_line_text_end(
      item.cleaned_text,
      line_start,
    )
    let line_end = if line_text_end < item.cleaned_text.length() {
      line_text_end + 1
    } else {
      line_text_end
    }
    let line = item.cleaned_text[line_start:line_text_end].to_owned()
    let offset = item.start +
      utf8_byte_length(item.cleaned_text[0:line_start].to_owned())
    collect_effective_def_names(line, effective_defs)
    ignore(
      substitute_identifiers(line, offset, declared_imports, used_imports, true) catch {
        AmbiguousImport(position) =>
          raise MetadataError::ImportParseError(
            "Ambiguous import path for item", position,
          )
      },
    )
    line_start = line_end
  }
}
