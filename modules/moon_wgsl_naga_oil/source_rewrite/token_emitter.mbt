///|
pub struct WgslTokenReplacement {
  priv start : Int
  priv end : Int
  priv replacement : String
}

///|
pub fn WgslTokenReplacement::WgslTokenReplacement(
  start : Int,
  end : Int,
  replacement : String,
) -> WgslTokenReplacement {
  { start, end, replacement }
}

///|
fn wgsl_token_text(token : WgslToken) -> String {
  match token.identifier_text() {
    Some(text) => return text
    None => ()
  }
  match token.number_text() {
    Some(text) => return text
    None => ()
  }
  match token.operator_text() {
    Some(text) => return text
    None => ()
  }
  match token.punctuation_code() {
    Some(_) => token.source_text()
    _ => ""
  }
}

///|
fn wgsl_token_replacement(
  token : WgslToken,
  replacements : Array[WgslTokenReplacement],
) -> String? {
  for replacement in replacements {
    if replacement.start == token.pos() && replacement.end == token.end() {
      return Some(replacement.replacement)
    }
  }
  None
}

///|
fn wgsl_token_replacement_starting_at(
  token : WgslToken,
  replacements : Array[WgslTokenReplacement],
) -> WgslTokenReplacement? {
  let mut matched : WgslTokenReplacement? = None
  for replacement in replacements {
    if replacement.start != token.pos() || replacement.end < token.end() {
      continue
    }
    match matched {
      Some(existing) if existing.end >= replacement.end => ()
      _ => matched = Some(replacement)
    }
  }
  matched
}

///|
fn wgsl_token_is_wordlike(text : String) -> Bool {
  if text == "" {
    return false
  }
  let code = text.code_unit_at(0).to_int()
  (code >= 48 && code <= 57) ||
  (code >= 65 && code <= 90) ||
  (code >= 97 && code <= 122) ||
  code == 95 ||
  code == 34
}

///|
fn wgsl_emit_needs_space(previous : String, current : String) -> Bool {
  if previous == "" || current == "" || previous == "\n" {
    return false
  }
  if current == ")" ||
    current == "]" ||
    current == ">" ||
    current == "," ||
    current == ";" ||
    current == ":" ||
    current == "." {
    return false
  }
  if previous == "(" ||
    previous == "[" ||
    previous == "." ||
    previous == "@" ||
    previous == "<" {
    return false
  }
  if current == "(" {
    return previous == "if" ||
      previous == "for" ||
      previous == "while" ||
      previous == "switch" ||
      previous == "const_assert"
  }
  if current == "{" || current == "@" {
    return true
  }
  if (previous == ")" || previous == ">") && wgsl_token_is_wordlike(current) {
    return true
  }
  if previous == "&" && wgsl_token_is_wordlike(current) {
    return true
  }
  if previous == "," || previous == ":" || previous == ";" || previous == "}" {
    return true
  }
  if previous == "->" || current == "->" || previous == "=" || current == "=" {
    return true
  }
  if previous == "==" ||
    previous == "!=" ||
    previous == "<=" ||
    previous == ">=" ||
    previous == "&&" ||
    previous == "||" ||
    previous == "+=" ||
    previous == "-=" ||
    previous == "*=" ||
    previous == "/=" ||
    previous == "%=" ||
    previous == "&=" ||
    previous == "|=" ||
    previous == "^=" ||
    previous == "+" ||
    previous == "-" ||
    previous == "*" ||
    previous == "/" ||
    previous == "%" ||
    current == "==" ||
    current == "!=" ||
    current == "<=" ||
    current == ">=" ||
    current == "&&" ||
    current == "||" ||
    current == "+=" ||
    current == "-=" ||
    current == "*=" ||
    current == "/=" ||
    current == "%=" ||
    current == "&=" ||
    current == "|=" ||
    current == "^=" ||
    current == "+" ||
    current == "-" ||
    current == "*" ||
    current == "/" ||
    current == "%" {
    return true
  }
  wgsl_token_is_wordlike(previous) && wgsl_token_is_wordlike(current)
}

///|
pub fn emit_wgsl_token_stream_canonical(
  tokens : Array[WgslToken],
  replacements : Array[WgslTokenReplacement],
) -> String {
  let out = StringBuilder::new()
  let mut previous = ""
  let mut skip_until = -1
  for token in tokens {
    if token.pos() < skip_until {
      continue
    }
    let text = match wgsl_token_replacement_starting_at(token, replacements) {
      Some(replacement) => {
        skip_until = replacement.end
        replacement.replacement
      }
      None =>
        match wgsl_token_replacement(token, replacements) {
          Some(replacement) => replacement
          None => wgsl_token_text(token)
        }
    }
    if text == "" {
      continue
    }
    if wgsl_emit_needs_space(previous, text) {
      out.write_string(" ")
    }
    out.write_string(text)
    if text == ";" || text == "}" {
      out.write_string("\n")
      previous = "\n"
    } else {
      previous = text
    }
  }
  out.to_string()
}

///|
pub fn emit_wgsl_source_tokens_canonical(
  source : String,
  replacements : Array[WgslTokenReplacement],
) -> String {
  let out = emit_wgsl_token_stream_canonical(
    tokenize_wgsl(replace_comments(source), false),
    replacements,
  )
  if out == "" || out.has_suffix("\n") {
    out
  } else {
    "\{out}\n"
  }
}

///|
pub fn tokenize_wgsl_absolute_source(source : String) -> Array[WgslToken] {
  tokenize_wgsl(replace_comments(source), false)
}

///|
pub fn tokenize_wgsl_absolute_fragment(
  source : String,
  start : Int,
  end_ : Int,
) -> Array[WgslToken] {
  let tokens : Array[WgslToken] = []
  if start < 0 || end_ < start || end_ > source.length() {
    return tokens
  }
  let fragment = replace_comments(source[start:end_].to_owned())
  for token in tokenize_wgsl(fragment, false) {
    tokens.push(token.shift(start))
  }
  tokens
}
