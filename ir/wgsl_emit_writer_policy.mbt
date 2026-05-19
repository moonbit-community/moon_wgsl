///|
priv enum WgslIrWriterBackendKind {
  RuntimeWriter
  NagaOilWriter
}

///|
priv struct WgslIrEmitOptions {
  backend : WgslIrWriterBackendKind
  preserve_abstract_float_literals : Bool
}

///|
fn WgslIrEmitOptions::valid_wgsl() -> WgslIrEmitOptions {
  WgslIrEmitOptions::{
    backend: RuntimeWriter,
    preserve_abstract_float_literals: false,
  }
}

///|
fn WgslIrEmitOptions::naga_oil_writer_backend() -> WgslIrEmitOptions {
  WgslIrEmitOptions::{
    backend: NagaOilWriter,
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
  match self.backend {
    NagaOilWriter => true
    RuntimeWriter => false
  }
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
  match self.backend {
    NagaOilWriter => true
    RuntimeWriter => false
  }
}

///|
fn WgslIrEmitOptions::emit_implicit_flat_interpolation(
  self : WgslIrEmitOptions,
) -> Bool {
  match self.backend {
    NagaOilWriter => true
    RuntimeWriter => false
  }
}

///|
fn WgslIrEmitOptions::compact_storage_texture_type_arguments(
  self : WgslIrEmitOptions,
) -> Bool {
  match self.backend {
    NagaOilWriter => true
    RuntimeWriter => false
  }
}

///|
fn WgslIrEmitOptions::emit_source_directives(self : WgslIrEmitOptions) -> Bool {
  match self.backend {
    RuntimeWriter => true
    NagaOilWriter => false
  }
}

///|
fn WgslIrEmitter::with_preserved_abstract_float_literals(
  self : WgslIrEmitter,
) -> WgslIrEmitter {
  WgslIrEmitter::{
    shader_module: self.shader_module,
    options: WgslIrEmitOptions::{
      backend: self.options.backend,
      preserve_abstract_float_literals: true,
    },
    filter: self.filter,
    naga_writer_module: self.naga_writer_module,
    names: self.names,
    current_function_origin: self.current_function_origin,
  }
}
