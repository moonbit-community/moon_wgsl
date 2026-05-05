///|
pub enum WgslSourceDirectiveItemKind {
  Trivia
  Enable(String)
  Requires(String)
  Diagnostic(String, String)
  PrefixCandidate
  Source
} derive(Debug, Eq)

///|
pub struct WgslSourceDirectiveItem {
  kind : WgslSourceDirectiveItemKind
  line : String
  start : Int
  end : Int
} derive(Debug)

///|
fn WgslSourceDirectiveItem::new(
  kind : WgslSourceDirectiveItemKind,
  line : String,
  start : Int,
) -> WgslSourceDirectiveItem {
  WgslSourceDirectiveItem::{ kind, line, start, end: start + line.length() }
}

///|
fn wgsl_source_directive_keyword_tail(
  line : String,
  keyword : String,
) -> String? {
  let trimmed = wgsl_regex_trim_whitespace(line)
  guard trimmed.length() > keyword.length() &&
    has_ascii_keyword_at(trimmed, 0, keyword) else {
    return None
  }
  let whitespace_start = keyword.length()
  guard wgsl_regex_whitespace_code_point(
    trimmed.code_unit_at(whitespace_start).to_int(),
  ) else {
    return None
  }
  let whitespace_end = wgsl_regex_skip_whitespace(trimmed, whitespace_start)
  let mut semicolon_pos = whitespace_start + 1
  while semicolon_pos < trimmed.length() &&
        trimmed.code_unit_at(semicolon_pos).to_int() != 59 {
    semicolon_pos = semicolon_pos + 1
  }
  guard semicolon_pos < trimmed.length() else { return None }
  if semicolon_pos <= whitespace_end {
    if semicolon_pos - whitespace_start <= 1 {
      return None
    }
    return Some("")
  }
  Some(
    wgsl_regex_trim_whitespace(trimmed[whitespace_end:semicolon_pos].to_owned()),
  )
}

///|
fn wgsl_source_diagnostic_tail(line : String) -> (String, String)? {
  let trimmed = wgsl_regex_trim_whitespace(line)
  guard trimmed.length() >= "diagnostic".length() &&
    has_ascii_keyword_at(trimmed, 0, "diagnostic") else {
    return None
  }
  let mut i = "diagnostic".length()
  i = wgsl_regex_skip_whitespace(trimmed, i)
  guard i < trimmed.length() && trimmed.code_unit_at(i).to_int() == 40 else {
    return None
  }
  let severity_raw_start = i + 1
  i = wgsl_regex_skip_whitespace(trimmed, severity_raw_start)
  let severity_start = i
  while i < trimmed.length() && trimmed.code_unit_at(i).to_int() != 44 {
    i = i + 1
  }
  guard i < trimmed.length() else { return None }
  guard i > severity_start || severity_start > severity_raw_start else {
    return None
  }
  let severity = wgsl_regex_trim_whitespace(
    trimmed[severity_start:i].to_owned(),
  )
  let rule_raw_start = i + 1
  i = wgsl_regex_skip_whitespace(trimmed, rule_raw_start)
  let rule_start = i
  while i < trimmed.length() && trimmed.code_unit_at(i).to_int() != 41 {
    i = i + 1
  }
  guard i < trimmed.length() else { return None }
  guard i > rule_start || rule_start > rule_raw_start else { return None }
  let rule = wgsl_regex_trim_whitespace(trimmed[rule_start:i].to_owned())
  i = wgsl_regex_skip_whitespace(trimmed, i + 1)
  guard i < trimmed.length() && trimmed.code_unit_at(i).to_int() == 59 else {
    return None
  }
  Some((severity, rule))
}

///|
fn wgsl_source_directive_prefix_candidate(trimmed : String) -> Bool {
  has_ascii_keyword_at(trimmed, 0, "enable") ||
  has_ascii_keyword_at(trimmed, 0, "requires") ||
  has_ascii_keyword_at(trimmed, 0, "diagnostic")
}

///|
fn parse_wgsl_source_directive_item_at(
  line : String,
  source_start : Int,
) -> WgslSourceDirectiveItem {
  let trimmed = wgsl_regex_trim_whitespace(line)
  let kind = if trimmed == "" || trimmed.has_prefix("//") {
    WgslSourceDirectiveItemKind::Trivia
  } else if wgsl_source_directive_keyword_tail(line, "enable") is Some(body) {
    WgslSourceDirectiveItemKind::Enable(body)
  } else if wgsl_source_directive_keyword_tail(line, "requires") is Some(body) {
    WgslSourceDirectiveItemKind::Requires(body)
  } else if wgsl_source_diagnostic_tail(line) is Some((severity, rule)) {
    WgslSourceDirectiveItemKind::Diagnostic(severity, rule)
  } else if wgsl_source_directive_prefix_candidate(trimmed) {
    WgslSourceDirectiveItemKind::PrefixCandidate
  } else {
    WgslSourceDirectiveItemKind::Source
  }
  WgslSourceDirectiveItem::new(kind, line, source_start)
}

///|
pub fn parse_wgsl_source_directive_items(
  source : String,
) -> Array[WgslSourceDirectiveItem] {
  let items : Array[WgslSourceDirectiveItem] = []
  let mut offset = 0
  for line in source_lines(source) {
    items.push(parse_wgsl_source_directive_item_at(line, offset))
    offset = offset + utf8_byte_length(line) + 1
  }
  items
}
