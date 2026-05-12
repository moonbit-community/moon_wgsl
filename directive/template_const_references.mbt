///|
pub struct WgslTemplateConstReference {
  priv name : String
  priv start : Int
  priv end : Int
} derive(Debug)

///|
fn WgslTemplateConstReference::WgslTemplateConstReference(
  name : String,
  start : Int,
  end : Int,
) -> WgslTemplateConstReference {
  WgslTemplateConstReference::{ name, start, end }
}

///|
pub fn WgslTemplateConstReference::name(
  self : WgslTemplateConstReference,
) -> String {
  self.name
}

///|
pub fn WgslTemplateConstReference::start(
  self : WgslTemplateConstReference,
) -> Int {
  self.start
}

///|
pub fn WgslTemplateConstReference::end(
  self : WgslTemplateConstReference,
) -> Int {
  self.end
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
  value_defines : Map[String, ShaderDefValue],
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
  value_defines : Map[String, ShaderDefValue],
) -> Array[WgslTemplateConstReference] {
  let references : Array[WgslTemplateConstReference] = []
  let tokens = tokenize(source, true)
  let mut i = 0
  while i < tokens.length() {
    guard tokens[i].is_punctuation(35) else {
      i = i + 1
      continue
    }
    let start = tokens[i].pos()
    guard i + 1 < tokens.length() else {
      i = i + 1
      continue
    }
    if i + 4 < tokens.length() &&
      tokens[i + 1].is_punctuation(35) &&
      tokens[i + 3].is_punctuation(35) &&
      tokens[i + 4].is_punctuation(35) {
      match tokens[i + 2].identifier_text() {
        Some(name) =>
          if value_defines.get(name) is Some(_) {
            references.push(
              WgslTemplateConstReference(name, start, tokens[i + 4].end()),
            )
            i = i + 5
            continue
          }
        None => ()
      }
    }
    let next = tokens[i + 1]
    if next.is_punctuation(123) {
      let body_start = tokens[i + 1].end()
      let mut j = i + 2
      while j < tokens.length() {
        if tokens[j].is_punctuation(125) {
          break
        } else {
          j = j + 1
        }
      }
      if j < tokens.length() {
        let name = source[body_start:tokens[j].pos()].to_owned()
        if wgsl_regex_word_text(name) {
          references.push(
            WgslTemplateConstReference(name, start, tokens[j].end()),
          )
        }
        i = j + 1
      } else {
        i = i + 1
      }
      continue
    }
    match next.identifier_text() {
      Some(text) => {
        let pos = next.pos()
        match longest_wgsl_template_const_prefix(text, value_defines) {
          Some(name) => {
            references.push(
              WgslTemplateConstReference(name, start, pos + name.length()),
            )
            i = i + 2
          }
          None => i = i + 1
        }
      }
      None => i = i + 1
    }
  }
  references
}
