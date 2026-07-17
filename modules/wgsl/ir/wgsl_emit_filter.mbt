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
pub struct WgslIrReachability {
  types : @set.Set[String]
  type_order : Array[Int]
  constants : @set.Set[String]
  constant_order : Array[Int]
  overrides : @set.Set[String]
  override_order : Array[Int]
  global_variables : @set.Set[String]
  global_variable_order : Array[Int]
  functions : @set.Set[String]
  entry_points : @set.Set[String]
}

///|
fn WgslIrReachability::WgslIrReachability() -> WgslIrReachability {
  {
    types: Set([]),
    type_order: [],
    constants: Set([]),
    constant_order: [],
    overrides: Set([]),
    override_order: [],
    global_variables: Set([]),
    global_variable_order: [],
    functions: Set([]),
    entry_points: Set([]),
  }
}

///|
fn wgsl_ir_reachability_key(index : Int) -> String {
  index.to_string()
}

///|
fn wgsl_ir_reachability_contains(items : @set.Set[String], index : Int) -> Bool {
  items.contains(wgsl_ir_reachability_key(index))
}

///|
fn wgsl_ir_reachability_mark(items : @set.Set[String], index : Int) -> Bool {
  let key = wgsl_ir_reachability_key(index)
  if items.contains(key) {
    return false
  }
  items.add(key)
  true
}

///|
pub fn WgslIrReachability::contains_type(
  self : WgslIrReachability,
  index : Int,
) -> Bool {
  wgsl_ir_reachability_contains(self.types, index)
}

///|
pub fn WgslIrReachability::contains_constant(
  self : WgslIrReachability,
  index : Int,
) -> Bool {
  wgsl_ir_reachability_contains(self.constants, index)
}

///|
pub fn WgslIrReachability::contains_override(
  self : WgslIrReachability,
  index : Int,
) -> Bool {
  wgsl_ir_reachability_contains(self.overrides, index)
}

///|
pub fn WgslIrReachability::contains_global_variable(
  self : WgslIrReachability,
  index : Int,
) -> Bool {
  wgsl_ir_reachability_contains(self.global_variables, index)
}

///|
pub fn WgslIrReachability::contains_function(
  self : WgslIrReachability,
  index : Int,
) -> Bool {
  wgsl_ir_reachability_contains(self.functions, index)
}

///|
pub fn WgslIrReachability::contains_entry_point(
  self : WgslIrReachability,
  index : Int,
) -> Bool {
  wgsl_ir_reachability_contains(self.entry_points, index)
}

///|
pub fn build_wgsl_ir_reachability(
  shader_module : Module,
  root_items : Array[String],
) -> WgslIrReachability {
  let filter = WgslIrReachability::WgslIrReachability()
  for root in root_items {
    filter.mark_root_name(shader_module, root)
  }
  filter
}

///|
fn wgsl_ir_reachability_from_optional_roots(
  shader_module : Module,
  root_items : Array[String]?,
) -> WgslIrReachability? {
  match root_items {
    Some(root_items) if root_items.length() > 0 =>
      Some(build_wgsl_ir_reachability(shader_module, root_items))
    _ => None
  }
}

///|
fn WgslIrReachability::mark_root_name(
  self : WgslIrReachability,
  shader_module : Module,
  root : String,
) -> Unit {
  for index in 0..<shader_module.types.items.length() {
    match shader_module.types.items[index].name {
      Some(name) if name == root => self.mark_type(shader_module, Handle(index))
      _ => ()
    }
  }
  for index in 0..<shader_module.constants.items.length() {
    match shader_module.constants.items[index].name {
      Some(name) if name == root =>
        self.mark_constant(shader_module, Handle(index))
      _ => ()
    }
  }
  for index in 0..<shader_module.overrides.items.length() {
    match shader_module.overrides.items[index].name {
      Some(name) if name == root =>
        self.mark_override(shader_module, Handle(index))
      _ => ()
    }
  }
  for index in 0..<shader_module.global_variables.items.length() {
    match shader_module.global_variables.items[index].name {
      Some(name) if name == root =>
        self.mark_global_variable(shader_module, Handle(index))
      _ => ()
    }
  }
  for index in 0..<shader_module.functions.items.length() {
    match shader_module.functions.items[index].name {
      Some(name) if name == root =>
        self.mark_function(shader_module, Handle(index))
      _ => ()
    }
  }
  for index in 0..<shader_module.entry_points.length() {
    if shader_module.entry_points[index].name == root {
      self.mark_entry_point(shader_module, index)
    }
  }
}

