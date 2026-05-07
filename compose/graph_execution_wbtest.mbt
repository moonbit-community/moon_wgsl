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
test "composer uses naga_oil module decoration for planned imported names" {
  debug_inspect(wgsl_naga_oil_base32_nopad("inc"), content="\"NFXGG\"")
  debug_inspect(wgsl_naga_oil_base32_nopad("mod"), content="\"NVXWI\"")
  debug_inspect(
    wgsl_naga_oil_decorated_final_name("inc", "hello"),
    content="\"helloX_naga_oil_mod_XNFXGGX\"",
  )
}

///|
test "compose graph execution plans reachability before emission" {
  let composer = Composer::default()
  let dep_source =
    #|#define_import_path dep
    #|fn dep_fn() -> u32 {
    #|  return 1u;
    #|}
    #|
  composer.register_source("dep.wgsl", dep_source)
  let session = composer.new_wgsl_compose_session(WgslComposeOptions::default())
  let source =
    #|#import dep::dep_fn
    #|fn root() -> u32 {
    #|  return dep_fn();
    #|}
    #|
  composer.complete_wgsl_compose_graph_execution(
    "root.wgsl",
    source,
    session,
    None,
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(session.graph_execution_complete, content="true")
  debug_inspect(session.link_graph.import_edge_count(), content="1")
  debug_inspect(
    session.link_graph.contains_reachable_symbol(
      WgslIrSymbolIdentity::new("dep.wgsl", "dep_fn"),
    ),
    content="true",
  )
  debug_inspect(session.final_names.canonical_entry_count(), content="0")
  let output = composer.preprocess_wgsl_source_with_path(
    "root.wgsl",
    source,
    session,
    None,
    WgslComposeBindingSet::new(),
    true,
    true,
    [],
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(output.contains("fn dep_fn"), content="true")
  debug_inspect(
    session.final_names.canonical_get(
      WgslIrSymbolIdentity::new("dep.wgsl", "dep_fn"),
    )
    is Some(_),
    content="true",
  )
}

///|
test "composer exposes IR-backed compose output" {
  let composer = Composer::default()
  let inc_source =
    #|#define_import_path ir_corpus::inc
    #|
    #|fn helper(value: u32) -> u32 {
    #|  return value + 1u;
    #|}
    #|
  composer.register_source("inc.wgsl", inc_source)
  let top_source =
    #|#import ir_corpus::inc::helper
    #|
    #|@group(0) @binding(0)
    #|var<storage, read_write> buffer: u32;
    #|
    #|@compute @workgroup_size(1, 1, 1)
    #|fn main() {
    #|  var result: u32 = helper(1u);
    #|  result = min(result, 9u);
    #|  buffer = result;
    #|}
    #|
  composer.register_source("top.wgsl", top_source)
  let emitted = composer.compose_wgsl_ir(
    "top.wgsl",
    WgslComposeOptions::default(),
  ) catch {
    error => abort(error.message())
  }
  debug_inspect(emitted.contains("#import"), content="false")
  debug_inspect(emitted.contains("fn helper"), content="true")
  debug_inspect(emitted.contains("@compute @workgroup_size"), content="true")
}
