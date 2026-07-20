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
test "wesl: module path from filesystem path follows Bevy semantics" {
  let absolute = ModulePath::from_path("/shaders/custom_material.wesl")
  let relative = ModulePath::from_path("../util.wesl")
  let package_path = ModulePath::from_path("mgstudio/shaders/util.wesl")

  debug_inspect(
    absolute.to_string(),
    content="\"package::shaders::custom_material\"",
  )
  debug_inspect(relative.to_string(), content="\"super::util\"")
  debug_inspect(package_path.to_string(), content="\"mgstudio::shaders::util\"")
}

///|
test "wesl: module path join matches relative import semantics" {
  let parent = try! parse_module_path("package::shaders")
  let child = try! parse_module_path("super::util")

  debug_inspect(
    parent.join_path(child).to_string(),
    content="\"package::util\"",
  )
}

///|
fn wesl_test_module_path_error_message(source : String) -> String {
  let path = parse_module_path(source) catch { err => return err.message() }
  ignore(path)
  abort("\{source}: expected parse failure")
}

///|
test "wesl: module path parser rejects misplaced reserved origins" {
  let valid = try! parse_module_path("super::super::util")
  debug_inspect(valid.to_string(), content="\"super::super::util\"")
  let cases = [
    ("package::self", "`self` must be a prefix of the module path"),
    ("self::super", "`super` must be a prefix of the module path"),
    ("demo::package", "`package` must be a prefix of the module path"),
    ("package::", "module name cannot be empty"),
  ]
  for case in cases {
    let (source, expected) = case
    debug_inspect(
      wesl_test_module_path_error_message(source),
      content="\"\{expected}\"",
    )
  }
}

///|
test "wesl: escape mangler matches Bevy naming" {
  let mangler = EscapeMangler::default()
  let package_path = try! parse_module_path("package::bevy_pbr::lighting")
  let slash_path = try! parse_module_path("bevy/pbr::lighting")

  debug_inspect(
    EscapeMangler::mangle(mangler, package_path, "item"),
    content="\"package__1bevy_pbr_lighting_item\"",
  )
  debug_inspect(
    EscapeMangler::mangle(mangler, slash_path, "item"),
    content="\"import_2_bevy_pbr_lighting_item\"",
  )
}

///|
test "wesl: mangler kind default is escape" {
  let path = try! parse_module_path("package::bevy_pbr::lighting")

  debug_inspect(
    ManglerKind::default().mangle(path, "item"),
    content="\"package__1bevy_pbr_lighting_item\"",
  )
}

///|
test "wesl: mangler kind can unmangle reversible schemes" {
  match ManglerKind::unmangle(Escape, "package__1bevy_pbr_lighting_item") {
    Some((path, item)) => {
      debug_inspect(path.to_string(), content="\"package::bevy_pbr::lighting\"")
      debug_inspect(item, content="\"item\"")
    }
    None => fail("expected escape unmangle")
  }
  match ManglerKind::unmangle(Escape, "import_2_bevy_pbr_item") {
    Some((path, item)) => {
      debug_inspect(path.to_string(), content="\"bevy/pbr\"")
      debug_inspect(item, content="\"item\"")
    }
    None => fail("expected dependency unmangle")
  }
  let unicode_path = try! parse_module_path("package::foo_bar")
  let unicode_mangled = ManglerKind::mangle(Unicode, unicode_path, "make_vec")
  match ManglerKind::unmangle(Unicode, unicode_mangled) {
    Some((path, item)) => {
      debug_inspect(path.to_string(), content="\"package::foo_bar\"")
      debug_inspect(item, content="\"make_vec\"")
    }
    None => fail("expected unicode unmangle")
  }
  debug_inspect(ManglerKind::unmangle(Hash, "item_123") is None, content="true")
}

///|
test "wesl: default result mirrors upstream empty output" {
  let result = CompileResult::default()
  let source_map = BasicSourceMap::new()
  let root_path = ModulePath::new_root()
  source_map.add_source(root_path, Some("root.wesl"), "fn helper() {}\n")
  source_map.set_default_source("fn helper() {}\n")
  source_map.add_decl("package_helper", root_path, "helper")

  debug_inspect(result.to_string(), content="\"\"")
  debug_inspect(result.has_sourcemap(), content="false")
  debug_inspect(result.modules.length(), content="0")
  debug_inspect(source_map.root.to_string(), content="\"package\"")
  debug_inspect(
    source_map.get_source(root_path),
    content="Some(\"fn helper() {}\\n\")",
  )
  debug_inspect(
    source_map.get_display_name(root_path),
    content="Some(\"root.wesl\")",
  )
  debug_inspect(
    source_map.get_default_source(),
    content="Some(\"fn helper() {}\\n\")",
  )
  debug_inspect(
    SourceMap::get_source(source_map, root_path),
    content="Some(\"fn helper() {}\\n\")",
  )
  debug_inspect(
    SourceMap::get_default_source(source_map),
    content="Some(\"fn helper() {}\\n\")",
  )
  debug_inspect(
    source_map.unmangle_identifier("package_helper"),
    content="Some(\"package::helper\")",
  )
  debug_inspect(
    source_map.unmangle_text(
      "error: duplicate package_helper and unknown".to_string(),
    ),
    content="\"error: duplicate package::helper and unknown\"",
  )
  debug_inspect(
    SourceMap::unmangle_text(
      NoSourceMap::default(),
      "error: duplicate package_helper".to_string(),
    ),
    content="\"error: duplicate package_helper\"",
  )
  match source_map.get_decl("package_helper") {
    Some((path, item)) => {
      debug_inspect(path.to_string(), content="\"package\"")
      debug_inspect(item, content="\"helper\"")
    }
    None => fail("expected source map declaration")
  }
}

///|
test "wesl: public const eval returns upstream literal result" {
  let result = eval_const(
    "@const fn test() -> i32 {\n  return 1 + 2;\n}", "test()",
  )
  inspect(result.to_string(), content="3i")
}

///|
test "wesl: public const eval supports typed function parameters" {
  let result = eval_const(
    "@const fn add(base: u32, extra: u32) -> u32 {\n  return base + extra;\n}", "add(40u, 2u)",
  )
  inspect(result.to_string(), content="42u")
}

///|
test "wesl: eval_str evaluates standalone const expressions" {
  inspect(eval_str("1 + 2").to_string(), content="3")
  inspect(eval_str("1u + 2u").to_string(), content="3u")
  inspect(eval_str("6u * 7u").to_string(), content="42u")
  inspect(eval_str("5 % 2").to_string(), content="1")
  inspect(eval_str("5u % 2u").to_string(), content="1u")
  inspect(eval_str("5i % 2i").to_string(), content="1i")
  inspect(eval_str("5.0 % 2.0").to_string(), content="1.0")
  inspect(eval_str("-5 % 2").to_string(), content="-1")
  inspect(eval_str("6 & 3").to_string(), content="2")
  inspect(eval_str("4 | 1").to_string(), content="5")
  inspect(eval_str("6 ^ 3").to_string(), content="5")
  inspect(eval_str("1 << 3").to_string(), content="8")
  inspect(eval_str("8 >> 1").to_string(), content="4")
  inspect(eval_str("6u & 3u").to_string(), content="2u")
  inspect(eval_str("1u << 3u").to_string(), content="8u")
  inspect(eval_str("8i >> 1u").to_string(), content="4i")
  inspect(eval_str("true & false").to_string(), content="false")
  inspect(eval_str("true | false").to_string(), content="true")
  inspect(eval_str("~0").to_string(), content="-1")
  inspect(eval_str("~0u").to_string(), content="4294967295u")
  inspect(eval_str("~0i").to_string(), content="-1i")
  inspect(eval_str("countOneBits(0)").to_string(), content="0")
  inspect(eval_str("countOneBits(7)").to_string(), content="3")
  inspect(eval_str("countOneBits(-1)").to_string(), content="64")
  inspect(eval_str("countOneBits(7u)").to_string(), content="3u")
  inspect(eval_str("countOneBits(7i)").to_string(), content="3i")
  inspect(eval_str("countOneBits(~0u)").to_string(), content="32u")
  inspect(eval_str("countLeadingZeros(0)").to_string(), content="64")
  inspect(eval_str("countLeadingZeros(-1)").to_string(), content="0")
  inspect(eval_str("countLeadingZeros(1u)").to_string(), content="31u")
  inspect(eval_str("countLeadingZeros(1i)").to_string(), content="31i")
  inspect(eval_str("countLeadingZeros(~0u)").to_string(), content="0u")
  inspect(eval_str("countTrailingZeros(0)").to_string(), content="64")
  inspect(eval_str("countTrailingZeros(-8)").to_string(), content="3")
  inspect(eval_str("countTrailingZeros(8u)").to_string(), content="3u")
  inspect(eval_str("countTrailingZeros(8i)").to_string(), content="3i")
  inspect(eval_str("countTrailingZeros(~0u)").to_string(), content="0u")
  inspect(eval_str("min(1, 2)").to_string(), content="1")
  inspect(eval_str("min(1, 2u)").to_string(), content="1u")
  inspect(eval_str("max(1u, 2u)").to_string(), content="2u")
  inspect(eval_str("min(1.0, 2)").to_string(), content="1.0")
  inspect(eval_str("min(1f, 2)").to_string(), content="1f")
  inspect(eval_str("abs(-3)").to_string(), content="3")
  inspect(eval_str("abs(-3i)").to_string(), content="3i")
  inspect(eval_str("abs(3u)").to_string(), content="3u")
  inspect(eval_str("abs(-3.0)").to_string(), content="3.0")
  inspect(eval_str("select(1, 2, true)").to_string(), content="2")
  inspect(eval_str("select(1, 2, false)").to_string(), content="1")
  inspect(eval_str("select(1u, 2u, true)").to_string(), content="2u")
  inspect(eval_str("select(true, false, true)").to_string(), content="false")
  inspect(eval_str("all(true)").to_string(), content="true")
  inspect(eval_str("any(false)").to_string(), content="false")
  inspect(eval_str("floor(1.9)").to_string(), content="1.0")
  inspect(eval_str("ceil(1.1)").to_string(), content="2.0")
  inspect(eval_str("round(1.5)").to_string(), content="2.0")
  inspect(eval_str("trunc(1.9)").to_string(), content="1.0")
  inspect(eval_str("fract(1.25)").to_string(), content="0.25")
  inspect(eval_str("sqrt(4.0)").to_string(), content="2.0")
  inspect(eval_str("inverseSqrt(4.0)").to_string(), content="0.5")
  inspect(eval_str("floor(1f)").to_string(), content="1f")
  inspect(eval_str("ceil(1.1f)").to_string(), content="2f")
  inspect(eval_str("round(1.5f)").to_string(), content="2f")
  inspect(eval_str("trunc(1.9f)").to_string(), content="1f")
  inspect(eval_str("fract(1.25f)").to_string(), content="0.25f")
  inspect(eval_str("sqrt(4f)").to_string(), content="2f")
  inspect(eval_str("inverseSqrt(4f)").to_string(), content="0.5f")
  inspect(eval_str("floor(1)").to_string(), content="1.0")
  inspect(eval_str("sqrt(4)").to_string(), content="2.0")
  inspect(eval_str("exp(1.0)").to_string(), content="2.718281828459045")
  inspect(eval_str("exp2(3.0)").to_string(), content="8.0")
  inspect(eval_str("log(1.0)").to_string(), content="0.0")
  inspect(eval_str("log2(8.0)").to_string(), content="3.0")
  inspect(eval_str("sin(0.0)").to_string(), content="0.0")
  inspect(eval_str("cos(0.0)").to_string(), content="1.0")
  inspect(eval_str("tan(0.0)").to_string(), content="0.0")
  inspect(eval_str("asin(0.0)").to_string(), content="0.0")
  inspect(eval_str("acos(1.0)").to_string(), content="0.0")
  inspect(eval_str("atan(1.0)").to_string(), content="0.7853981633974483")
  inspect(eval_str("sinh(0.0)").to_string(), content="0.0")
  inspect(eval_str("cosh(0.0)").to_string(), content="1.0")
  inspect(eval_str("tanh(0.0)").to_string(), content="0.0")
  inspect(eval_str("pow(2.0, 3.0)").to_string(), content="8.0")
  inspect(eval_str("atan2(1.0, 1.0)").to_string(), content="0.7853981633974483")
  inspect(eval_str("radians(180.0)").to_string(), content="3.141592653589793")
  inspect(eval_str("degrees(3.141592653589793)").to_string(), content="180.0")
  inspect(eval_str("exp(1f)").to_string(), content="2.7182817f")
  inspect(eval_str("pow(2f, 3)").to_string(), content="8f")
  inspect(eval_str("atan2(1f, 1f)").to_string(), content="0.7853982f")
  inspect(eval_str("sin(0)").to_string(), content="0.0")
  inspect(eval_str("pow(2, 3)").to_string(), content="8.0")
  inspect(eval_str("saturate(-0.5)").to_string(), content="0.0")
  inspect(eval_str("saturate(0.5)").to_string(), content="0.5")
  inspect(eval_str("saturate(2)").to_string(), content="1.0")
  inspect(eval_str("saturate(0.25f)").to_string(), content="0.25f")
  inspect(eval_str("saturate(2.5f)").to_string(), content="1f")
  inspect(eval_str("ldexp(1.0, 2)").to_string(), content="4.0")
  inspect(eval_str("ldexp(1.0, 2i)").to_string(), content="4f")
  inspect(eval_str("ldexp(1, -1i)").to_string(), content="0.5f")
  inspect(eval_str("ldexp(1.5, -1)").to_string(), content="0.75")
  inspect(eval_str("ldexp(1.5f, -1i)").to_string(), content="0.75f")
  inspect(eval_str("step(0.5, 0.25)").to_string(), content="0.0")
  inspect(eval_str("step(0.5, 0.75)").to_string(), content="1.0")
  inspect(eval_str("step(1f, 2f)").to_string(), content="1.0")
  inspect(eval_str("mix(1.0, 3.0, 0.25)").to_string(), content="1.5")
  inspect(eval_str("mix(1f, 3f, 0.25f)").to_string(), content="1.5f")
  inspect(eval_str("mix(1, 3, 0.25f)").to_string(), content="1.5f")
  inspect(eval_str("sign(-3)").to_string(), content="-1")
  inspect(eval_str("sign(-3.0)").to_string(), content="-1.0")
  inspect(eval_str("sign(0)").to_string(), content="0")
  inspect(eval_str("sign(2u)").to_string(), content="1u")
  inspect(
    eval_str("frexp(1.5)").to_string(),
    content="__frexp_result_abstract(0.75, 1)",
  )
  inspect(
    eval_str("frexp(-1.5)").to_string(),
    content="__frexp_result_abstract(-0.75, 1)",
  )
  inspect(
    eval_str("frexp(0.0)").to_string(),
    content="__frexp_result_abstract(0.0, 0)",
  )
  inspect(
    eval_str("frexp(4.0)").to_string(),
    content="__frexp_result_abstract(0.5, 3)",
  )
  inspect(
    eval_str("frexp(1.5f)").to_string(),
    content="__frexp_result_f32(0.75f, 1i)",
  )
  inspect(
    eval_str("frexp(0f)").to_string(),
    content="__frexp_result_f32(0f, 0i)",
  )
  inspect(eval_str("1.0 + 2.0").to_string(), content="3.0")
  inspect(eval_str("true").to_string(), content="true")
  inspect(eval_str("false").to_string(), content="false")
  inspect(eval_str("!true").to_string(), content="false")
  inspect(eval_str("1 == 1").to_string(), content="true")
  inspect(eval_str("1 != 2").to_string(), content="true")
  inspect(eval_str("1 < 2").to_string(), content="true")
  inspect(eval_str("2 <= 2").to_string(), content="true")
  inspect(eval_str("3 > 2").to_string(), content="true")
  inspect(eval_str("3 >= 4").to_string(), content="false")
  inspect(eval_str("true && false").to_string(), content="false")
  inspect(eval_str("true || false").to_string(), content="true")
  inspect(eval_str("(1 < 2) && !false").to_string(), content="true")
}

