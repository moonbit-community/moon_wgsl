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
pub(all) suberror ResolveError {
  ModuleNotFound(ModulePath, String)
  Error(String)
}

///|
pub fn ResolveError::message(self : ResolveError) -> String {
  match self {
    ModuleNotFound(path, context) =>
      "module not found: `\{path.to_string()}` (\{context})"
    Error(message) => message
  }
}

///|
pub(open) trait Resolver {
  fn resolve_source(Self, ModulePath) -> String raise ResolveError
  fn resolve_module(Self, ModulePath) -> TranslationUnit raise ResolveError = _
  fn display_name(Self, ModulePath) -> String? = _
}

///|
impl Resolver with fn resolve_module(self, path) {
  let source = Self::resolve_source(self, path)
  parse_translation_unit(path, source, true) catch {
    err => raise Error(err.message())
  }
}

///|
impl Resolver with fn display_name(_self, _path) {
  None
}

///|
pub struct NoResolver {}

///|
#warnings("-unnecessary_annotation")
pub fn NoResolver::new() -> NoResolver {
  NoResolver::{  }
}

///|
pub fn NoResolver::default() -> NoResolver {
  NoResolver::new()
}

///|
pub impl Resolver for NoResolver with fn resolve_source(_self, path) {
  raise ModuleNotFound(
    path, "no module resolver, imports are effectively disabled here",
  )
}

///|
pub struct VirtualResolver {
  files : @hashmap.HashMap[ModulePath, String]
}

///|
pub fn VirtualResolver::new() -> VirtualResolver {
  { files: HashMap([]) }
}

///|
pub fn VirtualResolver::default() -> VirtualResolver {
  VirtualResolver::new()
}

///|
pub fn VirtualResolver::add_module(
  self : VirtualResolver,
  path : ModulePath,
  source : String,
) -> Unit {
  self.files.set(path, source)
}

///|
pub fn VirtualResolver::add_translation_unit(
  self : VirtualResolver,
  path : ModulePath,
  translation_unit : TranslationUnit,
) -> Unit {
  self.add_module(path, translation_unit.to_string())
}

///|
pub fn VirtualResolver::get_module(
  self : VirtualResolver,
  path : ModulePath,
) -> String raise ResolveError {
  match self.files.get(path) {
    Some(source) => source
    None => raise ModuleNotFound(path, "virtual module")
  }
}

///|
pub fn VirtualResolver::modules(
  self : VirtualResolver,
) -> Array[(ModulePath, String)] {
  let modules : Array[(ModulePath, String)] = []
  for entry in self.files.iter() {
    modules.push(entry)
  }
  modules
}

///|
pub impl Resolver for VirtualResolver with fn resolve_source(self, path) {
  self.get_module(path)
}

///|
pub impl Resolver for VirtualResolver with fn display_name(_self, path) {
  Some(path.to_string())
}

///|
pub(open) trait ModulePreprocessor {
  fn preprocess_module(Self, ModulePath, TranslationUnit) -> TranslationUnit raise ResolveError
}

///|
pub struct IdentityPreprocessor {}

///|
#warnings("-unnecessary_annotation")
pub fn IdentityPreprocessor::new() -> IdentityPreprocessor {
  IdentityPreprocessor::{  }
}

///|
pub impl ModulePreprocessor for IdentityPreprocessor with fn preprocess_module(
  _self,
  _path,
  unit,
) {
  unit
}

///|
pub struct Preprocessor[R, P] {
  resolver : R
  preprocess : P
}

///|
pub fn[R, P] Preprocessor::new(
  resolver : R,
  preprocess : P,
) -> Preprocessor[R, P] {
  { resolver, preprocess }
}

///|
pub impl[R : Resolver, P : ModulePreprocessor] Resolver for Preprocessor[R, P] with fn resolve_source(
  self,
  path,
) {
  R::resolve_source(self.resolver, path)
}

///|
pub impl[R : Resolver, P : ModulePreprocessor] Resolver for Preprocessor[R, P] with fn resolve_module(
  self,
  path,
) {
  let unit = R::resolve_module(self.resolver, path)
  P::preprocess_module(self.preprocess, path, unit)
}

///|
pub impl[R : Resolver, P : ModulePreprocessor] Resolver for Preprocessor[R, P] with fn display_name(
  self,
  path,
) {
  R::display_name(self.resolver, path)
}

///|
pub struct CodegenModule {
  name : String
  source : String
  submodules : Array[CodegenModule]
} derive(Debug, Eq)

