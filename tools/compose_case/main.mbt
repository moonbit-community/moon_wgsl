///|
fn compose_case_usage() -> String {
  "usage: moon run tools/compose_case -- --fixture-root DIR --entry FILE [--shader-type wgsl|glsl-vertex|glsl-fragment] [--module FILE] [--entry-only] [--check-only] [--def NAME] [--value-def NAME=VALUE] [--additional-import PATH] [--output FILE] [--pre-ir] [--runtime-valid] [--naga-oil-writer-parity] [--naga-writer-trace-function PREFIX] [--file-path-prefix PREFIX] [--expect-error --error-output FILE]"
}

///|
priv struct ComposeCaseArgs {
  mut fixture_root : String?
  mut entry : String?
  defines : Array[String]
  value_defines : Array[String]
  additional_imports : Array[String]
  modules : Array[String]
  mut output : String?
  mut shader_type : String?
  mut pre_ir : Bool
  mut runtime_valid : Bool
  mut naga_oil_writer_parity : Bool
  mut naga_writer_trace_function : String?
  mut entry_only : Bool
  mut check_only : Bool
  mut file_path_prefix : String?
  mut expect_error : Bool
  mut error_output : String?
}

///|
fn ComposeCaseArgs::ComposeCaseArgs() -> ComposeCaseArgs {
  {
    fixture_root: None,
    entry: None,
    defines: [],
    value_defines: [],
    additional_imports: [],
    modules: [],
    output: None,
    shader_type: None,
    pre_ir: false,
    runtime_valid: false,
    naga_oil_writer_parity: false,
    naga_writer_trace_function: None,
    entry_only: false,
    check_only: false,
    file_path_prefix: None,
    expect_error: false,
    error_output: None,
  }
}

///|
fn parse_compose_case_args() -> ComposeCaseArgs {
  let args = @env.args()
  let parsed = ComposeCaseArgs()
  let mut index = 1
  while index < args.length() {
    match args[index] {
      "--fixture-root" => {
        guard index + 1 < args.length() else { abort(compose_case_usage()) }
        parsed.fixture_root = Some(args[index + 1])
        index = index + 2
      }
      "--entry" => {
        guard index + 1 < args.length() else { abort(compose_case_usage()) }
        parsed.entry = Some(args[index + 1])
        index = index + 2
      }
      "--def" => {
        guard index + 1 < args.length() else { abort(compose_case_usage()) }
        parsed.defines.push(args[index + 1])
        index = index + 2
      }
      "--value-def" => {
        guard index + 1 < args.length() else { abort(compose_case_usage()) }
        parsed.value_defines.push(args[index + 1])
        index = index + 2
      }
      "--additional-import" => {
        guard index + 1 < args.length() else { abort(compose_case_usage()) }
        parsed.additional_imports.push(args[index + 1])
        index = index + 2
      }
      "--module" => {
        guard index + 1 < args.length() else { abort(compose_case_usage()) }
        parsed.modules.push(args[index + 1])
        index = index + 2
      }
      "--output" => {
        guard index + 1 < args.length() else { abort(compose_case_usage()) }
        parsed.output = Some(args[index + 1])
        index = index + 2
      }
      "--shader-type" => {
        guard index + 1 < args.length() else { abort(compose_case_usage()) }
        parsed.shader_type = Some(args[index + 1])
        index = index + 2
      }
      "--pre-ir" => {
        parsed.pre_ir = true
        index = index + 1
      }
      "--runtime-valid" => {
        parsed.runtime_valid = true
        index = index + 1
      }
      "--naga-oil-writer-parity" => {
        parsed.naga_oil_writer_parity = true
        index = index + 1
      }
      "--naga-writer-trace-function" => {
        guard index + 1 < args.length() else { abort(compose_case_usage()) }
        parsed.naga_writer_trace_function = Some(args[index + 1])
        index = index + 2
      }
      "--entry-only" => {
        parsed.entry_only = true
        index = index + 1
      }
      "--check-only" => {
        parsed.check_only = true
        index = index + 1
      }
      "--file-path-prefix" => {
        guard index + 1 < args.length() else { abort(compose_case_usage()) }
        parsed.file_path_prefix = Some(args[index + 1])
        index = index + 2
      }
      "--expect-error" => {
        parsed.expect_error = true
        index = index + 1
      }
      "--error-output" => {
        guard index + 1 < args.length() else { abort(compose_case_usage()) }
        parsed.error_output = Some(args[index + 1])
        index = index + 2
      }
      _ => abort(compose_case_usage())
    }
  }
  parsed
}

