///|
pub enum WgslDirectiveScanItemKind {
  Source
  GlslVersion(String)
  Directive(WgslPreprocessorDirective)
} derive(Debug)

///|
pub struct WgslDirectiveScanSource {
  priv start : Int
  priv original_text : String
  priv cleaned_text : String
} derive(Debug)

///|
fn WgslDirectiveScanSource::WgslDirectiveScanSource(
  start : Int,
  original_text : String,
  cleaned_text : String,
) -> WgslDirectiveScanSource {
  { start, original_text, cleaned_text }
}

///|
fn WgslDirectiveScanSource::start(self : WgslDirectiveScanSource) -> Int {
  self.start
}

///|
pub fn WgslDirectiveScanSource::original_text(
  self : WgslDirectiveScanSource,
) -> String {
  self.original_text
}

///|
pub fn WgslDirectiveScanSource::cleaned_text(
  self : WgslDirectiveScanSource,
) -> String {
  self.cleaned_text
}

///|
pub struct WgslDirectiveScanItem {
  priv kind : WgslDirectiveScanItemKind
  priv source : WgslDirectiveScanSource
} derive(Debug)

///|
priv struct WgslDirectiveScanLine {
  original : String
  cleaned : String
  start : Int
}

///|
fn wgsl_directive_scan_exact_lines(source : String) -> Array[String] {
  let lines : Array[String] = []
  let mut line_start = 0
  let mut index = 0
  while index < source.length() {
    let break_width = wgsl_line_break_width(source, index)
    if break_width == 0 {
      index = index + 1
      continue
    }
    let line_end = index + break_width
    lines.push(source[line_start:line_end].to_owned())
    line_start = line_end
    index = line_end
  }
  if line_start < source.length() {
    lines.push(source[line_start:source.length()].to_owned())
  }
  lines
}

///|
fn WgslDirectiveScanItem::WgslDirectiveScanItem(
  kind : WgslDirectiveScanItemKind,
  start : Int,
  original_text : String,
  cleaned_text : String,
) -> WgslDirectiveScanItem {
  { kind, source: WgslDirectiveScanSource(start, original_text, cleaned_text) }
}

///|
pub fn WgslDirectiveScanItem::kind(
  self : WgslDirectiveScanItem,
) -> WgslDirectiveScanItemKind {
  self.kind
}

///|
pub fn WgslDirectiveScanItem::start(self : WgslDirectiveScanItem) -> Int {
  self.source.start()
}

///|
pub fn WgslDirectiveScanItem::source(
  self : WgslDirectiveScanItem,
) -> WgslDirectiveScanSource {
  self.source
}

///|
fn wgsl_directive_scan_build_lines(
  source : String,
) -> Array[WgslDirectiveScanLine] {
  let lines : Array[WgslDirectiveScanLine] = []
  let original_lines = wgsl_directive_scan_exact_lines(source)
  let cleaned_lines = wgsl_directive_scan_exact_lines(
    replace_comments_preserving_byte_width(source),
  )
  let mut byte_offset = 0
  for index in 0..<original_lines.length() {
    let original = original_lines[index]
    let cleaned = if index < cleaned_lines.length() {
      cleaned_lines[index]
    } else {
      original
    }
    lines.push({ original, cleaned, start: byte_offset })
    byte_offset = byte_offset + utf8_byte_length(original)
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
      Some(version) => return Some(GlslVersion(version))
      None => ()
    }
  }
  match parse_wgsl_directive_line_at(line.cleaned, line.start) {
    Some(directive) => Some(Directive(directive))
    None => None
  }
}

///|
fn wgsl_directive_scan_import_item_line_end(
  lines : Array[WgslDirectiveScanLine],
  line_index : Int,
) -> Int {
  let mut item_end = line_index + 1
  let mut balance = raw_import_brace_balance_next(0, lines[line_index].cleaned)
  while balance > 0 && item_end < lines.length() {
    balance = raw_import_brace_balance_next(balance, lines[item_end].cleaned)
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
  let out = StringBuilder::new()
  for i in start..<end_ {
    out.write_string(if cleaned { lines[i].cleaned } else { lines[i].original })
  }
  out.to_string()
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
    Directive(_) =>
      match parse_wgsl_directive_line_at(cleaned_text, lines[start].start) {
        Some(directive) => WgslDirectiveScanItemKind::Directive(directive)
        None => raw_kind
      }
    _ => raw_kind
  }
  items.push(
    WgslDirectiveScanItem(kind, lines[start].start, original_text, cleaned_text),
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
          Source,
          pending_start,
          line_index,
        )
        let item_end = match kind {
          Directive(directive) =>
            if directive.kind() == Import {
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
    Source,
    pending_start,
    lines.length(),
  )
  items
}
