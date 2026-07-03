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
pub suberror WgslNagaPipelineError {
  Lower(String)
  UnknownIdentifier(String)
  Emit(String)
  Validate(String)
}

///|
pub fn WgslNagaPipelineError::message(self : WgslNagaPipelineError) -> String {
  match self {
    Lower(message) => "IR lowering failed: \{message}"
    UnknownIdentifier(name) =>
      "IR lowering failed: unknown WGSL identifier in IR lowering: \{name}"
    Emit(message) => "IR emission failed: \{message}"
    Validate(message) => "IR validation failed: \{message}"
  }
}

///|
fn lower_validated_wgsl_source_to_ir(
  source : String,
) -> Module raise WgslNagaPipelineError {
  lower_validated_wgsl_source_to_ir_with_generated_imports_and_import_arena_events(
    source,
    [],
    [],
  )
}

///|
fn lower_validated_wgsl_source_to_ir_with_generated_imports_and_import_arena_events(
  source : String,
  generated_import_provenance : Array[@ir.WgslIrGeneratedImportProvenance],
  import_arena_events : Array[@ir.WgslIrImportArenaEvent],
  root_visible_rel_path? : String = "",
) -> Module raise WgslNagaPipelineError {
  let module_ = parse_wgsl_module_to_ir_with_generated_imports_and_import_arena_events(
    source,
    generated_import_provenance,
    import_arena_events,
    root_visible_rel_path~,
  ) catch {
    error =>
      match error {
        UnknownIdentifier(name) => raise UnknownIdentifier(name)
        _ => raise Lower(error.message())
      }
  }
  validate_wgsl_ir_module(module_) catch {
    error => raise Validate(error.message())
  }
  module_
}

///|
fn wgsl_ir_entry_point_root_items(module_ : Module) -> Array[String] {
  let roots : Array[String] = []
  for entry_point in module_.entry_points {
    roots.push(entry_point.name)
  }
  roots
}

///|
pub fn roundtrip_wgsl_source_via_ir(
  source : String,
) -> String raise WgslNagaPipelineError {
  let module_ = lower_validated_wgsl_source_to_ir(source)
  emit_wgsl_module_from_ir(module_) catch {
    error => raise Emit(error.message())
  }
}

///|
pub fn roundtrip_wgsl_source_via_ir_with_generated_imports_and_import_arena_events_entry_roots(
  source : String,
  generated_import_provenance : Array[@ir.WgslIrGeneratedImportProvenance],
  import_arena_events : Array[@ir.WgslIrImportArenaEvent],
) -> String raise WgslNagaPipelineError {
  let module_ = lower_validated_wgsl_source_to_ir_with_generated_imports_and_import_arena_events(
    source, generated_import_provenance, import_arena_events,
  )
  let roots = wgsl_ir_entry_point_root_items(module_)
  if roots.length() == 0 {
    emit_wgsl_module_from_ir(module_) catch {
      error => raise Emit(error.message())
    }
  } else {
    emit_wgsl_module_from_ir_roots(module_, roots) catch {
      error => raise Emit(error.message())
    }
  }
}

///|
pub fn roundtrip_wgsl_source_via_ir_with_generated_imports_compat_writer(
  source : String,
  generated_import_provenance : Array[@ir.WgslIrGeneratedImportProvenance],
) -> String raise WgslNagaPipelineError {
  roundtrip_wgsl_source_via_ir_with_generated_imports_and_import_arena_events_compat_writer(
    source,
    generated_import_provenance,
    [],
  )
}

///|
pub fn roundtrip_wgsl_source_via_ir_with_generated_imports_and_import_arena_events_compat_writer(
  source : String,
  generated_import_provenance : Array[@ir.WgslIrGeneratedImportProvenance],
  import_arena_events : Array[@ir.WgslIrImportArenaEvent],
  root_visible_rel_path? : String = "",
) -> String raise WgslNagaPipelineError {
  let module_ = lower_validated_wgsl_source_to_ir_with_generated_imports_and_import_arena_events(
    source,
    generated_import_provenance,
    import_arena_events,
    root_visible_rel_path~,
  )
  emit_wgsl_module_from_ir_compat_writer(module_) catch {
    error => raise Emit(error.message())
  }
}

///|
pub fn roundtrip_wgsl_source_via_ir_with_generated_imports_and_import_arena_events_compat_writer_entry_roots(
  source : String,
  generated_import_provenance : Array[@ir.WgslIrGeneratedImportProvenance],
  import_arena_events : Array[@ir.WgslIrImportArenaEvent],
) -> String raise WgslNagaPipelineError {
  let module_ = lower_validated_wgsl_source_to_ir_with_generated_imports_and_import_arena_events(
    source, generated_import_provenance, import_arena_events,
  )
  let roots = wgsl_ir_entry_point_root_items(module_)
  if roots.length() == 0 {
    emit_wgsl_module_from_ir_compat_writer(module_) catch {
      error => raise Emit(error.message())
    }
  } else {
    emit_wgsl_module_from_ir_compat_writer_roots(module_, roots) catch {
      error => raise Emit(error.message())
    }
  }
}
