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
fn upstream_assert_parse_result(
  case_name : String,
  source : String,
  expect_pass : Bool,
) -> String? {
  let root_path = ModulePath::from_path("/main.wgsl")
  let result = try parse_translation_unit(root_path, source, true) catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  match (expect_pass, result) {
    (true, Ok(_)) => None
    (false, Err(_)) => None
    (true, Err(err)) =>
      Some("\{case_name}: expected parse success, got \{err.message()}")
    (false, Ok(_)) => Some("\{case_name}: expected parse failure")
  }
}

///|
fn upstream_assert_expression_parse_result(
  case_name : String,
  source : String,
  expect_pass : Bool,
) -> String? {
  let result = try parse_expression(source) catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  match (expect_pass, result) {
    (true, Ok(_)) => None
    (false, Err(_)) => None
    (true, Err(err)) =>
      Some("\{case_name}: expected parse success, got \{err.message()}")
    (false, Ok(_)) => Some("\{case_name}: expected parse failure")
  }
}

///|
fn upstream_assert_eval_case(case : UpstreamEvalSpecCase) -> String? {
  let result = try eval_const(case.code, case.eval) catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  match (case.expect_pass, result) {
    (true, Ok(actual)) =>
      match case.expected_result {
        Some(expected) =>
          if actual.to_string() == expected {
            None
          } else {
            Some(
              "\{case.name}: expected `\{expected}`, got `\{actual.to_string()}`",
            )
          }
        None =>
          Some(
            "\{case.name}: expected eval failure, got `\{actual.to_string()}`",
          )
      }
    (false, Err(_)) => None
    (true, Err(err)) =>
      Some("\{case.name}: expected eval success, got \{err.message()}")
    (false, Ok(actual)) =>
      Some("\{case.name}: expected eval failure, got `\{actual.to_string()}`")
  }
}

///|
fn upstream_assert_standalone_compile_result(
  case_name : String,
  path : String,
  source : String,
) -> String? {
  let resolver = VirtualResolver::new()
  let root_path = upstream_fixture_module_path(path)
  resolver.add_module(root_path, source)
  let result = try
    compile(root_path, resolver, EscapeMangler::default(), {
      ..CompileOptions::default(),
      keep_root: true,
    })
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  match result {
    Ok(compiled) =>
      if compiled.to_string().trim().to_owned() == "" {
        Some("\{case_name}: expected non-empty compiled output")
      } else {
        None
      }
    Err(err) =>
      Some("\{case_name}: expected compile success, got \{err.message()}")
  }
}

///|
fn upstream_assert_bulk_case(case : UpstreamBulkCase) -> String? {
  if case.name.trim().to_owned() == "" {
    return Some("bulk case metadata: expected non-empty case name")
  }
  if case.base_dir.trim().to_owned() == "" {
    return Some("\{case.name}: expected non-empty base_dir")
  }
  if case.include_paths.length() == 0 {
    return Some("\{case.name}: expected at least one include path")
  }
  match (case.git_url, case.git_revision) {
    (Some(url), Some(revision)) => {
      if url.trim().to_owned() == "" {
        return Some("\{case.name}: expected non-empty git_url")
      }
      if revision.trim().to_owned() == "" {
        return Some("\{case.name}: expected non-empty git_revision")
      }
    }
    (None, None) => ()
    _ =>
      return Some(
        "\{case.name}: expected git_url and git_revision to be both present or both absent",
      )
  }
  for path in case.include_paths {
    if path.trim().to_owned() == "" {
      return Some("\{case.name}: include path must not be empty")
    }
    if !upstream_is_shader_path(path) {
      return Some(
        "\{case.name}: include path must point to a shader fixture: \{path}",
      )
    }
  }
  for path in case.exclude_paths {
    if path.trim().to_owned() == "" {
      return Some("\{case.name}: exclude path must not be empty")
    }
    if !upstream_is_shader_path(path) {
      return Some(
        "\{case.name}: exclude path must point to a shader fixture: \{path}",
      )
    }
  }
  None
}

///|
fn upstream_assert_context_case_with_options(
  case : UpstreamContextCase,
  options : CompileOptions,
) -> String? {
  let resolver = VirtualResolver::new()
  let root_path = ModulePath::from_path("/main.wgsl")
  resolver.add_module(root_path, case.source)
  let result = try
    compile(root_path, resolver, EscapeMangler::default(), options)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  match (case.expect_pass, result) {
    (true, Ok(_)) => None
    (false, Err(_)) => None
    (true, Err(err)) =>
      Some("\{case.name}: expected pass, got \{err.message()}")
    (false, Ok(compiled)) =>
      Some("\{case.name}: expected failure, got \{compiled.to_string()}")
  }
}

