///|
pub fn parse_glsl_version_directive(line : String) -> String? {
  let trimmed = wgsl_regex_trim_whitespace(line)
  let prefix = "#version"
  guard trimmed.length() > prefix.length() &&
    has_ascii_keyword_at(trimmed, 0, prefix) else {
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
