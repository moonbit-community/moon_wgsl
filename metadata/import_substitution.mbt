///|
priv struct DeclaredImportBinding {
  used_name : String
  full_paths : Array[String]
}

///|
pub struct WgslImportSubstitutionState {
  priv declared_imports : Array[DeclaredImportBinding]
}

///|
pub fn WgslImportSubstitutionState::default() -> WgslImportSubstitutionState {
  WgslImportSubstitutionState::{ declared_imports: [] }
}

///|
pub suberror WgslImportSubstitutionError {
  AmbiguousImport(Int)
  InvalidWgslSyntax(String, Int)
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
fn parse_imports(
  input : String,
  declared_imports : Array[DeclaredImportBinding],
) -> Unit raise ParseImportsError {
  let tokens = tokenize(input, false)
  if tokens.length() == 0 {
    raise ParseImportsError::Parse("expected #import", utf8_byte_length(input))
  }

  guard tokens[0].is_punctuation(35) else {
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
  guard tokens[1].is_identifier("import") else {
    raise ParseImportsError::Parse(
      "expected `#import`",
      import_token_byte_offset(input, tokens[1]),
    )
  }

  let tail_code_start = tokens[1].end()
  let tail_byte_start = import_token_byte_end(input, tokens[1])
  let tail = input[tail_code_start:input.length()].to_owned()
  if parse_wgsl_import_spec_is_empty_or_final_semicolon(tail) {
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
) -> Unit {
  if used_imports_find_index(used_imports, module_path) is Some(index) {
    used_imports[index].definition.items.push(item_name)
  } else {
    used_imports.push(
      ImportDefWithOffset::new(ImportDefinition::{
        import_path: module_path,
        items: [item_name],
      }),
    )
  }
}

///|
fn imported_identifier_replacement(
  ident : String,
  token_byte_pos : Int,
  declared_imports : Array[DeclaredImportBinding],
  used_imports : Array[ImportDefWithOffset],
  allow_ambiguous : Bool,
) -> String raise WgslImportSubstitutionError {
  let (first, residual) = match split_once_identifier(ident) {
    Some(parts) => parts
    None => (ident, "")
  }
  let full_paths = match declared_imports_get_paths(declared_imports, first) {
    Some(paths) => paths
    None => [first]
  }
  if !allow_ambiguous && full_paths.length() > 1 {
    raise AmbiguousImport(token_byte_pos)
  }
  let mut replacement = ""
  for full_path_base in full_paths {
    let full_path = if residual != "" {
      "\{full_path_base}::\{residual}"
    } else {
      full_path_base
    }
    if split_last_identifier(full_path) is Some((module_path, item_name)) {
      used_imports_record(used_imports, module_path, item_name)
      replacement = replacement + item_name + decorate(module_path)
    } else if full_path.contains("\"") {
      replacement = replacement + ident
    } else {
      replacement = replacement + full_path
    }
  }
  replacement
}

///|
priv struct WgslImportRewriteNode {
  start : Int
  end : Int
  replacement : String
}

///|
fn wgsl_import_token_text(token : WgslToken) -> String {
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
    Some(35) => "#"
    Some(37) => "%"
    Some(38) => "&"
    Some(40) => "("
    Some(41) => ")"
    Some(42) => "*"
    Some(43) => "+"
    Some(44) => ","
    Some(45) => "-"
    Some(46) => "."
    Some(47) => "/"
    Some(58) => ":"
    Some(59) => ";"
    Some(60) => "<"
    Some(61) => "="
    Some(62) => ">"
    Some(64) => "@"
    Some(91) => "["
    Some(93) => "]"
    Some(94) => "^"
    Some(123) => "{"
    Some(124) => "|"
    Some(125) => "}"
    Some(126) => "~"
    _ => ""
  }
}

///|
fn wgsl_import_token_replacement(
  token : WgslToken,
  nodes : Array[WgslImportRewriteNode],
) -> String? {
  for node in nodes {
    if node.start == token.pos() && node.end == token.end() {
      return Some(node.replacement)
    }
  }
  None
}

///|
fn wgsl_import_token_is_wordlike(text : String) -> Bool {
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
fn wgsl_import_emit_needs_space(previous : String, current : String) -> Bool {
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
  if (previous == ")" || previous == ">") &&
    wgsl_import_token_is_wordlike(current) {
    return true
  }
  if previous == "&" && wgsl_import_token_is_wordlike(current) {
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
  wgsl_import_token_is_wordlike(previous) &&
  wgsl_import_token_is_wordlike(current)
}

///|
fn emit_wgsl_import_token_stream_with_nodes(
  input : String,
  nodes : Array[WgslImportRewriteNode],
) -> String {
  let mut out = ""
  let mut previous = ""
  for token in tokenize_wgsl(replace_comments(input), false) {
    let text = match wgsl_import_token_replacement(token, nodes) {
      Some(replacement) => replacement
      None => wgsl_import_token_text(token)
    }
    if text == "" {
      continue
    }
    if wgsl_import_emit_needs_space(previous, text) {
      out = out + " "
    }
    out = out + text
    if text == ";" || text == "}" {
      out = out + "\n"
      previous = "\n"
    } else {
      previous = text
    }
  }
  if out == "" || out.has_suffix("\n") {
    out
  } else {
    "\{out}\n"
  }
}

///|
fn substitute_identifiers(
  input : String,
  offset : Int,
  declared_imports : Array[DeclaredImportBinding],
  used_imports : Array[ImportDefWithOffset],
  allow_ambiguous : Bool,
) -> String raise WgslImportSubstitutionError {
  if declared_imports.length() == 0 {
    return input
  }
  let nodes : Array[WgslImportRewriteNode] = []
  let unit = parse_wgsl_translation_unit_strict(input) catch {
    error => raise substitute_identifiers_wgsl_parse_error(error, offset)
  }
  for decl in unit.declarations() {
    let identifiers : Array[WgslIdent] = []
    collect_wgsl_decl_identifier_nodes(decl.data(), identifiers)
    for ident in identifiers {
      let token_byte_pos = utf8_byte_length(input[:ident.start()].to_owned())
      let replacement = imported_identifier_replacement(
        ident.name(),
        offset + token_byte_pos,
        declared_imports,
        used_imports,
        allow_ambiguous,
      )
      if replacement != ident.name() {
        nodes.push(WgslImportRewriteNode::{
          start: ident.start(),
          end: ident.end(),
          replacement,
        })
      }
    }
  }
  if nodes.length() == 0 {
    return input
  }
  emit_wgsl_import_token_stream_with_nodes(input, nodes)
}

///|
fn substitute_identifiers_wgsl_parse_error(
  error : WgslParseError,
  offset : Int,
) -> WgslImportSubstitutionError {
  match error {
    Parse(message, parse_offset) =>
      InvalidWgslSyntax(message, offset + parse_offset)
    UnparsedDeclaration(text, parse_offset) =>
      InvalidWgslSyntax(
        "declaration could not be parsed: \{text}",
        offset + parse_offset,
      )
  }
}

///|
pub fn WgslImportSubstitutionState::declare_imports(
  self : WgslImportSubstitutionState,
  input : String,
) -> Unit raise ParseImportsError {
  parse_imports(input, self.declared_imports)
}

///|
pub fn WgslImportSubstitutionState::rewrite_source(
  self : WgslImportSubstitutionState,
  input : String,
  offset : Int,
  used_imports : Array[ImportDefWithOffset],
  allow_ambiguous : Bool,
) -> String raise WgslImportSubstitutionError {
  substitute_identifiers(
    input,
    offset,
    self.declared_imports,
    used_imports,
    allow_ambiguous,
  )
}

///|
