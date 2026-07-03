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
pub using @common {
  default_wgsl_value_defines,
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
  type WgslSourceCatalogEntry,
  type WgslSourceFile,
  type WgslSourceMapEntry,
  type WgslSourceOriginEntry,
  type WgslSourceOriginKind,
  type WgslSourceScanOptions,
  type WgslSymbolRedirect,
}

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
  scan_wgsl_source_files,
  scan_wgsl_source_files_checked,
  type WgslSourceRegistry,
}

///|
pub using @compose {
  type ComposableModuleDefinition,
  type Composer,
  type ComposerError,
}

///|
pub using @export {export_wgsl_with_options}
