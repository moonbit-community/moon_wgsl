///|
fn wgsl_naga_oil_base32_nopad(text : String) -> String {
  let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
  let out = StringBuilder::new()
  let mut buffer = 0
  let mut bits = 0
  for ch in text {
    let code = ch.to_int()
    let bytes : Array[Int] = if code <= 0x7F {
      [code]
    } else if code <= 0x7FF {
      [0xC0 | (code >> 6), 0x80 | (code & 0x3F)]
    } else if code <= 0xFFFF {
      [0xE0 | (code >> 12), 0x80 | ((code >> 6) & 0x3F), 0x80 | (code & 0x3F)]
    } else {
      [
        0xF0 | (code >> 18),
        0x80 | ((code >> 12) & 0x3F),
        0x80 | ((code >> 6) & 0x3F),
        0x80 | (code & 0x3F),
      ]
    }
    for byte in bytes {
      buffer = (buffer << 8) | byte
      bits = bits + 8
      while bits >= 5 {
        let index = (buffer >> (bits - 5)) & 31
        out.write_string(alphabet[index:index + 1].to_owned())
        bits = bits - 5
      }
    }
  }
  if bits > 0 {
    let index = (buffer << (5 - bits)) & 31
    out.write_string(alphabet[index:index + 1].to_owned())
  }
  out.to_string()
}

///|
fn wgsl_naga_oil_module_decoration(module_path : String) -> String {
  "X_naga_oil_mod_X\{wgsl_naga_oil_base32_nopad(module_path)}X"
}

///|
fn wgsl_naga_oil_virtual_decoration(module_path : String) -> String {
  "X_naga_oil_vrt_X\{wgsl_naga_oil_base32_nopad(module_path)}X"
}

///|
fn wgsl_naga_oil_decorated_final_name(
  module_path : String,
  original_name : String,
) -> String {
  if module_path == "" {
    original_name
  } else {
    "\{original_name}\{wgsl_naga_oil_module_decoration(module_path)}"
  }
}

///|
fn wgsl_naga_oil_virtual_override_final_name(
  target_module_path : String,
  override_module_path : String,
  original_name : String,
) -> String {
  let virtual_name = if target_module_path == "" {
    original_name
  } else {
    "\{original_name}\{wgsl_naga_oil_virtual_decoration(target_module_path)}"
  }
  if override_module_path == "" {
    virtual_name
  } else {
    "\{virtual_name}\{wgsl_naga_oil_module_decoration(override_module_path)}"
  }
}
