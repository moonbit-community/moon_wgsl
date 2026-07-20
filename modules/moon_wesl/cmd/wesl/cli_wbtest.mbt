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
fn cli_test_ensure_dir(path : String) -> Unit {
  if !@fs.path_exists(path) {
    try! @fs.create_dir(path)
  }
}

///|
test "wesl cli: help lists upstream command matrix" {
  let result = wesl_cli_run(["help"][:])
  inspect(result.status, content="0")
  assert_true(result.stdout.contains("check"))
  assert_true(result.stdout.contains("compile"))
  assert_true(result.stdout.contains("eval"))
  assert_true(result.stdout.contains("exec"))
  assert_true(result.stdout.contains("package"))
}

///|
test "wesl cli: eval expression without context" {
  let result = wesl_cli_run(["eval", "abs(3 - 5)"][:])
  inspect(result.status, content="0")
  inspect(result.stdout, content="2")
  inspect(result.stderr, content="")
}

///|
test "wesl cli: eval binary output for scalar values" {
  let result = wesl_cli_run(["eval", "--binary", "42u"][:])
  inspect(result.status, content="0")
  inspect(result.stdout, content="")
  match result.stdout_bytes {
    Some(bytes) =>
      debug_inspect(
        bytes.to_array(),
        content=(
          #|[0x2a, 0x00, 0x00, 0x00]
        ),
      )
    None => fail("expected binary stdout")
  }
}

///|
test "wesl cli: eval binary rejects non-storable values" {
  let result = wesl_cli_run(["eval", "--binary", "true"][:])
  inspect(result.status, content="1")
  assert_true(result.stderr.contains("not storable"))
}

///|
test "wesl cli: compile file with base and feature flags" {
  cli_test_ensure_dir("_build")
  cli_test_ensure_dir("_build/cli_compile")
  try! @fs.write_string_to_file(
    "_build/cli_compile/main.wesl", "@if(foo)\nfn enabled() -> i32 { return 1; }\n@else\nfn disabled() -> i32 { return 0; }\n",
  )
  let result = wesl_cli_run(
    [
      "compile", "--base", "_build/cli_compile", "--no-strip", "-D", "foo=true",
      "_build/cli_compile/main.wesl",
    ][:],
  )
  inspect(result.status, content="0")
  assert_true(result.stdout.contains("fn enabled"))
  assert_false(result.stdout.contains("fn disabled"))
}

///|
test "wesl cli: check validates WGSL call expressions" {
  cli_test_ensure_dir("_build")
  cli_test_ensure_dir("_build/cli_check")
  try! @fs.write_string_to_file(
    "_build/cli_check/bad.wgsl", "const value = 1i;\nfn main() { let out = value(); }\n",
  )

  let result = wesl_cli_run(
    ["check", "--kind", "wgsl", "_build/cli_check/bad.wgsl"][:],
  )

  inspect(result.status, content="1")
  assert_true(result.stderr.contains("value"))
}

///|
test "wesl cli: check reports diagnostic origin" {
  cli_test_ensure_dir("_build")
  cli_test_ensure_dir("_build/cli_check")
  try! @fs.write_string_to_file(
    "_build/cli_check/diagnostic.wgsl", "const value = 1i;\nfn main() { let out = value(); }\n",
  )

  let result = wesl_cli_run(
    ["check", "--kind", "wgsl", "_build/cli_check/diagnostic.wgsl"][:],
  )

  inspect(result.status, content="1")
  assert_true(result.stderr.contains("error:"))
  assert_true(result.stderr.contains("_build/cli_check/diagnostic.wgsl"))
  assert_true(result.stderr.contains("value"))
}

///|
test "wesl cli: check validates WESL undefined symbols" {
  cli_test_ensure_dir("_build")
  cli_test_ensure_dir("_build/cli_check")
  try! @fs.write_string_to_file(
    "_build/cli_check/bad.wesl", "const value: MissingType = 1i;\n",
  )

  let result = wesl_cli_run(["check", "_build/cli_check/bad.wesl"][:])

  inspect(result.status, content="1")
  assert_true(result.stderr.contains("MissingType"))
}

