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
    content="1",
  )
  debug_inspect(
    module_.entry_points[0].function.body.statements.length(),
    content="3",
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
test "WGSL AST lowerer folds const float arithmetic" {
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
  debug_inspect(emitted.contains("PI * 2f"), content="false")
}

///|
test "WGSL AST lowerer preserves f16 literal suffixes" {
  let source =
    #|enable f16;
    #|const x: f16 = 1h;
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("const x: f16 = 1h;"), content="true")
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
  debug_inspect(emitted.contains("let _e2: u32 = values[0];"), content="true")
  debug_inspect(emitted.contains("return f32(_e2);"), content="true")
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
  debug_inspect(emitted.contains("let _e3: Frag = f;"), content="true")
  debug_inspect(
    emitted.contains("let _e4: f32 = fragment(_e3);"),
    content="true",
  )
  debug_inspect(emitted.contains("return _e4;"), content="true")
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
  debug_inspect(emitted.contains("let _e3: f32 = x;"), content="true")
  debug_inspect(emitted.contains("return _e3;"), content="true")
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
  debug_inspect(emitted.contains("pbr_input.value ="), content="true")
  debug_inspect(emitted.contains("+ 1u);"), content="true")
  debug_inspect(emitted.contains("apply_decals(&pbr_input);"), content="true")
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
  debug_inspect(emitted.contains(": f32 = dot(v1, v2);"), content="true")
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
  debug_inspect(emitted.contains("var T: vec3<f32> = TBN[0];"), content="true")
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
test "WGSL statement parser keeps condition tails after grouped operands" {
  let source =
    #|const FLAG: u32 = 1u;
    #|fn f(flags: u32) -> u32 {
    #|  var value: u32 = 0u;
    #|  if (flags & FLAG) != 0u {
    #|    value = 1u;
    #|  }
    #|  return value;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("if ((flags & FLAG) != 0u)"), content="true")
}

///|
test "WGSL AST lowerer lowers select expressions through IR" {
  let source =
    #|fn f(reject: vec4<f32>, accept: vec4<f32>, condition: bool) -> vec4<f32> {
    #|  let value = select(reject, accept, condition);
    #|  return value;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains(": vec4<f32>"), content="true")
  debug_inspect(
    emitted.contains("select(reject, accept, condition)"),
    content="true",
  )
}

///|
test "WGSL AST lowerer lowers bitcast expressions through IR" {
  let source =
    #|fn f(value: f32) -> u32 {
    #|  return bitcast<u32>(value);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("bitcast<u32>(value)"), content="true")
}

///|
test "WGSL AST lowerer binds context-typed array constructors" {
  let source =
    #|const offsets: array<vec2<f32>, 2> = array(vec2(0.125, -0.375), vec2(-0.125, 0.375));
    #|
    #|fn f() {
    #|  let local: array<vec2<f32>, 2> = array(vec2(0.0), vec2(1.0));
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("array<vec2<f32>, 2>(vec2<f32>(0.125f, -0.375f)"),
    content="true",
  )
  debug_inspect(
    emitted.contains(": array<vec2<f32>, 2> = array<vec2<f32>, 2>"),
    content="true",
  )
}

///|
test "WGSL AST lowerer binds local consts as constant expressions" {
  let source =
    #|const COUNT: u32 = 4u;
    #|
    #|fn main() -> u32 {
    #|  const LOCAL: u32 = COUNT + 1u;
    #|  let value: u32 = LOCAL + 2u;
    #|  return value;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  debug_inspect(
    module_.functions.items[0].local_variables.items.length(),
    content="1",
  )
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("const LOCAL"), content="false")
  debug_inspect(
    emitted.contains(": u32 = ((COUNT + 1u) + 2u);"),
    content="true",
  )
}

///|
test "WGSL AST lowerer rejects runtime local const initializers" {
  let source =
    #|fn main() -> u32 {
    #|  let runtime_value: u32 = 1u;
    #|  const LOCAL: u32 = runtime_value;
    #|  return LOCAL;
    #|}
  let message = try {
    ignore(parse_wgsl_module_to_ir(source))
    "ok"
  } catch {
    error => error.message()
  }
  debug_inspect(
    message,
    content="\"unsupported WGSL expression: local const initializer is not a const expression in function main\"",
  )
}