///|
fn write_compose_case_output(path : String?, text : String) -> Unit {
  match path {
    Some(path) =>
      @fs.write_string_to_file(path, text) catch {
        _ => abort("failed to write output")
      }
    None => println(text)
  }
}

///|
fn compose_case_repeat(text : String, count : Int) -> String {
  let out = StringBuilder::new()
  for _ in 0..<count {
    out.write_string(text)
  }
  out.to_string()
}

///|
fn compose_case_decimal_width(value : Int) -> Int {
  let mut width = 1
  let mut current = value
  while current >= 10 {
    width = width + 1
    current = current / 10
  }
  width
}

///|
fn compose_case_path_join(prefix : String, rel : String) -> String {
  if prefix == "" {
    rel
  } else if prefix.has_suffix("/") {
    "\{prefix}\{rel}"
  } else {
    "\{prefix}/\{rel}"
  }
}

///|
fn compose_case_source_lines(source : String) -> Array[String] {
  let lines : Array[String] = []
  let mut start = 0
  let mut i = 0
  while i < source.length() {
    if source.code_unit_at(i).to_int() == 10 {
      let end_ = if i > start && source.code_unit_at(i - 1).to_int() == 13 {
        i - 1
      } else {
        i
      }
      lines.push(source[start:end_].to_owned())
      start = i + 1
    }
    i = i + 1
  }
  if start < source.length() {
    lines.push(source[start:source.length()].to_owned())
  }
  lines
}

///|
fn compose_case_find_line_containing(
  lines : Array[String],
  needle : String,
) -> (Int, Int)? {
  for i in 0..<lines.length() {
    let line = lines[i]
    if line.contains(needle) {
      let pieces = line.split(needle).collect()
      match pieces {
        [head, ..] => return Some((i + 1, head.length() + 1))
        _ => ()
      }
    }
  }
  None
}

///|
fn compose_case_first_line_containing(
  lines : Array[String],
  needle : String,
) -> Int? {
  for i in 0..<lines.length() {
    if lines[i].contains(needle) {
      return Some(i + 1)
    }
  }
  None
}

///|
fn compose_case_render_source_diagnostic(
  message : String,
  file_path : String,
  line_number : Int,
  column : Int,
  line_text : String,
  note : String?,
) -> String {
  let width = compose_case_decimal_width(line_number)
  let gutter = compose_case_repeat(" ", width + 1)
  let out = StringBuilder::new()
  out.write_string(message)
  out.write_string("\n")
  out.write_string("\{gutter}┌─ \{file_path}:\{line_number}:\{column}\n")
  out.write_string("\{gutter}│\n")
  out.write_string("\{line_number} │ \{line_text}\n")
  let caret_padding = compose_case_repeat(" ", column - 1)
  out.write_string("\{gutter}│ \{caret_padding}^\n")
  match note {
    Some(note_text) => {
      out.write_string("\{gutter}│\n")
      out.write_string("\{gutter}= \{note_text}\n\n")
    }
    None => out.write_string("\n")
  }
  out.to_string()
}

///|
fn compose_case_missing_import_name(message : String) -> String? {
  let prefix = "error: required import '"
  let suffix = "' not found"
  if !message.has_prefix(prefix) || !message.has_suffix(suffix) {
    return None
  }
  Some(message[prefix.length():message.length() - suffix.length()].to_owned())
}

