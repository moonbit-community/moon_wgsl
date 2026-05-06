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
    content="2",
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
  debug_inspect(module_.functions.items.length(), content="1")
  debug_inspect(module_.entry_points.length(), content="1")
  debug_inspect(
    module_.entry_points[0].function.body.statements.length(),
    content="1",
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
    content="\"unknown WGSL identifier in IR lowering: missing_name\"",
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
  debug_inspect(emitted.contains("value = (value + 2u);"), content="true")
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
  match module_.entry_points[0].function.body.statements[0] {
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
  debug_inspect(function.local_variables.items.length(), content="2")
  match function.body.statements {
    [Loop(_, _, _), Store(_, _), Loop(_, _, _)] => ()
    _ => abort("expected lowered loops with explicit second initializer")
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("var i: u32 = 0u;"), content="true")
  debug_inspect(emitted.contains("loop {"), content="true")
  debug_inspect(emitted.contains("if (!(i < 4u)) {"), content="true")
  debug_inspect(emitted.contains("i = (i + 1);"), content="true")
  debug_inspect(emitted.contains("sum = (sum + 2u);"), content="true")
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
    #|var out_tex: texture_storage_2d<rgba8unorm, write>;
    #|
    #|@compute
    #|fn main() {
    #|  var uv: vec2f = vec2f(0.5, 0.25);
    #|  var color = textureSampleLevel(tex, samp, uv, 0.0);
    #|  var dims: u32 = textureDimensions(tex).x;
    #|  textureStore(out_tex, vec2u(0u, 0u), color);
    #|}
  let module_ = parse_wgsl_module_to_ir(source) catch {
    error => abort(error.message())
  }
  let emitted = emit_wgsl_module_from_ir(module_) catch {
    error => abort(error.message())
  }
  debug_inspect(
    emitted.contains("textureSampleLevel(tex, samp, uv, 0)"),
    content="true",
  )
  debug_inspect(emitted.contains("textureDimensions(tex).x"), content="true")
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
  debug_inspect(
    emitted.contains("textureSampleBias(tex, samp, uv, 0.25, vec2<i32>(0, 0))"),
    content="true",
  )
  debug_inspect(
    emitted.contains(
      "textureSampleGrad(tex, samp, uv, dx, dy, vec2<i32>(0, 0))",
    ),
    content="true",
  )
  debug_inspect(
    emitted.contains(
      "textureSampleLevel(tex_arr, samp, uv, 0u, 1, vec2<i32>(0, 0))",
    ),
    content="true",
  )
  debug_inspect(emitted.contains("textureNumLevels(tex)"), content="true")
  debug_inspect(
    emitted.contains(
      "textureSampleCompare(depth_tex, cmp_samp, uv, 0.5, vec2<i32>(0, 0))",
    ),
    content="true",
  )
  debug_inspect(
    emitted.contains(
      "textureSampleCompareLevel(depth_tex, cmp_samp, uv, 0.5, vec2<i32>(0, 0))",
    ),
    content="true",
  )
  debug_inspect(
    emitted.contains("textureGather(1, tex, samp, uv, vec2<i32>(0, 0))"),
    content="true",
  )
  debug_inspect(
    emitted.contains("textureGather(depth_tex, samp, uv, vec2<i32>(0, 0))"),
    content="true",
  )
  debug_inspect(
    emitted.contains(
      "textureGatherCompare(depth_arr, cmp_samp, uv, 0u, 0.5, vec2<i32>(0, 0))",
    ),
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
  debug_inspect(
    emitted.contains("textureLoad(ms_tex, coords, 0u)"),
    content="true",
  )
  debug_inspect(
    emitted.contains("textureLoad(arr_tex, coords, 0u, 0u)"),
    content="true",
  )
  debug_inspect(
    emitted.contains("textureLoad(storage_arr, coords, 0u)"),
    content="true",
  )
  debug_inspect(emitted.contains("textureNumSamples(ms_tex)"), content="true")
  debug_inspect(emitted.contains("textureNumLayers(arr_tex)"), content="true")
}
