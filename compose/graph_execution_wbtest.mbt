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