///|
fn WgslIrReachability::mark_type(
  self : WgslIrReachability,
  shader_module : Module,
  handle : Handle,
) -> Unit {
  if !wgsl_ir_reachability_mark(self.types, handle.index()) {
    return
  }
  match shader_module.types.items.get(handle.index()) {
    Some(ty) => {
      self.mark_type_inner(shader_module, ty.inner)
      self.type_order.push(handle.index())
    }
    None => ()
  }
}

///|
fn WgslIrReachability::mark_type_inner(
  self : WgslIrReachability,
  shader_module : Module,
  inner : TypeInner,
) -> Unit {
  match inner {
    Pointer(base, _) | BindingArray(base, _) =>
      self.mark_type(shader_module, base)
    Array(base, size, _) => {
      self.mark_type(shader_module, base)
      match size {
        Pending(expr) => self.mark_global_expression(shader_module, expr)
        Constant(_) | Dynamic => ()
      }
    }
    Struct(members, _) | PredeclaredStruct(members, _) =>
      for struct_member in members {
        self.mark_type(shader_module, struct_member.ty)
      }
    _ => ()
  }
}

///|
fn WgslIrReachability::mark_constant(
  self : WgslIrReachability,
  shader_module : Module,
  handle : Handle,
) -> Unit {
  if !wgsl_ir_reachability_mark(self.constants, handle.index()) {
    return
  }
  self.constant_order.push(handle.index())
  match shader_module.constants.items.get(handle.index()) {
    Some(constant) => {
      self.mark_type(shader_module, constant.ty)
      self.mark_global_expression(shader_module, constant.init)
    }
    None => ()
  }
}

///|
fn WgslIrReachability::mark_override(
  self : WgslIrReachability,
  shader_module : Module,
  handle : Handle,
) -> Unit {
  if !wgsl_ir_reachability_mark(self.overrides, handle.index()) {
    return
  }
  self.override_order.push(handle.index())
  match shader_module.overrides.items.get(handle.index()) {
    Some(override_) => {
      self.mark_type(shader_module, override_.ty)
      match override_.init {
        Some(init) => self.mark_global_expression(shader_module, init)
        None => ()
      }
    }
    None => ()
  }
}

///|
fn WgslIrReachability::mark_global_variable(
  self : WgslIrReachability,
  shader_module : Module,
  handle : Handle,
) -> Unit {
  if !wgsl_ir_reachability_mark(self.global_variables, handle.index()) {
    return
  }
  self.global_variable_order.push(handle.index())
  match shader_module.global_variables.items.get(handle.index()) {
    Some(global) => {
      self.mark_type(shader_module, global.ty)
      match global.init {
        Some(init) => self.mark_global_expression(shader_module, init)
        None => ()
      }
    }
    None => ()
  }
}

///|
fn WgslIrReachability::mark_function(
  self : WgslIrReachability,
  shader_module : Module,
  handle : Handle,
) -> Unit {
  if !wgsl_ir_reachability_mark(self.functions, handle.index()) {
    return
  }
  match shader_module.functions.items.get(handle.index()) {
    Some(function) => self.mark_function_body(shader_module, function)
    None => ()
  }
}

