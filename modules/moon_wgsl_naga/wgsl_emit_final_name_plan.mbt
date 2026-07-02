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
priv struct WgslIrFinalNamePlan {
  names : Map[String, String]
}

///|
fn WgslIrFinalNamePlan::empty() -> WgslIrFinalNamePlan {
  { names: Map([]) }
}

///|
priv struct WgslIrWriterNamer {
  unique : Map[String, Int]
}

///|
priv enum WgslIrEmitFunctionOrigin {
  UserFunction(Int)
  EntryPointFunction(Int)
}

///|
fn WgslIrWriterNamer::WgslIrWriterNamer() -> WgslIrWriterNamer {
  { unique: Map([]) }
}

///|
fn WgslIrWriterNamer::call(self : WgslIrWriterNamer, raw : String) -> String {
  self.call_with_builtin_policy(raw, true)
}

///|
fn WgslIrWriterNamer::member_call(
  self : WgslIrWriterNamer,
  raw : String,
) -> String {
  let name = self.call_with_builtin_policy(raw, false)
  if wgsl_ir_identifier_ends_with_digit(name) {
    "\{name}_"
  } else {
    name
  }
}

///|
fn WgslIrWriterNamer::call_with_builtin_policy(
  self : WgslIrWriterNamer,
  raw : String,
  reserve_builtin_functions : Bool,
) -> String {
  let base = sanitize_wgsl_ir_writer_identifier_base(raw)
  match self.unique.get(base) {
    Some(count) => {
      let next = count + 1
      self.unique.set(base, next)
      "\{base}_\{next}"
    }
    None => {
      self.unique.set(base, 0)
      if (
          !wgsl_ir_identifier_is_expression_temporary(base) &&
          wgsl_ir_identifier_ends_with_digit(base)
        ) ||
        self.should_reserve_identifier(base, reserve_builtin_functions) ||
        (
          reserve_builtin_functions &&
          wgsl_ir_identifier_is_builtin_function(base)
        ) {
        "\{base}_"
      } else {
        base
      }
    }
  }
}

///|
fn WgslIrWriterNamer::call_preserving_trailing_digit(
  self : WgslIrWriterNamer,
  raw : String,
) -> String {
  let base = sanitize_wgsl_ir_writer_identifier_base(raw)
  match self.unique.get(base) {
    Some(count) => {
      let next = count + 1
      self.unique.set(base, next)
      "\{base}_\{next}"
    }
    None => {
      self.unique.set(base, 0)
      if self.should_reserve_identifier(base, true) ||
        wgsl_ir_identifier_is_builtin_function(base) {
        "\{base}_"
      } else {
        base
      }
    }
  }
}

///|
fn WgslIrWriterNamer::should_reserve_identifier(
  self : WgslIrWriterNamer,
  base : String,
  reserve_builtin_functions : Bool,
) -> Bool {
  ignore(self)
  if !wgsl_ir_identifier_is_reserved(base) {
    return false
  }
  reserve_builtin_functions || !wgsl_ir_identifier_is_builtin_function(base)
}

///|
fn WgslIrWriterNamer::call_or(
  self : WgslIrWriterNamer,
  name : String?,
  fallback : String,
) -> String {
  match name {
    Some(value) => self.call(value)
    None => self.call(fallback)
  }
}

///|
fn sanitize_wgsl_ir_writer_identifier_base(raw : String) -> String {
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
fn wgsl_ir_identifier_is_expression_temporary(name : String) -> Bool {
  guard name.length() > 2 && name[0:2] == "_e" else { return false }
  for i in 2..<name.length() {
    if !wgsl_ir_ascii_is_digit(name.code_unit_at(i).to_int()) {
      return false
    }
  }
  true
}

///|
fn WgslIrWriterNamer::local_call(
  self : WgslIrWriterNamer,
  temp_namer : WgslIrWriterNamer,
  raw : String,
) -> String {
  let base = sanitize_wgsl_ir_writer_identifier_base(raw)
  if wgsl_ir_identifier_is_expression_temporary(base) {
    temp_namer.call(base)
  } else {
    self.call(raw)
  }
}

///|
fn WgslIrWriterNamer::local_call_or(
  self : WgslIrWriterNamer,
  temp_namer : WgslIrWriterNamer,
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
fn WgslIrFinalNamePlan::get(
  self : WgslIrFinalNamePlan,
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
    None => raise MissingName("emitter name key \{key}")
  }
}

///|
fn WgslIrEmitter::with_function_origin(
  self : WgslIrEmitter,
  origin : WgslIrEmitFunctionOrigin,
) -> WgslIrEmitter {
  {
    shader_module: self.shader_module,
    options: self.options,
    writer_module: self.writer_module,
    names: self.names,
    current_function_origin: Some(origin),
    compat_negative_zero_seen: self.compat_negative_zero_seen,
    emitted_function_named_expressions: Set([]),
    emitted_function_materialized_expressions: Set([]),
  }
}
