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
test "WGSL AST lowers declarations, bindings, and entry point metadata into IR" {
  let source =
    #|struct VertexIn {
    #|  @location(0) value: f32,
    #|}
    #|
    #|@group(0) @binding(1)
    #|var<uniform> scale: f32;
    #|
    #|const COUNT: u32 = 4u;
    #|@id(3) override ENABLED: bool = true;
    #|
    #|@compute @workgroup_size(2, 3, 4)
    #|fn main(@builtin(global_invocation_id) id: vec3u) {
    #|  var local_value: u32 = COUNT + 1u;
    #|  local_value = local_value + 1u;
    #|  return;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  debug_inspect(module_.global_variables.items.length(), content="1")
  debug_inspect(module_.constants.items.length(), content="1")
  debug_inspect(module_.overrides.items.length(), content="1")
  debug_inspect(module_.entry_points.length(), content="1")
  debug_inspect(module_.entry_points[0].workgroup_size, content="[2, 3, 4]")
  debug_inspect(
    module_.entry_points[0].function.arguments[0].binding,
    content="Some(BuiltIn(GlobalInvocationId))",
  )
  debug_inspect(
    module_.entry_points[0].function.local_variables.items.length(),
    content="2",
  )
  debug_inspect(
    module_.entry_points[0].function.body.statements.length(),
    content="6",
  )
}

///|
test "WGSL AST lowerer preserves const and override workgroup sizes in IR" {
  let source =
    #|const WIDTH: u32 = max(1u, 4u - 1u);
    #|@id(7) override HEIGHT: u32 = 8u;
    #|
    #|@compute @workgroup_size(WIDTH, HEIGHT, 1)
    #|fn main() {
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  debug_inspect(module_.entry_points[0].workgroup_size, content="[3, 1, 1]")
  guard module_.entry_points[0].workgroup_size_overrides is Some(overrides) else {
    abort("expected workgroup_size override handles")
  }
  debug_inspect(overrides[0], content="None")
  debug_inspect(overrides[1] != None, content="true")
  debug_inspect(overrides[2], content="None")
}

///|
test "WGSL AST lowerer keeps function argument swizzle before control-flow global member RHS" {
  let source =
    #|struct Settings {
    #|  size: vec3<u32>,
    #|}
    #|
    #|@group(0) @binding(0) var<uniform> settings: Settings;
    #|
    #|@compute @workgroup_size(1)
    #|fn main(@builtin(global_invocation_id) idx: vec3<u32>) {
    #|  if any(idx.xy > settings.size.xy) {
    #|    return;
    #|  }
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.entry_points[0].function
  match function.expressions.items[0] {
    FunctionArgument(index) => debug_inspect(index, content="0")
    _ => abort("expected entry argument first")
  }
  match function.expressions.items[1] {
    Swizzle(_, base, _) => debug_inspect(base.index(), content="0")
    _ => abort("expected source-left function argument swizzle before global")
  }
  match function.expressions.items[2] {
    GlobalVariable(_) => ()
    _ => abort("expected right-hand global after function argument swizzle")
  }
}

///|
test "WGSL AST lowerer allocates fresh literal for nested for execution-site initializer store" {
  let source =
    #|fn probe(limit: u32) {
    #|  var slice = 0u;
    #|  loop {
    #|    if slice < limit {
    #|    } else {
    #|      break;
    #|    }
    #|    {
    #|      for (var step = 0u; step < limit; step = step + 1u) {
    #|      }
    #|    }
    #|    continuing {
    #|      slice = slice + 1u;
    #|    }
    #|  }
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut step_local = -1
  for index in 0..<function.local_variables.items.length() {
    match function.local_variables.items[index].name {
      Some(name) if name == "step" => step_local = index
      _ => ()
    }
  }
  debug_inspect(step_local >= 0, content="true")
  let mut step_pointer_expression = -1
  for index in 0..<function.expressions.items.length() {
    match function.expressions.items[index] {
      LocalVariable(handle) if handle.index() == step_local &&
        step_pointer_expression == -1 => step_pointer_expression = index
      _ => ()
    }
  }
  debug_inspect(step_pointer_expression >= 0, content="true")
  match function.expressions.items[step_pointer_expression + 1] {
    Literal(U32(value)) => debug_inspect(value, content="0")
    _ =>
      abort("expected fresh nested for initializer literal after step pointer")
  }
}

///|
test "WGSL AST lowerer predeclares compound assignment RHS mutable local before target load" {
  let source =
    #|fn probe() {
    #|  var total = vec3(0.0);
    #|  var throughput = vec3(1.0);
    #|  let s = vec3(0.5);
    #|  total += throughput * s;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut total_local = -1
  let mut throughput_local = -1
  for index in 0..<function.local_variables.items.length() {
    match function.local_variables.items[index].name {
      Some(name) if name == "total" => total_local = index
      Some(name) if name == "throughput" => throughput_local = index
      _ => ()
    }
  }
  debug_inspect(total_local >= 0, content="true")
  debug_inspect(throughput_local >= 0, content="true")
  let mut found = false
  for index in 0..<(function.expressions.items.length() - 3) {
    match
      (
        function.expressions.items[index],
        function.expressions.items[index + 1],
        function.expressions.items[index + 2],
        function.expressions.items[index + 3],
      ) {
      (
        LocalVariable(total),
        LocalVariable(throughput),
        Load(total_pointer),
        Load(throughput_pointer),
      ) if total.index() == total_local &&
        throughput.index() == throughput_local &&
        total_pointer.index() == index &&
        throughput_pointer.index() == index + 1 => found = true
      _ => ()
    }
  }
  debug_inspect(found, content="true")
}

///|
test "WGSL AST lowerer predeclares mutable locals before non-const initializer arena values" {
  let source =
    #|fn probe(t0: f32) -> f32 {
    #|  var t = t0;
    #|  if 1. < t {
    #|    return t;
    #|  }
    #|  return t;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  match function.expressions.items[0] {
    LocalVariable(handle) => debug_inspect(handle.index(), content="0")
    _ => abort("expected mutable local pointer to own the first arena slot")
  }
  match function.expressions.items[1] {
    FunctionArgument(index) => debug_inspect(index, content="0")
    _ => abort("expected initializer argument after local pointer")
  }
  match function.expressions.items[2] {
    Load(_) => ()
    _ => abort("expected right-hand mutable local load before left literal")
  }
  match function.expressions.items[3] {
    Literal(_) => ()
    _ => abort("expected comparison literal after mutable local load")
  }
  match function.expressions.items[4] {
    Binary(Less, left, right) => {
      debug_inspect(left.index(), content="3")
      debug_inspect(right.index(), content="2")
    }
    _ => abort("expected comparison to preserve source operands")
  }
}

///|
test "WGSL AST lowerer keeps parent argument before higher-precedence call RHS" {
  let source =
    #|fn probe(N: vec3<f32>, V: vec3<f32>) -> vec3<f32> {
    #|  let T1 = normalize(V - N * dot(V, N));
    #|  return T1;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  match function.expressions.items[0] {
    FunctionArgument(index) => debug_inspect(index, content="1")
    _ => abort("expected parent-left argument before RHS product")
  }
  match function.expressions.items[1] {
    FunctionArgument(index) => debug_inspect(index, content="0")
    _ => abort("expected RHS product argument after parent-left argument")
  }
  match function.expressions.items[2] {
    Math(Dot, _, _, _, _) => ()
    _ => abort("expected dot after both arguments")
  }
}

///|
test "WGSL AST lowerer keeps right argument before completing left access" {
  let source =
    #|fn probe(P: vec3<f32>, points: array<vec3<f32>, 4>) -> vec3<f32> {
    #|  return points[0] - P;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  match function.expressions.items[0] {
    FunctionArgument(index) => debug_inspect(index, content="1")
    _ => abort("expected left access root before right argument")
  }
  match function.expressions.items[1] {
    FunctionArgument(index) => debug_inspect(index, content="0")
    _ => abort("expected right argument before left access completion")
  }
  match function.expressions.items[2] {
    AccessIndex(base, _) => debug_inspect(base.index(), content="0")
    _ => abort("expected left access after right argument")
  }
}

///|
test "WGSL AST lowerer lowers non-argument var initializer before mutable local pointer" {
  let source =
    #|struct Material {
    #|  color: vec4<f32>,
    #|}
    #|@group(0) @binding(0) var<uniform> material: Material;
    #|fn fragment() -> vec4<f32> {
    #|  var output_color: vec4<f32> = material.color;
    #|  return output_color;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  match function.expressions.items[0] {
    GlobalVariable(_) => ()
    _ => abort("expected global variable before mutable local pointer")
  }
  match function.expressions.items[1] {
    AccessIndex(_, _) => ()
    _ => abort("expected member access before mutable local pointer")
  }
  match function.expressions.items[2] {
    Load(_) => ()
    _ => abort("expected initializer load before mutable local pointer")
  }
  match function.expressions.items[3] {
    LocalVariable(handle) => debug_inspect(handle.index(), content="0")
    _ => abort("expected mutable local pointer after initializer")
  }
}

///|
test "WGSL AST lowerer orders comparison argument before mutable local load" {
  let source =
    #|fn probe(a: f32, limit: f32) -> f32 {
    #|  var t = a;
    #|  if t < limit {
    #|    return t;
    #|  }
    #|  return t;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  match function.expressions.items[2] {
    FunctionArgument(index) => debug_inspect(index, content="1")
    _ => abort("expected comparison argument before mutable local load")
  }
  match function.expressions.items[3] {
    Load(_) => ()
    _ => abort("expected mutable local load after comparison argument")
  }
  match function.expressions.items[4] {
    Binary(Less, left, right) => {
      debug_inspect(left.index(), content="3")
      debug_inspect(right.index(), content="2")
    }
    _ => abort("expected comparison to preserve source operands")
  }
}

///|
test "WGSL AST lowerer reuses initialized local pointer in branch assignments" {
  let source =
    #|fn probe(a: f32, limit: f32) -> f32 {
    #|  var t = (a + limit);
    #|  if t < limit {
    #|    t = 0.5 * t;
    #|  }
    #|  return t;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut local_handle : Handle? = None
  for index, local_var in function.local_variables.items {
    if local_var.name == Some("t") {
      local_handle = Some(Handle(index))
    }
  }
  guard local_handle is Some(handle) else { abort("expected local t") }
  let mut pointer_count = 0
  for expression in function.expressions.items {
    match expression {
      LocalVariable(candidate) => if candidate == handle { pointer_count += 1 }
      _ => ()
    }
  }
  debug_inspect(pointer_count, content="1")
}

///|
test "WGSL AST lowerer lowers plain local literal assignment target before value" {
  let source =
    #|fn probe(flag: bool) -> f32 {
    #|  var sign = -1.0;
    #|  if flag {
    #|    sign = 1.0;
    #|  }
    #|  return sign;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut sign_local : Handle? = None
  for index, local_var in function.local_variables.items {
    if local_var.name == Some("sign") {
      sign_local = Some(Handle(index))
    }
  }
  guard sign_local is Some(sign_handle) else { abort("expected sign local") }
  let mut found = false
  for index in 0..<(function.expressions.items.length() - 1) {
    match
      (function.expressions.items[index], function.expressions.items[index + 1]) {
      (LocalVariable(handle), Literal(_)) if handle == sign_handle =>
        found = true
      _ => ()
    }
  }
  debug_inspect(found, content="true")
}

///|
test "WGSL AST lowerer lowers complex mutable-local right subtree before literal left" {
  let source =
    #|fn probe(a: f32, limit: f32) -> f32 {
    #|  var t = a;
    #|  t = 0.5 * (1.0 + ((t - limit) / (1.0 - limit)));
    #|  return t;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  match function.expressions.items[2] {
    FunctionArgument(index) => debug_inspect(index, content="1")
    _ => abort("expected right subtree argument before mutable local load")
  }
  match function.expressions.items[3] {
    Load(_) => ()
    _ => abort("expected mutable local load before literal-left multiply")
  }
  match function.expressions.items[10] {
    Literal(_) => ()
    _ => abort("expected literal multiply operand after complex right subtree")
  }
  match function.expressions.items[11] {
    Binary(Multiply, left, right) => {
      debug_inspect(left.index(), content="10")
      debug_inspect(right.index(), content="9")
    }
    _ => abort("expected multiply to preserve source operands")
  }
}

///|
test "WGSL AST lowerer interleaves deferred constants with local binary subtrees" {
  let source =
    #|const PI: f32 = 3.141592653589793;
    #|
    #|fn rand_vec2f(state: ptr<function, u32>) -> vec2<f32> {
    #|  return vec2<f32>(f32(*state), f32(*state));
    #|}
    #|
    #|fn probe(disk_radius: f32, rng: ptr<function, u32>) -> vec2<f32> {
    #|  let ab = 2.0 * rand_vec2f(rng) - 1.0;
    #|  let a = ab.x;
    #|  var b = ab.y;
    #|  if (b == 0.0) { b = 1.0; }
    #|  var phi: f32;
    #|  var r: f32;
    #|  if (a * a > b * b) {
    #|    r = disk_radius * a;
    #|    phi = (PI / 4.0) * (b / a);
    #|  } else {
    #|    r = disk_radius * b;
    #|    phi = (PI / 2.0) - (PI / 4.0) * (a / b);
    #|  }
    #|  return vec2(r * cos(phi), r * sin(phi));
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[1]
  match function.expressions.items[22] {
    Literal(_) => ()
    _ => abort("expected true-branch scale constant before mutable local load")
  }
  match function.expressions.items[23] {
    Load(_) => ()
    _ => abort("expected true-branch mutable local load after scale constant")
  }
  match function.expressions.items[29] {
    Literal(_) => ()
    _ => abort("expected else-branch product constant before parent constant")
  }
  match function.expressions.items[30] {
    Literal(_) => ()
    _ => abort("expected else-branch parent constant after product constant")
  }
  match function.expressions.items[31] {
    Load(_) => ()
    _ => abort("expected else-branch mutable local load after constants")
  }
}

///|
test "WGSL AST lowerer inserts higher-precedence right binary subtrees before left operands" {
  let source =
    #|fn probe(point: vec2<f32>, size: vec2<f32>) -> vec2<f32> {
    #|  return point + size * 0.5;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  match function.expressions.items[0] {
    FunctionArgument(index) => debug_inspect(index, content="1")
    _ => abort("expected right subtree argument first")
  }
  match function.expressions.items[1] {
    Literal(_) => ()
    _ => abort("expected right subtree literal second")
  }
  match function.expressions.items[2] {
    FunctionArgument(index) => debug_inspect(index, content="0")
    _ =>
      abort(
        "expected source left operand after higher-precedence right subtree",
      )
  }
  match function.expressions.items[3] {
    Binary(Multiply, left, right) => {
      debug_inspect(left.index(), content="0")
      debug_inspect(right.index(), content="1")
    }
    _ => abort("expected right subtree multiply before parent add")
  }
  match function.expressions.items[4] {
    Binary(Add, left, right) => {
      debug_inspect(left.index(), content="2")
      debug_inspect(right.index(), content="3")
    }
    _ => abort("expected parent add to preserve source operands")
  }
}

///|
test "WGSL AST lowerer preserves literal-left product chain arena order" {
  let source =
    #|fn probe(ior: f32, a: f32, b: f32) -> f32 {
    #|  let eta = 1.0 / ior;
    #|  let ndot = a + b;
    #|  let result = 1.0 - eta * eta * (1.0 - ndot * ndot);
    #|  return result;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut eta_product = -1
  let mut ndot_product = -1
  let mut inner_literal = -1
  let mut saw_ndot_product = false
  for index, expression in function.expressions.items {
    match expression {
      Binary(Multiply, left, right) =>
        if left.index() == 2 && right.index() == 2 {
          eta_product = index
        } else if left.index() == 5 && right.index() == 5 {
          ndot_product = index
          saw_ndot_product = true
        }
      Literal(_) if saw_ndot_product && inner_literal == -1 =>
        inner_literal = index
      _ => ()
    }
  }
  if eta_product == -1 || ndot_product == -1 || inner_literal == -1 {
    abort("expected eta product, ndot product, and inner literal")
  }
  debug_inspect(eta_product < ndot_product, content="true")
  debug_inspect(ndot_product < inner_literal, content="true")
}

///|
test "WGSL AST lowerer commits source-let right binary before literal-left parent" {
  let source =
    #|fn probe(value: f32) -> f32 {
    #|  let named = value;
    #|  let result = 1.0 - named * named;
    #|  return result;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut product : Int? = None
  let mut literal : Int? = None
  for index, expression in function.expressions.items {
    match expression {
      Binary(Multiply, _, _) if product == None => product = Some(index)
      Literal(_) if literal == None => literal = Some(index)
      _ => ()
    }
  }
  match (product, literal) {
    (Some(product), Some(literal)) =>
      debug_inspect(product < literal, content="true")
    _ => abort("expected source-let product and literal-left parent")
  }
}

///|
test "WGSL AST lowerer predeclares right arguments before left access projection" {
  let source =
    #|fn probe(world_position: vec4<f32>, direction: vec3<f32>, thickness: f32) -> vec3<f32> {
    #|  let ray = direction;
    #|  return world_position.xyz + ray * thickness;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut world_root = -1
  let mut thickness_root = -1
  let mut swizzle = -1
  for index, expression in function.expressions.items {
    match expression {
      FunctionArgument(0) if world_root == -1 => world_root = index
      FunctionArgument(2) if thickness_root == -1 => thickness_root = index
      Swizzle(_, _, _) if swizzle == -1 => swizzle = index
      _ => ()
    }
  }
  if world_root == -1 || thickness_root == -1 || swizzle == -1 {
    abort("expected world root, thickness argument, and swizzle")
  }
  debug_inspect(world_root < thickness_root, content="true")
  debug_inspect(thickness_root < swizzle, content="true")
}

///|
test "WGSL AST lowerer keeps mutable local member load before right global root" {
  let source =
    #|struct View {
    #|  exposure: f32,
    #|}
    #|
    #|@group(0) @binding(0)
    #|var<uniform> view: View;
    #|
    #|fn probe() -> vec3<f32> {
    #|  var color: vec4<f32>;
    #|  return color.rgb / view.exposure;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut color_pointer = -1
  let mut color_load = -1
  let mut view_root = -1
  for index, expression in function.expressions.items {
    match expression {
      LocalVariable(_) if color_pointer == -1 => color_pointer = index
      Load(pointer) if pointer.index() == color_pointer && color_load == -1 =>
        color_load = index
      GlobalVariable(_) if view_root == -1 => view_root = index
      _ => ()
    }
  }
  if color_load == -1 || view_root == -1 {
    abort("expected mutable local load and global root")
  }
  debug_inspect(color_load < view_root, content="true")
}

///|
test "WGSL AST lowerer lowers right call before left literal constructor" {
  let source =
    #|fn helper(value: vec3<f32>, amount: f32) -> vec3<f32> {
    #|  return value * amount;
    #|}
    #|
    #|fn probe(base: vec3<f32>, amount: f32) -> vec3<f32> {
    #|  return vec3(1.0) - helper(base, amount);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[1]
  let mut call_result = -1
  let mut literal = -1
  let mut splat = -1
  for index, expression in function.expressions.items {
    match expression {
      CallResult(_) if call_result == -1 => call_result = index
      Literal(_) if literal == -1 => literal = index
      Splat(_, _) if splat == -1 => splat = index
      _ => ()
    }
  }
  if call_result == -1 || literal == -1 || splat == -1 {
    abort("expected call result, constructor literal, and splat")
  }
  debug_inspect(call_result < literal, content="true")
  debug_inspect(literal < splat, content="true")
}

///|
test "WGSL AST lowerer predeclares right call argument before left chain commit" {
  let source =
    #|fn probe(left: vec3<f32>, color: vec3<f32>, env: vec3<f32>, background: vec3<f32>, alpha: f32) -> vec3<f32> {
    #|  let fresnel = left + color;
    #|  return fresnel * color * mix(env, background, alpha);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut env_argument = -1
  let mut left_product = -1
  for index, expression in function.expressions.items {
    match expression {
      FunctionArgument(2) if env_argument == -1 => env_argument = index
      Binary(Multiply, _, _) if left_product == -1 => left_product = index
      _ => ()
    }
  }
  if env_argument == -1 || left_product == -1 {
    abort("expected env argument and left product")
  }
  debug_inspect(env_argument < left_product, content="true")
}