///|
fn WgslIrReachability::mark_entry_point(
  self : WgslIrReachability,
  shader_module : Module,
  index : Int,
) -> Unit {
  if !wgsl_ir_reachability_mark(self.entry_points, index) {
    return
  }
  match shader_module.entry_points.get(index) {
    Some(entry_point) => {
      self.mark_function_body(shader_module, entry_point.function)
      match entry_point.workgroup_size_overrides {
        Some(overrides) =>
          for item in overrides {
            match item {
              Some(expr) => self.mark_global_expression(shader_module, expr)
              None => ()
            }
          }
        None => ()
      }
      match entry_point.mesh_info {
        Some(mesh_info) => {
          match mesh_info.max_vertices_override {
            Some(expr) => self.mark_global_expression(shader_module, expr)
            None => ()
          }
          match mesh_info.max_primitives_override {
            Some(expr) => self.mark_global_expression(shader_module, expr)
            None => ()
          }
          self.mark_type(shader_module, mesh_info.vertex_output_type)
          self.mark_type(shader_module, mesh_info.primitive_output_type)
          self.mark_global_variable(shader_module, mesh_info.output_variable)
        }
        None => ()
      }
      match entry_point.task_payload {
        Some(handle) => self.mark_global_variable(shader_module, handle)
        None => ()
      }
      match entry_point.incoming_ray_payload {
        Some(handle) => self.mark_global_variable(shader_module, handle)
        None => ()
      }
    }
    None => ()
  }
}

///|
fn WgslIrReachability::mark_function_body(
  self : WgslIrReachability,
  shader_module : Module,
  function : Function,
) -> Unit {
  for argument in function.arguments {
    self.mark_type(shader_module, argument.ty)
  }
  match function.result {
    Some(result) => self.mark_type(shader_module, result.ty)
    None => ()
  }
  for local_var in function.local_variables.items {
    self.mark_type(shader_module, local_var.ty)
    match local_var.init {
      Some(expr) => self.mark_function_expression(shader_module, function, expr)
      None => ()
    }
  }
  for expression in function.expressions.items {
    self.mark_function_expression_inner(shader_module, function, expression)
  }
  self.mark_block(shader_module, function, function.body)
}

///|
fn WgslIrReachability::mark_block(
  self : WgslIrReachability,
  shader_module : Module,
  function : Function,
  block : Block,
) -> Unit {
  for statement in block.statements {
    self.mark_statement(shader_module, function, statement)
  }
}

