///|
pub struct DeclaredImportBinding {
  used_name : String
  full_paths : Array[String]
}

///|
pub suberror SubstituteIdentifiersError {
  AmbiguousImport(Int)
}

///|
fn import_token_byte_offset(input : String, token : WgslToken) -> Int {
  utf8_byte_length(input[:token.pos()].to_owned())
}

///|
fn import_token_byte_end(input : String, token : WgslToken) -> Int {
  utf8_byte_length(input[:token.end()].to_owned())
}

///|
fn import_tail_is_empty_or_final_semicolon(tail : String) -> Bool {
  let tokens = tokenize(tail, false)
  if tokens.length() == 0 {
    return true
  }
  if tokens.length() == 1 && tokens[0] is WgslToken::Other(59, _) {
    return true
  }
  false
}

///|
fn declared_imports_find_index(
  declared_imports : Array[DeclaredImportBinding],
  used_name : String,
) -> Int? {
  for i in 0..<declared_imports.length() {
    if declared_imports[i].used_name == used_name {
      return Some(i)
    }
  }
  None
}

///|
fn declared_imports_add(
  declared_imports : Array[DeclaredImportBinding],
  used_name : String,
  full_path : String,
) -> Unit {
  if declared_imports_find_index(declared_imports, used_name) is Some(index) {
    declared_imports[index].full_paths.push(full_path)
  } else {
    declared_imports.push(DeclaredImportBinding::{
      used_name,
      full_paths: [full_path],
    })
  }
}

///|
fn declared_imports_get_paths(
  declared_imports : Array[DeclaredImportBinding],
  used_name : String,
) -> Array[String]? {
  if declared_imports_find_index(declared_imports, used_name) is Some(index) {
    return Some(declared_imports[index].full_paths)
  }
  None
}

///|
fn split_once_identifier(text : String) -> (String, String)? {
  if text.find("::") is Some(index) {
    return Some(
      (text[:index].to_owned(), text[index + 2:text.length()].to_owned()),
    )
  }
  None
}

///|
fn wgsl_import_target_used_name(target : WgslImportTarget) -> String {
  if target.alias_name != "" {
    return target.alias_name
  }
  match split_last_identifier(target.raw_path) {
    Some((_, tail)) => tail
    None => target.raw_path
  }
}

///|
pub fn parse_imports(
  input : String,
  declared_imports : Array[DeclaredImportBinding],
) -> Unit raise ParseImportsError {
  let tokens = tokenize(input, false)
  if tokens.length() == 0 {
    raise ParseImportsError::Parse("expected #import", utf8_byte_length(input))
  }

  guard tokens[0] is WgslToken::Other(35, _) else {
    raise ParseImportsError::Parse(
      "expected `#import`",
      import_token_byte_offset(input, tokens[0]),
    )
  }
  if tokens.length() == 1 {
    raise ParseImportsError::Parse(
      "expected `#import`",
      utf8_byte_length(input),
    )
  }
  guard tokens[1] is WgslToken::Identifier("import", _) else {
    raise ParseImportsError::Parse(
      "expected `#import`",
      import_token_byte_offset(input, tokens[1]),
    )
  }

  let tail_code_start = tokens[1].end()
  let tail_byte_start = import_token_byte_end(input, tokens[1])
  let tail = input[tail_code_start:input.length()].to_owned()
  if import_tail_is_empty_or_final_semicolon(tail) {
    return
  }
  let targets : Array[WgslImportTarget] = []
  parse_wgsl_import_targets(tail, "", targets) catch {
    Parse(message, offset) =>
      raise ParseImportsError::Parse(message, tail_byte_start + offset)
  }
  for target in targets {
    declared_imports_add(
      declared_imports,
      wgsl_import_target_used_name(target),
      target.raw_path,
    )
  }
}

///|
fn base32_nopad(input : String) -> String {
  let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
  let bytes = @utf8.encode(input[:])
  let mut value = 0U
  let mut bits = 0
  let mut out = ""
  for byte in bytes {
    value = (value << 8) | byte.to_uint()
    bits = bits + 8
    while bits >= 5 {
      let index = ((value >> (bits - 5)) & 31U).reinterpret_as_int()
      out = out + alphabet[index:index + 1].to_owned()
      bits = bits - 5
    }
  }
  if bits > 0 {
    let index = ((value << (5 - bits)) & 31U).reinterpret_as_int()
    out = out + alphabet[index:index + 1].to_owned()
  }
  out
}

///|
fn decorate(module_name : String) -> String {
  "X_naga_oil_mod_X\{base32_nopad(module_name)}X"
}

///|
fn used_imports_find_index(
  used_imports : Array[ImportDefWithOffset],
  module_path : String,
) -> Int? {
  for i in 0..<used_imports.length() {
    if used_imports[i].definition.import_path == module_path {
      return Some(i)
    }
  }
  None
}

///|
fn used_imports_record(
  used_imports : Array[ImportDefWithOffset],
  module_path : String,
  item_name : String,
  offset : Int,
) -> Unit {
  if used_imports_find_index(used_imports, module_path) is Some(index) {
    used_imports[index].definition.items.push(item_name)
  } else {
    used_imports.push(ImportDefWithOffset::{
      definition: ImportDefinition::{
        import_path: module_path,
        items: [item_name],
      },
      offset,
    })
  }
}

///|
pub fn substitute_identifiers(
  input : String,
  offset : Int,
  declared_imports : Array[DeclaredImportBinding],
  used_imports : Array[ImportDefWithOffset],
  allow_ambiguous : Bool,
) -> String raise SubstituteIdentifiersError {
  let mut output = ""
  let mut copy_start = 0

  for reference in parse_wgsl_identifier_references(input) {
    output = output + input[copy_start:reference.start].to_owned()
    copy_start = reference.end
    let ident = reference.text
    if !reference.substitution_allowed {
      output = output + ident
      continue
    }
    let token_byte_pos = utf8_byte_length(input[:reference.start].to_owned())
    let (first, residual) = match split_once_identifier(ident) {
      Some(parts) => parts
      None => (ident, "")
    }
    let full_paths = match declared_imports_get_paths(declared_imports, first) {
      Some(paths) => paths
      None => [first]
    }
    if !allow_ambiguous && full_paths.length() > 1 {
      raise AmbiguousImport(offset + token_byte_pos)
    }

    for full_path_base in full_paths {
      let full_path = if residual != "" {
        "\{full_path_base}::\{residual}"
      } else {
        full_path_base
      }

      if split_last_identifier(full_path) is Some((module_path, item_name)) {
        used_imports_record(
          used_imports,
          module_path,
          item_name,
          offset + token_byte_pos,
        )
        output = output + item_name + decorate(module_path)
      } else if full_path.contains("\"") {
        output = output + ident
      } else {
        output = output + full_path
      }
    }
  }
  output = output + input[copy_start:input.length()].to_owned()

  output
}

///|
