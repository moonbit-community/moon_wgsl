///|
priv struct WgslIrEmitOptions {
  preserve_abstract_float_literals : Bool
  annotate_atomic_compare_exchange_result_locals : Bool
  inline_generated_import_constants : Bool
  fold_numeric_constant_expressions : Bool
  expand_matrix_scalar_constructors : Bool
  annotate_all_local_types : Bool
}

///|
fn WgslIrEmitOptions::valid_wgsl() -> WgslIrEmitOptions {
  WgslIrEmitOptions::{
    preserve_abstract_float_literals: false,
    annotate_atomic_compare_exchange_result_locals: false,
    inline_generated_import_constants: false,
    fold_numeric_constant_expressions: false,
    expand_matrix_scalar_constructors: false,
    annotate_all_local_types: false,
  }
}

///|
fn WgslIrEmitOptions::naga_oil_writer_compatible() -> WgslIrEmitOptions {
  WgslIrEmitOptions::{
    preserve_abstract_float_literals: false,
    annotate_atomic_compare_exchange_result_locals: true,
    inline_generated_import_constants: true,
    fold_numeric_constant_expressions: true,
    expand_matrix_scalar_constructors: true,
    annotate_all_local_types: true,
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
      fold_numeric_constant_expressions: self.options.fold_numeric_constant_expressions,
      expand_matrix_scalar_constructors: self.options.expand_matrix_scalar_constructors,
      annotate_all_local_types: self.options.annotate_all_local_types,
    },
    filter: self.filter,
    names: self.names,
    current_function_origin: self.current_function_origin,
    baked_function_expressions: self.baked_function_expressions,
  }
}