///|
test "WGSL AST lowerer keeps additive product subtrees in source arena order" {
  let source =
    #|fn probe(a: vec3<f32>, b: vec4<f32>, c: vec3<f32>, d: vec4<f32>) -> vec3<f32> {
    #|  return a * b.x + c * d.y;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  match function.expressions.items[0] {
    FunctionArgument(index) => debug_inspect(index, content="1")
    _ => abort("expected left product member root first")
  }
  match function.expressions.items[1] {
    FunctionArgument(index) => debug_inspect(index, content="0")
    _ => abort("expected left product value after predeclared member root")
  }
  match function.expressions.items[2] {
    AccessIndex(base, index) => {
      debug_inspect(base.index(), content="0")
      debug_inspect(index, content="0")
    }
    _ => abort("expected left product member projection")
  }
  match function.expressions.items[3] {
    Binary(Multiply, left, right) => {
      debug_inspect(left.index(), content="1")
      debug_inspect(right.index(), content="2")
    }
    _ => abort("expected left product before right product")
  }
  match function.expressions.items[4] {
    FunctionArgument(index) => debug_inspect(index, content="2")
    _ => abort("expected right product value after left product")
  }
  match function.expressions.items[5] {
    FunctionArgument(index) => debug_inspect(index, content="3")
    _ => abort("expected right product member root after left product")
  }
  match function.expressions.items[6] {
    AccessIndex(base, index) => {
      debug_inspect(base.index(), content="5")
      debug_inspect(index, content="1")
    }
    _ => abort("expected right product member projection")
  }
  match function.expressions.items[7] {
    Binary(Multiply, left, right) => {
      debug_inspect(left.index(), content="4")
      debug_inspect(right.index(), content="6")
    }
    _ => abort("expected right product after left product")
  }
  match function.expressions.items[8] {
    Binary(Add, left, right) => {
      debug_inspect(left.index(), content="3")
      debug_inspect(right.index(), content="7")
    }
    _ => abort("expected parent add over source-ordered products")
  }
}

///|
test "WGSL AST lowerer keeps right constructor arguments before left function argument in matrix multiply" {
  let source =
    #|fn matrix_vector_constructor_order(
    #|  origin: vec3<f32>,
    #|  transform: mat4x4<f32>,
    #|) -> vec3<f32> {
    #|  let projected = (transform * vec4(origin, 1.0)).xyz;
    #|  return projected;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  match function.expressions.items[0] {
    FunctionArgument(0) => ()
    _ => abort("expected constructor argument first")
  }
  match function.expressions.items[1] {
    Literal(AbstractFloat(1.0)) => ()
    _ => abort("expected constructor literal second")
  }
  match function.expressions.items[2] {
    FunctionArgument(1) => ()
    _ => abort("expected matrix argument after constructor leaves")
  }
  match function.expressions.items[3] {
    Compose(_, components) => {
      debug_inspect(components[0].index(), content="0")
      debug_inspect(components[1].index(), content="1")
    }
    _ => abort("expected vector constructor compose")
  }
  match function.expressions.items[4] {
    Binary(Multiply, left, right) => {
      debug_inspect(left.index(), content="2")
      debug_inspect(right.index(), content="3")
    }
    _ => abort("expected matrix/vector multiply")
  }
}

///|
test "WGSL AST lowerer keeps subtract product chains in writer arena order" {
  let source =
    #|struct Data {
    #|  x: f32,
    #|  z: f32,
    #|}
    #|
    #|fn probe(p: ptr<function, Data>) -> f32 {
    #|  return 1.0 - (*p).x * (*p).x - (*p).z * (*p).z;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  match function.expressions.items[0] {
    FunctionArgument(index) => debug_inspect(index, content="0")
    _ => abort("expected pointer argument root")
  }
  match function.expressions.items[1] {
    AccessIndex(base, _) => debug_inspect(base.index(), content="0")
    _ => abort("expected first x access before literal")
  }
  match function.expressions.items[2] {
    Load(pointer) => debug_inspect(pointer.index(), content="1")
    _ => abort("expected first x load")
  }
  match function.expressions.items[3] {
    AccessIndex(base, _) => debug_inspect(base.index(), content="0")
    _ => abort("expected second x access before literal")
  }
  match function.expressions.items[4] {
    Load(pointer) => debug_inspect(pointer.index(), content="3")
    _ => abort("expected second x load")
  }
  match function.expressions.items[5] {
    Binary(Multiply, left, right) => {
      debug_inspect(left.index(), content="2")
      debug_inspect(right.index(), content="4")
    }
    _ => abort("expected x product before literal")
  }
  match function.expressions.items[6] {
    Literal(_) => ()
    _ => abort("expected literal after first product")
  }
  match function.expressions.items[7] {
    Binary(Subtract, left, right) => {
      debug_inspect(left.index(), content="6")
      debug_inspect(right.index(), content="5")
    }
    _ => abort("expected first subtract before z product")
  }
  match function.expressions.items[8] {
    AccessIndex(base, _) => debug_inspect(base.index(), content="0")
    _ => abort("expected first z access after left subtract")
  }
  match function.expressions.items[9] {
    Load(pointer) => debug_inspect(pointer.index(), content="8")
    _ => abort("expected first z load")
  }
  match function.expressions.items[10] {
    AccessIndex(base, _) => debug_inspect(base.index(), content="0")
    _ => abort("expected second z access")
  }
  match function.expressions.items[11] {
    Load(pointer) => debug_inspect(pointer.index(), content="10")
    _ => abort("expected second z load")
  }
  match function.expressions.items[12] {
    Binary(Multiply, left, right) => {
      debug_inspect(left.index(), content="9")
      debug_inspect(right.index(), content="11")
    }
    _ => abort("expected z product after left subtract")
  }
  match function.expressions.items[13] {
    Binary(Subtract, left, right) => {
      debug_inspect(left.index(), content="7")
      debug_inspect(right.index(), content="12")
    }
    _ => abort("expected final subtract over source-ordered chain")
  }
}

///|
test "WGSL AST lowerer predeclares left associative binary chain roots" {
  let source =
    #|fn probe(factor: f32) -> f32 {
    #|  var lhs: f32;
    #|  var rhs: f32 = 1.0;
    #|  return lhs * factor * rhs;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  match function.expressions.items[1] {
    LocalVariable(_) => ()
    _ => abort("expected lhs local root before binary loads")
  }
  match function.expressions.items[2] {
    FunctionArgument(index) => debug_inspect(index, content="0")
    _ => abort("expected argument root before binary loads")
  }
  match function.expressions.items[3] {
    LocalVariable(_) => ()
    _ => abort("expected rhs local root before binary loads")
  }
  match function.expressions.items[4] {
    Load(pointer) => debug_inspect(pointer.index(), content="1")
    _ => abort("expected lhs load after source roots")
  }
  match function.expressions.items[5] {
    Binary(Multiply, left, right) => {
      debug_inspect(left.index(), content="4")
      debug_inspect(right.index(), content="2")
    }
    _ => abort("expected first multiply after lhs load")
  }
  match function.expressions.items[6] {
    Load(pointer) => debug_inspect(pointer.index(), content="3")
    _ => abort("expected rhs load after first multiply")
  }
  match function.expressions.items[7] {
    Binary(Multiply, left, right) => {
      debug_inspect(left.index(), content="5")
      debug_inspect(right.index(), content="6")
    }
    _ => abort("expected final multiply")
  }
}

///|
test "WGSL AST lowerer delays constructor literals after access arguments" {
  let source =
    #|struct Data {
    #|  x: f32,
    #|  y: f32,
    #|}
    #|
    #|fn probe(p: ptr<function, Data>) -> vec3<f32> {
    #|  return vec3<f32>((*p).x, 0.0, (*p).y);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  match function.expressions.items[0] {
    FunctionArgument(index) => debug_inspect(index, content="0")
    _ => abort("expected pointer argument root")
  }
  match function.expressions.items[1] {
    AccessIndex(base, _) => debug_inspect(base.index(), content="0")
    _ => abort("expected first access before literal")
  }
  match function.expressions.items[2] {
    Load(pointer) => debug_inspect(pointer.index(), content="1")
    _ => abort("expected first access load")
  }
  match function.expressions.items[3] {
    AccessIndex(base, _) => debug_inspect(base.index(), content="0")
    _ => abort("expected second access before literal")
  }
  match function.expressions.items[4] {
    Load(pointer) => debug_inspect(pointer.index(), content="3")
    _ => abort("expected second access load")
  }
  match function.expressions.items[5] {
    Literal(_) => ()
    _ => abort("expected literal after access arguments")
  }
  match function.expressions.items[6] {
    Compose(_, components) => {
      debug_inspect(components[0].index(), content="2")
      debug_inspect(components[1].index(), content="5")
      debug_inspect(components[2].index(), content="4")
    }
    _ => abort("expected constructor compose to preserve component order")
  }
}

///|
test "WGSL AST lowerer follows Naga call argument arena order for deferred select" {
  let source =
    #|struct Globals {
    #|  frame_count: u32,
    #|}
    #|
    #|@group(0) @binding(0) var<uniform> globals: Globals;
    #|
    #|fn noise(scale: vec2<f32>, frame: u32) -> f32 {
    #|  return scale.x + f32(frame);
    #|}
    #|
    #|fn probe(scale: vec2<f32>, temporal: bool) -> f32 {
    #|  let angle = 2.0 * 3.1415927 * noise(scale, select(1u, globals.frame_count, temporal));
    #|  return angle;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[1]
  match function.expressions.items[0] {
    GlobalVariable(_) => ()
    _ => abort("expected select accept root before call argument")
  }
  match function.expressions.items[1] {
    FunctionArgument(index) => debug_inspect(index, content="1")
    _ => abort("expected select condition before reject literal")
  }
  match function.expressions.items[2] {
    Literal(_) => ()
    _ => abort("expected select reject literal after condition")
  }
  match function.expressions.items[5] {
    Select(condition, accept, reject) => {
      debug_inspect(condition.index(), content="1")
      debug_inspect(accept.index(), content="4")
      debug_inspect(reject.index(), content="2")
    }
    _ => abort("expected select before first call argument")
  }
  match function.expressions.items[6] {
    FunctionArgument(index) => debug_inspect(index, content="0")
    _ => abort("expected direct call argument after deferred select")
  }
  match function.expressions.items[7] {
    CallResult(_) => ()
    _ => abort("expected user call result after arguments")
  }
  match function.expressions.items[8] {
    Literal(_) => ()
    _ => abort("expected folded left constant after call")
  }
}

///|
test "WGSL AST lowerer lowers constant select values after condition operands" {
  let source =
    #|const X_PLUS: u32 = 0u;
    #|const X_MINUS: u32 = 1u;
    #|
    #|fn probe(direction: vec3<f32>) -> u32 {
    #|  return select(X_PLUS, X_MINUS, direction.x < 0.0);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  match function.expressions.items[0] {
    FunctionArgument(index) => debug_inspect(index, content="0")
    _ => abort("expected direction argument root")
  }
  match function.expressions.items[1] {
    AccessIndex(base, index) => {
      debug_inspect(base.index(), content="0")
      debug_inspect(index, content="0")
    }
    _ => abort("expected condition access before constants")
  }
  match function.expressions.items[2] {
    Literal(_) => ()
    _ => abort("expected condition literal before constants")
  }
  match function.expressions.items[3] {
    Binary(_, left, right) => {
      debug_inspect(left.index(), content="1")
      debug_inspect(right.index(), content="2")
    }
    _ => abort("expected condition binary before constants")
  }
  match function.expressions.items[4] {
    Constant(_) => ()
    _ => abort("expected select accept constant after condition binary")
  }
  match function.expressions.items[5] {
    Constant(_) => ()
    _ => abort("expected select reject constant after accept")
  }
  match function.expressions.items[6] {
    Select(condition, accept, reject) => {
      debug_inspect(condition.index(), content="3")
      debug_inspect(accept.index(), content="4")
      debug_inspect(reject.index(), content="5")
    }
    _ => abort("expected select after binary condition")
  }
}

///|
test "WGSL AST lowerer lowers constant constructor select values after condition" {
  let source =
    #|fn probe(delta_cs: vec3<f32>) -> vec3<f32> {
    #|  return select(vec3(-1.0, -1.0, 0.0), vec3(1.0, 1.0, 1.0), delta_cs < vec3(0.0));
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  match function.expressions.items[0] {
    FunctionArgument(index) => debug_inspect(index, content="0")
    _ => abort("expected condition left argument")
  }
  match function.expressions.items[1] {
    Literal(_) => ()
    _ => abort("expected condition constructor literal")
  }
  match function.expressions.items[2] {
    Splat(_, component) => debug_inspect(component.index(), content="1")
    _ => abort("expected condition splat before binary")
  }
  match function.expressions.items[3] {
    Binary(_, left, right) => {
      debug_inspect(left.index(), content="0")
      debug_inspect(right.index(), content="2")
    }
    _ => abort("expected condition binary before select values")
  }
  match function.expressions.items[7] {
    Compose(_, components) => {
      debug_inspect(components[0].index(), content="4")
      debug_inspect(components[1].index(), content="5")
      debug_inspect(components[2].index(), content="6")
    }
    _ => abort("expected reject constructor after condition")
  }
  match function.expressions.items[11] {
    Compose(_, components) => {
      debug_inspect(components[0].index(), content="8")
      debug_inspect(components[1].index(), content="9")
      debug_inspect(components[2].index(), content="10")
    }
    _ => abort("expected accept constructor after reject")
  }
  match function.expressions.items[12] {
    Select(condition, accept, reject) => {
      debug_inspect(condition.index(), content="3")
      debug_inspect(accept.index(), content="11")
      debug_inspect(reject.index(), content="7")
    }
    _ => abort("expected select after constructor values")
  }
}

///|
test "WGSL AST lowerer lowers constant vector splat select values before binary condition root" {
  let source =
    #|fn probe(normal: vec3<f32>) -> vec3<f32> {
    #|  return select(vec3(0.0), vec3(0.5), normal < vec3(0.0));
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  match function.expressions.items[0] {
    Literal(_) => ()
    _ => abort("expected reject splat literal first")
  }
  match function.expressions.items[1] {
    Splat(_, component) => debug_inspect(component.index(), content="0")
    _ => abort("expected reject splat before condition")
  }
  match function.expressions.items[2] {
    Literal(_) => ()
    _ => abort("expected accept splat literal")
  }
  match function.expressions.items[3] {
    Splat(_, component) => debug_inspect(component.index(), content="2")
    _ => abort("expected accept splat before condition")
  }
  match function.expressions.items[4] {
    Literal(_) => ()
    _ => abort("expected condition right splat literal")
  }
  match function.expressions.items[5] {
    FunctionArgument(index) => debug_inspect(index, content="0")
    _ => abort("expected condition left root after right component")
  }
  match function.expressions.items[6] {
    Splat(_, component) => debug_inspect(component.index(), content="4")
    _ => abort("expected condition right splat")
  }
  match function.expressions.items[7] {
    Binary(_, left, right) => {
      debug_inspect(left.index(), content="5")
      debug_inspect(right.index(), content="6")
    }
    _ => abort("expected condition binary after splat operands")
  }
  match function.expressions.items[8] {
    Select(condition, accept, reject) => {
      debug_inspect(condition.index(), content="7")
      debug_inspect(accept.index(), content="3")
      debug_inspect(reject.index(), content="1")
    }
    _ => abort("expected select after splat condition")
  }
}

///|
test "WGSL AST lowerer folds pure literal binary constructor arguments in delayed literal pass" {
  let source =
    #|fn probe(uvw: vec3<f32>, offset: vec3<f32>) -> vec3<f32> {
    #|  return uvw + vec3(0.0, offset.y, 1.0 / 3.0);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  match function.expressions.items[2] {
    AccessIndex(_, _) => ()
    _ => abort("expected non-literal constructor argument first")
  }
  match function.expressions.items[3] {
    Literal(_) => ()
    _ => abort("expected first delayed literal")
  }
  match function.expressions.items[4] {
    Literal(_) => ()
    _ => abort("expected folded division literal")
  }
  match function.expressions.items[5] {
    Compose(_, components) => {
      debug_inspect(components[0].index(), content="3")
      debug_inspect(components[1].index(), content="2")
      debug_inspect(components[2].index(), content="4")
    }
    _ => abort("expected constructor compose before parent binary")
  }
  match function.expressions.items[6] {
    Binary(_, left, right) => {
      debug_inspect(left.index(), content="0")
      debug_inspect(right.index(), content="5")
    }
    _ => abort("expected parent binary after constructor compose")
  }
}

///|
test "WGSL AST lowerer lowers mutable local select operands before condition" {
  let source =
    #|fn probe(v: vec3<f32>) -> vec2<f32> {
    #|  var n = v / (abs(v.x) + abs(v.y) + abs(v.z));
    #|  let wrap = (1.0 - abs(n.yx)) * select(vec2(-1.0), vec2(1.0), n.xy > vec2f(0.0));
    #|  return select(wrap, n.xy, n.z >= 0.0);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  match function.expressions.items[29] {
    Load(pointer) => debug_inspect(pointer.index(), content="11")
    _ => abort("expected mutable local load before select condition")
  }
  match function.expressions.items[30] {
    Swizzle(_, base, _) => debug_inspect(base.index(), content="29")
    _ => abort("expected select accept swizzle before condition")
  }
  match function.expressions.items[31] {
    AccessIndex(base, index) => {
      debug_inspect(base.index(), content="11")
      debug_inspect(index, content="2")
    }
    _ => abort("expected condition member after accept")
  }
  match function.expressions.items[32] {
    Load(pointer) => debug_inspect(pointer.index(), content="31")
    _ => abort("expected condition load after member access")
  }
  match function.expressions.items[33] {
    Literal(_) => ()
    _ => abort("expected condition literal after local load")
  }
  match function.expressions.items[34] {
    Binary(_, left, right) => {
      debug_inspect(left.index(), content="32")
      debug_inspect(right.index(), content="33")
    }
    _ => abort("expected condition binary after accept")
  }
  match function.expressions.items[35] {
    Select(condition, accept, reject) => {
      debug_inspect(condition.index(), content="34")
      debug_inspect(accept.index(), content="30")
      debug_inspect(reject.index(), content="28")
    }
    _ => abort("expected select after source-order operands")
  }
}

///|
test "WGSL AST lowerer commits left constructor after right argument root" {
  let source =
    #|struct Raymarch { ray_start_cs: vec3<f32> }
    #|
    #|fn probe(raymarch: ptr<function, Raymarch>, dir_cs: vec4<f32>) -> vec4<f32> {
    #|  return vec4((*raymarch).ray_start_cs, 1.0) + dir_cs;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  match function.expressions.items[0] {
    FunctionArgument(index) => debug_inspect(index, content="0")
    _ => abort("expected pointer argument")
  }
  match function.expressions.items[1] {
    AccessIndex(base, index) => {
      debug_inspect(base.index(), content="0")
      debug_inspect(index, content="0")
    }
    _ => abort("expected member access")
  }
  match function.expressions.items[2] {
    Load(pointer) => debug_inspect(pointer.index(), content="1")
    _ => abort("expected member load")
  }
  match function.expressions.items[3] {
    Literal(_) => ()
    _ => abort("expected constructor literal before sibling argument")
  }
  match function.expressions.items[4] {
    FunctionArgument(index) => debug_inspect(index, content="1")
    _ => abort("expected sibling argument before constructor compose")
  }
  match function.expressions.items[5] {
    Compose(_, components) => {
      debug_inspect(components[0].index(), content="2")
      debug_inspect(components[1].index(), content="3")
    }
    _ => abort("expected constructor compose after sibling argument")
  }
  match function.expressions.items[6] {
    Binary(_, left, right) => {
      debug_inspect(left.index(), content="5")
      debug_inspect(right.index(), content="4")
    }
    _ => abort("expected final binary")
  }
}

///|
test "WGSL AST lowerer reuses duplicate untemplated var initializer literals" {
  let source =
    #|fn probe() -> vec2<u32> {
    #|  var corner_uv: vec2<u32> = vec2(0, 0);
    #|  return corner_uv;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  match function.expressions.items[0] {
    Literal(_) => ()
    _ => abort("expected a single typed literal")
  }
  match function.expressions.items[1] {
    Compose(_, components) => {
      debug_inspect(components[0].index(), content="0")
      debug_inspect(components[1].index(), content="0")
    }
    _ => abort("expected constructor compose to reuse duplicate literal")
  }
  match function.local_variables.items[0].init {
    Some(handle) => debug_inspect(handle.index(), content="1")
    None => abort("expected local initializer")
  }
}

///|
test "WGSL AST lowerer represents single vector members as Naga-style access indexes" {
  let source =
    #|fn probe(value: vec4<f32>) -> f32 {
    #|  return value.z;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  match function.expressions.items[1] {
    AccessIndex(base, index) => {
      debug_inspect(base.index(), content="0")
      debug_inspect(index, content="2")
    }
    Component(_, _) =>
      abort("expected Naga-style access index instead of component")
    _ => abort("expected vector member access")
  }
}

///|
test "WGSL AST lowerer predeclares binary member roots before projections" {
  let source =
    #|fn probe(point: vec2<f32>, width: vec4<f32>) -> f32 {
    #|  return point.x / width.x;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  match function.expressions.items[0] {
    FunctionArgument(index) => debug_inspect(index, content="0")
    _ => abort("expected left member root first")
  }
  match function.expressions.items[1] {
    FunctionArgument(index) => debug_inspect(index, content="1")
    _ => abort("expected right member root before left projection")
  }
  match function.expressions.items[2] {
    AccessIndex(base, index) => {
      debug_inspect(base.index(), content="0")
      debug_inspect(index, content="0")
    }
    _ => abort("expected left member projection after both roots")
  }
  match function.expressions.items[3] {
    AccessIndex(base, index) => {
      debug_inspect(base.index(), content="1")
      debug_inspect(index, content="0")
    }
    _ => abort("expected right member projection after left projection")
  }
  match function.expressions.items[4] {
    Binary(Divide, left, right) => {
      debug_inspect(left.index(), content="2")
      debug_inspect(right.index(), content="3")
    }
    _ => abort("expected division to preserve projected operands")
  }
}

