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
priv enum WgslRenameRuleKind {
  GlobalDeclarationAndReferences
  FunctionBodyReferencesOnly
  FunctionLocal
}

///|
priv struct WgslRenameRule {
  from_name : String
  to_name : String
  kind : WgslRenameRuleKind
}

///|
priv struct WgslRenamePlan {
  rules : Array[WgslRenameRule]
}

///|
priv struct WgslRenameMaps {
  global_declaration_rules : Array[WgslRenameRule]
  reference_rules : Array[WgslRenameRule]
  function_body_reference_rules : Array[WgslRenameRule]
  function_local_rules : Array[WgslRenameRule]
}

///|
pub struct WgslReferenceRewritePlan {
  priv bindings : Array[WgslReferenceRewriteBinding]
  priv virtual_overrides : Array[WgslVirtualOverrideRewriteBinding]
}

///|
priv struct WgslReferenceRewriteBinding {
  reference_path : WgslReferencePath
  final_name : String
  identity : WgslIrSymbolIdentity
}

///|
priv struct WgslVirtualOverrideRewriteBinding {
  raw_target_name : String
  target_name : String
  override_name : String
}

///|
fn WgslReferenceRewriteBinding::key(
  self : WgslReferenceRewriteBinding,
) -> String {
  "\{self.identity.key()}|\{self.reference_path.text()}|\{self.final_name}"
}

///|
fn WgslVirtualOverrideRewriteBinding::key(
  self : WgslVirtualOverrideRewriteBinding,
) -> String {
  "\{self.raw_target_name}|\{self.target_name}|\{self.override_name}"
}

///|
pub fn WgslReferenceRewritePlan::WgslReferenceRewritePlan() -> WgslReferenceRewritePlan {
  WgslReferenceRewritePlan::{ bindings: [], virtual_overrides: [] }
}

///|
pub fn WgslReferenceRewritePlan::add_symbol_reference_binding(
  self : WgslReferenceRewritePlan,
  identity : WgslIrSymbolIdentity,
  reference_path : WgslReferencePath,
  final_name : String,
) -> Unit {
  let final_name = final_name.trim().to_owned()
  if final_name == "" || reference_path.text() == final_name {
    return
  }
  let binding = WgslReferenceRewriteBinding::{
    reference_path,
    final_name,
    identity,
  }
  let key = binding.key()
  for existing in self.bindings {
    if existing.key() == key {
      return
    }
  }
  self.bindings.push(binding)
}

///|
pub fn WgslReferenceRewritePlan::add_virtual_override_binding(
  self : WgslReferenceRewritePlan,
  raw_target_name : String,
  target_name : String,
  override_name : String,
) -> Unit {
  let raw_target_name = raw_target_name.trim().to_owned()
  let target_name = target_name.trim().to_owned()
  let override_name = override_name.trim().to_owned()
  if raw_target_name == "" || target_name == "" || override_name == "" {
    return
  }
  let binding = WgslVirtualOverrideRewriteBinding::{
    raw_target_name,
    target_name,
    override_name,
  }
  let key = binding.key()
  for existing in self.virtual_overrides {
    if existing.key() == key {
      return
    }
  }
  self.virtual_overrides.push(binding)
}

///|
fn WgslRenamePlan::empty() -> WgslRenamePlan {
  WgslRenamePlan::{ rules: [] }
}

///|
fn WgslRenamePlan::add(
  self : WgslRenamePlan,
  from_name : String,
  to_name : String,
  kind : WgslRenameRuleKind,
) -> Unit {
  let from_name = from_name.trim().to_owned()
  let to_name = to_name.trim().to_owned()
  if from_name == "" || to_name == "" || from_name == to_name {
    return
  }
  self.rules.push(WgslRenameRule::{ from_name, to_name, kind })
}