///|
test "WGSL AST lowerer preserves suffixed array size literals" {
  let source =
    #|struct Light {
    #|  values: array<vec4<f32>, 10u>,
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("values: array<vec4<f32>, 10>"),
    content="true",
  )
}

///|
test "WGSL AST lowerer applies recursive struct layout semantics" {
  let source =
    #|struct Layout {
    #|  a: vec3<f32>,
    #|  b: array<vec3<f32>, 2>,
    #|  @align(32) @size(64) c: f32,
    #|  d: u32,
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let offsets : Array[Int] = []
  let mut span = -1
  for ty in module_.types.items {
    if ty.name == Some("Layout") {
      match ty.inner {
        Struct(members, struct_span) => {
          span = struct_span
          for struct_member in members {
            offsets.push(struct_member.offset)
          }
        }
        _ => ()
      }
    }
  }
  debug_inspect(offsets, content="[0, 16, 64, 128]")
  debug_inspect(span, content="160")
}

///|
test "WGSL AST lowerer rejects invalid struct layout attributes" {
  let source =
    #|struct InvalidLayout {
    #|  @align(3) value: f32,
    #|}
  let message = try {
    ignore(parse_wgsl_module_to_ir(source))
    "ok"
  } catch {
    error => error.message()
  }
  debug_inspect(
    message,
    content="\"unsupported WGSL type: @align must be a positive power of two\"",
  )
}

///|
test "WGSL AST lowerer supports function call expressions" {
  let source =
    #|fn helper() -> u32 {
    #|  return 1u;
    #|}
    #|
    #|@compute
    #|fn main() {
    #|  var value: u32 = helper();
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("var value: u32 = helper();"), content="true")
}

///|
test "WGSL AST lowerer supports builtin math call expressions" {
  let source =
    #|@compute
    #|fn main() {
    #|  var value: u32 = min(4u, 8u);
    #|  value = clamp(value, 1u, 9u);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("var value: u32 = min(4u, 8u);"),
    content="true",
  )
  debug_inspect(
    emitted.contains("value = clamp(value, 1u, 9u);"),
    content="true",
  )
}

///|
test "WGSL AST lowerer supports switch statements" {
  let source =
    #|@compute
    #|fn main() {
    #|  var value: u32 = 0u;
    #|  switch value {
    #|    case 0u, 1u: {
    #|      value = value + 1u;
    #|    }
    #|    default {
    #|      value = 9u;
    #|    }
    #|  }
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  match module_.entry_points[0].function.body.statements[1] {
    Switch(_, cases) => {
      debug_inspect(cases.length(), content="3")
      debug_inspect(cases[0].value, content="U32(0)")
      debug_inspect(cases[2].value, content="Default")
    }
    _ => abort("expected switch statement")
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("switch value {"), content="true")
  debug_inspect(emitted.contains("case 0u {"), content="true")
  debug_inspect(emitted.contains("default {"), content="true")
}

///|
test "WGSL AST lowerer preserves default case selectors" {
  let source =
    #|@compute
    #|fn main() {
    #|  var value: u32 = 0u;
    #|  switch value {
    #|    case 0u, default, : {
    #|      value = value + 1u;
    #|    }
    #|  }
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  match module_.entry_points[0].function.body.statements[1] {
    Switch(_, cases) => {
      debug_inspect(cases.length(), content="2")
      debug_inspect(cases[0].value, content="U32(0)")
      debug_inspect(cases[1].value, content="Default")
    }
    _ => abort("expected switch statement")
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("case 0u {"), content="true")
  debug_inspect(emitted.contains("default {"), content="true")
}

///|
test "WGSL AST lowerer lowers for loops into IR loops" {
  let source =
    #|@compute
    #|fn main() {
    #|  var sum: u32 = 0u;
    #|  for (var i = 0u; i < 4u; i++) {
    #|    sum += i;
    #|  }
    #|  for (sum = 0u; sum < 8u; sum += 1u) {
    #|    sum += 2u;
    #|  }
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.entry_points[0].function
  debug_inspect(function.local_variables.items.length(), content="5")
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("var i: u32 = 0u;"), content="true")
  debug_inspect(emitted.contains("loop {"), content="true")
  debug_inspect(emitted.contains("if !(i < 4u) {"), content="true")
  debug_inspect(emitted.contains("i = (i + 1u);"), content="true")
  debug_inspect(emitted.contains("sum = (_e"), content="true")
  debug_inspect(emitted.contains("+ 2u);"), content="true")
}