///|
test "WGSL AST lowerer keeps global member binary operands in chain order" {
  let source =
    #|struct Settings {
    #|  min_value: f32,
    #|  max_value: f32,
    #|}
    #|
    #|@group(0) @binding(0) var<uniform> settings: Settings;
    #|
    #|fn probe() -> bool {
    #|  return settings.min_value >= settings.max_value;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  match function.expressions.items[0] {
    GlobalVariable(_) => ()
    _ => abort("expected left global root")
  }
  match function.expressions.items[1] {
    AccessIndex(base, index) => {
      debug_inspect(base.index(), content="0")
      debug_inspect(index, content="0")
    }
    _ => abort("expected left global member projection before right root")
  }
  match function.expressions.items[2] {
    Load(base) => debug_inspect(base.index(), content="1")
    _ => abort("expected left global member load before right root")
  }
  match function.expressions.items[3] {
    GlobalVariable(_) => ()
    _ => abort("expected right global root after left chain")
  }
  match function.expressions.items[4] {
    AccessIndex(base, index) => {
      debug_inspect(base.index(), content="3")
      debug_inspect(index, content="1")
    }
    _ => abort("expected right global member projection")
  }
  match function.expressions.items[5] {
    Load(base) => debug_inspect(base.index(), content="4")
    _ => abort("expected right global member load")
  }
}

///|
test "WGSL AST lowerer predeclares right argument before left global member projection" {
  let source =
    #|struct View {
    #|  clip_from_world: mat4x4<f32>,
    #|}
    #|
    #|@group(0) @binding(0) var<uniform> view: View;
    #|
    #|fn project(world_position: vec4<f32>) -> vec4<f32> {
    #|  return view.clip_from_world * world_position;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  match function.expressions.items[0] {
    GlobalVariable(_) => ()
    _ => abort("expected global member root first")
  }
  match function.expressions.items[1] {
    FunctionArgument(index) => debug_inspect(index, content="0")
    _ => abort("expected right function argument before left projection")
  }
  match function.expressions.items[2] {
    AccessIndex(base, index) => {
      debug_inspect(base.index(), content="0")
      debug_inspect(index, content="0")
    }
    _ => abort("expected left member projection after right argument")
  }
  match function.expressions.items[3] {
    Load(base) => debug_inspect(base.index(), content="2")
    _ => abort("expected global member load after projection")
  }
  match function.expressions.items[4] {
    Binary(Multiply, left, right) => {
      debug_inspect(left.index(), content="3")
      debug_inspect(right.index(), content="1")
    }
    _ => abort("expected multiply to preserve source operands")
  }
}

///|
test "WGSL AST lowerer scopes binary member root predeclarations per arena layer" {
  let source =
    #|struct View {
    #|  viewport: vec4<f32>,
    #|}
    #|
    #|@group(0) @binding(0) var<uniform> view: View;
    #|
    #|fn frag_coord_to_uv(frag_coord: vec2<f32>) -> vec2<f32> {
    #|  return (frag_coord - view.viewport.xy) / view.viewport.zw;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  match function.expressions.items[0] {
    GlobalVariable(_) => ()
    _ => abort("expected inner RHS global root before argument")
  }
  match function.expressions.items[1] {
    FunctionArgument(index) => debug_inspect(index, content="0")
    _ => abort("expected argument after inner RHS root")
  }
  match function.expressions.items[6] {
    GlobalVariable(_) => ()
    _ => abort("expected top-level RHS global root after left subtree")
  }
  match function.expressions.items[10] {
    Binary(Divide, left, right) => {
      debug_inspect(left.index(), content="5")
      debug_inspect(right.index(), content="9")
    }
    _ => abort("expected top-level divide after both subtree arenas")
  }
}

///|
test "WGSL AST lowerer orders nested call argument dependencies before outer siblings" {
  let source =
    #|fn inner(a: f32, b: f32) -> vec2<f32> {
    #|  return vec2<f32>(a, b);
    #|}
    #|
    #|fn outer(x: f32, y: vec2<f32>) -> vec2<f32> {
    #|  return y + vec2<f32>(x);
    #|}
    #|
    #|fn probe(a: f32, b: f32, c: f32) -> vec2<f32> {
    #|  return outer(a, inner(b, c));
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[2]
  match function.expressions.items[0] {
    FunctionArgument(index) => debug_inspect(index, content="1")
    _ => abort("expected inner first argument before outer sibling")
  }
  match function.expressions.items[1] {
    FunctionArgument(index) => debug_inspect(index, content="2")
    _ => abort("expected inner second argument before outer sibling")
  }
  match function.expressions.items[2] {
    CallResult(_) => ()
    _ => abort("expected inner call result before outer sibling")
  }
  match function.expressions.items[3] {
    FunctionArgument(index) => debug_inspect(index, content="0")
    _ => abort("expected outer first argument after inner call")
  }
  match function.expressions.items[4] {
    CallResult(_) => ()
    _ => abort("expected outer call result after reordered arguments")
  }
}

///|
test "WGSL AST lowerer folds untemplated vector constructor constants in math arenas" {
  let source =
    #|fn probe(color: vec3<f32>) -> f32 {
    #|  return dot(color, vec3(50.0 * 0.33));
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  debug_inspect(function.expressions.items.length(), content="4")
  let mut literal : Handle? = None
  let mut splat : Handle? = None
  let mut argument : Handle? = None
  for index, expression in function.expressions.items {
    match expression {
      Literal(_) => literal = Some(Handle(index))
      Splat(Tri, component) => {
        guard literal is Some(literal_handle) else {
          abort("expected folded literal before splat")
        }
        if component != literal_handle {
          abort("expected folded literal to feed vector splat")
        }
        splat = Some(Handle(index))
      }
      FunctionArgument(0) => argument = Some(Handle(index))
      Binary(Multiply, _, _) =>
        abort("constructor constant product must not survive in arena")
      Math(Dot, left, Some(right), None, None) => {
        guard argument is Some(argument_handle) else {
          abort("expected argument before dot")
        }
        guard splat is Some(splat_handle) else {
          abort("expected splat before dot")
        }
        if left != argument_handle || right != splat_handle {
          abort("expected dot over argument and folded vector splat")
        }
      }
      _ => ()
    }
  }
}

///|
test "WGSL AST lowerer prelowers clamp splat constructors before direct value" {
  let source =
    #|const MAX_VALUE = 65408.0;
    #|
    #|fn probe(color: vec3<f32>) -> vec3<f32> {
    #|  return clamp(color, vec3(0.0), vec3(MAX_VALUE));
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  match function.expressions.items[0] {
    Literal(_) => ()
    _ => abort("expected lower bound scalar before direct argument")
  }
  match function.expressions.items[1] {
    Splat(_, component) => debug_inspect(component.index(), content="0")
    _ => abort("expected lower bound splat before direct argument")
  }
  match function.expressions.items[2] {
    Literal(_) => ()
    _ => abort("expected upper bound scalar before direct argument")
  }
  match function.expressions.items[3] {
    FunctionArgument(index) => debug_inspect(index, content="0")
    _ => abort("expected direct value after splat scalar prelower")
  }
  match function.expressions.items[4] {
    Splat(_, component) => debug_inspect(component.index(), content="2")
    _ => abort("expected upper bound splat after direct argument")
  }
  match function.expressions.items[5] {
    Math(Clamp, value, Some(low), Some(high), None) => {
      debug_inspect(value.index(), content="3")
      debug_inspect(low.index(), content="1")
      debug_inspect(high.index(), content="4")
    }
    _ => abort("expected clamp to use source-order argument handles")
  }
}

///|
test "WGSL AST lowerer places parent argument after binary member root" {
  let source =
    #|struct Lights {
    #|  ambient_color: vec4<f32>,
    #|}
    #|
    #|@group(0) @binding(0) var<uniform> lights: Lights;
    #|
    #|fn probe(a: vec3<f32>, b: vec3<f32>, occlusion: f32) -> vec3<f32> {
    #|  return (a + b) * lights.ambient_color.rgb * occlusion;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  match function.expressions.items[2] {
    Binary(Add, left, right) => {
      debug_inspect(left.index(), content="0")
      debug_inspect(right.index(), content="1")
    }
    _ => abort("expected pure left subtree before global root")
  }
  match function.expressions.items[3] {
    GlobalVariable(_) => ()
    _ => abort("expected global root after pure left subtree")
  }
  match function.expressions.items[4] {
    FunctionArgument(index) => debug_inspect(index, content="2")
    _ => abort("expected parent right argument before global projection")
  }
  match function.expressions.items[5] {
    AccessIndex(base, _) => debug_inspect(base.index(), content="3")
    _ => abort("expected global member projection after parent argument")
  }
  match function.expressions.items[8] {
    Binary(Multiply, left, right) => {
      debug_inspect(left.index(), content="2")
      debug_inspect(right.index(), content="7")
    }
    _ => abort("expected inner multiply after projected global value")
  }
  match function.expressions.items[9] {
    Binary(Multiply, left, right) => {
      debug_inspect(left.index(), content="8")
      debug_inspect(right.index(), content="4")
    }
    _ => abort("expected parent multiply to reuse predeclared argument")
  }
}

///|
test "WGSL AST lowerer lowers math reference RHS before literal LHS" {
  let source =
    #|fn probe(a: f32) -> f32 {
    #|  var x = a;
    #|  x = max(0.0001, x);
    #|  return x;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut math_seen = false
  for index, expression in function.expressions.items {
    match expression {
      Math(Max, left, Some(right), None, None) => {
        math_seen = true
        guard function.expressions.items.get(right.index()) is Some(Load(_)) else {
          abort("expected mutable local load before math literal")
        }
        guard function.expressions.items.get(left.index()) is Some(Literal(_)) else {
          abort("expected literal to stay first math argument")
        }
        if right.index() >= left.index() {
          abort("expected mutable local load arena slot before literal")
        }
      }
      _ => ignore(index)
    }
  }
  debug_inspect(math_seen, content="true")
}

///|
test "WGSL AST lowerer emits static array literal indexes as Naga access indexes" {
  let source =
    #|const LAYER_BASE: u32 = 0u;
    #|
    #|struct Layer {
    #|  n: f32,
    #|}
    #|
    #|struct Input {
    #|  layers: array<Layer, 4>,
    #|}
    #|
    #|fn probe(input: ptr<function, Input>) -> f32 {
    #|  return (*input).layers[LAYER_BASE].n;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  match function.expressions.items[0] {
    FunctionArgument(index) => debug_inspect(index, content="0")
    _ => abort("expected pointer argument root")
  }
  match function.expressions.items[1] {
    AccessIndex(base, index) => {
      debug_inspect(base.index(), content="0")
      debug_inspect(index, content="0")
    }
    _ => abort("expected struct member access")
  }
  match function.expressions.items[2] {
    AccessIndex(base, index) => {
      debug_inspect(base.index(), content="1")
      debug_inspect(index, content="0")
    }
    Access(_, _) => abort("expected static array index, not dynamic access")
    _ => abort("expected static array access index")
  }
  match function.expressions.items[3] {
    AccessIndex(base, index) => {
      debug_inspect(base.index(), content="2")
      debug_inspect(index, content="0")
    }
    _ => abort("expected array element member access")
  }
  match function.expressions.items[4] {
    Load(base) => debug_inspect(base.index(), content="3")
    _ => abort("expected final load")
  }
}

///|
test "WGSL AST lowerer emits static runtime array literal indexes as Naga access indexes" {
  let source =
    #|@group(0) @binding(0)
    #|var<storage, read_write> values: array<u32>;
    #|
    #|fn probe() {
    #|  values[0] += values[1];
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  match function.expressions.items[0] {
    GlobalVariable(_) => ()
    _ => abort("expected storage array global root")
  }
  match function.expressions.items[1] {
    AccessIndex(base, index) => {
      debug_inspect(base.index(), content="0")
      debug_inspect(index, content="0")
    }
    Access(_, _) => abort("expected static runtime array index")
    _ => abort("expected access index")
  }
  match function.expressions.items[2] {
    Load(base) => debug_inspect(base.index(), content="1")
    _ => abort("expected old value load")
  }
  for expression in function.expressions.items {
    match expression {
      Literal(U32(_)) =>
        abort("static runtime array index should not allocate a literal")
      _ => ()
    }
  }
}

///|
test "WGSL AST lowerer loads dynamic storage array index value expressions" {
  let source =
    #|@group(0) @binding(0)
    #|var<storage, read> values: array<u32>;
    #|
    #|fn probe(index: u32) -> u32 {
    #|  let value = values[index];
    #|  return value;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  match function.expressions.items[0] {
    FunctionArgument(argument) => debug_inspect(argument, content="0")
    _ => abort("expected dynamic index argument")
  }
  match function.expressions.items[1] {
    GlobalVariable(_) => ()
    _ => abort("expected storage array global root")
  }
  match function.expressions.items[2] {
    Access(base, index) => {
      debug_inspect(base.index(), content="1")
      debug_inspect(index.index(), content="0")
    }
    _ => abort("expected dynamic storage array access pointer")
  }
  match function.expressions.items[3] {
    Load(pointer) => debug_inspect(pointer.index(), content="2")
    _ => abort("expected load from dynamic storage array access")
  }
  match function.named_expressions.get(0) {
    Some(named) => {
      debug_inspect(named.name, content="\"value\"")
      debug_inspect(named.handle.index(), content="3")
    }
    None => abort("expected dynamic storage array load named expression")
  }
}

///|
test "WGSL AST lowerer allocates resource globals per arena reference" {
  let source =
    #|@group(0) @binding(0)
    #|var texture: texture_2d<f32>;
    #|
    #|fn probe(coord: vec2<i32>) -> vec4<f32> {
    #|  let dimensions = textureDimensions(texture);
    #|  return textureLoad(texture, coord, 0);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut global_reference_count = 0
  for expression in function.expressions.items {
    match expression {
      GlobalVariable(_) => global_reference_count += 1
      _ => ()
    }
  }
  debug_inspect(global_reference_count, content="2")
  match function.expressions.items[0] {
    GlobalVariable(_) => ()
    _ => abort("expected first texture reference for textureDimensions")
  }
}

///|
test "WGSL AST lowerer keeps handle resource lets as expression aliases" {
  let source =
    #|@group(0) @binding(0)
    #|var texture: texture_3d<f32>;
    #|
    #|fn probe() -> vec3<u32> {
    #|  let local_texture = texture;
    #|  return textureDimensions(local_texture);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  for local_var in function.local_variables.items {
    match local_var.name {
      Some("local_texture") =>
        abort("resource alias must not lower to a local variable")
      _ => ()
    }
  }
  match function.expressions.items[1] {
    ImageQuery(image, Size(None)) =>
      match function.expressions.items[image.index()] {
        GlobalVariable(_) => ()
        _ => abort("resource alias must resolve to the global resource handle")
      }
    _ => abort("expected textureDimensions image query")
  }
}

///|
test "WGSL AST lowerer binds load let initializers as named expressions" {
  let source =
    #|struct Layer {
    #|  r: vec3<f32>,
    #|}
    #|
    #|struct Input {
    #|  layers: array<Layer, 4>,
    #|}
    #|
    #|fn probe(input: ptr<function, Input>, layer: u32, light_to_frag: vec3<f32>) -> f32 {
    #|  let r = (*input).layers[layer].r;
    #|  return dot(light_to_frag, r);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  match function.named_expressions.get(0) {
    Some(named) => {
      debug_inspect(named.name, content="\"r\"")
      debug_inspect(named.handle.index(), content="5")
    }
    None => abort("expected load initializer named expression")
  }
  let mut generated_temporary_count = 0
  for local_var in function.local_variables.items {
    if local_var.generated_temporary {
      generated_temporary_count += 1
    }
  }
  debug_inspect(generated_temporary_count, content="0")
  match function.expressions.items[1] {
    FunctionArgument(index) => debug_inspect(index, content="1")
    _ => abort("expected dynamic member index before static member projection")
  }
  match function.expressions.items[2] {
    AccessIndex(base, index) => {
      debug_inspect(base.index(), content="0")
      debug_inspect(index, content="0")
    }
    _ => abort("expected static member projection after dynamic index")
  }
  match function.expressions.items[3] {
    Access(base, index) => {
      debug_inspect(base.index(), content="2")
      debug_inspect(index.index(), content="1")
    }
    _ => abort("expected dynamic access after static member projection")
  }
  match function.expressions.items[6] {
    FunctionArgument(index) => debug_inspect(index, content="2")
    _ => abort("expected third argument before dot")
  }
  match function.expressions.items[7] {
    Math(Dot, left, Some(right), None, None) => {
      debug_inspect(left.index(), content="6")
      debug_inspect(right.index(), content="5")
    }
    _ => abort("expected dot to reuse named load")
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("let r: vec3<f32> = (*input).layers[layer].r;"),
    content="true",
  )
  debug_inspect(emitted.contains("dot(light_to_frag, r)"), content="true")
  debug_inspect(emitted.contains("_e"), content="false")
}

///|
test "WGSL AST lowerer predeclares later direct math argument before reference projection" {
  let source =
    #|struct Light {
    #|  direction_to_light: vec3<f32>,
    #|}
    #|
    #|struct Lights {
    #|  directional_lights: array<Light, 4>,
    #|}
    #|
    #|@group(0) @binding(0)
    #|var<uniform> lights: Lights;
    #|
    #|fn probe(ray_dir: vec3<f32>, i: u32) -> f32 {
    #|  let light = &lights.directional_lights[i];
    #|  return dot((*light).direction_to_light, ray_dir);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut light_access = -1
  let mut ray_dir = -1
  let mut direction_access = -1
  let mut direction_load = -1
  for expression_index, expression in function.expressions.items {
    match expression {
      Access(_, _) if light_access == -1 => light_access = expression_index
      FunctionArgument(0) if light_access >= 0 && ray_dir == -1 =>
        ray_dir = expression_index
      AccessIndex(base, _) if base.index() == light_access &&
        direction_access == -1 => direction_access = expression_index
      Load(pointer) if pointer.index() == direction_access &&
        direction_load == -1 => direction_load = expression_index
      _ => ()
    }
  }
  debug_inspect(light_access >= 0, content="true")
  debug_inspect(ray_dir > light_access, content="true")
  debug_inspect(direction_access > ray_dir, content="true")
  debug_inspect(direction_load > direction_access, content="true")
}

///|
test "WGSL AST lowerer lets named expressions shadow global addressable names" {
  let source =
    #|struct View {
    #|  w: f32,
    #|}
    #|
    #|@group(0) @binding(0)
    #|var<uniform> view: View;
    #|
    #|fn probe(view_from_clip: mat4x4<f32>, clip: vec4<f32>) -> vec4<f32> {
    #|  let view = view_from_clip * clip;
    #|  return view / view.w;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("let view_1: vec4<f32> = (view_from_clip * clip);"),
    content="true",
  )
  debug_inspect(emitted.contains("view_1.w"), content="true")
}

///|
test "WGSL AST lowerer preserves vector named expression result types" {
  let source =
    #|fn target(c: vec3<f32>) -> vec3<f32> {
    #|  return c;
    #|}
    #|
    #|fn probe(x: f32) -> vec3<f32> {
    #|  let red = vec3<f32>(0.1, 0.2, 0.3);
    #|  let blue = vec3<f32>(0.4, 0.5, 0.6);
    #|  let mixed = mix(red, blue, x);
    #|  return target(mixed);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[1]
  let mut mixed_named : NamedExpression? = None
  for named in function.named_expressions {
    if named.name == "mixed" {
      mixed_named = Some(named)
    }
  }
  match mixed_named {
    Some(named) => {
      debug_inspect(named.name, content="\"mixed\"")
      match module_.types.items.get(named.ty.index()) {
        Some({ inner: Vector(size, scalar), .. }) => {
          debug_inspect(size.width(), content="3")
          debug_inspect(scalar.kind, content="Float")
          debug_inspect(scalar.width, content="4")
        }
        _ => abort("expected mixed to keep vec3<f32> named type")
      }
    }
    None => abort("expected mixed named expression")
  }
  validate_wgsl_ir_module(module_) catch {
    error => abort(error.message())
  }
}

///|
test "WGSL AST lowerer lowers literal-left global reference RHS before literal" {
  let source =
    #|struct Globals {
    #|  time: f32,
    #|}
    #|
    #|@group(0) @binding(0)
    #|var<uniform> globals: Globals;
    #|
    #|fn probe() -> f32 {
    #|  let t = 0.05 * (0.85 + sin(5.0 * globals.time));
    #|  return t;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  match function.expressions.items[0] {
    GlobalVariable(_) => ()
    _ => abort("expected global reference before literal-left binary literal")
  }
  match function.expressions.items[1] {
    AccessIndex(base, index) => {
      debug_inspect(base.index(), content="0")
      debug_inspect(index, content="0")
    }
    _ => abort("expected global member access before literal")
  }
  match function.expressions.items[2] {
    Load(base) => debug_inspect(base.index(), content="1")
    _ => abort("expected global member load before literal")
  }
  match function.expressions.items[3] {
    Literal(_) => ()
    _ => abort("expected literal after global RHS load")
  }
}

