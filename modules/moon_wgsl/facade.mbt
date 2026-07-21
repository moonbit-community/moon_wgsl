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
pub using @contract {
  type ComposableModuleDescriptor,
  type ImportDefWithOffset,
  type ImportDefinition,
  type PreparedWgslSource,
  type PreprocessOutput,
  type PreprocessorMetaData,
  type ShaderDefValue,
  type WgslComposeOptions,
  type WgslDiagnostic,
  type WgslDiagnosticSeverity,
  type WgslDirectives,
  type WgslExportOptions,
  type WgslExportOutput,
  type WgslImmediateSpecialization,
  type WgslSourceCatalogEntry,
  type WgslSourceFile,
  type WgslSourceMapEntry,
  type WgslSourceOriginEntry,
  type WgslSourceOriginKind,
  type WgslSymbolRedirect,
}

///|
pub using @profile {bevy_wgsl_value_defines}

///|
pub using @metadata {
  collect_wgsl_source_local_shader_defines,
  get_preprocessor_metadata,
  wgsl_source_define_import_path,
  type MetadataError,
}

///|
pub using @preprocess {
  apply_wgsl_ifdefs_strict,
  apply_wgsl_template_consts,
  type PreprocessError,
  type Preprocessor,
}

///|
pub using @resolver {
  default_shader_rel_path_for_module_path,
  normalize_shader_rel_path,
  type WgslSourceRegistry,
}

///|
/// Error reported by the user-facing WGSL workflow.
///
/// Lower-level parser, resolver, composer, and writer errors are deliberately
/// collapsed at this boundary. Callers that need stage-specific diagnostics
/// should use the dedicated naga-oil diagnostics package.
pub(all) suberror WgslError {
  WorkflowFailed(String)
}

///|
pub fn WgslError::message(self : WgslError) -> String {
  match self {
    WorkflowFailed(message) => message
  }
}

///|
/// A user-facing WGSL workspace.
///
/// Register all sources and modules before calling `prepare`, `compose`, or
/// `export_wgsl`. Registration mutates only this workspace. Each output operation
/// observes a stable snapshot of the registered inputs and does not expose
/// preprocessing, graph, IR, writer-plan, or parity stages.
pub struct Composer {
  priv inner : @compose.Composer
}

///|
pub fn Composer::default() -> Composer {
  { inner: @compose.Composer::default() }
}

///|
/// Replace or add one source under its normalized relative path.
pub fn Composer::register_source(
  self : Composer,
  rel_path : String,
  source : String,
) -> Unit {
  self.inner.register_source(rel_path, source)
}

///|
/// Replace or add a batch of source files.
pub fn Composer::register_source_files(
  self : Composer,
  source_files : Array[WgslSourceFile],
) -> Unit {
  self.inner.register_source_files(source_files)
}

///|
/// Remove every registered source and composable module.
pub fn Composer::clear_sources(self : Composer) -> Unit {
  self.inner.clear_sources()
}

///|
/// Register a named composable module.
pub fn Composer::add_module(
  self : Composer,
  descriptor : ComposableModuleDescriptor,
) -> Unit raise WgslError {
  ignore(self.inner.add_composable_module(descriptor)) catch {
    error => raise WorkflowFailed(error.message())
  }
}

///|
/// Remove a composable module when it exists.
pub fn Composer::remove_module(self : Composer, name : String) -> Unit {
  self.inner.remove_composable_module(name)
}

///|
/// Resolve and preprocess a registered source without exposing internal stages.
pub fn Composer::prepare(
  self : Composer,
  rel_path : String,
  options : WgslComposeOptions,
) -> PreparedWgslSource raise WgslError {
  self.inner.prepare_wgsl_source(rel_path, options) catch {
    error => raise WorkflowFailed(error.message())
  }
}

///|
/// Compose one registered source into runtime-valid WGSL.
pub fn Composer::compose(
  self : Composer,
  rel_path : String,
  options : WgslComposeOptions,
) -> String raise WgslError {
  self.inner.compose_wgsl(rel_path, options) catch {
    error => raise WorkflowFailed(error.message())
  }
}

///|
/// Compose and export one registered source with source-map metadata.
pub fn Composer::export_wgsl(
  self : Composer,
  rel_path : String,
  compose_options : WgslComposeOptions,
  export_options : WgslExportOptions,
) -> WgslExportOutput raise WgslError {
  @export.export_wgsl_with_options(
    self.inner,
    rel_path,
    compose_options,
    export_options,
  ) catch {
    error => raise WorkflowFailed(error.message())
  }
}
