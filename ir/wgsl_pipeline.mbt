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
pub suberror WgslIrPipelineError {
  Lower(String)
  UnknownIdentifier(String)
  Emit(String)
  Validate(String)
  Reparse(String)
}

///|
pub fn WgslIrPipelineError::message(self : WgslIrPipelineError) -> String {
  match self {
    Lower(message) => "IR lowering failed: \{message}"
    UnknownIdentifier(name) =>
      "IR lowering failed: unknown WGSL identifier in IR lowering: \{name}"
    Emit(message) => "IR emission failed: \{message}"
    Validate(message) => "IR validation failed: \{message}"
    Reparse(message) => "IR emitted WGSL is invalid: \{message}"
  }
}

///|
fn lower_validated_wgsl_source_to_ir(
  source : String,
) -> Module raise WgslIrPipelineError {
  lower_validated_wgsl_source_to_ir_with_generated_imports(source, [])
}

///|
fn lower_validated_wgsl_source_to_ir_with_generated_imports(
  source : String,
  generated_import_provenance : Array[WgslIrGeneratedImportProvenance],
) -> Module raise WgslIrPipelineError {
  let module_ = parse_wgsl_module_to_ir_with_generated_imports(
    source, generated_import_provenance,
  ) catch {
    error =>
      match error {
        UnknownIdentifier(name) =>
          raise WgslIrPipelineError::UnknownIdentifier(name)
        _ => raise WgslIrPipelineError::Lower(error.message())
      }
  }
  validate_wgsl_ir_module(module_) catch {
    error => raise WgslIrPipelineError::Validate(error.message())
  }
  module_
}

///|
fn emit_validated_wgsl_source_from_ir(
  module_ : Module,
) -> String raise WgslIrPipelineError {
  let source = emit_wgsl_module_from_ir(module_) catch {
    error => raise WgslIrPipelineError::Emit(error.message())
  }
  let reparsed = parse_wgsl_module_to_ir(source) catch {
    error => raise WgslIrPipelineError::Reparse(error.message())
  }
  validate_wgsl_ir_module(reparsed) catch {
    error => raise WgslIrPipelineError::Reparse(error.message())
  }
  source
}

///|
fn emit_naga_oil_writer_compatible_wgsl_source_from_ir(
  module_ : Module,
) -> String raise WgslIrPipelineError {
  emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => raise WgslIrPipelineError::Emit(error.message())
  }
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
fn emit_validated_wgsl_source_from_ir_roots(
  module_ : Module,
  root_items : Array[String],
) -> String raise WgslIrPipelineError {
  let source = emit_wgsl_module_from_ir_roots(module_, root_items) catch {
    error => raise WgslIrPipelineError::Emit(error.message())
  }
  let reparsed = parse_wgsl_module_to_ir(source) catch {
    error => raise WgslIrPipelineError::Reparse(error.message())
  }
  validate_wgsl_ir_module(reparsed) catch {
    error => raise WgslIrPipelineError::Reparse(error.message())
  }
  source
}

///|
fn emit_validated_wgsl_source_from_ir_entry_roots(
  module_ : Module,
) -> String raise WgslIrPipelineError {
  let roots = wgsl_ir_entry_point_root_items(module_)
  if roots.length() == 0 {
    emit_validated_wgsl_source_from_ir(module_)
  } else {
    emit_validated_wgsl_source_from_ir_roots(module_, roots)
  }
}

///|
fn emit_naga_oil_writer_compatible_wgsl_source_from_ir_entry_roots(
  module_ : Module,
) -> String raise WgslIrPipelineError {
  let roots = wgsl_ir_entry_point_root_items(module_)
  if roots.length() == 0 {
    emit_naga_oil_writer_compatible_wgsl_source_from_ir(module_)
  } else {
    let source = emit_wgsl_module_from_ir_with_options_and_roots(
      module_,
      WgslIrEmitOptions::naga_oil_writer_compatible(),
      roots,
    ) catch {
      error => raise WgslIrPipelineError::Emit(error.message())
    }
    let reparsed = parse_wgsl_module_to_ir(source) catch {
      error => raise WgslIrPipelineError::Reparse(error.message())
    }
    validate_wgsl_ir_module(reparsed) catch {
      error => raise WgslIrPipelineError::Reparse(error.message())
    }
    source
  }
}

///|
pub fn roundtrip_wgsl_source_via_ir(
  source : String,
) -> String raise WgslIrPipelineError {
  roundtrip_wgsl_source_via_ir_with_generated_imports(source, [])
}

///|
pub fn roundtrip_wgsl_source_via_ir_with_generated_imports(
  source : String,
  generated_import_provenance : Array[WgslIrGeneratedImportProvenance],
) -> String raise WgslIrPipelineError {
  emit_validated_wgsl_source_from_ir(
    lower_validated_wgsl_source_to_ir_with_generated_imports(
      source, generated_import_provenance,
    ),
  )
}

///|
pub fn roundtrip_wgsl_source_via_ir_with_generated_imports_entry_roots(
  source : String,
  generated_import_provenance : Array[WgslIrGeneratedImportProvenance],
) -> String raise WgslIrPipelineError {
  emit_validated_wgsl_source_from_ir_entry_roots(
    lower_validated_wgsl_source_to_ir_with_generated_imports(
      source, generated_import_provenance,
    ),
  )
}

///|
pub fn roundtrip_wgsl_source_via_ir_with_generated_imports_naga_oil_writer_compatible(
  source : String,
  generated_import_provenance : Array[WgslIrGeneratedImportProvenance],
) -> String raise WgslIrPipelineError {
  emit_naga_oil_writer_compatible_wgsl_source_from_ir(
    lower_validated_wgsl_source_to_ir_with_generated_imports(
      source, generated_import_provenance,
    ),
  )
}

///|
pub fn roundtrip_wgsl_source_via_ir_with_generated_imports_naga_oil_writer_compatible_entry_roots(
  source : String,
  generated_import_provenance : Array[WgslIrGeneratedImportProvenance],
) -> String raise WgslIrPipelineError {
  emit_naga_oil_writer_compatible_wgsl_source_from_ir_entry_roots(
    lower_validated_wgsl_source_to_ir_with_generated_imports(
      source, generated_import_provenance,
    ),
  )
}

///|
pub fn tree_shake_wgsl_source_via_ir(
  source : String,
  root_items : Array[String],
) -> String raise WgslIrPipelineError {
  emit_validated_wgsl_source_from_ir_roots(
    lower_validated_wgsl_source_to_ir(source),
    root_items,
  )
}