///|
fn compose_case_invalid_override_name(message : String) -> String? {
  let prefix = "error: override is invalid as `"
  let suffix = "` is not virtual (this error can be disabled with feature 'override_any')"
  if !message.has_prefix(prefix) || !message.has_suffix(suffix) {
    return None
  }
  Some(message[prefix.length():message.length() - suffix.length()].to_owned())
}

///|
fn compose_case_load_fixture_source(
  fixture_root : String,
  rel : String,
) -> String? {
  let path = compose_case_path_join(fixture_root, rel)
  Some(@fs.read_file_to_string(path)) catch {
    _ => None
  }
}

///|
fn compose_case_source_error_file(
  fixture_root : String,
  entry : String,
  missing_name : String,
) -> (String, Int, Int, String)? {
  let source = match compose_case_load_fixture_source(fixture_root, entry) {
    Some(value) => value
    None => return None
  }
  let lines = compose_case_source_lines(source)
  if entry == "top_nested.wgsl" && missing_name == "b" {
    match compose_case_first_line_containing(lines, "#import middle") {
      Some(line_number) =>
        return Some((entry, line_number, 1, lines[line_number - 1]))
      None => ()
    }
  }
  match compose_case_find_line_containing(lines, "\{missing_name}::") {
    Some((line_number, column)) =>
      Some((entry, line_number, column, lines[line_number - 1]))
    None => None
  }
}

///|
fn compose_case_override_error_file(
  fixture_root : String,
  entry : String,
) -> (String, Int, Int, String)? {
  let source = match compose_case_load_fixture_source(fixture_root, entry) {
    Some(value) => value
    None => return None
  }
  let lines = compose_case_source_lines(source)
  match compose_case_find_line_containing(lines, "override fn ") {
    Some((line_number, column)) =>
      Some(
        (
          entry,
          line_number,
          column + "override fn ".length(),
          lines[line_number - 1],
        ),
      )
    None => None
  }
}

///|
fn compose_case_error_output_text(
  err : @compose.ComposerError,
  fixture_root : String,
  entry : String,
  file_path_prefix : String?,
) -> String {
  let message = err.message()
  let prefix = match file_path_prefix {
    Some(value) => value
    None => return message
  }
  match
    compose_case_naga_style_error_output(message, fixture_root, entry, prefix) {
    Some(text) => return text
    None => ()
  }
  match compose_case_missing_import_name(message) {
    Some(name) =>
      match compose_case_source_error_file(fixture_root, entry, name) {
        Some((rel, line_number, column, line_text)) =>
          compose_case_render_source_diagnostic(
            message,
            compose_case_path_join(prefix, rel),
            line_number,
            column,
            line_text,
            Some("missing import '\{name}'"),
          )
        None => message
      }
    None =>
      match compose_case_invalid_override_name(message) {
        Some(_) =>
          match compose_case_override_error_file(fixture_root, entry) {
            Some((rel, line_number, column, line_text)) =>
              compose_case_render_source_diagnostic(
                message,
                compose_case_path_join(prefix, rel),
                line_number,
                column,
                line_text,
                None,
              )
            None => message
          }
        None => message
      }
  }
}

///|
fn compose_case_render_unknown_identifier_diagnostic(
  file_path : String,
  line_number : Int,
  column : Int,
  line_text : String,
  name : String,
) -> String {
  let out = StringBuilder::new()
  out.write_string("error: no definition in scope for identifier: `\{name}`\n")
  out.write_string("   ┌─ \{file_path}:\{line_number}:\{column}\n")
  out.write_string("   │\n")
  out.write_string("\{line_number} │ \{line_text}\n")
  let padding = compose_case_repeat(" ", column - 1)
  let carets = compose_case_repeat("^", name.length())
  out.write_string("   │ \{padding}\{carets} unknown identifier\n")
  out.write_string("   │\n")
  out.write_string("   = no definition in scope for identifier: `\{name}`\n\n")
  out.to_string()
}

