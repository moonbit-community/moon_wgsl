///|
fn token_end(token : WgslToken) -> Int {
  token.pos() + preprocess_token_text(token).length()
}

///|
fn wgsl_template_const_name_boundary(text : String, name : String) -> Bool {
  if text.length() == name.length() {
    return true
  }
  if text.length() < name.length() {
    return false
  }
  let tail = text[name.length():text.length()].to_owned()
  for prefix in ["_", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"] {
    if tail.has_prefix(prefix) {
      return false
    }
  }
  for
    prefix in [
      "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O",
      "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
    ] {
    if tail.has_prefix(prefix) {
      return false
    }
  }
  true
}

///|
fn longest_wgsl_template_const_prefix(
  text : String,
  value_defines : @hashmap.HashMap[String, Int],
) -> String? {
  let mut best = ""
  for entry in value_defines.iter() {
    let (name, _) = entry
    if name.length() > best.length() &&
      text.has_prefix(name) &&
      wgsl_template_const_name_boundary(text, name) {
      best = name
    }
  }
  if best == "" {
    None
  } else {
    Some(best)
  }
}

///|
fn parse_wgsl_template_const_references(
  source : String,
  value_defines : @hashmap.HashMap[String, Int],
) -> Array[WgslTemplateConstReference] {
  let references : Array[WgslTemplateConstReference] = []
  let tokens = tokenize(source, true)
  let mut i = 0
  while i < tokens.length() {
    guard tokens[i] is WgslToken::Other(35, start) else {
      i = i + 1
      continue
    }
    guard i + 1 < tokens.length() else {
      i = i + 1
      continue
    }
    match tokens[i + 1] {
      WgslToken::Other(123, _) => {
        let body_start = token_end(tokens[i + 1])
        let mut j = i + 2
        while j < tokens.length() {
          match tokens[j] {
            WgslToken::Other(125, _) => break
            _ => j = j + 1
          }
        }
        if j < tokens.length() {
          let name = source[body_start:tokens[j].pos()].to_owned()
          if wgsl_regex_word_text(name) {
            references.push(WgslTemplateConstReference::{
              name,
              start,
              end: token_end(tokens[j]),
            })
          }
          i = j + 1
        } else {
          i = i + 1
        }
      }
      WgslToken::Identifier(text, pos) =>
        match longest_wgsl_template_const_prefix(text, value_defines) {
          Some(name) => {
            references.push(WgslTemplateConstReference::{
              name,
              start,
              end: pos + name.length(),
            })
            i = i + 2
          }
          None => i = i + 1
        }
      _ => i = i + 1
    }
  }
  references
}

///|
fn preprocess_has_ascii_keyword_at(
  text : String,
  start : Int,
  keyword : String,
) -> Bool {
  guard start >= 0 && start + keyword.length() <= text.length() else {
    return false
  }
  for i in 0..<keyword.length() {
    if text.code_unit_at(start + i).to_int() != keyword.code_unit_at(i).to_int() {
      return false
    }
  }
  true
}

///|
pub fn parse_glsl_version_directive(line : String) -> String? {
  let trimmed = wgsl_regex_trim_whitespace(line)
  let prefix = "#version"
  guard trimmed.length() > prefix.length() &&
    preprocess_has_ascii_keyword_at(trimmed, 0, prefix) else {
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