///|
pub struct CodegenPkg {
  crate_name : String
  root : CodegenModule
  dependencies : Array[CodegenPkg]
} derive(Debug, Eq)

///|
pub fn CodegenModule::new(name : String, source : String) -> CodegenModule {
  { name, source, submodules: [] }
}

///|
pub fn CodegenModule::with_submodules(
  self : CodegenModule,
  submodules : Array[CodegenModule],
) -> CodegenModule {
  { ..self, submodules, }
}

///|
pub fn CodegenModule::add_submodule(
  self : CodegenModule,
  submodule : CodegenModule,
) -> Unit {
  self.submodules.push(submodule)
}

///|
pub fn CodegenPkg::new(crate_name : String, root : CodegenModule) -> CodegenPkg {
  { crate_name, root, dependencies: [] }
}

///|
pub fn CodegenPkg::with_dependencies(
  self : CodegenPkg,
  dependencies : Array[CodegenPkg],
) -> CodegenPkg {
  { ..self, dependencies, }
}

///|
pub fn CodegenPkg::add_dependency(
  self : CodegenPkg,
  dependency : CodegenPkg,
) -> Unit {
  self.dependencies.push(dependency)
}

///|
pub struct PkgBuilder {
  name : String
  dependencies : Array[CodegenPkg]
}

///|
pub(all) struct Pkg {
  crate_name : String
  root : CodegenModule
  dependencies : Array[CodegenPkg]
}

///|
pub fn PkgBuilder::new(name : String) -> PkgBuilder {
  { name: name.replace_all(old="-", new="_"), dependencies: [] }
}

///|
pub fn PkgBuilder::add_package(
  self : PkgBuilder,
  pkg : CodegenPkg,
) -> PkgBuilder {
  let dependencies = self.dependencies.copy()
  dependencies.push(pkg)
  { ..self, dependencies, }
}

///|
pub fn PkgBuilder::add_packages(
  self : PkgBuilder,
  pkgs : Array[CodegenPkg],
) -> PkgBuilder {
  let dependencies = self.dependencies.copy()
  for pkg in pkgs {
    dependencies.push(pkg)
  }
  { ..self, dependencies, }
}

///|
pub fn PkgBuilder::build(self : PkgBuilder, root : CodegenModule) -> Pkg {
  {
    crate_name: self.name,
    root: { ..root, name: self.name },
    dependencies: self.dependencies,
  }
}

///|
pub fn Pkg::to_codegen_pkg(self : Pkg) -> CodegenPkg {
  {
    crate_name: self.crate_name,
    root: self.root,
    dependencies: self.dependencies,
  }
}

///|
pub fn Pkg::validate(self : Pkg) -> Pkg raise WeslCompileError {
  fn validate_module(
    module_ : CodegenModule,
    path : ModulePath,
  ) -> Unit raise WeslCompileError {
    if module_.source != "" {
      ignore(parse_translation_unit(path, module_.source, true))
    }
    for submodule in module_.submodules {
      validate_module(submodule, path.join([submodule.name]))
    }
  }
  validate_module(self.root, ModulePath::new(Package(self.root.name), []))
  self
}

///|
fn pkg_codegen_escape_string(text : String) -> String {
  text
  .replace_all(old="\\", new="\\\\")
  .replace_all(old="\"", new="\\\"")
  .replace_all(old="\n", new="\\n")
  .replace_all(old="\r", new="\\r")
}

///|
fn pkg_codegen_module(module_ : CodegenModule, indent : String) -> String {
  let children : Array[String] = []
  for submodule in module_.submodules {
    children.push(pkg_codegen_module(submodule, indent + "  "))
  }
  let submodules = if children.length() == 0 {
    "[]"
  } else {
    let joined = children.join(",\n")
    "[\n\{joined}\n\{indent}]"
  }
  "\{indent}CodegenModule::{ name: \"\{pkg_codegen_escape_string(module_.name)}\", source: \"\{pkg_codegen_escape_string(module_.source)}\", submodules: \{submodules} }"
}

///|
pub fn Pkg::codegen(self : Pkg) -> String {
  let dependencies : Array[String] = []
  for dependency in self.dependencies {
    let root_code = pkg_codegen_module(dependency.root, "")
    dependencies.push(
      "CodegenPkg::{ crate_name: \"\{pkg_codegen_escape_string(dependency.crate_name)}\", root: \{root_code}, dependencies: [] }",
    )
  }
  let deps = if dependencies.length() == 0 {
    "[]"
  } else {
    let joined = dependencies.join(",\n")
    "[\n\{joined}\n]"
  }
  let root_code = pkg_codegen_module(self.root, "")
  "CodegenPkg::{ crate_name: \"\{pkg_codegen_escape_string(self.crate_name)}\", root: \{root_code}, dependencies: \{deps} }"
}

