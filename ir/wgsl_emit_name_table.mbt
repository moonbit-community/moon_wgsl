// Copyright 2026 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
priv struct WgslIrEmitNameTable {
  names : Map[String, String]
}

///|
priv struct WgslIrNagaNamer {
  unique : Map[String, Int]
}

///|
priv enum WgslIrEmitFunctionOrigin {
  UserFunction(Int)
  EntryPointFunction(Int)
}

///|
fn WgslIrNagaNamer::WgslIrNagaNamer() -> WgslIrNagaNamer {
  WgslIrNagaNamer::{ unique: Map([]) }
}

///|
fn WgslIrNagaNamer::call(self : WgslIrNagaNamer, raw : String) -> String {
  let base = sanitize_wgsl_ir_naga_identifier_base(raw)
  match self.unique.get(base) {
    Some(count) => {
      let next = count + 1
      self.unique.set(base, next)
      "\{base}_\{next}"
    }
    None => {
      self.unique.set(base, 0)
      if (
          !wgsl_ir_identifier_is_naga_expression_temporary(base) &&
          wgsl_ir_identifier_ends_with_digit(base)
        ) ||
        wgsl_ir_identifier_is_reserved(base) ||
        wgsl_ir_identifier_is_builtin_function(base) {
        "\{base}_"
      } else {
        base
      }
    }
  }
}

///|
fn WgslIrNagaNamer::call_or(
  self : WgslIrNagaNamer,
  name : String?,
  fallback : String,
) -> String {
  match name {
    Some(value) => self.call(value)
    None => self.call(fallback)
  }
}

///|
fn sanitize_wgsl_ir_naga_identifier_base(raw : String) -> String {
  let mut out = raw.trim().to_owned()
  while out.length() > 0 && wgsl_ir_ascii_is_digit(out.code_unit_at(0).to_int()) {
    out = out[1:].to_owned()
  }
  while out.has_suffix("_") {
    out = out[:out.length() - 1].to_owned()
  }
  while out.contains("__") {
    out = out.replace(old="__", new="_")
  }
  if out == "" {
    out = "unnamed"
  }
  if out.has_prefix("_naga") || out.has_prefix("__") {
    out = "gen_\{out}"
  }
  out
}

///|
fn wgsl_ir_ascii_is_digit(code : Int) -> Bool {
  code >= 48 && code <= 57
}

///|
fn wgsl_ir_identifier_is_naga_expression_temporary(name : String) -> Bool {
  guard name.length() > 2 && name[0:2] == "_e" else { return false }
  for i in 2..<name.length() {
    if !wgsl_ir_ascii_is_digit(name.code_unit_at(i).to_int()) {
      return false
    }
  }
  true
}

///|
fn WgslIrNagaNamer::local_call(
  self : WgslIrNagaNamer,
  temp_namer : WgslIrNagaNamer,
  raw : String,
) -> String {
  let base = sanitize_wgsl_ir_naga_identifier_base(raw)
  if wgsl_ir_identifier_is_naga_expression_temporary(base) {
    temp_namer.call(base)
  } else {
    self.call(raw)
  }
}

///|
fn WgslIrNagaNamer::local_call_or(
  self : WgslIrNagaNamer,
  temp_namer : WgslIrNagaNamer,
  name : String?,
  fallback : String,
) -> String {
  match name {
    Some(value) => self.local_call(temp_namer, value)
    None => self.local_call(temp_namer, fallback)
  }
}

///|
fn wgsl_ir_emit_name_key(kind : String, index : Int) -> String {
  "\{kind}:\{index}"
}

///|
fn wgsl_ir_emit_name_key2(kind : String, a : Int, b : Int) -> String {
  "\{kind}:\{a}:\{b}"
}

