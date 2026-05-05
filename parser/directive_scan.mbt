///|
pub enum WgslDirectiveScanItemKind {
  Source
  GlslVersion(String)
  Directive(WgslDirective)
} derive(Debug)

///|
pub struct WgslDirectiveScanItem {
  priv kind : WgslDirectiveScanItemKind
  priv start : Int
  priv required_tail_space : Bool
  priv original_text : String
  priv cleaned_text : String
} derive(Debug)

///|
priv struct WgslDirectiveScanLine {
  original : String
  cleaned : String
  start : Int
}

///|
fn WgslDirectiveScanItem::new(
  kind : WgslDirectiveScanItemKind,
  start : Int,
  original_text : String,
  cleaned_text : String,
  required_tail_space : Bool,
) -> WgslDirectiveScanItem {
  WgslDirectiveScanItem::{
    kind,
    start,
    required_tail_space,
    original_text,
    cleaned_text,
  }
}

///|
pub fn WgslDirectiveScanItem::kind(
  self : WgslDirectiveScanItem,
) -> WgslDirectiveScanItemKind {
  self.kind
}

///|
pub fn WgslDirectiveScanItem::start(self : WgslDirectiveScanItem) -> Int {
  self.start
}

///|
pub fn WgslDirectiveScanItem::requires_tail_space(
  self : WgslDirectiveScanItem,
) -> Bool {
  self.required_tail_space
}

///|
pub fn WgslDirectiveScanItem::original_trivia(
  self : WgslDirectiveScanItem,
) -> String {
  self.original_text
}

///|
pub fn WgslDirectiveScanItem::cleaned_directive_text(
  self : WgslDirectiveScanItem,
) -> String {
  self.cleaned_text
}

///|
fn wgsl_directive_scan_build_lines(
  source : String,
) -> Array[WgslDirectiveScanLine] {
  let original_lines = source_lines(source)
  let cleaned_lines = source_lines(replace_comments_naga_oil(source))
  let lines : Array[WgslDirectiveScanLine] = []
  let mut offset = 0
  for i in 0..<original_lines.length() {
    let original = original_lines[i]
    let cleaned = if i < cleaned_lines.length() {
      cleaned_lines[i]
    } else {
      original
    }
    lines.push(WgslDirectiveScanLine::{ original, cleaned, start: offset })
    offset = offset + utf8_byte_length(original) + 1
  }
  lines
}

///|
fn wgsl_directive_scan_line_kind(
  line : WgslDirectiveScanLine,
  include_glsl_version : Bool,
) -> WgslDirectiveScanItemKind? {
  if include_glsl_version {
    match parse_glsl_version_directive(line.cleaned) {
      Some(version) =>
        return Some(WgslDirectiveScanItemKind::GlslVersion(version))
      None => ()
    }
  }
  match parse_wgsl_directive_line_at(line.cleaned, line.start) {
    Some(directive) => Some(WgslDirectiveScanItemKind::Directive(directive))
    None => None
  }
}

///|
fn wgsl_directive_scan_import_item_line_end(
  lines : Array[WgslDirectiveScanLine],
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
fn wgsl_directive_scan_join_lines(
  lines : Array[WgslDirectiveScanLine],
  start : Int,
  end_ : Int,
  cleaned : Bool,
) -> String {
  let mut out = ""
  for i in start..<end_ {
    out = if cleaned { out + lines[i].cleaned } else { out + lines[i].original }
    out = out + "\n"
  }
  out
}

///|
fn wgsl_directive_scan_push_item(
  items : Array[WgslDirectiveScanItem],
  lines : Array[WgslDirectiveScanLine],
  raw_kind : WgslDirectiveScanItemKind,
  start : Int,
  end_ : Int,
) -> Unit {
  if end_ <= start {
    return
  }
  let original_text = wgsl_directive_scan_join_lines(lines, start, end_, false)
  let cleaned_text = wgsl_directive_scan_join_lines(lines, start, end_, true)
  let kind = match raw_kind {
    WgslDirectiveScanItemKind::Directive(_) =>
      match parse_wgsl_directive_line_at(cleaned_text, lines[start].start) {
        Some(directive) => WgslDirectiveScanItemKind::Directive(directive)
        None => raw_kind
      }
    _ => raw_kind
  }
  let required_tail_space = match kind {
    WgslDirectiveScanItemKind::Directive(directive) =>
      wgsl_directive_line_required_tail_space(
        lines[start].cleaned,
        directive.name().name(),
      )
    _ => false
  }
  items.push(
    WgslDirectiveScanItem::new(
      kind,
      lines[start].start,
      original_text,
      cleaned_text,
      required_tail_space,
    ),
  )
}

///|
pub fn parse_wgsl_directive_scan_items(
  source : String,
  include_glsl_version? : Bool = true,
) -> Array[WgslDirectiveScanItem] {
  let lines = wgsl_directive_scan_build_lines(source)
  let items : Array[WgslDirectiveScanItem] = []
  let mut pending_start = 0
  let mut line_index = 0
  while line_index < lines.length() {
    match
      wgsl_directive_scan_line_kind(lines[line_index], include_glsl_version) {
      Some(kind) => {
        wgsl_directive_scan_push_item(
          items,
          lines,
          WgslDirectiveScanItemKind::Source,
          pending_start,
          line_index,
        )
        let item_end = match kind {
          WgslDirectiveScanItemKind::Directive(directive) =>
            if directive.kind() == WgslDirectiveKind::Import {
              wgsl_directive_scan_import_item_line_end(lines, line_index)
            } else {
              line_index + 1
            }
          _ => line_index + 1
        }
        wgsl_directive_scan_push_item(items, lines, kind, line_index, item_end)
        pending_start = item_end
        line_index = item_end
      }
      None => line_index = line_index + 1
    }
  }
  wgsl_directive_scan_push_item(
    items,
    lines,
    WgslDirectiveScanItemKind::Source,
    pending_start,
    lines.length(),
  )
  items
}
