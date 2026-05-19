///|
fn WgslIrEmitter::emit_module(
  self : WgslIrEmitter,
) -> String raise WgslIrEmitError {
  let out = StringBuilder::new()
  let mut needs_blank = false
  let mut last_item_is_entry_point = false
  if self.options.emit_source_directives {
    for directive in self.shader_module.directives {
      out.write_string(directive)
      out.write_string("\n")
      needs_blank = true
      last_item_is_entry_point = false
    }
  }
  for index in self.type_emission_order() {
    if !self.should_emit_type(index) {
      continue
    }
    let ty = self.shader_module.types.items[index]
    match ty.inner {
      Struct(_, _) if ty.name != None => {
        if needs_blank {
          out.write_string("\n")
        }
        self.emit_struct_type(out, Handle::Handle(index), ty)
        needs_blank = true
        last_item_is_entry_point = false
      }
      _ => ()
    }
  }
  let mut emitted_constant = false
  for index in self.constant_emission_order() {
    if !self.should_emit_constant(index) {
      continue
    }
    if needs_blank && !emitted_constant {
      out.write_string("\n")
    }
    self.emit_constant(
      out,
      Handle::Handle(index),
      self.shader_module.constants.items[index],
    )
    needs_blank = true
    last_item_is_entry_point = false
    emitted_constant = true
  }
  let mut emitted_const_assert = false
  for condition in self.shader_module.const_asserts {
    if needs_blank && !emitted_const_assert {
      out.write_string("\n")
    }
    self.emit_global_const_assert(out, condition)
    needs_blank = true
    last_item_is_entry_point = false
    emitted_const_assert = true
  }
  let mut emitted_override = false
  for index in self.override_emission_order() {
    if !self.should_emit_override(index) {
      continue
    }
    if needs_blank && !emitted_override {
      out.write_string("\n")
    }
    self.emit_override(
      out,
      Handle::Handle(index),
      self.shader_module.overrides.items[index],
    )
    needs_blank = true
    last_item_is_entry_point = false
    emitted_override = true
  }
  let mut emitted_global_variable = false
  for index in self.global_variable_emission_order() {
    if !self.should_emit_global_variable(index) {
      continue
    }
    if needs_blank && !emitted_global_variable {
      out.write_string("\n")
    }
    self.emit_global_variable(
      out,
      Handle::Handle(index),
      self.shader_module.global_variables.items[index],
    )
    needs_blank = true
    last_item_is_entry_point = false
    emitted_global_variable = true
  }
  for index in self.function_emission_order() {
    if needs_blank {
      out.write_string("\n")
    }
    self.emit_function(
      out,
      self.shader_module.functions.items[index],
      UserFunction(index),
    )
    needs_blank = true
    last_item_is_entry_point = false
  }
  for index in 0..<self.shader_module.entry_points.length() {
    if !self.should_emit_entry_point(index) {
      continue
    }
    let entry_point = self.shader_module.entry_points[index]
    if needs_blank {
      out.write_string("\n")
    }
    self.emit_entry_point(out, entry_point, index)
    needs_blank = true
    last_item_is_entry_point = true
  }
  if needs_blank && !last_item_is_entry_point {
    out.write_string("\n")
  }
  out.to_string()
}

///|
fn WgslIrEmitter::type_emission_order(self : WgslIrEmitter) -> Array[Int] {
  match self.naga_writer_module {
    Some(view) => return view.type_order()
    None => ()
  }
  match self.filter {
    Some(filter) => filter.type_order
    None => self.default_type_emission_order()
  }
}

///|
fn WgslIrEmitter::constant_emission_order(self : WgslIrEmitter) -> Array[Int] {
  match self.naga_writer_module {
    Some(view) => return view.constant_order()
    None => ()
  }
  match self.filter {
    Some(filter) => filter.constant_order
    None => self.default_constant_emission_order()
  }
}

///|
fn WgslIrEmitter::override_emission_order(self : WgslIrEmitter) -> Array[Int] {
  match self.naga_writer_module {
    Some(view) => return view.override_order()
    None => ()
  }
  match self.filter {
    Some(filter) => filter.override_order
    None => self.default_override_emission_order()
  }
}

