///|
fn shader_def_name_token_text(token : WgslToken) -> String? {
  match token {
    WgslToken::Identifier(text, _) => Some(text)
    WgslToken::Other(124, _) => Some("|")
    WgslToken::Other(code, _) if code >= 48 && code <= 57 =>
      Some(code_unit_to_string(code))
    _ => None
  }
}

///|
fn shader_def_value_token_text(token : WgslToken) -> String? {
  match token {
    WgslToken::Identifier(text, _) => Some(text)
    WgslToken::Other(124, _) | WgslToken::Other(45, _) =>
      Some(preprocess_token_text(token))
    WgslToken::Other(code, _) if (code >= 48 && code <= 57) ||
      (code >= 65 && code <= 90) ||
      (code >= 97 && code <= 122) => Some(code_unit_to_string(code))
    _ => None
  }
}

///|
fn token_end(token : WgslToken) -> Int {
  token.pos() + preprocess_token_text(token).length()
}

///|
fn parse_shader_def_references(line : String) -> Array[ShaderDefReference] {
  let references : Array[ShaderDefReference] = []
  let tokens = tokenize(line, true)
  let mut i = 0
  while i < tokens.length() {
    guard tokens[i] is WgslToken::Other(35, start) else {
      i = i + 1
      continue
    }
    let mut j = i + 1
    while j < tokens.length() {
      match tokens[j] {
        WgslToken::Whitespace(_, _) => j = j + 1
        _ => break
      }
    }
    guard j < tokens.length() else {
      i = i + 1
      continue
    }
    match tokens[j] {
      WgslToken::Other(123, _) => {
        let body_start = token_end(tokens[j])
        let mut k = j + 1
        while k < tokens.length() {
          match tokens[k] {
            WgslToken::Other(125, _) => break
            _ => k = k + 1
          }
        }
        if k < tokens.length() {
          let name = line[body_start:tokens[k].pos()]
            .to_owned()
            .trim()
            .to_owned()
          if name != "" {
            references.push(ShaderDefReference::{
              name,
              start,
              end: token_end(tokens[k]),
            })
          }
          i = k + 1
        } else {
          i = i + 1
        }
      }
      _ => {
        let name_start = tokens[j].pos()
        let mut name = ""
        while j < tokens.length() {
          match shader_def_name_token_text(tokens[j]) {
            Some(text) => {
              name = name + text
              j = j + 1
            }
            None => break
          }
        }
        if name != "" {
          references.push(ShaderDefReference::{
            name,
            start,
            end: if j > 0 {
              token_end(tokens[j - 1])
            } else {
              name_start
            },
          })
          i = j
        } else {
          i = i + 1
        }
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
  match tokenize(text, true) {
    [WgslToken::Whitespace(_, 0), ..] => true
    _ => false
  }
}

///|
pub fn parse_glsl_version_directive(line : String) -> String? {
  let trimmed = line.trim().to_owned()
  let tokens = tokenize(trimmed, false)
  match tokens {
    [WgslToken::Other(35, 0), WgslToken::Identifier("version", _), ..] => ()
    _ => return None
  }
  guard tokens.length() > 2 else { return None }
  let start = tokens[2].pos()
  let mut end = start
  let mut i = 2
  while i < tokens.length() {
    match tokens[i] {
      WgslToken::Other(code, pos) if code >= 48 && code <= 57 && pos == end => {
        end = end + 1
        i = i + 1
      }
      _ => break
    }
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
  let trimmed = trim_trailing_semicolons(text)
  let tokens = tokenize(trimmed, false)
  let mut out = ""
  let mut expect_identifier = true
  for token in tokens {
    match token {
      WgslToken::Identifier(ident, _) if expect_identifier => {
        out = out + ident
        expect_identifier = false
      }
      WgslToken::Other(124, _) if !expect_identifier => {
        out = out + "|"
        expect_identifier = true
      }
      _ => break
    }
  }
  if out == "" || expect_identifier {
    None
  } else {
    Some(out)
  }
}