///|
fn WgslIrReachability::mark_statement(
  self : WgslIrReachability,
  shader_module : Module,
  function : Function,
  statement : Statement,
) -> Unit {
  match statement {
    Emit(range) => {
      let mut index = range.start.index()
      while index <= range.end.index() {
        self.mark_function_expression(shader_module, function, Handle(index))
        index = index + 1
      }
    }
    Phony(handle) =>
      self.mark_function_expression(shader_module, function, handle)
    If(condition, accept, reject) => {
      self.mark_function_expression(shader_module, function, condition)
      self.mark_block(shader_module, function, accept)
      self.mark_block(shader_module, function, reject)
    }
    Switch(selector, cases) => {
      self.mark_function_expression(shader_module, function, selector)
      for case in cases {
        for dependency in case.constant_dependencies {
          self.mark_constant(shader_module, dependency)
        }
        self.mark_block(shader_module, function, case.body)
      }
    }
    Loop(body, continuing, break_if) => {
      self.mark_block(shader_module, function, body)
      self.mark_block(shader_module, function, continuing)
      match break_if {
        Some(condition) =>
          self.mark_function_expression(shader_module, function, condition)
        None => ()
      }
    }
    Block(nested) => self.mark_block(shader_module, function, nested)
    Return(value) =>
      match value {
        Some(expr) =>
          self.mark_function_expression(shader_module, function, expr)
        None => ()
      }
    ConstAssert(expr) =>
      self.mark_function_expression(shader_module, function, expr)
    Store(pointer, value) => {
      self.mark_function_expression(shader_module, function, pointer)
      self.mark_function_expression(shader_module, function, value)
    }
    ImageStore(image, coordinate, array_index, value) => {
      self.mark_function_expression(shader_module, function, image)
      self.mark_function_expression(shader_module, function, coordinate)
      match array_index {
        Some(expr) =>
          self.mark_function_expression(shader_module, function, expr)
        None => ()
      }
      self.mark_function_expression(shader_module, function, value)
    }
    Atomic(pointer, _, value, compare, result) => {
      self.mark_function_expression(shader_module, function, pointer)
      self.mark_function_expression(shader_module, function, value)
      match compare {
        Some(expr) =>
          self.mark_function_expression(shader_module, function, expr)
        None => ()
      }
      match result {
        Some(expr) =>
          self.mark_function_expression(shader_module, function, expr)
        None => ()
      }
    }
    ImageAtomic(image, coordinate, array_index, _, value) => {
      self.mark_function_expression(shader_module, function, image)
      self.mark_function_expression(shader_module, function, coordinate)
      match array_index {
        Some(expr) =>
          self.mark_function_expression(shader_module, function, expr)
        None => ()
      }
      self.mark_function_expression(shader_module, function, value)
    }
    WorkGroupUniformLoad(pointer, result) => {
      self.mark_function_expression(shader_module, function, pointer)
      self.mark_function_expression(shader_module, function, result)
    }
    Call(callee, arguments, result) => {
      self.mark_function(shader_module, callee)
      for argument in arguments {
        self.mark_function_expression(shader_module, function, argument)
      }
      match result {
        Some(expr) =>
          self.mark_function_expression(shader_module, function, expr)
        None => ()
      }
    }
    RayQuery(query, _) =>
      self.mark_function_expression(shader_module, function, query)
    SubgroupBallot(value, result) => {
      self.mark_function_expression(shader_module, function, value)
      match result {
        Some(expr) =>
          self.mark_function_expression(shader_module, function, expr)
        None => ()
      }
    }
    SubgroupGather(_, value, result) => {
      self.mark_function_expression(shader_module, function, value)
      self.mark_function_expression(shader_module, function, result)
    }
    SubgroupCollectiveOperation(_, _, value, result) => {
      self.mark_function_expression(shader_module, function, value)
      self.mark_function_expression(shader_module, function, result)
    }
    CooperativeStore(_, data) =>
      self.mark_cooperative_data(shader_module, function, data)
    Declare(_)
    | Break
    | Continue
    | ImplicitReturn
    | Kill
    | ControlBarrier(_)
    | MemoryBarrier(_)
    | RayPipelineFunction(_) => ()
  }
}

///|
fn WgslIrReachability::mark_global_expression(
  self : WgslIrReachability,
  shader_module : Module,
  handle : Handle,
) -> Unit {
  match shader_module.global_expressions.items.get(handle.index()) {
    Some(expression) =>
      self.mark_global_expression_inner(shader_module, expression)
    None => ()
  }
}

