///|
priv struct WgslIrEmitOptions {
  preserve_abstract_float_literals : Bool
  annotate_atomic_compare_exchange_result_locals : Bool
  inline_generated_import_constants : Bool
  fold_integer_constant_expressions : Bool
  expand_matrix_scalar_constructors : Bool
}

///|
fn WgslIrEmitOptions::valid_wgsl() -> WgslIrEmitOptions {
  WgslIrEmitOptions::{
    preserve_abstract_float_literals: false,
    annotate_atomic_compare_exchange_result_locals: false,
    inline_generated_import_constants: false,
    fold_integer_constant_expressions: false,
    expand_matrix_scalar_constructors: false,
  }
}

///|
fn WgslIrEmitOptions::naga_oil_writer_compatible() -> WgslIrEmitOptions {
  WgslIrEmitOptions::{
    preserve_abstract_float_literals: false,
    annotate_atomic_compare_exchange_result_locals: true,
    inline_generated_import_constants: true,
    fold_integer_constant_expressions: true,
    expand_matrix_scalar_constructors: true,
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
      fold_integer_constant_expressions: self.options.fold_integer_constant_expressions,
      expand_matrix_scalar_constructors: self.options.expand_matrix_scalar_constructors,
    },
    filter: self.filter,
  }
}