///|
test "WGSL AST lowerer keeps member projections source ordered across higher-precedence right subtree" {
  let source =
    #|fn probe(point: vec2<f32>, width: vec4<f32>) -> f32 {
    #|  return point.x + width.y * 2.0;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  match function.expressions.items[0] {
    FunctionArgument(index) => debug_inspect(index, content="0")
    _ => abort("expected left member root first")
  }
  match function.expressions.items[1] {
    FunctionArgument(index) => debug_inspect(index, content="1")
    _ => abort("expected right member root second")
  }
  match function.expressions.items[2] {
    AccessIndex(base, index) => {
      debug_inspect(base.index(), content="0")
      debug_inspect(index, content="0")
    }
    _ => abort("expected left projection before right subtree projection")
  }
  match function.expressions.items[3] {
    AccessIndex(base, index) => {
      debug_inspect(base.index(), content="1")
      debug_inspect(index, content="1")
    }
    _ => abort("expected right projection before right subtree literal")
  }
  match function.expressions.items[4] {
    Literal(_) => ()
    _ => abort("expected right subtree literal after member projections")
  }
  match function.expressions.items[5] {
    Binary(Multiply, left, right) => {
      debug_inspect(left.index(), content="3")
      debug_inspect(right.index(), content="4")
    }
    _ => abort("expected right subtree multiply")
  }
  match function.expressions.items[6] {
    Binary(Add, left, right) => {
      debug_inspect(left.index(), content="2")
      debug_inspect(right.index(), content="5")
    }
    _ => abort("expected parent add")
  }
}

///|
test "WGSL AST lowerer predeclares right function argument root before left member multiply chain" {
  let source =
    #|struct Light {
    #|  shadow_normal_bias: f32,
    #|}
    #|
    #|@group(0) @binding(0)
    #|var<uniform> light: Light;
    #|
    #|fn probe(distance: f32, surface_normal: vec3<f32>) -> vec3<f32> {
    #|  let distance_to_light = distance + 1.0;
    #|  let normal_offset = light.shadow_normal_bias * distance_to_light * surface_normal.xyz;
    #|  return normal_offset;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut surface_argument : Int? = None
  let mut shadow_bias_load : Int? = None
  for index, expression in function.expressions.items {
    match expression {
      FunctionArgument(argument_index) if argument_index == 1 &&
        surface_argument == None => surface_argument = Some(index)
      Load(base) if shadow_bias_load == None =>
        match function.expressions.items.get(base.index()) {
          Some(AccessIndex(access_base, _)) =>
            match function.expressions.items.get(access_base.index()) {
              Some(GlobalVariable(_)) => shadow_bias_load = Some(index)
              _ => ()
            }
          _ => ()
        }
      _ => ()
    }
  }
  match (surface_argument, shadow_bias_load) {
    (Some(surface), Some(load)) => debug_inspect(surface < load, content="true")
    _ => abort("expected surface argument and shadow bias load handles")
  }
}

///|
test "WGSL AST lowerer schedules right multiply argument before left pointer field load" {
  let source =
    #|struct Meshlet {
    #|  start_vertex_position_bit: u32,
    #|}
    #|
    #|fn probe(meshlet: ptr<function, Meshlet>, vertex_id: u32, bits_per_vertex: u32) -> u32 {
    #|  var start_bit = (*meshlet).start_vertex_position_bit + (vertex_id * bits_per_vertex);
    #|  return start_bit;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut vertex_argument : Int? = None
  let mut field_load : Int? = None
  let mut multiply : Int? = None
  for index, expression in function.expressions.items {
    match expression {
      FunctionArgument(argument_index) if argument_index == 1 &&
        vertex_argument == None => vertex_argument = Some(index)
      Load(base) if field_load == None =>
        match function.expressions.items.get(base.index()) {
          Some(AccessIndex(access_base, _)) =>
            match function.expressions.items.get(access_base.index()) {
              Some(FunctionArgument(argument_index)) if argument_index == 0 =>
                field_load = Some(index)
              _ => ()
            }
          _ => ()
        }
      Binary(Multiply, _, _) if multiply == None => multiply = Some(index)
      _ => ()
    }
  }
  match (vertex_argument, field_load, multiply) {
    (Some(vertex), Some(load), Some(product)) => {
      debug_inspect(vertex < load, content="true")
      debug_inspect(load < product, content="true")
    }
    _ => abort("expected vertex argument, field load, and multiply handles")
  }
}

///|
test "WGSL AST lowerer predeclares compound assignment RHS function argument projection before target load" {
  let source =
    #|struct PartialDerivatives {
    #|  ddx: vec3<f32>,
    #|}
    #|
    #|fn probe(scale: vec2<f32>) -> vec3<f32> {
    #|  var result: PartialDerivatives;
    #|  result.ddx = vec3(1.0);
    #|  result.ddx *= scale.x;
    #|  return result.ddx;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut scale_argument : Int? = None
  let mut result_ddx_load : Int? = None
  for index, expression in function.expressions.items {
    match expression {
      FunctionArgument(argument_index) if argument_index == 0 &&
        scale_argument == None => scale_argument = Some(index)
      Load(pointer) =>
        match function.expressions.items.get(pointer.index()) {
          Some(AccessIndex(base, _)) =>
            match function.expressions.items.get(base.index()) {
              Some(LocalVariable(_)) if scale_argument != None &&
                result_ddx_load == None => result_ddx_load = Some(index)
              _ => ()
            }
          _ => ()
        }
      _ => ()
    }
  }
  match (scale_argument, result_ddx_load) {
    (Some(scale), Some(load)) => debug_inspect(scale < load, content="true")
    _ => abort("expected scale argument and result.ddx load")
  }
}

///|
test "WGSL AST lowerer materializes subgroup call conditions like Naga" {
  let source =
    #|enable subgroups;
    #|
    #|fn probe(max_x: f32, min_x: f32) {
    #|  if subgroupAny(max_x - min_x > 4.0) {
    #|  }
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("_ = subgroupAny"), content="false")
  debug_inspect(emitted.contains(": bool = subgroupAny"), content="true")
  debug_inspect(emitted.contains("if _e"), content="true")
}

///|
test "WGSL AST lowerer predeclares short-circuit condition local operands before loads" {
  let source =
    #|fn probe(layer_count: f32) -> f32 {
    #|  var texture_depth = 1.0;
    #|  var current_layer_depth = 0.0;
    #|  for (var i: i32 = 0; texture_depth > current_layer_depth && i <= i32(layer_count); i++) {
    #|    current_layer_depth += 0.1;
    #|  }
    #|  return texture_depth;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut matched = false
  for _, expression in function.expressions.items {
    match expression {
      Binary(Greater, left, right) =>
        match
          (
            function.expressions.items.get(left.index()),
            function.expressions.items.get(right.index()),
          ) {
          (Some(Load(left_pointer)), Some(Load(right_pointer))) => {
            debug_inspect(left_pointer.index() < left.index(), content="true")
            debug_inspect(right_pointer.index() < left.index(), content="true")
            debug_inspect(left.index() < right.index(), content="true")
            matched = true
          }
          _ => ()
        }
      _ => ()
    }
  }
  debug_inspect(matched, content="true")
}

///|
test "WGSL AST lowerer orders global scale root before argument product in subtract" {
  let source =
    #|@group(0) @binding(0) var<uniform> thickness: f32;
    #|
    #|fn probe(delta_position: vec3<f32>, view_vec: vec3<f32>) -> vec3<f32> {
    #|  return delta_position - view_vec * thickness;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut global_root : Int? = None
  let mut view_argument : Int? = None
  let mut delta_argument : Int? = None
  let mut global_load : Int? = None
  for index, expression in function.expressions.items {
    match expression {
      GlobalVariable(_) if global_root == None => global_root = Some(index)
      FunctionArgument(1) if view_argument == None =>
        view_argument = Some(index)
      FunctionArgument(0) if delta_argument == None =>
        delta_argument = Some(index)
      Load(pointer) =>
        match function.expressions.items.get(pointer.index()) {
          Some(GlobalVariable(_)) if global_load == None =>
            global_load = Some(index)
          _ => ()
        }
      _ => ()
    }
  }
  match (global_root, view_argument, delta_argument, global_load) {
    (Some(root), Some(view), Some(delta), Some(load)) => {
      debug_inspect(root < view, content="true")
      debug_inspect(view < delta, content="true")
      debug_inspect(delta < load, content="true")
    }
    _ => abort("expected global root, two arguments, and global load")
  }
}

///|
test "WGSL AST lowerer predeclares later fma direct argument after first constructor component" {
  let source =
    #|fn probe(sampling_direction: f32, n: vec2<f32>) -> vec2<f32> {
    #|  var front_back_horizon = vec2(0.1, 0.2);
    #|  front_back_horizon = fma(vec2(sampling_direction), -front_back_horizon, n);
    #|  return front_back_horizon;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut sampling_argument : Int? = None
  let mut n_argument : Int? = None
  let mut sampling_splat : Int? = None
  let mut horizon_load : Int? = None
  for index, expression in function.expressions.items {
    match expression {
      FunctionArgument(0) if sampling_argument == None =>
        sampling_argument = Some(index)
      FunctionArgument(1) if n_argument == None => n_argument = Some(index)
      Splat(_, inner) =>
        match sampling_argument {
          Some(sampling) if inner.index() == sampling && sampling_splat == None =>
            sampling_splat = Some(index)
          _ => ()
        }
      Load(pointer) =>
        match function.expressions.items.get(pointer.index()) {
          Some(LocalVariable(_)) if sampling_splat != None &&
            horizon_load == None => horizon_load = Some(index)
          _ => ()
        }
      _ => ()
    }
  }
  match (sampling_argument, n_argument, sampling_splat, horizon_load) {
    (Some(sampling), Some(n), Some(splat), Some(load)) => {
      debug_inspect(sampling < n, content="true")
      debug_inspect(n < splat, content="true")
      debug_inspect(splat < load, content="true")
    }
    _ => abort("expected fma argument ordering handles")
  }
}

///|
test "WGSL AST lowerer does not treat user call math argument as constructor" {
  let source =
    #|fn calculate(reflectance: vec3<f32>) -> vec3<f32> {
    #|  return reflectance;
    #|}
    #|
    #|fn probe(base_color: vec3<f32>, metallic: f32, reflectance: vec3<f32>) -> vec3<f32> {
    #|  return mix(calculate(reflectance), base_color, metallic);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[1]
  let mut call_result : Int? = None
  let mut base_color_argument : Int? = None
  for index, expression in function.expressions.items {
    match expression {
      CallResult(_) if call_result == None => call_result = Some(index)
      FunctionArgument(0) if base_color_argument == None =>
        base_color_argument = Some(index)
      _ => ()
    }
  }
  match (call_result, base_color_argument) {
    (Some(call), Some(base_color)) =>
      debug_inspect(call < base_color, content="true")
    _ => abort("expected user call result and base_color argument")
  }
}

///|
test "WGSL AST lowerer schedules store pointer argument reads through assignment context" {
  let source =
    #|fn update(a: f32, b: f32, samples: f32, bits: u32) -> u32 {
    #|  return bits;
    #|}
    #|
    #|fn probe(front_back_horizon: vec2<f32>, samples_per_slice: f32, bitmask: ptr<function, u32>) {
    #|  *bitmask = update(front_back_horizon.x, front_back_horizon.y, samples_per_slice, *bitmask);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[1]
  let mut bitmask_root : Int? = None
  let mut horizon_access : Int? = None
  let mut bitmask_load : Int? = None
  let mut samples_argument : Int? = None
  for index, expression in function.expressions.items {
    match expression {
      FunctionArgument(2) if bitmask_root == None => bitmask_root = Some(index)
      AccessIndex(base, _) if horizon_access == None =>
        match function.expressions.items.get(base.index()) {
          Some(FunctionArgument(0)) => horizon_access = Some(index)
          _ => ()
        }
      Load(base) if bitmask_load == None =>
        match function.expressions.items.get(base.index()) {
          Some(FunctionArgument(2)) => bitmask_load = Some(index)
          _ => ()
        }
      FunctionArgument(1) if samples_argument == None =>
        samples_argument = Some(index)
      _ => ()
    }
  }
  match (bitmask_root, horizon_access, bitmask_load, samples_argument) {
    (Some(root), Some(access), Some(load), Some(samples)) => {
      debug_inspect(root < access, content="true")
      debug_inspect(load < samples, content="true")
    }
    _ => abort("expected store pointer root, horizon access, load, and samples")
  }
}

///|
test "WGSL AST lowerer predeclares right argument projection before left member multiply chain" {
  let source =
    #|struct Light {
    #|  shadow_normal_bias: f32,
    #|}
    #|
    #|struct Cascade {
    #|  texel_size: f32,
    #|}
    #|
    #|@group(0) @binding(0)
    #|var<uniform> light: Light;
    #|
    #|@group(0) @binding(1)
    #|var<uniform> cascade: Cascade;
    #|
    #|fn probe(surface_normal: vec3<f32>) -> vec3<f32> {
    #|  let normal_offset = light.shadow_normal_bias * cascade.texel_size * surface_normal.xyz;
    #|  return normal_offset;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut surface_argument : Int? = None
  let mut first_member_load : Int? = None
  for index, expression in function.expressions.items {
    match expression {
      FunctionArgument(argument_index) if argument_index == 0 &&
        surface_argument == None => surface_argument = Some(index)
      Load(base) if first_member_load == None =>
        match function.expressions.items.get(base.index()) {
          Some(AccessIndex(access_base, _)) =>
            match function.expressions.items.get(access_base.index()) {
              Some(GlobalVariable(_)) => first_member_load = Some(index)
              _ => ()
            }
          _ => ()
        }
      _ => ()
    }
  }
  match (surface_argument, first_member_load) {
    (Some(surface), Some(load)) => debug_inspect(surface < load, content="true")
    _ => abort("expected surface argument and member load handles")
  }
}

///|
test "WGSL AST lowerer keeps math-call additive left subtree before right product" {
  let source =
    #|struct Light {
    #|  shadow_depth_bias: f32,
    #|  shadow_normal_bias: f32,
    #|}
    #|
    #|@group(0) @binding(0)
    #|var<uniform> light: Light;
    #|
    #|fn probe(surface_to_light: vec3<f32>, surface_normal: vec3<f32>, distance: f32) -> vec3<f32> {
    #|  let offset = -surface_to_light + (light.shadow_depth_bias * normalize(surface_to_light)) + (surface_normal.xyz * light.shadow_normal_bias) * distance;
    #|  return offset;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut global_root : Int? = None
  let mut left_unary : Int? = None
  let mut surface_argument : Int? = None
  let mut surface_swizzle : Int? = None
  let mut shadow_depth_load : Int? = None
  for index, expression in function.expressions.items {
    match expression {
      GlobalVariable(_) if global_root == None => global_root = Some(index)
      Unary(_, _) if left_unary == None => left_unary = Some(index)
      FunctionArgument(argument_index) if argument_index == 1 &&
        surface_argument == None => surface_argument = Some(index)
      Swizzle(_, base, _) if surface_swizzle == None =>
        match function.expressions.items.get(base.index()) {
          Some(FunctionArgument(argument_index)) if argument_index == 1 =>
            surface_swizzle = Some(index)
          _ => ()
        }
      Load(base) =>
        match function.expressions.items.get(base.index()) {
          Some(AccessIndex(access_base, 0)) =>
            match global_root {
              Some(root) if access_base.index() == root =>
                shadow_depth_load = Some(index)
              _ => ()
            }
          _ => ()
        }
      _ => ()
    }
  }
  match (left_unary, surface_argument, surface_swizzle, shadow_depth_load) {
    (Some(unary), Some(surface), Some(swizzle), Some(depth_load)) => {
      debug_inspect(unary < swizzle, content="true")
      debug_inspect(surface < depth_load, content="true")
    }
    _ => abort("expected left unary and surface normal swizzle handles")
  }
}

///|
test "WGSL AST lowerer keeps left splat constructor before grouped product RHS" {
  let source =
    #|struct Material {
    #|  scale: vec2<f32>,
    #|}
    #|
    #|@group(0) @binding(0)
    #|var<uniform> material: Material;
    #|
    #|fn probe(uv: vec2<f32>) -> vec2<f32> {
    #|  return vec2<f32>(1.0) - (vec2<f32>(1.0) - uv) * material.scale;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut splats_before_load = 0
  let mut scale_load : Int? = None
  for index, expression in function.expressions.items {
    match expression {
      Load(pointer) if scale_load == None =>
        match function.expressions.items.get(pointer.index()) {
          Some(AccessIndex(access_base, 0)) =>
            match function.expressions.items.get(access_base.index()) {
              Some(GlobalVariable(_)) => scale_load = Some(index)
              _ => ()
            }
          _ => ()
        }
      Splat(_, _) if scale_load == None => splats_before_load += 1
      _ => ()
    }
  }
  match scale_load {
    Some(_) => debug_inspect(splats_before_load, content="2")
    None => abort("expected material.scale load")
  }
}

///|
test "WGSL AST lowerer keeps field assignment RHS local load before global product roots" {
  let source =
    #|struct Material {
    #|  tile: vec2<f32>,
    #|}
    #|
    #|@group(0) @binding(0)
    #|var<uniform> material: Material;
    #|
    #|fn probe(input_uv: vec2<f32>) -> vec2<f32> {
    #|  var uv = input_uv;
    #|  uv.x = (uv.x - material.tile.x * floor(uv.x / material.tile.x)) / material.tile.x;
    #|  return uv;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut first_uv_load : Int? = None
  let mut first_material_load : Int? = None
  for index, expression in function.expressions.items {
    match expression {
      Load(pointer) =>
        match function.expressions.items.get(pointer.index()) {
          Some(AccessIndex(base, 0)) =>
            match function.expressions.items.get(base.index()) {
              Some(LocalVariable(_)) if first_uv_load == None =>
                first_uv_load = Some(index)
              Some(AccessIndex(material_root, _)) =>
                match function.expressions.items.get(material_root.index()) {
                  Some(GlobalVariable(_)) if first_material_load == None =>
                    first_material_load = Some(index)
                  _ => ()
                }
              _ => ()
            }
          _ => ()
        }
      _ => ()
    }
  }
  match (first_uv_load, first_material_load) {
    (Some(uv_load), Some(material_load)) =>
      debug_inspect(uv_load < material_load, content="true")
    _ => abort("expected uv and material loads")
  }
}

///|
test "WGSL AST lowerer appends literal-left division product denominator before numerator" {
  let source =
    #|fn probe(scale: f32, position: vec3<f32>) -> f32 {
    #|  let value = 1.0 / (scale * -position.z);
    #|  return value;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut denominator_binary : Int? = None
  let mut numerator_literal : Int? = None
  for index, expression in function.expressions.items {
    match expression {
      Binary(Multiply, _, _) if denominator_binary == None =>
        denominator_binary = Some(index)
      Literal(_) if numerator_literal == None => numerator_literal = Some(index)
      _ => ()
    }
  }
  match (denominator_binary, numerator_literal) {
    (Some(denominator), Some(numerator)) =>
      debug_inspect(denominator < numerator, content="true")
    _ => abort("expected denominator multiply and numerator literal")
  }
}

///|
test "WGSL AST lowerer appends literal-left division call denominator before numerator" {
  let source =
    #|fn near() -> f32 {
    #|  return 0.1;
    #|}
    #|
    #|fn probe() -> f32 {
    #|  let value = 1.0 / near();
    #|  return value;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[1]
  let mut denominator_call : Int? = None
  let mut numerator_literal : Int? = None
  for index, expression in function.expressions.items {
    match expression {
      CallResult(_) if denominator_call == None =>
        denominator_call = Some(index)
      Literal(_) if numerator_literal == None => numerator_literal = Some(index)
      _ => ()
    }
  }
  match (denominator_call, numerator_literal) {
    (Some(denominator), Some(numerator)) =>
      debug_inspect(denominator < numerator, content="true")
    _ => abort("expected denominator call and numerator literal")
  }
}

///|
test "WGSL AST lowerer lowers scalar conversion constructors as As expressions" {
  let source =
    #|fn probe(light_id: u32, offset: i32) -> i32 {
    #|  let array_index = i32(light_id) + offset;
    #|  return array_index;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut found_as = false
  for expression in function.expressions.items {
    match expression {
      As(_, Sint, Some(4)) => found_as = true
      _ => ()
    }
  }
  debug_inspect(found_as, content="true")
}