///|
fn WgslIrReachability::mark_global_expression_inner(
  self : WgslIrReachability,
  shader_module : Module,
  expression : Expression,
) -> Unit {
  match expression {
    Constant(handle) => self.mark_constant(shader_module, handle)
    Override(handle) => self.mark_override(shader_module, handle)
    GlobalVariable(handle) => self.mark_global_variable(shader_module, handle)
    ZeroValue(ty) => self.mark_type(shader_module, ty)
    Compose(ty, components) => {
      self.mark_type(shader_module, ty)
      for component in components {
        self.mark_global_expression(shader_module, component)
      }
    }
    Access(base, index) => {
      self.mark_global_expression(shader_module, base)
      self.mark_global_expression(shader_module, index)
    }
    AccessIndex(base, _)
    | Component(base, _)
    | Load(base)
    | Unary(_, base)
    | Bitcast(_, base)
    | As(base, _, _)
    | Relational(_, base)
    | ArrayLength(base)
    | WorkGroupUniformLoad(base) =>
      self.mark_global_expression(shader_module, base)
    AddressOf(ty, target) => {
      self.mark_type(shader_module, ty)
      self.mark_global_expression(shader_module, target)
    }
    Binary(_, left, right) => {
      self.mark_global_expression(shader_module, left)
      self.mark_global_expression(shader_module, right)
    }
    FunctionCall(function, arguments) => {
      self.mark_function(shader_module, function)
      for argument in arguments {
        self.mark_global_expression(shader_module, argument)
      }
    }
    Select(condition, accept, reject) => {
      self.mark_global_expression(shader_module, condition)
      self.mark_global_expression(shader_module, accept)
      self.mark_global_expression(shader_module, reject)
    }
    Math(_, a, b, c, d) => {
      self.mark_global_expression(shader_module, a)
      self.mark_optional_global_expression(shader_module, b)
      self.mark_optional_global_expression(shader_module, c)
      self.mark_optional_global_expression(shader_module, d)
    }
    Literal(_) => ()
    _ => ()
  }
}

///|
fn WgslIrReachability::mark_function_expression(
  self : WgslIrReachability,
  shader_module : Module,
  function : Function,
  handle : Handle,
) -> Unit {
  match function.expressions.items.get(handle.index()) {
    Some(expression) =>
      self.mark_function_expression_inner(shader_module, function, expression)
    None => ()
  }
}

