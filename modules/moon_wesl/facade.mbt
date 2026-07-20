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
pub struct Wesl[R] {
  options : CompileOptions
  use_sourcemap : Bool
  resolver : R
  mangler : ManglerKind
}

///|
pub fn Wesl::new_barebones() -> Wesl[NoResolver] {
  Wesl::{
    options: CompileOptions::{
      imports: false,
      condcomp: false,
      generics: false,
      strip: false,
      lower: false,
      validate: false,
      lazy_resolution: false,
      mangle_root: false,
      keep: None,
      keep_root: false,
      features: Features::default(),
    },
    use_sourcemap: false,
    resolver: NoResolver::new(),
    mangler: ManglerKind::None,
  }
}

///|
pub fn Wesl::new_virtual(resolver : VirtualResolver) -> Wesl[VirtualResolver] {
  Wesl::{
    options: CompileOptions::default(),
    use_sourcemap: true,
    resolver,
    mangler: ManglerKind::default(),
  }
}

///|
pub fn Wesl::new(base : String) -> Wesl[StandardResolver] {
  Wesl::{
    options: CompileOptions::default(),
    use_sourcemap: true,
    resolver: StandardResolver::new(base),
    mangler: ManglerKind::default(),
  }
}

///|
pub fn Wesl::new_experimental(base : String) -> Wesl[StandardResolver] {
  Wesl::{
    options: CompileOptions::default().with_generics(true).with_lower(true),
    use_sourcemap: true,
    resolver: StandardResolver::new(base),
    mangler: ManglerKind::default(),
  }
}

///|
pub fn[R] Wesl::set_options(
  self : Wesl[R],
  options : CompileOptions,
) -> Wesl[R] {
  Wesl::{ ..self, options, }
}

///|
pub fn[R] Wesl::set_mangler(self : Wesl[R], kind : ManglerKind) -> Wesl[R] {
  Wesl::{ ..self, mangler: kind }
}

///|
pub fn[R, CustomResolver] Wesl::set_custom_resolver(
  self : Wesl[R],
  resolver : CustomResolver,
) -> Wesl[CustomResolver] {
  Wesl::{
    options: self.options,
    use_sourcemap: self.use_sourcemap,
    resolver,
    mangler: self.mangler,
  }
}

///|
pub fn[R] Wesl::use_sourcemap(self : Wesl[R], value : Bool) -> Wesl[R] {
  Wesl::{ ..self, use_sourcemap: value }
}

///|
pub fn[R] Wesl::use_imports(self : Wesl[R], value : Bool) -> Wesl[R] {
  Wesl::{ ..self, options: self.options.with_imports(value) }
}

///|
pub fn[R] Wesl::use_condcomp(self : Wesl[R], value : Bool) -> Wesl[R] {
  Wesl::{ ..self, options: self.options.with_condcomp(value) }
}

///|
pub fn[R] Wesl::use_generics(self : Wesl[R], value : Bool) -> Wesl[R] {
  Wesl::{ ..self, options: self.options.with_generics(value) }
}

///|
pub fn[R] Wesl::set_feature(
  self : Wesl[R],
  feature : String,
  value : Feature,
) -> Wesl[R] {
  Wesl::{ ..self, options: self.options.set_feature(feature, value) }
}

///|
pub fn[R] Wesl::set_features(
  self : Wesl[R],
  features : Array[(String, Feature)],
) -> Wesl[R] {
  let flags : @hashmap.HashMap[String, Feature] = @hashmap.HashMap([])
  for entry in self.options.features.flags.iter() {
    let (name, value) = entry
    flags.set(name, value)
  }
  for entry in features {
    let (name, value) = entry
    flags.set(name, value)
  }
  Wesl::{
    ..self,
    options: CompileOptions::{
      ..self.options,
      features: Features::{ ..self.options.features, flags, },
    },
  }
}