///|
test "wesl cli: check keeps WESL validation source-local" {
  cli_test_ensure_dir("_build")
  cli_test_ensure_dir("_build/cli_check_imports")
  try! @fs.write_string_to_file(
    "_build/cli_check_imports/main.wesl", "import super::missing::make_value;\n@compute @workgroup_size(1)\nfn main() { let value = make_value(); }\n",
  )

  let result = wesl_cli_run(["check", "_build/cli_check_imports/main.wesl"][:])

  inspect(result.status, content="0")
  inspect(result.stdout, content="OK")
}

///|
test "wesl cli: compile reports diagnostic source context" {
  cli_test_ensure_dir("_build")
  cli_test_ensure_dir("_build/cli_compile_diag")
  try! @fs.write_string_to_file(
    "_build/cli_compile_diag/main.wesl", "const value: MissingType = 1i;\n",
  )

  let result = wesl_cli_run(
    [
      "compile", "--base", "_build/cli_compile_diag", "--no-strip", "_build/cli_compile_diag/main.wesl",
    ][:],
  )

  inspect(result.status, content="1")
  assert_true(result.stderr.contains("error:"))
  assert_true(result.stderr.contains("MissingType"))
  assert_true(result.stderr.contains("main.wesl"))
}

///|
test "wesl cli: naga validation reports unavailable backend" {
  cli_test_ensure_dir("_build")
  cli_test_ensure_dir("_build/cli_check")
  try! @fs.write_string_to_file(
    "_build/cli_check/good.wgsl", "fn main() { let value = 1i; }\n",
  )

  let result = wesl_cli_run(
    ["check", "--kind", "wgsl", "--naga", "_build/cli_check/good.wgsl"][:],
  )

  inspect(result.status, content="1")
  assert_true(result.stderr.contains("Naga validation is not available"))
}

///|
test "wesl cli: package emits scanned codegen artifact" {
  cli_test_ensure_dir("_build")
  cli_test_ensure_dir("_build/cli_package")
  try! @fs.write_string_to_file(
    "_build/cli_package/lib.wesl", "fn exported() -> i32 { return 1; }\n",
  )
  let result = wesl_cli_run(
    ["package", "shader-lib", "_build/cli_package/lib"][:],
  )
  inspect(result.status, content="0")
  assert_true(result.stdout.contains("CodegenPkg::"))
  assert_true(result.stdout.contains("shader_lib"))
}

///|
test "wesl cli: exec runs simple entrypoint return value" {
  cli_test_ensure_dir("_build")
  cli_test_ensure_dir("_build/cli_exec")
  try! @fs.write_string_to_file(
    "_build/cli_exec/main.wesl", "@compute @workgroup_size(1)\nfn main() -> i32 { return 7i; }\n",
  )
  let result = wesl_cli_run(["exec", "_build/cli_exec/main.wesl"][:])
  inspect(result.status, content="0")
  inspect(result.stdout, content="return: 7i")
}

///|
test "wesl cli: exec binary output for scalar return values" {
  cli_test_ensure_dir("_build")
  cli_test_ensure_dir("_build/cli_exec")
  try! @fs.write_string_to_file(
    "_build/cli_exec/binary.wesl", "@compute @workgroup_size(1)\nfn main() -> u32 { return 7u; }\n",
  )
  let result = wesl_cli_run(
    ["exec", "--out-binary", "_build/cli_exec/binary.wesl"][:],
  )
  inspect(result.status, content="0")
  inspect(result.stdout, content="")
  match result.stdout_bytes {
    Some(bytes) =>
      debug_inspect(
        bytes.to_array(),
        content=(
          #|[0x07, 0x00, 0x00, 0x00]
        ),
      )
    None => fail("expected binary stdout")
  }
}

///|
test "wesl cli: exec binary rejects non-storable return values" {
  cli_test_ensure_dir("_build")
  cli_test_ensure_dir("_build/cli_exec")
  try! @fs.write_string_to_file(
    "_build/cli_exec/bool.wesl", "@compute @workgroup_size(1)\nfn main() -> bool { return true; }\n",
  )
  let result = wesl_cli_run(
    ["exec", "--out-binary", "_build/cli_exec/bool.wesl"][:],
  )
  inspect(result.status, content="1")
  assert_true(result.stderr.contains("not storable"))
}

