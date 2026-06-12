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
pub fn roundtrip_wgsl_source_via_ir_with_generated_imports_and_import_arena_events_compat_writer(
  source : String,
  generated_import_provenance : Array[@ir.WgslIrGeneratedImportProvenance],
  import_arena_events : Array[@ir.WgslIrImportArenaEvent],
  root_visible_rel_path? : String = "",
) -> String raise @ir.WgslIrPipelineError {
  @ir.roundtrip_wgsl_source_via_ir_with_generated_imports_and_import_arena_events_compat_writer(
    source,
    generated_import_provenance,
    import_arena_events,
    root_visible_rel_path~,
  )
}

///|
pub fn roundtrip_wgsl_source_via_ir_with_generated_imports_and_import_arena_events_compat_writer_entry_roots(
  source : String,
  generated_import_provenance : Array[@ir.WgslIrGeneratedImportProvenance],
  import_arena_events : Array[@ir.WgslIrImportArenaEvent],
) -> String raise @ir.WgslIrPipelineError {
  @ir.roundtrip_wgsl_source_via_ir_with_generated_imports_and_import_arena_events_compat_writer_entry_roots(
    source, generated_import_provenance, import_arena_events,
  )
}

///|
pub fn trace_compat_writer_function_plan_for_source_with_generated_imports_and_import_arena_events(
  source : String,
  generated_import_provenance : Array[@ir.WgslIrGeneratedImportProvenance],
  import_arena_events : Array[@ir.WgslIrImportArenaEvent],
  function_name_prefix : String,
  root_visible_rel_path? : String = "",
) -> String raise @ir.WgslIrPipelineError {
  @ir.trace_compat_writer_function_plan_for_source_with_generated_imports_and_import_arena_events(
    source,
    generated_import_provenance,
    import_arena_events,
    function_name_prefix,
    root_visible_rel_path~,
  )
}

///|
pub fn trace_compat_writer_module_plan_for_source_with_generated_imports_and_import_arena_events(
  source : String,
  generated_import_provenance : Array[@ir.WgslIrGeneratedImportProvenance],
  import_arena_events : Array[@ir.WgslIrImportArenaEvent],
  root_visible_rel_path? : String = "",
) -> String raise @ir.WgslIrPipelineError {
  @ir.trace_compat_writer_module_plan_for_source_with_generated_imports_and_import_arena_events(
    source,
    generated_import_provenance,
    import_arena_events,
    root_visible_rel_path~,
  )
}
