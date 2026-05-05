///|
pub fn parse_glsl_version_directive(line : String) -> String? {
  let trimmed = wgsl_regex_trim_whitespace(line)
  let prefix = "#version"
  guard trimmed.length() > prefix.length() &&
    glsl_version_has_ascii_keyword_at(trimmed, 0, prefix) else {
    return None
  }
  let space_pos = prefix.length()
  guard wgsl_regex_whitespace_code_point(
    trimmed.code_unit_at(space_pos).to_int(),
  ) else {
    return None
  }
  let start = wgsl_regex_skip_whitespace(trimmed, space_pos)
  let mut end = start
  while end < trimmed.length() {
    let code = trimmed.code_unit_at(end).to_int()
    guard code >= 48 && code <= 57 else { break }
    end = end + 1
  }
  if end > start {
    Some(trimmed[start:end].to_owned())
  } else {
    None
  }
}

///|
fn glsl_version_has_ascii_keyword_at(
  text : String,
  offset : Int,
  keyword : String,
) -> Bool {
  if offset < 0 || offset + keyword.length() > text.length() {
    return false
  }
  for i in 0..<keyword.length() {
    if text.code_unit_at(offset + i) != keyword.code_unit_at(i) {
      return false
    }
  }
  true
}
