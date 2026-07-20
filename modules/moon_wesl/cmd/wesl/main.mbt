// Copyright 2026 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
struct CliRunResult {
  status : Int
  stdout : String
  stdout_bytes : Bytes?
  stderr : String
} derive(Eq, Debug)

///|
struct CliCompArgs {
  mangler : @moon_wesl.ManglerKind
  sourcemap : Bool
  imports : Bool
  condcomp : Bool
  generics : Bool
  strip : Bool
  lower : Bool
  validate : Bool
  lazy_resolution : Bool
  mangle_root : Bool
  keep : Array[String]?
  keep_root : Bool
  feature_default : @moon_wesl.Feature
  features : Array[(String, @moon_wesl.Feature)]
  base : String?
} derive(Debug)

///|
fn CliCompArgs::default() -> CliCompArgs {
  {
    mangler: Escape,
    sourcemap: true,
    imports: true,
    condcomp: true,
    generics: false,
    strip: true,
    lower: false,
    validate: true,
    lazy_resolution: true,
    mangle_root: false,
    keep: None,
    keep_root: false,
    feature_default: Disable,
    features: [],
    base: None,
  }
}

///|
fn CliCompArgs::compile_options(
  self : CliCompArgs,
) -> @moon_wesl.CompileOptions {
  let mut options = @moon_wesl.CompileOptions::default()
    .with_imports(self.imports)
    .with_condcomp(self.condcomp)
    .with_generics(self.generics)
    .with_strip(self.strip)
    .with_lower(self.lower)
    .with_validate(self.validate)
    .with_lazy(self.lazy_resolution)
    .with_mangle_root(self.mangle_root)
    .with_keep_root(self.keep_root)
    .set_missing_feature_behavior(self.feature_default)
  match self.keep {
    Some(keep) => options = options.keep_declarations(keep)
    None => ()
  }
  for entry in self.features {
    let (name, value) = entry
    options = options.set_feature(name, value)
  }
  options
}

///|
fn cli_ok(stdout : String) -> CliRunResult {
  { status: 0, stdout, stdout_bytes: None, stderr: "" }
}

///|
fn cli_ok_bytes(stdout : Bytes) -> CliRunResult {
  { status: 0, stdout: "", stdout_bytes: Some(stdout), stderr: "" }
}

///|
fn cli_err(message : String) -> CliRunResult {
  { status: 1, stdout: "", stdout_bytes: None, stderr: message }
}

///|
fn cli_usage() -> String {
  "Commands:\n  check    Check correctness of the source file\n  compile  Compile a WESL source file\n  eval     Evaluate a const-expression\n  exec     Execute a WGSL shader function on the CPU\n  package  Generate package artifact code\n  help     Print this message or command help"
}

///|
fn cli_compile_usage() -> String {
  "Usage: wesl compile [OPTIONS] [FILE]"
}

///|
fn cli_check_usage() -> String {
  "Usage: wesl check [--kind wesl|wgsl] [--naga] [FILE]"
}

///|
fn cli_eval_usage() -> String {
  "Usage: wesl eval [OPTIONS] [--file FILE] EXPR"
}

///|
fn cli_exec_usage() -> String {
  "Usage: wesl exec [OPTIONS] [--entrypoint NAME] [FILE]"
}

///|
fn cli_package_usage() -> String {
  "Usage: wesl package NAME DIR"
}

///|
fn cli_parse_mangler(value : String) -> Result[@moon_wesl.ManglerKind, String] {
  match value {
    "escape" => Ok(Escape)
    "hash" => Ok(Hash)
    "unicode" => Ok(Unicode)
    "none" => Ok(None)
    _ => Err("invalid mangler `\{value}`")
  }
}

///|
fn cli_parse_feature(value : String) -> Result[@moon_wesl.Feature, String] {
  match value {
    "enable" | "true" => Ok(Enable)
    "disable" | "false" => Ok(Disable)
    "keep" => Ok(Keep)
    "error" => Ok(Error)
    _ => Err("invalid feature value `\{value}`")
  }
}

