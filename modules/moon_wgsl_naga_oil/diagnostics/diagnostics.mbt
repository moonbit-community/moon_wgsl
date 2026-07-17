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
/// Return the prepared Compose source immediately before semantic IR lowering.
pub fn compose_before_ir(
  composer : @compose.Composer,
  rel_path : String,
  options : @contract.WgslComposeOptions,
) -> String raise @compose.ComposerError {
  composer.compose_wgsl_before_ir(rel_path, options)
}

///|
/// Run the compatibility writer used by the external naga-oil parity oracle.
pub fn compose_for_writer_parity(
  composer : @compose.Composer,
  rel_path : String,
  options : @contract.WgslComposeOptions,
) -> String raise @compose.ComposerError {
  composer.compose_wgsl_for_naga_oil_writer_parity(rel_path, options)
}

///|
/// Trace one function's compatibility writer plan.
pub fn trace_writer_function_plan(
  composer : @compose.Composer,
  rel_path : String,
  options : @contract.WgslComposeOptions,
  function_name_prefix : String,
) -> String raise @compose.ComposerError {
  composer.trace_naga_oil_writer_function_plan(
    rel_path, options, function_name_prefix,
  )
}

///|
/// Trace the compatibility writer's complete module plan.
pub fn trace_writer_module_plan(
  composer : @compose.Composer,
  rel_path : String,
  options : @contract.WgslComposeOptions,
) -> String raise @compose.ComposerError {
  composer.trace_naga_oil_writer_module_plan(rel_path, options)
}
