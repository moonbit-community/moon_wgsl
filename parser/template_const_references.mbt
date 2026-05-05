///|
pub struct WgslTemplateConstReference {
  name : String
  start : Int
  end : Int
} derive(Debug)

///|
fn WgslTemplateConstReference::new(
  name : String,
  start : Int,
  end : Int,
) -> WgslTemplateConstReference {
  WgslTemplateConstReference::{ name, start, end }
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
pub fn parse_wgsl_template_const_references(
  source : String,
  value_defines : @hashmap.HashMap[String, Int],
) -> Array[WgslTemplateConstReference] {
  let references : Array[WgslTemplateConstReference] = []
  let tokens = tokenize(source, true)
  let mut i = 0
  while i < tokens.length() {
    guard tokens[i] is WgslToken::Punctuation(35, start) else {
      i = i + 1
      continue
    }
    guard i + 1 < tokens.length() else {
      i = i + 1
      continue
    }
    match tokens[i + 1] {
      WgslToken::Punctuation(123, _) => {
        let body_start = tokens[i + 1].end()
        let mut j = i + 2
        while j < tokens.length() {
          match tokens[j] {
            WgslToken::Punctuation(125, _) => break
            _ => j = j + 1
          }
        }
        if j < tokens.length() {
          let name = source[body_start:tokens[j].pos()].to_owned()
          if wgsl_regex_word_text(name) {
            references.push(
              WgslTemplateConstReference::new(name, start, tokens[j].end()),
            )
          }
          i = j + 1
        } else {
          i = i + 1
        }
      }
      WgslToken::Identifier(text, pos) =>
        match longest_wgsl_template_const_prefix(text, value_defines) {
          Some(name) => {
            references.push(
              WgslTemplateConstReference::new(name, start, pos + name.length()),
            )
            i = i + 2
          }
          None => i = i + 1
        }
      _ => i = i + 1
    }
  }
  references
}