///|
fn cli_parse_feature_assignment(
  text : String,
) -> Result[(String, @moon_wesl.Feature), String] {
  let mut eq = -1
  for i in 0..<text.length() {
    if text.code_unit_at(i).to_int() == 61 {
      eq = i
      break
    }
  }
  if eq < 0 {
    Ok((text, Enable))
  } else {
    let name = text[:eq].to_owned()
    let value_text = text[eq + 1:].to_owned()
    match cli_parse_feature(value_text) {
      Ok(value) => Ok((name, value))
      Err(err) => Err(err)
    }
  }
}

///|
fn cli_parse_override_assignment(
  text : String,
) -> Result[@moon_wesl.OverrideValue, String] {
  let mut eq = -1
  for i in 0..<text.length() {
    if text.code_unit_at(i).to_int() == 61 {
      eq = i
      break
    }
  }
  if eq < 0 {
    Err("expected override assignment NAME=EXPRESSION")
  } else {
    let name = text[:eq].to_owned()
    let value = text[eq + 1:].to_owned()
    if name.trim().to_owned() == "" || value.trim().to_owned() == "" {
      Err("expected override assignment NAME=EXPRESSION")
    } else {
      Ok({ name, value })
    }
  }
}

///|
fn cli_parse_resource_binding(
  text : String,
) -> Result[@moon_wesl.ResourceBinding, String] {
  let parts : Array[String] = []
  for part in text.split(":") {
    parts.push(part.to_owned())
  }
  if parts.length() != 4 {
    return Err("expected resource binding GROUP:BINDING:TYPE:PATH")
  }
  let group = @string.parse_int(parts[0][:]) catch {
    _ => return Err("invalid resource group `\{parts[0]}`")
  }
  let binding = @string.parse_int(parts[1][:]) catch {
    _ => return Err("invalid resource binding `\{parts[1]}`")
  }
  let kind = parts[2]
  match kind {
    "uniform" | "storage" | "read-only-storage" => ()
    _ => return Err("unsupported resource binding type `\{kind}`")
  }
  let data = @fs.read_file_to_bytes(parts[3]) catch {
    err => return Err(@debug.to_string(err))
  }
  Ok({ group, binding, kind, data })
}

///|
fn cli_take_arg(
  args : ArrayView[String],
  index : Int,
  flag : String,
) -> Result[String, String] {
  if index + 1 >= args.length() {
    Err("expected value after \{flag}")
  } else {
    Ok(args[index + 1])
  }
}

///|
fn cli_parse_common_args(
  args : ArrayView[String],
) -> Result[(CliCompArgs, Array[String]), String] {
  let keep : Array[String] = []
  let features : Array[(String, @moon_wesl.Feature)] = []
  let positionals : Array[String] = []
  let mut opts = CliCompArgs::default()
  let mut index = 0
  while index < args.length() {
    let arg = args[index]
    match arg {
      "--mangler" => {
        let value = match cli_take_arg(args, index, arg) {
          Ok(value) => value
          Err(err) => return Err(err)
        }
        let mangler = match cli_parse_mangler(value) {
          Ok(value) => value
          Err(err) => return Err(err)
        }
        opts = { ..opts, mangler, }
        index = index + 2
      }
      "--no-sourcemap" => {
        opts = { ..opts, sourcemap: false }
        index = index + 1
      }
      "--no-imports" => {
        opts = { ..opts, imports: false }
        index = index + 1
      }
      "--no-cond-comp" => {
        opts = { ..opts, condcomp: false }
        index = index + 1
      }
      "--generics" => {
        opts = { ..opts, generics: true }
        index = index + 1
      }
      "--no-strip" => {
        opts = { ..opts, strip: false }
        index = index + 1
      }
      "--lower" => {
        opts = { ..opts, lower: true }
        index = index + 1
      }
      "--no-validate" => {
        opts = { ..opts, validate: false }
        index = index + 1
      }
      "--eager" => {
        opts = { ..opts, lazy_resolution: false }
        index = index + 1
      }
      "--mangle-root" => {
        opts = { ..opts, mangle_root: true }
        index = index + 1
      }
      "--keep" => {
        match cli_take_arg(args, index, arg) {
          Ok(value) => keep.push(value)
          Err(err) => return Err(err)
        }
        index = index + 2
      }
      "--keep-root" => {
        opts = { ..opts, keep_root: true }
        index = index + 1
      }
      "-D" | "--feature" => {
        let feature_text = match cli_take_arg(args, index, arg) {
          Ok(value) => value
          Err(err) => return Err(err)
        }
        match cli_parse_feature_assignment(feature_text) {
          Ok(value) => features.push(value)
          Err(err) => return Err(err)
        }
        index = index + 2
      }
      "--feature-default" => {
        let feature_text = match cli_take_arg(args, index, arg) {
          Ok(value) => value
          Err(err) => return Err(err)
        }
        let feature_default = match cli_parse_feature(feature_text) {
          Ok(value) => value
          Err(err) => return Err(err)
        }
        opts = { ..opts, feature_default, }
        index = index + 2
      }
      "--base" => {
        match cli_take_arg(args, index, arg) {
          Ok(value) => opts = { ..opts, base: Some(value) }
          Err(err) => return Err(err)
        }
        index = index + 2
      }
      "--no-naga" => index = index + 1
      _ => {
        if arg.has_prefix("--") {
          return Err("unknown option `\{arg}`")
        }
        positionals.push(arg)
        index = index + 1
      }
    }
  }
  if keep.length() > 0 {
    opts = { ..opts, keep: Some(keep) }
  }
  if features.length() > 0 {
    opts = { ..opts, features, }
  }
  Ok((opts, positionals))
}