///|
test "WGSL AST lowerer prelowers later reference call argument before prior direct argument" {
  let source =
    #|struct Light {
    #|  soft_shadow_size: f32,
    #|}
    #|
    #|@group(0) @binding(0)
    #|var<uniform> light: Light;
    #|
    #|fn target(depth: f32, frag_coord: vec2<f32>, light_size: f32) -> f32 {
    #|  return light_size;
    #|}
    #|
    #|fn probe(depth: f32, frag_coord: vec2<f32>) -> f32 {
    #|  return target(depth, frag_coord, light.soft_shadow_size);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[1]
  let mut depth_argument : Int? = None
  let mut frag_argument : Int? = None
  let mut soft_shadow_load : Int? = None
  for index, expression in function.expressions.items {
    match expression {
      FunctionArgument(argument_index) if argument_index == 0 &&
        depth_argument == None => depth_argument = Some(index)
      FunctionArgument(argument_index) if argument_index == 1 &&
        frag_argument == None => frag_argument = Some(index)
      Load(base) if soft_shadow_load == None =>
        match function.expressions.items.get(base.index()) {
          Some(AccessIndex(access_base, _)) =>
            match function.expressions.items.get(access_base.index()) {
              Some(GlobalVariable(_)) => soft_shadow_load = Some(index)
              _ => ()
            }
          _ => ()
        }
      _ => ()
    }
  }
  match (soft_shadow_load, depth_argument, frag_argument) {
    (Some(load), Some(depth), Some(frag)) => {
      debug_inspect(load < depth, content="true")
      debug_inspect(load < frag, content="true")
    }
    _ => abort("expected soft shadow load and frag coord argument")
  }
}

///|
test "WGSL AST lowerer prelowers later source-let arithmetic before prior direct literal argument" {
  let source =
    #|fn target(width: f32, dir: vec2<f32>, thickness: f32, radius: f32, mask: ptr<function, u32>) -> f32 {
    #|  *mask = 1u;
    #|  return radius + thickness + dir.x + width;
    #|}
    #|
    #|fn probe(width: f32, dir: vec2<f32>) -> f32 {
    #|  var mask = 0u;
    #|  let scale = width;
    #|  return target(width, dir, -1.0, scale * 2.0, &mask);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[1]
  let mut minus_literal = -1
  let mut scale_product = -1
  for expression_index, expression in function.expressions.items {
    match expression {
      Literal(AbstractFloat(value)) if value == -1.0 && minus_literal == -1 =>
        minus_literal = expression_index
      Binary(Multiply, _, _) if scale_product == -1 =>
        scale_product = expression_index
      _ => ()
    }
  }
  debug_inspect(minus_literal >= 0, content="true")
  debug_inspect(scale_product >= 0, content="true")
  debug_inspect(scale_product < minus_literal, content="true")
}

///|
test "WGSL AST lowerer skips alias projection call arguments when prelowering later reference argument" {
  let source =
    #|struct Light {
    #|  soft_shadow_size: f32,
    #|}
    #|
    #|@group(0) @binding(0)
    #|var<uniform> light: Light;
    #|
    #|const TEXEL_SIZE: f32 = 0.25;
    #|
    #|fn target(uv: vec2<f32>, depth: f32, frag_coord: vec2<f32>, texel_size: f32, light_size: f32) -> f32 {
    #|  return light_size;
    #|}
    #|
    #|fn probe(light_local: vec3<f32>, frag_coord: vec2<f32>) -> f32 {
    #|  let projected = light_local;
    #|  return target(projected.xy, projected.z, frag_coord, TEXEL_SIZE, light.soft_shadow_size);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[1]
  let mut frag_argument : Int? = None
  let mut soft_shadow_load : Int? = None
  for index, expression in function.expressions.items {
    match expression {
      FunctionArgument(argument_index) if argument_index == 1 &&
        frag_argument == None => frag_argument = Some(index)
      Load(base) if soft_shadow_load == None =>
        match function.expressions.items.get(base.index()) {
          Some(AccessIndex(access_base, _)) =>
            match function.expressions.items.get(access_base.index()) {
              Some(GlobalVariable(_)) => soft_shadow_load = Some(index)
              _ => ()
            }
          _ => ()
        }
      _ => ()
    }
  }
  match (soft_shadow_load, frag_argument) {
    (Some(load), Some(argument)) =>
      debug_inspect(load < argument, content="true")
    _ => abort("expected soft shadow load and frag coord argument")
  }
}

///|
test "WGSL AST lowerer keeps earlier compound call argument before later reference argument" {
  let source =
    #|struct Light {
    #|  soft_shadow_size: f32,
    #|}
    #|
    #|@group(0) @binding(0)
    #|var<uniform> light: Light;
    #|
    #|const flip_z: vec3<f32> = vec3<f32>(1.0, 1.0, -1.0);
    #|
    #|fn target(position: vec3<f32>, light_id: u32, light_size: f32) -> f32 {
    #|  return light_size;
    #|}
    #|
    #|fn probe(frag_ls: vec3<f32>, light_id: u32) -> f32 {
    #|  return target(frag_ls * flip_z, light_id, light.soft_shadow_size);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[1]
  let mut flip_constant : Int? = None
  let mut position_product : Int? = None
  let mut soft_shadow_load : Int? = None
  for index, expression in function.expressions.items {
    match expression {
      Constant(_) if flip_constant == None => flip_constant = Some(index)
      Binary(Multiply, _, _) if position_product == None =>
        position_product = Some(index)
      Load(base) if soft_shadow_load == None =>
        match function.expressions.items.get(base.index()) {
          Some(AccessIndex(access_base, _)) =>
            match function.expressions.items.get(access_base.index()) {
              Some(GlobalVariable(_)) => soft_shadow_load = Some(index)
              _ => ()
            }
          _ => ()
        }
      _ => ()
    }
  }
  match (flip_constant, position_product, soft_shadow_load) {
    (Some(constant), Some(product), Some(load)) =>
      debug_inspect(constant < product && product < load, content="true")
    _ =>
      abort("expected flip_z constant, position product, and soft shadow load")
  }
}

///|
test "WGSL AST lowerer keeps shadowing var out of scope while lowering its initializer" {
  let source =
    #|fn convert(value: vec2<f32>) -> vec4<f32> {
    #|  return vec4<f32>(value, 0.0, 1.0);
    #|}
    #|
    #|fn probe(input: vec2<f32>) -> vec3<f32> {
    #|  let p = input;
    #|  {
    #|    var p = convert(p).xyz;
    #|    return p;
    #|  }
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  validate_wgsl_ir_module(module_) catch {
    error => abort(error.message())
  }
}

///|
test "WGSL AST lowerer preserves global and function const_asserts in IR" {
  let source =
    #|const VALUE: u32 = 1u;
    #|const_assert VALUE == 1u;
    #|
    #|fn helper() {
    #|  const_assert VALUE > 0u;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  debug_inspect(module_.const_asserts.length(), content="1")
  guard module_.functions.items.length() == 1 else {
    abort("expected one helper function")
  }
  match module_.functions.items[0].body.statements[0] {
    ConstAssert(_) => ()
    _ => abort("expected function const_assert statement")
  }
}

///|
test "WGSL AST lowerer refreshes aggregate layouts after forward type bodies" {
  let source =
    #|struct Parent {
    #|  children: array<Child, 4>,
    #|  tail: vec2<u32>,
    #|}
    #|
    #|struct Child {
    #|  a: vec4<f32>,
    #|  b: vec4<f32>,
    #|}
    #|
    #|@group(0) @binding(0)
    #|var<storage, read> parents: array<Parent>;
    #|
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  validate_wgsl_ir_module(module_) catch {
    error => abort(error.message())
  }
}

///|
test "WGSL AST lowerer preserves barrier statement calls in IR" {
  let source =
    #|@compute @workgroup_size(1)
    #|fn main() {
    #|  workgroupBarrier();
    #|  storageBarrier();
    #|  textureBarrier();
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let statements = module_.entry_points[0].function.body.statements
  match statements[0] {
    ControlBarrier(barrier) =>
      debug_inspect(barrier == Barrier::work_group(), content="true")
    _ => abort("expected workgroup control barrier")
  }
  match statements[1] {
    MemoryBarrier(barrier) =>
      debug_inspect(barrier == Barrier::storage(), content="true")
    _ => abort("expected storage memory barrier")
  }
  match statements[2] {
    MemoryBarrier(barrier) =>
      debug_inspect(barrier == Barrier::texture(), content="true")
    _ => abort("expected texture memory barrier")
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("workgroupBarrier();"), content="true")
  debug_inspect(emitted.contains("storageBarrier();"), content="true")
  debug_inspect(emitted.contains("textureBarrier();"), content="true")
}

///|
test "WGSL AST lowerer rejects barrier calls in value position" {
  let source =
    #|@compute @workgroup_size(1)
    #|fn main() {
    #|  let value = workgroupBarrier();
    #|}
  let message = try {
    ignore(parse_wgsl_module_to_ir(source))
    "ok"
  } catch {
    error => error.message()
  }
  debug_inspect(
    message.contains("barrier builtin has no value: workgroupBarrier"),
    content="true",
  )
}

///|
test "WGSL AST lowerer maps official IO builtins into IR bindings" {
  let source =
    #|enable subgroups;
    #|enable clip_distances;
    #|
    #|@vertex
    #|fn vertex(
    #|  @builtin(vertex_index) vertex_index: u32,
    #|  @builtin(instance_index) instance_index: u32,
    #|  @builtin(view_index) view_index: u32,
    #|  @builtin(clip_distances) clip_distances: array<f32, 1>,
    #|) -> @builtin(position) vec4f {
    #|  return vec4f(f32(vertex_index + instance_index + view_index) + clip_distances[0], 0.0, 0.0, 1.0);
    #|}
    #|
    #|@fragment
    #|fn fragment(
    #|  @builtin(position) position: vec4f,
    #|  @builtin(front_facing) front_facing: bool,
    #|  @builtin(primitive_index) primitive_index: u32,
    #|  @builtin(sample_index) sample_index: u32,
    #|  @builtin(sample_mask) sample_mask: u32,
    #|) -> @builtin(frag_depth) f32 {
    #|  return position.z + f32(primitive_index + sample_index + sample_mask) + select(0.0, 1.0, front_facing);
    #|}
    #|
    #|@compute @workgroup_size(1)
    #|fn compute(
    #|  @builtin(global_invocation_id) global_id: vec3u,
    #|  @builtin(local_invocation_id) local_id: vec3u,
    #|  @builtin(local_invocation_index) local_index: u32,
    #|  @builtin(workgroup_id) workgroup_id: vec3u,
    #|  @builtin(num_workgroups) num_workgroups: vec3u,
    #|  @builtin(num_subgroups) num_subgroups: u32,
    #|  @builtin(subgroup_id) subgroup_id: u32,
    #|  @builtin(subgroup_size) subgroup_size: u32,
    #|  @builtin(subgroup_invocation_id) subgroup_invocation_id: u32,
    #|) {
    #|  let _sum = global_id.x + local_id.x + local_index + workgroup_id.x + num_workgroups.x + num_subgroups + subgroup_id + subgroup_size + subgroup_invocation_id;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  debug_inspect(module_.entry_points.length(), content="3")
  debug_inspect(
    module_.entry_points[0].function.arguments[2].binding,
    content="Some(BuiltIn(ViewIndex))",
  )
  debug_inspect(
    module_.entry_points[0].function.arguments[3].binding,
    content="Some(BuiltIn(ClipDistances))",
  )
  debug_inspect(
    module_.entry_points[1].function.arguments[2].binding,
    content="Some(BuiltIn(PrimitiveIndex))",
  )
  debug_inspect(
    module_.entry_points[2].function.arguments[8].binding,
    content="Some(BuiltIn(SubgroupInvocationId))",
  )
}

///|
test "WGSL AST lowerer uses stable function handles for calls" {
  let source =
    #|fn helper(x: u32) -> u32 {
    #|  return x + 1u;
    #|}
    #|
    #|@compute
    #|fn main() {
    #|  helper(1u);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  debug_inspect(module_.functions.items.length(), content="2")
  debug_inspect(module_.entry_points.length(), content="1")
  debug_inspect(
    module_.entry_points[0].function.body.statements.length(),
    content="2",
  )
  match module_.entry_points[0].function.body.statements[0] {
    Call(handle, arguments, _) => {
      debug_inspect(handle.index(), content="0")
      debug_inspect(arguments.length(), content="1")
    }
    _ => abort("expected call statement")
  }
}

///|
test "WGSL AST lowerer uses callee parameter types for pointer call arguments" {
  let source =
    #|fn sum(f: ptr<function, i32>) -> i32 {
    #|  return *f;
    #|}
    #|
    #|@compute @workgroup_size(1)
    #|fn main() {
    #|  var F = array(0, 1000, 2000, 3000);
    #|  _ = sum(&F[2]);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  validate_wgsl_ir_module(module_) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  let mut address_of_count = 0
  for expression in module_.entry_points[0].function.expressions.items {
    match expression {
      AddressOf(_, _) => address_of_count += 1
      _ => ()
    }
  }
  debug_inspect(address_of_count, content="0")
  debug_inspect(emitted.contains("array<i32, 4>"), content="true")
  debug_inspect(emitted.contains("sum(&F[2])"), content="true")
}

///|
test "WGSL AST lowerer rejects unresolved expression identifiers" {
  let source =
    #|@compute
    #|fn main() {
    #|  let value: u32 = missing_name;
    #|}
  let result = try {
    ignore(parse_wgsl_module_to_ir(source))
    "ok"
  } catch {
    error => error.message()
  }
  debug_inspect(
    result,
    content="\"unknown WGSL identifier in IR lowering: missing_name in function main with args \"",
  )
}

///|
test "WGSL AST lowerer preserves compound assignment semantics in IR" {
  let source =
    #|@compute
    #|fn main() {
    #|  var value: u32 = 1u;
    #|  value += 2u;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("let _e"), content="true")
  debug_inspect(emitted.contains("value = (_e"), content="true")
  debug_inspect(emitted.contains("+ 2u);"), content="true")
}

///|
test "WGSL AST lowerer schedules pointer argument store RHS before target" {
  let source =
    #|fn f(miss_t: ptr<function, f32>, hit_t: ptr<function, f32>) {
    #|  var min_t: f32 = 1.0;
    #|  *miss_t = min_t;
    #|  *hit_t = min_t;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut first_min_t_load = -1
  let mut first_pointer_argument = -1
  for index, expression in function.expressions.items {
    match expression {
      Load(pointer) =>
        match function.expressions.items.get(pointer.index()) {
          Some(LocalVariable(local_handle)) =>
            match function.local_variables.items.get(local_handle.index()) {
              Some({ name: Some("min_t"), .. }) =>
                if first_min_t_load < 0 {
                  first_min_t_load = index
                }
              _ => ()
            }
          _ => ()
        }
      FunctionArgument(_) =>
        if first_pointer_argument < 0 {
          first_pointer_argument = index
        }
      _ => ()
    }
  }
  debug_inspect(first_min_t_load >= 0, content="true")
  debug_inspect(first_pointer_argument >= 0, content="true")
  debug_inspect(first_min_t_load < first_pointer_argument, content="true")
}

///|
test "WGSL AST lowerer emits compound field target load before store" {
  let source =
    #|struct Material {
    #|  color: vec4<f32>,
    #|}
    #|
    #|@compute
    #|fn main() {
    #|  var material: Material;
    #|  let tint = vec4<f32>(0.5);
    #|  material.color *= tint;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  let load_index = emitted.find(": vec4<f32> = material.color;")
  let store_index = emitted.find("material.color = (_e")
  let ordered = match (load_index, store_index) {
    (Some(load), Some(store)) => load < store
    _ => false
  }
  debug_inspect(ordered, content="true")
}

///|
test "WGSL AST lowerer keeps compound field target load before RHS member roots" {
  let source =
    #|struct Material {
    #|  color: vec4<f32>,
    #|}
    #|
    #|struct Bias {
    #|  scale: f32,
    #|}
    #|
    #|fn sample(scale: f32) -> vec4<f32> {
    #|  return vec4<f32>(scale);
    #|}
    #|
    #|@compute
    #|fn main() {
    #|  var material: Material;
    #|  var bias: Bias;
    #|  material.color *= sample(bias.scale);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  let target_load = emitted.find(": vec4<f32> = material.color;")
  let rhs_load = emitted.find(": f32 = bias.scale;")
  let ordered = match (target_load, rhs_load) {
    (Some(target), Some(rhs)) => target < rhs
    _ => false
  }
  debug_inspect(ordered, content="true")
}

///|
test "WGSL AST lowerer predeclares field assignment RHS local before target" {
  let source =
    #|struct Payload {
    #|  diffuse: f32,
    #|  specular: f32,
    #|}
    #|
    #|@compute
    #|fn main() {
    #|  var payload: Payload;
    #|  var specular: f32 = 1.0;
    #|  payload.specular = specular;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.entry_points[0].function
  let mut rhs_local_index = -1
  let mut target_access_index = -1
  for index, expression in function.expressions.items {
    match expression {
      LocalVariable(handle) =>
        if handle.index() == 1 && rhs_local_index < 0 {
          rhs_local_index = index
        }
      AccessIndex(base, field_index) =>
        if field_index == 1 {
          match function.expressions.items.get(base.index()) {
            Some(LocalVariable(handle)) =>
              if handle.index() == 0 && target_access_index < 0 {
                target_access_index = index
              }
            _ => ()
          }
        }
      _ => ()
    }
  }
  debug_inspect(rhs_local_index >= 0, content="true")
  debug_inspect(target_access_index >= 0, content="true")
  debug_inspect(rhs_local_index < target_access_index, content="true")
}

///|
test "WGSL AST lowerer returns imported constants without synthetic temporaries" {
  let source =
    #|const VALUE: u32 = 1u;
    #|
    #|fn f() -> u32 {
    #|  return VALUE;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("return VALUE;"), content="true")
  debug_inspect(emitted.contains("let _e0: u32 = VALUE;"), content="false")
}

///|
test "WGSL AST lowerer folds global const float arithmetic through writer policy" {
  let source =
    #|const PI = 3.1;
    #|
    #|fn f() -> f32 {
    #|  return PI * 2.0;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("return 6.2f;"), content="true")
  debug_inspect(emitted.contains("return (PI * 2f);"), content="false")
}

///|
test "WGSL AST lowerer returns casts of materialized global loads directly" {
  let source =
    #|const X: u32 = 1u;
    #|var<private> arr: array<u32, X>;
    #|
    #|fn main() -> f32 {
    #|  return f32(arr[0]);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("return f32(_e"), content="true")
  debug_inspect(emitted.contains(": f32 = f32(_e"), content="false")
}

///|
test "WGSL IR writer emits Naga-style f32 literal spelling" {
  let source =
    #|fn f() -> f32 {
    #|  return 0.3963377774;
    #|}
    #|
    #|fn g() -> f32 {
    #|  return -1.2684380046;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("return 0.39633778f;"), content="true")
  debug_inspect(emitted.contains("return -1.268438f;"), content="true")
  debug_inspect(emitted.contains("-(1.268438"), content="false")
}

///|
test "WGSL IR lowerer materializes global reads inside math arguments" {
  let source =
    #|struct Globals {
    #|  time: f32,
    #|}
    #|
    #|@group(0) @binding(0)
    #|var<uniform> globals: Globals;
    #|
    #|fn f() -> f32 {
    #|  let value = sin(globals.time * 2.0);
    #|  return value;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("let _e"), content="true")
  debug_inspect(emitted.contains("globals.time;"), content="true")
  debug_inspect(emitted.contains("sin((_e"), content="true")
  debug_inspect(emitted.contains("sin((globals.time"), content="false")
}

///|
test "WGSL AST lowerer preserves f16 literal suffixes" {
  let source =
    #|enable f16;
    #|const x: f16 = 1h;
    #|const y: f16 = 1.5h;
    #|const z: f16 = 2.0;
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("const x: f16 = 1h;"), content="true")
  debug_inspect(emitted.contains("const y: f16 = 1.5h;"), content="true")
  debug_inspect(emitted.contains("const z: f16 = 2h;"), content="true")
}

///|
test "WGSL AST lowerer materializes global binding accesses inside return constructors" {
  let source =
    #|const SIZE: u32 = 1u;
    #|var<private> values: array<u32, SIZE>;
    #|
    #|fn f() -> f32 {
    #|  return f32(values[0]);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains(": u32 = values[0];"), content="true")
  debug_inspect(emitted.contains(": f32 = f32(_e"), content="false")
  debug_inspect(emitted.contains("return f32(_e"), content="true")
  debug_inspect(emitted.contains("return _e"), content="false")
}

///|
test "WGSL AST lowerer indexes addressable bindings without preloading base arrays" {
  let source =
    #|var<private> values: array<u32, 1>;
    #|
    #|fn f() -> f32 {
    #|  return f32(values[0]);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains(": u32 = values[0];") &&
    !emitted.contains(": f32 = f32(_e") &&
    emitted.contains("return f32(_e"),
    content="true",
  )
}

///|
test "WGSL AST lowerer materializes direct global binding returns" {
  let source =
    #|var<private> value: f32 = 0f;
    #|
    #|fn f() -> f32 {
    #|  return value;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("let _e1: f32 = value;"), content="true")
  debug_inspect(emitted.contains("return _e1;"), content="true")
}

