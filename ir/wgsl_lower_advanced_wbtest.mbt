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
test "WGSL IR roundtrip preserves transpose matrix result shape" {
  let source =
    #|fn inverse_affine3(affine: mat4x3<f32>) -> mat4x3<f32> {
    #|  return affine;
    #|}
    #|
    #|@compute @workgroup_size(1)
    #|fn main() {
    #|  let world_from_local_affine_transpose: mat3x4<f32> = mat3x4<f32>();
    #|  let inverse_transpose = transpose(inverse_affine3(transpose(world_from_local_affine_transpose)));
    #|  _ = inverse_transpose;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains(": mat3x4<f32> = transpose"), content="true")
}

///|
test "WGSL IR lowerer resolves struct members declared after function use" {
  let source =
    #|@vertex
    #|fn vs_main(@location(0) position: vec3<f32>) -> @builtin(position) vec4<f32> {
    #|  return uniforms.vertex * vec4<f32>(position, 1.0);
    #|}
    #|
    #|struct Uniforms {
    #|  vertex: mat4x4<f32>,
    #|};
    #|
    #|@group(0) @binding(0)
    #|var<uniform> uniforms: Uniforms;
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains(": mat4x4<f32> = uniforms.vertex"),
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
test "WGSL AST lowerer contextualizes texture mip levels as i32" {
  let source =
    #|@group(0) @binding(0)
    #|var depth_tex: texture_depth_2d;
    #|@group(0) @binding(1)
    #|var color_tex: texture_2d<f32>;
    #|
    #|fn read_depth(coords: vec2<i32>) -> f32 {
    #|  let dims = textureDimensions(color_tex, 0);
    #|  let value = textureLoad(depth_tex, coords, 0);
    #|  return value + f32(dims.x) * 0.0;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("textureDimensions(color_tex, 0i)"),
    content="true",
  )
  debug_inspect(
    emitted.contains("textureLoad(depth_tex, coords, 0i)"),
    content="true",
  )
}

///|
test "WGSL AST lowerer contextualizes homogeneous math literal arguments" {
  let source =
    #|fn choose(value: f32) -> i32 {
    #|  return max(0, i32(ceil(value)));
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("max(0i, i32(ceil(value)))"), content="true")
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
test "WGSL IR emitter preserves direct pointer dereference stores" {
  let source =
    #|var<private> global_value: u32;
    #|
    #|fn inc(p: ptr<private, u32>) {
    #|  (*p) += 1u;
    #|}
    #|
    #|@compute @workgroup_size(1)
    #|fn main() {
    #|  inc(&global_value);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("*(p) ="), content="true")
  debug_inspect(emitted.contains("p ="), content="false")
}

///|
test "WGSL IR emitter preserves pointer-valued local references" {
  let source =
    #|fn inc(p: ptr<function, u32>) {
    #|  (*p) += 1u;
    #|}
    #|
    #|@compute @workgroup_size(1)
    #|fn main() {
    #|  var x: u32 = 1u;
    #|  let p = &x;
    #|  (*p) = (*p) + 1u;
    #|  inc(p);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("*(p_1)"), content="true")
  debug_inspect(emitted.contains("inc(p_1)"), content="true")
  debug_inspect(emitted.contains("inc(*(p)"), content="false")
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
  debug_inspect(emitted.contains("var<storage> read_only: S;"), content="true")
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
    emitted.contains("if (id.x >= arrayLength((&values)))"),
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
test "WGSL AST lowerer preserves u32 literals above signed int range" {
  let source =
    #|const MASK: u32 = 3221225472u;
    #|
    #|fn main() -> u32 {
    #|  return 3221225472u;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("const MASK: u32 = 3221225472u;"),
    content="true",
  )
  debug_inspect(emitted.contains("return 3221225472u;"), content="true")
}

///|
test "WGSL AST lowerer preserves large u32 const switch selectors" {
  let source =
    #|const MASK: u32 = 3221225472u;
    #|
    #|fn choose(value: u32) -> u32 {
    #|  switch value {
    #|    case MASK: {
    #|      return 1u;
    #|    }
    #|    default {
    #|      return 0u;
    #|    }
    #|  }
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  match module_.functions.items[0].body.statements[0] {
    Switch(_, cases) => {
      debug_inspect(cases[0].value, content="U32(3221225472)")
      debug_inspect(cases[1].value, content="Default")
    }
    _ => abort("expected switch statement")
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("case 3221225472u {"), content="true")
}

