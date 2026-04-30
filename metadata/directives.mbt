///|
priv struct ShaderDefReference {
  name : String
}

///|
fn split_extensions(raw : String) -> Array[String] {
  let extensions : Array[String] = []
  for token in tokenize(raw, false) {
    match token {
      WgslToken::Identifier(text, _) => extensions.push(text)
      _ => ()
    }
  }
  extensions
}

///|
fn shader_def_name_token_text(token : WgslToken) -> String? {
  match token {
    WgslToken::Identifier(text, _) => Some(text)
    WgslToken::Other(124, _) => Some("|")
    WgslToken::Other(code, _) if code >= 48 && code <= 57 =>
      Some(wgsl_metadata_code_unit_to_string(code))
    _ => None
  }
}

///|
fn shader_def_value_token_text(token : WgslToken) -> String? {
  match token {
    WgslToken::Identifier(text, _) => Some(text)
    WgslToken::Other(124, _) | WgslToken::Other(45, _) =>
      Some(wgsl_metadata_token_text(token))
    WgslToken::Other(code, _) if (code >= 48 && code <= 57) ||
      (code >= 65 && code <= 90) ||
      (code >= 97 && code <= 122) =>
      Some(wgsl_metadata_code_unit_to_string(code))
    _ => None
  }
}

///|
fn token_end(token : WgslToken) -> Int {
  token.pos() + wgsl_metadata_token_text(token).length()
}

///|
fn parse_shader_def_references(line : String) -> Array[ShaderDefReference] {
  let references : Array[ShaderDefReference] = []
  let tokens = tokenize(line, true)
  let mut i = 0
  while i < tokens.length() {
    guard tokens[i] is WgslToken::Other(35, _) else {
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
            references.push(ShaderDefReference::{ name, })
          }
          i = k + 1
        } else {
          i = i + 1
        }
      }
      _ => {
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
          references.push(ShaderDefReference::{ name, })
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
fn collect_effective_def_names(
  line : String,
  effective_defs : @hashset.HashSet[String],
) -> Unit {
  for reference in parse_shader_def_references(line) {
    effective_defs.add(reference.name)
  }
}

///|
fn parse_define_value(raw_value : String) -> ShaderDefValue {
  let value = trim_trailing_semicolons(raw_value)
  if value == "" {
    return ShaderDefValue::Bool(true)
  }
  if value == "true" {
    return ShaderDefValue::Bool(true)
  }
  if value == "false" {
    return ShaderDefValue::Bool(false)
  }
  if !value.has_prefix("-") {
    let parsed_unsigned = @string.parse_int(value[:], base=10) catch { _ => -1 }
    if parsed_unsigned >= 0 {
      return ShaderDefValue::UInt(parsed_unsigned.reinterpret_as_uint())
    }
  }
  let parsed = @string.parse_int(value[:], base=10) catch {
    _ => return ShaderDefValue::Bool(false)
  }
  ShaderDefValue::Int(parsed)
}

///|
fn split_define_name_and_value(text : String) -> (String, String) {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return ("", "")
  }
  let tokens = tokenize(trimmed, true)
  let mut i = 0
  let mut name = ""
  while i < tokens.length() {
    match shader_def_name_token_text(tokens[i]) {
      Some(text) => {
        name = name + text
        i = i + 1
      }
      None => break
    }
  }
  if name == "" {
    return ("", "")
  }
  while i < tokens.length() {
    match tokens[i] {
      WgslToken::Whitespace(_, _) => i = i + 1
      _ => break
    }
  }
  let mut value = ""
  while i < tokens.length() {
    match shader_def_value_token_text(tokens[i]) {
      Some(text) => value = value + text
      None => break
    }
    i = i + 1
  }
  (name, value)
}

///|
fn starts_with_tokenized_space(text : String) -> Bool {
  match tokenize(text, true) {
    [WgslToken::Whitespace(_, 0), ..] => true
    _ => false
  }
}