///|
test "WGSL AST lowerer materializes composite local loads before return calls" {
  let source =
    #|struct Frag {
    #|  fragment: f32,
    #|}
    #|
    #|fn fragment(f: Frag) -> f32 {
    #|  return f.fragment * 2.0;
    #|}
    #|
    #|fn main() -> f32 {
    #|  var f: Frag;
    #|  f.fragment = 3.0;
    #|  return fragment(f);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains(": Frag = f_1;"), content="true")
  debug_inspect(emitted.contains(": f32 = fragment(_e"), content="true")
  debug_inspect(emitted.contains("return _e"), content="true")
}

///|
test "WGSL AST lowerer concretizes abstract local var storage types" {
  let source =
    #|fn f() -> f32 {
    #|  var x = 0.0;
    #|  x = 1.0;
    #|  return x;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("var x: f32 = 0f;"), content="true")
  debug_inspect(emitted.contains("x = 1f;"), content="true")
  debug_inspect(emitted.contains(": f32 = x;"), content="true")
  debug_inspect(emitted.contains("return _e"), content="true")
}

///|
test "WGSL AST lowerer converts abstract numeric operands toward concrete floats" {
  let source =
    #|override kTextureBaseSize: f32;
    #|override kViewportSize: f32;
    #|
    #|fn f(flange: f32) -> vec2f {
    #|  let radius = (1 + 2 * flange) * kTextureBaseSize / kViewportSize;
    #|  var positions = array(
    #|    vec2(-radius, -radius), vec2(-radius, radius), vec2(radius, -radius),
    #|    vec2(radius, -radius), vec2(-radius, radius), vec2(radius, radius),
    #|  );
    #|  return positions[0];
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  validate_wgsl_ir_module(module_) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("var positions: array<vec2<f32>, 6>"),
    content="true",
  )
}

///|
test "WGSL AST lowerer supports pointer dereference member lvalues" {
  let source =
    #|struct PbrInput {
    #|  value: u32,
    #|}
    #|
    #|fn apply_decals(pbr_input: ptr<function, PbrInput>) {
    #|  (*pbr_input).value = (*pbr_input).value + 1u;
    #|}
    #|
    #|@fragment
    #|fn fragment() -> @location(0) u32 {
    #|  var pbr_input: PbrInput;
    #|  apply_decals(&pbr_input);
    #|  return pbr_input.value;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("(*pbr_input_1).value ="), content="true")
  debug_inspect(emitted.contains("+ 1u);"), content="true")
  debug_inspect(emitted.contains("apply_decals(&pbr_input);"), content="true")
}

///|
test "WGSL AST lowerer materializes mutable member reads before stores" {
  let source =
    #|struct S {
    #|  x: f32,
    #|  y: f32,
    #|}
    #|
    #|fn f(v: f32) -> f32 {
    #|  var r: S;
    #|  r.x = r.x - max(v, 1.0);
    #|  return r.x;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains(": f32 = r.x;") &&
    emitted.contains("r.x = (_e") &&
    emitted.contains(" - max(v, 1f));"),
    content="true",
  )
}

///|
test "WGSL AST lowerer materializes compound assignment storage RHS reads" {
  let source =
    #|struct Args {
    #|  x: u32,
    #|}
    #|
    #|@group(0) @binding(0) var<storage, read_write> counters: array<u32, 2>;
    #|@group(0) @binding(1) var<storage, read_write> args: Args;
    #|
    #|@compute @workgroup_size(1)
    #|fn main() {
    #|  counters[0] += args.x;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains(": u32 = counters[0];") &&
    emitted.contains(": u32 = args.x;") &&
    emitted.contains("counters[0] = (_e") &&
    emitted.contains(" + _e"),
    content="true",
  )
  debug_inspect(
    emitted.contains("counters[0] = (_e3 + args.x);"),
    content="false",
  )
}

///|
test "WGSL AST lowerer respects nested lexical shadowing" {
  let source =
    #|@group(0) @binding(0) var<storage, read_write> buffer: array<u32, 4>;
    #|
    #|fn write_shadow(x: u32) {
    #|  {
    #|    var x = 30u;
    #|    let y = 40u;
    #|    buffer[0] = x;
    #|    buffer[1] = y;
    #|  }
    #|  buffer[2] = x;
    #|}
    #|
    #|@compute @workgroup_size(1)
    #|fn main() {
    #|  let y = 10u;
    #|  {
    #|    let y = 20u;
    #|    buffer[3] = y;
    #|  }
    #|  write_shadow(y);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("var x_1: u32 = 30u;\n"), content="true")
  debug_inspect(emitted.contains("x_1 = 30u;\n"), content="false")
  debug_inspect(emitted.contains("buffer[0] = _e"), content="true")
  debug_inspect(emitted.contains("buffer[2] = x;"), content="true")
  debug_inspect(emitted.contains("buffer[3] = 20u;"), content="true")
  debug_inspect(emitted.contains("write_shadow(10u);"), content="true")
}

///|
test "WGSL AST lowerer preserves continuing break-if conditions" {
  let source =
    #|@compute @workgroup_size(1)
    #|fn main() {
    #|  var counter = 0u;
    #|  loop {
    #|    continuing {
    #|      counter += 1u;
    #|      break if counter == 2u;
    #|    }
    #|  }
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("break if (counter == 2u);"), content="true")
}

///|
test "WGSL AST lowerer expands statement function call arguments" {
  let source =
    #|@group(0) @binding(0) var<storage, read_write> output: array<u32, 4>;
    #|
    #|fn write_values(a: u32, b: u32, c: u32, d: u32) {
    #|  output[0] = a;
    #|  output[1] = b;
    #|  output[2] = c;
    #|  output[3] = d;
    #|}
    #|
    #|@compute @workgroup_size(1)
    #|fn main() {
    #|  let base = 1u;
    #|  write_values(base, 2u, base + 2u, 4u);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("write_values(1u, 2u, (1u + 2u), 4u);"),
    content="true",
  )
}

///|
test "WGSL IR lowerer materializes function calls before assignment stores" {
  let source =
    #|struct Item {
    #|  value: vec4<f32>,
    #|}
    #|
    #|fn make_item() -> Item {
    #|  return Item(vec4<f32>(1f));
    #|}
    #|
    #|fn make() -> Item {
    #|  var item: Item;
    #|  item = make_item();
    #|  return item;
    #|}
  let emitted = roundtrip_wgsl_source_via_ir_with_generated_imports(source, []) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("let _e"), content="true")
  debug_inspect(emitted.contains("make_item();\n    item = _e"), content="true")
  debug_inspect(emitted.contains("item = make_item();"), content="false")
}

///|
test "WGSL AST lowerer reuses local pointer expressions across branch scopes" {
  let source =
    #|fn choose_a() -> f32 { return 1f; }
    #|fn choose_b() -> f32 { return 2f; }
    #|fn choose_c() -> f32 { return 3f; }
    #|
    #|fn choose(flag_a: bool, flag_b: bool) -> f32 {
    #|  var value: f32;
    #|  if flag_a {
    #|    value = choose_a();
    #|  } else if flag_b {
    #|    value = choose_b();
    #|  } else {
    #|    value = choose_c();
    #|  }
    #|  return value;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let mut pointer_expression_count = 0
  for function in module_.functions.items {
    if function.name == Some("choose") {
      for expression in function.expressions.items {
        match expression {
          LocalVariable(handle) =>
            if handle.index() == 0 {
              pointer_expression_count += 1
            }
          _ => ()
        }
      }
    }
  }
  debug_inspect(pointer_expression_count, content="1")
}

///|
test "WGSL IR lowerer materializes user function call let values" {
  let source =
    #|fn value(x: f32) -> f32 {
    #|  return x;
    #|}
    #|
    #|fn f(a: f32, b: f32) -> f32 {
    #|  let direct = value(a);
    #|  let nested = select(0f, 1f, value(b) > direct);
    #|  return direct + nested;
    #|}
  let emitted = roundtrip_wgsl_source_via_ir_with_generated_imports(source, []) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("let direct"), content="false")
  debug_inspect(emitted.contains("value(a);"), content="true")
  debug_inspect(emitted.contains("value(b);"), content="true")
  debug_inspect(emitted.contains("let _e"), content="true")
  debug_inspect(emitted.contains("value(b) >"), content="false")
}

///|
test "WGSL AST lowerer preserves address space through local pointer lvalues" {
  let source =
    #|struct Cascade {
    #|  value: f32,
    #|}
    #|struct Light {
    #|  cascades: array<Cascade, 4>,
    #|}
    #|@group(0) @binding(0) var<uniform> lights: array<Light, 1>;
    #|
    #|fn f() -> f32 {
    #|  let light: ptr<uniform, Light> = &lights[0];
    #|  let cascade = &(*light).cascades[0];
    #|  return cascade.value;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains(": ptr<uniform, Cascade>"), content="true")
}

///|
test "WGSL IR emitter uses explicit pointer dereference for member access" {
  let source =
    #|struct S {
    #|  value: u32,
    #|}
    #|fn read_s(p: ptr<function, S>) -> u32 {
    #|  return (*p).value;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("let _e2: u32 = (*p).value;"), content="true")
  debug_inspect(emitted.contains("return _e2;"), content="true")
  debug_inspect(emitted.contains("return p.value;"), content="false")
}

///|
test "WGSL AST lowerer infers scalar-vector binary local types" {
  let source =
    #|fn f(perceptual_roughness: f32, NdotV: f32) -> vec2<f32> {
    #|  let c0 = vec4<f32>(-1.0, -0.0275, -0.572, 0.022);
    #|  let c1 = vec4<f32>(1.0, 0.0425, 1.04, -0.04);
    #|  let r = perceptual_roughness * c0 + c1;
    #|  let a004 = min(r.x * r.x, exp2(-9.28 * NdotV)) * r.x + r.y;
    #|  let f_ab_epsilon = 0.00005;
    #|  return max(vec2<f32>(-1.04, 1.04) * a004 + r.zw, vec2<f32>(f_ab_epsilon));
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains(": vec4<f32>"), content="true")
  debug_inspect(emitted.contains(": f32"), content="true")
  debug_inspect(emitted.contains(".zw"), content="true")
}

///|
test "WGSL AST lowerer splats scalar operands for vector binary expressions" {
  let source =
    #|fn f(v: vec3<f32>, s: f32) -> vec3<f32> {
    #|  let a = v - s;
    #|  let b = s + v;
    #|  let c = v / s;
    #|  let d = v * s;
    #|  return a + b + c + d;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("let a: vec3<f32> = (v - vec3(s));"),
    content="true",
  )
  debug_inspect(
    emitted.contains("let b: vec3<f32> = (vec3(s) + v);"),
    content="true",
  )
  debug_inspect(
    emitted.contains("let c: vec3<f32> = (v / vec3(s));"),
    content="true",
  )
  debug_inspect(emitted.contains("let d: vec3<f32> = (v * s);"), content="true")
}

///|
test "WGSL AST lowerer infers scalar result math builtin local types" {
  let source =
    #|fn f(v1: vec3<f32>, v2: vec3<f32>) -> f32 {
    #|  let x = dot(v1, v2);
    #|  return x;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains(": f32 = dot(v1_, v2_);"), content="true")
}

///|
test "WGSL AST lowerer infers matrix-vector multiply local types" {
  let source =
    #|fn f(m: mat4x4<f32>, p: vec4<f32>) -> vec3<f32> {
    #|  let clip = m * p;
    #|  return clip.xyz;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains(": vec4<f32>"), content="true")
  debug_inspect(emitted.contains(".xyz"), content="true")
}

///|
test "WGSL AST lowerer infers matrix index local types" {
  let source =
    #|fn f(TBN: mat3x3<f32>) -> vec3<f32> {
    #|  var T = TBN[0];
    #|  return T;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("var T: vec3<f32>;"), content="true")
  debug_inspect(emitted.contains("T = TBN[0];"), content="true")
  debug_inspect(emitted.contains("var T: vec3<f32> = TBN[0];"), content="false")
}

///|
test "WGSL AST lowerer splits runtime var initializers like Writer" {
  let source =
    #|fn f(radius: vec4<f32>) -> vec4<f32> {
    #|  var r = radius;
    #|  return r;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("var r: vec4<f32>;"), content="true")
  debug_inspect(emitted.contains("r = radius;"), content="true")
  debug_inspect(emitted.contains("var r: vec4<f32> = radius;"), content="false")
}

///|
test "WGSL AST lowerer keeps struct const constructor var initializer" {
  let source =
    #|struct DistanceWithPenetration {
    #|  distance: f32,
    #|  valid: bool,
    #|  penetration: f32,
    #|}
    #|
    #|fn f() -> DistanceWithPenetration {
    #|  var min_d = DistanceWithPenetration(0.0, false, 0.0);
    #|  return min_d;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  match function.expressions.items[0] {
    Literal(_) => ()
    _ => abort("expected first struct constructor literal")
  }
  match function.expressions.items[1] {
    Literal(_) => ()
    _ => abort("expected bool struct constructor literal")
  }
  match function.expressions.items[2] {
    Compose(_, components) => {
      debug_inspect(components[0].index(), content="0")
      debug_inspect(components[1].index(), content="1")
      debug_inspect(components[2].index(), content="0")
    }
    _ => abort("expected struct constructor compose to reuse duplicate literal")
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains(
      "var min_d: DistanceWithPenetration = DistanceWithPenetration(0f, false, 0f);",
    ),
    content="true",
  )
  debug_inspect(
    emitted.contains("var min_d: DistanceWithPenetration;\n"),
    content="false",
  )
  debug_inspect(
    emitted.contains("min_d = DistanceWithPenetration"),
    content="false",
  )
}

///|
test "WGSL AST lowerer reuses nested vector splat literals in struct var initializer" {
  let source =
    #|struct DepthRayMarchResult {
    #|  hit: bool,
    #|  hit_t: f32,
    #|  hit_uv: vec2<f32>,
    #|  hit_penetration: f32,
    #|  hit_penetration_frac: f32,
    #|}
    #|
    #|fn f() -> DepthRayMarchResult {
    #|  var res = DepthRayMarchResult(false, 0.0, vec2(0.0), 0.0, 0.0);
    #|  return res;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  match function.expressions.items[0] {
    Literal(Bool(false)) => ()
    _ => abort("expected first struct constructor bool literal")
  }
  match function.expressions.items[1] {
    Literal(_) => ()
    _ => abort("expected first struct constructor numeric literal")
  }
  match function.expressions.items[2] {
    Splat(Bi, component) => debug_inspect(component.index(), content="1")
    _ => abort("expected nested vector splat to reuse f32 literal")
  }
  match function.expressions.items[3] {
    Compose(_, components) => {
      debug_inspect(components[0].index(), content="0")
      debug_inspect(components[1].index(), content="1")
      debug_inspect(components[2].index(), content="2")
      debug_inspect(components[3].index(), content="1")
      debug_inspect(components[4].index(), content="1")
    }
    _ => abort("expected struct compose to reuse nested splat and literals")
  }
  match function.local_variables.items[0].init {
    Some(handle) => debug_inspect(handle.index(), content="3")
    None => abort("expected local initializer")
  }
}

///|
test "WGSL AST lowerer contextualizes abstract int struct constructor fields" {
  let source =
    #|struct IteratorState {
    #|  first: i32,
    #|  second: i32,
    #|  uv: vec2<f32>,
    #|  tag: u32,
    #|}
    #|
    #|fn make_state() -> IteratorState {
    #|  return IteratorState(-1, -1, vec2(0.0), 0u);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("-1f"), content="false")
  debug_inspect(emitted.contains("IteratorState(-1i, -1i"), content="true")
  match function.expressions.items[0] {
    Literal(I32(value)) => debug_inspect(value, content="-1")
    _ => abort("expected first negative struct field to be i32")
  }
}

///|
test "WGSL AST lowerer restores speculative local constant aliases after rewind" {
  let source =
    #|fn probe(frame: u32) -> vec2<f32> {
    #|  let num_spirals: i32 = i32(ceil((f32(8i) / 8f)));
    #|  let current_spiral: i32 = 0i;
    #|  let angle = (f32(current_spiral) / f32(num_spirals));
    #|  return vec2<f32>(sin(angle), cos(angle));
    #|}
  let emitted = roundtrip_wgsl_source_via_ir(source) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("fn probe"), content="true")
}

///|
test "WGSL AST lowerer invalidates shared lazy aliases after child-scope rewinds" {
  let source =
    #|fn noise(_: vec2<f32>, _: u32) -> f32 {
    #|  return 0.25f;
    #|}
    #|
    #|fn probe(offset_position: vec2<f32>, frag_coord: vec3<f32>, view_z: f32, roughness: f32) -> vec2<f32> {
    #|  var i: i32 = 0i;
    #|  var spiral_offset: vec2<f32>;
    #|  let aspect: f32 = 1f;
    #|  let blur_intensity: f32 = ((roughness * roughness) / view_z);
    #|  let num_spirals: i32 = i32(ceil((f32(8i) / 8f)));
    #|  let jitter: f32 = noise(frag_coord.xy, 0u);
    #|  loop {
    #|    if i < 8i {
    #|    } else {
    #|      break;
    #|    }
    #|    {
    #|      let current_spiral: i32 = (i >> 3u);
    #|      let angle: f32 = ((jitter + (f32(current_spiral) / f32(num_spirals))) * 2f);
    #|      let m: vec2<f32> = vec2<f32>(sin(angle), cos(angle));
    #|      let rotation_matrix: mat2x2<f32> = mat2x2<f32>(vec2<f32>(m.y, -(m.x)), vec2<f32>(m.x, m.y));
    #|      spiral_offset = vec2<f32>(1f, 0f);
    #|      spiral_offset = (spiral_offset * (1f - ((0.5f * f32((current_spiral + 1i))) / f32(num_spirals))));
    #|      let rotated_spiral_offset: vec2<f32> = ((rotation_matrix * spiral_offset) * vec2<f32>(1f, aspect));
    #|      return (offset_position + (rotated_spiral_offset * blur_intensity));
    #|    }
    #|    continuing {
    #|      i = (i + 1i);
    #|    }
    #|  }
    #|  return offset_position;
    #|}
  let emitted = roundtrip_wgsl_source_via_ir(source) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("fn probe"), content="true")
}

///|
test "WGSL AST lowerer contextualizes array constructor elements with element type" {
  let source =
    #|@vertex
    #|fn vs_main(@builtin(vertex_index) index: u32) -> @builtin(position) vec4<f32> {
    #|  var vertices = array<vec4<f32>, 3>(
    #|    vec4<f32>(0.0, 1.0, 0.0, 1.0),
    #|    vec4<f32>(-1.0, -1.0, 0.0, 1.0),
    #|    vec4<f32>(1.0, -1.0, 0.0, 1.0)
    #|  );
    #|  return vertices[index];
    #|}
  let emitted = roundtrip_wgsl_source_via_ir(source) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("var vertices: array<vec4<f32>, 3>"),
    content="true",
  )
  debug_inspect(emitted.contains("vertices[index]"), content="true")
}

///|
test "WGSL AST lowerer contextualizes matrix constructor columns with vector type" {
  let source =
    #|fn make_matrix() -> mat3x2<f32> {
    #|  var value = mat3x2<f32>(
    #|    vec2<f32>(1.0),
    #|    vec2<f32>(2.0),
    #|    vec2<f32>(3.0)
    #|  );
    #|  return value;
    #|}
  let emitted = roundtrip_wgsl_source_via_ir(source) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("var value: mat3x2<f32>"), content="true")
  debug_inspect(emitted.contains("vec2(1f)"), content="true")
}

///|
test "WGSL AST lowerer preserves source let scalar constructor conversions" {
  let source =
    #|fn f() -> f32 {
    #|  let min_px_per_step = 1u;
    #|  return f32(min_px_per_step);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  match function.expressions.items[0] {
    Literal(U32(1)) => ()
    _ => abort("expected source let unsigned literal")
  }
  match function.expressions.items[1] {
    As(argument, Float, Some(4)) => debug_inspect(argument.index(), content="0")
    _ => abort("expected source let scalar constructor conversion")
  }
}

///|
test "WGSL AST lowerer keeps large abstract integer vector constants until u32 context" {
  let source =
    #|var<private> rnd: vec3u;
    #|
    #|fn init_rand(invocation_id: vec3u) {
    #|  const A = vec3(1741651 * 1009,
    #|                 140893  * 1609 * 13,
    #|                 6521    * 983  * 7 * 2);
    #|  rnd = invocation_id * A;
    #|}
  let emitted = roundtrip_wgsl_source_via_ir(source) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("2947058881u"), content="true")
  debug_inspect(emitted.contains("-1347908415"), content="false")
}

///|
test "WGSL AST lowerer infers scoped vector constructors with mixed composite arguments" {
  let source =
    #|fn f(cb: vec3<f32>, cs: vec3<f32>, ab: f32, as_: f32) -> vec4<f32> {
    #|  return min(vec4(1.0), vec4(as_ * cs + ab * cb, as_ + ab));
    #|}
  let emitted = roundtrip_wgsl_source_via_ir(source) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("min(vec4(1f), vec4<f32>"), content="true")
}

