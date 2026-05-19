///|
priv enum WgslIrWriterBackendKind {
  RuntimeWriter
  NagaOilWriter
}

///|
priv struct WgslIrEmitOptions {
  backend : WgslIrWriterBackendKind
  byte_plan : WgslIrWriterBytePlan
  preserve_abstract_float_literals : Bool
}

///|
fn WgslIrEmitOptions::valid_wgsl() -> WgslIrEmitOptions {
  WgslIrEmitOptions::{
    backend: RuntimeWriter,
    byte_plan: WgslIrWriterBytePlan::runtime_writer(),
    preserve_abstract_float_literals: false,
  }
}

///|
fn WgslIrEmitOptions::naga_oil_writer_backend() -> WgslIrEmitOptions {
  WgslIrEmitOptions::{
    backend: NagaOilWriter,
    byte_plan: WgslIrWriterBytePlan::naga_oil_writer(),
    preserve_abstract_float_literals: false,
  }
}

///|
fn WgslIrEmitOptions::preserve_abstract_float_literals(
  self : WgslIrEmitOptions,
) -> Bool {
  self.preserve_abstract_float_literals
}

///|
fn WgslIrEmitOptions::annotate_atomic_compare_exchange_result_locals(
  self : WgslIrEmitOptions,
) -> Bool {
  self.byte_plan.should_annotate_atomic_compare_exchange_result_locals()
}

///|
fn WgslIrEmitOptions::inline_generated_import_constants(
  self : WgslIrEmitOptions,
) -> Bool {
  match self.backend {
    NagaOilWriter => true
    RuntimeWriter => false
  }
}

///|
fn WgslIrEmitOptions::fold_numeric_constant_expressions(
  self : WgslIrEmitOptions,
) -> Bool {
  match self.backend {
    NagaOilWriter => true
    RuntimeWriter => false
  }
}

///|
fn WgslIrEmitOptions::expand_matrix_scalar_constructors(
  self : WgslIrEmitOptions,
) -> Bool {
  match self.backend {
    NagaOilWriter => true
    RuntimeWriter => false
  }
}

///|
fn WgslIrEmitOptions::contextualize_numeric_literals(
  self : WgslIrEmitOptions,
) -> Bool {
  match self.backend {
    NagaOilWriter => true
    RuntimeWriter => false
  }
}

///|
fn WgslIrEmitOptions::annotate_all_local_types(
  self : WgslIrEmitOptions,
) -> Bool {
  self.byte_plan.should_annotate_all_local_types()
}

///|
fn WgslIrEmitOptions::numeric_literal_policy(
  self : WgslIrEmitOptions,
) -> WgslIrNumericLiteralBytePolicy {
  self.byte_plan.numeric_literal_policy()
}

///|
fn WgslIrEmitOptions::emit_implicit_flat_interpolation(
  self : WgslIrEmitOptions,
) -> Bool {
  self.byte_plan.should_emit_implicit_flat_interpolation()
}

///|
fn WgslIrEmitOptions::storage_texture_type_argument_separator(
  self : WgslIrEmitOptions,
) -> String {
  self.byte_plan.storage_texture_type_separator()
}

///|
fn WgslIrEmitOptions::emit_source_directives(self : WgslIrEmitOptions) -> Bool {
  self.byte_plan.should_emit_source_directives()
}

///|
fn WgslIrEmitOptions::emit_trailing_blank_after_module(
  self : WgslIrEmitOptions,
  last_item_is_entry_point : Bool,
) -> Bool {
  self.byte_plan.should_emit_trailing_blank(last_item_is_entry_point)
}

///|
fn WgslIrEmitter::with_preserved_abstract_float_literals(
  self : WgslIrEmitter,
) -> WgslIrEmitter {
  WgslIrEmitter::{
    shader_module: self.shader_module,
    options: WgslIrEmitOptions::{
      backend: self.options.backend,
      byte_plan: self.options.byte_plan,
      preserve_abstract_float_literals: true,
    },
    writer_module: self.writer_module,
    names: self.names,
    current_function_origin: self.current_function_origin,
  }
}