///|
test "wesl cli: exec passes zero-initialized scalar builtin inputs" {
  cli_test_ensure_dir("_build")
  cli_test_ensure_dir("_build/cli_exec")
  try! @fs.write_string_to_file(
    "_build/cli_exec/input_scalar.wesl", "@compute @workgroup_size(1)\nfn main(@builtin(vertex_index) vertex_index: u32) -> u32 { return vertex_index + 1u; }\n",
  )
  let result = wesl_cli_run(["exec", "_build/cli_exec/input_scalar.wesl"][:])
  inspect(result.status, content="0")
  inspect(result.stdout, content="return: 1u")
}

///|
test "wesl cli: exec passes zero-initialized vector builtin inputs" {
  cli_test_ensure_dir("_build")
  cli_test_ensure_dir("_build/cli_exec")
  try! @fs.write_string_to_file(
    "_build/cli_exec/input_vector.wesl", "@compute @workgroup_size(1)\nfn main(@builtin(global_invocation_id) id: vec3<u32>) -> vec3<u32> { return id; }\n",
  )
  let result = wesl_cli_run(
    ["exec", "--out-binary", "_build/cli_exec/input_vector.wesl"][:],
  )
  inspect(result.status, content="0")
  inspect(result.stdout, content="")
  match result.stdout_bytes {
    Some(bytes) =>
      debug_inspect(
        bytes.to_array(),
        content=(
          #|[
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
          #|]
        ),
      )
    None => fail("expected builtin input binary stdout")
  }
}

///|
test "wesl cli: exec applies override values" {
  cli_test_ensure_dir("_build")
  cli_test_ensure_dir("_build/cli_exec")
  try! @fs.write_string_to_file(
    "_build/cli_exec/override.wesl", "override SCALE: u32 = 2u;\n@compute @workgroup_size(1)\nfn main() -> u32 { return SCALE + 1u; }\n",
  )
  let result = wesl_cli_run(
    ["exec", "--override", "SCALE=41u", "_build/cli_exec/override.wesl"][:],
  )
  inspect(result.status, content="0")
  inspect(result.stdout, content="return: 42u")
}

///|
test "wesl cli: exec rejects malformed override values" {
  let result = wesl_cli_run(["exec", "--override", "SCALE"][:])
  inspect(result.status, content="1")
  assert_true(result.stderr.contains("NAME=EXPRESSION"))
}

///|
test "wesl cli: exec reads scalar resource buffers" {
  cli_test_ensure_dir("_build")
  cli_test_ensure_dir("_build/cli_exec")
  try! @fs.write_string_to_file(
    "_build/cli_exec/resource.wesl", "@group(0) @binding(0) var<uniform> DATA: u32;\n@compute @workgroup_size(1)\nfn main() -> u32 { return DATA + 1u; }\n",
  )
  try! @fs.write_bytes_to_file(
    "_build/cli_exec/resource.bin",
    Bytes::from_array([b'\x29', b'\x00', b'\x00', b'\x00']),
  )
  let result = wesl_cli_run(
    [
      "exec", "--resource", "0:0:uniform:_build/cli_exec/resource.bin", "_build/cli_exec/resource.wesl",
    ][:],
  )
  inspect(result.status, content="0")
  inspect(result.stdout, content="return: 42u")
}

///|
test "wesl cli: exec binary output includes scalar resource values" {
  cli_test_ensure_dir("_build")
  cli_test_ensure_dir("_build/cli_exec")
  try! @fs.write_string_to_file(
    "_build/cli_exec/resource_binary.wesl", "@group(0) @binding(0) var<storage> DATA: u32;\n@compute @workgroup_size(1)\nfn main() -> u32 { return DATA + 1u; }\n",
  )
  try! @fs.write_bytes_to_file(
    "_build/cli_exec/resource_binary.bin",
    Bytes::from_array([b'\x29', b'\x00', b'\x00', b'\x00']),
  )
  let result = wesl_cli_run(
    [
      "exec", "--out-binary", "--resource", "0:0:storage:_build/cli_exec/resource_binary.bin",
      "_build/cli_exec/resource_binary.wesl",
    ][:],
  )
  inspect(result.status, content="0")
  inspect(result.stdout, content="")
  match result.stdout_bytes {
    Some(bytes) =>
      debug_inspect(
        bytes.to_array(),
        content=(
          #|[0x2a, 0x00, 0x00, 0x00]
        ),
      )
    None => fail("expected resource binary stdout")
  }
}

