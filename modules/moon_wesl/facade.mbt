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
  {
    options: {
      ..CompileOptions::default(),
      imports: false,
      condcomp: false,
      strip: false,
      validate: false,
      lazy_resolution: false,
    },
    use_sourcemap: false,
    resolver: NoResolver::new(),
    mangler: None,
  }
}

///|
pub fn Wesl::new_virtual(resolver : VirtualResolver) -> Wesl[VirtualResolver] {
  {
    options: CompileOptions::default(),
    use_sourcemap: true,
    resolver,
    mangler: ManglerKind::default(),
  }
}

///|
pub fn Wesl::new() -> Wesl[StandardResolver] {
  {
    options: CompileOptions::default(),
    use_sourcemap: true,
    resolver: StandardResolver::new(),
    mangler: ManglerKind::default(),
  }
}

///|
pub fn Wesl::new_experimental() -> Wesl[StandardResolver] {
  {
    options: { ..CompileOptions::default(), generics: true, lower: true },
    use_sourcemap: true,
    resolver: StandardResolver::new(),
    mangler: ManglerKind::default(),
  }
}

///|
pub fn[R] Wesl::set_options(
  self : Wesl[R],
  options : CompileOptions,
) -> Wesl[R] {
  { ..self, options, }
}

///|
pub fn[R] Wesl::set_mangler(self : Wesl[R], kind : ManglerKind) -> Wesl[R] {
  { ..self, mangler: kind }
}

///|
pub fn[R, CustomResolver] Wesl::set_custom_resolver(
  self : Wesl[R],
  resolver : CustomResolver,
) -> Wesl[CustomResolver] {
  {
    options: self.options,
    use_sourcemap: self.use_sourcemap,
    resolver,
    mangler: self.mangler,
  }
}

///|
pub fn[R] Wesl::use_sourcemap(self : Wesl[R], value : Bool) -> Wesl[R] {
  { ..self, use_sourcemap: value }
}

///|
pub fn[R] Wesl::use_imports(self : Wesl[R], value : Bool) -> Wesl[R] {
  { ..self, options: { ..self.options, imports: value } }
}

///|
pub fn[R] Wesl::use_condcomp(self : Wesl[R], value : Bool) -> Wesl[R] {
  { ..self, options: { ..self.options, condcomp: value } }
}

///|
pub fn[R] Wesl::use_generics(self : Wesl[R], value : Bool) -> Wesl[R] {
  { ..self, options: { ..self.options, generics: value } }
}

///|
pub fn[R] Wesl::set_feature(
  self : Wesl[R],
  feature : String,
  value : Feature,
) -> Wesl[R] {
  let features = self.options.features
  features.set_feature(feature, value)
  { ..self, options: { ..self.options, features, } }
}

///|
pub fn[R] Wesl::set_features(
  self : Wesl[R],
  features : Array[(String, Feature)],
) -> Wesl[R] {
  let flags : @hashmap.HashMap[String, Feature] = HashMap([])
  for entry in self.options.features.flags.iter() {
    let (name, value) = entry
    flags.set(name, value)
  }
  for entry in features {
    let (name, value) = entry
    flags.set(name, value)
  }
  {
    ..self,
    options: { ..self.options, features: { ..self.options.features, flags, } },
  }
}

///|
pub fn[R] Wesl::unset_feature(self : Wesl[R], feature : String) -> Wesl[R] {
  let flags : @hashmap.HashMap[String, Feature] = HashMap([])
  for entry in self.options.features.flags.iter() {
    let (name, value) = entry
    if name != feature {
      flags.set(name, value)
    }
  }
  {
    ..self,
    options: { ..self.options, features: { ..self.options.features, flags, } },
  }
}

///|
pub fn[R] Wesl::set_missing_feature_behavior(
  self : Wesl[R],
  value : Feature,
) -> Wesl[R] {
  {
    ..self,
    options: {
      ..self.options,
      features: { ..self.options.features, default: value },
    },
  }
}

///|
pub fn[R] Wesl::use_stripping(self : Wesl[R], value : Bool) -> Wesl[R] {
  { ..self, options: { ..self.options, strip: value } }
}

///|
pub fn[R] Wesl::use_lower(self : Wesl[R], value : Bool) -> Wesl[R] {
  { ..self, options: { ..self.options, lower: value } }
}

///|
pub fn[R] Wesl::keep_declarations(
  self : Wesl[R],
  keep : Array[String],
) -> Wesl[R] {
  { ..self, options: { ..self.options, keep: Some(keep) } }
}

///|
pub fn[R] Wesl::keep_all_entrypoints(self : Wesl[R]) -> Wesl[R] {
  { ..self, options: { ..self.options, keep: None } }
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
pub fn Wesl::add_module(
  self : Wesl[StandardResolver],
  path : ModulePath,
  source : String,
) -> Wesl[StandardResolver] {
  self.resolver.add_module(path, source)
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
