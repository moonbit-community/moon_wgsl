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
    content="0",
  )
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("const LOCAL"), content="false")
  debug_inspect(emitted.contains("let value"), content="false")
}

///|
test "WGSL AST lowerer rejects runtime local const initializers" {
  let source =
    #|fn main(runtime_value: u32) -> u32 {
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
test "WGSL AST lowerer rejects out-of-range abstract int contextualized to i32" {
  let source =
    #|const VALUE: i32 = 2147483648;
  let message = try {
    ignore(parse_wgsl_module_to_ir(source))
    "ok"
  } catch {
    error => error.message()
  }
  debug_inspect(
    message,
    content="\"unsupported WGSL expression: i32 literal 2147483648\"",
  )
}

///|
test "WGSL AST lowerer rejects out-of-range abstract int switch selectors" {
  let source =
    #|const CASE = 2147483648;
    #|fn main(value: i32) -> u32 {
    #|  switch value {
    #|    case CASE: { return 1u; }
    #|    default: { return 0u; }
    #|  }
    #|}
  let message = try {
    ignore(parse_wgsl_module_to_ir(source))
    "ok"
  } catch {
    error => error.message()
  }
  debug_inspect(
    message,
    content="\"unsupported WGSL expression: i32 literal 2147483648 in function main\"",
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
test "WGSL AST lowerer rejects unknown global address spaces" {
  let source =
    #|struct PushConstants {
    #|  multiplier: f32,
    #|}
    #|var<push_constant> pc: PushConstants;
  let message = try {
    ignore(parse_wgsl_module_to_ir(source))
    "ok"
  } catch {
    error => error.message()
  }
  debug_inspect(
    message,
    content="\"unsupported WGSL type: unknown WGSL address space: push_constant\"",
  )
}

///|
test "WGSL AST lowerer rejects unknown storage access modes" {
  let source =
    #|struct Data {
    #|  value: u32,
    #|}
    #|@group(0) @binding(0) var<storage, banana> data: Data;
  let message = try {
    ignore(parse_wgsl_module_to_ir(source))
    "ok"
  } catch {
    error => error.message()
  }
  debug_inspect(
    message,
    content="\"unsupported WGSL type: unknown WGSL storage access: banana\"",
  )
}

///|
test "WGSL AST lowerer supports function call expressions" {
  let source =
    #|fn helper(a: u32, b: u32, c: u32) -> u32 {
    #|  return a + b + c;
    #|}
    #|
    #|@compute
    #|fn main() {
    #|  let base = 1u;
    #|  var value: u32 = helper(base, 2u, base + 2u);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("helper(1u, 2u, (1u + 2u))"), content="true")
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
    emitted.contains("min(4u, 8u)") ||
    emitted.contains("var value: u32 = 4u;") ||
    emitted.contains("value = 4u;"),
    content="true",
  )
  debug_inspect(
    emitted.contains("value = clamp(_e") && emitted.contains(", 1u, 9u);"),
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
  let mut switch_cases : Array[SwitchCase]? = None
  for statement in module_.entry_points[0].function.body.statements {
    match statement {
      Switch(_, cases) => switch_cases = Some(cases)
      _ => ()
    }
  }
  match switch_cases {
    Some(cases) => {
      debug_inspect(cases.length(), content="3")
      debug_inspect(cases[0].value, content="U32(0)")
      debug_inspect(cases[2].value, content="Default")
    }
    None => abort("expected switch statement")
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("switch value {"), content="true")
  debug_inspect(emitted.contains("case 0u: {"), content="true")
  debug_inspect(emitted.contains("default: {"), content="true")
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
  let mut switch_cases : Array[SwitchCase]? = None
  for statement in module_.entry_points[0].function.body.statements {
    match statement {
      Switch(_, cases) => switch_cases = Some(cases)
      _ => ()
    }
  }
  match switch_cases {
    Some(cases) => {
      debug_inspect(cases.length(), content="2")
      debug_inspect(cases[0].value, content="U32(0)")
      debug_inspect(cases[1].value, content="Default")
    }
    None => abort("expected switch statement")
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("case 0u: {"), content="true")
  debug_inspect(emitted.contains("default: {"), content="true")
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
  debug_inspect(
    function.local_variables.items.length(),
    content=(
      #|9
    ),
  )
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("var i: u32 = 0u;"), content="true")
  debug_inspect(emitted.contains("loop {"), content="true")
  debug_inspect(emitted.contains("if (_e2 < 4u) {"), content="true")
  debug_inspect(
    emitted.contains("} else {\n            break;"),
    content="true",
  )
  debug_inspect(emitted.contains("i = (_e"), content="true")
  debug_inspect(emitted.contains("+ 1u);"), content="true")
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
  debug_inspect(emitted.contains(": u32 = weight;"), content="true")
  debug_inspect(emitted.contains("item.count = _e"), content="true")
  debug_inspect(emitted.contains("item.count = weight;"), content="false")
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
    #|@group(0) @binding(4)
    #|var tex_array: binding_array<texture_2d<f32>, 4>;
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
    content="false",
  )
  debug_inspect(
    emitted.contains("textureSampleLevel(tex, samp, _e"),
    content="true",
  )
  debug_inspect(emitted.contains("textureDimensions(tex).x"), content="false")
  debug_inspect(emitted.contains("dims = _e"), content="true")
  debug_inspect(
    emitted.contains(": vec2<u32> = textureDimensions(arr_tex);"),
    content="true",
  )
  debug_inspect(
    emitted.contains("shadow_map_size: vec2<f32> = vec2<f32>(arr_dims);"),
    content="false",
  )
  debug_inspect(
    emitted.contains("shadow_map_size = vec2<f32>(arr_dims);"),
    content="true",
  )
  debug_inspect(emitted.contains("textureStore(out_tex"), content="true")
  debug_inspect(
    emitted.contains("var tex_array: binding_array<texture_2d<f32>"),
    content="true",
  )
  debug_inspect(emitted.contains("var<private> tex_array"), content="false")
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
    #|  color = color + textureGather(0, depth_tex, samp, uv, vec2i(1i, 1i));
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
    emitted.contains("textureGather(depth_tex, samp") &&
    emitted.contains("vec2<i32>(1i, 1i)"),
    content="true",
  )
  debug_inspect(
    emitted.contains("textureGather(0, depth_tex, samp"),
    content="false",
  )
  debug_inspect(
    emitted.contains("textureGatherCompare(depth_arr, cmp_samp"),
    content="true",
  )
}