///|
test "WGSL AST lowerer infers unary const switch selector types" {
  let source =
    #|const NEG = -1;
    #|
    #|fn choose(value: i32) -> u32 {
    #|  switch value {
    #|    case NEG: {
    #|      return 1u;
    #|    }
    #|    default {
    #|      return 0u;
    #|    }
    #|  }
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  match module_.functions.items[0].body.statements[0] {
    Switch(_, cases) => {
      debug_inspect(cases[0].value, content="I32(-1)")
      debug_inspect(cases[1].value, content="Default")
    }
    _ => abort("expected switch statement")
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("case -1i {"), content="true")
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
test "WGSL AST lowerer supports storage texture atomics" {
  let source =
    #|@group(0) @binding(0)
    #|var image: texture_storage_2d<r32uint, atomic>;
    #|
    #|@compute @workgroup_size(1)
    #|fn main(@builtin(global_invocation_id) id: vec3<u32>) {
    #|  textureAtomicMax(image, id.xy, 1u);
    #|  textureAtomicMin(image, id.xy, 2u);
    #|  textureAtomicAdd(image, id.xy, 3u);
    #|  textureAtomicAnd(image, id.xy, 4u);
    #|  textureAtomicOr(image, id.xy, 5u);
    #|  textureAtomicXor(image, id.xy, 6u);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("texture_storage_2d<r32uint, atomic>"),
    content="true",
  )
  debug_inspect(emitted.contains("textureAtomicMax(image"), content="true")
  debug_inspect(emitted.contains("textureAtomicMin(image"), content="true")
  debug_inspect(emitted.contains("textureAtomicAdd(image"), content="true")
  debug_inspect(emitted.contains("textureAtomicAnd(image"), content="true")
  debug_inspect(emitted.contains("textureAtomicOr(image"), content="true")
  debug_inspect(emitted.contains("textureAtomicXor(image"), content="true")
}

///|
test "WGSL AST lowerer permits textureStore on atomic storage textures" {
  let source =
    #|@group(0) @binding(0)
    #|var image: texture_storage_2d<r32uint, atomic>;
    #|
    #|@compute @workgroup_size(1)
    #|fn main(@builtin(global_invocation_id) id: vec3<u32>) {
    #|  textureStore(image, id.xy, vec4<u32>(0u));
    #|  textureAtomicMax(image, id.xy, 1u);
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
  debug_inspect(emitted.contains("textureStore(image"), content="true")
  debug_inspect(emitted.contains("textureAtomicMax(image"), content="true")
}

///|
test "WGSL AST lowerer materializes storage texture load result types" {
  let source =
    #|@group(0) @binding(0)
    #|var out_tex: texture_storage_2d<rgba32float, write>;
    #|
    #|@group(0) @binding(1)
    #|var in_tex: texture_storage_2d<r32float, read>;
    #|
    #|@compute @workgroup_size(1)
    #|fn main() {
    #|  textureStore(out_tex, vec2u(0), textureLoad(in_tex, vec2u(0)));
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
  debug_inspect(emitted.contains("textureLoad(in_tex"), content="true")
}

///|
test "WGSL AST lowerer accepts fixed array zero constructors" {
  let source =
    #|fn main() {
    #|  var values = array<array<f32, 10>, 5>();
    #|  values[4][9] = 1.0;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  validate_wgsl_ir_module(module_) catch {
    error => abort(error.message())
  }
}

///|
test "WGSL AST lowerer accepts scalar and struct zero constructors" {
  let source =
    #|struct Foo {
    #|  a: vec4<f32>,
    #|  b: i32,
    #|}
    #|
    #|const cz0 = bool();
    #|const cz1 = i32();
    #|const cz2 = u32();
    #|const cz3 = f32();
    #|const cz4 = Foo();
    #|
    #|fn main() {
    #|  let zvc0 = bool();
    #|  let zvc1 = i32();
    #|  let zvc2 = u32();
    #|  let zvc3 = f32();
    #|  let zvc4 = Foo();
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  validate_wgsl_ir_module(module_) catch {
    error => abort(error.message())
  }
}