///|
fn cli_normalize_path(path : String) -> String {
  path.replace_all(old="\\", new="/")
}

///|
fn cli_dirname(path : String) -> String {
  let normalized = cli_normalize_path(path)
  let mut slash = -1
  for i in 0..<normalized.length() {
    if normalized.code_unit_at(i).to_int() == 47 {
      slash = i
    }
  }
  if slash < 0 {
    "."
  } else if slash == 0 {
    "/"
  } else {
    normalized[:slash].to_owned()
  }
}

///|
fn cli_basename(path : String) -> String {
  let normalized = cli_normalize_path(path)
  let mut slash = -1
  for i in 0..<normalized.length() {
    if normalized.code_unit_at(i).to_int() == 47 {
      slash = i
    }
  }
  normalized[slash + 1:].to_owned()
}

///|
fn cli_stem(path : String) -> String {
  let base = cli_basename(path)
  let mut dot = -1
  for i in 0..<base.length() {
    if base.code_unit_at(i).to_int() == 46 {
      dot = i
    }
  }
  if dot < 0 {
    base
  } else {
    base[:dot].to_owned()
  }
}

///|
fn cli_compile_file(
  file : String,
  options : CliCompArgs,
) -> Result[@moon_wesl.CompileResult, String] {
  let base = options.base.unwrap_or(cli_dirname(file))
  let stem = cli_stem(file)
  if stem == "" {
    return Err("input file not found")
  }
  let root = @moon_wesl.ModulePath::from_path("/\{stem}")
  let compiler = @moon_wesl.Wesl::new_barebones()
    .set_options(options.compile_options())
    .use_sourcemap(options.sourcemap)
    .set_mangler(options.mangler)
    .set_custom_resolver(@moon_wesl.StandardResolver::new(base))
  let result = compiler.compile_diagnostic(root) catch {
    err => return Err(err.message())
  }
  Ok(result)
}

///|
fn cli_check_diagnostic(
  err : @moon_wesl.WeslCompileError,
  path : @moon_wesl.ModulePath,
  display_name : String,
  source : String,
) -> String {
  err
  .diagnostic()
  .with_source(source)
  .with_module_path(path, Some(display_name))
  .infer_span_from_message()
  .to_string()
}

///|
fn cli_check_source(
  kind : String,
  source : String,
  display_name : String,
) -> Result[Unit, String] {
  let stem = cli_stem(display_name)
  let path = if stem == "" {
    @moon_wesl.ModulePath::from_path("/stdin")
  } else {
    @moon_wesl.ModulePath::from_path("/\{stem}")
  }
  match kind {
    "wesl" => {
      let unit = @moon_wesl.parse_translation_unit(path, source, true) catch {
        err => return Err(cli_check_diagnostic(err, path, display_name, source))
      }
      @moon_wesl.validate_wesl(unit) catch {
        err => return Err(cli_check_diagnostic(err, path, display_name, source))
      }
      let resolver = @moon_wesl.VirtualResolver::new()
      resolver.add_module(path, source)
      try
        @moon_wesl.compile(
          path,
          resolver,
          @moon_wesl.EscapeMangler::default(),
          @moon_wesl.CompileOptions::default().with_strip(false),
        )
      catch {
        Resolve(_) => ()
        err => return Err(cli_check_diagnostic(err, path, display_name, source))
      } noraise {
        _ => ()
      }
      Ok(())
    }
    "wgsl" => {
      @wgsl_validation.validate_source(source) catch {
        err =>
          return Err(
            cli_check_diagnostic(
              Validation(err.message()),
              path,
              display_name,
              source,
            ),
          )
      }
      Ok(())
    }
    _ => Err("invalid check kind `\{kind}`")
  }
}