///|
test "WGSL AST lowerer resolves struct member names by type" {
  let source =
    #|struct Item {
    #|  weight: u32,
    #|  count: u32,
    #|}
    #|
    #|@compute
    #|fn main() {
    #|  var item: Item = Item(1u, 2u);
    #|  var weight: u32 = item.weight;
    #|  item.count = weight;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("item.weight"), content="true")
  debug_inspect(emitted.contains("item.count = weight;"), content="true")
  debug_inspect(emitted.contains("item.x"), content="false")
}

///|
test "WGSL AST lowerer supports basic texture calls" {
  let source =
    #|@group(0) @binding(0)
    #|var tex: texture_2d<f32>;
    #|@group(0) @binding(1)
    #|var samp: sampler;
    #|@group(0) @binding(2)
    #|var arr_tex: texture_2d_array<f32>;
    #|@group(0) @binding(3)
    #|var out_tex: texture_storage_2d<rgba8unorm, write>;
    #|
    #|@compute
    #|fn main() {
    #|  var uv: vec2f = vec2f(0.5, 0.25);
    #|  var color = textureSampleLevel(tex, samp, uv, 0.0);
    #|  var dims: u32 = textureDimensions(tex).x;
    #|  let arr_dims = textureDimensions(arr_tex);
    #|  var shadow_map_size: vec2f = vec2f(arr_dims);
    #|  textureStore(out_tex, vec2u(0u, 0u), color);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("textureSampleLevel(tex, samp, uv, 0f)"),
    content="true",
  )
  debug_inspect(emitted.contains("textureDimensions(tex).x"), content="true")
  debug_inspect(
    emitted.contains(": vec2<u32> = textureDimensions(arr_tex);"),
    content="true",
  )
  debug_inspect(
    emitted.contains("shadow_map_size: vec2<f32> = vec2<f32>(_e"),
    content="true",
  )
  debug_inspect(emitted.contains("textureStore(out_tex"), content="true")
}

///|
test "WGSL AST lowerer uses texture type to lower advanced sampling arguments" {
  let source =
    #|@group(0) @binding(0)
    #|var tex: texture_2d<f32>;
    #|@group(0) @binding(1)
    #|var tex_arr: texture_2d_array<f32>;
    #|@group(0) @binding(2)
    #|var depth_tex: texture_depth_2d;
    #|@group(0) @binding(3)
    #|var depth_arr: texture_depth_2d_array;
    #|@group(0) @binding(4)
    #|var samp: sampler;
    #|@group(0) @binding(5)
    #|var cmp_samp: sampler_comparison;
    #|
    #|@fragment
    #|fn fragment() -> @location(0) vec4f {
    #|  let uv: vec2f = vec2f(0.5, 0.25);
    #|  let dx: vec2f = vec2f(0.01, 0.0);
    #|  let dy: vec2f = vec2f(0.0, 0.01);
    #|  var color = textureSampleBias(tex, samp, uv, 0.25, vec2i(0i, 0i));
    #|  color = color + textureSampleGrad(tex, samp, uv, dx, dy, vec2i(0i, 0i));
    #|  color = color + textureSampleLevel(tex_arr, samp, uv, 0u, 1.0, vec2i(0i, 0i));
    #|  let count: u32 = textureNumLevels(tex) + textureDimensions(tex).x;
    #|  let cmp: f32 = textureSampleCompare(depth_tex, cmp_samp, uv, 0.5, vec2i(0i, 0i));
    #|  let cmp0: f32 = textureSampleCompareLevel(depth_tex, cmp_samp, uv, 0.5, vec2i(0i, 0i));
    #|  color = color + textureGather(1u, tex, samp, uv, vec2i(0i, 0i));
    #|  color = color + textureGather(depth_tex, samp, uv, vec2i(0i, 0i));
    #|  color = color + textureGatherCompare(depth_arr, cmp_samp, uv, 0u, 0.5, vec2i(0i, 0i));
    #|  return color + vec4f(f32(count) * 0.0 + cmp + cmp0);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("textureSampleBias(tex, samp"), content="true")
  debug_inspect(emitted.contains("textureSampleGrad(tex, samp"), content="true")
  debug_inspect(
    emitted.contains("textureSampleLevel(tex_arr, samp"),
    content="true",
  )
  debug_inspect(emitted.contains("textureNumLevels(tex)"), content="true")
  debug_inspect(
    emitted.contains("textureSampleCompare(depth_tex, cmp_samp"),
    content="true",
  )
  debug_inspect(
    emitted.contains("textureSampleCompareLevel(depth_tex, cmp_samp"),
    content="true",
  )
  debug_inspect(emitted.contains("textureGather(1, tex, samp"), content="true")
  debug_inspect(
    emitted.contains("textureGather(depth_tex, samp"),
    content="true",
  )
  debug_inspect(
    emitted.contains("textureGatherCompare(depth_arr, cmp_samp"),
    content="true",
  )
}

