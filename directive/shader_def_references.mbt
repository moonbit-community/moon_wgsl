///|
pub struct WgslShaderDefReference {
  priv name : String
  priv start : Int
  priv end : Int
  priv delimited : Bool
} derive(Debug)

///|
fn WgslShaderDefReference::new(
  name : String,
  start : Int,
  end : Int,
  delimited : Bool,
) -> WgslShaderDefReference {
  WgslShaderDefReference::{ name, start, end, delimited }
}

///|
pub fn WgslShaderDefReference::name(self : WgslShaderDefReference) -> String {
  self.name
}

///|
pub fn WgslShaderDefReference::start(self : WgslShaderDefReference) -> Int {
  self.start
}

///|
pub fn WgslShaderDefReference::end(self : WgslShaderDefReference) -> Int {
  self.end
}

///|
pub fn WgslShaderDefReference::is_delimited(
  self : WgslShaderDefReference,
) -> Bool {
  self.delimited
}

///|
fn parse_wgsl_shader_def_references_at(
  line : String,
  source_start : Int,
) -> Array[WgslShaderDefReference] {
  let references : Array[WgslShaderDefReference] = []
  let mut i = 0
  while i < line.length() {
    guard line.code_unit_at(i).to_int() == 35 else {
      i = i + 1
      continue
    }
    let start = i
    let mut j = i + 1
    while j < line.length() &&
          wgsl_regex_whitespace_code_point(line.code_unit_at(j).to_int()) {
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
          references.push(
            WgslShaderDefReference::new(
              name,
              source_start + start,
              source_start + k + 1,
              true,
            ),
          )
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
        references.push(
          WgslShaderDefReference::new(
            line[name_start:name_end].to_owned(),
            source_start + start,
            source_start + name_end,
            false,
          ),
        )
        i = name_end
      } else {
        i = i + 1
      }
    }
  }
  references
}

///|
pub fn parse_wgsl_shader_def_references(
  line : String,
) -> Array[WgslShaderDefReference] {
  parse_wgsl_shader_def_references_at(line, 0)
}
