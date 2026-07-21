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
pub(all) struct WgslNagaPipelineOptions {
  compat_writer : Bool
  entry_roots : Bool
}

///|
pub struct WgslNagaComposeContext {
  priv generated_import_provenance : Array[WgslNagaGeneratedImportProvenance]
  priv import_arena_events : Array[WgslNagaImportArenaEvent]
  priv root_visible_rel_path : String
}

///|
pub fn WgslNagaPipelineOptions::default() -> WgslNagaPipelineOptions {
  { compat_writer: false, entry_roots: false }
}

///|
pub fn WgslNagaPipelineOptions::runtime() -> WgslNagaPipelineOptions {
  WgslNagaPipelineOptions::default()
}

///|
pub fn WgslNagaPipelineOptions::compat() -> WgslNagaPipelineOptions {
  { ..WgslNagaPipelineOptions::default(), compat_writer: true }
}

///|
pub fn WgslNagaComposeContext::empty() -> WgslNagaComposeContext {
  {
    generated_import_provenance: [],
    import_arena_events: [],
    root_visible_rel_path: "",
  }
}

///|
pub fn WgslNagaComposeContext::from_import_graph(
  generated_import_provenance : Array[WgslNagaGeneratedImportProvenance],
  import_arena_events : Array[WgslNagaImportArenaEvent],
  root_visible_rel_path? : String = "",
) -> WgslNagaComposeContext {
  { generated_import_provenance, import_arena_events, root_visible_rel_path }
}

///|
fn lower_validated_wgsl_source_to_ir(
  source : String,
) -> Module raise WgslNagaPipelineError {
  let module_ = parse_wgsl_module_to_ir(source) catch {
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
fn lower_validated_wgsl_source_to_ir_with_options(
  source : String,
  context : WgslNagaComposeContext,
) -> Module raise WgslNagaPipelineError {
  ignore(context)
  lower_validated_wgsl_source_to_ir(source)
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
pub fn roundtrip_wgsl_source(
  source : String,
  options? : WgslNagaPipelineOptions = WgslNagaPipelineOptions::runtime(),
) -> String raise WgslNagaPipelineError {
  roundtrip_wgsl_source_with_compose_context(
    source,
    WgslNagaComposeContext::empty(),
    options,
  )
}

///|
pub fn roundtrip_wgsl_compose_source(
  source : String,
  context : WgslNagaComposeContext,
  options? : WgslNagaPipelineOptions = WgslNagaPipelineOptions::compat(),
) -> String raise WgslNagaPipelineError {
  roundtrip_wgsl_source_with_compose_context(source, context, options)
}

///|
fn roundtrip_wgsl_source_with_compose_context(
  source : String,
  context : WgslNagaComposeContext,
  options : WgslNagaPipelineOptions,
) -> String raise WgslNagaPipelineError {
  let module_ = lower_validated_wgsl_source_to_ir_with_options(source, context)
  emit_wgsl_module_with_options(
    module_,
    options,
    compatibility=WgslNagaCompatibilityView::from_context(context),
  )
}

///|
fn roundtrip_wgsl_source_via_ir(
  source : String,
) -> String raise WgslNagaPipelineError {
  roundtrip_wgsl_source(source)
}

///|
fn emit_wgsl_module_with_options(
  module_ : Module,
  options : WgslNagaPipelineOptions,
  compatibility? : WgslNagaCompatibilityView = WgslNagaCompatibilityView::empty(),
) -> String raise WgslNagaPipelineError {
  let roots = if options.entry_roots {
    wgsl_ir_entry_point_root_items(module_)
  } else {
    []
  }
  if options.compat_writer {
    if roots.length() == 0 {
      emit_wgsl_module_from_ir_compat_writer(module_, compatibility~) catch {
        error => raise Emit(error.message())
      }
    } else {
      emit_wgsl_module_from_ir_compat_writer_roots(
        module_,
        roots,
        compatibility~,
      ) catch {
        error => raise Emit(error.message())
      }
    }
  } else if roots.length() == 0 {
    emit_wgsl_module_from_ir(module_, compatibility~) catch {
      error => raise Emit(error.message())
    }
  } else {
    emit_wgsl_module_from_ir_roots(module_, roots, compatibility~) catch {
      error => raise Emit(error.message())
    }
  }
}

///|
fn roundtrip_runtime_entry_roots(
  source : String,
  generated_import_provenance : Array[WgslNagaGeneratedImportProvenance],
  import_arena_events : Array[WgslNagaImportArenaEvent],
) -> String raise WgslNagaPipelineError {
  roundtrip_wgsl_compose_source(
    source,
    WgslNagaComposeContext::from_import_graph(
      generated_import_provenance, import_arena_events,
    ),
    options={ ..WgslNagaPipelineOptions::runtime(), entry_roots: true },
  )
}

///|
fn roundtrip_wgsl_source_via_ir_with_generated_imports_compat_writer(
  source : String,
  generated_import_provenance : Array[WgslNagaGeneratedImportProvenance],
) -> String raise WgslNagaPipelineError {
  roundtrip_compat_import_context(source, generated_import_provenance, [])
}

///|
fn roundtrip_compat_import_context(
  source : String,
  generated_import_provenance : Array[WgslNagaGeneratedImportProvenance],
  import_arena_events : Array[WgslNagaImportArenaEvent],
  root_visible_rel_path? : String = "",
) -> String raise WgslNagaPipelineError {
  roundtrip_wgsl_compose_source(
    source,
    WgslNagaComposeContext::from_import_graph(
      generated_import_provenance,
      import_arena_events,
      root_visible_rel_path~,
    ),
  )
}

///|
fn roundtrip_compat_entry_roots(
  source : String,
  generated_import_provenance : Array[WgslNagaGeneratedImportProvenance],
  import_arena_events : Array[WgslNagaImportArenaEvent],
) -> String raise WgslNagaPipelineError {
  roundtrip_wgsl_compose_source(
    source,
    WgslNagaComposeContext::from_import_graph(
      generated_import_provenance, import_arena_events,
    ),
    options={ ..WgslNagaPipelineOptions::compat(), entry_roots: true },
  )
}
