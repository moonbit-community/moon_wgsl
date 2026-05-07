///|
fn compose_case_usage() -> String {
  "usage: moon run tools/compose_case -- --fixture-root DIR --entry FILE [--def NAME] [--additional-import PATH] [--ir]"
}

///|
priv struct ComposeCaseArgs {
  mut fixture_root : String?
  mut entry : String?
  defines : Array[String]
  additional_imports : Array[String]
  mut output : String?
  mut ir : Bool
}

///|
fn ComposeCaseArgs::ComposeCaseArgs() -> ComposeCaseArgs {
  {
    fixture_root: None,
    entry: None,
    defines: [],
    additional_imports: [],
    output: None,
    ir: false,
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
      "--ir" => {
        parsed.ir = true
        index = index + 1
      }
      _ => abort(compose_case_usage())
    }
  }
  parsed
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
    value_defines: @common.default_wgsl_value_defines(),
    redirects: [],
    additional_imports: compose_case_additional_imports(args.additional_imports),
  }
  let output = try {
    if args.ir {
      composer.compose_wgsl_ir(entry, options)
    } else {
      composer.compose_wgsl(entry, options)
    }
  } catch {
    err => {
      println("failed to compose WGSL: \{err.message()}")
      abort("failed to compose WGSL")
    }
  }
  match args.output {
    Some(path) =>
      @fs.write_string_to_file(path, output) catch {
        _ => abort("failed to write output")
      }
    None => println(output)
  }
}