///|
fn upstream_assert_context_case(case : UpstreamContextCase) -> String? {
  upstream_assert_context_case_with_options(case, {
    ..CompileOptions::default(),
    lower: case.lower,
  })
}

///|
fn upstream_assert_module_case(case : UpstreamModuleCase) -> String? {
  let actual_result = try upstream_compile_module_case(case) catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  let actual = match actual_result {
    Ok(actual) => actual
    Err(err) =>
      return Some("\{case.name}: compile failed with \{err.message()}")
  }
  let normalized_actual = upstream_canonicalize_decl_order(actual)
  match upstream_expected_output(case) {
    Some(expected) => {
      let normalized_expected = upstream_canonicalize_decl_order(expected)
      if normalized_actual != normalized_expected {
        Some(
          "\{case.name}: expected `\{normalized_expected}`, got `\{normalized_actual}`",
        )
      } else {
        None
      }
    }
    None =>
      if normalized_actual == "" {
        Some("\{case.name}: expected non-empty compiled output")
      } else {
        None
      }
  }
}

///|
let upstream_bevy_standalone_compile_paths : Array[String] = [
  "bevy/custom_material_import.wgsl", "bevy/custom_phase_item.wgsl", "bevy/game_of_life.wgsl",
  "bevy/gpu_readback.wgsl", "bevy/util.wesl",
]

///|
let upstream_bevy_file_resolver_compile_paths : Array[String] = [
  "bevy/custom_material.wesl",
]

///|
test "upstream: vendored corpus manifest is present" {
  debug_inspect(upstream_spec_syntax_cases.length(), content="11")
  debug_inspect(upstream_spec_eval_cases.length(), content="27")
  debug_inspect(upstream_import_syntax_cases.length(), content="33")
  debug_inspect(upstream_import_cases.length(), content="40")
  debug_inspect(upstream_conditional_cases.length(), content="54")
  debug_inspect(upstream_dead_code_cases.length(), content="3")
  debug_inspect(upstream_import_context_cases.length(), content="4")
  debug_inspect(upstream_circular_context_cases.length(), content="7")
  debug_inspect(upstream_type_context_cases.length(), content="4")
  debug_inspect(upstream_bulk_cases.length(), content="3")
  debug_inspect(upstream_ctor_coverage_cases.length(), content="1")
  debug_inspect(upstream_bevy_e2e_cases.length(), content="33")
  debug_inspect(upstream_wgpu_e2e_cases.length(), content="248")
  for case in upstream_spec_syntax_cases {
    ignore(case.suite)
    ignore(case.description)
  }
  for case in upstream_spec_eval_cases {
    ignore(case.suite)
    ignore(case.description)
    ignore(case.stage)
  }
  for case in upstream_import_cases {
    ignore(case.notes)
  }
  for case in upstream_conditional_cases {
    ignore(case.notes)
  }
  for case in upstream_dead_code_cases {
    ignore(case.notes)
  }
  for case in upstream_import_context_cases {
    ignore(case.description)
  }
  for case in upstream_circular_context_cases {
    ignore(case.description)
  }
  for case in upstream_type_context_cases {
    ignore(case.description)
  }
  for case in upstream_bevy_e2e_cases {
    ignore(case.suite)
  }
  for case in upstream_wgpu_e2e_cases {
    ignore(case.suite)
  }
}

///|
test "upstream: spec declaration syntax cases parse at translation-unit level" {
  for case in upstream_spec_syntax_cases {
    if case.syntax_kind != "declaration" {
      continue
    }
    if upstream_array_contains(
        upstream_pending_spec_declaration_case_names,
        case.name,
      ) {
      continue
    }
    match upstream_assert_parse_result(case.name, case.code, case.expect_pass) {
      Some(message) => fail(message)
      None => ()
    }
  }
}

///|
test "upstream: spec expression syntax cases" {
  for case in upstream_spec_syntax_cases {
    if case.syntax_kind == "expression" {
      match
        upstream_assert_expression_parse_result(
          case.name,
          case.code,
          case.expect_pass,
        ) {
        Some(message) => fail(message)
        None => ()
      }
    }
  }
}

///|
test "upstream: spec eval cases" {
  for case in upstream_spec_eval_cases {
    if upstream_array_contains(upstream_pending_spec_eval_case_names, case.name) {
      continue
    }
    match upstream_assert_eval_case(case) {
      Some(message) => fail(message)
      None => ()
    }
  }
}