///|
pub fn[R] Wesl::unset_feature(self : Wesl[R], feature : String) -> Wesl[R] {
  let flags : @hashmap.HashMap[String, Feature] = @hashmap.HashMap([])
  for entry in self.options.features.flags.iter() {
    let (name, value) = entry
    if name != feature {
      flags.set(name, value)
    }
  }
  Wesl::{
    ..self,
    options: CompileOptions::{
      ..self.options,
      features: Features::{ ..self.options.features, flags, },
    },
  }
}

///|
pub fn[R] Wesl::set_missing_feature_behavior(
  self : Wesl[R],
  value : Feature,
) -> Wesl[R] {
  Wesl::{ ..self, options: self.options.set_missing_feature_behavior(value) }
}

///|
pub fn[R] Wesl::use_stripping(self : Wesl[R], value : Bool) -> Wesl[R] {
  Wesl::{ ..self, options: self.options.with_strip(value) }
}

///|
pub fn[R] Wesl::use_lower(self : Wesl[R], value : Bool) -> Wesl[R] {
  Wesl::{ ..self, options: self.options.with_lower(value) }
}

///|
pub fn[R] Wesl::keep_declarations(
  self : Wesl[R],
  keep : Array[String],
) -> Wesl[R] {
  Wesl::{ ..self, options: self.options.keep_declarations(keep) }
}

///|
pub fn[R] Wesl::keep_all_entrypoints(self : Wesl[R]) -> Wesl[R] {
  Wesl::{ ..self, options: CompileOptions::{ ..self.options, keep: None } }
}

///|
pub fn Wesl::add_package(
  self : Wesl[StandardResolver],
  pkg : CodegenPkg,
) -> Wesl[StandardResolver] {
  self.resolver.add_package(pkg)
  self
}

///|
pub fn Wesl::add_scanned_package(
  self : Wesl[StandardResolver],
  pkg : Pkg,
) -> Wesl[StandardResolver] {
  self.resolver.add_package(pkg.to_codegen_pkg())
  self
}

///|
pub fn Wesl::add_packages(
  self : Wesl[StandardResolver],
  pkgs : Array[CodegenPkg],
) -> Wesl[StandardResolver] {
  for pkg in pkgs {
    self.resolver.add_package(pkg)
  }
  self
}

///|
pub fn Wesl::add_constant(
  self : Wesl[StandardResolver],
  name : String,
  value : Double,
) -> Wesl[StandardResolver] {
  self.resolver.add_constant(name, value)
  self
}

///|
pub fn Wesl::add_constants(
  self : Wesl[StandardResolver],
  constants : Array[(String, Double)],
) -> Wesl[StandardResolver] {
  for entry in constants {
    let (name, value) = entry
    self.resolver.add_constant(name, value)
  }
  self
}

///|
pub fn[R] Wesl::resolver(self : Wesl[R]) -> R {
  self.resolver
}

///|
pub fn[R : Resolver] Wesl::compile(
  self : Wesl[R],
  root : ModulePath,
) -> CompileResult raise WeslCompileError {
  compile_with_mangler_kind(
    root,
    self.resolver,
    self.mangler,
    self.options,
    self.use_sourcemap,
  )
}

///|
pub fn[R : Resolver] Wesl::build_artifact(
  self : Wesl[R],
  root : ModulePath,
  artifact_name : String,
  out_dir? : String? = None,
) -> Unit raise WeslCompileError {
  let compiled = self.compile(root)
  emit_rerun_if_changed(compiled.modules, self.resolver)
  compiled.write_artifact(artifact_name, out_dir~)
}

///|
pub fn[R : Resolver] Wesl::compile_diagnostic(
  self : Wesl[R],
  root : ModulePath,
) -> CompileResult raise WeslDiagnosticError {
  compile_diagnostic_with_mangler_kind(
    root,
    self.resolver,
    self.mangler,
    self.options,
    self.use_sourcemap,
  )
}
