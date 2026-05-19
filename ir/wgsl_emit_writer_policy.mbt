///|
priv struct WgslIrEmitOptions {
  preserve_abstract_float_literals : Bool
  annotate_atomic_compare_exchange_result_locals : Bool
  inline_generated_import_constants : Bool
  fold_numeric_constant_expressions : Bool
  expand_matrix_scalar_constructors : Bool
  contextualize_numeric_literals : Bool
  annotate_all_local_types : Bool
  emit_implicit_flat_interpolation : Bool
  compact_storage_texture_type_arguments : Bool
  order_functions_by_naga_reachability : Bool
  emit_source_directives : Bool
}

///|
fn WgslIrEmitOptions::valid_wgsl() -> WgslIrEmitOptions {
  WgslIrEmitOptions::{
    preserve_abstract_float_literals: false,
    annotate_atomic_compare_exchange_result_locals: false,
    inline_generated_import_constants: false,
    fold_numeric_constant_expressions: false,
    expand_matrix_scalar_constructors: false,
    contextualize_numeric_literals: false,
    annotate_all_local_types: false,
    emit_implicit_flat_interpolation: false,
    compact_storage_texture_type_arguments: false,
    order_functions_by_naga_reachability: false,
    emit_source_directives: true,
  }
}

///|
fn WgslIrEmitOptions::naga_oil_writer_backend() -> WgslIrEmitOptions {
  WgslIrEmitOptions::{
    preserve_abstract_float_literals: false,
    annotate_atomic_compare_exchange_result_locals: true,
    inline_generated_import_constants: true,
    fold_numeric_constant_expressions: true,
    expand_matrix_scalar_constructors: true,
    contextualize_numeric_literals: true,
    annotate_all_local_types: true,
    emit_implicit_flat_interpolation: true,
    compact_storage_texture_type_arguments: true,
    order_functions_by_naga_reachability: true,
    emit_source_directives: false,
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
      contextualize_numeric_literals: self.options.contextualize_numeric_literals,
      annotate_all_local_types: self.options.annotate_all_local_types,
      emit_implicit_flat_interpolation: self.options.emit_implicit_flat_interpolation,
      compact_storage_texture_type_arguments: self.options.compact_storage_texture_type_arguments,
      order_functions_by_naga_reachability: self.options.order_functions_by_naga_reachability,
      emit_source_directives: self.options.emit_source_directives,
    },
    filter: self.filter,
    naga_compat_view: self.naga_compat_view,
    names: self.names,
    current_function_origin: self.current_function_origin,
    baked_function_expressions: self.baked_function_expressions,
  }
}
