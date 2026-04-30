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
  let lines = source_lines(input)
  let mut line_index = 0
  let mut source_offset = 0
  while line_index < lines.length() {
    let line = lines[line_index]
    let trimmed = line.trim().to_owned()
    guard wgsl_directive_tail(trimmed, WgslDirectiveKind::Import) is Some(spec) else {
      if trimmed == "" {
        source_offset = source_offset + line.length() + 1
        line_index = line_index + 1
        continue
      }
      raise ParseImportsError::Parse("expected `#import`", source_offset)
    }
    let mut block_spec = spec
    let mut brace_balance = wgsl_token_brace_balance(block_spec)
    let spec_offset = match line.find(spec) {
      Some(index) => index
      None => 0
    }
    let spec_start = source_offset + spec_offset
    let mut consumed_length = line.length() + 1
    while brace_balance > 0 && line_index + 1 < lines.length() {
      line_index = line_index + 1
      let next_line = lines[line_index]
      block_spec = "\{block_spec}\n\{next_line}"
      brace_balance = brace_balance + wgsl_token_brace_balance(next_line)
      consumed_length = consumed_length + next_line.length() + 1
    }
    let targets : Array[WgslImportTarget] = []
    parse_wgsl_import_targets(block_spec, "", targets) catch {
      Parse(message, offset) =>
        raise ParseImportsError::Parse(message, spec_start + offset)
    }
    for target in targets {
      declared_imports_add(
        declared_imports,
        wgsl_import_target_used_name(target),
        target.raw_path,
      )
    }
    source_offset = source_offset + consumed_length
    line_index = line_index + 1
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
  let tokens = tokenize(input, true)
  let mut output = ""
  let mut in_substitution_position = true

  for token in tokens {
    match token {
      Token::Identifier(ident, token_pos) =>
        if in_substitution_position {
          let (first, residual) = match split_once_identifier(ident) {
            Some(parts) => parts
            None => (ident, "")
          }
          let full_paths = match
            declared_imports_get_paths(declared_imports, first) {
            Some(paths) => paths
            None => [first]
          }
          if !allow_ambiguous && full_paths.length() > 1 {
            raise AmbiguousImport(offset + token_pos)
          }

          for full_path_base in full_paths {
            let full_path = if residual != "" {
              "\{full_path_base}::\{residual}"
            } else {
              full_path_base
            }

            if split_last_identifier(full_path)
              is Some((module_path, item_name)) {
              used_imports_record(
                used_imports,
                module_path,
                item_name,
                offset + token_pos,
              )
              output = output + item_name + decorate(module_path)
            } else if full_path.contains("\"") {
              output = output + ident
            } else {
              output = output + full_path
            }
          }
        } else {
          output = output + ident
        }
      Token::Other(other, _) => {
        output = output + wgsl_metadata_code_unit_to_string(other)
        if other == 46 || other == 64 { // '.' or '@'
          in_substitution_position = false
          continue
        }
      }
      Token::Whitespace(ws, _) => output = output + ws
    }

    in_substitution_position = true
  }

  output
}

///|