///|
test "wesl: eval result exposes scalar memory buffers" {
  let i32_buffer = eval_str("42i").to_buffer()
  match i32_buffer {
    Some(buffer) =>
      debug_inspect(
        buffer.to_array(),
        content=(
          #|[0x2a, 0x00, 0x00, 0x00]
        ),
      )
    None => fail("expected i32 buffer")
  }
  let u32_buffer = eval_str("42u").to_buffer()
  match u32_buffer {
    Some(buffer) =>
      debug_inspect(
        buffer.to_array(),
        content=(
          #|[0x2a, 0x00, 0x00, 0x00]
        ),
      )
    None => fail("expected u32 buffer")
  }
  let f32_buffer = eval_str("1.0f").to_buffer()
  match f32_buffer {
    Some(buffer) =>
      debug_inspect(
        buffer.to_array(),
        content=(
          #|[0x00, 0x00, 0x80, 0x3f]
        ),
      )
    None => fail("expected f32 buffer")
  }
}

///|
test "wesl: eval result rejects non-storable buffers" {
  match eval_str("true").to_buffer() {
    Some(_) => fail("expected bool to be non-storable")
    None => ()
  }
  match eval_str("42").to_buffer() {
    Some(_) => fail("expected abstract int to be non-storable")
    None => ()
  }
}

///|
test "wesl: eval result exposes vector memory buffers" {
  let result = eval_str("vec3<u32>(1u, 2u, 3u)")
  inspect(result.to_string(), content="vec3<u32>(1u, 2u, 3u)")
  match result.to_buffer() {
    Some(buffer) =>
      debug_inspect(
        buffer.to_array(),
        content=(
          #|[
          #|  0x01,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x02,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x03,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|]
        ),
      )
    None => fail("expected vector buffer")
  }
}

///|
test "wesl: const eval applies vector operators and builtins component-wise" {
  inspect(
    eval_str("vec3<u32>(1u, 2u, 3u) + 1u").to_string(),
    content="vec3<u32>(2u, 3u, 4u)",
  )
  inspect(
    eval_str("vec3<i32>(5i, -2i, 7i) - vec3<i32>(1i, 2i, 3i)").to_string(),
    content="vec3<i32>(4i, -4i, 4i)",
  )
  inspect(
    eval_str("abs(vec3<i32>(-1i, 0i, 2i))").to_string(),
    content="vec3<i32>(1i, 0i, 2i)",
  )
  inspect(
    eval_str("clamp(vec3<u32>(0u, 5u, 9u), 2u, 6u)").to_string(),
    content="vec3<u32>(2u, 5u, 6u)",
  )
  inspect(
    eval_str(
      "select(vec2<u32>(1u, 2u), vec2<u32>(3u, 4u), vec2<bool>(false, true))",
    ).to_string(),
    content="vec2<u32>(1u, 4u)",
  )
  inspect(
    eval_str("all(vec3<bool>(true, true, false))").to_string(),
    content="false",
  )
  inspect(
    eval_str("any(vec3<bool>(false, false, true))").to_string(),
    content="true",
  )
}

///|
test "wesl: eval_str reports known unimplemented builtins like upstream" {
  let result = try eval_str("fma(2.0, 0.5, 0.5)") catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  match result {
    Ok(_) => fail("expected fma to be a known unimplemented builtin")
    Err(err) =>
      debug_inspect(
        err.message().contains("not implemented: `fma`"),
        content="true",
      )
  }
  let arity_result = try eval_str("fma(1.0, 2.0)") catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  match arity_result {
    Ok(_) => fail("expected fma arity mismatch to remain a signature error")
    Err(err) =>
      debug_inspect(
        err
        .message()
        .contains(
          "invalid function call signature: `fma(AbstractFloat, AbstractFloat)`",
        ),
        content="true",
      )
  }
}

///|
test "wesl: compile result eval uses compiled const functions" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "@const\nfn test() -> u32 {\n  let base = 40u;\n  return base + 2u;\n}\n",
  )
  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default().keep_declarations(["test"]),
  )

  inspect(compiled.eval("test()").to_string(), content="42u")
}

///|
test "wesl: compile result exec runs simple entrypoint" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "const BASE: i32 = 40i;\n@compute @workgroup_size(1)\nfn main() -> i32 {\n  return BASE + 2i;\n}\n",
  )
  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default(),
  )
  let exec = compiled.exec("main", Inputs::new_zero_initialized(), [], [])

  match exec.return_value() {
    Some(value) => inspect(value, content="42i")
    None => fail("expected exec return value")
  }
  match exec.to_buffer() {
    Some(buffer) =>
      debug_inspect(
        buffer.to_array(),
        content=(
          #|[0x2a, 0x00, 0x00, 0x00]
        ),
      )
    None => fail("expected exec return buffer")
  }
  inspect(exec.to_string(), content="return: 42i")
}

///|
test "wesl: compile result exec passes scalar builtin inputs" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "@compute @workgroup_size(1)\nfn main(@builtin(vertex_index) vertex_index: u32) -> u32 {\n  return vertex_index + 1u;\n}\n",
  )
  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default(),
  )
  let inputs = Inputs::{
    ..Inputs::new_zero_initialized(),
    vertex_index: Some(41),
  }
  let exec = compiled.exec("main", inputs, [], [])
  match exec.return_value() {
    Some(value) => inspect(value, content="42u")
    None => fail("expected builtin input return")
  }
  match exec.to_buffer() {
    Some(buffer) =>
      debug_inspect(
        buffer.to_array(),
        content=(
          #|[0x2a, 0x00, 0x00, 0x00]
        ),
      )
    None => fail("expected builtin input return buffer")
  }
}

///|
test "wesl: compile result exec passes vector builtin inputs" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "@compute @workgroup_size(1)\nfn main(@builtin(global_invocation_id) id: vec3<u32>) -> vec3<u32> {\n  return id;\n}\n",
  )
  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default(),
  )
  let inputs = Inputs::{
    ..Inputs::new_zero_initialized(),
    global_invocation_id: Some([3, 4, 5]),
  }
  let exec = compiled.exec("main", inputs, [], [])
  match exec.return_value() {
    Some(value) => assert_true(value.contains("vec3<u32>"))
    None => fail("expected vector builtin input return")
  }
  match exec.to_buffer() {
    Some(buffer) =>
      debug_inspect(
        buffer.to_array(),
        content=(
          #|[
          #|  0x03,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x04,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x05,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|]
        ),
      )
    None => fail("expected vector builtin input return buffer")
  }
}

///|
test "wesl: compile result exec passes extended builtin inputs" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "@compute @workgroup_size(1)\nfn main(@builtin(subgroup_id) subgroup_id: u32, @builtin(num_subgroups) num_subgroups: u32, @builtin(primitive_index) primitive_index: u32, @builtin(view_index) view_index: u32) -> u32 {\n  return subgroup_id + num_subgroups + primitive_index + view_index;\n}\n",
  )
  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default(),
  )
  let inputs = Inputs::{
    ..Inputs::new_zero_initialized(),
    subgroup_id: Some(1),
    num_subgroups: Some(2),
    primitive_index: Some(4),
    view_index: Some(8),
  }
  let exec = compiled.exec("main", inputs, [], [])
  match exec.return_value() {
    Some(value) => inspect(value, content="15u")
    None => fail("expected extended builtin input return")
  }
}

///|
test "wesl: compile result exec passes user-defined scalar location inputs" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "@vertex\nfn main(@location(0) color: u32) -> u32 {\n  return color + 1u;\n}\n",
  )
  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default(),
  )
  let inputs = Inputs::{
    ..Inputs::new_zero_initialized(),
    user_defined: [{ location: 0, value: U32(41) }],
  }
  let exec = compiled.exec("main", inputs, [], [])
  match exec.return_value() {
    Some(value) => inspect(value, content="42u")
    None => fail("expected user-defined scalar input return")
  }
}

///|
test "wesl: compile result exec passes user-defined vector location inputs" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "@vertex\nfn main(@location(1) uv: vec2<f32>) -> vec2<f32> {\n  return uv;\n}\n",
  )
  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default(),
  )
  let inputs = Inputs::{
    ..Inputs::new_zero_initialized(),
    user_defined: [{ location: 1, value: F32Vector([1.0, 2.0]) }],
  }
  let exec = compiled.exec("main", inputs, [], [])
  match exec.return_value() {
    Some(value) => assert_true(value.contains("vec2<f32>"))
    None => fail("expected user-defined vector input return")
  }
  match exec.to_buffer() {
    Some(buffer) =>
      debug_inspect(
        buffer.to_array(),
        content=(
          #|[0x00, 0x00, 0x80, 0x3f, 0x00, 0x00, 0x00, 0x40]
        ),
      )
    None => fail("expected user-defined vector input return buffer")
  }
}

///|
test "wesl: compile result exec builds struct entrypoint inputs" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "struct VertexInput {\n  @builtin(vertex_index) index: u32,\n  @location(0) color: u32,\n}\n\n@vertex\nfn main(input: VertexInput) -> VertexInput {\n  return input;\n}\n",
  )
  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default(),
  )
  let inputs = Inputs::{
    ..Inputs::new_zero_initialized(),
    vertex_index: Some(7),
    user_defined: [{ location: 0, value: U32(35) }],
  }
  let exec = compiled.exec("main", inputs, [], [])
  match exec.return_value() {
    Some(value) => {
      assert_true(value.contains("index: 7u"))
      assert_true(value.contains("color: 35u"))
    }
    None => fail("expected struct input return")
  }
  match exec.to_buffer() {
    Some(buffer) =>
      debug_inspect(
        buffer.to_array(),
        content=(
          #|[0x07, 0x00, 0x00, 0x00, 0x23, 0x00, 0x00, 0x00]
        ),
      )
    None => fail("expected struct input return buffer")
  }
}