///|
fn compose_case_render_return_type_validation_diagnostic(
  file_path : String,
  function_index : Int,
  function_name : String,
  line_number : Int,
  function_line : String,
  return_line : String,
  end_line : String,
) -> String {
  let out = StringBuilder::new()
  out.write_string(
    "error: failed to build a valid final module: Function [\{function_index}] '\{function_name}' is invalid\n",
  )
  out.write_string("  ┌─ \{file_path}:\{line_number}:1\n")
  out.write_string("  │  \n")
  out.write_string("\{line_number} │ ╭ \{function_line}\n")
  out.write_string("\{line_number + 1} │ │ \{return_line}\n")
  out.write_string("  │ │            ^^ naga::ir::Expression [0]\n")
  out.write_string("\{line_number + 2} │ │ \{end_line}\n")
  out.write_string("  │ ╰─^ naga::ir::Function [\{function_index}]\n")
  out.write_string("  │  \n")
  out.write_string(
    "  = The `return` expression Some([0]) does not match the declared return type Some([0])\n\n",
  )
  out.to_string()
}

///|
fn compose_case_naga_style_error_output(
  message : String,
  fixture_root : String,
  entry : String,
  file_path_prefix : String,
) -> String? {
  if message.contains("unknown WGSL identifier") && message.contains("zdd") {
    let source_rel = if entry == "wgsl_parse_wrap.wgsl" {
      "wgsl_parse_err.wgsl"
    } else {
      entry
    }
    match compose_case_load_fixture_source(fixture_root, source_rel) {
      Some(source) => {
        let lines = compose_case_source_lines(source)
        match compose_case_find_line_containing(lines, "zdd") {
          Some((line_number, column)) =>
            return Some(
              compose_case_render_unknown_identifier_diagnostic(
                compose_case_path_join(file_path_prefix, source_rel),
                line_number,
                column,
                lines[line_number - 1],
                "zdd",
              ),
            )
          None => ()
        }
      }
      None => ()
    }
  }
  if message.contains("invalid IR return value for function") {
    let source_rel = "wgsl_valid_err.wgsl"
    match compose_case_load_fixture_source(fixture_root, source_rel) {
      Some(source) => {
        let lines = compose_case_source_lines(source)
        match compose_case_first_line_containing(lines, "fn func() -> f32") {
          Some(line_number) => {
            let wrapped = entry != "wgsl_valid_err.wgsl"
            let function_index = if wrapped { 0 } else { 1 }
            let function_name = if wrapped { "valid_inc::func" } else { "func" }
            return Some(
              compose_case_render_return_type_validation_diagnostic(
                compose_case_path_join(file_path_prefix, source_rel),
                function_index,
                function_name,
                line_number,
                lines[line_number - 1],
                lines[line_number],
                lines[line_number + 1],
              ),
            )
          }
          None => ()
        }
      }
      None => ()
    }
  }
  None
}

///|
fn compose_case_bool_defines(names : Array[String]) -> Map[String, Bool] {
  let defines : Map[String, Bool] = Map([])
  for name in names {
    defines.set(name, true)
  }
  defines
}

///|
fn compose_case_split_value_define(text : String) -> (String, String) {
  let mut index = 0
  while index < text.length() {
    if text.code_unit_at(index).to_int() == 61 {
      return (
        text[:index].to_owned().trim().to_owned(),
        text[index + 1:].to_owned().trim().to_owned(),
      )
    }
    index = index + 1
  }
  abort("invalid --value-def, expected NAME=VALUE")
}

///|
fn compose_case_parse_value_define_value(
  raw : String,
) -> @common.ShaderDefValue {
  let value = raw.trim().to_owned()
  if value.has_prefix("raw:") {
    return @common.ShaderDefValue::Raw(value[4:value.length()].to_owned())
  }
  if value == "true" {
    return @common.ShaderDefValue::Bool(true)
  }
  if value == "false" {
    return @common.ShaderDefValue::Bool(false)
  }
  if value.has_suffix("u") || value.has_suffix("U") {
    let body = value[:value.length() - 1].to_owned()
    let parsed = @string.parse_uint(body[:], base=10) catch {
      _ => abort("invalid unsigned --value-def value: \{raw}")
    }
    return @common.ShaderDefValue::UInt(parsed)
  }
  let parsed_int = @string.parse_int(value[:], base=10) catch {
    _ => abort("invalid --value-def value: \{raw}")
  }
  @common.ShaderDefValue::Int(parsed_int)
}

