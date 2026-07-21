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
priv struct ComposerWeslResolver {
  composer : @compose.Composer
}

///|
fn ComposerWeslResolver::find_source(
  self : ComposerWeslResolver,
  path : @moon_wesl.ModulePath,
) -> (String, String)? {
  let stem = @resolver.normalize_shader_rel_path(path.to_path_string())
  let candidates = ["\{stem}.wesl", "\{stem}.wgsl", stem]
  for candidate in candidates {
    match self.composer.registered_source(candidate) {
      Some(source) => return Some((candidate, source))
      None => ()
    }
  }
  None
}

///|
impl @moon_wesl.Resolver for ComposerWeslResolver with fn resolve_source(
  self,
  path,
) {
  match self.find_source(path) {
    Some((_, source)) => source
    None => raise ModuleNotFound(path, "composer source registry")
  }
}

///|
impl @moon_wesl.Resolver for ComposerWeslResolver with fn display_name(
  self,
  path,
) {
  match self.find_source(path) {
    Some((rel_path, _)) => Some(rel_path)
    None => None
  }
}

///|
/// Compile a registered WESL root and its imports into standard WGSL.
///
/// Imports are resolved from this composer's source registry. For each module,
/// a `.wesl` source is preferred over a `.wgsl` source with the same stem.
pub fn Composer::compile_wesl(
  self : Composer,
  root_rel_path : String,
  options : CompileOptions,
) -> String raise WgslError {
  let normalized = @resolver.normalize_shader_rel_path(root_rel_path)
  if normalized == "" {
    raise WorkflowFailed("WESL root path is empty")
  }
  let root = @moon_wesl.ModulePath::from_path("/\{normalized}")
  let resolver = ComposerWeslResolver::{ composer: self.inner }
  @moon_wesl.compile(
    root,
    resolver,
    @moon_wesl.EscapeMangler::default(),
    options,
  ).to_string() catch {
    error => raise WorkflowFailed(error.message())
  }
}