///|
test "wesl: compile result exec reads struct entrypoint fields" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "struct VertexInput {\n  @builtin(vertex_index) index: u32,\n  @location(0) color: u32,\n}\n\n@vertex\nfn main(input: VertexInput) -> u32 {\n  return input.index + input.color;\n}\n",
  )
  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default(),
  )
  let inputs = Inputs::{
    ..Inputs::new_zero_initialized(),
    vertex_index: Some(7),
    user_defined: [{ location: 0, value: U32(35) }],
  }
  let exec = compiled.exec("main", inputs, [], [])
  match exec.return_value() {
    Some(value) => inspect(value, content="42u")
    None => fail("expected struct field return")
  }
}

///|
test "wesl: compile result exec evaluates vector swizzles" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "@vertex\nfn main(@location(0) uv: vec3<f32>) -> vec2<f32> {\n  return uv.yx;\n}\n",
  )
  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default(),
  )
  let inputs = Inputs::{
    ..Inputs::new_zero_initialized(),
    user_defined: [{ location: 0, value: F32Vector([1.0, 2.0, 3.0]) }],
  }
  let exec = compiled.exec("main", inputs, [], [])
  match exec.return_value() {
    Some(value) => assert_true(value.contains("vec2<f32>"))
    None => fail("expected swizzle return")
  }
  match exec.to_buffer() {
    Some(buffer) =>
      debug_inspect(
        buffer.to_array(),
        content=(
          #|[0x00, 0x00, 0x00, 0x40, 0x00, 0x00, 0x80, 0x3f]
        ),
      )
    None => fail("expected swizzle return buffer")
  }
}

///|
test "wesl: compile result exec evaluates vector dynamic indexing" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "@compute @workgroup_size(1)\nfn main(@location(0) value: vec3<f32>, @builtin(local_invocation_index) index: u32) -> f32 {\n  return value[index];\n}\n",
  )
  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default(),
  )
  let inputs = Inputs::{
    ..Inputs::new_zero_initialized(),
    local_invocation_index: Some(2),
    user_defined: [{ location: 0, value: F32Vector([1.0, 2.0, 3.0]) }],
  }
  let exec = compiled.exec("main", inputs, [], [])
  match exec.to_buffer() {
    Some(buffer) =>
      debug_inspect(
        buffer.to_array(),
        content=(
          #|[0x00, 0x00, 0x40, 0x40]
        ),
      )
    None => fail("expected indexed vector return buffer")
  }
}

///|
test "wesl: compile result exec evaluates if else control flow" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "@compute @workgroup_size(1)\nfn main(@builtin(local_invocation_index) index: u32) -> u32 {\n  if (index == 0u) {\n    return 1u;\n  } else {\n    return index + 1u;\n  }\n}\n",
  )
  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default(),
  )
  let first = compiled.exec(
    "main",
    { ..Inputs::new_zero_initialized(), local_invocation_index: Some(0) },
    [],
    [],
  )
  match first.return_value() {
    Some(value) => inspect(value, content="1u")
    None => fail("expected first branch return")
  }
  let second = compiled.exec(
    "main",
    { ..Inputs::new_zero_initialized(), local_invocation_index: Some(41) },
    [],
    [],
  )
  match second.return_value() {
    Some(value) => inspect(value, content="42u")
    None => fail("expected else branch return")
  }
}

///|
test "wesl: compile result exec evaluates while break continue control flow" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "@compute @workgroup_size(1)\nfn main(@builtin(local_invocation_index) limit: u32) -> u32 {\n  var i: u32 = 0u;\n  var sum: u32 = 0u;\n  while (i < limit) {\n    i = i + 1u;\n    if (i == 2u) {\n      continue;\n    }\n    if (i == 5u) {\n      break;\n    }\n    sum = sum + i;\n  }\n  return sum;\n}\n",
  )
  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default(),
  )
  let exec = compiled.exec(
    "main",
    { ..Inputs::new_zero_initialized(), local_invocation_index: Some(10) },
    [],
    [],
  )
  match exec.return_value() {
    Some(value) => inspect(value, content="8u")
    None => fail("expected while loop return")
  }
  match exec.to_buffer() {
    Some(buffer) =>
      debug_inspect(
        buffer.to_array(),
        content=(
          #|[0x08, 0x00, 0x00, 0x00]
        ),
      )
    None => fail("expected while loop return buffer")
  }
}

///|
test "wesl: compile result exec evaluates for loop control flow" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "@compute @workgroup_size(1)\nfn main(@builtin(local_invocation_index) limit: u32) -> u32 {\n  var sum: u32 = 0u;\n  for (var i: u32 = 0u; i < limit; i++) {\n    if (i == 2u) {\n      continue;\n    }\n    if (i == 5u) {\n      break;\n    }\n    sum = sum + i;\n  }\n  return sum;\n}\n",
  )
  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default(),
  )
  let exec = compiled.exec(
    "main",
    { ..Inputs::new_zero_initialized(), local_invocation_index: Some(10) },
    [],
    [],
  )
  match exec.return_value() {
    Some(value) => inspect(value, content="8u")
    None => fail("expected for loop return")
  }
  match exec.to_buffer() {
    Some(buffer) =>
      debug_inspect(
        buffer.to_array(),
        content=(
          #|[0x08, 0x00, 0x00, 0x00]
        ),
      )
    None => fail("expected for loop return buffer")
  }
}

///|
test "wesl: compile result exec runs for update after continue" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "@compute @workgroup_size(1)\nfn main() -> u32 {\n  var sum: u32 = 0u;\n  for (var i: u32 = 0u; i < 4u; i = i + 1u) {\n    if (i < 3u) {\n      continue;\n    }\n    sum = sum + i;\n  }\n  return sum;\n}\n",
  )
  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default(),
  )
  let exec = compiled.exec("main", Inputs::new_zero_initialized(), [], [])
  match exec.return_value() {
    Some(value) => inspect(value, content="3u")
    None => fail("expected for continue update return")
  }
}

///|
test "wesl: compile result exec evaluates loop break continue control flow" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "@compute @workgroup_size(1)\nfn main() -> u32 {\n  var i: u32 = 0u;\n  var sum: u32 = 0u;\n  loop {\n    i++;\n    if (i == 2u) {\n      continue;\n    }\n    if (i == 5u) {\n      break;\n    }\n    sum += i;\n  }\n  return sum;\n}\n",
  )
  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default(),
  )
  let exec = compiled.exec("main", Inputs::new_zero_initialized(), [], [])
  match exec.return_value() {
    Some(value) => inspect(value, content="8u")
    None => fail("expected loop return")
  }
}

///|
test "wesl: compile result exec evaluates loop continuing break-if" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "@compute @workgroup_size(1)\nfn main() -> u32 {\n  var i: u32 = 0u;\n  var sum: u32 = 0u;\n  loop {\n    i += 1u;\n    if (i == 2u) {\n      continue;\n    }\n    sum += i;\n    continuing {\n      break if i == 5u;\n    }\n  }\n  return sum;\n}\n",
  )
  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default(),
  )
  let exec = compiled.exec("main", Inputs::new_zero_initialized(), [], [])
  match exec.return_value() {
    Some(value) => inspect(value, content="13u")
    None => fail("expected loop continuing return")
  }
}

///|
test "wesl: compile result exec evaluates switch cases and default" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "@compute @workgroup_size(1)\nfn main(@builtin(local_invocation_index) selector: u32) -> u32 {\n  switch selector {\n    case 0u: {\n      return 10u;\n    }\n    case 1u, 2u: {\n      return 20u;\n    }\n    default: {\n      return 30u;\n    }\n  }\n}\n",
  )
  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default(),
  )
  let first = compiled.exec(
    "main",
    { ..Inputs::new_zero_initialized(), local_invocation_index: Some(2) },
    [],
    [],
  )
  match first.return_value() {
    Some(value) => inspect(value, content="20u")
    None => fail("expected switch case return")
  }
  let second = compiled.exec(
    "main",
    { ..Inputs::new_zero_initialized(), local_invocation_index: Some(7) },
    [],
    [],
  )
  match second.return_value() {
    Some(value) => inspect(value, content="30u")
    None => fail("expected switch default return")
  }
}

///|
test "wesl: compile result exec keeps switch break scoped" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "@compute @workgroup_size(1)\nfn main() -> u32 {\n  var i: u32 = 0u;\n  var sum: u32 = 0u;\n  loop {\n    i++;\n    switch i {\n      case 1u: {\n        sum += 10u;\n        break;\n      }\n      case 2u, 3u: {\n        continue;\n      }\n      case 4u: {\n        break;\n      }\n      default: {\n        sum += 1u;\n      }\n    }\n    if (i == 4u) {\n      break;\n    }\n  }\n  return sum + i;\n}\n",
  )
  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default(),
  )
  let exec = compiled.exec("main", Inputs::new_zero_initialized(), [], [])
  match exec.return_value() {
    Some(value) => inspect(value, content="14u")
    None => fail("expected scoped switch break return")
  }
}

///|
test "wesl: compile result exec rejects non-storable return buffers" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "@compute @workgroup_size(1)\nfn main() -> bool {\n  return true;\n}\n",
  )
  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default(),
  )
  let exec = compiled.exec("main", Inputs::new_zero_initialized(), [], [])

  debug_inspect(exec.return_value(), content="Some(\"true\")")
  inspect(exec.to_buffer() is None, content="true")
}

///|
test "wesl: compile result exec applies override values" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "override SCALE: u32 = 2u;\n@compute @workgroup_size(1)\nfn main() -> u32 {\n  return SCALE + 1u;\n}\n",
  )
  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default(),
  )

  let default_exec = compiled.exec("main", Inputs::new_zero_initialized(), [], [])
  match default_exec.return_value() {
    Some(value) => inspect(value, content="3u")
    None => fail("expected default override return")
  }

  let overridden = compiled.exec("main", Inputs::new_zero_initialized(), [], [
    { name: "SCALE", value: "41u" },
  ])
  match overridden.return_value() {
    Some(value) => inspect(value, content="42u")
    None => fail("expected overridden return")
  }
  match overridden.to_buffer() {
    Some(buffer) =>
      debug_inspect(
        buffer.to_array(),
        content=(
          #|[0x2a, 0x00, 0x00, 0x00]
        ),
      )
    None => fail("expected override return buffer")
  }
}

///|
test "wesl: compile result exec rejects uninitialized overrides" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "override SCALE: u32;\n@compute @workgroup_size(1)\nfn main() -> u32 {\n  return SCALE;\n}\n",
  )
  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default(),
  )
  let exec = try
    compiled.exec("main", Inputs::new_zero_initialized(), [], [])
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  match exec {
    Err(Validation(message)) =>
      assert_true(message.contains("uninitialized override"))
    _ => fail("expected uninitialized override to be rejected")
  }
}

///|
test "wesl: compile result exec reads scalar resource buffers" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "@group(0) @binding(0) var<uniform> DATA: u32;\n@compute @workgroup_size(1)\nfn main() -> u32 {\n  return DATA + 1u;\n}\n",
  )
  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default(),
  )
  let exec = compiled.exec(
    "main",
    Inputs::new_zero_initialized(),
    [
      {
        group: 0,
        binding: 0,
        kind: "uniform",
        data: Bytes::from_array([b'\x29', b'\x00', b'\x00', b'\x00']),
      },
    ],
    [],
  )
  match exec.return_value() {
    Some(value) => inspect(value, content="42u")
    None => fail("expected resource return")
  }
  match exec.to_buffer() {
    Some(buffer) =>
      debug_inspect(
        buffer.to_array(),
        content=(
          #|[0x2a, 0x00, 0x00, 0x00]
        ),
      )
    None => fail("expected resource return buffer")
  }
  match exec.resource(0, 0) {
    Some(resource) => {
      inspect(resource.kind, content="uniform")
      debug_inspect(
        resource.data.to_array(),
        content=(
          #|[0x29, 0x00, 0x00, 0x00]
        ),
      )
    }
    None => fail("expected resource")
  }
}

///|
test "wesl: compile result exec writes scalar storage resources" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "@group(0) @binding(0) var<storage, read_write> DATA: u32;\n@compute @workgroup_size(1)\nfn main() -> u32 {\n  DATA += 1u;\n  return DATA;\n}\n",
  )
  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default(),
  )
  let exec = compiled.exec(
    "main",
    Inputs::new_zero_initialized(),
    [
      {
        group: 0,
        binding: 0,
        kind: "storage",
        data: Bytes::from_array([b'\x29', b'\x00', b'\x00', b'\x00']),
      },
    ],
    [],
  )
  match exec.return_value() {
    Some(value) => inspect(value, content="42u")
    None => fail("expected storage write return")
  }
  match exec.resource(0, 0) {
    Some(resource) =>
      debug_inspect(
        resource.data.to_array(),
        content=(
          #|[0x2a, 0x00, 0x00, 0x00]
        ),
      )
    None => fail("expected storage resource")
  }
}