///|
test "WGSL AST lowerer lowers textureLoad arguments from texture type" {
  let source =
    #|@group(0) @binding(0)
    #|var ms_tex: texture_multisampled_2d<f32>;
    #|@group(0) @binding(1)
    #|var arr_tex: texture_2d_array<f32>;
    #|@group(0) @binding(2)
    #|var storage_arr: texture_storage_2d_array<rgba8unorm, read>;
    #|
    #|@compute
    #|fn main() {
    #|  let coords: vec2u = vec2u(0u, 0u);
    #|  let ms_color = textureLoad(ms_tex, coords, 0u);
    #|  let arr_color = textureLoad(arr_tex, coords, 0u, 0u);
    #|  let storage_color = textureLoad(storage_arr, coords, 0u);
    #|  let count: u32 = textureNumSamples(ms_tex) + textureNumLayers(arr_tex) + textureNumLayers(storage_arr);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("textureLoad(ms_tex"), content="true")
  debug_inspect(emitted.contains("textureLoad(arr_tex"), content="true")
  debug_inspect(emitted.contains("textureLoad(storage_arr"), content="true")
  debug_inspect(emitted.contains("textureNumSamples(ms_tex)"), content="true")
  debug_inspect(emitted.contains("textureNumLayers(arr_tex)"), content="true")
}

///|
test "WGSL AST lowerer supports official constructor and swizzle forms" {
  let source =
    #|@fragment
    #|fn main() -> @location(0) vec4<f32> {
    #|  var v: vec3<i32> = vec3(1, 2, 3);
    #|  var w: vec4<i32> = vec4(10);
    #|  v *= w.xyz;
    #|  return vec4<f32>(.4, .2, .3, .1);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("vec3<i32>(1, 2, 3)"), content="true")
  debug_inspect(emitted.contains("v = (_e"), content="true")
  debug_inspect(emitted.contains("* w.xyz);"), content="true")
  debug_inspect(
    emitted.contains("vec4<f32>(0.4f, 0.2f, 0.3f, 0.1f);"),
    content="true",
  )
}

///|
test "WGSL AST lowerer supports phony assignment and address-of lvalues" {
  let source =
    #|struct S {
    #|  x: array<u32>,
    #|}
    #|@group(0) @binding(0) var<storage> v: S;
    #|@group(0) @binding(1) var<uniform> a: vec4f;
    #|
    #|fn foo() {
    #|  _ = a;
    #|  let tmp_ptr: ptr<storage, array<u32>> = &v.x;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("_ = a;"), content="true")
  debug_inspect(
    emitted.contains(": ptr<storage, array<u32>, read> = &v.x;"),
    content="true",
  )
}

///|
test "WGSL AST lowerer preserves storage access defaults" {
  let source =
    #|struct S {
    #|  x: u32,
    #|}
    #|@group(2) @binding(0) var<storage> read_only: S;
    #|@group(2) @binding(1) var<storage, read_write> writable: S;
    #|@compute
    #|fn main() {
    #|  _ = read_only.x;
    #|  writable.x = read_only.x;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  debug_inspect(
    module_.global_variables.items[0].space,
    content="Storage({ bits: 1 })",
  )
  debug_inspect(
    module_.global_variables.items[1].space,
    content="Storage({ bits: 3 })",
  )
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("var<storage, read> read_only: S;"),
    content="true",
  )
  debug_inspect(
    emitted.contains("var<storage, read_write> writable: S;"),
    content="true",
  )
}

///|
test "WGSL AST lowerer supports arrayLength on storage runtime arrays" {
  let source =
    #|@group(0) @binding(0) var<storage> values: array<u32>;
    #|@compute
    #|fn main(@builtin(global_invocation_id) id: vec3u) {
    #|  if id.x >= arrayLength(&values) {
    #|    return;
    #|  }
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("if (id.x >= arrayLength(&values))"),
    content="true",
  )
}