///|
fn WgslIrEmitter::global_variable_emission_order(
  self : WgslIrEmitter,
) -> Array[Int] {
  match self.naga_writer_module {
    Some(view) => return view.global_variable_order()
    None => ()
  }
  match self.filter {
    Some(filter) => filter.global_variable_order
    None => self.default_global_variable_emission_order()
  }
}

///|
fn WgslIrEmitter::default_type_emission_order(
  self : WgslIrEmitter,
) -> Array[Int] {
  let order : Array[Int] = []
  for index in 0..<self.shader_module.types.items.length() {
    order.push(index)
  }
  order
}

///|
fn WgslIrEmitter::default_constant_emission_order(
  self : WgslIrEmitter,
) -> Array[Int] {
  let order : Array[Int] = []
  for index in 0..<self.shader_module.constants.items.length() {
    order.push(index)
  }
  order
}

///|
fn WgslIrEmitter::default_override_emission_order(
  self : WgslIrEmitter,
) -> Array[Int] {
  let order : Array[Int] = []
  for index in 0..<self.shader_module.overrides.items.length() {
    order.push(index)
  }
  order
}

///|
fn WgslIrEmitter::default_global_variable_emission_order(
  self : WgslIrEmitter,
) -> Array[Int] {
  let order : Array[Int] = []
  for index in 0..<self.shader_module.global_variables.items.length() {
    order.push(index)
  }
  order
}

///|
fn WgslIrEmitter::should_emit_type(self : WgslIrEmitter, index : Int) -> Bool {
  match self.naga_writer_module {
    Some(module_) => return module_.contains_type_declaration(index)
    None => ()
  }
  match self.filter {
    Some(filter) => filter.contains_type(index)
    None => true
  }
}

///|
fn WgslIrEmitter::should_emit_constant(
  self : WgslIrEmitter,
  index : Int,
) -> Bool {
  match self.shader_module.constants.items.get(index) {
    Some(constant) if self.should_inline_constant_expression(constant) =>
      return false
    _ => ()
  }
  match self.naga_writer_module {
    Some(module_) => return module_.contains_constant_declaration(index)
    None => ()
  }
  match self.filter {
    Some(filter) => filter.contains_constant(index)
    None => true
  }
}

///|
fn WgslIrEmitter::should_emit_override(
  self : WgslIrEmitter,
  index : Int,
) -> Bool {
  match self.naga_writer_module {
    Some(module_) => return module_.contains_override_declaration(index)
    None => ()
  }
  match self.filter {
    Some(filter) => filter.contains_override(index)
    None => true
  }
}

///|
fn WgslIrEmitter::should_emit_global_variable(
  self : WgslIrEmitter,
  index : Int,
) -> Bool {
  match self.naga_writer_module {
    Some(module_) => return module_.contains_global_variable_declaration(index)
    None => ()
  }
  match self.filter {
    Some(filter) => filter.contains_global_variable(index)
    None => true
  }
}

///|
fn WgslIrEmitter::should_emit_function(
  self : WgslIrEmitter,
  index : Int,
) -> Bool {
  match self.naga_writer_module {
    Some(module_) => return module_.contains_function_declaration(index)
    None => ()
  }
  match self.filter {
    Some(filter) => filter.contains_function(index)
    None => true
  }
}

///|
fn WgslIrEmitter::should_emit_entry_point(
  self : WgslIrEmitter,
  index : Int,
) -> Bool {
  match self.filter {
    Some(filter) => filter.contains_entry_point(index)
    None => true
  }
}

///|
fn WgslIrEmitter::emit_global_const_assert(
  self : WgslIrEmitter,
  out : StringBuilder,
  condition : Handle,
) -> Unit raise WgslIrEmitError {
  out.write_string(
    "const_assert \{self.abstract_float_global_expression(condition)};\n",
  )
}

///|
fn WgslIrEmitter::function_is_entry_point_name(
  self : WgslIrEmitter,
  function : Function,
) -> Bool {
  match function.name {
    Some(name) =>
      for entry_point in self.shader_module.entry_points {
        if entry_point.name == name {
          return true
        }
      }
    None => ()
  }
  false
}