///|
test "wesl: compile result exec writes void entrypoint storage resources" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "@group(0) @binding(0) var<storage, read_write> DATA: u32;\n@compute @workgroup_size(1)\nfn main() {\n  DATA += 1u;\n  return;\n  DATA += 10u;\n}\n",
  )
  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default(),
  )
  let exec = compiled.exec(
    "main",
    Inputs::new_zero_initialized(),
    [
      {
        group: 0,
        binding: 0,
        kind: "storage",
        data: Bytes::from_array([b'\x29', b'\x00', b'\x00', b'\x00']),
      },
    ],
    [],
  )
  match exec.return_value() {
    Some(value) => fail("unexpected void return \{value}")
    None => ()
  }
  match exec.resource(0, 0) {
    Some(resource) =>
      debug_inspect(
        resource.data.to_array(),
        content=(
          #|[0x2a, 0x00, 0x00, 0x00]
        ),
      )
    None => fail("expected storage resource")
  }
}

///|
test "wesl: compile result exec increments struct storage fields" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "struct Data {\n  a: u32,\n  b: u32,\n}\n\n@group(0) @binding(0) var<storage, read_write> DATA: Data;\n@compute @workgroup_size(1)\nfn main() {\n  DATA.a++;\n  DATA.b--;\n}\n",
  )
  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default(),
  )
  let exec = compiled.exec(
    "main",
    Inputs::new_zero_initialized(),
    [
      {
        group: 0,
        binding: 0,
        kind: "storage",
        data: Bytes::from_array([
          b'\x01', b'\x00', b'\x00', b'\x00', b'\x07', b'\x00', b'\x00', b'\x00',
        ]),
      },
    ],
    [],
  )
  match exec.resource(0, 0) {
    Some(resource) =>
      debug_inspect(
        resource.data.to_array(),
        content=(
          #|[0x02, 0x00, 0x00, 0x00, 0x06, 0x00, 0x00, 0x00]
        ),
      )
    None => fail("expected storage resource")
  }
}

///|
test "wesl: compile result exec increments vector storage components" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "@group(0) @binding(0) var<storage, read_write> DATA: vec4<u32>;\n@compute @workgroup_size(1)\nfn main() {\n  DATA.x++;\n  DATA.w--;\n}\n",
  )
  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default(),
  )
  let exec = compiled.exec(
    "main",
    Inputs::new_zero_initialized(),
    [
      {
        group: 0,
        binding: 0,
        kind: "storage",
        data: Bytes::from_array([
          b'\x01', b'\x00', b'\x00', b'\x00', b'\x02', b'\x00', b'\x00', b'\x00',
          b'\x03', b'\x00', b'\x00', b'\x00', b'\x04', b'\x00', b'\x00', b'\x00',
        ]),
      },
    ],
    [],
  )
  match exec.resource(0, 0) {
    Some(resource) =>
      debug_inspect(
        resource.data.to_array(),
        content=(
          #|[
          #|  0x02,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x02,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x03,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x03,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|]
        ),
      )
    None => fail("expected storage resource")
  }
}

///|
test "wesl: compile result exec reads vector resource buffers" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "@group(0) @binding(0) var<uniform> DATA: vec4<f32>;\n@compute @workgroup_size(1)\nfn main() -> vec4<f32> {\n  return DATA + vec4<f32>(1.0f);\n}\n",
  )
  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default(),
  )
  let input = Bytes::from_array([
    b'\x00', b'\x00', b'\x80', b'\x3F', b'\x00', b'\x00', b'\x00', b'\x40', b'\x00',
    b'\x00', b'\x40', b'\x40', b'\x00', b'\x00', b'\x80', b'\x40',
  ])
  let exec = compiled.exec(
    "main",
    Inputs::new_zero_initialized(),
    [{ group: 0, binding: 0, kind: "uniform", data: input }],
    [],
  )
  match exec.return_value() {
    Some(value) => assert_true(value.contains("vec4<f32>"))
    None => fail("expected vector resource return")
  }
  match exec.to_buffer() {
    Some(buffer) =>
      debug_inspect(
        buffer.to_array(),
        content=(
          #|[
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x40,
          #|  0x00,
          #|  0x00,
          #|  0x40,
          #|  0x40,
          #|  0x00,
          #|  0x00,
          #|  0x80,
          #|  0x40,
          #|  0x00,
          #|  0x00,
          #|  0xa0,
          #|  0x40,
          #|]
        ),
      )
    None => fail("expected vector resource return buffer")
  }
}

///|
test "wesl: compile result exec reads struct resource buffers" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "struct Data {\n  a: u32,\n  b: vec3<f32>,\n  c: u32,\n}\n\n@group(0) @binding(0) var<uniform> DATA: Data;\n@compute @workgroup_size(1)\nfn main() -> Data {\n  return DATA;\n}\n",
  )
  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default(),
  )
  let input = Bytes::from_array([
    b'\x2A', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
    b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
    b'\x80', b'\x3F', b'\x00', b'\x00', b'\x00', b'\x40', b'\x00', b'\x00', b'\x40',
    b'\x40', b'\x07', b'\x00', b'\x00', b'\x00',
  ])
  let exec = compiled.exec(
    "main",
    Inputs::new_zero_initialized(),
    [{ group: 0, binding: 0, kind: "uniform", data: input }],
    [],
  )
  match exec.return_value() {
    Some(value) => {
      assert_true(value.contains("Data{"))
      assert_true(value.contains("vec3<f32>"))
    }
    None => fail("expected struct resource return")
  }
  match exec.to_buffer() {
    Some(buffer) =>
      debug_inspect(
        buffer.to_array(),
        content=(
          #|[
          #|  0x2a,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x80,
          #|  0x3f,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x40,
          #|  0x00,
          #|  0x00,
          #|  0x40,
          #|  0x40,
          #|  0x07,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|]
        ),
      )
    None => fail("expected struct resource return buffer")
  }
}

///|
test "wesl: struct resource layout honors member align and size attributes" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "struct Data {\n  a: u32,\n  @align(16) @size(16) b: u32,\n  c: u32,\n}\n\n@group(0) @binding(0) var<uniform> DATA: Data;\n@compute @workgroup_size(1)\nfn main() -> Data {\n  return DATA;\n}\n",
  )
  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default(),
  )
  let input = Bytes::from_array([
    b'\x01', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
    b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x02', b'\x00',
    b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
    b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x03', b'\x00', b'\x00', b'\x00',
  ])
  let exec = compiled.exec(
    "main",
    Inputs::new_zero_initialized(),
    [{ group: 0, binding: 0, kind: "uniform", data: input }],
    [],
  )
  match exec.to_buffer() {
    Some(buffer) =>
      debug_inspect(
        buffer.to_array(),
        content=(
          #|[
          #|  0x01,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x02,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x03,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|]
        ),
      )
    None => fail("expected struct resource return buffer")
  }
}

///|
test "wesl: compile result exec reads array resource buffers with stride padding" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "@group(0) @binding(0) var<uniform> DATA: array<vec3<f32>, 2>;\n@compute @workgroup_size(1)\nfn main() -> array<vec3<f32>, 2> {\n  return DATA;\n}\n",
  )
  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default(),
  )
  let input = Bytes::from_array([
    b'\x00', b'\x00', b'\x80', b'\x3F', b'\x00', b'\x00', b'\x00', b'\x40', b'\x00',
    b'\x00', b'\x40', b'\x40', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
    b'\x80', b'\x40', b'\x00', b'\x00', b'\xA0', b'\x40', b'\x00', b'\x00', b'\xC0',
    b'\x40', b'\x00', b'\x00', b'\x00', b'\x00',
  ])
  let exec = compiled.exec(
    "main",
    Inputs::new_zero_initialized(),
    [{ group: 0, binding: 0, kind: "uniform", data: input }],
    [],
  )
  match exec.return_value() {
    Some(value) => assert_true(value.contains("array<vec3<f32>>"))
    None => fail("expected array resource return")
  }
  match exec.to_buffer() {
    Some(buffer) =>
      debug_inspect(
        buffer.to_array(),
        content=(
          #|[
          #|  0x00,
          #|  0x00,
          #|  0x80,
          #|  0x3f,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x40,
          #|  0x00,
          #|  0x00,
          #|  0x40,
          #|  0x40,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x80,
          #|  0x40,
          #|  0x00,
          #|  0x00,
          #|  0xa0,
          #|  0x40,
          #|  0x00,
          #|  0x00,
          #|  0xc0,
          #|  0x40,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|]
        ),
      )
    None => fail("expected array resource return buffer")
  }
}

///|
test "wesl: compile result exec indexes storage array resources" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "@group(0) @binding(0) var<storage> DATA: array<u32, 4>;\n@compute @workgroup_size(1)\nfn main(@builtin(local_invocation_index) index: u32) -> u32 {\n  return DATA[index] + 1u;\n}\n",
  )
  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default(),
  )
  let input = Bytes::from_array([
    b'\x0A', b'\x00', b'\x00', b'\x00', b'\x14', b'\x00', b'\x00', b'\x00', b'\x1E',
    b'\x00', b'\x00', b'\x00', b'\x28', b'\x00', b'\x00', b'\x00',
  ])
  let exec = compiled.exec(
    "main",
    { ..Inputs::new_zero_initialized(), local_invocation_index: Some(2) },
    [{ group: 0, binding: 0, kind: "storage", data: input }],
    [],
  )
  match exec.return_value() {
    Some(value) => inspect(value, content="31u")
    None => fail("expected indexed array resource return")
  }
}

///|
test "wesl: compile result exec writes storage array elements" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "@group(0) @binding(0) var<storage, read_write> DATA: array<u32, 4>;\n@compute @workgroup_size(1)\nfn main(@builtin(local_invocation_index) index: u32) -> u32 {\n  DATA[index] += 5u;\n  return DATA[index];\n}\n",
  )
  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default(),
  )
  let input = Bytes::from_array([
    b'\x0A', b'\x00', b'\x00', b'\x00', b'\x14', b'\x00', b'\x00', b'\x00', b'\x1E',
    b'\x00', b'\x00', b'\x00', b'\x28', b'\x00', b'\x00', b'\x00',
  ])
  let exec = compiled.exec(
    "main",
    { ..Inputs::new_zero_initialized(), local_invocation_index: Some(2) },
    [{ group: 0, binding: 0, kind: "storage", data: input }],
    [],
  )
  match exec.return_value() {
    Some(value) => inspect(value, content="35u")
    None => fail("expected storage array write return")
  }
  match exec.resource(0, 0) {
    Some(resource) =>
      debug_inspect(
        resource.data.to_array(),
        content=(
          #|[
          #|  0x0a,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x14,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x23,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x28,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|]
        ),
      )
    None => fail("expected storage array resource")
  }
}

///|
test "wesl: compile result exec increments indexed storage in for update" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "@group(0) @binding(0) var<storage, read_write> DATA: array<u32, 4>;\n@compute @workgroup_size(1)\nfn main() {\n  for (var i: u32 = 0u; i < 3u; DATA[i]++) {\n    i++;\n  }\n}\n",
  )
  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default(),
  )
  let input = Bytes::from_array([
    b'\x0A', b'\x00', b'\x00', b'\x00', b'\x14', b'\x00', b'\x00', b'\x00', b'\x1E',
    b'\x00', b'\x00', b'\x00', b'\x28', b'\x00', b'\x00', b'\x00',
  ])
  let exec = compiled.exec(
    "main",
    Inputs::new_zero_initialized(),
    [{ group: 0, binding: 0, kind: "storage", data: input }],
    [],
  )
  match exec.resource(0, 0) {
    Some(resource) =>
      debug_inspect(
        resource.data.to_array(),
        content=(
          #|[
          #|  0x0a,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x15,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x1f,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x29,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|]
        ),
      )
    None => fail("expected storage array resource")
  }
}

///|
test "wesl: compile result exec evaluates runtime array length" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "@group(0) @binding(0) var<storage> DATA: array<u32>;\n@compute @workgroup_size(1)\nfn main() -> u32 {\n  return arrayLength(&DATA);\n}\n",
  )
  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default(),
  )
  let input = Bytes::from_array([
    b'\x0A', b'\x00', b'\x00', b'\x00', b'\x14', b'\x00', b'\x00', b'\x00', b'\x1E',
    b'\x00', b'\x00', b'\x00',
  ])
  let exec = compiled.exec(
    "main",
    Inputs::new_zero_initialized(),
    [{ group: 0, binding: 0, kind: "storage", data: input }],
    [],
  )
  match exec.return_value() {
    Some(value) => inspect(value, content="3u")
    None => fail("expected runtime array length")
  }
  match exec.to_buffer() {
    Some(buffer) =>
      debug_inspect(
        buffer.to_array(),
        content=(
          #|[0x03, 0x00, 0x00, 0x00]
        ),
      )
    None => fail("expected runtime array length buffer")
  }
}

