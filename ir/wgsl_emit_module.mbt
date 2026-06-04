///|
fn WgslIrEmitter::emit_module(
  self : WgslIrEmitter,
) -> String raise WgslIrEmitError {
  let module_ = self.writer_module
  let out = StringBuilder::new()
  let mut needs_blank = false
  let mut last_item_is_entry_point = false
  if self.options.emit_source_directives() {
    for directive in module_.source_directives() {
      out.write_string(directive)
      out.write_string("\n")
      needs_blank = true
      last_item_is_entry_point = false
    }
  }
  for slot in module_.type_slots() {
    let ty = slot.item
    match ty.inner {
      Struct(_, _) if ty.name != None => {
        if needs_blank {
          out.write_string("\n")
        }
        self.emit_struct_type(out, Handle(slot.source_index), ty)
        needs_blank = true
        last_item_is_entry_point = false
      }
      _ => ()
    }
  }
  let mut emitted_constant = false
  for slot in module_.constant_slots() {
    if self.should_inline_constant_expression(slot.item) {
      continue
    }
    if needs_blank && !emitted_constant {
      out.write_string("\n")
    }
    self.emit_constant(out, Handle(slot.source_index), slot.item)
    needs_blank = true
    last_item_is_entry_point = false
    emitted_constant = true
  }
  self.naga_compatible_negative_zero_seen = false
  let mut emitted_const_assert = false
  for slot in module_.const_assert_slots() {
    if needs_blank && !emitted_const_assert {
      out.write_string("\n")
    }
    self.emit_global_const_assert(out, slot.condition)
    needs_blank = true
    last_item_is_entry_point = false
    emitted_const_assert = true
  }
  let mut emitted_override = false
  for slot in module_.override_slots() {
    if needs_blank && !emitted_override {
      out.write_string("\n")
    }
    self.emit_override(out, Handle(slot.source_index), slot.item)
    needs_blank = true
    last_item_is_entry_point = false
    emitted_override = true
  }
  let mut emitted_global_variable = false
  for slot in module_.global_variable_slots() {
    if needs_blank && !emitted_global_variable {
      out.write_string("\n")
    }
    self.emit_global_variable(out, Handle(slot.source_index), slot.item)
    needs_blank = true
    last_item_is_entry_point = false
    emitted_global_variable = true
  }
  for slot in module_.function_slots() {
    if needs_blank {
      out.write_string("\n")
    }
    self.emit_function(
      out,
      slot.item,
      slot.body_plan,
      UserFunction(slot.source_index),
    )
    needs_blank = true
    last_item_is_entry_point = false
  }
  for slot in module_.entry_point_slots() {
    if needs_blank {
      out.write_string("\n")
    }
    self.emit_entry_point(out, slot.item, slot.body_plan, slot.source_index)
    needs_blank = true
    last_item_is_entry_point = true
  }
  if needs_blank &&
    self.options.emit_trailing_blank_after_module(last_item_is_entry_point) {
    out.write_string("\n")
  }
  out.to_string()
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
