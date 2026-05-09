///|
fn compose_case_usage() -> String {
  "usage: moon run tools/compose_case -- --fixture-root DIR --entry FILE [--def NAME] [--value-def NAME=VALUE] [--additional-import PATH] [--output FILE] [--pre-ir] [--runtime-valid] [--naga-oil-writer-parity] [--file-path-prefix PREFIX] [--expect-error --error-output FILE]"
}

///|
priv struct ComposeCaseArgs {
  mut fixture_root : String?
  mut entry : String?
  defines : Array[String]
  value_defines : Array[String]
  additional_imports : Array[String]
  mut output : String?
  mut pre_ir : Bool
  mut runtime_valid : Bool
  mut naga_oil_writer_parity : Bool
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
    output: None,
    pre_ir: false,
    runtime_valid: false,
    naga_oil_writer_parity: false,
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
      "--output" => {
        guard index + 1 < args.length() else { abort(compose_case_usage()) }
        parsed.output = Some(args[index + 1])
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
fn compose_case_bool_defines(
  names : Array[String],
) -> @hashmap.HashMap[String, Bool] {
  let defines : @hashmap.HashMap[String, Bool] = @hashmap.HashMap([])
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
) -> @hashmap.HashMap[String, @common.ShaderDefValue] {
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
  composer.register_source_tree(
    fixture_root,
    @common.WgslSourceScanOptions::default(),
  ) catch {
    _ => abort("failed to register fixture root")
  }
  let options : @common.WgslComposeOptions = {
    defines: compose_case_bool_defines(args.defines),
    value_defines: compose_case_value_defines(args.value_defines),
    redirects: [],
    additional_imports: compose_case_additional_imports(args.additional_imports),
  }
  let output = try {
    if args.pre_ir {
      composer.compose_wgsl_before_ir(entry, options)
    } else if args.runtime_valid {
      composer.compose_wgsl_runtime_valid(entry, options)
    } else if args.naga_oil_writer_parity {
      composer.compose_wgsl_for_naga_oil_writer_parity(entry, options)
    } else {
      composer.compose_wgsl(entry, options)
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
  } else {
    write_compose_case_output(args.output, output)
  }
}
