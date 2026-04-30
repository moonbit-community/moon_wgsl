///|
pub fn wgsl_blankspace_code_point(code_point : Int) -> Bool {
  (code_point >= 0x09 && code_point <= 0x0D) ||
  code_point == 0x20 ||
  code_point == 0x85 ||
  code_point == 0x200E ||
  code_point == 0x200F ||
  code_point == 0x2028 ||
  code_point == 0x2029
}

///|
fn wgsl_blankspace_width(text : String, index : Int) -> Int {
  match wgsl_code_point_at(text, index) {
    Some((code_point, width)) if wgsl_blankspace_code_point(code_point) => width
    _ => 0
  }
}

///|
fn wgsl_skip_blankspace(text : String, start : Int) -> Int {
  let mut index = start
  while index < text.length() {
    let width = wgsl_blankspace_width(text, index)
    guard width > 0 else { break }
    index = index + width
  }
  index
}

///|
pub fn wgsl_trim_blankspace(text : String) -> String {
  let start = wgsl_skip_blankspace(text, 0)
  let mut end = text.length()
  while end > start {
    let width = wgsl_blankspace_width(text, end - 1)
    if width > 0 {
      end = end - width
      continue
    }
    break
  }
  text[start:end].to_owned()
}