///|
test "wesl: compile result exec evaluates struct runtime array length" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "struct Data {\n  header: u32,\n  values: array<u32>,\n}\n\n@group(0) @binding(0) var<storage> DATA: Data;\n@compute @workgroup_size(1)\nfn main() -> u32 {\n  return DATA.header + arrayLength(&DATA.values);\n}\n",
  )
  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default(),
  )
  let input = Bytes::from_array([
    b'\x05', b'\x00', b'\x00', b'\x00', b'\x0A', b'\x00', b'\x00', b'\x00', b'\x14',
    b'\x00', b'\x00', b'\x00', b'\x1E', b'\x00', b'\x00', b'\x00',
  ])
  let exec = compiled.exec(
    "main",
    Inputs::new_zero_initialized(),
    [{ group: 0, binding: 0, kind: "storage", data: input }],
    [],
  )
  match exec.return_value() {
    Some(value) => inspect(value, content="8u")
    None => fail("expected struct runtime array length")
  }
}

///|
test "wesl: compile result exec reads matrix resource buffers as padded columns" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "@group(0) @binding(0) var<uniform> DATA: mat3x3<f32>;\n@compute @workgroup_size(1)\nfn main() -> mat3x3<f32> {\n  return DATA;\n}\n",
  )
  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default(),
  )
  let input = Bytes::from_array([
    b'\x00', b'\x00', b'\x80', b'\x3F', b'\x00', b'\x00', b'\x00', b'\x40', b'\x00',
    b'\x00', b'\x40', b'\x40', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
    b'\x80', b'\x40', b'\x00', b'\x00', b'\xA0', b'\x40', b'\x00', b'\x00', b'\xC0',
    b'\x40', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\xE0', b'\x40',
    b'\x00', b'\x00', b'\x00', b'\x41', b'\x00', b'\x00', b'\x10', b'\x41', b'\x00',
    b'\x00', b'\x00', b'\x00',
  ])
  let exec = compiled.exec(
    "main",
    Inputs::new_zero_initialized(),
    [{ group: 0, binding: 0, kind: "uniform", data: input }],
    [],
  )
  match exec.return_value() {
    Some(value) => assert_true(value.contains("mat3x3<f32>"))
    None => fail("expected matrix resource return")
  }
  match exec.to_buffer() {
    Some(buffer) =>
      debug_inspect(
        buffer.to_array(),
        content=(
          #|[
          #|  0x00,
          #|  0x00,
          #|  0x80,
          #|  0x3f,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x40,
          #|  0x00,
          #|  0x00,
          #|  0x40,
          #|  0x40,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x80,
          #|  0x40,
          #|  0x00,
          #|  0x00,
          #|  0xa0,
          #|  0x40,
          #|  0x00,
          #|  0x00,
          #|  0xc0,
          #|  0x40,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0xe0,
          #|  0x40,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x41,
          #|  0x00,
          #|  0x00,
          #|  0x10,
          #|  0x41,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|  0x00,
          #|]
        ),
      )
    None => fail("expected matrix resource return buffer")
  }
}

///|
test "wesl: compile result exec rejects incompatible scalar resource buffers" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "@group(0) @binding(0) var<uniform> DATA: u32;\n@compute @workgroup_size(1)\nfn main() -> u32 {\n  return DATA;\n}\n",
  )
  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default(),
  )
  let exec = try
    compiled.exec(
      "main",
      Inputs::new_zero_initialized(),
      [
        {
          group: 0,
          binding: 0,
          kind: "uniform",
          data: Bytes::from_array([b'\x2A']),
        },
      ],
      [],
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  match exec {
    Err(Validation(message)) => assert_true(message.contains("incompatible"))
    _ => fail("expected incompatible resource buffer to be rejected")
  }
}

///|
test "wesl: compile result writes build artifacts" {
  let out_dir = "_build/compile_result_artifact"
  wesl_test_ensure_dir("_build")
  wesl_test_ensure_dir(out_dir)
  let resolver = VirtualResolver::new()
  let root = ModulePath::from_path("/artifact")
  resolver.add_module(root, "fn artifact() {}\n")
  let result = Wesl::new_barebones()
    .set_custom_resolver(resolver)
    .set_options(CompileOptions::default().with_strip(false))
    .compile(root)
  result.write_artifact("artifact_shader", out_dir=Some(out_dir))
  let artifact = try! @fs.read_file_to_string(out_dir + "/artifact_shader.wgsl")
  inspect(artifact.contains("fn artifact() {}"), content="true")
  let invalid = try
    result.write_artifact("nested/artifact", out_dir=Some(out_dir))
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  match invalid {
    Err(Artifact(_)) => ()
    _ => fail("expected invalid artifact names to be rejected")
  }
}

///|
test "wesl: compile result eval sees global const context" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "const BASE: u32 = 40u;\n\n@const\nfn add_two() -> u32 {\n  return BASE + 2u;\n}\n",
  )
  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default().keep_declarations(["BASE", "add_two"]),
  )

  inspect(compiled.eval("BASE + add_two()").to_string(), content="82u")
}

///|
test "wesl: compile result eval passes arguments into const functions" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "const BASE: u32 = 40u;\n\n@const\nfn add(base: u32, extra: u32) -> u32 {\n  return base + extra;\n}\n",
  )
  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default().keep_declarations(["BASE", "add"]),
  )

  inspect(compiled.eval("add(BASE, 2u)").to_string(), content="42u")
}

///|
test "wesl: compile result eval handles multiplied global constants" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "const PI: f32 = 3.0;\nconst TAU: f32 = PI * 2.0;\n",
  )
  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default().keep_declarations(["PI", "TAU"]),
  )

  inspect(compiled.eval("TAU").to_string(), content="6f")
}

///|
test "wesl: compile result eval handles bool global constants" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "const FLAG: bool = true;\nconst DISABLED: bool = !FLAG;\nconst HAS_SIZE: bool = 2u >= 2u;\nconst SIZE: u32 = 2u;\n",
  )
  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default().keep_declarations([
      "FLAG", "DISABLED", "HAS_SIZE", "SIZE",
    ]),
  )

  inspect(compiled.eval("FLAG").to_string(), content="true")
  inspect(compiled.eval("DISABLED").to_string(), content="false")
  inspect(compiled.eval("HAS_SIZE").to_string(), content="true")
  inspect(compiled.eval("SIZE").to_string(), content="2u")
}

///|
test "wesl: feature default and bool conversion match upstream" {
  debug_inspect(Feature::default(), content="Disable")
  debug_inspect(Feature::from_bool(true), content="Enable")
  debug_inspect(Feature::from_bool(false), content="Disable")
}

///|
test "wesl: compile resolves imports and conditional translation" {
  let resolver = VirtualResolver::new()
  let util_path = ModulePath::from_path("/shaders/util")
  let root_path = ModulePath::from_path("/shaders/custom_material")
  resolver.add_module(
    util_path, "fn make_polka_dots(v: f32) -> f32 {\n  @if(PARTY_MODE) {\n    return v * 2.0;\n  } @else {\n    return v;\n  }\n}\n",
  )
  resolver.add_module(
    root_path, "import super::util::make_polka_dots;\n@fragment\nfn fragment(v: f32) -> f32 {\n  return make_polka_dots(v);\n}\n",
  )
  let options = CompileOptions::default()
    .with_lower(true)
    .with_feature("PARTY_MODE", true)
  let compiled = compile(root_path, resolver, EscapeMangler::default(), options)
  let compiled_text = compiled.to_string()

  debug_inspect(compiled_text.contains("@fragment"), content="true")
  debug_inspect(
    compiled_text.contains("package_shaders_util__2make_polka_dots"),
    content="true",
  )
  debug_inspect(compiled_text.contains("return v * 2.0;"), content="true")
}

///|
test "wesl: missing imported module stays resolver-backed" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "import super::missing::make_it;\n@fragment\nfn fragment() -> f32 {\n  return make_it();\n}\n",
  )
  let result = try
    compile(
      root_path,
      resolver,
      EscapeMangler::default(),
      CompileOptions::default(),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }

  match result {
    Err(Resolve(ModuleNotFound(path, context))) => {
      debug_inspect(path.to_string(), content="\"package::shaders::missing\"")
      debug_inspect(context, content="\"virtual module\"")
    }
    _ => fail("expected resolver-backed missing module error")
  }
}

///|
test "wesl: lazy strip does not load unused imports" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "import super::missing::unused_helper;\n@fragment\nfn fragment() -> f32 {\n  return 1.0;\n}\n",
  )

  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default().with_lower(true),
  )

  debug_inspect(compiled.to_string().contains("return 1.0;"), content="true")
}

///|
test "wesl: strip keeps entrypoints and their transitive dependencies only" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "fn helper_unused() -> f32 {\n  return 5.0;\n}\n\nfn helper_used() -> f32 {\n  return 7.0;\n}\n\n@fragment\nfn fragment() -> f32 {\n  return helper_used();\n}\n",
  )

  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default().with_lower(true),
  )
  let compiled_text = compiled.to_string()

  debug_inspect(compiled_text.contains("helper_unused"), content="false")
  debug_inspect(compiled_text.contains("helper_used"), content="true")
  debug_inspect(compiled_text.contains("fn fragment()"), content="true")
}

///|
test "wesl: strip keeps declarations referenced by attribute expressions" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "const GROUP_SIZE = 64;\n\nfn helper_unused() -> u32 {\n  return 1u;\n}\n\n@compute\n@workgroup_size(GROUP_SIZE)\nfn main() {\n  return;\n}\n",
  )

  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default(),
  )
  let compiled_text = compiled.to_string()

  debug_inspect(compiled_text.contains("const GROUP_SIZE"), content="true")
  debug_inspect(compiled_text.contains("helper_unused"), content="false")
  debug_inspect(
    compiled_text.contains("@workgroup_size(GROUP_SIZE)"),
    content="true",
  )
}

///|
test "wesl: lowering removes aliases and global const declarations" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "alias Scalar = f32;\nconst SCALE = 2.0;\n\nfn helper(v: Scalar) -> Scalar {\n  return v * SCALE;\n}\n\n@fragment\nfn fragment() -> f32 {\n  return helper(1.0);\n}\n",
  )

  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default().with_lower(true),
  )
  let compiled_text = compiled.to_string()

  debug_inspect(compiled_text.contains("alias Scalar"), content="false")
  debug_inspect(compiled_text.contains("const SCALE"), content="false")
  debug_inspect(compiled_text.contains("(2.0)"), content="true")
}

///|
test "wesl: grouped imports expand and local aliases resolve correctly" {
  let resolver = VirtualResolver::new()
  let util_path = ModulePath::from_path("/shaders/util")
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    util_path, "fn make_value() -> f32 {\n  return 3.0;\n}\n\nfn helper_unused() -> f32 {\n  return 5.0;\n}\n",
  )
  resolver.add_module(
    root_path, "import super::util::{make_value as renamed_value, helper_unused};\n@fragment\nfn fragment() -> f32 {\n  return renamed_value();\n}\n",
  )

  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default().with_lower(true),
  )
  let compiled_text = compiled.to_string()

  debug_inspect(
    compiled_text.contains("return package_shaders_util__1make_value();"),
    content="true",
  )
  debug_inspect(compiled_text.contains("renamed_value"), content="false")
  debug_inspect(compiled_text.contains("helper_unused"), content="false")
}

///|
test "wesl: parse errors include module and line context" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "import super::util::make_value\n@fragment\nfn fragment() -> f32 {\n  return 1.0;\n}\n",
  )

  let result = try
    compile(
      root_path,
      resolver,
      EscapeMangler::default(),
      CompileOptions::default().with_lower(true),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }

  match result {
    Err(Parse(reason)) => {
      debug_inspect(
        reason.contains("unsupported import statement"),
        content="true",
      )
      debug_inspect(reason.contains("package::shaders::root:1"), content="true")
    }
    _ => fail("expected parse error with source context")
  }
}

///|
test "wesl: duplicate declarations include module and line context" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "fn helper() -> f32 {\n  return 1.0;\n}\n\nfn helper() -> f32 {\n  return 2.0;\n}\n",
  )

  let result = try
    compile(
      root_path,
      resolver,
      EscapeMangler::default(),
      CompileOptions::default(),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }

  match result {
    Err(DuplicateSymbol(symbol)) => {
      debug_inspect(symbol.contains("helper"), content="true")
      debug_inspect(symbol.contains("package::shaders::root:5"), content="true")
    }
    _ => fail("expected duplicate symbol with source context")
  }
}