///|
pub struct PkgResolver {
  packages : Array[CodegenPkg]
}

///|
pub fn PkgResolver::new() -> PkgResolver {
  { packages: [] }
}

///|
pub fn PkgResolver::default() -> PkgResolver {
  PkgResolver::new()
}

///|
pub fn PkgResolver::add_package(self : PkgResolver, pkg : CodegenPkg) -> Unit {
  self.packages.push(pkg)
}

///|
fn pkg_resolver_find_package(
  packages : Array[CodegenPkg],
  name : String,
) -> CodegenPkg? {
  for pkg in packages {
    if pkg.root.name == name {
      return Some(pkg)
    }
  }
  None
}

///|
fn pkg_resolver_find_submodule(
  node : CodegenModule,
  name : String,
) -> CodegenModule? {
  for submodule in node.submodules {
    if submodule.name == name {
      return Some(submodule)
    }
  }
  None
}

///|
fn pkg_resolver_resolve_package_path(
  root : CodegenPkg,
  package_path : String,
  full_path : ModulePath,
) -> CodegenPkg raise ResolveError {
  let parts = module_path_split_non_empty(package_path, "/")
  if parts.length() <= 1 {
    return root
  }
  let mut current = root
  for index in 1..<parts.length() {
    match pkg_resolver_find_package(current.dependencies, parts[index]) {
      Some(next) => current = next
      None =>
        raise ModuleNotFound(
          full_path,
          "dependency `\{parts[index]}` not found in package path `\{package_path}`",
        )
    }
  }
  current
}

///|
pub impl Resolver for PkgResolver with fn resolve_source(self, path) {
  let package_path = match path.origin {
    Package(name) => name
    _ => raise ModuleNotFound(path, "resolver can only resolve package imports")
  }
  let package_parts = module_path_split_non_empty(package_path, "/")
  guard package_parts.get(0) is Some(root_name) else {
    raise ModuleNotFound(path, "empty package path")
  }
  let root_package = match pkg_resolver_find_package(self.packages, root_name) {
    Some(pkg) => pkg
    None => raise ModuleNotFound(path, "dependency `\{package_path}` not found")
  }
  let pkg = pkg_resolver_resolve_package_path(root_package, package_path, path)
  let mut current = pkg.root
  for component in path.components {
    match pkg_resolver_find_submodule(current, component) {
      Some(submodule) => current = submodule
      None =>
        raise ModuleNotFound(
          path,
          "in module `\{current.name}`, no submodule named `\{component}`",
        )
    }
  }
  current.source
}

///|
pub impl Resolver for PkgResolver with fn display_name(_self, path) {
  Some(path.to_string())
}

///|
pub struct StandardResolver {
  pkg : PkgResolver
  modules : VirtualResolver
  constants : @hashmap.HashMap[String, Double]
}

///|
pub fn StandardResolver::new() -> StandardResolver {
  {
    pkg: PkgResolver::new(),
    modules: VirtualResolver::new(),
    constants: HashMap([]),
  }
}

///|
pub fn StandardResolver::add_module(
  self : StandardResolver,
  path : ModulePath,
  source : String,
) -> Unit {
  self.modules.add_module(path, source)
}

///|
pub fn StandardResolver::add_package(
  self : StandardResolver,
  pkg : CodegenPkg,
) -> Unit {
  self.pkg.add_package(pkg)
}

///|
pub fn StandardResolver::add_constant(
  self : StandardResolver,
  name : String,
  value : Double,
) -> Unit {
  self.constants.set(name, value)
}

///|
pub fn StandardResolver::generate_constant_module(
  self : StandardResolver,
) -> String {
  let parts : Array[String] = []
  for entry in self.constants.iter() {
    let (name, value) = entry
    parts.push("const \{name} = \{value.to_string()};")
  }
  parts.join("\n")
}

///|
fn standard_resolver_is_constants_path(path : ModulePath) -> Bool {
  match path.origin {
    Package(name) => name == "constants" || name.has_suffix("/constants")
    _ => false
  }
}

///|
pub impl Resolver for StandardResolver with fn resolve_source(self, path) {
  if standard_resolver_is_constants_path(path) {
    self.generate_constant_module()
  } else if path.is_package() {
    self.pkg.resolve_source(path)
  } else {
    self.modules.resolve_source(path)
  }
}