///|
fn cli_run_check(args : ArrayView[String]) -> CliRunResult {
  let mut kind = "wesl"
  let mut file : String? = None
  let mut use_naga = false
  let mut index = 0
  while index < args.length() {
    let arg = args[index]
    match arg {
      "-h" | "--help" => return cli_ok(cli_check_usage())
      "--kind" => {
        match cli_take_arg(args, index, arg) {
          Ok(value) => kind = value
          Err(err) => return cli_err(err)
        }
        index = index + 2
      }
      "--naga" => {
        use_naga = true
        index = index + 1
      }
      _ => {
        if arg.has_prefix("--") {
          return cli_err("unknown option `\{arg}`")
        }
        file = Some(arg)
        index = index + 1
      }
    }
  }
  if use_naga {
    return cli_err("Naga validation is not available in this MoonBit build")
  }
  match file {
    Some(path) => {
      let source = @fs.read_file_to_string(path) catch {
        _ => return cli_err("input file not found")
      }
      match cli_check_source(kind, source, path) {
        Ok(_) => cli_ok("OK")
        Err(err) => cli_err(err)
      }
    }
    None => cli_err("missing input file")
  }
}

///|
fn cli_run_compile(args : ArrayView[String]) -> CliRunResult {
  let parsed = match cli_parse_common_args(args) {
    Ok(value) => value
    Err(err) => return cli_err(err)
  }
  let (options, positionals) = parsed
  if positionals.length() == 0 {
    return cli_ok("")
  }
  if positionals.length() > 1 {
    return cli_err(cli_compile_usage())
  }
  match cli_compile_file(positionals[0], options) {
    Ok(result) => cli_ok(result.to_string())
    Err(err) => cli_err(err)
  }
}

///|
fn cli_run_eval(args : ArrayView[String]) -> CliRunResult {
  let mut file : String? = None
  let filtered : Array[String] = []
  let mut binary = false
  let mut index = 0
  while index < args.length() {
    let arg = args[index]
    match arg {
      "-h" | "--help" => return cli_ok(cli_eval_usage())
      "-b" | "--binary" => {
        binary = true
        index = index + 1
      }
      "--file" => {
        match cli_take_arg(args, index, arg) {
          Ok(path) => file = Some(path)
          Err(err) => return cli_err(err)
        }
        index = index + 2
      }
      _ => {
        filtered.push(arg)
        index = index + 1
      }
    }
  }
  let parsed = match cli_parse_common_args(filtered[:]) {
    Ok(value) => value
    Err(err) => return cli_err(err)
  }
  let (options, positionals) = parsed
  if positionals.length() != 1 {
    return cli_err(cli_eval_usage())
  }
  match file {
    Some(path) =>
      match cli_compile_file(path, options) {
        Ok(result) => {
          let eval = result.eval(positionals[0]) catch {
            err => return cli_err(err.message())
          }
          if binary {
            match eval.to_buffer() {
              Some(buffer) => cli_ok_bytes(buffer)
              None =>
                cli_err(
                  "Could not convert instance to buffer (type is not storable)",
                )
            }
          } else {
            cli_ok(eval.to_string())
          }
        }
        Err(err) => cli_err(err)
      }
    None => {
      let eval = @moon_wesl.eval_str(positionals[0]) catch {
        err => return cli_err(err.message())
      }
      if binary {
        match eval.to_buffer() {
          Some(buffer) => cli_ok_bytes(buffer)
          None =>
            cli_err(
              "Could not convert instance to buffer (type is not storable)",
            )
        }
      } else {
        cli_ok(eval.to_string())
      }
    }
  }
}