///|
test "wesl: lowering preserves non-lowered declaration kinds" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "struct Payload {\n  value: f32,\n}\n\noverride SCALE: f32 = 2.0;\n\n@fragment\nfn fragment() -> f32 {\n  return 1.0;\n}\n",
  )

  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default().with_lower(true).with_strip(false),
  )
  let compiled_text = compiled.to_string()

  debug_inspect(compiled_text.contains("struct Payload"), content="true")
  debug_inspect(compiled_text.contains("override SCALE"), content="true")
}

///|
test "wesl: parser handles attribute arguments and generic var declarations" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "@group(0)\n@binding(1)\nvar<uniform> DATA: f32;\n\n@fragment\nfn fragment() -> f32 {\n  return DATA;\n}\n",
  )

  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default().with_strip(false),
  )
  let compiled_text = compiled.to_string()

  debug_inspect(compiled_text.contains("@group(0)"), content="true")
  debug_inspect(compiled_text.contains("var<uniform> DATA"), content="true")
  debug_inspect(compiled_text.contains("return DATA;"), content="true")
}

///|
test "wesl: parser classifies global directives" {
  let unit = parse_translation_unit(
    ModulePath::from_path("/shaders/root"),
    "enable f16;\nrequires readonly_and_readwrite_storage_textures;\ndiagnostic(error, derivative_uniformity);\n",
    true,
  )
  let headers : Array[GlobalDeclarationHeader] = []
  for declaration in unit.global_declarations {
    headers.push(declaration.header)
  }
  let expected_headers =
    #|[
    #|  EnableDirective({ names: ["f16"] }),
    #|  RequiresDirective({ names: ["readonly_and_readwrite_storage_textures"] }),
    #|  DiagnosticDirective(
    #|    {
    #|      arguments: ["error", "derivative_uniformity"],
    #|      severity: Some("error"),
    #|      rule_name: Some("derivative_uniformity"),
    #|    },
    #|  ),
    #|]
  debug_inspect(headers, content=expected_headers)
}

///|
test "wesl: nested grouped imports resolve through syntax tree flattening" {
  let resolver = VirtualResolver::new()
  let util_path = ModulePath::from_path("/shaders/util")
  let bridge_path = ModulePath::from_path("/shaders/bridge")
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    util_path, "fn make_value() -> f32 {\n  return 3.0;\n}\n\nfn helper_unused() -> f32 {\n  return 5.0;\n}\n",
  )
  resolver.add_module(bridge_path, "fn helper() -> f32 {\n  return 7.0;\n}\n")
  resolver.add_module(
    root_path, "import super::{util::{make_value as renamed_value, helper_unused}, bridge::helper};\n@fragment\nfn fragment() -> f32 {\n  return renamed_value() + helper();\n}\n",
  )

  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default().with_lower(true),
  )
  let compiled_text = compiled.to_string()

  debug_inspect(
    compiled_text.contains(
      "return package_shaders_util__1make_value() + package_shaders_bridge_helper();",
    ),
    content="true",
  )
  debug_inspect(compiled_text.contains("helper_unused"), content="false")
}

///|
test "wesl: published imports can be re-exported across modules" {
  let resolver = VirtualResolver::new()
  let util_path = ModulePath::from_path("/shaders/util")
  let bridge_path = ModulePath::from_path("/shaders/bridge")
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(util_path, "fn make_value() -> f32 {\n  return 3.0;\n}\n")
  resolver.add_module(bridge_path, "@publish import super::util::make_value;\n")
  resolver.add_module(
    root_path, "import super::bridge::make_value;\n@fragment\nfn fragment() -> f32 {\n  return make_value();\n}\n",
  )

  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default().with_lower(true),
  )
  let compiled_text = compiled.to_string()

  debug_inspect(
    compiled_text.contains("package_shaders_util__1make_value"),
    content="true",
  )
  debug_inspect(
    compiled_text.contains("return package_shaders_util__1make_value();"),
    content="true",
  )
}

///|
test "wesl: private imports cannot be re-exported" {
  let resolver = VirtualResolver::new()
  let util_path = ModulePath::from_path("/shaders/util")
  let bridge_path = ModulePath::from_path("/shaders/bridge")
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(util_path, "fn make_value() -> f32 {\n  return 3.0;\n}\n")
  resolver.add_module(bridge_path, "import super::util::make_value;\n")
  resolver.add_module(
    root_path, "import super::bridge::make_value;\n@fragment\nfn fragment() -> f32 {\n  return make_value();\n}\n",
  )

  let result = try
    compile(
      root_path,
      resolver,
      EscapeMangler::default(),
      CompileOptions::default().with_lower(true),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }

  match result {
    Err(Private(item, path)) => {
      debug_inspect(item, content="\"make_value\"")
      debug_inspect(path.to_string(), content="\"package::shaders::bridge\"")
    }
    _ => fail("expected non-publish re-export to fail")
  }
}

///|
test "wesl: missing conditional feature can be configured as an error" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "@if(EXPERIMENTAL_SHADER)\nfn enabled() -> f32 {\n  return 1.0;\n}\n@else\nfn disabled() -> f32 {\n  return 0.0;\n}\n",
  )

  let result = try
    compile(
      root_path,
      resolver,
      EscapeMangler::default(),
      CompileOptions::default().set_missing_feature_behavior(Error),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }

  match result {
    Err(InvalidExpression(message)) => {
      debug_inspect(message.contains("unexpected feature flag"), content="true")
      debug_inspect(message.contains("EXPERIMENTAL_SHADER"), content="true")
    }
    _ => fail("expected unexpected feature flag error")
  }
}

///|
test "wesl: keep conditional feature preserves unresolved attributes" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "@if(EXPERIMENTAL_SHADER)\nfn enabled() -> f32 {\n  return 1.0;\n}\n@else\nfn disabled() -> f32 {\n  return 0.0;\n}\n",
  )

  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default()
    .with_strip(false)
    .with_validate(false)
    .set_missing_feature_behavior(Keep),
  )
  let compiled_text = compiled.to_string()

  debug_inspect(
    compiled_text.contains("@if(EXPERIMENTAL_SHADER)"),
    content="true",
  )
  debug_inspect(compiled_text.contains("@else"), content="true")
  debug_inspect(compiled_text.contains("fn enabled()"), content="true")
  debug_inspect(compiled_text.contains("fn disabled()"), content="true")
}

///|
test "wesl: conditional expression parser rejects malformed expressions" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(root_path, "@if(true &&)\nfn bad() {}\n")
  let result = try
    compile(
      root_path,
      resolver,
      EscapeMangler::default(),
      CompileOptions::default(),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  match result {
    Err(InvalidExpression(expr)) =>
      debug_inspect(
        expr,
        content="\"invalid if attribute expression: `true &&`\"",
      )
    _ => fail("expected invalid conditional expression")
  }
}

///|
test "wesl: conditional translation handles top-level elif chains" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "@if(FIRST)\nfn selected() -> f32 {\n  return 1.0;\n}\n@elif(SECOND)\nfn selected() -> f32 {\n  return 2.0;\n}\n@else\nfn selected() -> f32 {\n  return 3.0;\n}\n\n@fragment\nfn fragment() -> f32 {\n  return selected();\n}\n",
  )

  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default().with_strip(false).with_feature("SECOND", true),
  )
  let compiled_text = compiled.to_string()

  debug_inspect(compiled_text.contains("return 1.0;"), content="false")
  debug_inspect(compiled_text.contains("return 2.0;"), content="true")
  debug_inspect(compiled_text.contains("return 3.0;"), content="false")
  debug_inspect(compiled_text.contains("@elif"), content="false")
}

///|
test "wesl: validate option controls semantic validation pass" {
  let root_path = ModulePath::from_path("/shaders/root")
  let source = "const m: mat2x2<i32> = mat2x2(1, 0, 0, 0);\n"

  let failing_resolver = VirtualResolver::new()
  failing_resolver.add_module(root_path, source)
  let failing = try
    compile(
      root_path,
      failing_resolver,
      EscapeMangler::default(),
      CompileOptions::default().with_strip(false),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }

  match failing {
    Err(Validation(message)) =>
      debug_inspect(
        message.contains("matrix type must use a floating-point scalar"),
        content="true",
      )
    _ => fail("expected matrix validation error")
  }

  let passing_resolver = VirtualResolver::new()
  passing_resolver.add_module(root_path, source)
  let compiled = compile(
    root_path,
    passing_resolver,
    EscapeMangler::default(),
    CompileOptions::default().with_strip(false).with_validate(false),
  )

  debug_inspect(compiled.to_string().contains("mat2x2<i32>"), content="true")
}

///|
test "wesl: validation checks matrix templates through AST type expressions" {
  let root_path = ModulePath::from_path("/shaders/root")
  let resolver = VirtualResolver::new()
  resolver.add_module(
    root_path, "fn main() {\n  var m: array<mat2x2<i32>, 1>;\n}\n",
  )

  let result = try
    compile(
      root_path,
      resolver,
      EscapeMangler::default(),
      CompileOptions::default().with_strip(false),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }

  match result {
    Err(Validation(message)) =>
      debug_inspect(
        message.contains("matrix type must use a floating-point scalar"),
        content="true",
      )
    _ => fail("expected matrix validation error")
  }
}

///|
test "wesl: validation checks matrix constructors through AST calls" {
  let root_path = ModulePath::from_path("/shaders/root")
  let resolver = VirtualResolver::new()
  resolver.add_module(root_path, "const m = mat2x2(1i, 0.0, 0.0, 0.0);\n")

  let result = try
    compile(
      root_path,
      resolver,
      EscapeMangler::default(),
      CompileOptions::default().with_strip(false),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }

  match result {
    Err(Validation(_)) => ()
    _ => fail("expected matrix constructor validation error")
  }
}

///|
test "wesl: validation checks matrix assignments through AST lhs scopes" {
  let root_path = ModulePath::from_path("/shaders/root")
  let resolver = VirtualResolver::new()
  resolver.add_module(
    root_path, "fn main() {\n  var m = mat2x2(0.0, 0.0, 0.0, 0.0);\n  m[0] = vec2(1i, 0.0);\n}\n",
  )

  let result = try
    compile(
      root_path,
      resolver,
      EscapeMangler::default(),
      CompileOptions::default().with_strip(false),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }

  match result {
    Err(Validation(_)) => ()
    _ => fail("expected matrix assignment validation error")
  }
}

///|
test "wesl: public validate_wesl rejects duplicate declarations" {
  let root_path = ModulePath::from_path("/shaders/root")
  let unit = parse_translation_unit(
    root_path, "fn make() -> i32 { return 1i; }\nfn make() -> i32 { return 2i; }\n",
    true,
  )

  try validate_wesl(unit) catch {
    Validate(Duplicate(name)) => debug_inspect(name, content="\"make\"")
    _ => fail("expected duplicate declaration validation error")
  } noraise {
    _ => fail("expected duplicate declaration validation error")
  }
}

///|
test "wesl: public validate_wesl skips conditional duplicate declarations" {
  let root_path = ModulePath::from_path("/shaders/root")
  let unit = parse_translation_unit(
    root_path, "@if(FEATURE)\nfn make() -> i32 { return 1i; }\nfn make() -> i32 { return 2i; }\n",
    true,
  )

  validate_wesl(unit)
}

///|
test "wesl: public validate_wesl rejects cyclic declarations" {
  let root_path = ModulePath::from_path("/shaders/root")
  let unit = parse_translation_unit(
    root_path, "alias A = B;\nalias B = A;\n", true,
  )

  try validate_wesl(unit) catch {
    Validate(Cycle(name, _)) =>
      debug_inspect(name.contains("A") || name.contains("B"), content="true")
    _ => fail("expected cyclic declaration validation error")
  } noraise {
    _ => fail("expected cyclic declaration validation error")
  }
}

///|
test "wesl: compile delegates user function arity validation to WGSL Core" {
  let root_path = ModulePath::from_path("/shaders/root")
  let resolver = VirtualResolver::new()
  resolver.add_module(
    root_path, "fn takes_one(value: i32) -> i32 { return value; }\nfn main() { let value = takes_one(1i, 2i); }\n",
  )

  try
    compile(
      root_path,
      resolver,
      EscapeMangler::default(),
      CompileOptions::default().with_strip(false),
    )
  catch {
    Validation(message) =>
      debug_inspect(message.contains("takes_one"), content="true")
    _ => fail("expected function arity validation error")
  } noraise {
    _ => fail("expected function arity validation error")
  }
}

///|
test "wesl: compile accepts WGSL builtin calls through WGSL Core" {
  let root_path = ModulePath::from_path("/shaders/root")
  let resolver = VirtualResolver::new()
  resolver.add_module(
    root_path, "fn main() { let value = sin(0.0); let position = vec4<f32>(value); }\n",
  )

  ignore(
    compile(
      root_path,
      resolver,
      EscapeMangler::default(),
      CompileOptions::default().with_strip(false),
    ),
  )
}

