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
  shader_defs : Map[String, @contract.ShaderDefValue],
) -> @contract.ComposableModuleDescriptor {
  {
    ..@contract.ComposableModuleDescriptor::default(),
    source,
    file_path,
    shader_defs,
  }
}

///|
fn composer_test_add_or_abort(
  composer : @compose.Composer,
  desc : @contract.ComposableModuleDescriptor,
) -> @compose.ComposableModuleDefinition {
  composer.add_composable_module(desc) catch {
    err => abort("expected add_composable_module success: \{err.message()}")
  }
}

///|
test "naga_oil: composer add_composable_module mirrors module bookkeeping" {
  let composer = @compose.Composer::default()
  let base_shader_defs : Map[String, @contract.ShaderDefValue] = Map([])
  base_shader_defs.set("BASE_DEF", Bool(true))

  let base_definition = composer_test_add_or_abort(
    composer,
    composer_test_descriptor(
      (
        #|#define_import_path test::base
        #|fn base_value() -> f32 {
        #|  return 1f;
        #|}
        #|
      ),
      "tests/base.wgsl",
      base_shader_defs,
    ),
  )
  debug_inspect(base_definition.name(), content="\"test::base\"")
  debug_inspect(base_definition.all_imports_is_empty(), content="true")

  let child_definition = composer_test_add_or_abort(
    composer,
    composer_test_descriptor(
      (
        #|#define_import_path test::child
        #|#import test::base::base_value
        #|#ifdef USE_CHILD
        #|fn child_value() -> f32 {
        #|  return base_value();
        #|}
        #|#else
        #|fn child_value() -> f32 {
        #|  return 0.0;
        #|}
        #|#endif
        #|
      ),
      "tests/child.wgsl",
      Map([]),
    ),
  )

  debug_inspect(composer.contains_module("test::base"), content="true")
  debug_inspect(composer.contains_module("test::child"), content="true")
  debug_inspect(child_definition.name(), content="\"test::child\"")
  debug_inspect(child_definition.imports_module("test::base"), content="true")
  debug_inspect(
    child_definition.contains_effective_def("USE_CHILD"),
    content="true",
  )
  debug_inspect(
    child_definition.shader_def("BASE_DEF"),
    content="Some(Bool(true))",
  )
}

///|
test "naga_oil: composer remove_composable_module removes dependent modules" {
  let composer = @compose.Composer::default()
  ignore(
    composer_test_add_or_abort(
      composer,
      composer_test_descriptor(
        (
          #|#define_import_path test::base
          #|fn base_value() -> f32 {
          #|  return 1f;
          #|}
          #|
        ),
        "tests/base_remove.wgsl",
        Map([]),
      ),
    ),
  )
  ignore(
    composer_test_add_or_abort(
      composer,
      composer_test_descriptor(
        (
          #|#define_import_path test::child
          #|#import test::base::base_value
          #|fn child_value() -> f32 {
          #|  return base_value();
          #|}
          #|
        ),
        "tests/child_remove.wgsl",
        Map([]),
      ),
    ),
  )

  composer.remove_composable_module("test::base")

  debug_inspect(composer.contains_module("test::base"), content="false")
  debug_inspect(composer.contains_module("test::child"), content="false")
}

///|
test "naga_oil: composer rejects modules without an import path name" {
  let composer = @compose.Composer::default()
  let mut message : String? = None
  ignore(
    composer.add_composable_module(
      composer_test_descriptor(
        (
          #|fn shade() -> f32 {
          #|  return 1f;
          #|}
          #|
        ),
        "tests/no_name.wgsl",
        Map([]),
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

///|
test "naga_oil: add_composable_module resolves imports from the composer registry" {
  let composer = @compose.Composer::default()
  composer.register_source(
    "tests/plain_shared.wgsl",
    (
      #|#define_import_path test::plain
      #|fn plain_value() -> f32 {
      #|  return 2f;
      #|}
      #|
    ),
  )

  let child_definition = composer_test_add_or_abort(
    composer,
    composer_test_descriptor(
      (
        #|#define_import_path test::child
        #|#import test::plain::plain_value
        #|fn child_value() -> f32 {
        #|  return plain_value();
        #|}
        #|
      ),
      "tests/child_against_registry.wgsl",
      Map([]),
    ),
  )

  debug_inspect(child_definition.imports_module("test::plain"), content="true")

  let composed = composer.compose_wgsl("tests/child_against_registry.wgsl", {
    ..@contract.WgslComposeOptions::default(),
    defines: Map([]),
    value_defines: @profile.bevy_wgsl_value_defines(),
  }) catch {
    err =>
      abort(
        "expected registry-backed composable module compose success: \{err.message()}",
      )
  }

  debug_inspect(composed.contains("fn plain_value"), content="true")
  debug_inspect(composed.contains("fn child_value"), content="true")
  debug_inspect(
    composed.contains("plain_valueX_naga_oil_mod_X"),
    content="true",
  )
}
