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
priv struct WgslIrRequiredEnableExtensions {
  mut f16 : Bool
  mut dual_source_blending : Bool
  mut ray_query : Bool
  mut ray_query_vertex_return : Bool
  mut clip_distances : Bool
}

///|
fn WgslIrRequiredEnableExtensions::WgslIrRequiredEnableExtensions() -> WgslIrRequiredEnableExtensions {
  {
    f16: false,
    dual_source_blending: false,
    ray_query: false,
    ray_query_vertex_return: false,
    clip_distances: false,
  }
}

///|
pub fn wgsl_ir_semantic_source_directives(
  shader_module : Module,
) -> Array[String] {
  let required = wgsl_ir_required_enable_extensions(shader_module)
  let out : Array[String] = []
  for directive in shader_module.directives {
    match wgsl_ir_filter_enable_directive(directive, required) {
      Some(filtered) => wgsl_ir_push_unique_directive(out, filtered)
      None =>
        if !wgsl_ir_source_directive_is_enable(directive) {
          wgsl_ir_push_unique_directive(out, directive)
        }
    }
  }
  out
}

///|
fn wgsl_ir_push_unique_directive(
  out : Array[String],
  directive : String,
) -> Unit {
  if out.contains(directive) {
    return
  }
  out.push(directive)
}

///|
fn wgsl_ir_source_directive_is_enable(directive : String) -> Bool {
  match wgsl_ir_directive_body(directive, "enable") {
    Some(_) => true
    None => false
  }
}

///|
fn wgsl_ir_filter_enable_directive(
  directive : String,
  required : WgslIrRequiredEnableExtensions,
) -> String? {
  guard wgsl_ir_directive_body(directive, "enable") is Some(body) else {
    return None
  }
  let kept : Array[String] = []
  for raw_extension in body.split(",") {
    let extension = raw_extension.trim().to_owned()
    if extension == "" {
      continue
    }
    if !wgsl_ir_known_enable_extension(extension) ||
      wgsl_ir_extension_is_required(required, extension) {
      kept.push(extension)
    }
  }
  if kept.length() == 0 {
    None
  } else {
    Some("enable \{kept.join(", ")};")
  }
}

///|
fn wgsl_ir_directive_body(directive : String, keyword : String) -> String? {
  let trimmed = directive.trim().to_owned()
  guard trimmed.length() >= keyword.length() else { return None }
  guard trimmed[0:keyword.length()].to_owned() == keyword else { return None }
  if trimmed.length() == keyword.length() {
    return Some("")
  }
  let separator = trimmed[keyword.length():keyword.length() + 1].to_owned()
  guard separator == " " || separator == "\t" || separator == ";" else {
    return None
  }
  let mut body = trimmed[keyword.length():trimmed.length()].trim().to_owned()
  if body.length() > 0 &&
    body[body.length() - 1:body.length()].to_owned() == ";" {
    body = body[0:body.length() - 1].trim().to_owned()
  }
  Some(body)
}

///|
fn wgsl_ir_known_enable_extension(extension : String) -> Bool {
  match extension {
    "f16"
    | "dual_source_blending"
    | "subgroups"
    | "wgpu_ray_query"
    | "wgpu_ray_query_vertex_return"
    | "clip_distances" => true
    _ => false
  }
}

///|
fn wgsl_ir_extension_is_required(
  required : WgslIrRequiredEnableExtensions,
  extension : String,
) -> Bool {
  match extension {
    "f16" => required.f16
    "dual_source_blending" => required.dual_source_blending
    // Naga accepts subgroup operations through capabilities, but its WGSL
    // frontend currently rejects the `enable subgroups;` directive.
    "subgroups" => false
    "wgpu_ray_query" => required.ray_query
    "wgpu_ray_query_vertex_return" => required.ray_query_vertex_return
    "clip_distances" => required.clip_distances
    _ => false
  }
}

///|
fn wgsl_ir_required_enable_extensions(
  shader_module : Module,
) -> WgslIrRequiredEnableExtensions {
  let required = WgslIrRequiredEnableExtensions()
  for constant in shader_module.constants.items {
    wgsl_ir_collect_required_extensions_from_type_handle(
      shader_module,
      constant.ty,
      required,
    )
    wgsl_ir_collect_required_extensions_from_global_expression(
      shader_module,
      constant.init,
      required,
    )
  }
  for override_ in shader_module.overrides.items {
    wgsl_ir_collect_required_extensions_from_type_handle(
      shader_module,
      override_.ty,
      required,
    )
    match override_.init {
      Some(init) =>
        wgsl_ir_collect_required_extensions_from_global_expression(
          shader_module, init, required,
        )
      None => ()
    }
  }
  for global in shader_module.global_variables.items {
    wgsl_ir_collect_required_extensions_from_type_handle(
      shader_module,
      global.ty,
      required,
    )
    match global.init {
      Some(init) =>
        wgsl_ir_collect_required_extensions_from_global_expression(
          shader_module, init, required,
        )
      None => ()
    }
  }
  for function in shader_module.functions.items {
    wgsl_ir_collect_required_extensions_from_function(
      shader_module, function, required,
    )
  }
  for entry_point in shader_module.entry_points {
    wgsl_ir_collect_required_extensions_from_entry_point(
      shader_module, entry_point, required,
    )
  }
  required
}

///|
fn wgsl_ir_collect_required_extensions_from_type_handle(
  shader_module : Module,
  handle : Handle,
  required : WgslIrRequiredEnableExtensions,
) -> Unit {
  match shader_module.types.items.get(handle.index()) {
    Some(ty) => wgsl_ir_collect_required_extensions_from_type(ty, required)
    None => ()
  }
}

