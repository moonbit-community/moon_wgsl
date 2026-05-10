///|
fn WgslIrEmitter::constant_name(
  self : WgslIrEmitter,
  handle : Handle,
) -> String raise WgslIrEmitError {
  match self.shader_module.constants.items.get(handle.index()) {
    Some(constant) =>
      match constant.name {
        Some(name) => sanitize_wgsl_ir_identifier(name)
        None => raise WgslIrEmitError::MissingName("constant \{handle.index()}")
      }
    None => raise WgslIrEmitError::MissingHandle("constant \{handle.index()}")
  }
}

///|
fn WgslIrEmitter::constant_expression(
  self : WgslIrEmitter,
  handle : Handle,
) -> String raise WgslIrEmitError {
  match self.shader_module.constants.items.get(handle.index()) {
    Some(constant) =>
      if self.options.inline_generated_import_constants && constant.inline_value {
        self.global_expression(constant.init)
      } else {
        self.constant_name(handle)
      }
    None => raise WgslIrEmitError::MissingHandle("constant \{handle.index()}")
  }
}

///|
fn WgslIrEmitter::override_name(
  self : WgslIrEmitter,
  handle : Handle,
) -> String raise WgslIrEmitError {
  match self.shader_module.overrides.items.get(handle.index()) {
    Some(override_) =>
      match override_.name {
        Some(name) => sanitize_wgsl_ir_identifier(name)
        None => raise WgslIrEmitError::MissingName("override \{handle.index()}")
      }
    None => raise WgslIrEmitError::MissingHandle("override \{handle.index()}")
  }
}

///|
fn WgslIrEmitter::global_variable_name(
  self : WgslIrEmitter,
  handle : Handle,
) -> String raise WgslIrEmitError {
  match self.shader_module.global_variables.items.get(handle.index()) {
    Some(global) =>
      match global.name {
        Some(name) => sanitize_wgsl_ir_identifier(name)
        None =>
          raise WgslIrEmitError::MissingName(
            "global variable \{handle.index()}",
          )
      }
    None =>
      raise WgslIrEmitError::MissingHandle("global variable \{handle.index()}")
  }
}

///|
fn WgslIrEmitter::function_name(
  self : WgslIrEmitter,
  handle : Handle,
) -> String raise WgslIrEmitError {
  match self.shader_module.functions.items.get(handle.index()) {
    Some(function) =>
      match function.name {
        Some(name) => sanitize_wgsl_ir_identifier(name)
        None => raise WgslIrEmitError::MissingName("function \{handle.index()}")
      }
    None => raise WgslIrEmitError::MissingHandle("function \{handle.index()}")
  }
}

///|
fn WgslIrEmitter::function_argument_name(
  self : WgslIrEmitter,
  function : Function?,
  index : Int,
) -> String raise WgslIrEmitError {
  guard function is Some(func) else {
    raise WgslIrEmitError::Unsupported("function argument outside function")
  }
  match func.arguments.get(index) {
    Some(argument) => {
      let base_name = self.function_argument_base_name(argument, index)
      if self.function_argument_name_needs_suffix(func, index, base_name) {
        "\{base_name}_1"
      } else {
        base_name
      }
    }
    None => raise WgslIrEmitError::MissingHandle("function argument \{index}")
  }
}

///|
fn WgslIrEmitter::function_argument_base_name(
  self : WgslIrEmitter,
  argument : FunctionArgument,
  index : Int,
) -> String {
  ignore(self)
  match argument.name {
    Some(name) => sanitize_wgsl_ir_identifier(name)
    None => "arg\{index}"
  }
}

///|
fn WgslIrEmitter::function_argument_name_needs_suffix(
  self : WgslIrEmitter,
  function : Function,
  argument_index : Int,
  base_name : String,
) -> Bool {
  if self.function_is_entry_point_name(function) {
    return false
  }
  if !self.function_is_generated_import_function(function) {
    return false
  }
  for index in 0..<argument_index {
    if self.function_argument_base_name(function.arguments[index], index) ==
      base_name {
      return true
    }
  }
  if self.previous_generated_import_function_uses_argument_name(
      function, base_name,
    ) {
    return true
  }
  self.entry_point_function_uses_local_name(base_name)
}

///|
fn WgslIrEmitter::previous_generated_import_function_uses_argument_name(
  self : WgslIrEmitter,
  function : Function,
  base_name : String,
) -> Bool {
  guard function.name is Some(current_name) else { return false }
  for sibling in self.shader_module.functions.items {
    match sibling.name {
      Some(name) if name == current_name => return false
      _ => ()
    }
    if self.function_is_generated_import_function(sibling) {
      for index in 0..<sibling.arguments.length() {
        if self.function_argument_base_name(sibling.arguments[index], index) ==
          base_name {
          return true
        }
      }
    }
  }
  false
}

///|
fn WgslIrEmitter::function_is_generated_import_function(
  self : WgslIrEmitter,
  function : Function,
) -> Bool {
  ignore(self)
  function.generated_import
}

///|
fn WgslIrEmitter::entry_point_function_uses_local_name(
  self : WgslIrEmitter,
  name : String,
) -> Bool {
  for entry_point in self.shader_module.entry_points {
    for index in 0..<entry_point.function.arguments.length() {
      if self.function_argument_base_name(
          entry_point.function.arguments[index],
          index,
        ) ==
        name {
        return true
      }
    }
    for index in 0..<entry_point.function.local_variables.items.length() {
      if self.local_variable_base_name(
          entry_point.function.local_variables.items[index],
          Handle::Handle(index),
        ) ==
        name {
        return true
      }
    }
  }
  false
}

///|
fn WgslIrEmitter::local_variable_name(
  self : WgslIrEmitter,
  function : Function?,
  handle : Handle,
) -> String raise WgslIrEmitError {
  ignore(self)
  guard function is Some(func) else {
    raise WgslIrEmitError::Unsupported("local variable outside function")
  }
  match func.local_variables.items.get(handle.index()) {
    Some(local_var) => {
      let base_name = self.local_variable_base_name(local_var, handle)
      if self.local_variable_name_needs_suffix(func, handle, base_name) {
        "\{base_name}_\{handle.index()}"
      } else {
        base_name
      }
    }
    None =>
      raise WgslIrEmitError::MissingHandle("local variable \{handle.index()}")
  }
}

///|
fn WgslIrEmitter::local_variable_base_name(
  self : WgslIrEmitter,
  local_var : LocalVariable,
  handle : Handle,
) -> String {
  ignore(self)
  match local_var.name {
    Some(name) => sanitize_wgsl_ir_identifier(name)
    None => "local\{handle.index()}"
  }
}

///|
fn WgslIrEmitter::local_variable_name_needs_suffix(
  self : WgslIrEmitter,
  function : Function,
  handle : Handle,
  base_name : String,
) -> Bool {
  for index in 0..<function.arguments.length() {
    if self.function_argument_base_name(function.arguments[index], index) ==
      base_name {
      return true
    }
  }
  for index in 0..<function.local_variables.items.length() {
    if index == handle.index() {
      return false
    }
    if self.local_variable_base_name(
        function.local_variables.items[index],
        Handle::Handle(index),
      ) ==
      base_name {
      return true
    }
  }
  false
}