///|
fn WgslReferenceRewritePlan::target_for_reference(
  self : WgslReferenceRewritePlan,
  from_name : String,
) -> String? {
  match WgslReferencePath::from_text(from_name) {
    Some(reference_path) =>
      match wgsl_symbol_binding_for_reference(self.bindings, reference_path) {
        Some(binding) => Some(binding.final_name)
        None => None
      }
    None => None
  }
}

///|
fn WgslReferenceRewritePlan::has_symbol_bindings(
  self : WgslReferenceRewritePlan,
) -> Bool {
  self.bindings.length() > 0
}

///|
fn WgslReferenceRewritePlan::virtual_override_name_for_target(
  self : WgslReferenceRewritePlan,
  raw_target_name : String,
  target_name : String,
) -> String? {
  let mut override_name : String? = None
  for binding in self.virtual_overrides {
    if binding.raw_target_name != raw_target_name &&
      binding.target_name != target_name {
      continue
    }
    if binding.target_name != target_name {
      continue
    }
    match override_name {
      Some(existing) if existing != binding.override_name => return None
      Some(_) => ()
      None => override_name = Some(binding.override_name)
    }
  }
  override_name
}

///|
fn WgslReferenceRewritePlan::virtual_target_name_for_raw_target(
  self : WgslReferenceRewritePlan,
  raw_target_name : String,
) -> String? {
  let mut target_name : String? = None
  for binding in self.virtual_overrides {
    if binding.raw_target_name != raw_target_name {
      continue
    }
    match target_name {
      Some(existing) if existing != binding.target_name => return None
      Some(_) => ()
      None => target_name = Some(binding.target_name)
    }
  }
  target_name
}

///|
fn WgslReferenceRewritePlan::virtual_raw_target_name_for_target(
  self : WgslReferenceRewritePlan,
  target_name : String,
) -> String? {
  let mut raw_target_name : String? = None
  for binding in self.virtual_overrides {
    if binding.target_name != target_name {
      continue
    }
    match raw_target_name {
      Some(existing) if existing != binding.raw_target_name => return None
      Some(_) => ()
      None => raw_target_name = Some(binding.raw_target_name)
    }
  }
  raw_target_name
}

///|
fn build_wgsl_rename_maps(plan : WgslRenamePlan) -> WgslRenameMaps {
  let global_declaration_rules : Array[WgslRenameRule] = []
  let reference_rules : Array[WgslRenameRule] = []
  let function_body_reference_rules : Array[WgslRenameRule] = []
  let function_local_rules : Array[WgslRenameRule] = []
  for rule in plan.rules {
    match rule.kind {
      GlobalDeclarationAndReferences => {
        global_declaration_rules.push(rule)
        reference_rules.push(rule)
      }
      FunctionBodyReferencesOnly => function_body_reference_rules.push(rule)
      FunctionLocal => function_local_rules.push(rule)
    }
  }
  WgslRenameMaps::{
    global_declaration_rules,
    reference_rules,
    function_body_reference_rules,
    function_local_rules,
  }
}

///|
fn wgsl_rename_rules_target(
  rules : Array[WgslRenameRule],
  from_name : String,
) -> String? {
  let mut target : String? = None
  for rule in rules {
    if rule.from_name != from_name {
      continue
    }
    match target {
      Some(existing) if existing != rule.to_name => return None
      Some(_) => ()
      None => target = Some(rule.to_name)
    }
  }
  target
}

///|
fn wgsl_symbol_binding_for_reference(
  bindings : Array[WgslReferenceRewriteBinding],
  reference_path : WgslReferencePath,
) -> WgslReferenceRewriteBinding? {
  let mut target : WgslReferenceRewriteBinding? = None
  for binding in bindings {
    if !binding.reference_path.matches(reference_path) {
      continue
    }
    let current_identity_key = binding.identity.key()
    match target {
      Some(existing) if existing.final_name != binding.final_name =>
        if existing.identity.key() == current_identity_key {
          target = Some(binding)
        } else {
          return None
        }
      Some(existing) =>
        if existing.identity.key() != current_identity_key {
          return None
        }
      None => target = Some(binding)
    }
  }
  target
}