///|
fn wgsl_ir_collect_required_extensions_from_type(
  ty : Type,
  required : WgslIrRequiredEnableExtensions,
) -> Unit {
  match ty.inner {
    Scalar({ kind: Float, width: 2 }) => required.f16 = true
    Vector(_, { kind: Float, width: 2 }) => required.f16 = true
    Matrix(_, _, { kind: Float, width: 2 }) => required.f16 = true
    CooperativeMatrix(_, _, { kind: Float, width: 2 }, _) => required.f16 = true
    Atomic({ kind: Float, width: 2 }) => required.f16 = true
    ValuePointer(_, { kind: Float, width: 2 }, _) => required.f16 = true
    Struct(struct_members, _) | PredeclaredStruct(struct_members, _) =>
      for struct_member in struct_members {
        wgsl_ir_collect_required_extensions_from_binding(
          struct_member.binding,
          required,
        )
      }
    RayQuery(vertex_return) => {
      required.ray_query = true
      if vertex_return {
        required.ray_query_vertex_return = true
      }
    }
    _ => ()
  }
}

///|
fn wgsl_ir_collect_required_extensions_from_binding(
  binding : Binding?,
  required : WgslIrRequiredEnableExtensions,
) -> Unit {
  match binding {
    Some(Location(_, _, _, Some(_), _)) => required.dual_source_blending = true
    Some(BuiltIn(ClipDistances | CullDistance)) =>
      required.clip_distances = true
    _ => ()
  }
}

///|
fn wgsl_ir_collect_required_extensions_from_global_expression(
  shader_module : Module,
  handle : Handle,
  required : WgslIrRequiredEnableExtensions,
) -> Unit {
  match shader_module.global_expressions.items.get(handle.index()) {
    Some(expression) =>
      wgsl_ir_collect_required_extensions_from_expression(expression, required)
    None => ()
  }
}

///|
fn wgsl_ir_collect_required_extensions_from_function_expression(
  function : Function,
  handle : Handle,
  required : WgslIrRequiredEnableExtensions,
) -> Unit {
  match function.expressions.items.get(handle.index()) {
    Some(expression) =>
      wgsl_ir_collect_required_extensions_from_expression(expression, required)
    None => ()
  }
}

///|
fn wgsl_ir_collect_required_extensions_from_expression(
  expression : Expression,
  required : WgslIrRequiredEnableExtensions,
) -> Unit {
  match expression {
    Literal(F16(_)) => required.f16 = true
    RayQueryInitialize(_, _, _)
    | RayQueryProceed(_)
    | RayQueryGenerateIntersection(_, _)
    | RayQueryConfirmIntersection(_)
    | RayQueryTerminate(_)
    | RayQueryProceedResult
    | RayQueryGetIntersection(_, _) => required.ray_query = true
    RayQueryVertexPositions(_, _) => {
      required.ray_query = true
      required.ray_query_vertex_return = true
    }
    _ => ()
  }
}

///|
fn wgsl_ir_collect_required_extensions_from_function(
  shader_module : Module,
  function : Function,
  required : WgslIrRequiredEnableExtensions,
) -> Unit {
  for argument in function.arguments {
    wgsl_ir_collect_required_extensions_from_binding(argument.binding, required)
    wgsl_ir_collect_required_extensions_from_type_handle(
      shader_module,
      argument.ty,
      required,
    )
  }
  match function.result {
    Some(result) => {
      wgsl_ir_collect_required_extensions_from_binding(result.binding, required)
      wgsl_ir_collect_required_extensions_from_type_handle(
        shader_module,
        result.ty,
        required,
      )
    }
    None => ()
  }
  for local_variable in function.local_variables.items {
    wgsl_ir_collect_required_extensions_from_type_handle(
      shader_module,
      local_variable.ty,
      required,
    )
    match local_variable.init {
      Some(init) =>
        wgsl_ir_collect_required_extensions_from_function_expression(
          function, init, required,
        )
      None => ()
    }
  }
  for expression in function.expressions.items {
    wgsl_ir_collect_required_extensions_from_expression(expression, required)
  }
  wgsl_ir_collect_required_extensions_from_block(function.body, required)
}

///|
fn wgsl_ir_collect_required_extensions_from_entry_point(
  shader_module : Module,
  entry_point : EntryPoint,
  required : WgslIrRequiredEnableExtensions,
) -> Unit {
  wgsl_ir_collect_required_extensions_from_function(
    shader_module,
    entry_point.function,
    required,
  )
}

///|
fn wgsl_ir_collect_required_extensions_from_block(
  block : Block,
  required : WgslIrRequiredEnableExtensions,
) -> Unit {
  for statement in block.statements {
    wgsl_ir_collect_required_extensions_from_statement(statement, required)
  }
}

///|
fn wgsl_ir_collect_required_extensions_from_statement(
  statement : Statement,
  required : WgslIrRequiredEnableExtensions,
) -> Unit {
  match statement {
    Block(block) =>
      wgsl_ir_collect_required_extensions_from_block(block, required)
    If(_, accept, reject) => {
      wgsl_ir_collect_required_extensions_from_block(accept, required)
      wgsl_ir_collect_required_extensions_from_block(reject, required)
    }
    Switch(_, cases) =>
      for case in cases {
        wgsl_ir_collect_required_extensions_from_block(case.body, required)
      }
    Loop(body, continuing, _) => {
      wgsl_ir_collect_required_extensions_from_block(body, required)
      wgsl_ir_collect_required_extensions_from_block(continuing, required)
    }
    RayQuery(_, _) => required.ray_query = true
    RayPipelineFunction(_) => required.ray_query = true
    _ => ()
  }
}
