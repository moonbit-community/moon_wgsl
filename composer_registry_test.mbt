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
fn composer_test_descriptor(
  source : String,
  file_path : String,
  shader_defs : @hashmap.HashMap[String, @moon_wgsl.ShaderDefValue],
) -> @moon_wgsl.ComposableModuleDescriptor {
  @moon_wgsl.ComposableModuleDescriptor::{
    source,
    file_path,
    language: @moon_wgsl.ShaderLanguage::Wgsl,
    as_name: None,
    additional_imports: [],
    shader_defs,
  }
}

///|
fn composer_test_add_or_abort(
  composer : @moon_wgsl.Composer,
  desc : @moon_wgsl.ComposableModuleDescriptor,
) -> @moon_wgsl.ComposableModuleDefinition {
  composer.add_composable_module(desc) catch {
    err => abort("expected add_composable_module success: \{err.message()}")
  }
}

///|
test "naga_oil: composer add_composable_module mirrors module bookkeeping" {
  let composer = @moon_wgsl.Composer::default()
  let base_shader_defs : @hashmap.HashMap[String, @moon_wgsl.ShaderDefValue] = @hashmap.HashMap::new()
  base_shader_defs.set("BASE_DEF", @moon_wgsl.ShaderDefValue::Bool(true))

  let base_definition = composer_test_add_or_abort(
    composer,
    composer_test_descriptor(
      "#define_import_path test::base\nfn base_value() -> f32 {\n  return 1.0;\n}\n",
      "tests/base.wgsl", base_shader_defs,
    ),
  )
  debug_inspect(base_definition.name, content="\"test::base\"")
  debug_inspect(base_definition.all_imports.is_empty(), content="true")

  let child_definition = composer_test_add_or_abort(
    composer,
    composer_test_descriptor(
      "#define_import_path test::child\n#import test::base::base_value\n#ifdef USE_CHILD\nfn child_value() -> f32 {\n  return base_value();\n}\n#else\nfn child_value() -> f32 {\n  return 0.0;\n}\n#endif\n",
      "tests/child.wgsl",
      @hashmap.HashMap::new(),
    ),
  )

  debug_inspect(composer.contains_module("test::base"), content="true")
  debug_inspect(composer.contains_module("test::child"), content="true")
  debug_inspect(child_definition.name, content="\"test::child\"")
  debug_inspect(
    child_definition.all_imports.contains("test::base"),
    content="true",
  )
  debug_inspect(
    child_definition.effective_defs.contains("USE_CHILD"),
    content="true",
  )
  debug_inspect(
    child_definition.shader_defs.get("BASE_DEF"),
    content="Some(Bool(true))",
  )
}

///|
test "naga_oil: composer remove_composable_module removes dependent modules" {
  let composer = @moon_wgsl.Composer::default()
  ignore(
    composer_test_add_or_abort(
      composer,
      composer_test_descriptor(
        "#define_import_path test::base\nfn base_value() -> f32 {\n  return 1.0;\n}\n",
        "tests/base_remove.wgsl",
        @hashmap.HashMap::new(),
      ),
    ),
  )
  ignore(
    composer_test_add_or_abort(
      composer,
      composer_test_descriptor(
        "#define_import_path test::child\n#import test::base::base_value\nfn child_value() -> f32 {\n  return base_value();\n}\n",
        "tests/child_remove.wgsl",
        @hashmap.HashMap::new(),
      ),
    ),
  )

  composer.remove_composable_module("test::base")

  debug_inspect(composer.contains_module("test::base"), content="false")
  debug_inspect(composer.contains_module("test::child"), content="false")
}

///|
test "naga_oil: composer rejects modules without an import path name" {
  let composer = @moon_wgsl.Composer::default()
  let mut message : String? = None
  ignore(
    composer.add_composable_module(
      composer_test_descriptor(
        "fn shade() -> f32 {\n  return 1.0;\n}\n",
        "tests/no_name.wgsl",
        @hashmap.HashMap::new(),
      ),
    ),
  ) catch {
    err => message = Some(err.message())
  }
  guard message is Some(error_message) else {
    abort("expected missing module-name error")
  }
  debug_inspect(
    error_message,
    content="\"shader module is missing #define_import_path: tests/no_name.wgsl\"",
  )
}