///|
test "WGSL AST lowerer validates modf and frexp result member access" {
  let source =
    #|fn main() {
    #|  let modf_scalar = modf(1.5).whole;
    #|  let modf_vector = modf(vec4(1.5, 1.5, 1.5, 1.5)).fract.x;
    #|  let frexp_scalar: i32 = frexp(1.5).exp;
    #|  let frexp_vector: i32 = frexp(vec4(1.5, 1.5, 1.5, 1.5)).exp.x;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  validate_wgsl_ir_module(module_) catch {
    error => abort(error.message())
  }
}

///|
test "WGSL AST lowerer validates address-of read-only storage globals" {
  let source =
    #|@group(0) @binding(0)
    #|var<storage, read> values: array<f32>;
    #|
    #|@compute @workgroup_size(1)
    #|fn main() {
    #|  _ = &values;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  validate_wgsl_ir_module(module_) catch {
    error => abort(error.message())
  }
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
    emitted.contains("fn imported(frag_coord_1: vec4<f32>) -> vec4<f32>"),
    content="true",
  )
  debug_inspect(emitted.contains("imported(frag_coord);"), content="true")
}

///|
test "WGSL IR lowerer resolves constants declared after functions" {
  let source =
    #|fn main(i: u32) -> f32 {
    #|  return vertices[i];
    #|}
    #|
    #|const vertices = array(1.0, 2.0, 3.0, 4.0);
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("const vertices = array(1.0, 2.0, 3.0, 4.0);"),
    content="true",
  )
  debug_inspect(emitted.contains("return vertices[i];"), content="true")
}

///|
test "WGSL IR lowerer resolves forward constant references" {
  let source =
    #|const b = a + 1u;
    #|const a = 41u;
    #|
    #|fn main() -> u32 {
    #|  return b;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("const a: u32 = 41u;"), content="true")
  debug_inspect(emitted.contains("const b: u32 = (a + 1u);"), content="true")
  debug_inspect(emitted.contains("return b;"), content="true")
}

///|
test "WGSL IR lowerer resolves Naga ray query predeclared constants" {
  let source =
    #|enable wgpu_ray_query;
    #|
    #|fn flag() -> u32 {
    #|  if RAY_QUERY_INTERSECTION_AABB == RAY_QUERY_INTERSECTION_GENERATED {
    #|    return RAY_FLAG_SKIP_AABBS;
    #|  }
    #|  return RAY_FLAG_NONE;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("if (3u == 2u) {"), content="true")
  debug_inspect(emitted.contains("return 512u;"), content="true")
  debug_inspect(emitted.contains("return 0u;"), content="true")
}

///|
test "WGSL IR lowerer exposes complete Naga RayIntersection fields" {
  let source =
    #|enable wgpu_ray_query;
    #|
    #|fn transform(hit: RayIntersection) -> vec3<f32> {
    #|  return (hit.object_to_world * vec4<f32>(0.0, 0.0, 0.0, 1.0)).xyz;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains(".object_to_world"), content="true")
  debug_inspect(emitted.contains("* vec4<f32>"), content="true")
}

///|
test "WGSL IR lowerer supports external textureLoad without mip level" {
  let source =
    #|@group(0) @binding(0) var tex: texture_external;
    #|
    #|fn main(coords: vec2<u32>) -> vec4<f32> {
    #|  return textureLoad(tex, coords);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("textureLoad(tex, coords);"), content="true")
}

///|
test "WGSL IR lowerer supports complete storage texture format names" {
  let source =
    #|@group(0) @binding(0) var tex: texture_storage_2d<rg32float, read>;
    #|
    #|fn main(coords: vec2<u32>) -> vec4<f32> {
    #|  return textureLoad(tex, coords);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("texture_storage_2d<rg32float, read>"),
    content="true",
  )
}

///|
test "WGSL IR lowerer infers r64uint textureLoad result as u64 vector" {
  let source =
    #|@group(0) @binding(0) var tex: texture_storage_2d<r64uint, read>;
    #|
    #|fn main(coords: vec2<u32>) -> u32 {
    #|  let value = textureLoad(tex, coords);
    #|  return u32(value.x);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("vec4<u64> = textureLoad"), content="true")
}

///|
test "WGSL IR emitter preserves phony must-use texture calls" {
  let source =
    #|@group(0) @binding(0) var tex: texture_storage_2d<rg32float, read>;
    #|
    #|@compute @workgroup_size(1)
    #|fn main() {
    #|  _ = textureLoad(tex, vec2u(0));
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("_ = textureLoad(tex, vec2(0));"),
    content="true",
  )
}

