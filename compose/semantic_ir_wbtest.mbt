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
fn semantic_ir_facts(source : String) -> WgslComposeSemanticFacts {
  let declarations = collect_wgsl_named_declarations_strict(source) catch {
    _ => abort("expected semantic IR fixture parse success")
  }
  WgslComposeSemanticFacts::{ declarations, }
}

///|
fn push_required_alias_binding(
  bindings : WgslComposeBindingSet,
  rel_path : String,
  alias_name : String,
  original_name : String,
  final_name : String,
) -> Unit {
  match
    WgslComposeBinding::for_alias_symbol(
      rel_path,
      alias_name,
      original_name,
      final_name,
      QualifiedAliasBinding,
    ) {
    Some(binding) => bindings.push(binding)
    None => abort("expected valid alias binding fixture")
  }
}

///|
test "compose semantic IR resolves undeclared alias target through emitted identity" {
  let source =
    #|struct view_bindings__View {
    #|  value: f32,
    #|}
    #|var<private> view_bindings__view: view_bindings__View;
    #|
  let bindings = WgslComposeBindingSet()
  push_required_alias_binding(
    bindings, "mesh_view_bindings.wgsl", "view_bindings", "view", "view_bindings__view",
  )
  push_required_alias_binding(
    bindings, "mesh_view_bindings.wgsl", "view_bindings", "view", "shadows__view_bindings__view",
  )
  let plan = WgslComposeSemanticIr::from_facts_and_bindings(
    semantic_ir_facts(source),
    bindings,
  ).live_binding_plan()
  let mut unresolved_alias_targets = 0
  let mut emitted_identity_targets = 0
  for binding in plan.bindings {
    if binding.target.final_name == "shadows__view_bindings__view" {
      unresolved_alias_targets = unresolved_alias_targets + 1
    }
    if binding.target.final_name == "view_bindings__view" {
      emitted_identity_targets = emitted_identity_targets + 1
    }
  }
  debug_inspect(unresolved_alias_targets, content="0")
  debug_inspect(emitted_identity_targets > 0, content="true")
}

///|
test "compose semantic IR preserves declared alias-scope target" {
  let source =
    #|struct view_bindings__View {
    #|  value: f32,
    #|}
    #|var<private> view_bindings__view: view_bindings__View;
    #|var<private> shadows__view_bindings__view: view_bindings__View;
    #|
  let bindings = WgslComposeBindingSet()
  push_required_alias_binding(
    bindings, "mesh_view_bindings.wgsl", "view_bindings", "view", "view_bindings__view",
  )
  push_required_alias_binding(
    bindings, "mesh_view_bindings.wgsl", "view_bindings", "view", "shadows__view_bindings__view",
  )
  let plan = WgslComposeSemanticIr::from_facts_and_bindings(
    semantic_ir_facts(source),
    bindings,
  ).live_binding_plan()
  let mut declared_alias_targets = 0
  for binding in plan.bindings {
    if binding.target.final_name == "shadows__view_bindings__view" {
      declared_alias_targets = declared_alias_targets + 1
    }
  }
  debug_inspect(declared_alias_targets > 0, content="true")
}
