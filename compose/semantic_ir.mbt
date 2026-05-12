///|
priv struct WgslComposeIrSymbol {
  identity : WgslIrSymbolIdentity
  final_name : String
  declared : Bool
}

///|
priv struct WgslComposeIrReferenceBinding {
  binding : WgslComposeBinding
  target : WgslComposeIrSymbol
}

///|
priv struct WgslComposeIrSymbolKey {
  text : String
}

///|
priv struct WgslComposeIrIdentityKey {
  text : String
}

///|
priv struct WgslComposeSemanticIr {
  declared_names : @set.Set[String]
  symbol_keys : @set.Set[String]
  symbols : Array[WgslComposeIrSymbol]
  emitted_final_name_by_identity : Map[String, String]
  reference_bindings : Array[WgslComposeIrReferenceBinding]
}

///|
fn WgslComposeIrSymbolKey::WgslComposeIrSymbolKey(
  identity : WgslIrSymbolIdentity,
  final_name : String,
  declared : Bool,
) -> WgslComposeIrSymbolKey {
  WgslComposeIrSymbolKey::{
    text: "\{identity.key()}|\{final_name}|\{declared}",
  }
}

///|
fn WgslComposeIrSymbolKey::text(self : WgslComposeIrSymbolKey) -> String {
  self.text
}

///|
fn WgslComposeIrIdentityKey::WgslComposeIrIdentityKey(
  identity : WgslIrSymbolIdentity,
) -> WgslComposeIrIdentityKey {
  WgslComposeIrIdentityKey::{ text: identity.key() }
}

///|
fn WgslComposeIrIdentityKey::text(self : WgslComposeIrIdentityKey) -> String {
  self.text
}

///|
fn WgslComposeSemanticIr::WgslComposeSemanticIr() -> WgslComposeSemanticIr {
  WgslComposeSemanticIr::{
    declared_names: @set.Set([]),
    symbol_keys: @set.Set([]),
    symbols: [],
    emitted_final_name_by_identity: Map([]),
    reference_bindings: [],
  }
}

///|
fn WgslComposeSemanticIr::record_declared_name(
  self : WgslComposeSemanticIr,
  name : String,
) -> Unit {
  let name = name.trim().to_owned()
  if name != "" {
    self.declared_names.add(name)
  }
}

///|
fn WgslComposeSemanticIr::record_symbol(
  self : WgslComposeSemanticIr,
  identity : WgslIrSymbolIdentity,
  final_name : String,
  declared : Bool,
) -> Unit {
  let final_name = final_name.trim().to_owned()
  if final_name == "" {
    return
  }
  let symbol_key = WgslComposeIrSymbolKey(identity, final_name, declared).text()
  if self.symbol_keys.contains(symbol_key) {
    return
  }
  self.symbol_keys.add(symbol_key)
  self.symbols.push(WgslComposeIrSymbol::{ identity, final_name, declared })
}

///|
fn WgslComposeSemanticIr::record_emitted_symbol_target(
  self : WgslComposeSemanticIr,
  binding : WgslComposeBinding,
) -> Unit {
  let final_name = binding.target.final_name.trim().to_owned()
  if final_name == "" || !self.declared_names.contains(final_name) {
    return
  }
  let identity = binding.target.identity
  self.record_symbol(identity, final_name, true)
  let identity_key = WgslComposeIrIdentityKey(identity).text()
  if !self.emitted_final_name_by_identity.contains(identity_key) {
    self.emitted_final_name_by_identity.set(identity_key, final_name)
  }
}

///|
fn WgslComposeSemanticIr::resolved_binding_target_symbol(
  self : WgslComposeSemanticIr,
  binding : WgslComposeBinding,
) -> WgslComposeIrSymbol {
  let requested_final_name = binding.target.final_name.trim().to_owned()
  if requested_final_name == "" ||
    self.declared_names.contains(requested_final_name) {
    return WgslComposeIrSymbol::{
      identity: binding.target.identity,
      final_name: requested_final_name,
      declared: self.declared_names.contains(requested_final_name),
    }
  }
  let identity_key = WgslComposeIrIdentityKey(binding.target.identity).text()
  match self.emitted_final_name_by_identity.get(identity_key) {
    Some(emitted_name) =>
      WgslComposeIrSymbol::{
        identity: binding.target.identity,
        final_name: emitted_name,
        declared: true,
      }
    None =>
      WgslComposeIrSymbol::{
        identity: binding.target.identity,
        final_name: requested_final_name,
        declared: false,
      }
  }
}

