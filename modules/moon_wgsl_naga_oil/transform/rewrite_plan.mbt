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
pub struct WgslReferenceRewritePlan {
  priv bindings : Array[WgslReferenceRewriteBinding]
  priv bindings_by_reference : Map[String, Array[WgslReferenceRewriteBinding]]
  priv virtual_overrides : Array[WgslVirtualOverrideRewriteBinding]
}

///|
priv struct WgslReferenceRewriteBinding {
  final_name : String
  identity_key : String
  key : String
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
  self.key
}

///|
fn WgslVirtualOverrideRewriteBinding::key(
  self : WgslVirtualOverrideRewriteBinding,
) -> String {
  "\{self.raw_target_name}|\{self.target_name}|\{self.override_name}"
}

///|
pub fn WgslReferenceRewritePlan::WgslReferenceRewritePlan() -> WgslReferenceRewritePlan {
  { bindings: [], bindings_by_reference: Map([]), virtual_overrides: [] }
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
  let reference_text = reference_path.text()
  let identity_key = identity.key()
  let binding = WgslReferenceRewriteBinding::{
    final_name,
    identity_key,
    key: "\{identity_key}|\{reference_text}|\{final_name}",
  }
  let key = binding.key()
  for existing in self.bindings {
    if existing.key() == key {
      return
    }
  }
  self.bindings.push(binding)
  match self.bindings_by_reference.get(reference_text) {
    Some(bucket) => bucket.push(binding)
    None => self.bindings_by_reference.set(reference_text, [binding])
  }
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
fn WgslReferenceRewritePlan::has_symbol_bindings(
  self : WgslReferenceRewritePlan,
) -> Bool {
  self.bindings.length() > 0
}

///|
pub fn WgslReferenceRewritePlan::has_virtual_override_bindings(
  self : WgslReferenceRewritePlan,
) -> Bool {
  self.virtual_overrides.length() > 0
}

///|
fn WgslReferenceRewritePlan::final_name_for_reference_path(
  self : WgslReferenceRewritePlan,
  reference_path : WgslReferencePath,
) -> String? {
  match self.binding_for_reference_text(reference_path.text()) {
    Some(binding) => Some(binding.final_name)
    None => None
  }
}

///|
fn WgslReferenceRewritePlan::final_name_for_identifier_text(
  self : WgslReferenceRewritePlan,
  identifier_text : String,
) -> String? {
  match self.binding_for_reference_text(identifier_text) {
    Some(binding) => Some(binding.final_name)
    None => None
  }
}

///|
fn WgslReferenceRewritePlan::binding_for_reference_text(
  self : WgslReferenceRewritePlan,
  reference_text : String,
) -> WgslReferenceRewriteBinding? {
  let reference_text = reference_text.trim().to_owned()
  if reference_text == "" {
    return None
  }
  match self.bindings_by_reference.get(reference_text) {
    Some(bindings) => wgsl_symbol_binding_from_candidates(bindings)
    None => None
  }
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
fn wgsl_symbol_binding_from_candidates(
  bindings : Array[WgslReferenceRewriteBinding],
) -> WgslReferenceRewriteBinding? {
  let mut target : WgslReferenceRewriteBinding? = None
  for binding in bindings {
    let current_identity_key = binding.identity_key
    match target {
      Some(existing) if existing.final_name != binding.final_name =>
        if existing.identity_key == current_identity_key {
          target = Some(binding)
        } else {
          return None
        }
      Some(existing) =>
        if existing.identity_key != current_identity_key {
          return None
        }
      None => target = Some(binding)
    }
  }
  target
}