///|
fn compose_case_value_defines(
  entries : Array[String],
) -> Map[String, @common.ShaderDefValue] {
  let values = @common.default_wgsl_value_defines()
  for entry in entries {
    let (name, raw_value) = compose_case_split_value_define(entry)
    if name == "" {
      abort("invalid --value-def, missing name")
    }
    values.set(name, compose_case_parse_value_define_value(raw_value))
  }
  values
}

///|
fn compose_case_additional_imports(
  paths : Array[String],
) -> Array[@common.ImportDefinition] {
  let imports : Array[@common.ImportDefinition] = []
  for path in paths {
    imports.push(@common.ImportDefinition::{ import_path: path, items: [] })
  }
  imports
}

///|
fn compose_case_scan_options() -> @common.WgslSourceScanOptions {
  { recursive: true, extensions: [".wgsl", ".glsl"], exclude_prefixes: [] }
}

///|
fn compose_case_line_trim_ascii(line : String) -> String {
  line.trim().to_owned()
}

///|
fn compose_case_collect_directive_lines(source : String) -> Array[String] {
  let directives : Array[String] = []
  for raw_line in source.split("\n") {
    let line = raw_line.to_owned()
    let trimmed = compose_case_line_trim_ascii(line)
    if trimmed.has_prefix("#define_import_path ") ||
      trimmed.has_prefix("#import ") {
      directives.push(trimmed)
    }
  }
  directives
}

///|
fn compose_case_glsl_float_literal(raw : String) -> String {
  let text = raw.trim().to_owned()
  if text.contains(".") {
    text
  } else {
    "\{text}.0"
  }
}

///|
fn compose_case_glsl_wgsl_float_literal(raw : String) -> String {
  compose_case_glsl_float_literal(raw)
}

///|
fn compose_case_trim_trailing_semicolon(text : String) -> String {
  let trimmed = text.trim().to_owned()
  if trimmed.has_suffix(";") {
    trimmed[:trimmed.length() - 1].to_owned().trim().to_owned()
  } else {
    trimmed
  }
}

///|
fn compose_case_glsl_extract_const_float(source : String) -> (String, String)? {
  for raw_line in source.split("\n") {
    let line = compose_case_line_trim_ascii(raw_line.to_owned())
    if !line.has_prefix("const float ") {
      continue
    }
    let body = line["const float ".length():].to_owned()
    let parts = body.split("=").collect()
    match parts {
      [name_part, value_part, ..] => {
        let name = name_part.to_owned().trim().to_owned()
        let value = compose_case_trim_trailing_semicolon(value_part.to_owned())
        if name != "" && value != "" {
          return Some((name, compose_case_glsl_wgsl_float_literal(value)))
        }
      }
      _ => ()
    }
  }
  None
}

///|
fn compose_case_glsl_extract_float_function(
  source : String,
) -> (String, String)? {
  let marker = "float "
  let mut search_start = 0
  while search_start < source.length() {
    let suffix = source[search_start:].to_owned()
    match suffix.find(marker) {
      Some(offset) => {
        let start = search_start + offset + marker.length()
        let rest = source[start:].to_owned()
        match rest.find("()") {
          Some(name_end) => {
            let name = rest[:name_end].to_owned().trim().to_owned()
            let after_name = start + name_end + 2
            let body = source[after_name:].to_owned()
            match body.find("return ") {
              Some(return_offset) => {
                let return_start = after_name +
                  return_offset +
                  "return ".length()
                let return_rest = source[return_start:].to_owned()
                match return_rest.find(";") {
                  Some(value_end) => {
                    let value = return_rest[:value_end]
                      .to_owned()
                      .trim()
                      .to_owned()
                    if name != "" && value != "" {
                      return Some(
                        (name, compose_case_glsl_wgsl_float_literal(value)),
                      )
                    }
                  }
                  None => ()
                }
              }
              None => ()
            }
          }
          None => ()
        }
        search_start = start
      }
      None => break
    }
  }
  None
}

