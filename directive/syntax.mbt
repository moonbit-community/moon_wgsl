///|
pub(all) enum WgslShaderDefOperator {
  Equal
  NotEqual
  Greater
  GreaterEqual
  Less
  LessEqual
  Unknown(String)
} derive(Eq, Debug)

///|
fn WgslShaderDefOperator::from_text(text : String) -> WgslShaderDefOperator {
  match text {
    "==" => Equal
    "!=" => NotEqual
    ">" => Greater
    ">=" => GreaterEqual
    "<" => Less
    "<=" => LessEqual
    _ => Unknown(text)
  }
}

///|
pub struct WgslShaderDefComparison {
  priv def : String
  priv operator : WgslShaderDefOperator
  priv value : String
} derive(Debug)

///|
fn WgslShaderDefComparison::new(
  def : String,
  operator : WgslShaderDefOperator,
  value : String,
) -> WgslShaderDefComparison {
  WgslShaderDefComparison::{ def, operator, value }
}

///|
pub fn WgslShaderDefComparison::def_name(
  self : WgslShaderDefComparison,
) -> String {
  self.def
}

///|
pub fn WgslShaderDefComparison::operator(
  self : WgslShaderDefComparison,
) -> WgslShaderDefOperator {
  self.operator
}

///|
pub fn WgslShaderDefComparison::value_text(
  self : WgslShaderDefComparison,
) -> String {
  self.value
}

///|
pub fn wgsl_text_starts_with_tokenized_space(text : String) -> Bool {
  text.length() > 0 &&
  wgsl_regex_whitespace_code_point(text.code_unit_at(0).to_int())
}

///|
pub fn parse_wgsl_directive_identifier(text : String) -> String? {
  let trimmed = wgsl_regex_trim_whitespace(trim_trailing_semicolons(text))
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

///|
fn directive_has_ascii_keyword_at(
  text : String,
  start : Int,
  keyword : String,
) -> Bool {
  guard start >= 0 && start + keyword.length() <= text.length() else {
    return false
  }
  text[start:start + keyword.length()] == keyword
}

///|
pub fn wgsl_required_space_word_tail(
  text : String,
  keyword : String,
) -> String? {
  let trimmed = wgsl_regex_trim_whitespace(text)
  guard keyword.length() < trimmed.length() else { return None }
  guard directive_has_ascii_keyword_at(trimmed, 0, keyword) else { return None }
  let space_pos = keyword.length()
  let code = trimmed.code_unit_at(space_pos).to_int()
  guard wgsl_regex_whitespace_code_point(code) else { return None }
  let tail_start = wgsl_regex_skip_whitespace(trimmed, space_pos)
  Some(
    wgsl_regex_trim_whitespace(trimmed[tail_start:trimmed.length()].to_owned()),
  )
}

///|
pub fn parse_wgsl_shader_def_comparison(
  expression : String,
) -> WgslShaderDefComparison? {
  let text = trim_trailing_semicolons(expression)
  let mut i = 0
  while i < text.length() {
    let code = text.code_unit_at(i).to_int()
    if wgsl_regex_whitespace_code_point(code) {
      i = i + 1
      continue
    }
    break
  }
  let def_start = i
  while i < text.length() {
    let width = wgsl_regex_word_width(text, i)
    guard width > 0 else { break }
    i = i + width
  }
  guard i > def_start else { return None }
  let def = text[def_start:i].to_owned()
  while i < text.length() {
    let code = text.code_unit_at(i).to_int()
    if wgsl_regex_whitespace_code_point(code) {
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
    if wgsl_regex_whitespace_code_point(code) {
      i = i + 1
      continue
    }
    break
  }
  let value_start = i
  while i < text.length() {
    let code = text.code_unit_at(i).to_int()
    if code == 45 {
      i = i + 1
      continue
    }
    let width = wgsl_regex_word_width(text, i)
    guard width > 0 else { break }
    i = i + width
  }
  if i == value_start {
    None
  } else {
    Some(
      WgslShaderDefComparison::new(
        def,
        WgslShaderDefOperator::from_text(operator),
        text[value_start:i].to_owned(),
      ),
    )
  }
}

///|
pub fn wgsl_effective_directive_tail(directive : WgslDirective) -> String {
  match directive.kind() {
    WgslDirectiveKind::Else =>
      if directive.tail() == "" {
        ""
      } else {
        " \{directive.tail()}"
      }
    WgslDirectiveKind::Endif => directive.tail()
    WgslDirectiveKind::Other => {
      let name = directive.name().name()
      if name.has_prefix("else") {
        let suffix = name["else".length():name.length()].to_owned()
        if directive.tail() == "" {
          suffix
        } else {
          "\{suffix} \{directive.tail()}"
        }
      } else if name.has_prefix("endif") {
        let suffix = name["endif".length():name.length()].to_owned()
        if directive.tail() == "" {
          suffix
        } else {
          "\{suffix} \{directive.tail()}"
        }
      } else {
        directive.tail()
      }
    }
    _ => directive.tail()
  }
}

///|
pub fn wgsl_effective_directive_kind(
  directive : WgslDirective,
) -> WgslDirectiveKind {
  match directive.kind() {
    WgslDirectiveKind::Other => {
      let name = directive.name().name()
      if name.has_prefix("else") {
        WgslDirectiveKind::Else
      } else if name.has_prefix("endif") {
        WgslDirectiveKind::Endif
      } else {
        directive.kind()
      }
    }
    _ => directive.kind()
  }
}
