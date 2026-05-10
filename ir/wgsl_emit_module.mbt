///|
fn WgslIrEmitter::emit_module(
  self : WgslIrEmitter,
) -> String raise WgslIrEmitError {
  let out = StringBuilder::new()
  let mut needs_blank = false
  let mut last_item_is_entry_point = false
  for directive in self.shader_module.directives {
    out.write_string(directive)
    out.write_string("\n")
    needs_blank = true
    last_item_is_entry_point = false
  }
  for index in 0..<self.shader_module.types.items.length() {
    if !self.should_emit_type(index) {
      continue
    }
    let ty = self.shader_module.types.items[index]
    match ty.inner {
      Struct(_, _) if ty.name != None => {
        if needs_blank {
          out.write_string("\n")
        }
        self.emit_struct_type(out, ty)
        needs_blank = true
        last_item_is_entry_point = false
      }
      _ => ()
    }
  }
  let mut emitted_constant = false
  for index in 0..<self.shader_module.constants.items.length() {
    if !self.should_emit_constant(index) {
      continue
    }
    if needs_blank && !emitted_constant {
      out.write_string("\n")
    }
    self.emit_constant(out, self.shader_module.constants.items[index])
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
  for index in 0..<self.shader_module.overrides.items.length() {
    if !self.should_emit_override(index) {
      continue
    }
    if needs_blank && !emitted_override {
      out.write_string("\n")
    }
    self.emit_override(out, self.shader_module.overrides.items[index])
    needs_blank = true
    last_item_is_entry_point = false
    emitted_override = true
  }
  let mut emitted_global_variable = false
  for index in 0..<self.shader_module.global_variables.items.length() {
    if !self.should_emit_global_variable(index) {
      continue
    }
    if needs_blank && !emitted_global_variable {
      out.write_string("\n")
    }
    self.emit_global_variable(
      out,
      self.shader_module.global_variables.items[index],
    )
    needs_blank = true
    last_item_is_entry_point = false
    emitted_global_variable = true
  }
  for index in 0..<self.shader_module.functions.items.length() {
    if !self.should_emit_function(index) {
      continue
    }
    if self.function_is_entry_point_name(
        self.shader_module.functions.items[index],
      ) {
      continue
    }
    if needs_blank {
      out.write_string("\n")
    }
    self.emit_function(out, self.shader_module.functions.items[index], None)
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
    self.emit_entry_point(out, entry_point)
    needs_blank = true
    last_item_is_entry_point = true
  }
  if needs_blank && !last_item_is_entry_point {
    out.write_string("\n")
  }
  out.to_string()
}

///|
fn WgslIrEmitter::should_emit_type(self : WgslIrEmitter, index : Int) -> Bool {
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