///|
fn WgslIrReachability::mark_function_expression_inner(
  self : WgslIrReachability,
  shader_module : Module,
  function : Function,
  expression : Expression,
) -> Unit {
  match expression {
    Constant(handle) => self.mark_constant(shader_module, handle)
    Override(handle) => self.mark_override(shader_module, handle)
    GlobalVariable(handle) => self.mark_global_variable(shader_module, handle)
    ZeroValue(ty) => self.mark_type(shader_module, ty)
    Compose(ty, components) => {
      self.mark_type(shader_module, ty)
      for component in components {
        self.mark_function_expression(shader_module, function, component)
      }
    }
    Access(base, index) => {
      self.mark_function_expression(shader_module, function, base)
      self.mark_function_expression(shader_module, function, index)
    }
    AccessIndex(base, _)
    | Component(base, _)
    | Load(base)
    | Unary(_, base)
    | Bitcast(_, base)
    | As(base, _, _)
    | Relational(_, base)
    | ArrayLength(base)
    | WorkGroupUniformLoad(base)
    | Splat(_, base)
    | Swizzle(_, base, _)
    | Derivative(_, _, base)
    | WorkGroupUniformLoadResult(base)
    | RayQueryProceed(base)
    | RayQueryConfirmIntersection(base)
    | RayQueryTerminate(base)
    | RayQueryGetIntersection(base, _) =>
      self.mark_function_expression(shader_module, function, base)
    AtomicResult(_, _) => ()
    AddressOf(ty, target) => {
      self.mark_type(shader_module, ty)
      self.mark_function_expression(shader_module, function, target)
    }
    Binary(_, left, right) => {
      self.mark_function_expression(shader_module, function, left)
      self.mark_function_expression(shader_module, function, right)
    }
    FunctionCall(function_handle, arguments) => {
      self.mark_function(shader_module, function_handle)
      for argument in arguments {
        self.mark_function_expression(shader_module, function, argument)
      }
    }
    Select(condition, accept, reject) => {
      self.mark_function_expression(shader_module, function, condition)
      self.mark_function_expression(shader_module, function, accept)
      self.mark_function_expression(shader_module, function, reject)
    }
    ImageSample(
      image,
      sampler,
      _,
      coordinate,
      array_index,
      offset,
      level,
      depth_ref,
      _
    ) => {
      self.mark_function_expression(shader_module, function, image)
      self.mark_function_expression(shader_module, function, sampler)
      self.mark_function_expression(shader_module, function, coordinate)
      self.mark_optional_function_expression(
        shader_module, function, array_index,
      )
      self.mark_optional_function_expression(shader_module, function, offset)
      self.mark_sample_level(shader_module, function, level)
      self.mark_optional_function_expression(shader_module, function, depth_ref)
    }
    ImageLoad(image, coordinate, array_index, sample, level) => {
      self.mark_function_expression(shader_module, function, image)
      self.mark_function_expression(shader_module, function, coordinate)
      self.mark_optional_function_expression(
        shader_module, function, array_index,
      )
      self.mark_optional_function_expression(shader_module, function, sample)
      self.mark_optional_function_expression(shader_module, function, level)
    }
    ImageQuery(image, query) => {
      self.mark_function_expression(shader_module, function, image)
      match query {
        Size(level) =>
          self.mark_optional_function_expression(shader_module, function, level)
        _ => ()
      }
    }
    AtomicCall(_, arguments) | SubgroupCall(_, arguments) =>
      for argument in arguments {
        self.mark_function_expression(shader_module, function, argument)
      }
    Math(_, a, b, c, d) => {
      self.mark_function_expression(shader_module, function, a)
      self.mark_optional_function_expression(shader_module, function, b)
      self.mark_optional_function_expression(shader_module, function, c)
      self.mark_optional_function_expression(shader_module, function, d)
    }
    CallResult(handle) => self.mark_function(shader_module, handle)
    RayQueryInitialize(query, acceleration, ray_desc) => {
      self.mark_function_expression(shader_module, function, query)
      self.mark_function_expression(shader_module, function, acceleration)
      self.mark_function_expression(shader_module, function, ray_desc)
    }
    RayQueryGenerateIntersection(query, intersection_t) => {
      self.mark_function_expression(shader_module, function, query)
      self.mark_function_expression(shader_module, function, intersection_t)
    }
    RayQueryVertexPositions(query, _) =>
      self.mark_function_expression(shader_module, function, query)
    SubgroupOperationResult(handle) =>
      self.mark_function_expression(shader_module, function, handle)
    CooperativeLoad(_, _, _, data) =>
      self.mark_cooperative_data(shader_module, function, data)
    CooperativeMultiplyAdd(a, b, c) => {
      self.mark_function_expression(shader_module, function, a)
      self.mark_function_expression(shader_module, function, b)
      self.mark_function_expression(shader_module, function, c)
    }
    Literal(_)
    | FunctionArgument(_)
    | LocalVariable(_)
    | RayQueryProceedResult
    | SubgroupBallotResult => ()
  }
}

///|
fn WgslIrReachability::mark_sample_level(
  self : WgslIrReachability,
  shader_module : Module,
  function : Function,
  level : SampleLevel,
) -> Unit {
  match level {
    Exact(handle) | Bias(handle) =>
      self.mark_function_expression(shader_module, function, handle)
    Gradient(x, y) => {
      self.mark_function_expression(shader_module, function, x)
      self.mark_function_expression(shader_module, function, y)
    }
    Auto | Zero => ()
  }
}

///|
fn WgslIrReachability::mark_cooperative_data(
  self : WgslIrReachability,
  shader_module : Module,
  function : Function,
  data : CooperativeData,
) -> Unit {
  self.mark_function_expression(shader_module, function, data.pointer)
  self.mark_function_expression(shader_module, function, data.stride)
}

///|
fn WgslIrReachability::mark_optional_global_expression(
  self : WgslIrReachability,
  shader_module : Module,
  handle : Handle?,
) -> Unit {
  match handle {
    Some(value) => self.mark_global_expression(shader_module, value)
    None => ()
  }
}

///|
fn WgslIrReachability::mark_optional_function_expression(
  self : WgslIrReachability,
  shader_module : Module,
  function : Function,
  handle : Handle?,
) -> Unit {
  match handle {
    Some(value) => self.mark_function_expression(shader_module, function, value)
    None => ()
  }
}
