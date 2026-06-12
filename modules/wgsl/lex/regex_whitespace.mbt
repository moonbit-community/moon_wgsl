///|
pub fn wgsl_regex_whitespace_code_point(code_point : Int) -> Bool {
  (code_point >= 0x09 && code_point <= 0x0D) ||
  code_point == 0x20 ||
  code_point == 0x85 ||
  code_point == 0xA0 ||
  code_point == 0x1680 ||
  (code_point >= 0x2000 && code_point <= 0x200A) ||
  code_point == 0x2028 ||
  code_point == 0x2029 ||
  code_point == 0x202F ||
  code_point == 0x205F ||
  code_point == 0x3000
}

///|
pub fn wgsl_regex_whitespace_width(text : String, index : Int) -> Int {
  match wgsl_code_point_at(text, index) {
    Some((code_point, width)) if wgsl_regex_whitespace_code_point(code_point) =>
      width
    _ => 0
  }
}

///|
pub fn wgsl_regex_skip_whitespace(text : String, start : Int) -> Int {
  let mut index = start
  while index < text.length() {
    let width = wgsl_regex_whitespace_width(text, index)
    guard width > 0 else { break }
    index = index + width
  }
  index
}

///|
pub fn wgsl_regex_trim_whitespace(text : String) -> String {
  let start = wgsl_regex_skip_whitespace(text, 0)
  let mut end = text.length()
  while end > start {
    let width = wgsl_regex_whitespace_width(text, end - 1)
    if width > 0 {
      end = end - width
      continue
    }
    break
  }
  text[start:end].to_owned()
}