///|
test "WGSL AST lowerer supports abstract hex integer constants" {
  let source =
    #|const lhs = 0xfffff0000;
    #|const res = lhs << 4u;
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("const lhs = 68719411200;"), content="true")
  debug_inspect(emitted.contains("const res = (lhs << 4u);"), content="true")
}

///|
test "WGSL AST lowerer preserves abstract composite constructors" {
  let source =
    #|const vector = vec2(0xffffffffff, 0xfffffffff0);
    #|const values = array(0xffffffffff, 0xfffffffff0);
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("const vector = vec2(1099511627775, 1099511627760);"),
    content="true",
  )
  debug_inspect(
    emitted.contains("const values = array(1099511627775, 1099511627760);"),
    content="true",
  )
}

///|
test "WGSL AST lowerer resolves forward override types" {
  let source =
    #|override x = y;
    #|override y: i32;
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("override x: i32 = y;"), content="true")
  debug_inspect(emitted.contains("override y: i32;"), content="true")
}

///|
test "WGSL AST lowerer folds constant-backed array sizes" {
  let source =
    #|const COUNT: u32 = 4u;
    #|var<private> data: array<u32, COUNT>;
    #|
    #|fn main() -> u32 {
    #|  return data[0];
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("array<u32, 4>"), content="true")
}

///|
test "WGSL AST lowerer materializes atomic side effects through IR" {
  let source =
    #|var<workgroup> atom: atomic<u32>;
    #|
    #|fn main() -> u32 {
    #|  atomicStore(&atom, 1u);
    #|  var y = atomicLoad(&atom);
    #|  y += atomicAdd(&atom, 2u);
    #|  let exchange = atomicCompareExchangeWeak(&atom, 12u, 0u);
    #|  if exchange.exchanged {
    #|    y += exchange.old_value;
    #|  }
    #|  return y;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  let var_index = emitted.find("var y: u32;")
  let store_index = emitted.find("atomicStore((&atom), 1u);")
  let load_index = emitted.find("let _e3: u32 = atomicLoad((&atom));")
  debug_inspect(store_index != None, content="true")
  let materialized_after_store = match (store_index, load_index) {
    (Some(store), Some(load)) => load > store
    _ => false
  }
  let var_hoisted_before_store = match (var_index, store_index) {
    (Some(var_), Some(store)) => var_ < store
    _ => false
  }
  debug_inspect(var_hoisted_before_store, content="true")
  debug_inspect(materialized_after_store, content="true")
  debug_inspect(
    emitted.contains("atomicCompareExchangeWeak((&atom), 12u, 0u)"),
    content="true",
  )
  debug_inspect(emitted.contains(".old_value"), content="true")
}

///|
test "WGSL AST lowerer supports modf predeclared result members" {
  let source =
    #|fn main(x: f32) -> f32 {
    #|  let fw = modf(x);
    #|  return fw.fract * fw.whole;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("modf(x);"), content="true")
  debug_inspect(emitted.contains(".fract"), content="true")
  debug_inspect(emitted.contains(".whole"), content="true")
}

///|
test "WGSL AST lowerer materializes sampled vector before local swizzle" {
  let source =
    #|@group(0) @binding(0) var image: texture_2d<f32>;
    #|@group(0) @binding(1) var s: sampler;
    #|
    #|fn main() -> f32 {
    #|  let x = textureSample(image, s, vec2<f32>(0.0)).r;
    #|  return x;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("let x: f32 = _e") && emitted.contains(".x;"),
    content="true",
  )
  debug_inspect(emitted.contains("vec4<f32> = textureSample"), content="true")
  debug_inspect(emitted.contains("let x: f32 = textureSample"), content="false")
}

///|
test "WGSL AST lowerer makes referenced entry points callable helpers" {
  let source =
    #|@fragment
    #|fn imported(@builtin(position) frag_coord: vec4<f32>) -> @location(0) vec4<f32> {
    #|  return vec4<f32>(frag_coord);
    #|}
    #|
    #|@fragment
    #|fn fragment(@builtin(position) frag_coord: vec4<f32>) -> @location(0) vec4<f32> {
    #|  return imported(frag_coord);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(module_.entry_points.length(), content="1")
  debug_inspect(
    emitted.contains("fn imported(frag_coord: vec4<f32>) -> vec4<f32>"),
    content="true",
  )
  debug_inspect(emitted.contains("imported(frag_coord);"), content="true")
}