///|
fn semicolon_directive_body(line : String, keyword : String) -> String? {
  let trimmed = line.trim().to_owned()
  let tokens = tokenize(trimmed, false)
  match tokens {
    [WgslToken::Identifier(actual, start), ..] if actual == keyword &&
      start == 0 => {
      let body_start = keyword.length()
      for token in tokens {
        match token {
          WgslToken::Other(59, semicolon_pos) =>
            if semicolon_pos > body_start {
              return Some(
                trimmed[body_start:semicolon_pos].to_owned().trim().to_owned(),
              )
            } else {
              return None
            }
          _ => ()
        }
      }
      None
    }
    _ => None
  }
}

///|
fn parse_diagnostic_directive_body(line : String) -> (String, String)? {
  match tokenize(line.trim().to_owned(), false) {
    [
      WgslToken::Identifier("diagnostic", 0),
      WgslToken::Other(40, _),
      WgslToken::Identifier(severity, _),
      WgslToken::Other(44, _),
      WgslToken::Identifier(rule, _),
      WgslToken::Other(41, _),
      WgslToken::Other(59, _),
      ..,
    ] => Some((severity, rule))
    _ => None
  }
}

///|
fn wgsl_source_directive_keyword(line : String) -> String? {
  match tokenize(line.trim().to_owned(), false) {
    [WgslToken::Identifier(keyword, _), ..] => Some(keyword)
    _ => None
  }
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

///|
fn metadata_identifier_code_unit(code : Int) -> Bool {
  (code >= 65 && code <= 90) ||
  (code >= 97 && code <= 122) ||
  (code >= 48 && code <= 57) ||
  code == 95
}

///|
fn metadata_skip_ascii_space(text : String, start : Int) -> Int {
  let mut i = start
  while i < text.length() {
    let code = text.code_unit_at(i).to_int()
    if code == 32 || code == 9 {
      i = i + 1
      continue
    }
    break
  }
  i
}

///|
fn metadata_word_tail(text : String, word : String) -> String? {
  let trimmed = text.trim().to_owned()
  let start = metadata_skip_ascii_space(trimmed, 0)
  guard start + word.length() <= trimmed.length() else { return None }
  guard trimmed[start:start + word.length()].to_owned() == word else {
    return None
  }
  let end = start + word.length()
  if end < trimmed.length() &&
    metadata_identifier_code_unit(trimmed.code_unit_at(end).to_int()) {
    return None
  }
  Some(trimmed[end:trimmed.length()].to_owned().trim().to_owned())
}

///|
fn parse_if_operator_expression(
  expression : String,
) -> (String, String, String)? {
  let text = trim_trailing_semicolons(expression)
  let mut i = 0
  while i < text.length() {
    let code = text.code_unit_at(i).to_int()
    if code == 32 || code == 9 {
      i = i + 1
      continue
    }
    break
  }
  let def_start = i
  while i < text.length() {
    let code = text.code_unit_at(i).to_int()
    if code == 124 ||
      code == 95 ||
      code > 127 ||
      (code >= 48 && code <= 57) ||
      (code >= 65 && code <= 90) ||
      (code >= 97 && code <= 122) {
      i = i + 1
      continue
    }
    break
  }
  guard i > def_start else { return None }
  let def = text[def_start:i].to_owned()
  while i < text.length() {
    let code = text.code_unit_at(i).to_int()
    if code == 32 || code == 9 {
      i = i + 1
      continue
    }
    break
  }
  let operator_start = i
  while i < text.length() {
    let code = text.code_unit_at(i).to_int()
    if code == 61 || code == 33 || code == 60 || code == 62 {
      i = i + 1
      continue
    }
    break
  }
  let operator = text[operator_start:i].to_owned()
  while i < text.length() {
    let code = text.code_unit_at(i).to_int()
    if code == 32 || code == 9 {
      i = i + 1
      continue
    }
    break
  }
  let value_start = i
  while i < text.length() {
    let code = text.code_unit_at(i).to_int()
    if code == 45 ||
      code == 124 ||
      code == 95 ||
      code > 127 ||
      (code >= 48 && code <= 57) ||
      (code >= 65 && code <= 90) ||
      (code >= 97 && code <= 122) {
      i = i + 1
      continue
    }
    break
  }
  if i == value_start {
    None
  } else {
    let value = text[value_start:i].to_owned()
    Some((def, operator, value))
  }
}

///|
fn if_operator_expression_def(expression : String) -> String? {
  match parse_if_operator_expression(expression) {
    Some((def, _, _)) => Some(def)
    None => None
  }
}

///|
fn metadata_scope_def(line : String) -> (Bool, String?) {
  if wgsl_directive_tail(line, WgslDirectiveKind::Ifdef) is Some(rest) &&
    directive_identifier(rest) is Some(name) {
    return (true, Some(name))
  }
  if wgsl_directive_tail(line, WgslDirectiveKind::Ifndef) is Some(rest) &&
    directive_identifier(rest) is Some(name) {
    return (true, Some(name))
  }
  if wgsl_directive_prefix_tail(line, WgslDirectiveKind::Else)
    is Some(else_tail) {
    let else_tail_has_space = starts_with_tokenized_space(else_tail)
    if else_tail_has_space &&
      metadata_word_tail(else_tail, "ifdef") is Some(rest) &&
      directive_identifier(rest) is Some(name) {
      return (true, Some(name))
    }
    if else_tail_has_space &&
      metadata_word_tail(else_tail, "ifndef") is Some(rest) &&
      directive_identifier(rest) is Some(name) {
      return (true, Some(name))
    }
    if else_tail_has_space &&
      metadata_word_tail(else_tail, "if") is Some(expr) &&
      if_operator_expression_def(expr) is Some(def) {
      return (true, Some(def))
    }
  }
  if wgsl_directive_tail(line, WgslDirectiveKind::If) is Some(expr) &&
    if_operator_expression_def(expr) is Some(def) {
    return (true, Some(def))
  }
  if wgsl_directive_prefix_tail(line, WgslDirectiveKind::Else) is Some(_) {
    return (true, None)
  }
  if wgsl_directive_prefix_tail(line, WgslDirectiveKind::Endif) is Some(_) {
    return (true, None)
  }
  (false, None)
}

///|
pub fn extract_wgsl_directives(
  source : String,
) -> (String, WgslDirectives) raise MetadataError {
  let directives = WgslDirectives::default()
  let cleaned_lines : Array[String] = []
  let mut in_directive_section = true
  let mut line_index = 0
  for line in source_lines(source) {
    let trimmed = line.trim().to_owned()

    if trimmed == "" || replace_comments(trimmed).trim().to_owned() == "" {
      cleaned_lines.push(line)
      line_index = line_index + 1
      continue
    }

    if in_directive_section {
      if semicolon_directive_body(trimmed, "enable") is Some(body) {
        let extensions = split_extensions(body)
        if extensions.is_empty() {
          raise MetadataError::InvalidWgslDirective(
            trimmed, line_index, "No extensions specified",
          )
        }
        cleaned_lines.push("")
        directives.enables.push(EnableDirective::{
          extensions,
          source_location: line_index,
        })
        line_index = line_index + 1
        continue
      }
      if semicolon_directive_body(trimmed, "requires") is Some(body) {
        let extensions = split_extensions(body)
        if extensions.is_empty() {
          raise MetadataError::InvalidWgslDirective(
            trimmed, line_index, "No extensions specified",
          )
        }
        cleaned_lines.push("")
        directives.requires.push(RequiresDirective::{
          extensions,
          source_location: line_index,
        })
        line_index = line_index + 1
        continue
      }
      if parse_diagnostic_directive_body(trimmed) is Some((severity, rule)) {
        if severity != "off" &&
          severity != "info" &&
          severity != "warn" &&
          severity != "error" {
          raise MetadataError::InvalidWgslDirective(
            trimmed,
            line_index,
            "Invalid severity '\{severity}'. Must be one of: off, info, warn, error",
          )
        }
        cleaned_lines.push("")
        directives.diagnostics.push(DiagnosticDirective::{
          severity,
          rule,
          source_location: line_index,
        })
        line_index = line_index + 1
        continue
      }
      match wgsl_source_directive_keyword(trimmed) {
        Some("enable") | Some("requires") | Some("diagnostic") => ()
        _ => in_directive_section = false
      }
    }

    cleaned_lines.push(line)
    line_index = line_index + 1
  }

  let mut cleaned_source = ""
  for i in 0..<cleaned_lines.length() {
    if i > 0 {
      cleaned_source = "\{cleaned_source}\n"
    }
    cleaned_source = cleaned_source + cleaned_lines[i]
  }

  (cleaned_source, directives)
}

///|