///|
test "wesl: compile delegates unknown types to WGSL Core" {
  let root_path = ModulePath::from_path("/shaders/root")
  let resolver = VirtualResolver::new()
  resolver.add_module(root_path, "const value: MissingType = 1i;\n")

  let result = try
    compile(
      root_path,
      resolver,
      EscapeMangler::default(),
      CompileOptions::default().with_strip(false),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }

  match result {
    Err(Validation(message)) =>
      debug_inspect(message.contains("MissingType"), content="true")
    _ => fail("expected WGSL Core validation error")
  }
}

///|
test "wesl: compile validate runs assembled WGSL call checks" {
  let root_path = ModulePath::from_path("/shaders/root")
  let resolver = VirtualResolver::new()
  resolver.add_module(
    root_path, "const value = 1i;\n@compute @workgroup_size(1)\nfn main() {\n  let out = value();\n}\n",
  )

  let result = try
    compile(
      root_path,
      resolver,
      EscapeMangler::default(),
      CompileOptions::default().with_strip(false),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }

  match result {
    Err(Validation(message)) =>
      debug_inspect(message.contains("value"), content="true")
    _ => fail("expected assembled WGSL validation error")
  }
}

///|
test "wesl: compile validation rejects invalid imported call statements" {
  let root_path = ModulePath::from_path("/shaders/root")
  let util_path = ModulePath::from_path("/shaders/util")
  let resolver = VirtualResolver::new()
  resolver.add_module(
    root_path, "import super::util::foo;\n@compute @workgroup_size(1)\nfn main() {\n  foo();\n}\n",
  )
  resolver.add_module(
    util_path, "struct AStruct { x: u32 }\nfn foo(a: AStruct) {\n  let b = a.x;\n}\n",
  )

  try
    compile(
      root_path,
      resolver,
      EscapeMangler::default(),
      CompileOptions::default().with_keep_root(true),
    )
  catch {
    Validation(message) =>
      debug_inspect(message.contains("expected 1, got 0"), content="true")
    _ => fail("expected assembled WGSL validation error")
  } noraise {
    _ => fail("expected assembled WGSL validation error")
  }
}

///|
test "wesl: WGSL Core accepts storage texture formats" {
  let root_path = ModulePath::from_path("/shaders/root")
  let resolver = VirtualResolver::new()
  resolver.add_module(
    root_path, "@group(0) @binding(0) var input: texture_storage_2d<r32float, read>;\n",
  )

  ignore(
    compile(
      root_path,
      resolver,
      EscapeMangler::default(),
      CompileOptions::default().with_strip(false),
    ),
  )
}

///|
test "wesl: compile options expose lazy resolution control" {
  let options = CompileOptions::default()

  debug_inspect(options.lazy_resolution, content="true")
  debug_inspect(options.with_lazy(false).lazy_resolution, content="false")
}

///|
test "wesl: facade compile uses custom resolver and sourcemap option" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "@compute @workgroup_size(1)\nfn main() {\n}\n",
  )

  let compiled = Wesl::new_barebones()
    .set_custom_resolver(resolver)
    .set_options(
      CompileOptions::default().with_strip(false).with_validate(false),
    )
    .use_sourcemap(true)
    .compile(root_path)

  debug_inspect(compiled.has_sourcemap(), content="true")
  debug_inspect(compiled.modules.length(), content="1")
  debug_inspect(compiled.syntax.global_declarations.length(), content="1")
  debug_inspect(compiled.to_string().contains("@compute"), content="true")
  match compiled.sourcemap {
    Some(source_map) => {
      debug_inspect(
        source_map.get_source(root_path),
        content="Some(\"@compute @workgroup_size(1)\\nfn main() {\\n}\\n\")",
      )
      debug_inspect(
        source_map.get_display_name(root_path),
        content="Some(\"package::shaders::root\")",
      )
      debug_inspect(
        source_map.get_default_source(),
        content="Some(\"@compute @workgroup_size(1)\\nfn main() {\\n}\\n\")",
      )
    }
    None => fail("expected sourcemap")
  }
}

///|
test "wesl: compile sourcemap unmangles imported diagnostics" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  let util_path = ModulePath::from_path("/shaders/util")
  resolver.add_module(
    root_path, "import super::util::make_value;\n@compute @workgroup_size(1)\nfn main() {\n  let value = make_value();\n}\n",
  )
  resolver.add_module(util_path, "fn make_value() -> i32 {\n  return 1i;\n}\n")

  let compiled = compile_sourcemap(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default(),
  )
  let mangled = "package_shaders_util__1make_value"
  match compiled.sourcemap {
    Some(source_map) =>
      match source_map.get_decl(mangled) {
        Some((path, item)) => {
          debug_inspect(path.to_string(), content="\"package::shaders::util\"")
          debug_inspect(item, content="\"make_value\"")
        }
        None => fail("expected imported declaration mapping")
      }
    None => fail("expected sourcemap")
  }
  debug_inspect(
    compiled.unmangle_text("unknown function package_shaders_util__1make_value"),
    content="\"unknown function package::shaders::util::make_value\"",
  )
}

///|
test "wesl: diagnostic renders source origin and snippets" {
  let root_path = ModulePath::from_path("/shaders/root")
  let source = "fn ok() {}\nfn bad() {\n  return;\n}\n"
  let diagnostic = WeslCompileError::Validation("bad return")
    .diagnostic()
    .with_module_path(root_path, Some("root.wesl"))
    .with_source(source)
    .with_syntax_span({ start_line: 2, end_line: 2 })
    .with_declaration("bad")
  let rendered = diagnostic.to_string()

  debug_inspect(rendered.contains("error: bad return"), content="true")
  debug_inspect(rendered.contains("root.wesl:2:1"), content="true")
  debug_inspect(rendered.contains("2 | fn bad() {"), content="true")
  debug_inspect(
    rendered.contains(
      "note: in declaration of `bad` in package::shaders::root (root.wesl)",
    ),
    content="true",
  )
}

///|
test "wesl: diagnostic compile path attaches resolver source context" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(root_path, "fn bad() {\n  var m: mat2x2<i32>;\n}\n")

  let result = try
    compile_sourcemap_diagnostic(
      root_path,
      resolver,
      EscapeMangler::default(),
      CompileOptions::default().with_strip(false),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }

  match result {
    Err(Diagnostic(diagnostic)) => {
      let rendered = diagnostic.to_string()
      debug_inspect(
        rendered.contains("matrix type must use a floating-point scalar"),
        content="true",
      )
      debug_inspect(
        rendered.contains("note: in package::shaders::root"),
        content="true",
      )
      debug_inspect(
        match diagnostic.detail.source {
          Some(source) => source.contains("mat2x2<i32>")
          None => false
        },
        content="true",
      )
    }
    _ => fail("expected diagnostic validation error")
  }
}

///|
test "wesl: source mapper records resolver sources and mangled declarations" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  let util_path = ModulePath::from_path("/shaders/util")
  resolver.add_module(root_path, "import super::util::make_value;\n")
  resolver.add_module(util_path, "fn make_value() -> f32 {\n  return 1.0;\n}\n")
  let mapper = SourceMapper::new(root_path, resolver, Escape)

  let root_source = mapper.resolve_source(root_path)
  let mangled = mapper.mangle(util_path, "make_value")
  let source_map = mapper.finish()

  debug_inspect(root_source.contains("make_value"), content="true")
  debug_inspect(mangled, content="\"package_shaders_util__1make_value\"")
  debug_inspect(
    source_map.get_source(root_path),
    content="Some(\"import super::util::make_value;\\n\")",
  )
  debug_inspect(
    source_map.get_default_source(),
    content="Some(\"import super::util::make_value;\\n\")",
  )
  match source_map.get_decl(mangled) {
    Some((path, item)) => {
      debug_inspect(path.to_string(), content="\"package::shaders::util\"")
      debug_inspect(item, content="\"make_value\"")
    }
    None => fail("expected sourcemapper declaration mapping")
  }
}

///|
test "wesl: facade can select hash mangler" {
  let resolver = VirtualResolver::new()
  let util_path = ModulePath::from_path("/shaders/util")
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(util_path, "fn make_value() -> f32 {\n  return 3.0;\n}\n")
  resolver.add_module(
    root_path, "import super::util::make_value;\n@fragment\nfn fragment() -> f32 {\n  return make_value();\n}\n",
  )

  let compiled = Wesl::new_barebones()
    .set_custom_resolver(resolver)
    .set_options(CompileOptions::default().with_lower(true))
    .set_mangler(Hash)
    .compile(root_path)
  let compiled_text = compiled.to_string()

  debug_inspect(
    compiled_text.contains("package_shaders_util__1make_value"),
    content="false",
  )
  debug_inspect(compiled_text.contains("make_value_"), content="true")
}

///|
test "wesl: facade build_artifact compiles and writes wgsl output" {
  let base = "_build/facade_build_artifact"
  let out_dir = base + "/out"
  wesl_test_ensure_dir("_build")
  wesl_test_ensure_dir(base)
  wesl_test_ensure_dir(out_dir)
  try! @fs.write_string_to_file(
    base + "/main.wesl",
    "@fragment\nfn fragment() -> i32 { return 7; }\n",
  )

  Wesl::new(base).build_artifact(
    ModulePath::from_path("/main"),
    "main_shader",
    out_dir=Some(out_dir),
  )
  let artifact = try! @fs.read_file_to_string(out_dir + "/main_shader.wgsl")
  inspect(artifact.contains("@fragment"), content="true")
  inspect(artifact.contains("return 7;"), content="true")
}

///|
test "wesl: facade can set features in bulk and expose resolver" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "@if(A)\nfn a() -> f32 {\n  return 1.0;\n}\n@if(B)\nfn b() -> f32 {\n  return 2.0;\n}\n@fragment\nfn fragment() -> f32 {\n  return a() + b();\n}\n",
  )

  let wesl = Wesl::new_barebones()
    .set_custom_resolver(resolver)
    .set_options(
      CompileOptions::default().with_strip(false).with_validate(false),
    )
    .set_features([("A", Enable), ("B", Enable)])
  let compiled = wesl.compile(root_path)
  let returned_resolver = wesl.resolver()

  debug_inspect(
    compiled.to_string().contains("return a() + b();"),
    content="true",
  )
  debug_inspect(returned_resolver.modules().length(), content="1")
}

///|
test "wesl: facade standard resolver can add packages and constants" {
  let root = CodegenModule::new("demo", "fn root() {}\n")
  root.add_submodule(
    CodegenModule::new(
      "shader", "@fragment\nfn fragment() -> f32 {\n  return 1.0;\n}\n",
    ),
  )
  let compiled_pkg = Wesl::new("shaders")
    .add_package(CodegenPkg::new("demo_crate", root))
    .use_stripping(false)
    .use_lower(false)
    .compile(try! parse_module_path("demo::shader"))

  debug_inspect(compiled_pkg.to_string().contains("@fragment"), content="true")

  let compiled_constants = Wesl::new("shaders")
    .add_constant("PI", 3.141592653589793)
    .use_stripping(false)
    .use_lower(false)
    .compile(try! parse_module_path("constants"))

  debug_inspect(
    compiled_constants.to_string().contains("const PI = 3.141592653589793"),
    content="true",
  )
}

///|
test "wesl: resolver exposes display name and registered modules" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(root_path, "fn helper() {}\n")

  debug_inspect(
    resolver.display_name(root_path),
    content="Some(\"package::shaders::root\")",
  )
  debug_inspect(resolver.fs_path(root_path), content="None")
  debug_inspect(resolver.modules().length(), content="1")
}

///|
test "wesl: no resolver error matches upstream context" {
  let result = try
    NoResolver::new().resolve_source(ModulePath::new_root())
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }

  match result {
    Err(ModuleNotFound(_, context)) =>
      debug_inspect(
        context,
        content="\"no module resolver, imports are effectively disabled here\"",
      )
    _ => fail("expected no resolver module-not-found error")
  }
}

///|
test "wesl: resolver defaults match upstream constructors" {
  let root_path = ModulePath::new_root()
  let no_resolver_result = try
    NoResolver::default().resolve_source(root_path)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  let pkg_result = try
    PkgResolver::default().resolve_source(try! parse_module_path("demo"))
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  let router_result = try Router::default().resolve_source(root_path) catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }

  debug_inspect(VirtualResolver::default().modules().length(), content="0")
  debug_inspect(
    FileResolver::default().fs_path(root_path),
    content="Some(\"package\")",
  )
  match no_resolver_result {
    Err(ModuleNotFound(_, context)) =>
      debug_inspect(
        context,
        content="\"no module resolver, imports are effectively disabled here\"",
      )
    _ => fail("expected default no resolver to reject modules")
  }
  match pkg_result {
    Err(ModuleNotFound(_, context)) =>
      debug_inspect(context, content="\"dependency `demo` not found\"")
    _ => fail("expected default package resolver to reject unknown package")
  }
  match router_result {
    Err(ModuleNotFound(_, context)) =>
      debug_inspect(context, content="\"no mount point\"")
    _ => fail("expected default router to have no mount point")
  }
}