///|
test "WGSL AST lowerer preserves explicit same-type scalar constructors as casts" {
  let source =
    #|fn probe(value: u32) -> u32 {
    #|  return u32(value);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  match function.expressions.items[1] {
    As(argument, Uint, Some(4)) => debug_inspect(argument.index(), content="0")
    _ => abort("expected explicit same-type scalar constructor cast")
  }
}

///|
test "WGSL AST lowerer materializes function-call if conditions" {
  let source =
    #|fn enabled(flags: u32, mask: u32) -> bool {
    #|  return (flags & mask) != 0u;
    #|}
    #|
    #|fn f(flags: u32) -> u32 {
    #|  if enabled(flags, 1u) {
    #|    return 1u;
    #|  }
    #|  return 0u;
    #|}
  let emitted = roundtrip_wgsl_source_via_ir(source) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("let _e") && emitted.contains(": bool = enabled("),
    content="true",
  )
  debug_inspect(emitted.contains("if enabled("), content="false")
}

///|
test "WGSL AST lowerer materializes function-call else-if conditions" {
  let source =
    #|fn enabled(flags: u32, mask: u32) -> bool {
    #|  return (flags & mask) != 0u;
    #|}
    #|
    #|fn f(flags: u32) -> u32 {
    #|  if enabled(flags, 1u) {
    #|    return 1u;
    #|  } else if enabled(flags, 2u) {
    #|    return 2u;
    #|  }
    #|  return 0u;
    #|}
  let emitted = roundtrip_wgsl_source_via_ir(source) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("let _e") && emitted.contains(": bool = enabled("),
    content="true",
  )
  debug_inspect(emitted.contains("if enabled("), content="false")
}

///|
test "WGSL AST lowerer materializes function-call while conditions inside loop" {
  let source =
    #|fn enabled(flags: u32, mask: u32) -> bool {
    #|  return (flags & mask) != 0u;
    #|}
    #|
    #|fn f(flags: u32) -> u32 {
    #|  var value = flags;
    #|  while enabled(value, 1u) {
    #|    value = value - 1u;
    #|  }
    #|  return value;
    #|}
  let emitted = roundtrip_wgsl_source_via_ir(source) catch {
    error => abort(error.message())
  }
  let loop_offset = emitted.find("loop {")
  let let_offset = emitted.find("let _e")
  debug_inspect(
    match (loop_offset, let_offset) {
      (Some(loop_pos), Some(let_pos)) => let_pos > loop_pos
      _ => false
    },
    content="true",
  )
  debug_inspect(emitted.contains("while enabled("), content="false")
}

///|
test "WGSL AST lowerer materializes short-circuit if conditions" {
  let source =
    #|fn f(value: f32) -> u32 {
    #|  if 0.0 <= value && value < 1.0 {
    #|    return 1u;
    #|  }
    #|  return 0u;
    #|}
  let emitted = roundtrip_wgsl_source_via_ir(source) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("var local: bool;"), content="true")
  debug_inspect(emitted.contains("if ((0f <= value) &&"), content="false")
}

///|
test "WGSL AST lowerer materializes short-circuit for conditions from AST nodes" {
  let source =
    #|fn probe(limit: u32) {
    #|  var values: array<u32, 4>;
    #|  var i = limit;
    #|  for (; i > 0u && values[i - 1u] > 0u; i -= 1u) {
    #|    values[i] = values[i - 1u];
    #|  }
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  for expression in function.expressions.items {
    match expression {
      Binary(LogicalAnd, _, _) =>
        abort("for short-circuit condition must not keep a parent LogicalAnd")
      _ => ()
    }
  }
}

///|
test "WGSL AST lowerer folds typed integer const subexpressions in function arena" {
  let source =
    #|const LIMIT: u32 = 8u;
    #|
    #|fn probe(i: u32) -> bool {
    #|  return i < LIMIT - 1u;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut saw_seven_u32 = false
  for expression in function.expressions.items {
    match expression {
      Literal(U32(value)) if value == 7U => saw_seven_u32 = true
      Constant(_) =>
        abort("folded integer const subexpression must not keep Constant")
      _ => ()
    }
  }
  debug_inspect(saw_seven_u32, content="true")
}

///|
test "WGSL AST lowerer allocates trailing source-let literals before mutable local loads" {
  let source =
    #|fn probe(input: vec3<f32>) -> vec3<f32> {
    #|  var color = input;
    #|  let scale = 0.97;
    #|  return color * scale;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let last = function.expressions.items.length() - 1
  match function.expressions.items[last - 2] {
    Literal(F32(value)) =>
      debug_inspect(value.to_double() > 0.969, content="true")
    Literal(AbstractFloat(value)) =>
      debug_inspect(value > 0.969, content="true")
    _ => abort("expected source-let literal before mutable local load")
  }
  match function.expressions.items[last - 1] {
    Load(_) => ()
    _ => abort("expected mutable local load after source-let literal")
  }
  match function.expressions.items[last] {
    Binary(Multiply, left, right) => {
      debug_inspect(left.index(), content="\{last - 1}")
      debug_inspect(right.index(), content="\{last - 2}")
    }
    _ => abort("expected binary to preserve source operand semantics")
  }
}

///|
test "WGSL AST lowerer schedules homogeneous math const leaves before later function arguments" {
  let source =
    #|fn probe(color: vec3<f32>, minimum_ev: f32, maximum_ev: f32) -> vec3<f32> {
    #|  let mid = 0.18;
    #|  var normalized_color = max(vec3(0.0), color);
    #|  normalized_color = clamp(
    #|    log2(normalized_color / mid),
    #|    vec3(minimum_ev),
    #|    vec3(maximum_ev)
    #|  );
    #|  return normalized_color;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut zero_literal = -1
  let mut color_argument = -1
  let mut max_splat = -1
  let mut max_call = -1
  let mut mid_literal = -1
  let mut minimum_argument = -1
  let mut maximum_argument = -1
  let mut normalized_load = -1
  let mut mid_splat = -1
  let mut log2_call = -1
  let mut minimum_splat = -1
  let mut maximum_splat = -1
  let mut clamp_call = -1
  for expression_index, expression in function.expressions.items {
    match expression {
      Literal(AbstractFloat(value)) =>
        if value < 0.001 && zero_literal == -1 {
          zero_literal = expression_index
        } else if value > 0.179 && value < 0.181 && mid_literal == -1 {
          mid_literal = expression_index
        }
      Literal(F32(value)) => {
        let value = value.to_double()
        if value < 0.001 && zero_literal == -1 {
          zero_literal = expression_index
        } else if value > 0.179 && value < 0.181 && mid_literal == -1 {
          mid_literal = expression_index
        }
      }
      FunctionArgument(0) if color_argument == -1 =>
        color_argument = expression_index
      FunctionArgument(1) if minimum_argument == -1 =>
        minimum_argument = expression_index
      FunctionArgument(2) if maximum_argument == -1 =>
        maximum_argument = expression_index
      Splat(_, inner) if inner.index() == zero_literal && max_splat == -1 =>
        max_splat = expression_index
      Splat(_, inner) if inner.index() == mid_literal && mid_splat == -1 =>
        mid_splat = expression_index
      Splat(_, inner) if inner.index() == minimum_argument &&
        minimum_splat == -1 => minimum_splat = expression_index
      Splat(_, inner) if inner.index() == maximum_argument &&
        maximum_splat == -1 => maximum_splat = expression_index
      Math(Max, left, Some(right), None, None) if max_call == -1 => {
        max_call = expression_index
        debug_inspect(left.index(), content="\{max_splat}")
        debug_inspect(right.index(), content="\{color_argument}")
      }
      Load(_) if maximum_argument >= 0 && normalized_load == -1 =>
        normalized_load = expression_index
      Math(Log2, _, None, None, None) if log2_call == -1 =>
        log2_call = expression_index
      Math(Clamp, value, Some(low), Some(high), None) if clamp_call == -1 => {
        clamp_call = expression_index
        debug_inspect(value.index(), content="\{log2_call}")
        debug_inspect(low.index(), content="\{minimum_splat}")
        debug_inspect(high.index(), content="\{maximum_splat}")
      }
      _ => ()
    }
  }
  debug_inspect(zero_literal < color_argument, content="true")
  debug_inspect(color_argument < max_splat, content="true")
  debug_inspect(max_splat < max_call, content="true")
  debug_inspect(mid_literal < minimum_argument, content="true")
  debug_inspect(minimum_argument < maximum_argument, content="true")
  debug_inspect(maximum_argument < normalized_load, content="true")
  debug_inspect(normalized_load < mid_splat, content="true")
  debug_inspect(mid_splat < log2_call, content="true")
  debug_inspect(log2_call < minimum_splat, content="true")
  debug_inspect(minimum_splat < maximum_splat, content="true")
  debug_inspect(maximum_splat < clamp_call, content="true")
}

///|
test "WGSL AST lowerer schedules mutable second math argument before foldable first splat" {
  let source =
    #|fn probe(color: vec3<f32>) -> vec3<f32> {
    #|  var open_color = color;
    #|  open_color = pow(vec3(2.0), open_color);
    #|  return open_color;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut open_load = -1
  let mut two_literal = -1
  let mut two_splat = -1
  let mut pow_call = -1
  for expression_index, expression in function.expressions.items {
    match expression {
      Load(_) if open_load == -1 => open_load = expression_index
      Literal(AbstractFloat(value)) if value > 1.99 &&
        value < 2.01 &&
        two_literal == -1 => two_literal = expression_index
      Literal(F32(value)) if value.to_double() > 1.99 &&
        value.to_double() < 2.01 &&
        two_literal == -1 => two_literal = expression_index
      Splat(_, inner) if inner.index() == two_literal && two_splat == -1 =>
        two_splat = expression_index
      Math(Pow, left, Some(right), None, None) if pow_call == -1 => {
        pow_call = expression_index
        debug_inspect(left.index(), content="\{two_splat}")
        debug_inspect(right.index(), content="\{open_load}")
      }
      _ => ()
    }
  }
  debug_inspect(open_load < two_literal, content="true")
  debug_inspect(two_literal < two_splat, content="true")
  debug_inspect(two_splat < pow_call, content="true")
}

///|
test "WGSL AST lowerer lazily materializes return short-circuit branches in Naga order" {
  let source =
    #|const BORDER_LEFT: u32 = 256u;
    #|const BORDER_TOP: u32 = 512u;
    #|const BORDER_RIGHT: u32 = 1024u;
    #|const BORDER_BOTTOM: u32 = 2048u;
    #|const BORDER_ANY: u32 = BORDER_LEFT + BORDER_TOP + BORDER_RIGHT + BORDER_BOTTOM;
    #|
    #|fn enabled(flags: u32, mask: u32) -> bool {
    #|  return (flags & mask) == mask;
    #|}
    #|
    #|fn nearest_border_active(point_vs_mid: vec2<f32>, size: vec2<f32>, width: vec4<f32>, flags: u32) -> bool {
    #|  if ((flags & BORDER_ANY) == BORDER_ANY) {
    #|    return true;
    #|  }
    #|  let point = clamp(point_vs_mid + size * 0.49999, vec2(0.0), size);
    #|  let left = point.x / width.x;
    #|  let top = point.y / width.y;
    #|  let right = (size.x - point.x) / width.z;
    #|  let bottom = (size.y - point.y) / width.w;
    #|  let min_dist = min(min(left, top), min(right, bottom));
    #|  return (enabled(flags, BORDER_LEFT) && min_dist == left) ||
    #|    (enabled(flags, BORDER_TOP) && min_dist == top) ||
    #|    (enabled(flags, BORDER_RIGHT) && min_dist == right) ||
    #|    (enabled(flags, BORDER_BOTTOM) && min_dist == bottom);
    #|}
  let emitted = roundtrip_wgsl_source_via_ir(source) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("if _e43 {\n            local_2 = (min_dist == top);"),
    content="true",
  )
  debug_inspect(
    emitted.contains("if _e55 {\n            local_4 = (min_dist == right);"),
    content="true",
  )
  debug_inspect(emitted.contains("return local_5;"), content="false")
  debug_inspect(
    emitted.contains("let _e76: bool = local_5;\n    return _e76;"),
    content="true",
  )
}

///|
test "WGSL AST lowerer preserves nested var const initializer execution site" {
  let source =
    #|fn nested_var_init(count: u32) -> f32 {
    #|  var total: f32 = 0.0;
    #|  for (var i: u32 = 0u; i < count; i = i + 1u) {
    #|    var shadow: f32 = 1.0;
    #|    if i == 0u {
    #|      shadow = 0.5;
    #|    }
    #|    total = total + shadow;
    #|  }
    #|  return total;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("var shadow: f32;\n"), content="true")
  debug_inspect(emitted.contains("var shadow: f32 = 1f;"), content="false")
  debug_inspect(emitted.contains("shadow = 1f;\n"), content="true")
}

///|
test "WGSL AST lowerer schedules runtime const var store pointer before initializer" {
  let source =
    #|fn runtime_const_var_store_pointer_order(count: u32) -> f32 {
    #|  var total: f32 = 0.0;
    #|  for (var i: u32 = 0u; i < count; i = i + 1u) {
    #|    var shadow: f32 = 1.0;
    #|    total = total + shadow;
    #|  }
    #|  return total;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut shadow_local = -1
  for index, local_var in function.local_variables.items {
    match local_var.name {
      Some("shadow") => shadow_local = index
      _ => ()
    }
  }
  let mut pointer_index = -1
  let mut literal_index = -1
  for index, expression in function.expressions.items {
    match expression {
      LocalVariable(handle) =>
        if handle.index() == shadow_local && pointer_index == -1 {
          pointer_index = index
        }
      Literal(AbstractFloat(value)) =>
        if value == 1.0 && pointer_index != -1 && literal_index == -1 {
          literal_index = index
        }
      _ => ()
    }
  }
  debug_inspect(shadow_local >= 0, content="true")
  debug_inspect(pointer_index >= 0, content="true")
  debug_inspect(literal_index > pointer_index, content="true")
}

///|
test "WGSL AST lowerer builds global member base before mutable dynamic index load" {
  let source =
    #|struct Light {
    #|  flags: u32,
    #|}
    #|
    #|struct Lights {
    #|  directional_lights: array<Light, 4>,
    #|}
    #|
    #|@group(0) @binding(0)
    #|var<uniform> lights: Lights;
    #|
    #|fn dynamic_uniform_index_order(count: u32) -> u32 {
    #|  var total: u32 = 0u;
    #|  for (var i: u32 = 0u; i < count; i = i + 1u) {
    #|    total = total + lights.directional_lights[i].flags;
    #|  }
    #|  return total;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut loop_index_local = -1
  for local_index, local_var in function.local_variables.items {
    match local_var.name {
      Some("i") => loop_index_local = local_index
      _ => ()
    }
  }
  let mut member_base_index = -1
  let mut index_load_index = -1
  let mut dynamic_access_index = -1
  for expression_index, expression in function.expressions.items {
    match expression {
      Access(base, index) =>
        match function.expressions.items.get(base.index()) {
          Some(AccessIndex(root, _)) =>
            match function.expressions.items.get(root.index()) {
              Some(GlobalVariable(_)) =>
                match function.expressions.items.get(index.index()) {
                  Some(Load(pointer)) =>
                    match function.expressions.items.get(pointer.index()) {
                      Some(LocalVariable(handle)) =>
                        if handle.index() == loop_index_local &&
                          dynamic_access_index == -1 {
                          member_base_index = base.index()
                          index_load_index = index.index()
                          dynamic_access_index = expression_index
                        }
                      _ => ()
                    }
                  _ => ()
                }
              _ => ()
            }
          _ => ()
        }
      _ => ()
    }
  }
  debug_inspect(loop_index_local >= 0, content="true")
  debug_inspect(member_base_index >= 0, content="true")
  debug_inspect(index_load_index > member_base_index, content="true")
  debug_inspect(dynamic_access_index > index_load_index, content="true")
}

///|
test "WGSL AST lowerer does not materialize value vector dynamic access in conditions" {
  let source =
    #|fn dynamic_value_vector_condition(values: vec3<u32>, count: u32) -> u32 {
    #|  var i: u32 = count;
    #|  if values[i] > 1u {
    #|    return values[i];
    #|  }
    #|  return 0u;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut condition_access : Handle? = None
  for expression_index, expression in function.expressions.items {
    match expression {
      Access(base, index) =>
        match
          (
            function.expressions.items.get(base.index()),
            function.expressions.items.get(index.index()),
          ) {
          (Some(FunctionArgument(0)), Some(Load(_))) if condition_access == None =>
            condition_access = Some(Handle(expression_index))
          _ => ()
        }
      _ => ()
    }
  }
  let mut access_materialized = false
  match condition_access {
    Some(access) =>
      for local_var in function.local_variables.items {
        if local_var.generated_temporary && local_var.init == Some(access) {
          access_materialized = true
        }
      }
    None => abort("expected dynamic vector access")
  }
  debug_inspect(access_materialized, content="false")
}

///|
test "WGSL AST lowerer predeclares dynamic lvalue function argument roots after global root" {
  let source =
    #|struct Item {
    #|  x: u32,
    #|}
    #|
    #|struct Buffer {
    #|  data: array<Item, 16>,
    #|}
    #|
    #|@group(0) @binding(0)
    #|var<storage, read_write> buffer: Buffer;
    #|
    #|fn dynamic_lvalue_argument_root(local_id: vec3<u32>, offset: u32) -> u32 {
    #|  var i: u32 = 0u;
    #|  buffer.data[i + local_id.x].x += offset;
    #|  return buffer.data[i].x;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut global_root = -1
  let mut local_id_root = -1
  let mut data_projection = -1
  let mut i_load = -1
  let mut local_id_x = -1
  let mut dynamic_sum = -1
  for expression_index, expression in function.expressions.items {
    match expression {
      GlobalVariable(_) if global_root == -1 => global_root = expression_index
      FunctionArgument(index) if index == 0 && local_id_root == -1 =>
        local_id_root = expression_index
      AccessIndex(base, field) =>
        if base.index() == global_root && field == 0 && data_projection == -1 {
          data_projection = expression_index
        } else if base.index() == local_id_root &&
          field == 0 &&
          local_id_x == -1 {
          local_id_x = expression_index
        }
      Load(pointer) =>
        match function.expressions.items.get(pointer.index()) {
          Some(LocalVariable(_)) if data_projection >= 0 && i_load == -1 =>
            i_load = expression_index
          _ => ()
        }
      Binary(_, left, right) =>
        if left.index() == i_load && right.index() == local_id_x {
          dynamic_sum = expression_index
        }
      _ => ()
    }
  }
  debug_inspect(global_root >= 0, content="true")
  debug_inspect(local_id_root > global_root, content="true")
  debug_inspect(data_projection > local_id_root, content="true")
  debug_inspect(i_load > data_projection, content="true")
  debug_inspect(local_id_x > i_load, content="true")
  debug_inspect(dynamic_sum > local_id_x, content="true")
}

///|
test "WGSL AST lowerer lowers pure global array index children before root" {
  let source =
    #|var<workgroup> memory: array<array<f32, 16>, 16>;
    #|
    #|fn pure_global_array_index(x: u32, y: u32, value: f32) {
    #|  memory[x * 2u + 0u][y * 2u + 0u] = value;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut global_root = -1
  let mut first_literal = -1
  let mut first_binary = -1
  for expression_index, expression in function.expressions.items {
    match expression {
      Literal(U32(2)) if first_literal == -1 => first_literal = expression_index
      Binary(_, _, _) if first_binary == -1 => first_binary = expression_index
      GlobalVariable(_) if global_root == -1 => global_root = expression_index
      _ => ()
    }
  }
  debug_inspect(first_literal >= 0, content="true")
  debug_inspect(first_binary > first_literal, content="true")
  debug_inspect(global_root > first_binary, content="true")
}

///|
test "WGSL AST lowerer lowers mutable call argument before scalar const alias" {
  let source =
    #|fn callee(index: u32, enabled: bool) -> u32 {
    #|  if enabled {
    #|    return index;
    #|  }
    #|  return 0u;
    #|}
    #|
    #|fn probe() -> u32 {
    #|  var i: u32 = 1u;
    #|  let enabled = true;
    #|  return callee(i, enabled);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[1]
  let mut i_local = -1
  for local_index, local_var in function.local_variables.items {
    match local_var.name {
      Some("i") => i_local = local_index
      _ => ()
    }
  }
  let mut i_arg_load = -1
  let mut enabled_literal = -1
  let mut call_index = -1
  for expression_index, expression in function.expressions.items {
    match expression {
      Load(pointer) =>
        match function.expressions.items.get(pointer.index()) {
          Some(LocalVariable(handle)) =>
            if handle.index() == i_local && i_arg_load == -1 {
              i_arg_load = expression_index
            }
          _ => ()
        }
      Literal(Bool(true)) if enabled_literal == -1 =>
        enabled_literal = expression_index
      FunctionCall(_, _) | CallResult(_) if call_index == -1 =>
        call_index = expression_index
      _ => ()
    }
  }
  debug_inspect(i_local >= 0, content="true")
  debug_inspect(i_arg_load >= 0, content="true")
  debug_inspect(enabled_literal > i_arg_load, content="true")
  debug_inspect(call_index > enabled_literal, content="true")
}