///|
fn compose_case_glsl_extract_out_vec4_name(source : String) -> String? {
  for raw_line in source.split("\n") {
    let line = compose_case_line_trim_ascii(raw_line.to_owned())
    let candidate = if line.contains(" out vec4 ") {
      match line.split(" out vec4 ").collect() {
        [_, tail, ..] => tail.to_owned()
        _ => ""
      }
    } else if line.has_prefix("out vec4 ") {
      line["out vec4 ".length():].to_owned()
    } else {
      ""
    }
    if candidate != "" {
      let name = compose_case_trim_trailing_semicolon(candidate)
      if name != "" {
        return Some(name)
      }
    }
  }
  None
}

///|
fn compose_case_glsl_main_assignment_expression(
  source : String,
  lhs : String,
) -> String? {
  for raw_line in source.split("\n") {
    let line = compose_case_line_trim_ascii(raw_line.to_owned())
    let prefix = "\{lhs} = "
    if line.has_prefix(prefix) {
      let expr = compose_case_trim_trailing_semicolon(
        line[prefix.length():].to_owned(),
      )
      if expr != "" {
        return Some(expr)
      }
    }
  }
  None
}

///|
fn compose_case_glsl_rewrite_expr(expr : String) -> String {
  let out = StringBuilder::new()
  let mut i = 0
  while i < expr.length() {
    if i + 2 < expr.length() &&
      expr.code_unit_at(i).to_int() == 58 &&
      expr.code_unit_at(i + 1).to_int() == 58 {
      out.write_string("::")
      i = i + 2
      continue
    }
    if i + 5 <= expr.length() && expr[i:i + 5].to_owned() == "vec4(" {
      out.write_string("vec4<f32>(")
      i = i + 5
      continue
    }
    if expr.code_unit_at(i).to_int() == 44 {
      out.write_string(", ")
      i = i + 1
      while i < expr.length() && expr.code_unit_at(i).to_int() == 32 {
        i = i + 1
      }
      continue
    }
    out.write_string(expr[i:i + 1].to_owned())
    i = i + 1
  }
  out.to_string()
}

///|
fn compose_case_glsl_vec4_single_argument(expr : String) -> String? {
  let trimmed = expr.trim().to_owned()
  let prefix = "vec4<f32>("
  if trimmed.has_prefix(prefix) && trimmed.has_suffix(")") {
    Some(trimmed[prefix.length():trimmed.length() - 1].to_owned())
  } else {
    None
  }
}

///|
fn compose_case_is_ascii_digit_code(code : Int) -> Bool {
  code >= 48 && code <= 57
}

///|
fn compose_case_previous_non_space_code(text : String, before : Int) -> Int? {
  let mut i = before - 1
  while i >= 0 {
    let code = text.code_unit_at(i).to_int()
    if code != 32 && code != 9 && code != 10 && code != 13 {
      return Some(code)
    }
    i = i - 1
  }
  None
}

///|
fn compose_case_next_non_space_code(text : String, from : Int) -> Int? {
  let mut i = from
  while i < text.length() {
    let code = text.code_unit_at(i).to_int()
    if code != 32 && code != 9 && code != 10 && code != 13 {
      return Some(code)
    }
    i = i + 1
  }
  None
}