///|
test "wesl: virtual resolver accepts translation units" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  let unit = parse_translation_unit(
    root_path, "fn helper() -> f32 {\n  return 1.0;\n}\n", true,
  )
  resolver.add_translation_unit(root_path, unit)

  let compiled = compile(
    root_path,
    resolver,
    EscapeMangler::default(),
    CompileOptions::default().with_strip(false),
  )

  debug_inspect(compiled.to_string().contains("fn helper()"), content="true")
}

///|
struct AppendDeclPreprocessor {}

///|
impl ModulePreprocessor for AppendDeclPreprocessor with fn preprocess_module(
  _self,
  _path,
  unit,
) {
  unit.global_declarations.push({
    header: Function({
      name: "injected",
      generic_parameters: None,
      parameters: [],
      return_type: Some("f32"),
      return_type_expr: Some({
        path: [],
        ident: "f32",
        template_text: None,
        template_args: [],
      }),
      return_attributes: [],
      body: { statements: [] },
    }),
    attributes: Array::new(),
    source: "fn injected() -> f32 {\n  return 1.0;\n}",
    span: { start_line: 1, end_line: 3 },
  })
  unit
}

///|
struct ConditionalAppendPreprocessor {}

///|
impl ModulePreprocessor for ConditionalAppendPreprocessor with fn preprocess_module(
  _self,
  _path,
  unit,
) {
  unit.global_declarations.push({
    header: Function({
      name: "injected",
      generic_parameters: None,
      parameters: [],
      return_type: Some("f32"),
      return_type_expr: Some({
        path: [],
        ident: "f32",
        template_text: None,
        template_args: [],
      }),
      return_attributes: [],
      body: { statements: [] },
    }),
    attributes: [
      {
        name: "if",
        arguments: Some("EXTRA"),
        argument_exprs: [],
        condition_expr: Some(Feature("EXTRA")),
        span: { start_line: 1, end_line: 1 },
      },
    ],
    source: "@if(EXTRA)\nfn injected() -> f32 {\n  return 4.0;\n}",
    span: { start_line: 1, end_line: 4 },
  })
  unit
}

///|
test "wesl: preprocessor can transform resolved translation units" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "@fragment\nfn fragment() -> f32 {\n  return injected();\n}\n",
  )

  let compiled = compile(
    root_path,
    Preprocessor::new(resolver, AppendDeclPreprocessor::{  }),
    EscapeMangler::default(),
    CompileOptions::default().with_condcomp(false).with_strip(false),
  )
  let compiled_text = compiled.to_string()

  debug_inspect(compiled_text.contains("fn injected()"), content="true")
  debug_inspect(compiled_text.contains("return injected();"), content="true")
}

///|
test "wesl: conditional translation runs after custom module preprocessing" {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/shaders/root")
  resolver.add_module(
    root_path, "@fragment\nfn fragment() -> f32 {\n  return injected();\n}\n",
  )

  let compiled = compile(
    root_path,
    Preprocessor::new(resolver, ConditionalAppendPreprocessor::{  }),
    EscapeMangler::default(),
    CompileOptions::default().with_strip(false).with_feature("EXTRA", true),
  )
  let compiled_text = compiled.to_string()

  debug_inspect(compiled_text.contains("@if(EXTRA)"), content="false")
  debug_inspect(compiled_text.contains("return 4.0;"), content="true")
}

///|
test "wesl: file resolver maps module path to wesl path" {
  let resolver = FileResolver::new("shaders")
  let root_path = ModulePath::from_path("/materials/root")

  debug_inspect(
    resolver.fs_path(root_path),
    content="Some(\"shaders/materials/root.wesl\")",
  )
  let wgsl_resolver = resolver.set_extension("wgsl")
  debug_inspect(
    wgsl_resolver.fs_path(root_path),
    content="Some(\"shaders/materials/root.wgsl\")",
  )
  debug_inspect(
    FileResolver::default().fs_path(root_path),
    content="Some(\"materials/root\")",
  )
}

///|
test "wesl: file resolver reads files and falls back from wesl to wgsl" {
  let resolver = FileResolver::new("testdata/upstream/bevy")
  let wesl_source = resolver.resolve_source(
    ModulePath::from_path("/custom_material"),
  )
  debug_inspect(wesl_source.contains("make_polka_dots"), content="true")

  let wgsl_source = resolver.resolve_source(
    ModulePath::from_path("/custom_material_import"),
  )
  debug_inspect(wgsl_source.contains("COLOR_MULTIPLIER"), content="true")
}

///|
test "wesl: file resolver compiles local file imports" {
  let resolver = FileResolver::new("testdata/upstream/bevy")
  let compiled = compile(
    ModulePath::from_path("/custom_material"),
    resolver,
    EscapeMangler::default(),
    CompileOptions::default().with_keep_root(true),
  )
  let compiled_text = compiled.to_string()

  debug_inspect(
    compiled_text.contains("fn package_util__2make_polka_dots"),
    content="true",
  )
  debug_inspect(
    compiled_text.contains("return package_util__2make_polka_dots"),
    content="true",
  )
}

///|
test "wesl: standard resolver exposes constants package" {
  let resolver = StandardResolver::new("shaders")
  resolver.add_constant("PI", 3.141592653589793)
  let constants_path = try! parse_module_path("constants")

  let source = resolver.resolve_source(constants_path)
  debug_inspect(source.contains("const PI = 3.141592653589793"), content="true")
  debug_inspect(resolver.fs_path(constants_path), content="None")
}

///|
test "wesl: package resolver reads codegen modules" {
  let root = CodegenModule::new("demo", "fn root() {}\n")
  root.add_submodule(CodegenModule::new("util", "fn util() {}\n"))
  let resolver = PkgResolver::new()
  resolver.add_package(CodegenPkg::new("demo_crate", root))

  debug_inspect(
    resolver.resolve_source(try! parse_module_path("demo")),
    content="\"fn root() {}\\n\"",
  )
  debug_inspect(
    resolver.resolve_source(try! parse_module_path("demo::util")),
    content="\"fn util() {}\\n\"",
  )
  debug_inspect(
    resolver.display_name(try! parse_module_path("demo::util")),
    content="Some(\"demo::util\")",
  )
}

///|
fn wesl_test_ensure_dir(path : String) -> Unit {
  if !@fs.path_exists(path) {
    try! @fs.create_dir(path)
  }
}

///|
test "wesl: package builder scans filesystem artifacts" {
  let base = "_build/pkg_builder_fixture"
  let root_dir = base + "/shaders"
  wesl_test_ensure_dir("_build")
  wesl_test_ensure_dir(base)
  wesl_test_ensure_dir(root_dir)
  wesl_test_ensure_dir(root_dir + "/nested")
  try! @fs.write_string_to_file(
    root_dir + ".wesl",
    "fn root_value() -> f32 {\n  return 1.0;\n}\n",
  )
  try! @fs.write_string_to_file(
    root_dir + "/util.wesl",
    "fn make_value() -> f32 {\n  return 2.0;\n}\n",
  )
  try! @fs.write_string_to_file(
    root_dir + "/nested/math.wgsl",
    "fn triple(value: f32) -> f32 {\n  return value * 3.0;\n}\n",
  )
  try! @fs.write_string_to_file(
    root_dir + "/bad-name.wesl",
    "fn skipped() -> f32 {\n  return 9.0;\n}\n",
  )

  let pkg = PkgBuilder::new("demo-crate").scan_root(root_dir).validate()
  let artifact_path = base + "/demo_artifact.mbt.txt"
  pkg.build_artifact(artifact_path)
  let artifact = try! @fs.read_file_to_string(artifact_path)
  debug_inspect(artifact.contains("CodegenPkg::"), content="true")
  debug_inspect(artifact.contains("demo_crate"), content="true")
  let codegen_pkg = pkg.to_codegen_pkg()
  let resolver = PkgResolver::new()
  resolver.add_package(codegen_pkg)

  debug_inspect(
    resolver.resolve_source(try! parse_module_path("demo_crate")),
    content="\"fn root_value() -> f32 {\\n  return 1.0;\\n}\\n\"",
  )
  debug_inspect(
    resolver.resolve_source(try! parse_module_path("demo_crate::util")),
    content="\"fn make_value() -> f32 {\\n  return 2.0;\\n}\\n\"",
  )
  debug_inspect(
    resolver.resolve_source(try! parse_module_path("demo_crate::nested::math")),
    content="\"fn triple(value: f32) -> f32 {\\n  return value * 3.0;\\n}\\n\"",
  )
  let skipped = try
    resolver.resolve_source(try! parse_module_path("demo_crate::bad-name"))
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  match skipped {
    Err(ModuleNotFound(_, _)) => ()
    _ => fail("expected invalid module filename to be skipped")
  }
}

///|
test "wesl: package builder artifacts compile through standard resolver" {
  let base = "_build/pkg_builder_compile_fixture"
  let root_dir = base + "/lib"
  wesl_test_ensure_dir("_build")
  wesl_test_ensure_dir(base)
  wesl_test_ensure_dir(base + "/app")
  wesl_test_ensure_dir(root_dir)
  try! @fs.write_string_to_file(root_dir + ".wesl", "")
  try! @fs.write_string_to_file(
    root_dir + "/util.wesl",
    "fn make_value() -> f32 {\n  return 4.0;\n}\n",
  )
  try! @fs.write_string_to_file(
    base + "/app/root.wesl",
    "import shader_lib::util::make_value;\n@fragment\nfn fragment() -> f32 {\n  return make_value();\n}\n",
  )

  let pkg = PkgBuilder::new("shader-lib").scan_root(root_dir).validate()
  let compiled = Wesl::new(base)
    .add_scanned_package(pkg)
    .use_lower(true)
    .compile(ModulePath::from_path("/app/root"))
  let compiled_text = compiled.to_string()
  let expected = ManglerKind::mangle(
    Escape,
    try! parse_module_path("shader_lib::util"),
    "make_value",
  )

  debug_inspect(compiled_text.contains("fn \{expected}"), content="true")
  debug_inspect(compiled_text.contains("return \{expected}();"), content="true")
}

///|
test "wesl: standard resolver delegates package imports to codegen resolver" {
  let root = CodegenModule::new("demo", "fn root() {}\n")
  root.add_submodule(CodegenModule::new("util", "fn util() {}\n"))
  let resolver = StandardResolver::new("shaders")
  resolver.add_package(CodegenPkg::new("demo_crate", root))

  debug_inspect(
    resolver.resolve_source(try! parse_module_path("demo::util")),
    content="\"fn util() {}\\n\"",
  )
  debug_inspect(
    resolver.fs_path(try! parse_module_path("demo::util")),
    content="None",
  )
}

///|
test "wesl: router dispatches to longest matching mount" {
  let router = Router::new()
  let package_path = try! parse_module_path("package")
  let bar_path = try! parse_module_path("package::bar")

  let base = VirtualResolver::new()
  base.add_module(ModulePath::new_root(), "fn root() {}\n")
  base.add_module(ModulePath::new(Absolute, ["foo"]), "fn foo() {}\n")
  base.add_module(ModulePath::new(Absolute, ["bar"]), "fn base_bar() {}\n")
  router.mount_resolver(package_path, base)

  let nested = VirtualResolver::new()
  nested.add_module(ModulePath::new_root(), "fn nested_root() {}\n")
  nested.add_module(ModulePath::new(Absolute, ["baz"]), "fn baz() {}\n")
  router.mount_resolver(bar_path, nested)

  let fallback = VirtualResolver::new()
  fallback.add_module(
    ModulePath::new(Absolute, ["external"]),
    "fn external() {}\n",
  )
  router.mount_fallback_resolver(fallback)

  debug_inspect(
    router.resolve_source(try! parse_module_path("package::foo")),
    content="\"fn foo() {}\\n\"",
  )
  debug_inspect(
    router.resolve_source(try! parse_module_path("package::bar")),
    content="\"fn nested_root() {}\\n\"",
  )
  debug_inspect(
    router.resolve_source(try! parse_module_path("package::bar::baz")),
    content="\"fn baz() {}\\n\"",
  )
  debug_inspect(
    router.resolve_source(try! parse_module_path("foo::external")),
    content="\"fn external() {}\\n\"",
  )
}

///|
test "wesl: router can mount package resolver" {
  let root = CodegenModule::new("demo", "fn root() {}\n")
  root.add_submodule(CodegenModule::new("util", "fn util() {}\n"))
  let pkg_resolver = PkgResolver::new()
  pkg_resolver.add_package(CodegenPkg::new("demo_crate", root))

  let router = Router::new()
  router.mount_pkg_resolver(try! parse_module_path("demo"), pkg_resolver)

  debug_inspect(
    router.resolve_source(try! parse_module_path("demo::util")),
    content="\"fn util() {}\\n\"",
  )
}