///|
fn WgslComposeSemanticIr::record_reference_binding(
  self : WgslComposeSemanticIr,
  binding : WgslComposeBinding,
) -> Unit {
  let target = self.resolved_binding_target_symbol(binding)
  self.record_symbol(target.identity, target.final_name, target.declared)
  self.reference_bindings.push(WgslComposeIrReferenceBinding::{
    binding,
    target,
  })
}

///|
fn WgslComposeSemanticIr::from_facts_and_bindings(
  facts : WgslComposeSemanticFacts,
  bindings : WgslComposeBindingSet,
) -> WgslComposeSemanticIr {
  let ir = WgslComposeSemanticIr()
  for declaration in facts.declarations {
    ir.record_declared_name(declaration.name())
  }
  for binding in bindings.bindings {
    ir.record_emitted_symbol_target(binding)
  }
  for binding in bindings.bindings {
    ir.record_reference_binding(binding)
  }
  ir
}

///|
fn WgslComposeSemanticIr::symbol_target_is_declared(
  self : WgslComposeSemanticIr,
  identity : WgslIrSymbolIdentity,
  final_name : String,
) -> Bool {
  let final_name = final_name.trim().to_owned()
  if final_name == "" {
    return false
  }
  let identity_key = WgslComposeIrIdentityKey(identity).text()
  for symbol in self.symbols {
    if WgslComposeIrIdentityKey(symbol.identity).text() == identity_key &&
      symbol.final_name == final_name {
      return symbol.declared
    }
  }
  false
}

///|
fn WgslComposeSemanticIr::binding_target_is_declared(
  self : WgslComposeSemanticIr,
  binding : WgslComposeBinding,
  final_name : String,
) -> Bool {
  self.symbol_target_is_declared(binding.target.identity, final_name)
}

///|
fn WgslComposeSemanticIr::binding_is_shadowed_by_local_declaration(
  self : WgslComposeSemanticIr,
  binding : WgslComposeBinding,
  final_name : String,
) -> Bool {
  if binding.scope != UnqualifiedItemBinding {
    return false
  }
  let reference_name = binding.reference_path.text()
  let final_name = final_name.trim().to_owned()
  reference_name != "" &&
  final_name != "" &&
  reference_name != final_name &&
  self.declared_names.contains(reference_name)
}

///|
fn WgslComposeSemanticIr::live_binding_plan(
  self : WgslComposeSemanticIr,
) -> WgslLiveBindingPlan {
  let plan = WgslLiveBindingPlan()
  let seen_binding_keys : @set.Set[String] = @set.Set([])
  for ir_binding in self.reference_bindings {
    let resolved_binding = if ir_binding.target.final_name ==
      ir_binding.binding.target.final_name.trim().to_owned() {
      ir_binding.binding
    } else {
      ir_binding.binding.with_target(
        WgslComposeSymbolTarget(
          ir_binding.target.identity,
          ir_binding.target.final_name,
        ),
      )
    }
    let binding_key = WgslComposeBindingKey(resolved_binding).text()
    if seen_binding_keys.contains(binding_key) {
      continue
    }
    seen_binding_keys.add(binding_key)
    if self.binding_is_shadowed_by_local_declaration(
        resolved_binding,
        ir_binding.target.final_name,
      ) {
      continue
    }
    if ir_binding.target.final_name != "" &&
      (
        self.binding_target_is_declared(
          resolved_binding,
          ir_binding.target.final_name,
        ) ||
        ir_binding.binding.scope == UnqualifiedItemBinding ||
        ir_binding.binding.scope == QualifiedAliasBinding
      ) {
      plan.push(
        resolved_binding.to_live_binding(
          WgslComposeSymbolTarget(
            ir_binding.target.identity,
            ir_binding.target.final_name,
          ),
        ),
      )
    }
  }
  plan
}
