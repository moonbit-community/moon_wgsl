///|
fn compose_case_usage() -> String {
  "usage: moon run tools/compose_case -- --fixture-root DIR --entry FILE [--def NAME] [--value-def NAME=VALUE] [--additional-import PATH] [--output FILE] [--expect-error --error-output FILE]"
}

///|
priv struct ComposeCaseArgs {
  mut fixture_root : String?
  mut entry : String?
  defines : Array[String]
  value_defines : Array[String]
  additional_imports : Array[String]
  mut output : String?
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
  let output = composer.compose_wgsl(entry, options) catch {
    err =>
      if args.expect_error {
        write_compose_case_output(args.error_output, err.message())
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
