///|
fn token_end(token : WgslToken) -> Int {
  token.pos() + preprocess_token_text(token).length()
}

///|
fn parse_shader_def_references(line : String) -> Array[ShaderDefReference] {
  let references : Array[ShaderDefReference] = []
  let mut i = 0
  while i < line.length() {
    guard line.code_unit_at(i).to_int() == 35 else {
      i = i + 1
      continue
    }
    let start = i
    let mut j = i + 1
    while j < line.length() &&
          preprocess_regex_whitespace_code_unit(line.code_unit_at(j).to_int()) {
      j = j + 1
    }
    guard j < line.length() else {
      i = i + 1
      continue
    }
    if line.code_unit_at(j).to_int() == 123 {
      let body_start = j + 1
      let mut k = body_start
      while k < line.length() && line.code_unit_at(k).to_int() != 125 {
        k = k + 1
      }
      if k < line.length() {
        let name = line[body_start:k].to_owned()
        if wgsl_regex_word_text(name) {
          references.push(ShaderDefReference::{
            name,
            start,
            end: k + 1,
            delimited: true,
          })
        }
        i = k + 1
      } else {
        i = i + 1
      }
    } else {
      let name_start = j
      let mut name_end = j
      while name_end < line.length() {
        let width = wgsl_regex_word_width(line, name_end)
        guard width > 0 else { break }
        name_end = name_end + width
      }
      if name_end > name_start {
        references.push(ShaderDefReference::{
          name: line[name_start:name_end].to_owned(),
          start,
          end: name_end,
          delimited: false,
        })
        i = name_end
      } else {
        i = i + 1
      }
    }
  }
  references
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
          let name = source[body_start:tokens[j].pos()]
            .to_owned()
            .trim()
            .to_owned()
          references.push(WgslTemplateConstReference::{
            name,
            start,
            end: token_end(tokens[j]),
          })
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
fn starts_with_tokenized_space(text : String) -> Bool {
  text.length() > 0 &&
  preprocess_regex_whitespace_code_unit(text.code_unit_at(0).to_int())
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
fn required_space_directive_tail(line : String, keyword : String) -> String? {
  let trimmed = preprocess_trim_regex_whitespace(line)
  guard trimmed.length() > 0 && trimmed.code_unit_at(0).to_int() == 35 else {
    return None
  }
  let start = preprocess_skip_regex_whitespace(trimmed, 1)
  guard start + keyword.length() < trimmed.length() else { return None }
  guard preprocess_has_ascii_keyword_at(trimmed, start, keyword) else {
    return None
  }
  let space_pos = start + keyword.length()
  let code = trimmed.code_unit_at(space_pos).to_int()
  guard preprocess_regex_whitespace_code_unit(code) else { return None }
  let tail_start = preprocess_skip_regex_whitespace(trimmed, space_pos)
  Some(
    preprocess_trim_regex_whitespace(
      trimmed[tail_start:trimmed.length()].to_owned(),
    ),
  )
}

///|
fn required_space_word_tail(text : String, keyword : String) -> String? {
  let trimmed = preprocess_trim_regex_whitespace(text)
  guard keyword.length() < trimmed.length() else { return None }
  guard preprocess_has_ascii_keyword_at(trimmed, 0, keyword) else {
    return None
  }
  let space_pos = keyword.length()
  let code = trimmed.code_unit_at(space_pos).to_int()
  guard preprocess_regex_whitespace_code_unit(code) else { return None }
  let tail_start = preprocess_skip_regex_whitespace(trimmed, space_pos)
  Some(
    preprocess_trim_regex_whitespace(
      trimmed[tail_start:trimmed.length()].to_owned(),
    ),
  )
}

///|
pub fn parse_glsl_version_directive(line : String) -> String? {
  let trimmed = preprocess_trim_regex_whitespace(line)
  let prefix = "#version"
  guard trimmed.length() > prefix.length() &&
    preprocess_has_ascii_keyword_at(trimmed, 0, prefix) else {
    return None
  }
  let space_pos = prefix.length()
  guard preprocess_regex_whitespace_code_unit(
    trimmed.code_unit_at(space_pos).to_int(),
  ) else {
    return None
  }
  let start = preprocess_skip_regex_whitespace(trimmed, space_pos)
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
fn check_glsl_version_directive(
  line : String,
  offset : Int,
) -> Bool raise PreprocessError {
  match parse_glsl_version_directive(line) {
    Some(version) => {
      if version != "440" && version != "450" {
        raise PreprocessError::GlslInvalidVersion(offset)
      }
      true
    }
    None => false
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

///|
fn directive_identifier(text : String) -> String? {
  let trimmed = trim_trailing_semicolons(text).trim().to_owned()
  let mut i = 0
  while i < trimmed.length() {
    let width = wgsl_regex_word_width(trimmed, i)
    guard width > 0 else { break }
    i = i + width
  }
  if i == 0 {
    None
  } else {
    Some(trimmed[0:i].to_owned())
  }
}