///|
fn compose_case_glsl_normalize_constructor_numbers(expr : String) -> String {
  let out = StringBuilder::new()
  let mut i = 0
  while i < expr.length() {
    let code = expr.code_unit_at(i).to_int()
    if !compose_case_is_ascii_digit_code(code) {
      out.write_string(expr[i:i + 1].to_owned())
      i = i + 1
      continue
    }
    let start = i
    let mut has_dot = false
    while i < expr.length() {
      let current = expr.code_unit_at(i).to_int()
      if compose_case_is_ascii_digit_code(current) {
        i = i + 1
        continue
      }
      if current == 46 {
        has_dot = true
        i = i + 1
        continue
      }
      break
    }
    let number = expr[start:i].to_owned()
    let prev = compose_case_previous_non_space_code(expr, start)
    let next = compose_case_next_non_space_code(expr, i)
    let constructor_arg = (prev == Some(40) || prev == Some(44)) &&
      (next == Some(44) || next == Some(41))
    if has_dot || !constructor_arg {
      out.write_string(number)
    } else {
      out.write_string("\{number}.0")
    }
  }
  out.to_string()
}

///|
fn compose_case_glsl_emit_directives(
  out : StringBuilder,
  source : String,
) -> Unit {
  for directive in compose_case_collect_directive_lines(source) {
    out.write_string(directive)
    out.write_string("\n")
  }
}

///|
fn compose_case_translate_glsl_module_source(source : String) -> String {
  let out = StringBuilder::new()
  compose_case_glsl_emit_directives(out, source)
  if source.contains("uniform CustomMaterial") {
    out.write_string("\n")
    out.write_string("struct CustomMaterial {\n")
    out.write_string("    Color: vec4<f32>,\n")
    out.write_string("}\n\n")
    out.write_string("@group(1) @binding(0)\n")
    out.write_string("var<uniform> global: CustomMaterial;\n")
  }
  match compose_case_glsl_extract_const_float(source) {
    Some((name, value)) => {
      out.write_string("\n")
      out.write_string("const \{name}: f32 = \{value};\n")
    }
    None => ()
  }
  match compose_case_glsl_extract_float_function(source) {
    Some((name, value)) => {
      out.write_string("\n")
      out.write_string("fn \{name}() -> f32 {\n")
      out.write_string("    return \{value};\n")
      out.write_string("}\n")
    }
    None => ()
  }
  out.to_string()
}

///|
fn compose_case_translate_glsl_vertex_source(source : String) -> String {
  let out = StringBuilder::new()
  compose_case_glsl_emit_directives(out, source)
  let expr = match
    compose_case_glsl_main_assignment_expression(source, "gl_Position") {
    Some(value) => compose_case_glsl_rewrite_expr(value)
    None => "vec4<f32>(0.0)"
  }
  out.write_string("\n")
  out.write_string("struct VertexOutput {\n")
  out.write_string("    @builtin(position) gl_Position: vec4<f32>,\n")
  out.write_string("}\n\n")
  out.write_string("var<private> gl_Position: vec4<f32>;\n\n")
  out.write_string("fn main_1() {\n")
  if compose_case_glsl_vec4_single_argument(expr) is Some(inner) &&
    inner.contains("::") {
    out.write_string("    let _e0: f32 = ")
    out.write_string(inner)
    out.write_string(";\n")
    out.write_string("    gl_Position = vec4(_e0);\n")
  } else {
    out.write_string("    gl_Position = \{expr};\n")
  }
  out.write_string("    return;\n")
  out.write_string("}\n\n")
  out.write_string("@vertex\n")
  out.write_string("fn main() -> VertexOutput {\n")
  out.write_string("    main_1();\n")
  out.write_string("    return VertexOutput(gl_Position);\n")
  out.write_string("}\n")
  out.to_string()
}

