///|
priv struct WgslIrEmitOptions {
  preserve_abstract_float_literals : Bool
  annotate_atomic_compare_exchange_result_locals : Bool
  inline_generated_import_constants : Bool
}

///|
fn WgslIrEmitOptions::valid_wgsl() -> WgslIrEmitOptions {
  WgslIrEmitOptions::{
    preserve_abstract_float_literals: false,
    annotate_atomic_compare_exchange_result_locals: false,
    inline_generated_import_constants: false,
  }
}

///|
fn WgslIrEmitOptions::naga_oil_writer_compatible() -> WgslIrEmitOptions {
  WgslIrEmitOptions::{
    preserve_abstract_float_literals: false,
    annotate_atomic_compare_exchange_result_locals: true,
    inline_generated_import_constants: true,
  }
}

///|
fn WgslIrEmitter::with_preserved_abstract_float_literals(
  self : WgslIrEmitter,
) -> WgslIrEmitter {
  WgslIrEmitter::{
    shader_module: self.shader_module,
    options: WgslIrEmitOptions::{
      preserve_abstract_float_literals: true,
      annotate_atomic_compare_exchange_result_locals: self.options.annotate_atomic_compare_exchange_result_locals,
      inline_generated_import_constants: self.options.inline_generated_import_constants,
    },
    filter: self.filter,
  }
}