///|
test "WGSL IR lowerer preserves barycentric builtins" {
  let source =
    #|@fragment
    #|fn main(
    #|  @builtin(barycentric) bary: vec3<f32>,
    #|  @builtin(barycentric_no_perspective) no_perspective: vec3<f32>,
    #|) -> @location(0) vec4<f32> {
    #|  return vec4<f32>(bary + no_perspective, 1.0);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("@builtin(barycentric)"), content="true")
  debug_inspect(
    emitted.contains("@builtin(barycentric_no_perspective)"),
    content="true",
  )
}

///|
test "WGSL IR lowerer roundtrips cooperative matrix builtins" {
  let source =
    #|enable wgpu_cooperative_matrix;
    #|
    #|@group(0) @binding(0) var<storage, read> a: array<f32>;
    #|@group(0) @binding(1) var<storage, read> b: array<f32>;
    #|@group(0) @binding(2) var<storage, read_write> c: array<f32>;
    #|
    #|@compute @workgroup_size(8, 8, 1)
    #|fn main() {
    #|  let stride = 8u;
    #|  let a_tile = coopLoad<coop_mat8x8<f32, A>>(&a[0u], stride);
    #|  let b_tile = coopLoad<coop_mat8x8<f32, B>>(&b[0u], stride);
    #|  var c_tile = coopLoad<coop_mat8x8<f32, C>>(&c[0u], stride);
    #|  c_tile = coopMultiplyAdd(a_tile, b_tile, c_tile);
    #|  coopStore(c_tile, &c[0u], stride);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("coopLoad<coop_mat8x8<f32, A>>(&a[0u], 8u)"),
    content="true",
  )
  debug_inspect(
    emitted.contains("coopMultiplyAdd(a_tile, b_tile, _e"),
    content="true",
  )
  debug_inspect(
    emitted.contains("coopStore(c_tile, &c[0u], 8u);"),
    content="true",
  )
}

///|
test "WGSL IR lowerer preserves else-if conditions as control flow" {
  let source =
    #|fn classify(value: u32) -> u32 {
    #|  var result = 3u;
    #|  if value == 0u {
    #|    result = 0u;
    #|  } else if value == 1u || value == 2u {
    #|    result = 1u;
    #|  } else {
    #|    result = 4u;
    #|  }
    #|  return result;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let statements = module_.functions.items[0].body.statements
  guard statements[1] is Statement::If(_, _, reject) else {
    abort("expected outer if")
  }
  let mut saw_nested_if = false
  for statement in reject.statements {
    match statement {
      Statement::If(_, _, _) => saw_nested_if = true
      _ => ()
    }
  }
  if !saw_nested_if {
    abort("expected nested else-if")
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("var local: bool;"), content="true")
  debug_inspect(emitted.contains("if ((value == 1u) ||"), content="false")
  debug_inspect(
    emitted.contains("} else {\n        result = 1u;"),
    content="false",
  )
}

///|
test "WGSL IR lowerer materializes short-circuit return expressions as control flow" {
  let source =
    #|fn enabled(flags: u32, mask: u32) -> bool {
    #|  return (flags & mask) != 0u;
    #|}
    #|
    #|fn active(flags: u32, value: u32) -> bool {
    #|  return (enabled(flags, 1u) && value == 1u) || (enabled(flags, 2u) && value == 2u);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("var local: bool;"), content="true")
  debug_inspect(emitted.contains("if !("), content="true")
  debug_inspect(
    emitted.contains("return ((enabled(flags, 1u) && (value == 1u))"),
    content="false",
  )
}

///|
test "WGSL IR lowerer materializes abstract matrix index result types" {
  let source =
    #|const idx = 0i;
    #|const_assert mat2x2(1.11001100110011008404,1,1,1)[0i][0i] == 1.11001100110011008404;
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
    emitted.contains("mat2x2(1.11001100110011, 1, 1, 1)[0i][0i]"),
    content="true",
  )
}

///|
test "WGSL IR lowerer accepts override expressions in module array aliases" {
  let source =
    #|override x = 1;
    #|alias T = array<u32, x + 1>;
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  validate_wgsl_ir_module(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(module_.overrides.items.length(), content="1")
}
