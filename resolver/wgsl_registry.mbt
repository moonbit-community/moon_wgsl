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
pub struct WgslSourceRegistry {
  rel_to_source_ref : Ref[@hashmap.HashMap[String, String]]
  module_to_rel_ref : Ref[@hashmap.HashMap[String, String]]
}

///|
pub fn WgslSourceRegistry::default() -> WgslSourceRegistry {
  WgslSourceRegistry::{
    rel_to_source_ref: Ref::new(@hashmap.HashMap::new()),
    module_to_rel_ref: Ref::new(@hashmap.HashMap::new()),
  }
}

///|
fn WgslSourceRegistry::source_registry(
  self : WgslSourceRegistry,
) -> @hashmap.HashMap[String, String] {
  self.rel_to_source_ref.val
}

///|
fn WgslSourceRegistry::module_paths(
  self : WgslSourceRegistry,
) -> @hashmap.HashMap[String, String] {
  self.module_to_rel_ref.val
}

///|
pub fn WgslSourceRegistry::clear(self : WgslSourceRegistry) -> Unit {
  clear_wgsl_source_registry(self.source_registry(), self.module_paths())
}

///|
pub fn WgslSourceRegistry::register_source(
  self : WgslSourceRegistry,
  rel_path : String,
  source : String,
  explicit_module_path : String?,
) -> String? {
  register_source_into(
    self.source_registry(),
    self.module_paths(),
    rel_path,
    source,
    explicit_module_path,
  )
}

///|
pub fn WgslSourceRegistry::analyze_source_files(
  self : WgslSourceRegistry,
  files : Array[WgslSourceFile],
) -> Array[WgslDiagnostic] {
  let diagnostics : Array[WgslDiagnostic] = []
  analyze_source_files_against(
    copy_wgsl_source_registry_map(self.source_registry()),
    copy_wgsl_import_module_map(self.module_paths()),
    files,
    diagnostics,
  )
  diagnostics
}

///|
pub fn WgslSourceRegistry::register_source_files_checked(
  self : WgslSourceRegistry,
  files : Array[WgslSourceFile],
  diagnostics : Array[WgslDiagnostic],
) -> Unit {
  register_source_files_checked_into(
    self.source_registry(),
    self.module_paths(),
    files,
    diagnostics,
  )
}

///|
pub fn WgslSourceRegistry::register_source_files(
  self : WgslSourceRegistry,
  files : Array[WgslSourceFile],
) -> Unit {
  register_source_files_into(self.source_registry(), self.module_paths(), files)
}

///|
pub fn WgslSourceRegistry::registered_source(
  self : WgslSourceRegistry,
  rel_path : String,
) -> String? {
  registered_source_from_registry(self.source_registry(), rel_path)
}

///|
pub fn WgslSourceRegistry::copy_import_module_paths(
  self : WgslSourceRegistry,
) -> @hashmap.HashMap[String, String] {
  copy_wgsl_import_module_map(self.module_paths())
}

///|
pub fn WgslSourceRegistry::remove_source_and_module(
  self : WgslSourceRegistry,
  rel_path : String,
  module_path : String,
) -> Unit {
  ignore(self.source_registry().remove(rel_path))
  ignore(self.module_paths().remove(module_path))
}
