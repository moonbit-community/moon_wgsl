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
    content="4",
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
test "WGSL AST lowerer preserves global const float arithmetic for writer policy" {
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
  debug_inspect(emitted.contains("return (PI * 2f);"), content="true")
  debug_inspect(emitted.contains("return 6.2f;"), content="false")
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
  debug_inspect(emitted.contains("return f32(_e"), content="true")
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
  debug_inspect(emitted.contains("let _e3: u32 = values[0];"), content="true")
  debug_inspect(emitted.contains("return f32(_e3);"), content="true")
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
  let emitted = emit_wgsl_module_from_ir_naga_oil_writer_compatible(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("let _e2: u32 = counters[0];") &&
    emitted.contains("let _e5: u32 = args.x;") &&
    emitted.contains("counters[0] = (_e2 + _e5);"),
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
  debug_inspect(emitted.contains("var x_1: u32 = 30u;"), content="true")
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
  let emitted = roundtrip_wgsl_source_via_ir_with_generated_imports_naga_oil_writer_compatible(
    source,
    [],
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("let _e"), content="true")
  debug_inspect(emitted.contains("make_item();\n    item = _e"), content="true")
  debug_inspect(emitted.contains("item = make_item();"), content="false")
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
  let emitted = roundtrip_wgsl_source_via_ir_with_generated_imports_naga_oil_writer_compatible(
    source,
    [],
  ) catch {
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
test "WGSL AST lowerer splits runtime var initializers like Naga writer" {
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
