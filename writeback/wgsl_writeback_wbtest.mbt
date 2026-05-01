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
test "writeback sanitizer rewrites reserved local bindings through AST scopes" {
  let source =
    #|fn fragment(value: f32) -> f32 {
    #|  let in = value + 1.0;
    #|  return in;
    #|}
    #|
  let rewritten = sanitize_wgsl_writeback_identifiers(source)
  debug_inspect(
    rewritten.contains("let in_wgsl = value + 1.0;"),
    content="true",
  )
  debug_inspect(rewritten.contains("return in_wgsl;"), content="true")
  debug_inspect(rewritten.contains("return in;"), content="false")
}

///|
test "writeback sanitizer rewrites naga local prefixes through AST scopes" {
  let source =
    #|fn fragment(value: f32) -> f32 {
    #|  let _naga_tmp = value + 1.0;
    #|  return _naga_tmp;
    #|}
    #|
  let rewritten = sanitize_wgsl_writeback_identifiers(source)
  debug_inspect(
    rewritten.contains("let gen__naga_tmp = value + 1.0;"),
    content="true",
  )
  debug_inspect(rewritten.contains("return gen__naga_tmp;"), content="true")
  debug_inspect(rewritten.contains("return _naga_tmp;"), content="false")
}

///|
test "writeback sanitizer rewrites nested local bindings through AST scopes" {
  let source =
    #|fn fragment(value: f32) -> f32 {
    #|  if (value > 0.0) {
    #|    let in = value + 1.0;
    #|    return in;
    #|  }
    #|  return value;
    #|}
    #|
  let rewritten = sanitize_wgsl_writeback_identifiers(source)
  debug_inspect(
    rewritten.contains("let in_wgsl = value + 1.0;"),
    content="true",
  )
  debug_inspect(rewritten.contains("return in_wgsl;"), content="true")
  debug_inspect(rewritten.contains("return in;"), content="false")
}