///|
test "wesl cli: exec binary output includes vector resource values" {
  cli_test_ensure_dir("_build")
  cli_test_ensure_dir("_build/cli_exec")
  try! @fs.write_string_to_file(
    "_build/cli_exec/resource_vector.wesl", "@group(0) @binding(0) var<uniform> DATA: vec2<u32>;\n@compute @workgroup_size(1)\nfn main() -> vec2<u32> { return DATA + vec2<u32>(1u); }\n",
  )
  try! @fs.write_bytes_to_file(
    "_build/cli_exec/resource_vector.bin",
    Bytes::from_array([
      b'\x01', b'\x00', b'\x00', b'\x00', b'\x02', b'\x00', b'\x00', b'\x00',
    ]),
  )
  let result = wesl_cli_run(
    [
      "exec", "--out-binary", "--resource", "0:0:uniform:_build/cli_exec/resource_vector.bin",
      "_build/cli_exec/resource_vector.wesl",
    ][:],
  )
  inspect(result.status, content="0")
  inspect(result.stdout, content="")
  match result.stdout_bytes {
    Some(bytes) =>
      debug_inspect(
        bytes.to_array(),
        content=(
          #|[0x02, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00]
        ),
      )
    None => fail("expected vector resource binary stdout")
  }
}

///|
test "wesl cli: exec binary output includes struct resource values" {
  cli_test_ensure_dir("_build")
  cli_test_ensure_dir("_build/cli_exec")
  try! @fs.write_string_to_file(
    "_build/cli_exec/resource_struct.wesl", "struct Data {\n  a: u32,\n  b: vec3<f32>,\n  c: u32,\n}\n\n@group(0) @binding(0) var<uniform> DATA: Data;\n@compute @workgroup_size(1)\nfn main() -> Data { return DATA; }\n",
  )
  try! @fs.write_bytes_to_file(
    "_build/cli_exec/resource_struct.bin",
    Bytes::from_array([
      b'\x2A', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
      b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
      b'\x80', b'\x3F', b'\x00', b'\x00', b'\x00', b'\x40', b'\x00', b'\x00', b'\x40',
      b'\x40', b'\x07', b'\x00', b'\x00', b'\x00',
    ]),
  )
  let result = wesl_cli_run(
    [
      "exec", "--out-binary", "--resource", "0:0:uniform:_build/cli_exec/resource_struct.bin",
      "_build/cli_exec/resource_struct.wesl",
    ][:],
  )
  inspect(result.status, content="0")
  inspect(result.stdout, content="")
  match result.stdout_bytes {
    Some(bytes) =>
      debug_inspect(
        bytes.to_array(),
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
    None => fail("expected struct resource binary stdout")
  }
}

///|
test "wesl cli: exec binary output includes array resource stride padding" {
  cli_test_ensure_dir("_build")
  cli_test_ensure_dir("_build/cli_exec")
  try! @fs.write_string_to_file(
    "_build/cli_exec/resource_array.wesl", "@group(0) @binding(0) var<uniform> DATA: array<vec3<f32>, 2>;\n@compute @workgroup_size(1)\nfn main() -> array<vec3<f32>, 2> { return DATA; }\n",
  )
  try! @fs.write_bytes_to_file(
    "_build/cli_exec/resource_array.bin",
    Bytes::from_array([
      b'\x00', b'\x00', b'\x80', b'\x3F', b'\x00', b'\x00', b'\x00', b'\x40', b'\x00',
      b'\x00', b'\x40', b'\x40', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
      b'\x80', b'\x40', b'\x00', b'\x00', b'\xA0', b'\x40', b'\x00', b'\x00', b'\xC0',
      b'\x40', b'\x00', b'\x00', b'\x00', b'\x00',
    ]),
  )
  let result = wesl_cli_run(
    [
      "exec", "--out-binary", "--resource", "0:0:uniform:_build/cli_exec/resource_array.bin",
      "_build/cli_exec/resource_array.wesl",
    ][:],
  )
  inspect(result.status, content="0")
  inspect(result.stdout, content="")
  match result.stdout_bytes {
    Some(bytes) =>
      debug_inspect(
        bytes.to_array(),
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
    None => fail("expected array resource binary stdout")
  }
}

///|
test "wesl cli: exec rejects malformed resource bindings" {
  let result = wesl_cli_run(["exec", "--resource", "0:0:uniform"][:])
  inspect(result.status, content="1")
  assert_true(result.stderr.contains("GROUP:BINDING:TYPE:PATH"))
}