///|
test "WGSL AST lowerer prelowers later mutable local call argument before prior direct argument" {
  let source =
    #|fn quat_rotate(q: vec4<f32>, v: vec3<f32>) -> vec3<f32> {
    #|  return v;
    #|}
    #|
    #|fn probe(view_rotation: vec4<f32>, dir: vec3<f32>) -> vec3<f32> {
    #|  var sample_dir: vec3<f32>;
    #|  sample_dir = dir;
    #|  sample_dir = quat_rotate(view_rotation, sample_dir);
    #|  return sample_dir;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[1]
  let mut sample_dir_local = -1
  for local_index, local_var in function.local_variables.items {
    match local_var.name {
      Some("sample_dir") => sample_dir_local = local_index
      _ => ()
    }
  }
  let mut sample_dir_call_load = -1
  let mut view_rotation_argument = -1
  let mut call_result = -1
  for expression_index, expression in function.expressions.items {
    match expression {
      Load(pointer) if sample_dir_call_load == -1 =>
        match function.expressions.items.get(pointer.index()) {
          Some(LocalVariable(handle)) if handle.index() == sample_dir_local =>
            sample_dir_call_load = expression_index
          _ => ()
        }
      FunctionArgument(argument_index) if argument_index == 0 &&
        view_rotation_argument == -1 =>
        view_rotation_argument = expression_index
      FunctionCall(_, _) | CallResult(_) if call_result == -1 =>
        call_result = expression_index
      _ => ()
    }
  }
  debug_inspect(sample_dir_local >= 0, content="true")
  debug_inspect(sample_dir_call_load >= 0, content="true")
  debug_inspect(view_rotation_argument > sample_dir_call_load, content="true")
  debug_inspect(call_result > view_rotation_argument, content="true")
}

///|
test "WGSL AST lowerer keeps literal-only let aliases lazy until use" {
  let source =
    #|fn probe(s: f32) -> f32 {
    #|  let uw0 = (4.0 - 3.0 * s);
    #|  let uw1 = 7.0;
    #|  let uw2 = (1.0 + 3.0 * s);
    #|  let u1 = (3.0 + s) / uw1;
    #|  return uw0 + uw2 + u1;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut uw2_handle = -1
  for named in function.named_expressions {
    if named.name == "uw2" {
      uw2_handle = named.handle.index()
    }
  }
  let mut seven_literal = -1
  for expression_index, expression in function.expressions.items {
    match expression {
      Literal(AbstractFloat(value)) if value == 7.0 && seven_literal == -1 =>
        seven_literal = expression_index
      _ => ()
    }
  }
  debug_inspect(uw2_handle >= 0, content="true")
  debug_inspect(seven_literal > uw2_handle, content="true")
}

///|
test "WGSL AST lowerer preserves source let products before compound call RHS" {
  let source =
    #|fn sample(value: f32) -> f32 {
    #|  return value;
    #|}
    #|
    #|fn probe(value: f32) -> f32 {
    #|  let a = 7.0;
    #|  let b = 7.0;
    #|  var sum = 0.0;
    #|  sum += a * b * sample(value);
    #|  return sum;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[1]
  let mut product = -1
  let mut call_result = -1
  let mut folded_product = false
  for expression_index, expression in function.expressions.items {
    match expression {
      Literal(AbstractFloat(value)) if value == 49.0 => folded_product = true
      Binary(Multiply, left, right) if product == -1 =>
        match
          (
            function.expressions.items.get(left.index()),
            function.expressions.items.get(right.index()),
          ) {
          (Some(Literal(AbstractFloat(7.0))), Some(Literal(AbstractFloat(7.0)))) =>
            product = expression_index
          _ => ()
        }
      FunctionCall(_, _) | CallResult(_) if call_result == -1 =>
        call_result = expression_index
      _ => ()
    }
  }
  debug_inspect(product >= 0, content="true")
  debug_inspect(call_result > product, content="true")
  debug_inspect(folded_product, content="false")
}

///|
test "WGSL AST lowerer lowers later math access before deferred first literal" {
  let source =
    #|struct View {
    #|  exposure: f32,
    #|}
    #|
    #|@group(0) @binding(0)
    #|var<uniform> view: View;
    #|
    #|fn probe(emissive: vec4<f32>) -> f32 {
    #|  return mix(1.0, view.exposure, emissive.a);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut exposure_load = -1
  let mut emissive_access = -1
  let mut first_literal = -1
  let mut mix_call = -1
  for expression_index, expression in function.expressions.items {
    match expression {
      Load(pointer) =>
        match function.expressions.items.get(pointer.index()) {
          Some(AccessIndex(base, _)) =>
            match function.expressions.items.get(base.index()) {
              Some(GlobalVariable(_)) if exposure_load == -1 =>
                exposure_load = expression_index
              _ => ()
            }
          _ => ()
        }
      AccessIndex(base, _) =>
        match function.expressions.items.get(base.index()) {
          Some(FunctionArgument(_)) if emissive_access == -1 =>
            emissive_access = expression_index
          _ => ()
        }
      Literal(AbstractFloat(value)) if value == 1.0 && first_literal == -1 =>
        first_literal = expression_index
      Math(Mix, _, _, _, _) if mix_call == -1 => mix_call = expression_index
      _ => ()
    }
  }
  debug_inspect(exposure_load >= 0, content="true")
  debug_inspect(emissive_access > exposure_load, content="true")
  debug_inspect(first_literal > emissive_access, content="true")
  debug_inspect(mix_call > first_literal, content="true")
}

///|
test "WGSL AST lowerer lowers later math user call before deferred first const expression" {
  let source =
    #|const BIAS = 15;
    #|
    #|fn floor_log2_(value: f32) -> i32 {
    #|  return i32(value);
    #|}
    #|
    #|fn probe(maxrgb: f32) -> i32 {
    #|  return max(-BIAS - 1, floor_log2_(maxrgb)) + 1 + BIAS;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[1]
  let mut call_result = -1
  let mut first_const_expr = -1
  let mut max_call = -1
  let mut max_left = -1
  let mut max_right = -1
  for expression_index, expression in function.expressions.items {
    match expression {
      FunctionCall(_, _) | CallResult(_) if call_result == -1 =>
        call_result = expression_index
      Unary(_, _) if call_result >= 0 && first_const_expr == -1 =>
        first_const_expr = expression_index
      Constant(_) if call_result >= 0 && first_const_expr == -1 =>
        first_const_expr = expression_index
      Literal(_) if call_result >= 0 && first_const_expr == -1 =>
        first_const_expr = expression_index
      Binary(_, _, _) if call_result >= 0 && first_const_expr == -1 =>
        first_const_expr = expression_index
      Math(Max, left, Some(right), None, None) if max_call == -1 => {
        max_call = expression_index
        max_left = left.index()
        max_right = right.index()
      }
      _ => ()
    }
  }
  debug_inspect(call_result >= 0, content="true")
  debug_inspect(first_const_expr > call_result, content="true")
  debug_inspect(max_call > first_const_expr, content="true")
  debug_inspect(max_left > call_result, content="true")
  debug_inspect(max_right, content="\{call_result}")
}

///|
test "WGSL AST lowerer predeclares later constructor local root after first global root" {
  let source =
    #|struct View {
    #|  exposure: f32,
    #|}
    #|
    #|@group(0) @binding(0)
    #|var<uniform> view: View;
    #|
    #|fn probe(color: vec3<f32>) -> vec4<f32> {
    #|  var output_color: vec4<f32>;
    #|  output_color = vec4<f32>(0.0);
    #|  var transmitted_light: vec3<f32> = vec3<f32>(0.0);
    #|  return vec4<f32>(view.exposure * transmitted_light, output_color.a);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut transmitted_local = -1
  for local_index, local_var in function.local_variables.items {
    match local_var.name {
      Some("transmitted_light") => transmitted_local = local_index
      _ => ()
    }
  }
  let mut global_root = -1
  let mut transmitted_root = -1
  let mut exposure_access = -1
  let mut exposure_load = -1
  let mut transmitted_load = -1
  for expression_index, expression in function.expressions.items {
    match expression {
      GlobalVariable(_) if global_root == -1 => global_root = expression_index
      LocalVariable(handle) =>
        if handle.index() == transmitted_local &&
          global_root >= 0 &&
          transmitted_root == -1 {
          transmitted_root = expression_index
        }
      AccessIndex(base, _) if base.index() == global_root &&
        exposure_access == -1 => exposure_access = expression_index
      Load(pointer) if pointer.index() == exposure_access && exposure_load == -1 =>
        exposure_load = expression_index
      Load(pointer) if pointer.index() == transmitted_root &&
        transmitted_load == -1 => transmitted_load = expression_index
      _ => ()
    }
  }
  debug_inspect(transmitted_local >= 0, content="true")
  debug_inspect(global_root >= 0, content="true")
  debug_inspect(transmitted_root > global_root, content="true")
  debug_inspect(exposure_access > transmitted_root, content="true")
  debug_inspect(exposure_load > exposure_access, content="true")
  debug_inspect(transmitted_load > exposure_load, content="true")
}

///|
test "WGSL AST lowerer keeps constructor member root after left global load" {
  let source =
    #|struct Atmosphere {
    #|  world_to_atmosphere: mat4x4<f32>,
    #|}
    #|
    #|struct View {
    #|  world_position: vec3<f32>,
    #|}
    #|
    #|@group(0) @binding(0)
    #|var<uniform> atmosphere: Atmosphere;
    #|
    #|@group(0) @binding(1)
    #|var<uniform> view: View;
    #|
    #|fn probe(position: vec3<f32>) -> vec3<f32> {
    #|  return (atmosphere.world_to_atmosphere * vec4(view.world_position, 1.0)).xyz;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut left_root = -1
  let mut right_root = -1
  let mut left_access = -1
  let mut left_load = -1
  let mut right_access = -1
  for expression_index, expression in function.expressions.items {
    match expression {
      GlobalVariable(_) if left_root == -1 => left_root = expression_index
      GlobalVariable(_) if left_root >= 0 && right_root == -1 =>
        right_root = expression_index
      AccessIndex(base, _) if base.index() == left_root && left_access == -1 =>
        left_access = expression_index
      Load(pointer) if pointer.index() == left_access && left_load == -1 =>
        left_load = expression_index
      AccessIndex(base, _) if base.index() == right_root && right_access == -1 =>
        right_access = expression_index
      _ => ()
    }
  }
  debug_inspect(left_root, content="0")
  debug_inspect(left_access, content="1")
  debug_inspect(left_load, content="2")
  debug_inspect(right_root, content="3")
  debug_inspect(right_access, content="4")
}

///|
test "WGSL AST lowerer predeclares constructor argument root before left global projection" {
  let source =
    #|struct VolumeInfo {
    #|  voxel_from_world: mat4x4<f32>,
    #|}
    #|
    #|struct VertexOutput {
    #|  world_position: vec4<f32>,
    #|}
    #|
    #|@group(0) @binding(0)
    #|var<uniform> volume: VolumeInfo;
    #|
    #|fn fragment(mesh: VertexOutput) -> vec3<f32> {
    #|  return (volume.voxel_from_world * vec4<f32>(mesh.world_position.xyz, 1.0)).xyz;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  match function.expressions.items[0] {
    GlobalVariable(_) => ()
    _ => abort("expected left global root first")
  }
  match function.expressions.items[1] {
    FunctionArgument(index) => debug_inspect(index, content="0")
    _ => abort("expected constructor argument root before left projection")
  }
  match function.expressions.items[2] {
    AccessIndex(base, index) => {
      debug_inspect(base.index(), content="0")
      debug_inspect(index, content="0")
    }
    _ => abort("expected left global projection after argument root")
  }
  match function.expressions.items[3] {
    Load(pointer) => debug_inspect(pointer.index(), content="2")
    _ => abort("expected left global load after projection")
  }
  match function.expressions.items[4] {
    AccessIndex(base, index) => {
      debug_inspect(base.index(), content="1")
      debug_inspect(index, content="0")
    }
    _ => abort("expected constructor member projection after left load")
  }
}

///|
test "WGSL AST lowerer delays literal let constants used by assignment RHS" {
  let source =
    #|fn color_sweep(uv_input: vec2<f32>) -> vec2<f32> {
    #|  var uv = uv_input;
    #|  let steps = 24.0;
    #|  uv.y = uv.y * (1.0 + 1.0 / steps);
    #|  return uv;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("let _e4: f32 = uv.y;"), content="true")
  debug_inspect(
    emitted.contains("uv.y = (_e4 * (1f + (1f / 24f)));"),
    content="true",
  )
}

///|
test "WGSL AST lowerer keeps non-loop nested var const initializer in declaration" {
  let source =
    #|fn nested_if_var_init(flag: bool) -> f32 {
    #|  var total: f32 = 0.0;
    #|  if flag {
    #|    var color: vec3<f32> = vec3(1.0);
    #|    total = color.x;
    #|  }
    #|  return total;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("var color: vec3<f32> = vec3(1f);\n"),
    content="true",
  )
  debug_inspect(emitted.contains("color = vec3(1f);\n"), content="false")
}

///|
test "WGSL AST lowerer reuses source local const initializer literal by scalar type" {
  let source =
    #|fn source_const_literal_reuse() -> f32 {
    #|  var color: vec3<f32> = vec3(1.0);
    #|  var scalar: f32 = 1.0;
    #|  return scalar + color.x;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut color_init = -1
  let mut scalar_init = -1
  for local_var in function.local_variables.items {
    match local_var.name {
      Some("color") =>
        match local_var.init {
          Some(init) => color_init = init.index()
          None => ()
        }
      Some("scalar") =>
        match local_var.init {
          Some(init) => scalar_init = init.index()
          None => ()
        }
      _ => ()
    }
  }
  debug_inspect(color_init, content="1")
  debug_inspect(scalar_init, content="0")
  let mut literal_count = 0
  for expression in function.expressions.items {
    match expression {
      Literal(_) => literal_count += 1
      _ => ()
    }
  }
  debug_inspect(literal_count, content="1")
}

///|
test "WGSL AST lowerer reuses inferred scalar var initializer literals in vector splats" {
  let source =
    #|fn source_var_splat_literal_reuse() -> vec3<f32> {
    #|  var scalar = 0.0;
    #|  var vector = vec3(0.0);
    #|  return vector + vec3(scalar);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut scalar_init = -1
  let mut vector_init = -1
  for local_var in function.local_variables.items {
    match local_var.name {
      Some("scalar") =>
        match local_var.init {
          Some(init) => scalar_init = init.index()
          None => ()
        }
      Some("vector") =>
        match local_var.init {
          Some(init) => vector_init = init.index()
          None => ()
        }
      _ => ()
    }
  }
  debug_inspect(scalar_init, content="0")
  debug_inspect(vector_init, content="1")
  match function.expressions.items[1] {
    Splat(Tri, component) => debug_inspect(component.index(), content="0")
    _ => abort("expected vector splat to reuse inferred scalar literal")
  }
  let mut literal_count = 0
  for expression in function.expressions.items {
    match expression {
      Literal(_) => literal_count += 1
      _ => ()
    }
  }
  debug_inspect(literal_count, content="1")
}

///|
test "WGSL AST lowerer reuses semantic source local const initializers" {
  let source =
    #|fn source_const_semantic_initializer_reuse() -> vec3<f32> {
    #|  var first: vec3<f32> = vec3<f32>(0.0);
    #|  var second = vec3(0.0f);
    #|  var flag = false;
    #|  var again = false;
    #|  if again {
    #|    return first;
    #|  }
    #|  return first + second;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut first_init = -1
  let mut second_init = -2
  let mut flag_init = -3
  let mut again_init = -4
  for local_var in function.local_variables.items {
    match local_var.name {
      Some("first") =>
        match local_var.init {
          Some(init) => first_init = init.index()
          None => ()
        }
      Some("second") =>
        match local_var.init {
          Some(init) => second_init = init.index()
          None => ()
        }
      Some("flag") =>
        match local_var.init {
          Some(init) => flag_init = init.index()
          None => ()
        }
      Some("again") =>
        match local_var.init {
          Some(init) => again_init = init.index()
          None => ()
        }
      _ => ()
    }
  }
  debug_inspect(first_init == second_init, content="true")
  debug_inspect(flag_init == again_init, content="true")
  let mut splat_count = 0
  let mut false_count = 0
  for expression in function.expressions.items {
    match expression {
      Splat(_, _) => splat_count += 1
      Literal(Bool(false)) => false_count += 1
      _ => ()
    }
  }
  debug_inspect(splat_count, content="1")
  debug_inspect(false_count, content="1")
}

///|
test "WGSL AST lowerer reuses concrete storage vector splat initializers" {
  let source =
    #|fn source_var_zero_vector_storage_reuse() -> vec3<f32> {
    #|  var first: vec3<f32> = vec3<f32>(0.0);
    #|  var second = vec3(0.0);
    #|  var third = vec3(0.0);
    #|  var one = vec3(1.0);
    #|  return first + second + third + one;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut first_init = -1
  let mut second_init = -2
  let mut third_init = -3
  let mut one_init = -4
  for local_var in function.local_variables.items {
    match local_var.name {
      Some("first") =>
        match local_var.init {
          Some(init) => first_init = init.index()
          None => ()
        }
      Some("second") =>
        match local_var.init {
          Some(init) => second_init = init.index()
          None => ()
        }
      Some("third") =>
        match local_var.init {
          Some(init) => third_init = init.index()
          None => ()
        }
      Some("one") =>
        match local_var.init {
          Some(init) => one_init = init.index()
          None => ()
        }
      _ => ()
    }
  }
  debug_inspect(first_init == second_init, content="true")
  debug_inspect(second_init == third_init, content="true")
  debug_inspect(one_init == first_init, content="false")
  let mut splat_count = 0
  for expression in function.expressions.items {
    match expression {
      Splat(_, _) => splat_count += 1
      _ => ()
    }
  }
  debug_inspect(splat_count, content="2")
}

///|
test "WGSL AST lowerer preserves abstract scalar source local const initializer identity" {
  let source =
    #|fn source_var_scalar_zero_reuse() -> f32 {
    #|  var hit = 0.0;
    #|  var miss = 0.0;
    #|  return hit + miss;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut hit_init = -1
  let mut miss_init = -2
  for local_var in function.local_variables.items {
    match local_var.name {
      Some("hit") =>
        match local_var.init {
          Some(init) => hit_init = init.index()
          None => ()
        }
      Some("miss") =>
        match local_var.init {
          Some(init) => miss_init = init.index()
          None => ()
        }
      _ => ()
    }
  }
  debug_inspect(hit_init == miss_init, content="true")
  let mut zero_count = 0
  for expression in function.expressions.items {
    match expression {
      Literal(AbstractFloat(0.0)) => zero_count += 1
      _ => ()
    }
  }
  debug_inspect(zero_count, content="1")
}

///|
test "WGSL IR emitter disambiguates repeated local names" {
  let source =
    #|fn f() -> u32 {
    #|  var i: u32 = 0u;
    #|  i = i + 1u;
    #|  var i: u32 = 2u;
    #|  return i;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("var i: u32 = 0u;"), content="true")
  debug_inspect(emitted.contains("var i_1: u32 = 2u;"), content="true")
  debug_inspect(emitted.contains("return _e"), content="true")
}

///|
test "WGSL AST lowerer lowers relational builtin expressions through IR" {
  let source =
    #|fn f(v: vec3<f32>) -> bool {
    #|  return any(v > vec3<f32>(1.0));
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("any("), content="true")
}

///|
test "WGSL AST lowerer lowers scalar vector constructors as splats" {
  let source =
    #|fn f(v: vec3<f32>) -> f32 {
    #|  return dot(v, vec3(16.5));
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  match module_.functions.items.get(0) {
    Some(function) => {
      let mut has_splat = false
      let mut has_single_component_compose = false
      for expression in function.expressions.items {
        match expression {
          Splat(Tri, _) => has_splat = true
          Compose(_, [_]) => has_single_component_compose = true
          _ => ()
        }
      }
      debug_inspect(has_splat, content="true")
      debug_inspect(has_single_component_compose, content="false")
    }
    None => abort("missing function")
  }
}

///|
test "WGSL AST lowerer contextualizes shift amount literals as u32" {
  let source =
    #|fn f32_bits_to_sortable_u32(bits: u32) -> u32 {
    #|  return bitcast<u32>(bitcast<i32>(bits) >> 31);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut found_shift = false
  for expression in function.expressions.items {
    match expression {
      Binary(ShiftRight, _, right) =>
        match function.expressions.items.get(right.index()) {
          Some(Literal(U32(31))) => found_shift = true
          Some(_) => abort("unexpected shift amount")
          None => abort("missing shift amount")
        }
      _ => ()
    }
  }
  debug_inspect(found_shift, content="true")
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains(">> 31u"), content="true")
}

///|