///|
test "upstream: import syntax cases parse at syntax-tree level" {
  for case in upstream_import_syntax_cases {
    if upstream_array_contains(
        upstream_pending_import_syntax_case_names,
        case.name,
      ) {
      continue
    }
    match upstream_assert_parse_result(case.name, case.source, !case.fails) {
      Some(message) => fail(message)
      None => ()
    }
  }
}

///|
test "upstream: import context cases" {
  for case in upstream_import_context_cases {
    match upstream_assert_context_case(case) {
      Some(message) => fail(message)
      None => ()
    }
  }
}

///|
test "upstream: circular context cases" {
  for case in upstream_circular_context_cases {
    if upstream_array_contains(upstream_pending_circular_case_names, case.name) {
      continue
    }
    match upstream_assert_context_case(case) {
      Some(message) => fail(message)
      None => ()
    }
  }
}

///|
test "upstream: type context cases" {
  for case in upstream_type_context_cases {
    match
      upstream_assert_context_case_with_options(case, {
        ..CompileOptions::default(),
        lower: if case.expect_pass {
          case.lower
        } else {
          false
        },
        strip: false,
        keep_root: true,
      }) {
      Some(message) => fail(message)
      None => ()
    }
  }
}

///|
test "upstream: import cases compile against vendored corpus" {
  for case in upstream_import_cases {
    if upstream_array_contains(upstream_pending_import_case_names, case.name) {
      continue
    }
    match upstream_assert_module_case(case) {
      Some(message) => fail(message)
      None => ()
    }
  }
}

///|
test "upstream: conditional translation cases compile against vendored corpus" {
  for case in upstream_conditional_cases {
    if upstream_array_contains(
        upstream_pending_conditional_case_names,
        case.name,
      ) {
      continue
    }
    match upstream_assert_module_case(case) {
      Some(message) => fail(message)
      None => ()
    }
  }
}

///|
test "upstream: dead code cases compile against vendored corpus" {
  for case in upstream_dead_code_cases {
    match upstream_assert_module_case(case) {
      Some(message) => fail(message)
      None => ()
    }
  }
}

///|
test "upstream: bulk validation metadata is internally consistent" {
  for case in upstream_bulk_cases {
    match upstream_assert_bulk_case(case) {
      Some(message) => fail(message)
      None => ()
    }
  }
}

///|
test "upstream: ctor coverage fixture compiles through current validator slice" {
  for case in upstream_ctor_coverage_cases {
    match
      upstream_assert_standalone_compile_result(
        case.path,
        case.path,
        case.source,
      ) {
      Some(message) => fail(message)
      None => ()
    }
  }
}

///|
test "upstream: bevy shader fixtures parse at translation-unit level" {
  for case in upstream_bevy_e2e_cases {
    if !upstream_is_shader_path(case.path) {
      continue
    }
    if upstream_array_contains(
        upstream_pending_bevy_parse_case_paths,
        case.path,
      ) {
      continue
    }
    match upstream_assert_parse_result(case.path, case.source, true) {
      Some(message) => fail(message)
      None => ()
    }
  }
}

///|
test "upstream: bevy standalone fixtures without package imports compile through current slice" {
  for case in upstream_bevy_e2e_cases {
    if !upstream_array_contains(
        upstream_bevy_standalone_compile_paths,
        case.path,
      ) {
      continue
    }
    match
      upstream_assert_standalone_compile_result(
        case.path,
        case.path,
        case.source,
      ) {
      Some(message) => fail(message)
      None => ()
    }
  }
}

///|
#skip
test "upstream: bevy package-import integration e2e awaits resolver parity" {
  for case in upstream_bevy_e2e_cases {
    if upstream_is_shader_path(case.path) &&
      !upstream_array_contains(
        upstream_bevy_standalone_compile_paths,
        case.path,
      ) &&
      !upstream_array_contains(
        upstream_bevy_file_resolver_compile_paths,
        case.path,
      ) {
      ignore(case)
    }
  }
}

///|
test "upstream: wgpu fixtures parse at translation-unit level" {
  for case in upstream_wgpu_e2e_cases {
    if upstream_array_contains(
        upstream_pending_wgpu_parse_case_paths,
        case.path,
      ) {
      continue
    }
    match upstream_assert_parse_result(case.path, case.source, true) {
      Some(message) => fail(message)
      None => ()
    }
  }
}

///|
#skip
test "upstream: wgpu validation e2e awaits validate and lower parity" {
  for case in upstream_wgpu_e2e_cases {
    ignore(case)
  }
}