///|
fn build_wgsl_ir_emit_name_table(module_ : Module) -> WgslIrEmitNameTable {
  let table = WgslIrEmitNameTable::{ names: Map([]) }
  let namer = WgslIrNagaNamer::WgslIrNagaNamer()
  for index in 0..<module_.types.items.length() {
    let ty = module_.types.items[index]
    let raw = match ty.name {
      Some(name) => name
      None => "type"
    }
    table.names.set(wgsl_ir_emit_name_key("type", index), namer.call(raw))
    match ty.inner {
      Struct(members, _) | PredeclaredStruct(members, _) => {
        let member_namer = WgslIrNagaNamer::WgslIrNagaNamer()
        for member_index in 0..<members.length() {
          let raw = match members[member_index].name {
            Some(name) => name
            None => "member"
          }
          table.names.set(
            wgsl_ir_emit_name_key2("member", index, member_index),
            member_namer.call(raw),
          )
        }
      }
      _ => ()
    }
  }
  for ep_index in 0..<module_.entry_points.length() {
    let ep = module_.entry_points[ep_index]
    table.names.set(wgsl_ir_emit_name_key("ep", ep_index), namer.call(ep.name))
    for arg_index in 0..<ep.function.arguments.length() {
      table.names.set(
        wgsl_ir_emit_name_key2("ep_arg", ep_index, arg_index),
        namer.call_or(ep.function.arguments[arg_index].name, "param"),
      )
    }
  }
  for fn_index in 0..<module_.functions.items.length() {
    let function = module_.functions.items[fn_index]
    if wgsl_ir_name_table_function_is_entry_point(function, module_) {
      continue
    }
    table.names.set(
      wgsl_ir_emit_name_key("fn", fn_index),
      namer.call_or(function.name, "function"),
    )
    for arg_index in 0..<function.arguments.length() {
      table.names.set(
        wgsl_ir_emit_name_key2("fn_arg", fn_index, arg_index),
        namer.call_or(function.arguments[arg_index].name, "param"),
      )
    }
  }
  for index in 0..<module_.global_variables.items.length() {
    table.names.set(
      wgsl_ir_emit_name_key("global", index),
      namer.call_or(module_.global_variables.items[index].name, "global"),
    )
  }
  for index in 0..<module_.constants.items.length() {
    table.names.set(
      wgsl_ir_emit_name_key("const", index),
      namer.call_or(module_.constants.items[index].name, "const"),
    )
  }
  for index in 0..<module_.overrides.items.length() {
    table.names.set(
      wgsl_ir_emit_name_key("override", index),
      namer.call_or(module_.overrides.items[index].name, "override"),
    )
  }
  for ep_index in 0..<module_.entry_points.length() {
    let ep = module_.entry_points[ep_index]
    let temp_namer = WgslIrNagaNamer::WgslIrNagaNamer()
    for local_index in 0..<ep.function.local_variables.items.length() {
      table.names.set(
        wgsl_ir_emit_name_key2("ep_local", ep_index, local_index),
        namer.local_call_or(
          temp_namer,
          ep.function.local_variables.items[local_index].name,
          "local",
        ),
      )
    }
    for expr_index in 0..<ep.function.expressions.items.length() {
      match ep.function.expressions.items.get(expr_index) {
        Some(CallResult(_)) => {
          let semantic_index = wgsl_ir_emit_call_result_expression_index(
            ep.function,
            Handle::Handle(expr_index),
          )
          table.names.set(
            wgsl_ir_emit_name_key2("ep_expr", ep_index, expr_index),
            temp_namer.call("_e\{semantic_index}"),
          )
        }
        _ => ()
      }
    }
  }
  for fn_index in 0..<module_.functions.items.length() {
    let function = module_.functions.items[fn_index]
    if wgsl_ir_name_table_function_is_entry_point(function, module_) {
      continue
    }
    let temp_namer = WgslIrNagaNamer::WgslIrNagaNamer()
    for local_index in 0..<function.local_variables.items.length() {
      table.names.set(
        wgsl_ir_emit_name_key2("fn_local", fn_index, local_index),
        namer.local_call_or(
          temp_namer,
          function.local_variables.items[local_index].name,
          "local",
        ),
      )
    }
    for expr_index in 0..<function.expressions.items.length() {
      match function.expressions.items.get(expr_index) {
        Some(CallResult(_)) => {
          let semantic_index = wgsl_ir_emit_call_result_expression_index(
            function,
            Handle::Handle(expr_index),
          )
          table.names.set(
            wgsl_ir_emit_name_key2("fn_expr", fn_index, expr_index),
            temp_namer.call("_e\{semantic_index}"),
          )
        }
        _ => ()
      }
    }
  }
  table
}

///|
fn wgsl_ir_name_table_function_is_entry_point(
  function : Function,
  module_ : Module,
) -> Bool {
  match function.name {
    Some(name) =>
      for entry_point in module_.entry_points {
        if entry_point.name == name {
          return true
        }
      }
    None => ()
  }
  false
}

///|
fn wgsl_ir_emit_call_result_expression_index(
  function : Function,
  handle : Handle,
) -> Int {
  let mut skipped = 0
  for index in 0..<handle.index() {
    let expression_handle = Handle::Handle(index)
    if wgsl_ir_function_expression_is_synthetic_local_reference(
        function, expression_handle,
      ) ||
      wgsl_ir_function_expression_is_unmaterialized_function_argument_reference(
        function, expression_handle, handle,
      ) ||
      wgsl_ir_function_expression_is_atomic_compare_exchange_projection_role(
        function, expression_handle,
      ) {
      skipped += 1
    }
  }
  handle.index() - skipped
}

///|
fn WgslIrEmitNameTable::get(
  self : WgslIrEmitNameTable,
  key : String,
) -> String? {
  self.names.get(key)
}

///|
fn WgslIrEmitter::required_emit_name(
  self : WgslIrEmitter,
  key : String,
) -> String raise WgslIrEmitError {
  match self.names.get(key) {
    Some(value) => value
    None => raise WgslIrEmitError::MissingName("emitter name key \{key}")
  }
}

///|
fn WgslIrEmitter::with_function_origin(
  self : WgslIrEmitter,
  origin : WgslIrEmitFunctionOrigin,
) -> WgslIrEmitter {
  WgslIrEmitter::{
    shader_module: self.shader_module,
    options: self.options,
    filter: self.filter,
    names: self.names,
    current_function_origin: Some(origin),
    baked_function_expressions: Map([]),
  }
}

///|
fn wgsl_ir_emit_baked_function_expression_key(
  origin : WgslIrEmitFunctionOrigin,
  handle : Handle,
) -> String {
  match origin {
    UserFunction(index) => "function:\{index}:\{handle.index()}"
    EntryPointFunction(index) => "entry-point:\{index}:\{handle.index()}"
  }
}

///|
fn WgslIrEmitter::baked_function_expression_name(
  self : WgslIrEmitter,
  handle : Handle,
) -> String? {
  match self.current_function_origin {
    Some(origin) =>
      self.baked_function_expressions.get(
        wgsl_ir_emit_baked_function_expression_key(origin, handle),
      )
    None => None
  }
}

///|
fn WgslIrEmitter::record_baked_function_expression(
  self : WgslIrEmitter,
  handle : Handle,
  name : String,
) -> Unit {
  match self.current_function_origin {
    Some(origin) =>
      self.baked_function_expressions.set(
        wgsl_ir_emit_baked_function_expression_key(origin, handle),
        name,
      )
    None => ()
  }
}