///|
test "WGSL AST lowerer schedules textureGather offset leaves before resource roots" {
  let source =
    #|@group(0) @binding(0)
    #|var depth_tex: texture_depth_2d;
    #|@group(0) @binding(1)
    #|var samp: sampler;
    #|
    #|fn probe(uv: vec2<f32>) -> vec4<f32> {
    #|  return textureGather(0, depth_tex, samp, uv, vec2<i32>(1i, 1i));
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  match function.expressions.items[0] {
    Literal(I32(1)) => ()
    _ => abort("expected first offset literal before texture root")
  }
  match function.expressions.items[1] {
    Literal(I32(1)) => ()
    _ => abort("expected second offset literal before texture root")
  }
  match function.expressions.items[2] {
    GlobalVariable(_) => ()
    _ => abort("expected texture root after offset leaves")
  }
  match function.expressions.items[3] {
    GlobalVariable(_) => ()
    _ => abort("expected sampler root after texture root")
  }
  match function.expressions.items[5] {
    Compose(_, components) => {
      debug_inspect(components[0].index(), content="0")
      debug_inspect(components[1].index(), content="1")
    }
    _ => abort("expected offset compose after texture and sampler roots")
  }
  match function.expressions.items[6] {
    ImageSample(_, _, _, _, _, offset, _, _, _) =>
      match offset {
        Some(handle) => debug_inspect(handle.index(), content="5")
        None => abort("expected textureGather offset handle")
      }
    _ => abort("expected textureGather image sample after offset compose")
  }
}

///|
test "WGSL AST lowerer schedules textureLoad coordinate before texture root" {
  let source =
    #|@group(0) @binding(0)
    #|var color_texture: texture_2d<f32>;
    #|
    #|fn probe(position: vec4<f32>) -> vec4<f32> {
    #|  var frag_coord = position;
    #|  return textureLoad(color_texture, vec2<i32>(frag_coord.xy), 0);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut as_index = -1
  let mut texture_root_index = -1
  for index in 0..<function.expressions.items.length() {
    match function.expressions.items[index] {
      As(_, Sint, Some(4)) if as_index == -1 => as_index = index
      GlobalVariable(_) if texture_root_index == -1 =>
        texture_root_index = index
      _ => ()
    }
  }
  debug_inspect(as_index >= 0, content="true")
  debug_inspect(texture_root_index >= 0, content="true")
  debug_inspect(as_index < texture_root_index, content="true")
  match function.expressions.items[texture_root_index + 2] {
    ImageLoad(_, coordinate, _, _, level) => {
      debug_inspect(coordinate.index(), content="\{as_index}")
      match level {
        Some(handle) =>
          debug_inspect(handle.index(), content="\{texture_root_index + 1}")
        None => abort("expected textureLoad mip level")
      }
    }
    _ => abort("expected ImageLoad after texture root and level")
  }
}

