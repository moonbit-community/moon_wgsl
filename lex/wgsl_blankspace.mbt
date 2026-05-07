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
pub fn wgsl_line_break_width(text : String, index : Int) -> Int {
  guard index >= 0 && index < text.length() else { return 0 }
  let code = text.code_unit_at(index).to_int()
  if code == 13 {
    if index + 1 < text.length() && text.code_unit_at(index + 1).to_int() == 10 {
      2
    } else {
      1
    }
  } else if code == 10 {
    1
  } else {
    match wgsl_code_point_at(text, index) {
      Some((0x85, width)) | Some((0x2028, width)) | Some((0x2029, width)) =>
        width
      _ => 0
    }
  }
}

///|
pub fn wgsl_line_start(text : String, pos : Int) -> Int {
  let limit = if pos < 0 {
    0
  } else if pos > text.length() {
    text.length()
  } else {
    pos
  }
  let mut start = 0
  let mut index = 0
  while index < limit {
    let width = wgsl_line_break_width(text, index)
    if width > 0 {
      start = index + width
      index = index + width
    } else {
      index = index + 1
    }
  }
  start
}

///|
pub fn wgsl_line_text_end(text : String, pos : Int) -> Int {
  let mut index = if pos < 0 { 0 } else { pos }
  while index < text.length() {
    if wgsl_line_break_width(text, index) > 0 {
      return index
    }
    index = index + 1
  }
  text.length()
}

///|
pub fn wgsl_line_end(text : String, pos : Int) -> Int {
  let text_end = wgsl_line_text_end(text, pos)
  text_end + wgsl_line_break_width(text, text_end)
}

///|
pub fn wgsl_identifier_start_code_point(code_point : Int) -> Bool {
  code_point == 95 || wgsl_xid_start_code_point(code_point)
}

///|
pub fn wgsl_identifier_continue_code_point(code_point : Int) -> Bool {
  wgsl_identifier_start_code_point(code_point) ||
  (code_point >= 48 && code_point <= 57)
}

///|
pub fn wgsl_identifier_text(text : String) -> Bool {
  guard text != "" else { return false }
  let mut index = 0
  match wgsl_code_point_at(text, index) {
    Some((code_point, width)) if wgsl_identifier_start_code_point(code_point) =>
      index = index + width
    _ => return false
  }
  while index < text.length() {
    match wgsl_code_point_at(text, index) {
      Some((code_point, width)) if wgsl_identifier_continue_code_point(
          code_point,
        ) => index = index + width
      _ => return false
    }
  }
  true
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
