///|
pub(all) suberror WeslIoError {
  InvalidArtifactName(String)
  MissingOutputDirectory
  RootNotFound(String)
  ReservedModuleName(String)
  Io(String)
}

///|
pub fn WeslIoError::message(self : WeslIoError) -> String {
  match self {
    InvalidArtifactName(name) => "invalid artifact name: `\{name}`"
    MissingOutputDirectory => "OUT_DIR environment variable is not defined"
    RootNotFound(path) => "package root was not found: `\{path}`"
    ReservedModuleName(name) => "module name `\{name}` is reserved"
    Io(message) => message
  }
}

///|
fn join_path(base : String, tail : String) -> String {
  if base == "" || base == "." {
    tail
  } else if base.has_suffix("/") || base.has_suffix("\\") {
    base + tail
  } else {
    base + "/" + tail
  }
}

///|
pub struct FileResolver {
  base : String
  extension : String
}

///|
pub fn FileResolver::new(base : String) -> FileResolver {
  { base, extension: "wesl" }
}

///|
pub fn FileResolver::set_extension(
  self : FileResolver,
  extension : String,
) -> FileResolver {
  { ..self, extension, }
}

///|
pub fn FileResolver::file_path(
  self : FileResolver,
  path : @moon_wesl.ModulePath,
) -> String raise @moon_wesl.ResolveError {
  if path.is_package() {
    raise ModuleNotFound(
      path, "external package imports must be handled by a package resolver",
    )
  }
  let tail = path.components.join("/")
  let stem = if tail == "" { "package" } else { tail }
  let filename = if self.extension == "" {
    stem
  } else {
    "\{stem}.\{self.extension}"
  }
  join_path(self.base, filename)
}

///|
pub impl @moon_wesl.Resolver for FileResolver with fn resolve_source(self, path) {
  let wesl_path = self.file_path(path)
  @fs.read_file_to_string(wesl_path) catch {
    _ =>
      if self.extension == "wesl" {
        let wgsl_path = self.set_extension("wgsl").file_path(path)
        @fs.read_file_to_string(wgsl_path) catch {
          _ =>
            raise ModuleNotFound(
              path,
              "physical source not found at `\{wesl_path}` or `\{wgsl_path}`",
            )
        }
      } else {
        raise ModuleNotFound(
          path,
          "physical source not found at `\{wesl_path}`",
        )
      }
  }
}

///|
pub impl @moon_wesl.Resolver for FileResolver with fn display_name(self, path) {
  Some(self.file_path(path)) catch {
    _ => None
  }
}

///|
fn trim_trailing_slash(path : String) -> String {
  let mut end = path.length()
  while end > 1 {
    let code = path.code_unit_at(end - 1).to_int()
    if code == 47 || code == 92 {
      end -= 1
    } else {
      break
    }
  }
  path[:end].to_owned()
}

///|
fn basename(path : String) -> String {
  let trimmed = trim_trailing_slash(path)
  let mut start = 0
  for index in 0..<trimmed.length() {
    let code = trimmed.code_unit_at(index).to_int()
    if code == 47 || code == 92 {
      start = index + 1
    }
  }
  trimmed[start:trimmed.length()].to_owned()
}

///|
fn without_extension(path : String) -> String {
  let trimmed = trim_trailing_slash(path)
  let mut dot = trimmed.length()
  for index in 0..<trimmed.length() {
    let code = trimmed.code_unit_at(index).to_int()
    if code == 47 || code == 92 {
      dot = trimmed.length()
    } else if code == 46 {
      dot = index
    }
  }
  trimmed[:dot].to_owned()
}

///|
fn is_reserved_module_name(name : String) -> Bool {
  match name {
    "const_assert"
    | "continue"
    | "continuing"
    | "default"
    | "diagnostic"
    | "discard"
    | "else"
    | "enable"
    | "false"
    | "fn"
    | "for"
    | "if"
    | "let"
    | "loop"
    | "override"
    | "requires"
    | "return"
    | "struct"
    | "switch"
    | "true"
    | "var"
    | "while"
    | "self"
    | "super"
    | "package"
    | "as"
    | "import" => true
    _ => false
  }
}

///|
fn unique_stems(dir : String) -> Array[String] raise WeslIoError {
  let entries = @fs.read_dir(dir) catch {
    err => raise Io(@debug.to_string(err))
  }
  let stems : Array[String] = []
  for entry in entries {
    let stem = without_extension(entry)
    if stem != "" && !stems.contains(stem) {
      stems.push(stem)
    }
  }
  stems.sort()
  stems
}

///|
fn scan_module(path : String) -> @moon_wesl.CodegenModule? raise WeslIoError {
  let stem_path = without_extension(path)
  let wesl_path = stem_path + ".wesl"
  let wgsl_path = stem_path + ".wgsl"
  let name = basename(stem_path)
  let has_wesl = @fs.is_file(wesl_path) catch { _ => false }
  let has_wgsl = @fs.is_file(wgsl_path) catch { _ => false }
  let has_dir = @fs.is_dir(stem_path) catch { _ => false }
  if !has_wesl && !has_wgsl && !has_dir {
    return None
  }
  if is_reserved_module_name(name) {
    raise ReservedModuleName(name)
  }
  if !@lex.wgsl_identifier_text(name) {
    return None
  }
  let source = if has_wesl {
    @fs.read_file_to_string(wesl_path) catch {
      err => raise Io(@debug.to_string(err))
    }
  } else if has_wgsl {
    @fs.read_file_to_string(wgsl_path) catch {
      err => raise Io(@debug.to_string(err))
    }
  } else {
    ""
  }
  let module_ = @moon_wesl.CodegenModule::new(name, source)
  if has_dir {
    for stem in unique_stems(stem_path) {
      match scan_module(join_path(stem_path, stem)) {
        Some(child) => module_.add_submodule(child)
        None => ()
      }
    }
  }
  if source == "" && module_.submodules.length() == 0 {
    None
  } else {
    Some(module_)
  }
}

///|
pub fn scan_package(
  builder : @moon_wesl.PkgBuilder,
  path : String,
) -> @moon_wesl.Pkg raise WeslIoError {
  match scan_module(path) {
    Some(root) => builder.build(root)
    None => raise RootNotFound(path)
  }
}

///|
pub fn write_compile_result(
  result : @moon_wesl.CompileResult,
  path : String,
) -> Unit raise WeslIoError {
  @fs.write_string_to_file(path, result.to_string()) catch {
    err => raise Io(@debug.to_string(err))
  }
}

///|
pub fn write_package_artifact(
  pkg : @moon_wesl.Pkg,
  path : String,
) -> Unit raise WeslIoError {
  @fs.write_string_to_file(path, pkg.codegen()) catch {
    err => raise Io(@debug.to_string(err))
  }
}

///|
pub fn write_artifact(
  result : @moon_wesl.CompileResult,
  artifact_name : String,
  out_dir? : String? = None,
) -> Unit raise WeslIoError {
  if artifact_name == "" ||
    artifact_name.contains("/") ||
    artifact_name.contains("\\") ||
    artifact_name.contains(".") {
    raise InvalidArtifactName(artifact_name)
  }
  let dirname = match out_dir {
    Some(value) => value
    None =>
      match @env.get_env_var("OUT_DIR") {
        Some(value) => value
        None => raise MissingOutputDirectory
      }
  }
  write_compile_result(result, join_path(dirname, "\{artifact_name}.wgsl"))
}