///|
test "WGSL AST lowerer schedules textureSampleLevel mutable coordinate before texture root" {
  let source =
    #|@group(0) @binding(0)
    #|var color_texture: texture_2d<f32>;
    #|@group(0) @binding(1)
    #|var color_sampler: sampler;
    #|
    #|fn probe(uv: vec2<f32>, enabled: bool) -> vec4<f32> {
    #|  var sample_uv = uv;
    #|  if enabled {
    #|    return textureSampleLevel(color_texture, color_sampler, sample_uv, 0.0);
    #|  }
    #|  return vec4<f32>(0.0);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut sample_uv_local = -1
  for local_index, local_var in function.local_variables.items {
    match local_var.name {
      Some("sample_uv") => sample_uv_local = local_index
      _ => ()
    }
  }
  let mut coordinate_load = -1
  let mut texture_root = -1
  for index, expression in function.expressions.items {
    match expression {
      Load(pointer) if coordinate_load == -1 =>
        match function.expressions.items.get(pointer.index()) {
          Some(LocalVariable(handle)) if handle.index() == sample_uv_local =>
            coordinate_load = index
          _ => ()
        }
      GlobalVariable(_) if texture_root == -1 => texture_root = index
      _ => ()
    }
  }
  debug_inspect(sample_uv_local >= 0, content="true")
  debug_inspect(coordinate_load >= 0, content="true")
  debug_inspect(texture_root > coordinate_load, content="true")
}

///|
test "WGSL AST lowerer schedules textureLoad array index before texture root" {
  let source =
    #|struct Globals {
    #|  frame_count: u32,
    #|}
    #|
    #|@group(0) @binding(0)
    #|var<uniform> globals: Globals;
    #|@group(0) @binding(1)
    #|var stbn_texture: texture_2d_array<f32>;
    #|
    #|fn probe(coords: vec2<u32>, layers: u32) -> vec4<f32> {
    #|  return textureLoad(stbn_texture, coords, i32(globals.frame_count % layers), 0);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut array_index_as = -1
  let mut texture_root = -1
  for index in 0..<function.expressions.items.length() {
    match function.expressions.items[index] {
      As(_, Sint, Some(4)) if array_index_as == -1 => array_index_as = index
      GlobalVariable(global) if global.index() == 1 && texture_root == -1 =>
        texture_root = index
      _ => ()
    }
  }
  debug_inspect(array_index_as >= 0, content="true")
  debug_inspect(texture_root >= 0, content="true")
  debug_inspect(array_index_as < texture_root, content="true")
  match function.expressions.items[texture_root + 2] {
    ImageLoad(image, _, array_index, _, level) => {
      debug_inspect(image.index(), content="\{texture_root}")
      match array_index {
        Some(handle) =>
          debug_inspect(handle.index(), content="\{array_index_as}")
        None => abort("expected array index")
      }
      match level {
        Some(handle) =>
          debug_inspect(handle.index(), content="\{texture_root + 1}")
        None => abort("expected mip level")
      }
    }
    _ => abort("expected ImageLoad after texture root and level")
  }
}

///|
test "WGSL AST lowerer infers textureLoad image type from function arguments" {
  let source =
    #|fn get_occluder_depth(
    #|  coord: vec2<u32>,
    #|  depth_level: i32,
    #|  depth_pyramid: texture_2d<f32>
    #|) -> f32 {
    #|  return textureLoad(depth_pyramid, coord, depth_level).x;
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let function = module_.functions.items[0]
  let mut found = false
  for expression in function.expressions.items {
    match expression {
      ImageLoad(_, _, _, _, Some(_)) => found = true
      _ => ()
    }
  }
  debug_inspect(found, content="true")
}

///|