///|
fn cli_run_exec(args : ArrayView[String]) -> CliRunResult {
  let mut entrypoint = "main"
  let resources : Array[@moon_wesl.ResourceBinding] = []
  let overrides : Array[@moon_wesl.OverrideValue] = []
  let filtered : Array[String] = []
  let mut binary = false
  let mut index = 0
  while index < args.length() {
    let arg = args[index]
    match arg {
      "-h" | "--help" => return cli_ok(cli_exec_usage())
      "-b" | "--out-binary" => {
        binary = true
        index = index + 1
      }
      "--entrypoint" => {
        match cli_take_arg(args, index, arg) {
          Ok(value) => entrypoint = value
          Err(err) => return cli_err(err)
        }
        index = index + 2
      }
      "--resource" => {
        match cli_take_arg(args, index, arg) {
          Ok(value) =>
            match cli_parse_resource_binding(value) {
              Ok(resource) => resources.push(resource)
              Err(err) => return cli_err(err)
            }
          Err(err) => return cli_err(err)
        }
        index = index + 2
      }
      "--override" => {
        match cli_take_arg(args, index, arg) {
          Ok(value) =>
            match cli_parse_override_assignment(value) {
              Ok(override_) => overrides.push(override_)
              Err(err) => return cli_err(err)
            }
          Err(err) => return cli_err(err)
        }
        index = index + 2
      }
      _ => {
        filtered.push(arg)
        index = index + 1
      }
    }
  }
  let parsed = match cli_parse_common_args(filtered[:]) {
    Ok(value) => value
    Err(err) => return cli_err(err)
  }
  let (options, positionals) = parsed
  if positionals.length() > 1 {
    return cli_err(cli_exec_usage())
  }
  let compiled = if positionals.length() == 1 {
    match cli_compile_file(positionals[0], options) {
      Ok(result) => result
      Err(err) => return cli_err(err)
    }
  } else {
    @moon_wesl.CompileResult::default()
  }
  let exec = compiled.exec(
    entrypoint,
    @moon_wesl.Inputs::new_zero_initialized(),
    resources,
    overrides,
  ) catch {
    err => return cli_err(err.message())
  }
  if binary {
    match (exec.return_value(), exec.to_buffer()) {
      (Some(_), Some(buffer)) => cli_ok_bytes(buffer)
      (Some(_), None) =>
        cli_err("Could not convert instance to buffer (type is not storable)")
      (None, _) => cli_ok_bytes(Bytes::new(0))
    }
  } else {
    cli_ok(exec.to_string())
  }
}

///|
fn cli_run_package(args : ArrayView[String]) -> CliRunResult {
  if args.length() == 1 && (args[0] == "-h" || args[0] == "--help") {
    return cli_ok(cli_package_usage())
  }
  if args.length() != 2 {
    return cli_err(cli_package_usage())
  }
  let pkg = @moon_wesl.PkgBuilder::new(args[0]).scan_root(args[1]) catch {
    err => return cli_err(err.message())
  }
  let validated = pkg.validate() catch { err => return cli_err(err.message()) }
  cli_ok(validated.codegen())
}

///|
fn cli_write_stdout_bytes(bytes : Bytes) -> String? {
  @fs.write_bytes_to_file("/dev/stdout", bytes) catch {
    err => return Some(@debug.to_string(err))
  }
  None
}

///|
fn wesl_cli_run(args : ArrayView[String]) -> CliRunResult {
  if args.length() == 0 {
    return cli_ok(cli_usage())
  }
  match args[0] {
    "-h" | "--help" | "help" => cli_ok(cli_usage())
    "check" => cli_run_check(args[1:])
    "compile" => cli_run_compile(args[1:])
    "eval" => cli_run_eval(args[1:])
    "exec" => cli_run_exec(args[1:])
    "package" => cli_run_package(args[1:])
    command => cli_err("unknown command `\{command}`\n\{cli_usage()}")
  }
}

///|
fn main {
  let result = wesl_cli_run(@sys.get_cli_args()[1:])
  match result.stdout_bytes {
    Some(bytes) =>
      if bytes.length() > 0 {
        match cli_write_stdout_bytes(bytes) {
          Some(err) => {
            println(err)
            @sys.exit(1)
          }
          None => ()
        }
      }
    None => ()
  }
  if result.stdout != "" {
    println(result.stdout)
  }
  if result.stderr != "" {
    println(result.stderr)
  }
  if result.status != 0 {
    @sys.exit(result.status)
  }
}