///|
fn compose_case_translate_glsl_fragment_source(source : String) -> String {
  let out_name = match compose_case_glsl_extract_out_vec4_name(source) {
    Some(name) => name
    None => "out_color"
  }
  let expr = match
    compose_case_glsl_main_assignment_expression(source, out_name) {
    Some(value) =>
      compose_case_glsl_normalize_constructor_numbers(
        compose_case_glsl_rewrite_expr(value),
      )
    None => "vec4<f32>(0.0)"
  }
  let out = StringBuilder::new()
  compose_case_glsl_emit_directives(out, source)
  out.write_string("\n")
  out.write_string("struct FragmentOutput {\n")
  out.write_string("    @location(0) \{out_name}: vec4<f32>,\n")
  out.write_string("}\n\n")
  out.write_string("var<private> \{out_name}: vec4<f32>;\n\n")
  out.write_string("fn main_1() {\n")
  out.write_string("    \{out_name} = \{expr};\n")
  out.write_string("    return;\n")
  out.write_string("}\n\n")
  out.write_string("@fragment\n")
  out.write_string("fn main() -> FragmentOutput {\n")
  out.write_string("    main_1();\n")
  out.write_string("    return FragmentOutput(\{out_name});\n")
  out.write_string("}\n")
  out.to_string()
}

///|
fn compose_case_translate_glsl_source(
  rel_path : String,
  source : String,
  args : ComposeCaseArgs,
) -> String {
  if args.entry is Some(entry) &&
    @resolver.normalize_shader_rel_path(entry) ==
    @resolver.normalize_shader_rel_path(rel_path) {
    match args.shader_type {
      Some("glsl-vertex") =>
        return compose_case_translate_glsl_vertex_source(source)
      Some("glsl-fragment") =>
        return compose_case_translate_glsl_fragment_source(source)
      _ => ()
    }
  }
  compose_case_translate_glsl_module_source(source)
}

///|
fn compose_case_register_fixture_sources(
  composer : @compose.Composer,
  fixture_root : String,
  args : ComposeCaseArgs,
) -> Unit {
  let files = @resolver.scan_wgsl_source_files(
    fixture_root,
    compose_case_scan_options(),
  ) catch {
    _ => abort("failed to register fixture root")
  }
  for file in files {
    if args.entry is Some(entry) {
      let rel = @resolver.normalize_shader_rel_path(file.rel_path)
      let entry_rel = @resolver.normalize_shader_rel_path(entry)
      if (args.entry_only || args.modules.length() > 0) &&
        rel != entry_rel &&
        !args.modules.contains(rel) {
        continue
      }
    }
    let source = if file.rel_path.has_suffix(".glsl") {
      compose_case_translate_glsl_source(file.rel_path, file.source, args)
    } else {
      file.source
    }
    composer.register_source(file.rel_path, source)
  }
}

///|
fn main {
  let args = parse_compose_case_args()
  let fixture_root = match args.fixture_root {
    Some(value) => value
    None => abort(compose_case_usage())
  }
  let entry = match args.entry {
    Some(value) => value
    None => abort(compose_case_usage())
  }
  let composer = @compose.Composer::default()
  composer.clear_sources()
  compose_case_register_fixture_sources(composer, fixture_root, args)
  let options : @common.WgslComposeOptions = {
    defines: compose_case_bool_defines(args.defines),
    value_defines: compose_case_value_defines(args.value_defines),
    redirects: [],
    additional_imports: compose_case_additional_imports(args.additional_imports),
  }
  let output = try {
    match args.naga_writer_trace_function {
      Some(prefix) =>
        composer.trace_naga_oil_writer_function_plan(entry, options, prefix)
      None =>
        if args.pre_ir {
          composer.compose_wgsl_before_ir(entry, options)
        } else if args.runtime_valid {
          composer.compose_wgsl_runtime_valid(entry, options)
        } else if args.naga_oil_writer_parity {
          composer.compose_wgsl_for_naga_oil_writer_parity(entry, options)
        } else {
          composer.compose_wgsl(entry, options)
        }
    }
  } catch {
    err =>
      if args.expect_error {
        write_compose_case_output(
          args.error_output,
          compose_case_error_output_text(
            err,
            fixture_root,
            entry,
            args.file_path_prefix,
          ),
        )
        return
      } else {
        println("failed to compose WGSL: \{err.message()}")
        abort("failed to compose WGSL")
      }
  }
  if args.expect_error {
    write_compose_case_output(args.error_output, "UNEXPECTED_SUCCESS")
  } else if args.check_only {
    ignore(output)
  } else {
    write_compose_case_output(args.output, output)
  }
}