///|
pub impl Resolver for StandardResolver with fn display_name(self, path) {
  if standard_resolver_is_constants_path(path) {
    Some(path.to_string())
  } else if path.is_package() {
    self.pkg.display_name(path)
  } else {
    self.modules.display_name(path)
  }
}

///|
priv enum ResolverMount {
  Virtual(VirtualResolver)
  Pkg(PkgResolver)
  Standard(StandardResolver)
}

///|
fn ResolverMount::resolve_source(
  self : ResolverMount,
  path : ModulePath,
) -> String raise ResolveError {
  match self {
    Virtual(resolver) => resolver.resolve_source(path)
    Pkg(resolver) => resolver.resolve_source(path)
    Standard(resolver) => resolver.resolve_source(path)
  }
}

///|
fn ResolverMount::resolve_module(
  self : ResolverMount,
  path : ModulePath,
) -> TranslationUnit raise ResolveError {
  match self {
    Virtual(resolver) => resolver.resolve_module(path)
    Pkg(resolver) => resolver.resolve_module(path)
    Standard(resolver) => resolver.resolve_module(path)
  }
}

///|
fn ResolverMount::display_name(
  self : ResolverMount,
  path : ModulePath,
) -> String? {
  match self {
    Virtual(resolver) => resolver.display_name(path)
    Pkg(resolver) => resolver.display_name(path)
    Standard(resolver) => resolver.display_name(path)
  }
}

///|
fn ResolverMount::route_path(
  self : ResolverMount,
  original : ModulePath,
  suffix : ModulePath,
) -> ModulePath {
  match self {
    Pkg(_) => original
    _ => suffix
  }
}

///|
pub struct Router {
  priv mount_points : Array[(ModulePath, ResolverMount)]
  priv mut fallback : (ModulePath, ResolverMount)?
}

///|
pub fn Router::new() -> Router {
  { mount_points: [], fallback: None }
}

///|
pub fn Router::default() -> Router {
  Router::new()
}

///|
pub fn Router::mount_resolver(
  self : Router,
  prefix : ModulePath,
  resolver : VirtualResolver,
) -> Unit {
  self.mount_points.push((prefix, Virtual(resolver)))
}

///|
pub fn Router::mount_standard_resolver(
  self : Router,
  prefix : ModulePath,
  resolver : StandardResolver,
) -> Unit {
  self.mount_points.push((prefix, Standard(resolver)))
}

///|
pub fn Router::mount_pkg_resolver(
  self : Router,
  prefix : ModulePath,
  resolver : PkgResolver,
) -> Unit {
  self.mount_points.push((prefix, Pkg(resolver)))
}

///|
pub fn Router::mount_fallback_resolver(
  self : Router,
  resolver : VirtualResolver,
) -> Unit {
  self.fallback = Some((ModulePath::new_root(), Virtual(resolver)))
}

///|
fn router_suffix_path(path : ModulePath, prefix : ModulePath) -> ModulePath {
  ModulePath::new(
    Absolute,
    module_path_slice(
      path.components,
      prefix.components.length(),
      path.components.length(),
    ),
  )
}

///|
fn Router::route(
  self : Router,
  path : ModulePath,
) -> (ResolverMount, ModulePath) raise ResolveError {
  let mut selected : (ModulePath, ResolverMount)? = None
  for entry in self.mount_points {
    let (prefix, _) = entry
    if path.starts_with(prefix) {
      match selected {
        Some((best_prefix, _)) =>
          if prefix.components.length() > best_prefix.components.length() {
            selected = Some(entry)
          }
        None => selected = Some(entry)
      }
    }
  }
  match selected {
    Some((prefix, resolver)) => (resolver, router_suffix_path(path, prefix))
    None =>
      match self.fallback {
        Some((prefix, resolver)) => (resolver, router_suffix_path(path, prefix))
        None => raise ModuleNotFound(path, "no mount point")
      }
  }
}

///|
pub impl Resolver for Router with fn resolve_source(self, path) {
  let (resolver, suffix) = self.route(path)
  resolver.resolve_source(resolver.route_path(path, suffix))
}

///|
pub impl Resolver for Router with fn resolve_module(self, path) {
  let (resolver, suffix) = self.route(path)
  resolver.resolve_module(resolver.route_path(path, suffix))
}

///|
pub impl Resolver for Router with fn display_name(self, path) {
  try {
    let (resolver, suffix) = self.route(path)
    resolver.display_name(resolver.route_path(path, suffix))
  } catch {
    _ => None
  }
}
